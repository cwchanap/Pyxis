# HPA-475 Vanguard Captain + Rally Implementation Plan

**Linear:** HPA-475  
**Design:** `docs/superpowers/specs/2026-09-19-vanguard-captain-rally-design.md`  
**Baseline:** `main` at `51346efefd116360a2a5b242c307ced99842bb07`  
**Delivery:** one draft/implementation PR; do not split persistence, combat, HUD, or integration into child PRs.

## Implementation shape

Reuse the HPA-468/HPA-469 runtime instead of building a parallel hero actor:

- `SiegeProgress` persists Captain lane + HP/recovery + Rally consumption.
- `Country1CityCatalog.swift` owns `VanguardCaptainRules` beside `HighcrestGuardRules`; availability remains derived from City 3+ campaign position.
- `BattleCombatState.Soldier` gains transient `isCaptain`; the Captain reuses the existing soldier movement/route/Guard/tower/pruning loop.
- `SoldierAttackEvent` / `SoldierLossEvent` gain transient `isCaptain` with default false; BattleScene partitions Captain events before report persistence.
- `BattleCombatState` owns only the Rally lane/timer and ticket-required auto-trigger request; no Captain actor hierarchy or generic effect system.
- `BattleScene` restores/synchronizes Captain through a sibling post-tick function next to HPA-469 Guard synchronization; ordinary `applyCombatResult` is not widened into a five-condition continuation.
- Captain recovery advances only in live Battle. Settlement/idle code remains unchanged.
- `BattleChromeLayout` computes disjoint Deploy/Captain/Rally frames; `BattleHUDNode` is a pure consumer.
- Existing soldier-node animation/rendering is reused with a Captain asset prefix.
- Existing soldier report rows stay soldier-only; no `BattleResult` schema change.
- HPA-476 remains the sole final image/animation-production task.

Run tests with parallel testing disabled.

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

## Task 1 — Add bounded Captain persistence and Country 1 rules

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`

### 1.1 RED: availability + durable shape

Pin:

- City 1/2 -> `captain == nil`;
- fresh City 3+ -> full current HP, recovery 0, Rally unused, lane = selected/default lane;
- lane/HP/recovery/Rally round-trip;
- malformed optional Captain payload does not discard sibling siege/Guard progress;
- negative HP/recovery normalize safely;
- current max HP is derived from the current soldier-upgrade level without changing `normalizedSiegeProgress`'s signature;
- increasing the soldier upgrade level never heals a damaged Captain;
- HP 0 + recovery 0 means recovery complete and restores current max HP on current selected lane;
- next-city entry creates a fresh Captain/Rally state.

### 1.2 Add `VanguardCaptainProgress`

In `SiegeState.swift`:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
    var recoveryRemainingSeconds: Double
    var rallyConsumed: Bool
}
```

Add optional `captain` to `SiegeProgress` and its forgiving custom decode. A malformed Captain payload drops to nil; lane/objective/Guard siblings still decode.

No status enum, actor ID, position, animation state, active Rally seconds, or save version.

### 1.3 Put Captain rules beside Country 1 combat tuning

In `Country1CityCatalog.swift`, beside `HighcrestGuardRules`:

```swift
enum VanguardCaptainRules {
    static let unlockCity = 3
    static let recoverySeconds = 12.0
    static let rallyDurationSeconds = 5.0
    static let rallyDamageMultiplier = 0.70

    static func isAvailable(cityNumber: Int) -> Bool {
        cityNumber >= unlockCity
    }

    static func attackPower(for upgradeLevel: Int) -> Int { ... }
    static func maxHP(for upgradeLevel: Int) -> Int { ... }
}
```

Also add parameter-free `VanguardCaptainProgress.normalizedForCaptain()` beside `normalizedForHighcrest()`: clamp HP >= 0, recovery into 0...12, preserve lane/consumed, force recovery 0 while HP > 0.

Do not add `CityDefinition.hasVanguardCaptain`: that would be a second authored unlock flag for a rule already defined as “City 3 onward.”

### 1.4 Keep `normalizedSiegeProgress` generic

Do **not** add city-number or upgrade-level parameters to `normalizedSiegeProgress`.

In the existing top-level `KingdomGameState.init`, after ordinary siege normalization and after `normalSoldierUpgradeLevel` is clamped:

1. if stage is not `.battleActive` or `VanguardCaptainRules.isAvailable(cityNumber: normalizedCityNumber)` is false -> `captain = nil`;
2. City 3+ missing Captain -> seed fresh full HP on `siegeProgress.selectedLane`;
3. existing Captain -> `normalizedForCaptain()`, then clamp HP to `VanguardCaptainRules.maxHP(for: normalSoldierUpgradeLevel)`;
4. HP 0 + recovery 0 -> recovery is complete: restore current max HP and set lane to selected lane.

This keeps the existing generic siege normalizer signature and avoids decoder ordering coupling.

### 1.5 Seed direct city entry

`startCityFromMap` constructs `SiegeProgress` directly. Seed fresh Captain state for City 3+ at the same call site that seeds Highcrest Guard progress.

### 1.6 Add focused state mutations

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

- retreat -> HP 0 + 12s recovery, keep last live lane;
- recovery accepts non-negative **live combat delta only**; crossing zero restores current max HP + current selected lane once;
- consume Rally once while deployable/unused;
- live sync clamps HP to current max and writes live lane/HP; never resurrect a retreat;
- no mutation here creates damage/reward/conquest.

### 1.7 Run focused pure-state suites

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/Country1CityCatalogTests
```

**Gate:** durable shape, fresh entry, decode, current-max clamp, and one-shot Rally mutation green. No settlement/scene file changes.

## Task 2 — Reuse the existing Soldier runtime for the Captain

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

### 2.1 RED: flagged-soldier contract

Pin:

- ordinary `spawnSoldier` creates `isCaptain == false`;
- `spawnCaptain` creates exactly one `isCaptain == true` soldier and a second call is a no-op/returns the same active Captain contract;
- Captain restores persisted lane + HP at position 0;
- Captain uses existing infantry movement/range/defense/attack-speed but Captain HP/attack formula;
- lane-chip state changes outside combat do not mutate the live Captain lane;
- existing route/Guard blocker/structure targeting applies to Captain without a second loop;
- Captain can hit a Guard and later structure through existing soldier logic;
- tower/Guard target the flagged Captain naturally;
- equal-position ties prefer Captain;
- ordinary behavior is unchanged when no Captain exists.

### 2.2 Add one flag, not one actor hierarchy

Extend `BattleCombatState.Soldier`:

```swift
let isCaptain: Bool
```

Ordinary spawns set false. Add one narrow `spawnCaptain(progress:upgradeLevel:)` / restore helper that appends a `Soldier` using:

```text
type = infantry
source = manual        // transient compatibility carrier only
level = current upgrade level
lane = persisted Captain lane
currentHP = min(persisted HP, Captain max)
attackPower = VanguardCaptainRules.attackPower
remaining stats = existing infantry formulas
position = 0
isCaptain = true
```

No `Captain` struct, `AlliedTarget` enum, enemy hierarchy, pathfinder, or duplicate actor loop.

### 2.3 Reuse movement/route/Guard/tower logic unchanged

Captain stays in `soldiers`, so existing:

- soldier loop;
- `movementTarget`;
- `advanceMovement`;
- `isInAttackRange`;
- `attackGuardBlockerIfInRange`;
- `resolveSoldierAttackOnGuard`;
- `nearestGuardBlockerIndex`;
- Guard movement/attack selection;
- defensive-fire in-range selection;
- pruning;

all remain the implementation path.

Only adjust the two foremost `max` comparisons so equal-position candidates prefer `isCaptain`.

### 2.4 Transient event identity

Add `isCaptain: Bool = false` via explicit initializers to:

```swift
SoldierAttackEvent
SoldierLossEvent
```

The existing loop sets the flag from the attacking/lost Soldier.

Do not change `SoldierSpawnSource` or `BattleResultModels`.

### 2.5 Preserve ordinary soldier counts

Change:

```swift
livingSoldierCount
livingSoldierCount(source:)
```

to count only living `!isCaptain` soldiers.

Add a focused Captain accessor/snapshot for BattleScene orchestration.

This one filter preserves:

- HUD manual count;
- manual cap;
- Battle -> Camp/Map navigation lock;
- ordinary “Soldiers” tooltip/count.

### 2.6 Regression gate

Pin:

- Captain attack/loss events carry `isCaptain`;
- ordinary events default false so existing test constructors remain concise;
- Captain retreat event does not change ordinary count;
- Guard/tower can hit Captain;
- Guard/tower equal-position tie picks Captain;
- ordinary `livingSoldierCount` remains unchanged with Captain present;
- no-Captain HPA-469 fixtures stay byte-for-byte equivalent where deterministic.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleCombatStateTests
```

**Gate:** Captain combat works entirely through the existing Soldier loop before Rally/UI integration.

## Task 3 — Add hard-coded Rally reduction and required automatic fallback

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

### 3.1 Add only two transient fields

```swift
private var rallyLane: BattleLane?
private var rallyRemainingSeconds: Double
```

Expose read-only `rallyRemainingSeconds` and:

```swift
mutating func startRally(lane: BattleLane)
```

No `Buff`, `Ability`, `TimedEffect`, cooldown, charge, or status-effect collection.

### 3.2 Fold Rally into tower damage's existing single round

For a protected ordinary soldier:

```swift
laneMultiplier * rallyMultiplier
```

is multiplied into base tower damage **before** the existing `.rounded()` + `max(1,...)`.

Never round lane damage first and Rally second.

Pin Rally effect at neutral lane multiplier:

```text
1 -> 1
2 -> 1
3 -> 2
4 -> 3
```

### 3.3 Insert Guard Rally reduction before HP clamp

Guard attacks do not use `damageAgainstSoldier` today. Apply the 0.70 multiplier to `HighcrestGuardRules.attackPower`, round once/minimum 1, then `min(..., currentHP)`.

Pin the same 1→1, 2→1, 3→2, 4→3 reduction helper at this site too.

Captain (`isCaptain`) and off-lane soldiers are never reduced.

### 3.4 Keep the Linear-required automatic fallback

Do **not** delete auto Rally. HPA-475 explicitly requires it and acceptance requires automatic trigger + manual/automatic double-trigger prevention.

Give `tick` one explicit Boolean such as `rallyAutoTriggerAvailable`. On tower/Guard damage to an ordinary soldier:

- Captain is active;
- target lane equals Captain lane;
- pre-hit HP >= half max HP;
- post-hit HP < half max HP and > 0;
- Rally was available at tick start;
- Rally is not already active;

then set `TickResult.shouldAutoActivateRally = true` at most once.

The triggering hit and all later hits in the same tick remain unprotected; BattleScene activates only after `tick` returns.

### 3.5 Pure combat gate

Pin:

- timer starts 5s and expires deterministically;
- no stack/restart;
- off-lane / Captain unaffected;
- threshold crossing requests once;
- already-below-half, killing hit, wrong lane, no Captain, unavailable/active Rally do not request;
- ordinary Captain-as-tank tie behavior can delay auto fallback naturally, but no product rule is changed.

Run `BattleCombatStateTests` again.

**Gate:** manual `startRally` and ticket-required auto request are pure/deterministic before scene/UI wiring.

## Task 4 — Move the Deploy/Captain split into pure BattleChromeLayout

**Files:**
- Modify: `Pyxis/BattleChromeLayout.swift`
- Modify: `Pyxis/BattleHUDNode.swift`
- Modify: `PyxisTests/BattleChromeLayoutTests.swift`
- Modify: `PyxisTests/BattleHUDContentTests.swift`
- Modify: `PyxisTests/BattleHUDNodeTests.swift`

### 4.1 Add explicit disjoint frames

`BattleChromeLayout` gains:

```swift
let deployActionFrame: CGRect
let captainStripFrame: CGRect
let rallyHitFrame: CGRect
```

Derive them from `deployFrame` in both compact/reference branches:

```text
captainStripWidth = 132
gap = 8
deployActionFrame = remaining left width
rallyHitFrame = rightmost 44pt of captainStripFrame
minimum deployActionFrame width = 196
```

Guard:

- all three frames finite/positive;
- contained in `deployFrame`;
- pairwise non-overlapping;
- Rally hit >=44×44;
- Deploy action width >=196;
- otherwise `compute` returns nil through the existing layout-gate path.

At the narrowest 375pt fixture, content/deploy width is 343: 343 - 132 - 8 = 203, so this contract is intentionally feasible.

### 4.2 City 1–2 remain visually unchanged

The layout computes the subframes for every scene, but City 1–2 ignore them:

- current centered Deploy cluster stays inside full `deployFrame`;
- current full `deployFrame` hit target stays intact.

City 3+:

- render current Deploy cluster inside `deployActionFrame`;
- render Captain/Rally strip inside `captainStripFrame`;
- `.deploy` maps only to `deployActionFrame`;
- `.rally` maps only to `rallyHitFrame`.

No overlap means no “check Rally before Deploy” rule.

### 4.3 Extend BattleHUDContent with transient Rally view state

`BattleHUDContent` remains in `BattleHUDNode.swift`.

Its projection accepts:

```text
captainIsDeployed
rallyRemainingSeconds
```

plus durable `KingdomGameState.siegeProgress.captain`.

Project compact state:

```text
unavailable
ready(currentHP,maxHP,rallyReady)
active(currentHP,maxHP)
used(currentHP,maxHP)
recovering(seconds,rallyConsumed)
```

No new domain state owner.

### 4.4 Pure geometry/UI tests

At 375×667, 393×852, portrait iPad:

- subframes contained/disjoint;
- Rally >=44;
- Deploy >=196;
- layout fails closed on an artificially too-narrow width;
- City 1/2 apply path still centered/full Deploy;
- City 3+ Rally point returns `.rally`, Deploy point returns `.deploy`;
- Captain status copy fits its strip;
- Active requires live timer > 0; durable consumed + zero timer shows Used.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleChromeLayoutTests \
  -only-testing:PyxisTests/BattleHUDContentTests \
  -only-testing:PyxisTests/BattleHUDNodeTests
```

**Gate:** the interaction geometry is structurally non-overlapping before BattleScene integration.

## Task 5 — Wire scene restore/sibling persistence, Rally activation, animation, and feedback

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`

### 5.1 RED: durable reconstruction + live-only recovery

Pin:

- City 2 scene has no Captain;
- City 3 scene restores exactly one flagged Captain from durable lane + HP;
- lane-chip tap does not move live Captain;
- Battle -> Camp/Map -> Battle restores persisted lane + HP;
- background teardown/foreground restore preserves lane + HP;
- recovering Captain restores no live actor;
- Camp/Map/background time does **not** reduce recovery;
- live `advanceCombat` reduces recovery by clamped combat delta;
- recovery completion restores current max HP, adopts current selected lane, and spawns exactly one Captain.

### 5.2 Restore through the existing Soldier roster

At scene init / foreground convergence, after `makeCombat`:

- restore HPA-469 Guards as today;
- if Captain progress is deployable, call `combat.spawnCaptain`;
- if recovering, spawn none.

No Captain node bundle: `syncSoldierNodes` discovers the flagged Soldier.

### 5.3 Partition ordinary report events; keep ordinary conquest guard narrow

`applyCombatResult` may make only the minimal identity partition:

```swift
let ordinaryAttacks = result.soldierAttacks.filter { !$0.isCaptain }
let ordinaryLosses = result.soldierLosses.filter { !$0.isCaptain }
```

Use those for:

- `recordSoldierLosses`;
- `applyLiveSoldierAttacks`;
- ordinary objective/report feedback.

Keep its ordinary `guard !ordinaryAttacks.isEmpty` behavior. Do **not** widen it to Captain conditions.

### 5.4 Add sibling `synchronizeAndPersistCaptain`

Call after `applyCombatResult(result)` and beside the Guard sibling:

```text
feedback.emitAutomaticCombat(result)
applyCombatResult(result)
synchronizeAndPersistCaptain(result, deltaTime: clampedDeltaTime)
synchronizeAndPersistHighcrestGuards(deltaTime: clampedDeltaTime)
```

Captain sibling:

1. apply `result.soldierAttacks.filter(\.isCaptain)` to objectives through `state.applyObjectiveDamage`;
2. if a Captain loss exists and stage is still active, `recordCaptainRetreat`;
3. otherwise sync the live flagged soldier's lane + HP;
4. if no live Captain and still active/recovering, advance recovery with clamped live delta;
5. if recovery completes, spawn one Captain from the newly durable state;
6. save immediately for HP change, retreat, objective damage, Rally consume, or recovery completion;
7. recovery-countdown-only state participates in the existing two-second progress-save cadence;
8. if Captain objective damage completes the Keep, use the newly created `pendingBattleResult` to call the existing fresh-live outcome/report helpers exactly once—no second reward calculation/model.

### 5.5 One Rally activation funnel

```swift
private func activateRally()
```

Order:

1. find live flagged Captain, capture its durable lane;
2. `guard state.consumeVanguardRally() else { return }`;
3. save consumed bit;
4. `combat.startRally(lane: captain.lane)`;
5. emit existing feedback/redraw.

Both `BattleHUDNode.Action.rally` and `result.shouldAutoActivateRally` call it.

Auto call occurs after the current tick; next tick is the first protected tick.

### 5.6 Reuse soldier nodes/animation, no parallel visual runtime

`createSoldierNode` / `syncSoldierNodes` keep owning every allied actor.

Parameterize existing asset lookup/probe by an asset prefix:

- ordinary -> current `SoldierType.rawValue`;
- Captain -> `vanguard-captain`.

Stable contracts:

```text
vanguard-captain-portrait
vanguard-captain-resting
vanguard-captain-walk-01...10
vanguard-captain-attack-01...10
vanguard-captain-hit-01...10
rally-icon
rally-protection-accent
```

No generated assets in HPA-475. Missing/partial Captain trio -> static/procedural Captain fallback. Complete HPA-476 trio -> existing walk/attack/hit player.

### 5.7 Existing automatic sounds

Because Captain uses existing events:

- Captain structure attack (`SoldierAttackEvent(type: .infantry, isCaptain: true)`) already maps to melee;
- Captain hitting Guard already maps from GuardHitEvent infantry type;
- tower hit already maps from TowerShot;
- Guard attack already contributes melee.

Only adjust ordinary death selection so `SoldierLossEvent.isCaptain == true` does not emit `.soldierDeath` or ordinary loss reporting.

No new SFX IDs/assets.

### 5.8 Scene/lifecycle gate

Pin:

- damaged active HP/lane survives Camp/Map/background reconstruction;
- recovery pauses outside Battle and resumes inside Battle;
- Captain-only Barracks/Keep attack persists through sibling despite ordinary `soldierAttacks` partition;
- Captain-only Keep kill gets one reward + one `.freshLive` report;
- Captain loss never enters report losses / soldierDeath SFX;
- manual cap/navigation lock still ignore Captain;
- manual Rally and automatic fallback share one consume path and cannot double-trigger;
- active Rally reconstruction loses timer but stays Used;
- compact/reference/iPad scene smoke keeps Settings/tabs/lane chips/report intact.

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests
```

**Gate:** full feature works through reused Soldier + pure layout + sibling persistence, with settlement code untouched.

## Task 6 — Tune only bounded numbers and finish evidence

**Files:** source/tests only if a bounded tuning value changes; otherwise PR body evidence.

### 6.1 Deterministic comparison

Using the exact shipped HPA-469 setup from Task 0 (seed 1, 1/60 tick, right/exposed, no manual spawns, Barracks L2/L1 + Archery L1, soldier level 1), compare production behavior:

1. **watch-only:** never press Rally; ticket-required auto fallback may consume it;
2. **manual:** invoke the same production Rally action at a deterministic pre-threshold combat point while the relevant ordinary soldier is still >=50% HP, so manual consumption wins before auto.

Keep auto enabled in both cases. Keep 567.62s / 158 ordinary-soldier losses as the pre-Captain reference; do not substitute a new camp or add a benchmark-only “disable auto” rule.

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
- Camp/Map/background reconstruction retaining persisted lane + HP and pausing recovery;
- live recovery completion redeploying in the new selected lane;
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
Pyxis/Country1CityCatalog.swift
Pyxis/KingdomGameState.swift
Pyxis/BattleCombatState.swift
Pyxis/BattleChromeLayout.swift
Pyxis/BattleHUDNode.swift
Pyxis/BattleScene.swift
Pyxis/AutomaticCombatFeedbackScheduler.swift
```

Expected test files:

```text
PyxisTests/Country1CityCatalogTests.swift
PyxisTests/KingdomGameStateTests.swift
PyxisTests/KingdomGameStoreTests.swift
PyxisTests/BattleCombatStateTests.swift
PyxisTests/BattleChromeLayoutTests.swift
PyxisTests/BattleHUDContentTests.swift
PyxisTests/BattleHUDNodeTests.swift
PyxisTests/BattleSceneTests.swift
PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift
PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift
PyxisTests/ActiveSiegeLifecycleTests.swift
```

## Risks

1. **Transient Captain identity leakage.** `isCaptain` must be filtered at every count/report/death-SFX persistence seam; tests pin this boundary.
2. **375×667 Deploy packing.** Pure `BattleChromeLayout` owns fixed disjoint frames and fails closed; do not patch overlap in SpriteKit hit-test ordering.
3. **Manual-vs-auto Rally reachability.** Auto is a Linear requirement, so Task 6 must demonstrate a real manual pre-threshold activation under production rules. If it cannot, record product evidence and revise the ticket rather than silently deleting auto.
4. **Captain-only conquest.** The sibling path must reuse the existing pending-result/fresh-live presenter exactly once without duplicating reward/report attribution.



Explicitly **not expected**:

```text
BattleResultModels schema changes
new hero/ability/effect framework files
new persistence repository
new offline simulator
new art or SFX files
new Linear child tickets
```
