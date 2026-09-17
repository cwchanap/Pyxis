# HPA-469 Highcrest Barracks + Guard Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Highcrest's one-Barracks / finite-Guard reinforcement pilot while preserving HPA-468's siege model, existing conquest semantics, and single-combat-simulator architecture.

**Architecture:** Extend the existing siege value types with one Barracks objective kind and Highcrest-local Guard persistence/tuning. `KingdomGameState` owns the durable wave phase/reserve plus one shared chronological building/Guard settlement helper; `BattleCombatState` remains the sole live actor simulator; `BattleScene.advanceCombat` owns live integration, persistence, and procedural placeholder presentation.

**Tech Stack:** Swift 5, Swift Testing, SpriteKit/UIKit, existing `KingdomGameStore` JSON persistence, Xcode/xcodebuild, SwiftLint.

**Spec:** `docs/superpowers/specs/2026-09-16-highcrest-barracks-guard-pilot-design.md`

## Global Constraints

- One implementation PR for HPA-469; do not split foundation, persistence, combat, UI, art, or QA into child PRs.
- Keep HP remains the only conquest/liveness authority.
- Exact starting wave contract: 2 Guards / 6 seconds, max 4 living Guards **per reinforced lane**, 8 reserve globally across the siege.
- Reserve is consumed only for Guards actually spawned; a cap-blocked wave does not queue a burst.
- New Guards use the currently selected assault lane; existing Guards keep their assigned lane.
- New/restored Guards start at Keep `visualProgress`, not Barracks `visualProgress`.
- Barracks destruction prevents future spawns but does not delete living Guards.
- Keep existing 8-hour idle cap, 1/10 player building-production rate, no-buildings/no-progress behavior, at-most-one-city conquest, and exactly-once report/reward behavior.
- Background idle and Camp/build-upgrade settlement share one private chronological resolver.
- Preserve tower-first ordering inside `BattleCombatState.tick`; do not rewrite combat as a generic phase engine.
- Guard-only ticks must persist Guard HP/wave state and participate in existing automatic melee/hit sounds.
- No save migration, generic wave engine, enemy-AI framework, target registry, pathfinder, physics, new reward system, or generated art.
- HPA-476 owns final `siege-barracks` / `siege-guard` art and animation production.
- Run tests with parallel testing disabled.

---

### Task 1: Extend siege authoring, normalization, and Scout copy

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/KingdomGameState.swift` at siege-progress initialization/normalization/Codable handling
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
- Produces `HighcrestGuardRules` with `maxActiveGuardsPerLane == 4` and the exact starting constants from the spec.
- Produces `GuardSnapshot`, `GuardReinforcementProgress`, and `SiegeProgress.guardReinforcements`.
- Highcrest authoring produces `highcrest.keep` and `highcrest.barracks` with 4:1 weights and left Barracks-first route.
- `normalizedSiegeProgress` materializes/preserves Highcrest reinforcement state and forces non-Highcrest state to `nil`.
- Scout tactical copy produces `L Barracks` from the authored route.

- [ ] **Step 1: Add failing Highcrest layout and Scout tests.**

Pin the real catalog rather than a duplicate test layout:

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
    #expect(maxPower["highcrest.keep"] == 342)
    #expect(maxPower["highcrest.barracks"] == 85)
}

@Test func highcrestScoutTeachesBarracksRoute() {
    let layout = Country1CityCatalog.definition(for: 5).siegeLayout
    #expect(CountryMapScoutCardContent.tacticalFooter(for: layout) == "L Barracks")
}
```

Also pin the existing defensive-fire source to `highcrest.keep` and add a compact Scout acceptance assertion proving `L Barracks` presents above the existing fail-closed font floor.

- [ ] **Step 2: Run focused tests and verify they fail.**

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

- [ ] **Step 3: Add the minimal authored Guard values.**

In `SiegeState.swift` add:

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 6.0
    static let maxActiveGuardsPerLane = 4
    static let totalReserve = 8
    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}

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

Add `.barracks`, optional `barracksObjective`, and `guardReinforcements` on `SiegeProgress`. Keep stable IDs and all existing route invariants. Add a fail-closed `precondition` that authored layouts contain at most one `.barracks`.

- [ ] **Step 4: Author Highcrest and fix stale model documentation.**

Use exactly:

```swift
siegeLayout: CitySiegeLayout(
    objectives: [
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

Update `CityDefinition.siegeLayout` comments so they describe authored tactical layouts rather than claiming Falconridge is the only custom-layout city.

- [ ] **Step 5: Extend `normalizedSiegeProgress` rather than reconstructing away Guard state.**

Fresh Highcrest uses:

```swift
GuardReinforcementProgress(
    waveElapsedSeconds: 0,
    remainingReserve: HighcrestGuardRules.totalReserve,
    unresolvedGuards: []
)
```

Normalize persisted Highcrest state by:

- clamping reserve to `0...8`;
- reducing elapsed into `0..<6`;
- clamping HP to `1...12`;
- retaining at most four Guards per lane and eight total, preserving order;
- preserving lanes;
- leaving Barracks-destroyed survivors intact;
- returning `nil` reinforcement progress for every non-Highcrest city.

Do not persist IDs or positions and do not add save versioning.

- [ ] **Step 6: Add round-trip and normalization tests.**

Pin that JSON/store round-trip preserves elapsed phase, remaining reserve, Guard lanes, and HP; loading cannot heal a 5-HP Guard, restore reserve from 3 to 8, or drop Highcrest reinforcement progress. Also prove non-Highcrest state normalizes to `nil`.

- [ ] **Step 7: Add the closed enum Scout case.**

In `CountryMapScoutCardContent.swift`:

```swift
case .barracks: return "Barracks"
```

Keep route membership as the source of `L`; do not hard-code Highcrest copy in the view.

- [ ] **Step 8: Run focused suites and commit.**

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

### Task 2: Add per-lane waves and one shared settlement path

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**
- Consumes `GuardReinforcementProgress`, `HighcrestGuardRules`, and `CitySiegeLayout.barracksObjective`.
- Produces `advanceActiveGuardReinforcements(deltaTime:) -> [GuardSnapshot]` using an O(1) due-opportunity calculation rather than looping every six-second boundary.
- Produces `synchronizeLiveGuardSnapshots(_:) -> Bool` to replace durable unresolved Guard lane/HP from the live simulator and report whether durable Guard state changed.
- Produces one private `resolveCurrentCityBuildingSettlement(...)` used by both current settlement callers.
- Keeps existing `resolveBuildingSpawns(in:effectiveActiveSeconds:)` as the only building-production mutation primitive.

- [ ] **Step 1: Add failing active-wave tests, including the lane-switch exploit.**

Pin:

```text
5.9s -> 0 Guards, reserve 8
+0.1s -> 2 right Guards, reserve 6
+6.0s -> 4 right Guards, reserve 4
+6.0s while right has 4 -> still 4 right, reserve 4
switch left with 4 right still alive, +6.0s -> 2 left Guards, reserve 2
blocked opportunities never consume reserve or queue >2 on the next opportunity
Barracks destroyed, +60s -> no new Guards and reserve unchanged
```

Also pin the review regression directly:

```swift
@Test func oldLaneCapDoesNotSuppressNewLaneWave() {
    // Seed four left Guards and reserve 8, select right, advance 6s.
    // Expect four left + two right, reserve 6.
}
```

Use the actual intended reserve fixture; do not infer reserve from living Guard count.

- [ ] **Step 2: Implement the live scheduler without iterating empty boundaries.**

For active Highcrest only:

```swift
let totalElapsed = progress.waveElapsedSeconds + max(0, deltaTime)
let dueOpportunities = Int(totalElapsed / HighcrestGuardRules.waveIntervalSeconds)
progress.waveElapsedSeconds = totalElapsed.truncatingRemainder(
    dividingBy: HighcrestGuardRules.waveIntervalSeconds
)
```

If Keep/Barracks is dead or reserve is zero, spawn none. Otherwise count unresolved Guards only on `siegeProgress.selectedLane` and compute:

```swift
let availableSlots = max(
    0,
    HighcrestGuardRules.maxActiveGuardsPerLane - livingOnSelectedLane
)
let opportunityCapacity = dueOpportunities * HighcrestGuardRules.guardsPerWave
let spawnCount = min(availableSlots, progress.remainingReserve, opportunityCapacity)
```

Append exactly `spawnCount` full-HP snapshots on the selected lane and subtract exactly that reserve. This collapses thousands of cap-blocked opportunities to arithmetic while preserving the six-second phase.

- [ ] **Step 3: Add live-snapshot synchronization.**

Add:

```swift
@discardableResult
mutating func synchronizeLiveGuardSnapshots(_ snapshots: [GuardSnapshot]) -> Bool
```

For active Highcrest, normalize the incoming lane/HP snapshots using the same per-lane/total limits as decode, compare with persisted `unresolvedGuards`, replace them, and return whether they changed. Other cities return `false`.

- [ ] **Step 4: Add failing tests proving both settlement callers share Guard semantics.**

Use deterministic building timers/dates to cover both:

- `resolveCurrentCityBuildingIdleProgress(at:)`;
- `settleCurrentCityBuildingProgress(at:)` reached through a build/upgrade mutation.

Pin:

- a wave due before a player production event exists when that event resolves;
- existing same-lane Guard HP absorbs production damage before structure damage;
- a full selected-lane cap does not burn reserve;
- repeated cap-blocked wave boundaries do not require iteration;
- Barracks death suppresses later waves;
- direct-route settlement can conquer Keep while Barracks remains alive;
- no buildings returns no progress and does not advance Guard phase;
- conquest remains at most one city and reward/report stay exactly once.

- [ ] **Step 5: Add one shared private chronological settlement helper.**

Both callers delegate to one helper shaped like:

```swift
private mutating func resolveCurrentCityBuildingSettlement(
    elapsedSeconds: Double,
    cityState: inout CityBattleState,
    conquestMode: ConquestMode
) -> (applied: Int, conquered: Bool, goldEarned: Int)
```

Do not add a public settlement type.

The event loop advances to the next **player building-production event** or capped end. Compute the next production delay from each building's existing `spawnTimerElapsed` and `activeSpawnInterval(for:)`; convert the effective-active delay back to real settlement seconds with `idleBuildingProductionScale`.

For each segment:

1. call `advanceActiveGuardReinforcements(deltaTime:)` with that segment's real elapsed time; the scheduler itself collapses cap-blocked six-second opportunities;
2. call `resolveBuildingSpawns(in:effectiveActiveSeconds:)` with `segment / idleBuildingProductionScale`;
3. for each returned `BuildingSpawn`, spend trait-adjusted damage against oldest unresolved Guards on `siegeProgress.selectedLane` first;
4. send only leftover damage to `currentSiegeLayout.spendDamageBudget(...)`;
5. stop immediately on Keep conquest;
6. once Barracks is dead, scheduler calls naturally produce no future Guards.

This is event-driven by real production work; it never walks 4,800 empty six-second slices.

- [ ] **Step 6: Preserve no-buildings and caller-specific bookkeeping.**

`resolveCurrentCityBuildingIdleProgress` keeps its `lastBackgroundedAt` clearing/result shape. `settleCurrentCityBuildingProgress` keeps build/upgrade timestamp semantics. If `occupiedSlotCount == 0`, preserve current no-buildings/no-progress behavior and do not advance Guard phase in isolation.

- [ ] **Step 7: Run focused state/lifecycle suites and commit.**

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

### Task 3: Extend `BattleCombatState` with fortress-spawned lane-local Guards

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift` only for concrete TickResult fixture compilation/behavior

**Interfaces:**
- Consumes `GuardSnapshot` and `HighcrestGuardRules`.
- Produces `GuardID`, transient `Guard`, restore/spawn helpers, `guardSnapshots`, and Guard attack/hit/loss events.
- New/restored Guard position is `siege.layout.keepObjective.visualProgress`.
- `tick(deltaTime:siege:)` remains the only live combat tick and preserves its current tower-first section.
- Automatic combat feedback maps Guard activity to existing melee/hit sound IDs only.

- [ ] **Step 1: Write failing Guard-combat tests.**

Pin with deterministic configuration/seed:

- restored 5-HP Guard keeps lane/HP but starts at Keep progress;
- a right-lane allied soldier already at `0.80` still meets a later Guard spawned at Keep progress and cannot pass it;
- Guard and allied soldier move toward contact but never cross;
- soldier attacks the nearest living Guard ahead before its structure objective;
- Guard attacks the foremost allied soldier in its lane only;
- Guard cannot target another lane or player castle;
- dead Guard emits one loss and survivors resume structure movement;
- Guard already on field remains functional after Barracks death;
- Keep destruction returns conquest immediately without Guard cleanup;
- an empty Guard roster keeps existing HPA-468 movement/attack/tower behavior unchanged.

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

Add one guard array and next-ID counter. Do not create an enemy protocol/base class.

- [ ] **Step 3: Add restore/spawn/snapshot helpers with Keep progress.**

The restore/spawn API receives the current `SiegeSnapshot` so it can use:

```swift
let spawnProgress = snapshot.layout.keepObjective.visualProgress
```

`guardSnapshots` returns living Guards as lane + clamped HP only. It never exposes transient ID/position for persistence.

- [ ] **Step 4: Insert Guard contact without moving the existing tower block.**

Keep the current defensive-fire shot/cooldown resolution at the beginning of `tick`. After that block:

1. resolve each soldier's first structure target and nearest living Guard ahead on its lane;
2. move soldiers toward the nearer blocking Guard or normal structure stop point;
3. move each Guard downward toward the foremost living allied soldier in its lane, clamping so it cannot cross;
4. resolve living Guard attacks;
5. resolve still-living allied attacks against a blocking Guard first, otherwise structure;
6. prune deaths and emit events.

Do not build a generic phase engine and do not move tower targeting after actor movement.

- [ ] **Step 5: Add only the required TickResult events.**

```swift
struct GuardAttackEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

struct GuardHitEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

struct GuardLossEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let lane: BattleLane
}
```

`TickResult` gains `guardAttacks`, `guardHits`, and `guardLosses`. Guard damage must not become `SoldierAttackEvent` or battle-report city damage. Existing `damagedSoldierIDs` / `soldierLosses` still carry Guard-caused allied damage/death.

- [ ] **Step 6: Make automatic combat feedback treat Guard combat as existing combat.**

In `AutomaticCombatFeedbackScheduler.candidates(from:)`:

- `guardAttacks` and `guardHits` may contribute existing `.attackMelee` / `.soldierHit` candidates;
- keep existing rate limits/priority;
- add no sound ID, category, queue, or replay behavior.

Add tests where `soldierAttacks` is empty but Guard events still yield the existing combat sound candidate.

- [ ] **Step 7: Run focused combat/feedback suites and commit.**

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

### Task 4: Integrate Guard state/persistence and procedural presentation in `BattleScene`

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BattleSceneCoverageTests.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/SoldierRuntimeGeometryTests.swift` only if shared actor geometry actually changes

**Interfaces:**
- Consumes `synchronizeLiveGuardSnapshots`, `advanceActiveGuardReinforcements`, combat Guard restore/spawn/snapshot helpers, and Guard TickResult events.
- Extends existing `SiegeObjectiveAssetContract` with `barracks = "siege-barracks"`.
- Produces procedural `siege-barracks` and `siege-guard` placeholder presentation only; final art stays HPA-476.

- [ ] **Step 1: Add failing integration tests for Guard-only persistence and frame ordering.**

Pin:

- a persisted 5-HP Guard reconstructs as 5 HP at Keep progress;
- a tick where allies only damage a Guard updates `SiegeProgress` even though `result.soldierAttacks.isEmpty`;
- Guard wave elapsed persists via the existing two-second progress-save cadence even when the current city has no player buildings;
- a due wave is created only after current combat result/snapshots are applied;
- Barracks destroyed in that tick prevents a due same-frame wave;
- a non-pilot city creates no Guard/Barracks runtime nodes.

- [ ] **Step 2: Restore Guards when the scene creates/recreates combat.**

After constructing `BattleCombatState`, read `state.siegeProgress.guardReinforcements?.unresolvedGuards` and restore each snapshot through the combat helper using `state.currentSiegeSnapshot`. Do not use Barracks progress as the actor position and do not reconstruct IDs.

- [ ] **Step 3: Keep Guard synchronization outside `applyCombatResult`'s attack guard.**

`applyCombatResult` may keep its existing structure-attack early return, but `advanceCombat` must continue afterward. After `applyCombatResult(result)`:

```swift
let guardStateChanged = state.synchronizeLiveGuardSnapshots(combat.guardSnapshots)
let spawnedGuards = state.advanceActiveGuardReinforcements(
    deltaTime: combat.clampedDeltaTime(deltaTime)
)
for snapshot in spawnedGuards {
    combat.restoreGuard(snapshot, siege: state.currentSiegeSnapshot)
}
```

Use the actual helper name chosen in Task 3 consistently; do not hide these calls behind `!result.soldierAttacks.isEmpty`.

- [ ] **Step 4: Broaden the existing progress-save throttle instead of adding a second timer.**

Rename/generalize `buildingProgressSaveAccumulator` / `buildingProgressSaveInterval` only as much as needed so the current 2-second cadence applies when either:

- the city has building progress to persist; or
- Highcrest Guard reinforcement progress is active.

Keep immediate saves for real building spawns. Also save immediately when Guard snapshots change, Guards spawn, Guard losses occur, or structure damage mutates state. Do not save every render frame.

- [ ] **Step 5: Preserve live ordering exactly.**

The final `advanceCombat` sequence is:

```text
record active time
resolve/spawn player building units
maintain existing persistence throttle
combat.tick (tower-first remains inside tick)
feedback.emitAutomaticCombat(result)
applyCombatResult(result)
synchronize living Guard lane/HP snapshots
advance due Guard waves with combat-clamped delta
restore returned Guard snapshots into combat
persist if durable Guard state changed/spawned
sync soldier + Guard nodes / HUD
```

If Keep conquest changes stage out of `.battleActive`, skip subsequent wave creation.

- [ ] **Step 6: Add the Barracks asset contract and local procedural Barracks rendering.**

Extend existing `SiegeObjectiveAssetContract`:

```swift
static let barracks = "siege-barracks"
```

Render one Barracks from the authored objective position with objective HP, intact state, ruined/disabled `SHUT DOWN` state, and compact `GUARDS N` reserve copy. Follow existing objective-node code; do not add a structure renderer framework.

- [ ] **Step 7: Add structurally distinct Guard placeholders.**

Build Guard nodes from a helmet/head + shield/body composition with enemy-facing posture. Do not identify them only by color. Map `guardAttacks`, `guardHits`, and `guardLosses` to short observational actions; model timing remains authoritative.

Document the HPA-476 handoff beside the existing objective contract:

```text
siege-barracks — bottom-center — intact, ruined/disabled
siege-guard    — feet/bottom-center — resting, walk, attack, hit
```

Defeat may stay a procedural fade.

- [ ] **Step 8: Extend Forged fixtures and re-pin existing City 5 assumptions.**

Add only the Highcrest evidence states needed for capture: active Barracks/wave, damaged Guard, Barracks shut down with survivor, and final advance. Re-run existing City 5 Camp/Forged fixtures because Highcrest now has a custom siege layout; fix fixture assumptions rather than adding a second capture system.

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
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/SoldierRuntimeGeometryTests.swift
git commit -m "feat: present Highcrest Barracks and Guards"
```

---

### Task 5: Prove lifecycle reconstruction and non-pilot regression behavior

**Files:**
- Modify as required by concrete failures: `PyxisTests/KingdomGameStoreTests.swift`
- Modify as required by concrete failures: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify as required by concrete failures: `PyxisTests/BuildingViewSceneTests.swift`
- Modify as required by concrete failures: `PyxisTests/CountryMapSceneTests.swift`
- Modify as required by concrete failures: `PyxisTests/GameViewControllerTests.swift`
- Modify as required by concrete failures: `PyxisTests/DevJumpStateTests.swift`

**Interfaces:**
- No new production abstraction is expected here. This task closes lifecycle/routing gaps using the APIs introduced in Tasks 1–4.

- [ ] **Step 1: Add a save/reload regression sequence.**

Seed Highcrest with:

```text
waveElapsedSeconds = 4.5
remainingReserve = 3
Guard A: left / 5 HP
Guard B: right / 9 HP
Barracks damaged but alive
```

Round-trip through `KingdomGameStore`, reconstruct Battle, and assert durable values remain exact while transient Guard IDs/positions are recreated at Keep progress.

- [ ] **Step 2: Add tab/Camp/Map settlement coverage.**

Prove leaving Battle and returning cannot heal Guards, refill reserve, or restart phase; Camp build/upgrade and background return both use the shared settlement semantics; settlement conquest still routes through the pending Battle result exactly once.

- [ ] **Step 3: Pin one non-pilot city.**

Use City 1 or 2 to prove:

- `guardReinforcements == nil`;
- no Guard scheduler work occurs;
- HPA-468 selected-lane spawn/objective combat and tower ordering remain unchanged;
- existing conquest/report flow still passes.

- [ ] **Step 4: Re-smoke City 5 dev-jump/fixture flows.**

Because Highcrest changed from single-Keep to custom layout, verify DEBUG city jump and existing fixture state materialization normalize the fresh Highcrest Barracks/Guard progress correctly without special-case migration code.

- [ ] **Step 5: Run broad affected suites and commit fixes only if needed.**

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
```

If production/test fixes are required:

```bash
git add Pyxis PyxisTests
git commit -m "test: lock Highcrest Guard lifecycle"
```

---

### Task 6: Balance, gameplay evidence, and final gates

**Files:**
- Modify if evidence triggers retuning: `Pyxis/SiegeState.swift`, `Pyxis/Country1CityCatalog.swift`
- Modify matching tests for any exact tuned values
- Update PR body with measured evidence; do not add a new evidence framework

- [ ] **Step 1: Capture the deterministic Highcrest baseline on this PR's base.**

Use `main` at `76f5e6b836acab5e48f6c27ab107049e1811ba18` with one fixed seed and representative camp/loadout. Record current City 5 elapsed time and allied losses under the existing single-Keep encounter so the new pilot has an honest reference.

- [ ] **Step 2: Run the same camp/loadout on the right direct route.**

Record:

```text
elapsed to Keep conquest
allied losses
Guards spawned
guards defeated
Barracks remaining HP at conquest
```

Explicitly capture a later wave intercepting an army whose foremost soldier has already passed `0.62`; this is the regression for the reviewed spawn-behind failure.

- [ ] **Step 3: Run the same camp/loadout on the left Barracks-first route.**

Record the same fields plus Barracks shutdown time and prove no Guard appears after at least one full subsequent six-second opportunity.

- [ ] **Step 4: Exercise the lane-switch cap case in running gameplay.**

Create/retain old-lane Guards, switch assault lane, and prove the newly selected lane still receives reinforcement while reserve remains. Automated tests are the contract; this smoke confirms the behavior is visually understandable.

- [ ] **Step 5: Retune only if the evidence gate triggers.**

Retune only Highcrest objective weights and/or `HighcrestGuardRules` when:

- one route is an obvious free choice on both elapsed time and losses;
- both routes stall unreasonably;
- Barracks shutdown has no visible consequence; or
- direct-route Guard pressure is effectively irrelevant.

Do not add another structure, enemy type, ability, wave framework, or reward to fix balance.

- [ ] **Step 6: Capture presentation evidence.**

Capture real running gameplay at:

- existing 393×852 reference;
- one compact supported phone;
- portrait iPad.

Show Guard/direct-route intercept, active Barracks pressure, Barracks shutdown, survivor after shutdown, lane-switch reinforcement, final Keep conquest, and one non-pilot city. Verify Settings/tabs/assault flag/Spawn controls/objective HP/conquest report remain unobstructed.

- [ ] **Step 7: Run full gates.**

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

Keep the repository's existing lint/coverage policy; do not weaken gates for this ticket.

- [ ] **Step 8: Update the PR evidence section and commit final tuning/doc synchronization if required.**

The final PR body must state the shipped Highcrest weights/Guard constants and measured direct-vs-Barracks evidence. If values changed, update both spec/plan exact starting/shipped-value notes and their matching tests in the same final commit.

```bash
git add Pyxis PyxisTests docs/superpowers

git commit -m "balance: finalize Highcrest Guard pilot"
```

Skip the commit when no files changed.

---

## Review-risk checklist before implementation completion

- **Spawn-behind:** Guards spawn/restore at Keep progress; a direct-route soldier past `0.62` still intercepts a wave.
- **Lane-switch cap:** four old-lane Guards do not suppress a new-lane wave; reserve remains globally finite at eight.
- **Guard-only save/feedback:** Guard HP and wave phase survive without structure hits; automatic Guard activity reuses existing melee/hit sounds.
- **Dual settlement callers:** background idle and Camp/build-upgrade use the same private chronological helper.
- **Closed enum/fixtures:** Scout `L Barracks`, `SiegeObjectiveAssetContract.barracks`, normalization, CityDefinition comments, and City 5 Forged fixtures are all explicitly updated.
