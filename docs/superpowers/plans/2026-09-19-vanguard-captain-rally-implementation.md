# HPA-475 Vanguard Captain + Rally Implementation Plan

**Linear:** HPA-475  
**Design:** `docs/superpowers/specs/2026-09-19-vanguard-captain-rally-design.md`  
**Baseline:** `main` at `51346efefd116360a2a5b242c307ced99842bb07`  
**Delivery:** one draft/implementation PR; do not split persistence, combat, HUD, or integration into child PRs.

## Implementation shape

Extend the HPA-468/HPA-469 seams only:

- `SiegeProgress` persists Captain HP/recovery + Rally consumption.
- `KingdomGameState` owns City 3 availability, stat formula, retreat/recovery, and once-per-siege consumption.
- `BattleCombatState` owns the single transient Captain actor, enemy targeting, Rally timer/reduction, and auto-trigger request.
- `BattleScene` owns orchestration, one Rally activation funnel, rendering, save cadence, and reconstruction.
- `BattleHUDContent` / `BattleHUDNode` add one compact Captain/Rally segment inside the current Deploy panel.
- Existing soldier report rows stay soldier-only; no `BattleResult` schema change.
- HPA-476 remains the sole final image/animation-production task.

Run tests with parallel testing disabled.

---

## Task 0 — Pin the pre-Captain gameplay baseline

**Files:** PR body evidence only; no source change.

- [ ] Use the merged HPA-469 `main` baseline and one deterministic City 5 setup/seed.
- [ ] Record the setup used for the final comparison: buildings/levels, selected lane, manual spawn policy, combat seed.
- [ ] Capture watch-only Highcrest elapsed conquest time + normal soldier losses.
- [ ] Keep this same setup for Task 6. Do not write a new benchmark harness unless current test seams cannot make the comparison deterministic.

**Gate:** one reproducible pre-HPA-475 reference recorded in the PR body.

---

## Task 1 — Add bounded Captain siege persistence and rules

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`

### 1.1 RED: availability + normalization

Add tests proving:

- City 1 and City 2 normalize `captain == nil`.
- Fresh City 3+ starts at full HP, recovery 0, Rally unused.
- malformed HP/recovery clamp to current rule values;
- damaged HP round-trips exactly;
- Rally consumed round-trips exactly;
- increasing `normalSoldierUpgradeLevel` never heals current HP;
- a zero-HP / zero-recovery active Captain state normalizes to recovered/full HP;
- starting the next city creates fresh Captain/Rally progress.

### 1.2 Add the smallest durable shape

In `SiegeState.swift`:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
    var remainingHP: Int
    var recoveryRemainingSeconds: Double
    var rallyConsumed: Bool
}
```

Add:

```swift
var captain: VanguardCaptainProgress?
```

to `SiegeProgress`. Extend the current forgiving custom decode so a malformed optional Captain payload drops to `nil` and owner normalization reconstructs the valid City 3+ state rather than throwing away lane/objective/Guard siblings.

No status enum, lane, actor ID, animation, active Rally timer, or version field.

### 1.3 Add one rule owner

Near `KingdomGameState` add `VanguardCaptainRules` exactly as the design specifies:

```swift
unlockCity = 3
recoverySeconds = 12
rallyDurationSeconds = 5
rallyDamageMultiplier = 0.70
attack = normal soldier attack + 1
HP base = 20 with existing 1.25-per-level HP curve
```

Do not introduce a Captain level.

### 1.4 Extend `normalizedSiegeProgress`

Give normalization enough context to derive availability/max HP (current city number + current soldier-upgrade level).

For City 3+:

- HP -> `0...maxHP`;
- recovery -> `0...12`;
- HP > 0 forces recovery to 0;
- HP == 0 and recovery > 0 remains recovering;
- HP == 0 and recovery == 0 means recovery complete -> full HP;
- preserve `rallyConsumed`.

For City 1–2 force `captain = nil`.

### 1.5 Add focused mutations

```swift
mutating func recordCaptainRetreat()
@discardableResult
mutating func advanceCaptainRecovery(deltaTime: Double) -> Bool
@discardableResult
mutating func consumeVanguardRally() -> Bool
```

Rules:

- retreat is available only in an active City 3+ siege and sets HP 0 + 12s recovery;
- recovery accepts non-negative elapsed only, never creates damage/reward;
- crossing recovery to zero restores the **current** max HP exactly once;
- Rally consumption succeeds only when Captain is currently deployable and unused;
- later calls return false.

### 1.6 RED/GREEN lifecycle ownership

Add lifecycle tests proving:

1. live recovery advances only by the passed delta;
2. background/foreground may advance recovery with zero buildings;
3. zero buildings still deal zero idle damage and cannot conquer;
4. building-driven idle damage/reward behavior is byte-for-byte unchanged apart from Captain recovery state;
5. active Rally is not persisted — only consumed is.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests
```

**Gate:** pure save/state behavior green before live combat changes.

---

## Task 2 — Add one Captain actor to the existing combat tick

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

### 2.1 RED: Captain actor contract

Pin:

- only one Captain can be deployed;
- deployment starts at position 0 on the requested lane;
- deploying again while alive is a no-op;
- Captain current HP is restored from persisted progress;
- lane does not change when assault selection changes outside combat;
- Captain uses the same first Guard / first live route-objective ordering;
- Captain cannot walk through a Guard;
- Captain structure hit reports the correct objective ID and clamped combat damage;
- Captain Guard damage stays Guard damage, not city damage.

### 2.2 Add dedicated Captain, not a SoldierType

Add one optional `Captain` to `BattleCombatState` with:

```text
lane
max/current HP
defense
attack power/speed/range
movement speed
position
attack cooldown
```

Use `VanguardCaptainRules` for HP/attack and existing base infantry configuration values for the remaining stats.

Do not add:

- `SoldierType.captain`;
- `SoldierSpawnSource.captain`;
- hero protocol/base class;
- actor registry.

### 2.3 Reuse route/Guard targeting

Captain movement in the existing tick:

1. find nearest living Guard in Captain lane;
2. otherwise find first live route objective;
3. move toward that target under the same no-cross/range math;
4. hit Guard first when blocked;
5. otherwise emit Captain structure hit.

Add only the Captain-specific result records needed by scene/presentation. Do not convert Captain structure damage to `SoldierAttackEvent`.

### 2.4 Let enemies target Captain

Introduce a **private** combat-only `AlliedTarget` selector so tower/Guard targeting can choose the foremost in-range soldier or Captain without changing public soldier identity.

Preserve existing soldier events. Add separate Captain-hit signals for:

- tower -> Captain;
- Guard -> Captain.

Captain HP reaching zero:

- emits `didCaptainRetreat` once;
- removes Captain from live combat;
- emits no `SoldierLossEvent`;
- does not increment soldier loss/deployment/report rows.

Tower lane RNG remains conditional on a real choice between multiple occupied covered lanes.

### 2.5 Regression tests

Pin:

- tower can select/damage Captain;
- same-lane Guard can select/damage Captain;
- Captain defeat emits no normal loss;
- with Captain absent, existing HPA-469 tower/Guard/soldier results stay unchanged;
- `livingSoldierCount(source: .manual)` ignores Captain.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleCombatStateTests
```

**Gate:** Captain combat works with no Rally/HUD dependency.

---

## Task 3 — Add hard-coded Rally and automatic trigger

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

### 3.1 RED: exact Rally math

Pin protected same-lane ordinary soldier base damage:

```text
1 -> 1
2 -> 1
3 -> 2
4 -> 3
```

Also pin:

- off-lane soldier unchanged;
- Captain damage unchanged;
- active timer starts at exactly 5.0s;
- timer expires deterministically and never becomes ready again by itself;
- no stacking/restart inside the same activation.

### 3.2 Add two transient fields only

```swift
private var rallyLane: BattleLane?
private var rallyRemainingSeconds: Double
```

Expose small read-only projections needed by scene/UI plus:

```swift
mutating func startRally(lane: BattleLane)
```

No `TimedEffect`, `Buff`, `Ability`, cooldown, charge, or status-effect collection.

### 3.3 Apply reduction at enemy damage sites

After existing tower/Guard base damage is calculated, for an ordinary soldier only:

```swift
max(1, Int((Double(baseDamage) * 0.70).rounded()))
```

Apply only if timer > 0 and lane matches captured `rallyLane`.

### 3.4 Emit one auto-trigger request

Give `tick` one explicit Boolean input such as `rallyAutoTriggerAvailable`.

When tower/Guard damages an ordinary soldier and the hit:

- targets Captain lane;
- starts at/above half HP;
- leaves that soldier alive below half HP;
- Rally was available at tick start;
- Rally is not already active;

set `TickResult.shouldAutoActivateRally = true` once.

Do not introduce an engagement state: the enemy hit itself proves active engagement, and the current enemy target helper already selects a frontline target.

The triggering hit is not re-run/reduced.

### 3.5 Double-trigger tests

Within one tick and across consecutive ticks prove:

- multiple qualifying hits still request only one activation;
- once BattleScene consumes Rally, later requests are rejected by durable state;
- a soldier already below half before the hit does not trigger;
- a killing hit does not trigger;
- off-lane hit does not trigger;
- recovering/no-Captain case cannot request.

Run the focused combat suite again.

**Gate:** pure Rally semantics complete before UI wiring.

---

## Task 4 — Wire scene reconstruction, recovery, combat events, and one Rally funnel

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift` only if needed to reuse an existing melee/impact cue
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift` only if scheduler changes
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`

### 4.1 RED: scene construction/redeployment

Pin:

- City 2 has no Captain node/actor;
- City 3 constructs exactly one healthy Captain in selected lane;
- changing lane while Captain is alive leaves its lane unchanged;
- reconstructing the scene is a redeployment and uses the current selected lane;
- recovering Captain has no actor;
- recovery completion creates one Captain in the then-current lane.

### 4.2 Restore/deploy from durable state

At BattleScene construction/clear-and-rebuild:

- restore HPA-469 Guards exactly as today;
- if Captain progress is healthy, deploy one Captain using persisted HP + selected lane;
- if recovering, deploy none.

Do not persist Captain position/lane.

### 4.3 Integrate live tick in existing order

Preserve the HPA-469 save/settlement order. Add:

- apply Captain structure-hit events via `state.applyObjectiveDamage`;
- **do not** call `recordSoldierDeployment`, `recordSoldierLosses`, or `ActiveSiegeSession.recordAttack` for Captain;
- on `didCaptainRetreat`, call `state.recordCaptainRetreat()`;
- advance Captain recovery using the same combat-clamped live delta;
- on recovery completion, deploy once;
- keep Guard snapshot synchronization/waves in their existing owner/order.

A Captain Keep kill can finish conquest through `applyObjectiveDamage`; report MVP remains ordinary-soldier attribution only.

### 4.4 One activation funnel

Add one private scene method:

```swift
private func activateRally()
```

Order:

1. require live Captain and capture its lane;
2. `guard state.consumeVanguardRally() else { return }`;
3. `combat.startRally(lane: captainLane)`;
4. persist state;
5. emit existing feedback;
6. redraw.

Manual HUD action and `result.shouldAutoActivateRally` both call this method.

### 4.5 Lifecycle/reconstruction tests

Pin:

- manual then auto cannot consume twice;
- auto then manual cannot consume twice;
- save/load retains damaged/recovering HP and Rally used;
- scene reconstruction while active Rally ends transient effect but leaves Used;
- background/foreground advances recovery without Captain offline damage;
- Captain never arms/extends manual-soldier navigation lock.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests
```

**Gate:** feature is fully playable with procedural Captain/Rally presentation.

---

## Task 5 — Add compact Deploy-row presentation and fixed HPA-476 asset contract

**Files:**
- Modify: `Pyxis/BattleHUDNode.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/BattleHUDContent.swift`
- Modify: `PyxisTests/BattleHUDContentTests.swift`
- Modify: `PyxisTests/BattleHUDNodeTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

Do **not** modify `BattleChromeLayout` unless the existing Deploy frame genuinely cannot fit the bounded segment on the supported compact-phone fixture. Prefer deriving the subframes inside `BattleHUDNode` from the already validated `deployFrame`.

### 5.1 Extend HUD projection

Add one small Captain projection to `BattleHUDContent`, for example:

```text
unavailable
ready(currentHP,maxHP,rallyState)
recovering(seconds,rallyConsumed)
```

This is display state, not a new domain owner.

### 5.2 Add right-side Captain/Rally segment

City 1–2 retain today's Deploy rendering/hit area.

For City 3+:

- reserve a bounded right-side segment inside `layout.deployFrame`;
- show portrait/fallback, compact HP or recovery seconds, and Rally Ready/Active/Used;
- Rally segment has a >=44pt hit target only when actionable;
- remaining Deploy area remains the soldier-spawn hit target;
- `action(at:)` checks Rally before Deploy.

Keep the existing manual count visible.

Do not add a second bottom row, battlefield floating button, hero modal, or top-band height.

### 5.3 Placeholder asset probes

Add stable names/fallbacks only:

```text
vanguard-captain-portrait        128x128 center
vanguard-captain-resting         128x128 feet/bottom-center
vanguard-captain-walk-01...10    128x128 feet/bottom-center
vanguard-captain-attack-01...10  128x128 feet/bottom-center
vanguard-captain-hit-01...10     128x128 feet/bottom-center
rally-icon                       64x64 center
rally-protection-accent          128x128 feet/bottom-center
```

HPA-475 adds no generated assets. Reuse procedural shapes/SF symbols when files are absent. Retreat remains procedural fade/scale and requires no asset set.

### 5.4 Visual/interaction tests

Pin at minimum:

- existing City 1/2 HUD remains unchanged;
- City 3 Captain segment fits inside Deploy frame on 375×667 and 393×852;
- Rally hit target >=44;
- Rally tap is not interpreted as Deploy;
- Deploy outside Rally segment still spawns normally;
- manual count remains visible/correct;
- portrait/fallback does not alter hit geometry;
- Ready / Active / Used / Recovering copy fits;
- Settings, tabs, lane chips and conquest report remain reachable.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleHUDContentTests \
  -only-testing:PyxisTests/BattleHUDNodeTests \
  -only-testing:PyxisTests/BattleSceneTests
```

**Gate:** compact phone and portrait iPad smoke pass before tuning.

---

## Task 6 — Tune only bounded numbers and finish evidence

**Files:** source/tests only if a bounded tuning value changes; otherwise PR body evidence.

### 6.1 Deterministic comparison

Using Task 0 setup/seed, compare:

1. automatic/watch-only behavior;
2. one deliberately timed manual Rally.

Record:

```text
elapsed to conquest
ordinary soldier losses
Captain retreats
Rally activation time + manual/auto origin
Captain structure damage observed (debug evidence only; no report schema)
```

Success criteria are qualitative but bounded:

- Captain is visible/useful support, not the dominant damage source;
- Rally causes a noticeable survival difference when timed into pressure;
- watch-only remains viable;
- no new mechanic is added to “fix” tuning.

If needed, tune only:

- Captain base HP;
- Captain attack `+N`;
- fixed recovery seconds.

Do not change Rally's 30% / five seconds / once-per-siege contract.

### 6.2 Gameplay/visual evidence

Capture:

- City 3 automatic Captain deployment;
- lane flag changed while Captain remains in old live lane;
- next redeployment in new selected lane;
- Captain vs Guard and structure;
- manual or automatic Rally plus visible protected-soldier accent;
- Captain retreat and automatic return;
- 393×852 reference, compact supported phone, portrait iPad;
- Settings/tabs/lane flag/Deploy/report unobstructed.

### 6.3 Full gates

Run repository-required tests/lint/coverage plus at least:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Update the PR body with:

- focused test results;
- full suite result;
- deterministic comparison table;
- visual smoke evidence;
- final tuning values;
- explicit note that HPA-476 owns all final generated Captain/Rally art.

---

## Expected implementation footprint

Primary production files:

```text
Pyxis/SiegeState.swift
Pyxis/KingdomGameState.swift
Pyxis/BattleCombatState.swift
Pyxis/BattleScene.swift
Pyxis/BattleHUDContent.swift
Pyxis/BattleHUDNode.swift
```

Possibly `AutomaticCombatFeedbackScheduler.swift` only to reuse existing sound candidates.

Expected test files:

```text
PyxisTests/KingdomGameStateTests.swift
PyxisTests/KingdomGameStoreTests.swift
PyxisTests/ActiveSiegeLifecycleTests.swift
PyxisTests/BattleCombatStateTests.swift
PyxisTests/BattleSceneTests.swift
PyxisTests/BattleHUDContentTests.swift
PyxisTests/BattleHUDNodeTests.swift
```

Explicitly **not expected**:

```text
BattleResultModels schema changes
new hero/ability/effect framework files
new persistence repository
new offline simulator
new art or SFX files
new Linear child tickets
```
