# HPA-469 Highcrest Barracks + Guard Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Highcrest's one-Barracks / finite-Guard reinforcement pilot while preserving HPA-468's siege model, Keep-only conquest semantics, and single live combat simulator.

**Architecture:** Extend the existing siege value types with one Barracks objective kind and minimal Guard persistence. `KingdomGameState` owns one O(1) durable wave clock/reserve and reuses the existing `applyAbstractBuildingSpawnDamage` seam for approximate idle/Camp resolution. `BattleCombatState` remains the only live actor simulator; `BattleScene.advanceCombat` owns integration, persistence, and procedural placeholders.

**Tech Stack:** Swift 5, Swift Testing, SpriteKit/UIKit, existing `KingdomGameStore` JSON persistence, Xcode/xcodebuild, SwiftLint.

**Spec:** `docs/superpowers/specs/2026-09-16-highcrest-barracks-guard-pilot-design.md`

## Global Constraints

- One implementation PR for HPA-469; do not split foundation, persistence, combat, UI, art, or QA into child PRs.
- Keep HP remains the only conquest/liveness authority.
- Starting reinforcement contract: 2 Guards / 6 seconds, 8 reserve globally (superseded — shipped: 30 seconds / 12 reserve; see Task 1 Step 4 shipped-tuning notes). There is no active-Guard cap.
- New Guards use the currently selected assault lane; existing Guards keep their assigned lane.
- New/restored Guards start at Keep progress and may not move below the authored Barracks progress.
- Soldiers and Guards use their own attack ranges independently; do not collapse combat to one shared contact distance.
- Barracks destruction prevents future spawns but does not delete living Guards.
- Keep existing 8-hour idle cap, 1/10 player building-production rate, no-buildings/no-progress behavior, at-most-one-city conquest, and exactly-once report/reward behavior.
- Reuse `applyAbstractBuildingSpawnDamage`; do not add a chronological building-production walker.
- Preserve tower-first ordering inside `BattleCombatState.tick`; do not rewrite combat as a generic phase engine.
- Guard-only ticks must persist Guard HP/wave state and participate in existing automatic combat feedback.
- Guard positions remain transient; persist lane + HP only.
- No save migration, generic wave engine, enemy-AI framework, target registry, pathfinder, physics, new reward system, or generated art.
- HPA-476 owns final `siege-barracks` / `siege-guard` art and animation production.
- Run tests with parallel testing disabled.

---

### Task 0: Capture the pre-pilot Highcrest baseline

**Files:**
- Update PR body evidence only; no source file changes.

**Interfaces:**
- Produces the current-`main` reference used by Task 6 balance decisions.

- [ ] **Step 1: Check out the exact implementation base in a clean worktree.**

Use `main` at:

```text
76f5e6b836acab5e48f6c27ab107049e1811ba18
```

Do not use the HPA-469 branch for this measurement.

- [ ] **Step 2: Use one deterministic representative camp/loadout.**

Use the same fixed seed, buildings, building levels, soldier upgrade level, and manual-spawn policy that will be used for final HPA-469 comparisons. Record those inputs in the PR body before implementation starts.

- [ ] **Step 3: Record the current City 5 result.**

Capture:

```text
elapsed to conquest
allied losses
seed
camp/loadout
```

This is the single-Keep Highcrest reference. No commit is required for measurement-only evidence.

---

### Task 1: Extend siege authoring, normalization, and Scout copy

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `PyxisTests/SiegeStateTests.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Modify: `PyxisTests/SiegeTestSupport.swift`

**Interfaces:**
- Produces `CitySiegeLayout.ObjectiveKind.barracks`.
- Produces `CitySiegeLayout.barracksObjective: Objective?` with an at-most-one authored invariant.
- Produces top-level `HighcrestGuardRules` in `Country1CityCatalog.swift`.
- Produces `GuardSnapshot`, `GuardReinforcementProgress`, and `SiegeProgress.guardReinforcements` in `SiegeState.swift`.
- Highcrest authoring produces `highcrest.keep` and `highcrest.barracks` with 20:1 weights and left Barracks-first route.
- `normalizedSiegeProgress` preserves/clamps Highcrest reinforcement state and forces non-Highcrest state to `nil`.
- Scout tactical copy produces `L Barracks` from authored route membership.

- [ ] **Step 1: Add failing catalog/Scout tests.**

```swift
@Test func highcrestAuthorsKeepAndBarracksPilot() {
    let definition = Country1CityCatalog.definition(for: 5)
    let layout = definition.siegeLayout
    let maxPower = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))

    #expect(layout.defaultLane == .right)
    #expect(layout.routes[.left] == ["highcrest.barracks", "highcrest.keep"])
    #expect(layout.routes[.center] == ["highcrest.keep"])
    #expect(layout.routes[.right] == ["highcrest.keep"])
    #expect(layout.barracksObjective?.id == "highcrest.barracks")
    #expect(maxPower["highcrest.keep"] == 407)
    #expect(maxPower["highcrest.barracks"] == 20)
}

@Test func highcrestScoutTeachesBarracksRoute() {
    let layout = Country1CityCatalog.definition(for: 5).siegeLayout
    #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L Barracks")
}
```

Also assert defensive fire remains sourced from `highcrest.keep` across all lanes, and pin compact Scout presentation above the existing fail-closed font floor.

- [ ] **Step 2: Run the focused tests and verify failure.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

Expected: FAIL because `.barracks`, Highcrest custom layout, and Barracks Scout copy do not exist.

- [ ] **Step 3: Add generic siege persistence types in `SiegeState.swift`.**

```swift
struct GuardSnapshot: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
}

struct GuardReinforcementProgress: Codable, Equatable {
    var waveElapsedSeconds: Double
    var remainingReserve: Int
    var unresolvedGuards: [GuardSnapshot]
}
```

Add `.barracks`, optional `barracksObjective`, and `guardReinforcements` on `SiegeProgress`. Keep stable IDs and every existing route invariant. Add a fail-closed precondition that an authored layout contains at most one `.barracks`.

- [ ] **Step 4: Put Highcrest-only tuning beside Highcrest authoring.**

In `Country1CityCatalog.swift`, near City 5:

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 6.0
    static let totalReserve = 8
    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}
```

**Shipped tuning differs (HPA-469 Task 6):** balance evidence tuned `waveIntervalSeconds` from the 6.0 starting value above to **20.0** — at 6.0s the whole reserve deployed by t = 24s, so Barracks shutdown canceled nothing and waves never met a standing army.

**Shipped tuning differs again (2026-09-19 route-balance pass):** the route-dominance retune shipped `waveIntervalSeconds` **30.0**, `totalReserve` **12**, `attackRange` **0.28**, keep durability weight **20** (20:1 weights, 407/20 of the 427 budget), Barracks `visualProgress` **0.72**, and the City 5 lane profile flipped to `LaneDefenseProfile(fortifiedLane: .center, exposedLane: .right)`. The 6.0→20.0 note above remains the Task 6 rationale; the 20.0/8 starting values themselves were superseded. See the design spec's shipped-value notes for the final rationale. `guardsPerWave`, `maxHP`, `attackPower`, `attackSpeed`, `movementSpeed` shipped unchanged.

Do not put these City 5 tuning values in generic `SiegeState.swift`.

- [ ] **Step 5: Author Highcrest.**

```swift
siegeLayout: CitySiegeLayout(
    objectives: [
        // Route-balance pass shipped the keep weight as 20 and the Barracks
        // progress as 0.72 (starting values below were 4 and 0.62).
        .init(id: "highcrest.keep", kind: .keep, durabilityWeight: 4,
              visualLane: .center, visualProgress: 1.0),
        .init(id: "highcrest.barracks", kind: .barracks, durabilityWeight: 1,
              visualLane: .left, visualProgress: 0.62)
    ],
    routes: [
        .left: ["highcrest.barracks", "highcrest.keep"],
        .center: ["highcrest.keep"],
        .right: ["highcrest.keep"]
    ],
    defaultLane: .right,
    defensiveFire: .init(sourceObjectiveID: "highcrest.keep", coveredLanes: BattleLane.allCases)
)
```

Update the stale `CityDefinition.siegeLayout` comment so it describes authored tactical layouts rather than naming Falconridge as the only one.

- [ ] **Step 6: Extend `normalizedSiegeProgress`.**

Fresh Highcrest gets:

```swift
GuardReinforcementProgress(
    waveElapsedSeconds: 0,
    remainingReserve: HighcrestGuardRules.totalReserve,
    unresolvedGuards: []
)
```

Normalize Highcrest by:

```text
reserve -> 0...12
waveElapsedSeconds -> 0..<30
Guard HP -> 1...12
unresolvedGuards -> first 12 valid snapshots
remainingReserve -> at most 12 - unresolvedGuards.count
```

Preserve Guard lanes and Barracks-destroyed survivors. Non-Highcrest cities normalize reinforcement progress to `nil`. Do not persist IDs or positions and do not add save versioning.

- [ ] **Step 7: Add round-trip tests.**

Round-trip a Highcrest save containing:

```text
waveElapsedSeconds = 4.5
remainingReserve = 3
left Guard = 5 HP
right Guard = 9 HP
```

Assert exact lane/HP/phase/reserve preservation. Also prove malformed values clamp and non-Highcrest reinforcement progress is removed.

- [ ] **Step 8: Add the exhaustive Scout enum case.**

```swift
case .barracks: return "Barracks"
```

Keep lane letters derived from routes; do not hard-code `L Barracks` in the view.

- [ ] **Step 9: Run focused suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests

git add Pyxis/SiegeState.swift Pyxis/Country1CityCatalog.swift Pyxis/CityDefinition.swift \
  Pyxis/KingdomGameState.swift Pyxis/CountryMapScoutCardContent.swift \
  PyxisTests/SiegeStateTests.swift PyxisTests/Country1CityCatalogTests.swift \
  PyxisTests/KingdomGameStateTests.swift PyxisTests/KingdomGameStoreTests.swift \
  PyxisTests/CountryMapScoutCardContentTests.swift \
  PyxisTests/CountryMapScoutCardAcceptanceTests.swift PyxisTests/SiegeTestSupport.swift
git commit -m "feat: author Highcrest Guard siege state"
```

---

### Task 2: Add finite waves and reuse the existing abstract settlement seam

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**
- Consumes `GuardReinforcementProgress`, `HighcrestGuardRules`, and `CitySiegeLayout.barracksObjective`.
- Produces `advanceActiveGuardReinforcements(deltaTime:) -> [GuardSnapshot]` with O(1) due-opportunity arithmetic.
- Produces `synchronizeLiveGuardSnapshots(_:) -> Bool` for live persistence.
- Extends existing `applyAbstractBuildingSpawnDamage(_:elapsedSeconds:conquestMode:)`; no new settlement walker is introduced.

- [ ] **Step 1: Add failing active-wave tests.**

Pin:

```text
29.9s -> 0 Guards, reserve 12, phase 29.9
+0.1s -> 2 Guards on selected lane, reserve 10, phase 0
+30.0s -> 2 more Guards, reserve 8
+120.0s -> final 8 Guards, reserve 0
later time -> no additional Guards
Barracks dead -> no additional Guards
Keep dead -> no additional Guards
```

Switch lanes before one wave and assert only newly created Guards use the new lane while earlier snapshots keep theirs.

- [ ] **Step 2: Implement the O(1) scheduler.**

```swift
let totalElapsed = progress.waveElapsedSeconds + max(0, deltaTime)
let dueOpportunities = Int(totalElapsed / HighcrestGuardRules.waveIntervalSeconds)
progress.waveElapsedSeconds = totalElapsed.truncatingRemainder(
    dividingBy: HighcrestGuardRules.waveIntervalSeconds
)
let spawnCount = min(
    progress.remainingReserve,
    dueOpportunities * HighcrestGuardRules.guardsPerWave
)
```

Append exactly `spawnCount` full-HP snapshots on `siegeProgress.selectedLane` and subtract exactly that reserve. Do not add active-cap, queue, or blocked-wave branches.

- [ ] **Step 3: Add live Guard snapshot synchronization.**

```swift
@discardableResult
mutating func synchronizeLiveGuardSnapshots(_ snapshots: [GuardSnapshot]) -> Bool
```

For active Highcrest, normalize incoming lane/HP snapshots with the same 12-total limit as decode, compare with persisted `unresolvedGuards`, replace them, and return whether durable state changed. Other cities return `false`.

- [ ] **Step 4: Add failing abstract-settlement tests for both callers.**

Cover background idle and a Camp build/upgrade settlement. Pin:

- due window Guards are materialized before abstract player damage;
- oldest same-lane Guard HP absorbs each building spawn's damage before structure damage;
- Guard damage is not recorded as city damage;
- Barracks already dead at window start creates no new Guards;
- no player buildings means no Guard-wave advancement;
- direct-route settlement can conquer Keep while Barracks remains alive;
- at-most-one-city conquest and exactly-once reward/report stay unchanged.

- [ ] **Step 5: Extend `applyAbstractBuildingSpawnDamage`, not production timing.**

Change the signature to:

```swift
private mutating func applyAbstractBuildingSpawnDamage(
    _ spawns: [BuildingSpawn],
    elapsedSeconds: Double,
    conquestMode: BattleConquestMode
) -> (applied: Int, conquered: Bool, goldEarned: Int)
```

When the current city has player buildings, call:

```swift
_ = advanceActiveGuardReinforcements(deltaTime: elapsedSeconds)
```

once before iterating `spawns`.

For each `BuildingSpawn`:

1. compute the existing trait-adjusted `power`;
2. spend that budget against oldest unresolved Guards on `siegeProgress.selectedLane` first;
3. remove dead Guard snapshots and retain partial HP;
4. pass only leftover power to `currentSiegeLayout.spendDamageBudget`;
5. record only structure-applied damage in `ActiveSiegeSession.recordIdleDamage` and `appliedTotal`.

Do not calculate building spawn timestamps or duplicate `resolveBuildingSpawns` timing math.

- [ ] **Step 6: Update both existing callers with their already-known elapsed window.**

`settleCurrentCityBuildingProgress(at:)` passes its capped `elapsedSeconds`.

`resolveCurrentCityBuildingIdleProgress(at:)` passes `Double(elapsedSeconds)`.

If `occupiedSlotCount == 0`, preserve the current no-buildings/no-progress behavior and never advance Guard waves in isolation. If buildings exist but `spawns` is empty, still call the abstract damage seam so Guard phase advances consistently for that credited settlement window.

- [ ] **Step 7: Pin live-to-settlement time ownership.**

Add a lifecycle test:

1. seed Highcrest with at least one player building;
2. advance live Guard wave phase in Battle-equivalent state;
3. call `markCurrentCityBuildingProgressInactive(at:)` at the transition time;
4. settle a later Camp/Map window;
5. assert only the post-transition elapsed interval advances Guard phase.

Also pin the no-building variant: settlement does not advance Guard phase at all.

- [ ] **Step 8: Run focused suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests

git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift \
  PyxisTests/ActiveSiegeLifecycleTests.swift PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: settle finite Highcrest Guard waves"
```

---

### Task 3: Extend `BattleCombatState` with bounded lane-local Guards

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`

**Interfaces:**
- Consumes `GuardSnapshot`, `HighcrestGuardRules`, and `CitySiegeLayout.barracksObjective`.
- Produces transient `GuardID`, `Guard`, restore/spawn helpers, `guardSnapshots`, and Guard attack/hit/loss events.
- New/restored Guard position is Keep progress; Guard downward movement is clamped at Barracks progress.
- `tick(deltaTime:siege:)` remains the only live combat tick and keeps the existing tower-first block.
- `GuardHitEvent` carries the attacking `SoldierType`.

- [ ] **Step 1: Write failing Guard-combat tests.**

Pin:

- restored 5-HP Guard keeps lane/HP but starts at Keep progress;
- a right-lane soldier already at `0.80` still meets a later Keep-spawned Guard;
- Guard never moves below `highcrest.barracks` progress;
- soldier and Guard movement never cross;
- Guard attacks only the foremost soldier in its lane;
- Guard never targets another lane or player castle;
- dead Guard emits one loss and survivors resume structure targeting;
- living Guard still functions after Barracks destruction;
- Keep destruction wins immediately without Guard cleanup;
- empty Guard roster preserves existing HPA-468 tower/movement/attack behavior.

- [ ] **Step 2: Add the smallest transient Guard actor.**

```swift
typealias GuardID = Int

struct Guard: Equatable, Identifiable {
    let id: GuardID
    let lane: BattleLane
    let maxHP: Int
    var currentHP: Int
    var position: Double
    var attackCooldownRemaining: Double
}
```

Add one Guard array and next-ID counter. Do not add an enemy protocol/base class.

- [ ] **Step 3: Add restore/spawn/snapshot helpers.**

Restore/spawn receives the current `SiegeSnapshot` and starts at:

```swift
snapshot.layout.keepObjective.visualProgress
```

The movement floor is derived from:

```swift
snapshot.layout.barracksObjective?.visualProgress ?? 0
```

`guardSnapshots` returns living lane + clamped HP only; position remains transient.

- [ ] **Step 4: Preserve independent attack ranges.**

For each soldier/Guard pair:

- soldier movement stops once distance is within `soldier.attackRange`;
- Guard movement continues while distance exceeds `HighcrestGuardRules.attackRange`, subject to the Barracks floor and no-cross clamp;
- soldier may attack as soon as its own range is satisfied;
- Guard may attack only when its own range is satisfied.

Add per-type tests for Infantry, Archer, Cavalry, Mage, and Siege. In particular, prove Archer/Mage/Siege can emit an attack before a still-closing Guard can retaliate.

- [ ] **Step 5: Insert Guard combat without moving the tower block.**

Keep existing defensive-fire resolution first. After that:

1. resolve lane-local blockers;
2. move soldiers/Guards under the independent-range rules;
3. resolve living Guard attacks;
4. resolve still-living soldier attacks against Guard blocker first, otherwise structure;
5. prune dead actors and emit events.

Do not add a phase framework and do not move tower targeting after actor movement.

- [ ] **Step 6: Add the required TickResult events.**

```swift
struct GuardAttackEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

struct GuardHitEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let type: SoldierType
    let appliedDamage: Int
}

struct GuardLossEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let lane: BattleLane
}
```

Guard hits must not become `SoldierAttackEvent` or battle-report city damage. Guard-caused allied damage/death continues through `damagedSoldierIDs` / `soldierLosses`.

- [ ] **Step 7: Reuse the existing sound mapping precisely.**

In `AutomaticCombatFeedbackScheduler.candidates(from:)`:

- non-empty `guardAttacks` may add existing `.attackMelee`;
- map each `guardHits.type` through existing `attackSound(for:)`;
- do not add `.soldierHit` from `guardHits` because that event means the Guard was hit;
- keep current `damagedSoldierIDs` / `soldierLosses` handling for Guard-caused allied hit/death.

Add tests with empty `soldierAttacks` proving an Archer Guard hit yields `.attackRanged`, a Siege hit yields `.attackSiege`, and a Guard attack yields `.attackMelee`.

- [ ] **Step 8: Run focused combat/feedback suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleCombatStateTests \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests

git add Pyxis/BattleCombatState.swift Pyxis/AutomaticCombatFeedbackScheduler.swift \
  PyxisTests/BattleCombatStateTests.swift PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift
git commit -m "feat: add lane-local enemy Guard combat"
```

---

### Task 4: Integrate Guard persistence and procedural presentation in `BattleScene`

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BattleSceneCoverageTests.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`

**Interfaces:**
- Consumes `synchronizeLiveGuardSnapshots`, `advanceActiveGuardReinforcements`, Guard combat restore/spawn/snapshot helpers, and Guard TickResult events.
- Extends existing `SiegeObjectiveAssetContract` with `barracks = "siege-barracks"`.
- Produces procedural `siege-barracks` / `siege-guard` placeholders only; final art remains HPA-476.

- [ ] **Step 1: Add failing integration tests.**

Pin:

- persisted 5-HP Guard reconstructs at Keep progress without healing;
- Battle -> reconstruction deliberately resets position to Keep progress;
- a tick where allies only damage a Guard updates `SiegeProgress` even when `result.soldierAttacks.isEmpty`;
- Guard wave elapsed persists through the existing two-second save cadence even with no player buildings;
- Barracks destroyed in the current combat tick prevents a same-frame wave;
- non-pilot city creates no Guard/Barracks nodes.

- [ ] **Step 2: Restore Guards after creating combat.**

Read `state.siegeProgress.guardReinforcements?.unresolvedGuards` and restore each through the Task 3 helper using `state.currentSiegeSnapshot`. Do not reconstruct persisted IDs or positions.

- [ ] **Step 3: Keep Guard synchronization outside `applyCombatResult`'s structure-attack guard.**

After `applyCombatResult(result)` in `advanceCombat`:

```swift
let guardStateChanged = state.synchronizeLiveGuardSnapshots(combat.guardSnapshots)
let spawnedGuards = state.advanceActiveGuardReinforcements(
    deltaTime: combat.clampedDeltaTime(deltaTime)
)
for snapshot in spawnedGuards {
    combat.restoreGuard(snapshot, siege: state.currentSiegeSnapshot)
}
```

If Keep conquest changed stage out of `.battleActive`, skip wave advancement.

- [ ] **Step 4: Broaden the existing progress-save throttle.**

Generalize `buildingProgressSaveAccumulator` / `buildingProgressSaveInterval` only enough that the existing two-second cadence runs when either:

```text
player building progress is active
OR
Highcrest Guard reinforcement progress is active
```

Keep immediate saves when Guard snapshots change, Guards spawn/die, or structure state mutates. Do not save every frame and do not add a second timer.

- [ ] **Step 5: Preserve final frame order.**

```text
record active time
resolve/spawn player building units
maintain existing persistence throttle
combat.tick (tower-first inside tick)
feedback.emitAutomaticCombat(result)
applyCombatResult(result)
synchronize living Guard snapshots
advance due waves with combat-clamped delta
restore new Guards into combat
persist changed Guard state
sync soldier + Guard nodes / HUD
```

- [ ] **Step 6: Extend the existing asset contract and structure builder.**

Add:

```swift
static let barracks = "siege-barracks"
```

Reuse the existing siege structure/HP/ruin helpers for the authored Barracks objective. Render `GUARDS N` while active/reserve remains and `SHUT DOWN` after Barracks death.

- [ ] **Step 7: Add structurally distinct Guard placeholders.**

Use a helmet/head + shield/body composition and enemy-facing orientation; do not rely only on tint. Map Guard attack/hit/loss events to short observational actions. Model timing remains authoritative.

Document the HPA-476 runtime handoff beside the existing contract:

```text
siege-barracks — bottom-center — intact, ruined/disabled
siege-guard    — feet/bottom-center — resting, walk, attack, hit
```

- [ ] **Step 8: Re-pin City 5 Forged fixtures.**

Add capture states for active wave, damaged Guard, Barracks shutdown with surviving Guard, and final advance. Re-run existing City 5 Camp/Forged fixtures because Highcrest now has a custom layout; fix their assumptions instead of adding another fixture framework.

- [ ] **Step 9: Run focused scene suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BattleSceneCoverageTests \
  -only-testing:PyxisTests/ForgedVisualFixtureTests

git add Pyxis/BattleScene.swift Pyxis/ForgedVisualFixture.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/BattleSceneCoverageTests.swift \
  PyxisTests/ForgedVisualFixtureTests.swift
git commit -m "feat: present Highcrest Barracks and Guards"
```

---

### Task 5: Prove lifecycle reconstruction and non-pilot regressions

**Files:**
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/DevJumpStateTests.swift`

**Interfaces:**
- No new production abstraction is introduced here. This task closes lifecycle/routing regressions around the APIs from Tasks 1–4.

- [ ] **Step 1: Add the save/reload regression sequence.**

Seed:

```text
waveElapsedSeconds = 4.5
remainingReserve = 3
left Guard = 5 HP
right Guard = 9 HP
Barracks damaged but alive
```

Round-trip through `KingdomGameStore`, reconstruct Battle, and assert durable values remain exact while transient Guard IDs/positions are recreated at Keep progress.

- [ ] **Step 2: Pin tab/Camp/Map lifecycle.**

Prove:

- leaving Battle and returning cannot heal Guards, refill reserve, or restart phase;
- Guard position reset to Keep is deliberate and does not change lane/HP;
- live Battle wave time before `markCurrentCityBuildingProgressInactive` is not re-walked by the following settlement window;
- Camp build/upgrade and background return both use the same abstract damage seam;
- settlement conquest still routes through the pending Battle result exactly once.

- [ ] **Step 3: Pin one non-pilot city.**

Use City 1 or 2:

```text
guardReinforcements == nil
no Guard scheduler work
HPA-468 selected-lane spawn/objective combat unchanged
tower ordering unchanged
existing conquest/report flow unchanged
```

- [ ] **Step 4: Re-smoke City 5 dev-jump/fixture materialization.**

Verify fresh DEBUG jump to City 5 creates normalized Highcrest Barracks/Guard progress without migration or special checkpoint code.

- [ ] **Step 5: Run broad affected suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/ActiveSiegeLifecycleTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests \
  -only-testing:PyxisTests/DevJumpStateTests

git add PyxisTests/KingdomGameStoreTests.swift PyxisTests/ActiveSiegeLifecycleTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift PyxisTests/DevJumpStateTests.swift
git commit -m "test: lock Highcrest Guard lifecycle"
```

---

### Task 6: Balance, gameplay evidence, and final gates

**Files:**
- Potentially modify: `Pyxis/Country1CityCatalog.swift` only if the evidence gate requires Highcrest-local retuning.
- Modify matching exact-value tests when a tuning value changes.
- Update PR body with final evidence.

- [ ] **Step 1: Run the baseline camp/loadout on right / standard direct.**

Use the exact Task 0 seed/loadout. Record:

```text
elapsed to Keep conquest
allied losses
Guards spawned
Guards defeated
Barracks remaining HP
```

Capture a later wave intercepting an army whose foremost soldier has already passed the Barracks (shipped progress `0.72`).

- [ ] **Step 2: Run the same camp/loadout on the left Barracks-first route (shipped lane role: standard).**

Record the same fields plus Barracks shutdown time. Prove no Guard appears after Barracks shutdown despite additional elapsed wave time.

- [ ] **Step 3: Smoke center as the deliberate hard lane.**

Do not treat center as a parity target. Confirm only that its direct route functions and retains the existing fortified `1.25x` incoming tower pressure versus left's standard `1.0x` and right's exposed `0.8x` (lane roles shipped by the 2026-09-19 route-balance pass).

- [ ] **Step 4: Apply the narrow retune gate.**

Retune only when:

```text
one route is an obvious free choice on both elapsed time and losses
OR both routes stall unreasonably
OR Barracks shutdown has no visible consequence
OR the starting contract's 8 Guards deploying by t=24s is too steep for the representative camp
```

Allowed knobs, in order:

1. Highcrest objective weights;
2. `HighcrestGuardRules.totalReserve`;
3. `HighcrestGuardRules.waveIntervalSeconds`;
4. existing local Guard HP/damage/speed numbers.

Do not add an active cap, another structure, enemy type, ability, wave framework, or reward as the first balance response.

- [ ] **Step 5: Capture presentation evidence.**

Capture real running gameplay at:

- existing 393x852 reference;
- one compact supported phone;
- portrait iPad.

Show direct-route late-wave intercept, active Barracks pressure, Barracks shutdown, surviving Guard after shutdown, final Keep conquest, and one non-pilot city. Verify Settings/tabs/assault flag/Spawn controls/objective HP/conquest report remain unobstructed.

- [ ] **Step 6: Run full gates.**

```bash
swiftlint lint

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' build

git diff --check main...HEAD
```

Keep the repository's existing coverage policy; do not weaken gates.

- [ ] **Step 7: Synchronize final shipped values.**

If evidence changes Highcrest weights or Guard constants, update the spec, this plan's starting/shipped-value notes, exact-value tests, Linear HPA-469 description, and PR body in the same final commit.

```bash
git add Pyxis PyxisTests docs/superpowers
git commit -m "balance: finalize Highcrest Guard pilot"
```

Skip this commit when no files changed.

---

## Review-risk checklist before implementation completion

- **Spawn-behind:** Guards spawn/restore at Keep progress; a direct-route soldier past the Barracks (shipped progress `0.72`) still intercepts later waves.
- **Spawn camping:** Guard downward movement clamps at authored Barracks progress.
- **Range identity:** soldiers and Guards use their own attack ranges; ranged types receive earlier attack opportunities while Guards continue closing.
- **Settlement duplication:** no chronological walker; both callers reuse `applyAbstractBuildingSpawnDamage`.
- **Guard-only save/feedback:** Guard HP and wave phase survive without structure hits; sound mapping preserves attacking SoldierType.
- **Live/settlement ownership:** `markCurrentCityBuildingProgressInactive` prevents already-counted live time from being credited again when buildings exist; no-buildings remains no-progress.
- **Closed enum/fixtures:** Scout `L Barracks`, `SiegeObjectiveAssetContract.barracks`, normalization, CityDefinition comments, and City 5 Forged fixtures are explicitly covered.
- **Transient position:** Guard position reset is intentional and symmetric with the existing transient allied combat roster; do not add Guard-only spatial persistence.
