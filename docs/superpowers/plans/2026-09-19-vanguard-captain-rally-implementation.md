# HPA-475 Vanguard Captain + Rally Implementation Plan

**Linear:** HPA-475  
**Design:** `docs/superpowers/specs/2026-09-19-vanguard-captain-rally-design.md`  
**Baseline:** `main` at `51346efefd116360a2a5b242c307ced99842bb07`  
**Delivery:** one draft/implementation PR; do not split persistence, combat, HUD, or integration into child PRs.

## Implementation shape

Extend the HPA-468/HPA-469 seams only:

- `SiegeProgress` persists Captain lane + HP/recovery + Rally consumption.
- `KingdomGameState` owns City 3 availability, stat formula, retreat/recovery, and once-per-siege consumption.
- `BattleCombatState` owns the single transient Captain actor, enemy targeting, Rally timer/reduction, and auto-trigger request.
- `BattleScene` owns orchestration, one Rally activation funnel, rendering, save cadence, and reconstruction.
- `BattleHUDContent` / `BattleHUDNode` add one compact Captain/Rally segment inside the current Deploy panel.
- Existing soldier report rows stay soldier-only; no `BattleResult` schema change.
- HPA-476 remains the sole final image/animation-production task.

Run tests with parallel testing disabled.

---

## Task 0 — Reuse the shipped HPA-469 Highcrest baseline

**Files:** PR body evidence only; no source change.

Do not invent a new benchmark setup. Reuse the deterministic HPA-469 route-balance run already recorded on merged `main`:

```text
City 5 Highcrest
seed: 1
tick: 1/60
selected lane: right / exposed
manual spawns: none
Barracks L2 — slot 1
Barracks L1 — slot 2
Archery Range L1 — slot 3
soldier upgrade level: 1
pre-Captain right-direct result: 567.62s / 158 ordinary-soldier losses
```

- [ ] Record this exact baseline in PR #45.
- [ ] Reuse the same seed/camp/lane/manual policy for Task 6 automatic-vs-manual Rally comparison.
- [ ] Only rerun the existing deterministic seam if implementation needs confirmation; do not author a new benchmark harness or choose a different camp.

**Gate:** Task 6 remains directly comparable with the shipped HPA-469 evidence.

## Task 1 — Add bounded Captain siege persistence, live sync, and recovery ownership

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

### 1.1 RED: availability + normalization + lane

Add tests proving:

- City 1 and City 2 normalize `captain == nil`.
- Fresh City 3+ starts full HP, recovery 0, Rally unused, lane = selected/default lane.
- malformed HP/recovery clamp to current rule values;
- persisted Captain lane survives decode/normalization;
- damaged HP round-trips exactly;
- Rally consumed round-trips exactly;
- increasing `normalSoldierUpgradeLevel` never heals current HP;
- a zero-HP / zero-recovery Captain normalizes to recovered/full HP on current selected lane;
- starting the next city creates fresh Captain/Rally state.

### 1.2 Add the smallest durable shape

In `SiegeState.swift`:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
    var recoveryRemainingSeconds: Double
    var rallyConsumed: Bool
}
```

Add:

```swift
var captain: VanguardCaptainProgress?
```

to `SiegeProgress`. Extend its forgiving custom decode so a malformed optional Captain payload drops to `nil` and owner normalization reconstructs the valid City 3+ state rather than throwing away lane/objective/Guard siblings.

No status enum, actor ID, position, animation, active Rally timer, or version field.

### 1.3 Add one rule owner

Near `KingdomGameState` add `VanguardCaptainRules` exactly as the design specifies:

```text
unlockCity = 3
recoverySeconds = 12
rallyDurationSeconds = 5
rallyDamageMultiplier = 0.70
attack = normal soldier attack + 1
HP base = 20 with existing 1.25-per-level HP curve
```

Do not introduce a Captain level.

### 1.4 Extend `normalizedSiegeProgress` and `startCityFromMap`

Give normalization enough context to derive availability/max HP (current city number + current soldier-upgrade level).

For City 3+:

- HP -> `0...maxHP`;
- recovery -> `0...12`;
- HP > 0 forces recovery to 0 and preserves persisted lane;
- HP == 0 and recovery > 0 remains recovering;
- HP == 0 and recovery == 0 means recovery complete -> full HP and lane = current selected lane;
- preserve `rallyConsumed`.

For City 1–2 force `captain = nil`.

`startCityFromMap` constructs `SiegeProgress` directly; seed fresh Captain progress there for City 3+ in the same construction that already seeds `GuardReinforcementProgress.freshHighcrest()`. Do not rely on decoder normalization to create new-city Captain state.

### 1.5 Add focused mutations + live sync seam

```swift
mutating func recordCaptainRetreat()
@discardableResult
mutating func advanceCaptainRecovery(deltaTime: Double) -> Bool
@discardableResult
mutating func consumeVanguardRally() -> Bool
@discardableResult
mutating func synchronizeLiveCaptain(lane: BattleLane, remainingHP: Int) -> Bool
```

Rules:

- retreat is available only in an active City 3+ siege and sets HP 0 + 12s recovery;
- recovery accepts non-negative elapsed only, never creates damage/reward;
- crossing recovery to zero restores current max HP and writes `lane = siegeProgress.selectedLane` exactly once;
- Rally consumption succeeds only when Captain is currently deployable and unused;
- later Rally calls return false;
- live sync clamps HP to current max, updates the persisted live lane + HP, and reports whether durable state changed;
- never use live sync to resurrect a retreated Captain.

### 1.6 Pin zero-building recovery before current early returns

The existing settlement code deliberately skips Guard/building progress with zero player buildings. Captain recovery is different: it may advance, but still produces no damage.

Add tests and implementation notes for these exact seams:

- `resolveCurrentCityBuildingIdleProgress(at:)`: after computing the capped elapsed window, call `advanceCaptainRecovery` **before** the `occupiedSlotCount == 0` damage return.
- `settleCurrentCityBuildingProgress(at:)`: resolve Captain recovery elapsed from the existing `lastBuildingProgressResolvedAt` or the already-recorded `lastBackgroundedAt` fallback, advance recovery before building-only exits, then continue current spawn/damage semantics.
- `markCurrentCityBuildingProgressInactive(at:)` remains the transition timestamp owner; no Captain timestamp/clock is added.
- zero buildings must still leave Guard wave phase, objective HP, rewards, and conquest unchanged.

Pin both Camp build/upgrade and background/foreground paths so the same elapsed interval is not counted twice.

### 1.7 Round-trip/lifecycle gates

Prove:

1. scene-independent live sync preserves a damaged Captain HP + lane;
2. partial recovery persists;
3. background/foreground may complete recovery with zero buildings;
4. Camp time before the first building may complete recovery but cannot create offline damage;
5. building-driven idle damage/reward behavior stays unchanged apart from Captain recovery;
6. active Rally is not persisted — only consumed is.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests
```

**Gate:** fresh entry, save normalization, live HP/lane durability, and zero-building recovery are green before live combat changes.

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

Introduce one **private** combat-only `AlliedTarget` enum without changing public soldier identity, then keep two helpers because Guard and tower semantics are different:

- `foremostAlliedTarget(in:)` — no range filter; Guard close/attack uses it.
- defensive-fire target selection — covered lanes + source-relative range; tower uses it.

When Captain and a soldier tie at the foremost position, prefer the Captain so equal-speed infantry does not make the Captain impossible to target.

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

- tower can select/damage Captain through the in-range helper;
- same-lane Guard closes on and damages a lone/leading Captain through the no-range foremost helper;
- Captain wins an equal-position tie against an ordinary soldier;
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

The triggering hit is not re-run/reduced. BattleScene cannot activate Rally until `tick` returns, so **all later enemy hits in that same tick are also unprotected**. Rally begins on the next tick.

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

## Task 4 — Wire durable reconstruction, Captain-only ticks, feedback, and one Rally funnel

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

### 4.1 RED: reconstruction restores durable lane + HP

Pin:

- City 2 has no Captain actor/node;
- City 3 constructs exactly one healthy Captain from persisted HP + persisted Captain lane;
- changing the assault flag while Captain is alive leaves both live/persisted Captain lane unchanged;
- Battle -> Camp/Map -> Battle restores that same lane + HP, not `selectedLane`;
- background teardown/foreground restore retains damaged HP + lane;
- recovering Captain has no actor;
- recovery completion writes current selected lane and deploys exactly one Captain there.

### 4.2 Restore beside HPA-469 Guards

Add a focused `restorePersistedCaptainIntoCombat()` next to `restorePersistedGuardsIntoCombat()`.

At scene init and foreground convergence:

- restore Guards exactly as today;
- healthy Captain restores persisted lane + HP;
- recovering Captain restores no actor;
- position starts at 0 and IDs/actions remain transient.

Do not append/duplicate a Captain on UIKit's initial foreground callback; restoration is replace/idempotent like the Guard path.

### 4.3 Widen the current `soldierAttacks.isEmpty` continuation

Current `applyCombatResult` returns when there are no ordinary soldier structure attacks. Captain-only work cannot be placed behind that return.

After `combat.tick`:

1. emit feedback;
2. apply ordinary soldier structure events through current `applyLiveSoldierAttacks`;
3. apply each Captain structure hit through `state.applyObjectiveDamage` with **no** soldier report attribution;
4. record ordinary losses;
5. record Captain retreat;
6. synchronize surviving live Captain lane + HP through `synchronizeLiveCaptain`;
7. process `shouldAutoActivateRally` through the one activation funnel;
8. advance Captain recovery with the combat-clamped delta;
9. deploy once if recovery crosses ready;
10. then run the existing Guard snapshot sync / wave advance / restore.

The continuation must run when **any** of these are present: soldier structure attack, Captain structure hit, Captain retreat, Captain HP change, or Rally auto-request.

A Captain Keep kill must reuse the existing `persistLiveCombatStateAndEmitFreshOutcomeFeedback` and pending-report presenter. Capture the pre-Captain-hit stage; if `applyObjectiveDamage` moves the state out of `.battleActive`, use the newly created `pendingBattleResult` as the source of `goldEarned` and present that outcome exactly once through the existing path. Do not add a second conquest/report path or a Captain-specific reward calculation.

### 4.4 Immediate save rules

Match the HPA-469 durability lesson:

- changed Captain HP/lane -> save immediately;
- retreat -> save immediately;
- Rally consumed -> save before starting the transient timer;
- recovery completion -> save immediately;
- recovery countdown-only changes may use the broadened existing two-second progress cadence.

Extend the cadence predicate so a recovering Captain is a reason to persist progress even when there are no buildings/Guard waves.

### 4.5 One activation funnel

Add:

```swift
private func activateRally()
```

Order:

1. require a live Captain and capture its fixed lane;
2. `guard state.consumeVanguardRally() else { return }`;
3. save consumed state;
4. `combat.startRally(lane: captainLane)`;
5. emit existing feedback;
6. redraw.

Manual HUD action and `result.shouldAutoActivateRally` both call this method. Because auto activation happens after `tick`, protection begins next tick; no same-tick hit is retroactively changed.

### 4.6 Existing sound mapping is required, not optional

Extend `AutomaticCombatFeedbackScheduler.candidates(from:)` only:

- Captain structure / Guard hits contribute existing `.attackMelee`;
- Guard attacks against Captain still contribute existing `.attackMelee`;
- Captain-targeted tower hits contribute existing `.towerFire`;
- no new sound IDs/assets.

Add scheduler/coordinator tests for Captain-only combat so City 3+ is not silent when ordinary soldiers are not attacking.

### 4.7 Lifecycle + regression gate

Pin:

- manual then auto and auto then manual cannot consume twice;
- save/load retains damaged active HP/lane, recovering state, and Rally used;
- scene reconstruction while active Rally loses timer but stays Used;
- Camp/background HP round-trip cannot heal Captain;
- zero-building recovery can complete without any objective damage/reward/conquest;
- Captain-only structure tick damages Barracks/Keep and Captain-only Keep kill presents the normal conquest report;
- Captain never arms/extends manual-soldier navigation lock.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

**Gate:** Captain-only combat, HP/lane reconstruction, and zero-building recovery are green before HUD polish.

## Task 5 — Pack Captain/Rally into the existing Deploy row and reuse animation seams

**Files:**
- Modify: `Pyxis/BattleHUDNode.swift` (**`BattleHUDContent` is in this file**)
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleHUDContentTests.swift`
- Modify: `PyxisTests/BattleHUDNodeTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

Do **not** add `Pyxis/BattleHUDContent.swift`. Do **not** modify `BattleChromeLayout` unless the 375×667 packing test proves today's `deployFrame` cannot hold both regions.

### 5.1 Extend HUD projection with live Rally state

Add a small Captain display projection inside `BattleHUDContent`, for example:

```text
unavailable
ready(currentHP,maxHP,rallyState)
recovering(seconds,rallyConsumed)
```

Change `BattleHUDContent.project` to accept live combat inputs from BattleScene:

```text
captainIsDeployed
rallyRemainingSeconds
```

`KingdomGameState` supplies durable HP/recovery/consumed state; `rallyRemainingSeconds` is required to distinguish transient **Active** from durable **Used**.

### 5.2 Pin the packing rule

City 1–2: today's centered Deploy cluster and full-frame Deploy hit region remain unchanged.

City 3+:

- left-align the current Deploy icon/label/divider/manual-count cluster;
- reserve one right strip for Captain status;
- the right strip must contain a ≥44pt Rally target plus compact `CAPT 18/20` / `CAPT 7s`;
- the remaining left region must still contain a valid Deploy hit target;
- `Action.rally` is checked before `.deploy` in `action(at:)`.

This is the contract to test at 375×667 before considering any `BattleChromeLayout` change.

### 5.3 Placeholder/runtime asset contract

Stable names only:

```text
vanguard-captain-portrait        128x128 center
vanguard-captain-resting         128x128 feet/bottom-center
vanguard-captain-walk-01...10    128x128 feet/bottom-center
vanguard-captain-attack-01...10  128x128 feet/bottom-center
vanguard-captain-hit-01...10     128x128 feet/bottom-center
rally-icon                       64x64 center
rally-protection-accent          128x128 feet/bottom-center
```

HPA-475 adds no generated images.

Do not fork `playSoldierAnimation`. Reuse:

- `SoldierAnimationAction`;
- `SoldierAnimationTiming`;
- the existing complete-trio walk/attack/hit probe/playback semantics.

Make the existing all-or-nothing name probe usable with the Captain prefix. While HPA-476 frames are absent, render one procedural/static Captain sprite. Once HPA-476 drops the complete trio under the fixed names, the same animation path activates automatically; partial action sets fall back to static.

Retreat remains procedural fade/scale. Rally protection may be procedural until HPA-476 supplies its optional accent.

### 5.4 Visual/interaction tests

Pin:

- City 1/2 HUD remains unchanged;
- City 3 Captain strip fits inside Deploy on 375×667 and 393×852;
- Rally target >=44;
- remaining Deploy region is still tappable;
- Rally tap never returns `.deploy`;
- Deploy outside Rally strip still spawns normally;
- manual count remains visible/correct;
- Ready / Active / Used / Recovering copy fits;
- project receives live timer and shows Active only while timer > 0;
- missing/partial Captain frame trio uses static fallback;
- complete trio path uses the existing animation mechanism;
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

## Task 6 — Tune only bounded numbers and finish evidence

**Files:** source/tests only if a bounded tuning value changes; otherwise PR body evidence.

### 6.1 Deterministic comparison

Using the exact shipped HPA-469 setup from Task 0 (seed 1, 1/60 tick, right/exposed, no manual spawns, Barracks L2/L1 + Archery L1, soldier level 1), compare:

1. automatic/watch-only behavior;
2. one deliberately timed manual Rally.

Keep 567.62s / 158 ordinary-soldier losses as the pre-Captain reference; do not substitute a new camp.

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
- Camp/Map/background reconstruction retaining the old persisted live lane;
- recovery completion redeploying in the new selected lane;
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
Pyxis/BattleHUDNode.swift
```

`Pyxis/AutomaticCombatFeedbackScheduler.swift` to reuse existing sound candidates for Captain-only combat.

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
