# HPA-469 Highcrest Barracks + Guard Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Highcrest's one-Barracks / finite-Guard reinforcement pilot while preserving HPA-468's siege model, existing idle semantics, and single-combat-simulator architecture.

**Architecture:** Extend the existing siege value types with one Barracks objective kind and Highcrest-local Guard persistence/tuning. `KingdomGameState` owns the durable wave clock/reserve and bounded idle settlement; `BattleCombatState` remains the sole live actor simulator; `BattleScene` mirrors model events into procedural placeholders and later HPA-476 asset contracts.

**Tech Stack:** Swift 5, Swift Testing, SpriteKit/UIKit, existing `KingdomGameStore` JSON persistence, Xcode/xcodebuild, SwiftLint.

**Spec:** `docs/superpowers/specs/2026-09-16-highcrest-barracks-guard-pilot-design.md`

## Global Constraints

- One implementation PR for HPA-469; do not split foundation, persistence, combat, UI, or QA into child PRs.
- Keep HP remains the only conquest/liveness authority.
- Exact initial wave contract: 2 Guards / 6 seconds, max 4 active, 8 reserve.
- Reserve is consumed only for Guards actually spawned.
- Barracks destruction prevents future spawns but does not delete living Guards.
- New Guards use the currently selected assault lane; existing Guards keep their assigned lane.
- Keep existing 8-hour idle cap, 1/10 idle building-production rate, no-buildings/no-progress behavior, at-most-one-city conquest, and exactly-once report/reward behavior.
- No save migration, generic wave engine, enemy-AI framework, pathfinder, physics, new reward system, or generated art.
- HPA-476 owns final `siege-barracks` / `siege-guard` assets and animation production.
- Run tests with parallel testing disabled.

---

### Task 1: Extend siege authoring and persisted Guard state

**Files:**
- Modify: `Pyxis/SiegeState.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `Pyxis/KingdomGameState.swift` at siege-progress initialization/normalization and Codable handling
- Modify: `PyxisTests/SiegeStateTests.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `PyxisTests/SiegeTestSupport.swift`

**Interfaces:**
- Produces `CitySiegeLayout.ObjectiveKind.barracks`.
- Produces `HighcrestGuardRules` with the exact constants from the design.
- Produces `GuardSnapshot`, `GuardReinforcementProgress`, and `SiegeProgress.guardReinforcements`.
- Highcrest authoring produces `highcrest.keep` and `highcrest.barracks` with 4:1 weights and left Barracks-first route.

- [ ] **Step 1: Add failing Highcrest layout tests.**

Pin the real catalog, not a duplicate test layout:

```swift
@Test func highcrestAuthorsOnlyKeepAndBarracksPilot() {
    let definition = Country1CityCatalog.definition(for: 5)
    let layout = definition.siegeLayout
    let maxPower = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))

    #expect(layout.defaultLane == .right)
    #expect(layout.routes[.left] == ["highcrest.barracks", "highcrest.keep"])
    #expect(layout.routes[.center] == ["highcrest.keep"])
    #expect(layout.routes[.right] == ["highcrest.keep"])
    #expect(maxPower["highcrest.keep"] == 342)
    #expect(maxPower["highcrest.barracks"] == 85)
}
```

Also assert `highcrest.barracks` is `.barracks`, there is exactly one Barracks, and defensive fire remains sourced from `highcrest.keep` across all lanes.

- [ ] **Step 2: Run focused catalog/siege tests and confirm failure.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/SiegeStateTests
```

Expected: FAIL because `.barracks` and Highcrest custom layout do not exist.

- [ ] **Step 3: Add the minimal authored model.**

In `SiegeState.swift`:

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 6.0
    static let maxActiveGuards = 4
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

Add `.barracks`, an optional Barracks lookup, and `guardReinforcements` on `SiegeProgress`. Keep construction invariants fail-closed and current routes ID-based.

- [ ] **Step 4: Author Highcrest in `Country1CityCatalog`.**

Use exactly the spec layout:

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

- [ ] **Step 5: Initialize and normalize reinforcement progress in `KingdomGameState`.**

Fresh/current Highcrest siege progress gets:

```swift
GuardReinforcementProgress(
    waveElapsedSeconds: 0,
    remainingReserve: HighcrestGuardRules.totalReserve,
    unresolvedGuards: []
)
```

Other cities stay `nil`. Clamp reserve, elapsed, count, and HP exactly as specified; do not persist positions or IDs. Do not add save versioning.

- [ ] **Step 6: Add round-trip tests.**

Pin that JSON/store round-trip preserves wave elapsed, remaining reserve, Guard lanes, and HP; loading cannot heal a 5-HP Guard or restore reserve from 3 to 8.

- [ ] **Step 7: Run focused tests and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests

git add Pyxis/SiegeState.swift Pyxis/Country1CityCatalog.swift Pyxis/KingdomGameState.swift \
  PyxisTests/SiegeStateTests.swift PyxisTests/Country1CityCatalogTests.swift \
  PyxisTests/KingdomGameStateTests.swift PyxisTests/KingdomGameStoreTests.swift PyxisTests/SiegeTestSupport.swift
git commit -m "feat: author Highcrest Guard siege state"
```

---

### Task 2: Add durable live waves and bounded idle Guard settlement

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift` only where settlement contracts need existing regression coverage
- Modify: `PyxisTests/CountryMapSceneTests.swift` only where settlement contracts need existing regression coverage

**Interfaces:**
- Consumes `GuardReinforcementProgress`, `HighcrestGuardRules`, `CitySiegeLayout.barracksObjective`.
- Produces `advanceActiveGuardReinforcements(deltaTime:) -> [GuardSnapshot]`.
- Existing `resolveCurrentCityBuildingIdleProgress(at:)` and settlement helpers gain bounded Guard checkpoints without a second idle simulator.

- [ ] **Step 1: Add failing active-wave tests.**

Cover these exact transitions:

```text
5.9s -> 0 Guards, reserve 8
+0.1s -> 2 Guards on current selected lane, reserve 6
+6.0s -> 4 active Guards, reserve 4
+6.0s while cap=4 -> still 4 Guards, reserve still 4
kill one, +6.0s -> one new Guard, reserve 3
Barracks destroyed, +60s -> no new Guards and reserve unchanged
```

Also switch assault lane between waves and assert only newly spawned Guards use the new lane.

- [ ] **Step 2: Implement the live scheduler with no generic wave abstraction.**

Add one focused mutating function on `KingdomGameState`. It must:

1. require `.battleActive` Highcrest with reinforcement progress;
2. stop if Keep or Barracks is dead;
3. advance persisted elapsed time;
4. process each due six-second boundary;
5. compute available slots from persisted living snapshots;
6. append `min(2, slots, reserve)` full-HP snapshots on the current selected lane;
7. subtract only the count appended;
8. return only newly appended snapshots.

- [ ] **Step 3: Add failing idle tests around wave boundaries.**

Use deterministic city-building states and dates to pin:

- existing Guard HP absorbs production damage before structure damage;
- a due wave appears before later production segments;
- cap-blocked wave does not burn reserve;
- Barracks death in one segment suppresses later wave checkpoints;
- direct-route settlement can leave Barracks alive while Keep falls;
- no buildings returns `.none` and leaves Guard progress untouched;
- conquest remains at most one city and reward/report stay exactly once.

- [ ] **Step 4: Refactor idle settlement into bounded chronological segments.**

Do not simulate frames. Reuse the existing private `resolveBuildingSpawns(in:effectiveActiveSeconds:)` helper repeatedly on the same `CityBattleState`.

For each segment ending at the next due Guard-wave boundary:

```swift
let effectiveActive = segmentSeconds / Self.idleBuildingProductionScale
let spawns = Self.resolveBuildingSpawns(in: &cityState, effectiveActiveSeconds: effectiveActive)
```

For each returned player `BuildingSpawn`, spend trait-adjusted damage in this order:

1. unresolved Guards on that spawn's selected siege lane, oldest snapshot first;
2. `currentSiegeLayout.spendDamageBudget(...)` for any remaining damage.

At the boundary, append a due Guard wave only if Barracks and Keep still live. The finite reserve guarantees at most four wave checkpoints.

- [ ] **Step 5: Preserve existing result attribution.**

Structure damage continues through the existing siege/session attribution path. Guard damage absorbs production but is not recorded as city/objective damage and grants no reward.

- [ ] **Step 6: Run focused state/lifecycle suites and commit.**

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

### Task 3: Extend `BattleCombatState` with lane-local Guard contact

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift` only if new TickResult fields require fixture updates
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift` only if new TickResult fields require fixture updates

**Interfaces:**
- Consumes `GuardSnapshot` and `HighcrestGuardRules`.
- Produces `GuardID`, transient `Guard`, restore/spawn helpers, `guardSnapshots`, and small Guard attack/hit/loss events.
- `tick(deltaTime:siege:)` remains the only live combat tick.

- [ ] **Step 1: Write failing Guard-combat tests.**

Pin these behaviors with deterministic configuration/seed:

- restored Guard starts at Barracks progress and keeps persisted HP/lane;
- Guard and allied soldier move toward contact but never cross;
- allied soldier attacks the blocking Guard before its structure objective;
- Guard attacks the foremost allied soldier in its lane only;
- Guard cannot target another lane or player castle;
- dead Guard disappears, emits one loss, and survivors resume structure movement;
- Guard already on field remains functional when Barracks snapshot is dead;
- Keep destruction returns conquest immediately without requiring Guard cleanup.

- [ ] **Step 2: Add the smallest transient Guard actor.**

Add:

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

Do not create an enemy protocol/base class. Add one guard array and next-ID counter beside the existing soldier roster.

- [ ] **Step 3: Add restore/spawn/snapshot helpers.**

A restored or newly spawned Guard starts at the Barracks objective's `visualProgress`; persistent snapshots omit ID/position. `guardSnapshots` returns living Guards as lane + clamped HP only.

- [ ] **Step 4: Implement contact and deterministic tick order.**

For each tick:

1. resolve lane-local blocker relationships;
2. move allied soldiers toward either blocking Guard or first living structure;
3. move Guards only toward the foremost allied soldier in their own lane;
4. resolve living Guard attacks;
5. resolve still-living allied attacks against Guard blocker first, otherwise structure;
6. prune dead Guards/soldiers and emit events.

Use each actor's own attack range to clamp movement; never let one movement step pass the opposing actor's current position.

- [ ] **Step 5: Keep structure events structure-only.**

Do not emit `SoldierAttackEvent` when a soldier hits a Guard. Add only:

```swift
var guardAttacks: [GuardAttackEvent]
var guardHits: [GuardHitEvent]
var guardLosses: [GuardLossEvent]
```

Existing `damagedSoldierIDs` and `soldierLosses` continue to represent Guard-caused allied damage/losses for current feedback/reporting behavior.

- [ ] **Step 6: Run focused combat/feedback tests and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleCombatStateTests \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests

git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift \
  PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift
git commit -m "feat: add lane-local enemy Guard combat"
```

---

### Task 4: Integrate Barracks and Guards into `BattleScene`

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BattleSceneCoverageTests.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/SoldierRuntimeGeometryTests.swift` only if shared actor geometry needs a regression pin

**Interfaces:**
- Consumes `advanceActiveGuardReinforcements`, combat Guard restore/spawn/snapshot helpers, and Guard TickResult events.
- Produces procedural `siege-barracks` and `siege-guard` placeholder presentation contract.

- [ ] **Step 1: Add failing scene tests for reconstruction and ordering.**

Pin:

- Highcrest builds one Barracks node at the authored objective position with its own HP;
- persisted 5-HP Guard reconstructs as 5 HP rather than full HP;
- a due wave is created only after the current combat result is applied;
- Barracks destroyed in that tick prevents a due same-frame wave;
- old Guards remain rendered and fighting after shutdown;
- Keep conquest hides/stops remaining combat without requiring Guard cleanup;
- a non-pilot city renders no Barracks/Guard nodes.

- [ ] **Step 2: Restore Guards when the scene rebuilds combat state.**

When Highcrest `BattleScene` is created/recreated, read `state.siegeProgress.guardReinforcements?.unresolvedGuards` and seed transient Guards at `highcrest.barracks.visualProgress`. Never reconstruct positions/IDs from persistence.

- [ ] **Step 3: Apply the spec's frame ordering.**

In `update(_:)` keep current building-spawn and combat behavior, but order the new work as:

```text
player building spawns
-> combat tick
-> apply structure/soldier/Guard result to state
-> replace persisted Guard snapshots from combat
-> advance due Guard wave
-> spawn returned Guards into combat
-> save + sync nodes
```

Use the combat tick's clamped delta for the active Guard wave clock so render stalls do not create burst waves.

- [ ] **Step 4: Add local procedural Barracks rendering.**

Follow the existing objective-node pattern rather than a generic structure renderer. Add intact + ruined/disabled states, objective HP, and one compact attached status:

```text
GUARDS 8 ... GUARDS 0
SHUT DOWN
```

The label belongs to the Barracks node, not a new battlefield HUD panel.

- [ ] **Step 5: Add structurally distinct Guard placeholders.**

Build Guard nodes from a helmet/head + shield/body composition with downward/enemy-facing posture. Do not identify them only with color. Map `guardAttacks`, `guardHits`, and `guardLosses` to short observational actions; combat timing remains model-owned.

- [ ] **Step 6: Add spawn/shutdown cues and asset contract comments.**

Define the runtime names used by HPA-476:

```text
siege-barracks — bottom-center — intact, ruined/disabled
siege-guard    — feet/bottom-center — resting, walk, attack, hit
```

Defeat can stay a procedural fade. No image generation or final animation frames land here.

- [ ] **Step 7: Extend Forged fixture coverage for captures.**

Add only the Highcrest states needed for evidence: active Barracks/wave, damaged Guard, Barracks shut down with survivor, and final advance. Reuse existing DEBUG-only fixture routing; do not add another capture framework.

- [ ] **Step 8: Run focused scene tests and commit.**

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

### Task 5: Prove lifecycle persistence and non-pilot regression behavior

**Files:**
- Modify as needed: `PyxisTests/KingdomGameStoreTests.swift`
- Modify as needed: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify as needed: `PyxisTests/BuildingViewSceneTests.swift`
- Modify as needed: `PyxisTests/CountryMapSceneTests.swift`
- Modify as needed: `PyxisTests/GameViewControllerTests.swift`
- Modify as needed: `PyxisTests/DevJumpStateTests.swift`

**Interfaces:**
- No new production abstraction is expected in this task; it closes persistence/routing gaps discovered by integration tests.

- [ ] **Step 1: Add a save/reload regression sequence.**

Create Highcrest with:

```text
waveElapsedSeconds = 4.5
remainingReserve = 3
Guard A: left / 5 HP
Guard B: right / 9 HP
Barracks damaged but alive
```

Round-trip through `KingdomGameStore`, reconstruct Battle, and assert the exact durable values remain while transient Guard IDs/positions may differ.

- [ ] **Step 2: Add tab/Camp/Map settlement coverage.**

Pin that leaving Battle and returning cannot heal Guards or refill reserve, and settlement conquest still routes through the existing pending Battle result exactly once.

- [ ] **Step 3: Pin one non-pilot city.**

Use City 1 or 2 to prove:

- `guardReinforcements == nil`;
- no Guard wave work occurs;
- HPA-468 selected-lane spawn/objective combat remains unchanged;
- existing conquest/report flow still passes.

- [ ] **Step 4: Run the broad affected suites and commit any fixes.**

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

If fixes are required:

```bash
git add Pyxis PyxisTests
git commit -m "test: lock Highcrest Guard lifecycle"
```

---

### Task 6: Balance, gameplay evidence, and final gates

**Files:**
- Modify if evidence triggers retuning: `Pyxis/SiegeState.swift`, `Pyxis/Country1CityCatalog.swift`
- Modify matching tests for any exact tuned values
- Update PR body with evidence; no new evidence framework/file is required unless the repository's current convention requires one

- [ ] **Step 1: Capture a deterministic Highcrest baseline on this PR's base (`76f5e6b`).**

Use one fixed representative camp/loadout for every comparison. Record at minimum elapsed time and allied losses for current single-Keep Highcrest.

- [ ] **Step 2: Run two feature routes with the identical camp/loadout and seed.**

Record:

| Route | Required observation |
| --- | --- |
| right direct push | elapsed, allied losses, Guards spawned/defeated, Barracks still alive at conquest |
| left Barracks-first | elapsed, allied losses, Barracks shutdown time, Guards spawned/defeated, no post-shutdown wave |

- [ ] **Step 3: Apply the bounded retune rule only if needed.**

Retune only:

- Highcrest 4:1 objective weights while keeping total durability budget 427; and/or
- numeric constants already inside `HighcrestGuardRules`.

Do not add another structure, new Guard class, wave system, reward, or player mechanic. Update exact tests and spec table if shipped numbers change.

- [ ] **Step 4: Capture visual/runtime evidence.**

Capture the full sequence at 393x852 plus compact phone and portrait iPad:

1. Guard wave meets army;
2. Barracks active pressure;
3. Barracks destruction;
4. `SHUT DOWN` + no spawn across another six-second interval;
5. surviving Guard after shutdown;
6. final Keep conquest;
7. one non-pilot city smoke.

Also verify reduced-motion/static readability if that path changes Guard actions.

- [ ] **Step 5: Run final repository gates.**

```bash
swiftlint lint

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' build

git diff --check
```

Keep the existing CI/Codecov threshold; do not weaken coverage or lint gates to ship the feature.

- [ ] **Step 6: Update the existing HPA-469 draft PR body with final evidence and implementation deviations, then mark ready only after review.**

The final PR must still be the same single HPA-469 PR created from this plan.
