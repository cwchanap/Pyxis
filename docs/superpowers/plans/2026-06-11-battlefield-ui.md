# Battlefield UI (Vertical 3-Lane) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rotate the battle screen to a vertical full-screen battlefield (enemy city top, player castle bottom) with three marching lanes, random lane assignment at spawn, per-lane tower targeting, and per-city deterministic lane defense modifiers.

**Architecture:** Lane rules live in the pure models: `BattleCombatState` gains a seedable PRNG, a `lane` per soldier, per-lane tower targeting, and lane damage multipliers in its `Configuration`; a new pure `LaneDefenseProfile` derives each city's lane roles. `BattleScene` only re-projects `(lane, position)` onto a vertical full-screen layout.

**Tech Stack:** Swift 5, SpriteKit, Swift Testing (`import Testing`, `@Test`, `#expect`) for unit tests.

**Spec:** `docs/superpowers/specs/2026-06-11-battlefield-ui-design.md`

**Test command (whole unit suite):**
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests
```
If that simulator isn't available, list destinations with `xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations` and substitute.

**Project note:** The Xcode project auto-discovers new files under `Pyxis/` and `PyxisTests/` (`PBXFileSystemSynchronizedRootGroup`) — do NOT edit `project.pbxproj`.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `Pyxis/SplitMix64.swift` | Create | Tiny Equatable seedable PRNG (`RandomNumberGenerator`) |
| `Pyxis/BattleLane.swift` | Create | `BattleLane` enum (left/center/right) |
| `Pyxis/LaneDefenseProfile.swift` | Create | Per-city lane roles + tower damage multipliers (pure) |
| `Pyxis/BattleCombatState.swift` | Modify | Soldier lane, seeded RNG, per-lane targeting, lane damage scaling |
| `Pyxis/KingdomGameState.swift` | Modify | `currentCityLaneDefenseProfile` accessor |
| `Pyxis/BattleScene.swift` | Modify | Vertical full-screen layout, per-lane gates/effects, lane indicators |
| `PyxisTests/SplitMix64Tests.swift` | Create | PRNG determinism tests |
| `PyxisTests/LaneDefenseProfileTests.swift` | Create | Profile determinism tests |
| `PyxisTests/BattleCombatStateTests.swift` | Modify | Lane assignment / targeting / modifier tests; pin lanes in 1 existing test |
| `PyxisTests/KingdomGameStateTests.swift` | Modify | Profile accessor test |
| `PyxisTests/BattleSceneTests.swift` | Modify | Vertical layout / lane rendering / indicator tests |
| `CLAUDE.md` | Modify | Update architecture notes for lanes |

---

### Task 1: SplitMix64 seedable PRNG

**Files:**
- Create: `Pyxis/SplitMix64.swift`
- Create: `PyxisTests/SplitMix64Tests.swift`

- [ ] **Step 1: Write the failing test**

Create `PyxisTests/SplitMix64Tests.swift`:

```swift
//
//  SplitMix64Tests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct SplitMix64Tests {
    @Test func sameSeedProducesSameSequence() {
        var first = SplitMix64(seed: 42)
        var second = SplitMix64(seed: 42)

        for _ in 0..<10 {
            #expect(first.next() == second.next())
        }
    }

    @Test func differentSeedsProduceDifferentSequences() {
        var first = SplitMix64(seed: 1)
        var second = SplitMix64(seed: 2)

        #expect(first.next() != second.next())
    }

    @Test func generatorsWithSameSeedAndAdvancementAreEqual() {
        var first = SplitMix64(seed: 7)
        var second = SplitMix64(seed: 7)

        #expect(first == second)

        _ = first.next()
        #expect(first != second)

        _ = second.next()
        #expect(first == second)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/SplitMix64Tests
```
Expected: BUILD FAILS with "cannot find 'SplitMix64' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `Pyxis/SplitMix64.swift`:

```swift
//
//  SplitMix64.swift
//  Pyxis
//

import Foundation

/// Seedable, Equatable PRNG so `BattleCombatState` stays a deterministic value type.
struct SplitMix64: RandomNumberGenerator, Equatable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: TEST SUCCEEDED, 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/SplitMix64.swift PyxisTests/SplitMix64Tests.swift
git commit -m "Add SplitMix64 seedable PRNG for deterministic combat"
```

---

### Task 2: BattleLane enum + random lane assignment at spawn

**Files:**
- Create: `Pyxis/BattleLane.swift`
- Modify: `Pyxis/BattleCombatState.swift` (stored `rng`, seeded init, `Soldier.lane`, spawn lane parameter)
- Modify: `PyxisTests/BattleCombatStateTests.swift` (add tests)

- [ ] **Step 1: Write the failing tests**

Add to `PyxisTests/BattleCombatStateTests.swift` (inside `struct BattleCombatStateTests`):

```swift
    @Test func spawnAssignsLaneDeterministicallyFromSeed() throws {
        var first = BattleCombatState(configuration: .live(cityLevel: 1), seed: 99)
        var second = BattleCombatState(configuration: .live(cityLevel: 1), seed: 99)

        var firstLanes: [BattleLane] = []
        var secondLanes: [BattleLane] = []
        for _ in 0..<12 {
            let firstID = first.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
            let secondID = second.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
            firstLanes.append(try #require(first.soldier(id: firstID)).lane)
            secondLanes.append(try #require(second.soldier(id: secondID)).lane)
        }

        #expect(firstLanes == secondLanes)
        // 12 spawns across 3 lanes should not all collapse into a single lane.
        #expect(Set(firstLanes).count > 1)
    }

    @Test func spawnHonorsExplicitLane() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1), seed: 1)

        for lane in BattleLane.allCases {
            let id = combat.spawnSoldier(type: .archer, source: .building, level: 2, attackPower: 3, lane: lane)
            #expect(try #require(combat.soldier(id: id)).lane == lane)
        }
    }

    @Test func laneIsFixedForSoldierLifetime() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1), seed: 5)
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        _ = combat.tick(deltaTime: 0.2, cityRemainingHP: 1_000)
        _ = combat.tick(deltaTime: 0.2, cityRemainingHP: 1_000)

        #expect(try #require(combat.soldier(id: id)).lane == .right)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```
Expected: BUILD FAILS with "cannot find 'BattleLane' in scope" / no `seed:` initializer.

- [ ] **Step 3: Implement**

Create `Pyxis/BattleLane.swift`:

```swift
//
//  BattleLane.swift
//  Pyxis
//

import Foundation

/// One of the three vertical marching lanes on the battlefield.
/// Raw values are lane indices: left = 0, center = 1, right = 2.
enum BattleLane: Int, CaseIterable, Equatable {
    case left = 0
    case center = 1
    case right = 2
}
```

In `Pyxis/BattleCombatState.swift`:

1. Add `lane` to `Soldier` (after `let level: Int`):

```swift
        let level: Int
        let lane: BattleLane
```

2. Add the RNG stored property (after `private var towerCooldownRemaining: Double`):

```swift
    private var rng: SplitMix64
```

3. Replace the two initializers:

```swift
    init(configuration: Configuration, seed: UInt64) {
        self.configuration = configuration
        self.soldiers = []
        self.nextSoldierID = 1
        self.towerCooldownRemaining = 0
        self.rng = SplitMix64(seed: seed)
    }

    init(configuration: Configuration) {
        self.init(configuration: configuration, seed: UInt64.random(in: .min ... .max))
    }

    init(cityLevel: Int) {
        self.init(configuration: .live(cityLevel: cityLevel))
    }
```

4. Replace the full `spawnSoldier(type:source:level:attackPower:)` with a version taking an optional lane (the `spawnSoldier(attackPower:)` convenience stays as-is and forwards):

```swift
    @discardableResult
    mutating func spawnSoldier(
        type: SoldierType,
        source: SoldierSpawnSource,
        level: Int,
        attackPower: Int,
        lane: BattleLane? = nil
    ) -> SoldierID {
        let id = nextSoldierID
        nextSoldierID += 1

        let assignedLane = lane ?? (BattleLane.allCases.randomElement(using: &rng) ?? .center)
        let clampedLevel = max(1, level)
        let maxHP = maxHP(for: type, level: clampedLevel)
        soldiers.append(
            Soldier(
                id: id,
                type: type,
                source: source,
                level: clampedLevel,
                lane: assignedLane,
                maxHP: maxHP,
                currentHP: maxHP,
                defense: max(0, configuration.soldierDefense),
                attackPower: max(1, attackPower),
                attackSpeed: attackSpeed(for: type),
                attackRange: attackRange(for: type),
                movementSpeed: movementSpeed(for: type),
                position: 0,
                attackCooldownRemaining: 0
            )
        )

        return id
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: TEST SUCCEEDED — all `BattleCombatStateTests` pass (existing tests are unaffected: `Soldier` memberwise init is only used inside the model).

- [ ] **Step 5: Build the app target to catch any other call sites**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Expected: BUILD SUCCEEDED (scene call sites pass no `lane:`, so the default applies).

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BattleLane.swift Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Assign soldiers a random battle lane at spawn"
```

---

### Task 3: Per-lane tower targeting

**Files:**
- Modify: `Pyxis/BattleCombatState.swift` (`towerTargetIndex()`)
- Modify: `PyxisTests/BattleCombatStateTests.swift` (new tests; pin lanes in `towerTargetsLivingSoldierClosestToCity`)

- [ ] **Step 1: Update the existing targeting test to pin lanes**

In `towerTargetsLivingSoldierClosestToCity`, both spawns must share a lane or the new lane-based targeting makes the test flaky. Replace its spawn lines:

```swift
        let first = combat.spawnSoldier(attackPower: 1)
        _ = combat.tick(deltaTime: 0.7, cityRemainingHP: 20)
        let second = combat.spawnSoldier(attackPower: 1)
```

with:

```swift
        let first = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.tick(deltaTime: 0.7, cityRemainingHP: 20)
        let second = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
```

- [ ] **Step 2: Write the failing tests**

Add to `PyxisTests/BattleCombatStateTests.swift`:

```swift
    @Test func towerTargetsMostAdvancedSoldierWithinChosenLane() throws {
        // Tower range covers the whole field; all soldiers are eligible.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.5,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 3
        )
        // Front and back soldier in the same lane; the back one must never be hit
        // while the front one lives, regardless of which lane the RNG picks.
        let front = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = combat.tick(deltaTime: 0.5, cityRemainingHP: 1_000)
        let back = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(result.towerShots.count == 1)
        #expect(try #require(result.towerShots.first).soldierID == front)
        #expect(try #require(combat.soldier(id: back)).currentHP == 10)
    }

    @Test func towerNeverTargetsLaneWithNoSoldierInRange() throws {
        // Tower range 0.40: only soldiers past position 0.60 are eligible.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.7,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.40,
                maxDeltaTime: 1.0
            ),
            seed: 11
        )
        let advanced = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.tick(deltaTime: 1.0, cityRemainingHP: 1_000) // advanced reaches 0.70
        let fresh = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let result = combat.tick(deltaTime: 0.05, cityRemainingHP: 1_000)

        // Only the center lane has a soldier in range; the fresh right-lane
        // soldier (position ~0) must never be chosen.
        #expect(result.towerShots.count == 1)
        #expect(try #require(result.towerShots.first).soldierID == advanced)
        #expect(try #require(combat.soldier(id: fresh)).currentHP == 10)
    }

    @Test func towerSpreadsShotsAcrossOccupiedLanesOverTime() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 1_000,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 1,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 4
        )
        let left = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        let right = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        var hitSoldierIDs = Set<BattleCombatState.SoldierID>()
        for _ in 0..<30 {
            let result = combat.tick(deltaTime: 1.0, cityRemainingHP: 1_000_000)
            for shot in result.towerShots {
                hitSoldierIDs.insert(shot.soldierID)
            }
        }

        // Over 30 shots with a seeded RNG, both occupied lanes get hit.
        #expect(hitSoldierIDs.contains(left))
        #expect(hitSoldierIDs.contains(right))
    }
```

- [ ] **Step 3: Run tests to verify the new ones fail**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```
Expected: `towerSpreadsShotsAcrossOccupiedLanesOverTime` FAILS (current targeting always hits the single most advanced soldier — with movement 0 and insertion order, only one soldier gets hit). The two other new tests may pass already; that's fine.

- [ ] **Step 4: Implement per-lane targeting**

In `Pyxis/BattleCombatState.swift`, replace `towerTargetIndex()`:

```swift
    private mutating func towerTargetIndex() -> Int? {
        let inRangeIndices = soldiers.indices.filter {
            soldiers[$0].isAlive && isInTowerRange(soldiers[$0])
        }
        guard !inRangeIndices.isEmpty else {
            return nil
        }

        let occupiedLanes = BattleLane.allCases.filter { lane in
            inRangeIndices.contains { soldiers[$0].lane == lane }
        }
        // Only consume RNG when there is a real choice, so single-lane
        // scenarios stay byte-for-byte deterministic.
        let targetLane = occupiedLanes.count == 1
            ? occupiedLanes[0]
            : (occupiedLanes.randomElement(using: &rng) ?? occupiedLanes[0])

        return inRangeIndices
            .filter { soldiers[$0].lane == targetLane }
            .max { soldiers[$0].position < soldiers[$1].position }
    }
```

(The call site in `tick` already runs in a `mutating` context, so the `mutating` keyword change compiles as-is.)

- [ ] **Step 5: Run tests to verify they pass**

Same command as Step 3. Expected: TEST SUCCEEDED, all `BattleCombatStateTests` pass.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Target tower shots at a random occupied lane"
```

---

### Task 4: Lane damage multipliers in Configuration

**Files:**
- Modify: `Pyxis/BattleCombatState.swift` (`Configuration` + `damageAgainstSoldier`)
- Modify: `PyxisTests/BattleCombatStateTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `PyxisTests/BattleCombatStateTests.swift`:

```swift
    @Test func fortifiedLaneScalesTowerDamageUp() throws {
        // towerDamage 5, defense 1 → base 4; fortified 1.25× → 5.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.left: 1.25, .center: 1.0, .right: 0.80]
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 5)
        #expect(try #require(combat.soldier(id: id)).currentHP == 15)
    }

    @Test func exposedLaneScalesTowerDamageDown() throws {
        // towerDamage 5, defense 1 → base 4; exposed 0.80× → 3.2 → rounds to 3.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.left: 1.25, .center: 1.0, .right: 0.80]
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 3)
        #expect(try #require(combat.soldier(id: id)).currentHP == 17)
    }

    @Test func missingLaneMultiplierDefaultsToNeutral() throws {
        // Empty map → multiplier 1.0 everywhere; base damage 4 unchanged.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 4)
    }

    @Test func nonPositiveLaneMultiplierStillDealsMinimumDamage() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.center: -2.0]
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 1)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```
Expected: BUILD FAILS — `Configuration` has no `laneDamageMultipliers` parameter.

- [ ] **Step 3: Implement**

In `Pyxis/BattleCombatState.swift`:

1. Inside `Configuration`, add the stored property (after `let maxDeltaTime: Double`) and an explicit init so existing 9-argument call sites keep compiling:

```swift
        let maxDeltaTime: Double
        let laneDamageMultipliers: [BattleLane: Double]

        init(
            soldierMaxHP: Int,
            soldierDefense: Int,
            soldierAttackSpeed: Double,
            soldierAttackRange: Double,
            soldierMovementSpeed: Double,
            towerDamage: Int,
            towerAttackSpeed: Double,
            towerAttackRange: Double,
            maxDeltaTime: Double,
            laneDamageMultipliers: [BattleLane: Double] = [:]
        ) {
            self.soldierMaxHP = soldierMaxHP
            self.soldierDefense = soldierDefense
            self.soldierAttackSpeed = soldierAttackSpeed
            self.soldierAttackRange = soldierAttackRange
            self.soldierMovementSpeed = soldierMovementSpeed
            self.towerDamage = towerDamage
            self.towerAttackSpeed = towerAttackSpeed
            self.towerAttackRange = towerAttackRange
            self.maxDeltaTime = maxDeltaTime
            self.laneDamageMultipliers = laneDamageMultipliers
        }
```

2. Update `Configuration.live` to accept multipliers:

```swift
        static func live(
            cityLevel: Int,
            laneDamageMultipliers: [BattleLane: Double] = [:]
        ) -> Configuration {
            let clampedLevel = max(1, cityLevel)

            return Configuration(
                soldierMaxHP: 10,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.12,
                soldierMovementSpeed: 0.45,
                towerDamage: max(2, Int(ceil(1.5 * Double(clampedLevel)))),
                towerAttackSpeed: 0.8,
                towerAttackRange: 0.55,
                maxDeltaTime: 0.25,
                laneDamageMultipliers: laneDamageMultipliers
            )
        }
```

3. Replace `damageAgainstSoldier(_:)`:

```swift
    private func damageAgainstSoldier(_ soldier: Soldier) -> Int {
        let baseDamage = max(1, max(0, configuration.towerDamage) - soldier.defense)
        let laneMultiplier = max(0, configuration.laneDamageMultipliers[soldier.lane] ?? 1.0)
        return max(1, Int((Double(baseDamage) * laneMultiplier).rounded()))
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Same command as Step 2. Expected: TEST SUCCEEDED, all `BattleCombatStateTests` pass.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Scale tower damage by per-lane multipliers"
```

---

### Task 5: LaneDefenseProfile pure type

**Files:**
- Create: `Pyxis/LaneDefenseProfile.swift`
- Create: `PyxisTests/LaneDefenseProfileTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `PyxisTests/LaneDefenseProfileTests.swift`:

```swift
//
//  LaneDefenseProfileTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct LaneDefenseProfileTests {
    @Test func everyCityGetsExactlyOneOfEachRole() {
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let profile = LaneDefenseProfile.profile(forCityNumber: cityNumber)
            let roles = BattleLane.allCases.map { profile.role(for: $0) }

            #expect(roles.filter { $0 == .fortified }.count == 1)
            #expect(roles.filter { $0 == .exposed }.count == 1)
            #expect(roles.filter { $0 == .standard }.count == 1)
        }
    }

    @Test func assignmentFollowsCityNumberRotation() {
        // City 1: fortified = (1-1) % 3 = 0 (left), exposed = (1+1) % 3 = 2 (right).
        let cityOne = LaneDefenseProfile.profile(forCityNumber: 1)
        #expect(cityOne.role(for: .left) == .fortified)
        #expect(cityOne.role(for: .center) == .standard)
        #expect(cityOne.role(for: .right) == .exposed)

        // City 2: fortified = 1 (center), exposed = 0 (left).
        let cityTwo = LaneDefenseProfile.profile(forCityNumber: 2)
        #expect(cityTwo.role(for: .left) == .exposed)
        #expect(cityTwo.role(for: .center) == .fortified)
        #expect(cityTwo.role(for: .right) == .standard)

        // Consecutive cities differ.
        #expect(cityOne != cityTwo)
    }

    @Test func sameCityNumberAlwaysYieldsSameProfile() {
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 7) == LaneDefenseProfile.profile(forCityNumber: 7)
        )
    }

    @Test func outOfRangeCityNumbersClamp() {
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 0) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: -3) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 99)
                == LaneDefenseProfile.profile(forCityNumber: KingdomGameState.firstCountryCityCount)
        )
    }

    @Test func towerDamageMultipliersMatchRoles() {
        let profile = LaneDefenseProfile.profile(forCityNumber: 1)
        let multipliers = profile.towerDamageMultipliers

        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func roleMultiplierValuesMirrorDefenseTraitCurve() {
        #expect(LaneDefenseRole.fortified.towerDamageMultiplier == 1.25)
        #expect(LaneDefenseRole.exposed.towerDamageMultiplier == 0.80)
        #expect(LaneDefenseRole.standard.towerDamageMultiplier == 1.0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/LaneDefenseProfileTests
```
Expected: BUILD FAILS with "cannot find 'LaneDefenseProfile' in scope".

- [ ] **Step 3: Implement**

Create `Pyxis/LaneDefenseProfile.swift`:

```swift
//
//  LaneDefenseProfile.swift
//  Pyxis
//

import Foundation

/// How strongly the city tower punishes soldiers in a given lane.
enum LaneDefenseRole: String, CaseIterable, Equatable {
    case fortified
    case exposed
    case standard

    /// Multiplier on tower→soldier damage. Mirrors CityDefenseTrait's
    /// 1.25× / 0.80× balance values (which scale soldier→city damage).
    var towerDamageMultiplier: Double {
        switch self {
        case .fortified:
            return 1.25
        case .exposed:
            return 0.80
        case .standard:
            return 1.0
        }
    }
}

/// Per-city deterministic assignment of one role per battle lane.
struct LaneDefenseProfile: Equatable {
    let roles: [BattleLane: LaneDefenseRole]

    func role(for lane: BattleLane) -> LaneDefenseRole {
        roles[lane] ?? .standard
    }

    var towerDamageMultipliers: [BattleLane: Double] {
        roles.mapValues(\.towerDamageMultiplier)
    }

    static func profile(forCityNumber cityNumber: Int) -> LaneDefenseProfile {
        let clamped = min(max(1, cityNumber), KingdomGameState.firstCountryCityCount)
        let fortifiedIndex = (clamped - 1) % 3
        let exposedIndex = (clamped + 1) % 3

        var roles: [BattleLane: LaneDefenseRole] = [:]
        for lane in BattleLane.allCases {
            switch lane.rawValue {
            case fortifiedIndex:
                roles[lane] = .fortified
            case exposedIndex:
                roles[lane] = .exposed
            default:
                roles[lane] = .standard
            }
        }

        return LaneDefenseProfile(roles: roles)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/LaneDefenseProfileTests
```
Expected: TEST SUCCEEDED, 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/LaneDefenseProfile.swift PyxisTests/LaneDefenseProfileTests.swift
git commit -m "Add per-city deterministic lane defense profiles"
```

---

### Task 6: KingdomGameState lane profile accessor

**Files:**
- Modify: `Pyxis/KingdomGameState.swift` (next to `currentCityDefenseTrait`, around line 686)
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `PyxisTests/KingdomGameStateTests.swift` (inside the test struct):

```swift
    @Test func currentCityLaneDefenseProfileFollowsCityNumber() {
        let cityOne = KingdomGameState(gold: 0, cityRemainingPower: 10)
        #expect(cityOne.currentCityLaneDefenseProfile == LaneDefenseProfile.profile(forCityNumber: 1))

        let cityFive = KingdomGameState(
            gold: 0,
            cityRemainingPower: 10,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        #expect(cityFive.currentCityLaneDefenseProfile == LaneDefenseProfile.profile(forCityNumber: 5))
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests/currentCityLaneDefenseProfileFollowsCityNumber
```
Expected: BUILD FAILS — `currentCityLaneDefenseProfile` not found.

- [ ] **Step 3: Implement**

In `Pyxis/KingdomGameState.swift`, directly below `currentCityDefenseTrait` (line ~688):

```swift
    var currentCityLaneDefenseProfile: LaneDefenseProfile {
        LaneDefenseProfile.profile(forCityNumber: cityNumberInCountry)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Expose current city lane defense profile"
```

---

### Task 7: Wire lane multipliers into BattleScene's combat state

**Files:**
- Modify: `Pyxis/BattleScene.swift` (both inits ~line 128–144, `clearLiveCombat()` ~line 1166, DEBUG testing extension ~line 1620)
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `PyxisTests/BattleSceneTests.swift` (use the file's existing `makeStore`/`makeScene` helpers):

```swift
    @Test func combatUsesCurrentCityLaneDefenseMultipliers() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // City 1: left fortified (1.25), center standard (1.0), right exposed (0.80).
        let multipliers = scene.combatLaneDamageMultipliersForTesting
        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests/combatUsesCurrentCityLaneDefenseMultipliers
```
Expected: BUILD FAILS — `combatLaneDamageMultipliersForTesting` not found.

- [ ] **Step 3: Implement**

In `Pyxis/BattleScene.swift`:

1. Add a private factory (place near the inits):

```swift
    private static func makeCombat(for state: KingdomGameState) -> BattleCombatState {
        BattleCombatState(
            configuration: .live(
                cityLevel: state.cityLevel,
                laneDamageMultipliers: state.currentCityLaneDefenseProfile.towerDamageMultipliers
            )
        )
    }
```

2. In `init(size:store:router:)` replace
   `self.combat = BattleCombatState(cityLevel: loadedState.cityLevel)` with
   `self.combat = Self.makeCombat(for: loadedState)`.

3. In `required init?(coder:)` replace
   `self.combat = BattleCombatState(cityLevel: loadedState.cityLevel)` with
   `self.combat = Self.makeCombat(for: loadedState)`.

4. In `clearLiveCombat()` replace
   `combat = BattleCombatState(cityLevel: state.cityLevel)` with
   `combat = Self.makeCombat(for: state)`.

5. In the `#if DEBUG` extension, add:

```swift
    var combatLaneDamageMultipliersForTesting: [BattleLane: Double] {
        combat.configuration.laneDamageMultipliers
    }
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: TEST SUCCEEDED.

- [ ] **Step 5: Run the full BattleSceneTests suite for regressions**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```
Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Apply city lane defense profile to live combat"
```

---

### Task 8: Vertical full-screen battlefield layout

This is the big scene task: cities move to top/bottom, three vertical lanes replace the single horizontal one, soldiers march upward, and effects originate per-lane.

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `PyxisTests/BattleSceneTests.swift`:

```swift
    @Test func verticalBattlefieldPlacesEnemyCityAboveCastle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let enemyFrame = try #require(scene.enemyCityFrameForTesting)
        let castleFrame = try #require(scene.playerCastleFrameForTesting)
        let battlefield = try #require(scene.battleLayoutFramesForTesting).battlefield

        // Enemy city base sits at the top of the lane field; castle base at the bottom.
        #expect(enemyFrame.minY > castleFrame.maxY)
        #expect(abs(enemyFrame.minY - battlefield.maxY) <= 1)
        #expect(abs(castleFrame.minY - battlefield.minY) <= 1)
    }

    @Test func threeVerticalLanesSpanCastleGateToEnemyGate() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let laneXs = scene.laneCenterXsForTesting
        #expect(laneXs.count == 3)
        // Distinct, ascending lane columns.
        #expect(laneXs[0] < laneXs[1])
        #expect(laneXs[1] < laneXs[2])

        for lane in BattleLane.allCases {
            let start = try #require(scene.castleGatePointForTesting(lane: lane))
            let end = try #require(scene.enemyGatePointForTesting(lane: lane))
            // Vertical marching: same x, gaining y.
            #expect(start.x == end.x)
            #expect(end.y > start.y)
        }
    }

    @Test func soldierNodesRenderAtTheirLaneColumn() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, cityRemainingPower: 1_000))
        let scene = makeScene(store: store)

        for _ in 0..<6 {
            scene.spawnSoldierForTesting()
        }

        let placements = scene.soldierLanePlacementsForTesting
        #expect(placements.count == 6)
        for placement in placements {
            let expectedX = try #require(scene.castleGatePointForTesting(lane: placement.lane)?.x)
            #expect(abs(placement.nodePosition.x - expectedX) <= 0.5)
        }
    }

    @Test func backdropCoversFullScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        guard let backdropFrame = scene.battlefieldBackdropFrameForTesting else {
            // No backdrop asset bundled — nothing to assert.
            return
        }

        #expect(backdropFrame.minX <= 0)
        #expect(backdropFrame.maxX >= scene.size.width)
        #expect(backdropFrame.minY <= 0)
        #expect(backdropFrame.maxY >= scene.size.height)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```
Expected: BUILD FAILS — the new `ForTesting` accessors don't exist yet.

- [ ] **Step 3: Implement the vertical layout**

All changes in `Pyxis/BattleScene.swift`.

**3a. Replace the gate-point/lane stored properties** (lines ~82–84):

```swift
    private var castleGatePoints: [BattleLane: CGPoint] = [:]
    private var enemyGatePoints: [BattleLane: CGPoint] = [:]
    private var laneNodes: [SKShapeNode] = []
    private var laneIndicatorNodes: [SKNode] = []
```

(Delete `castleGatePoint`, `enemyGatePoint`, and `battleGroundLane`.) Add a convenience for city-level effects:

```swift
    private var enemyCityImpactPoint: CGPoint {
        enemyGatePoints[.center] ?? .zero
    }
```

**3b. Track each soldier node's lane.** Extend `SoldierNodeBundle`:

```swift
    private struct SoldierNodeBundle {
        let root: SKNode
        let body: SKNode
        let hpBarBackground: SKShapeNode
        let hpBarFill: SKShapeNode
        let lane: BattleLane
    }
```

In `createSoldierNode(id:)`, the `soldier` constant is already fetched; pass its lane when storing the bundle:

```swift
        soldierNodes[id] = SoldierNodeBundle(
            root: root,
            body: body,
            hpBarBackground: hpBackground,
            hpBarFill: hpFill,
            lane: soldier.lane
        )
```

**3c. Replace `layoutBattlefield(contentWidth:hpBarBottomY:spawnButtonTopY:feedbackY:)`** wholesale:

```swift
    private func layoutBattlefield(
        contentWidth: CGFloat,
        hpBarBottomY: CGFloat,
        spawnButtonTopY: CGFloat,
        feedbackY: CGFloat
    ) {
        #if DEBUG
        battlefieldLayoutCount += 1
        #endif
        let actualGap = hpBarBottomY - spawnButtonTopY
        let verticalPadding: CGFloat = 8
        let feedbackClearance = max(30, feedbackLabel.fontSize + 18)
        let safeTopY = hpBarBottomY - verticalPadding
        let safeBottomY = max(spawnButtonTopY + verticalPadding, feedbackY + feedbackClearance)
        battlefieldLayoutFrame = CGRect(
            x: (size.width - contentWidth) / 2,
            y: safeBottomY,
            width: contentWidth,
            height: max(0, safeTopY - safeBottomY)
        )
        let availableHeight = safeTopY - safeBottomY

        if !isConquestPopupVisible {
            cancelCityFeedbackActions()
        }

        let structureHeight = min(96, size.height * 0.16, contentWidth * 0.30, max(0, availableHeight * 0.32))
        let minimumStructureHeight: CGFloat = 28
        let minimumLaneLength: CGFloat = 60

        // The castle stands inside the field; the enemy city's base anchors at the
        // field's top edge and its sprite extends up behind the floating HUD.
        let castleGateY = safeBottomY + structureHeight
        let enemyGateY = safeTopY

        guard availableHeight >= 44,
              structureHeight >= minimumStructureHeight,
              enemyGateY - castleGateY >= minimumLaneLength else {
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            let fallbackY = spawnButtonTopY + max(10, actualGap * 0.25)
            for lane in BattleLane.allCases {
                let x = size.width * (0.25 + 0.25 * CGFloat(lane.rawValue))
                castleGatePoints[lane] = CGPoint(x: x, y: fallbackY)
                enemyGatePoints[lane] = CGPoint(x: x, y: fallbackY)
            }
            return
        }

        setBattlefieldHidden(false)

        if let battlefieldBackdropNode {
            battlefieldBackdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
            battlefieldBackdropNode.setScale(1)
            let scale = max(
                size.width / max(1, battlefieldBackdropNode.size.width),
                size.height / max(1, battlefieldBackdropNode.size.height)
            )
            battlefieldBackdropNode.setScale(scale)
        }

        if let playerCastleNode {
            fitBattleNode(playerCastleNode, targetHeight: structureHeight)
        }
        if let enemyCityNode {
            fitBattleNode(enemyCityNode, targetHeight: structureHeight * 1.04)
        }

        let centerX = size.width / 2
        playerCastleNode?.position = CGPoint(x: centerX, y: safeBottomY)
        enemyCityNode?.position = CGPoint(x: centerX, y: safeTopY)

        for lane in BattleLane.allCases {
            let x = battlefieldLayoutFrame.minX
                + battlefieldLayoutFrame.width * (0.25 + 0.25 * CGFloat(lane.rawValue))
            castleGatePoints[lane] = CGPoint(x: x, y: castleGateY)
            enemyGatePoints[lane] = CGPoint(x: x, y: enemyGateY)
        }

        drawLanePaths()
        layoutLaneIndicators()
        syncSoldierNodes()
    }
```

**Backdrop scaling note:** the original code never reset the node scale before reading `size`, because `setScale` on an `SKSpriteNode` changes `size`. The `setScale(1)` line above fixes that latent re-layout bug — keep it.

**3d. Replace `drawGroundLane(from:to:)` and `groundLaneHeight()`** with:

```swift
    private func drawLanePaths() {
        removeLaneNodes()

        let laneWidth = lanePathWidth()
        for lane in BattleLane.allCases {
            guard let start = castleGatePoints[lane], let end = enemyGatePoints[lane] else {
                continue
            }

            let laneRect = CGRect(
                x: start.x - laneWidth / 2,
                y: start.y,
                width: laneWidth,
                height: max(0, end.y - start.y)
            )
            let node = SKShapeNode(rect: laneRect, cornerRadius: laneWidth / 2)
            node.name = "battleLanePath-\(lane.rawValue)"
            node.fillColor = SKColor(red: 0.25, green: 0.34, blue: 0.27, alpha: 1.0)
            node.strokeColor = SKColor(red: 0.43, green: 0.52, blue: 0.36, alpha: 1.0)
            node.lineWidth = 2
            node.zPosition = -1
            environmentLayer.addChild(node)
            laneNodes.append(node)
        }
    }

    private func removeLaneNodes() {
        laneNodes.forEach { $0.removeFromParent() }
        laneNodes.removeAll()
    }

    private func lanePathWidth() -> CGFloat {
        max(14, min(26, size.width * 0.05))
    }
```

Also delete the `private var battleGroundLane: SKShapeNode?` usages — the guard branch previously did `battleGroundLane?.removeFromParent()`; that is now `removeLaneNodes()` (already in 3c).

For this task, add placeholder indicator helpers (Task 9 fills them in):

```swift
    private func layoutLaneIndicators() {
        removeLaneIndicatorNodes()
    }

    private func removeLaneIndicatorNodes() {
        laneIndicatorNodes.forEach { $0.removeFromParent() }
        laneIndicatorNodes.removeAll()
    }
```

**3e. Replace `pointForSoldierPosition(_:)`** with a lane-aware projection, and update `syncSoldierNodes()`:

```swift
    private func point(forLane lane: BattleLane, position: Double) -> CGPoint {
        let clamped = CGFloat(min(max(0, position), 1))
        let start = castleGatePoints[lane] ?? .zero
        let end = enemyGatePoints[lane] ?? start
        return CGPoint(
            x: start.x + (end.x - start.x) * clamped,
            y: start.y + (end.y - start.y) * clamped
        )
    }
```

In `syncSoldierNodes()`, replace
`bundle.root.position = pointForSoldierPosition(soldier.position)` with
`bundle.root.position = point(forLane: soldier.lane, position: soldier.position)`.

**3f. Update effect origins:**

- `playImpactFlash()`: `flash.position = enemyGatePoint` → `flash.position = enemyCityImpactPoint`
- `applyCombatResult(_:)`: both `playFloatingFeedback(text:..., at: enemyGatePoint)` calls → `at: enemyCityImpactPoint`
- `playTowerShot(at:)`: `shot.position = enemyGatePoint` → `shot.position = enemyGatePoints[bundle.lane] ?? enemyCityImpactPoint` (the `bundle` constant already exists in that function)
- `playSoldierAttackFeedback(for:)`: soldiers now march upward, so the lunge is vertical:

```swift
        let lunge = SKAction.moveBy(x: 0, y: 8, duration: 0.06)
        let back = SKAction.moveBy(x: 0, y: -8, duration: 0.08)
```

**3g. Add the testing accessors** to the `#if DEBUG` extension:

```swift
    var enemyCityFrameForTesting: CGRect? {
        enemyCityNode.map { $0.calculateAccumulatedFrame() }
    }

    var playerCastleFrameForTesting: CGRect? {
        playerCastleNode.map { $0.calculateAccumulatedFrame() }
    }

    var battlefieldBackdropFrameForTesting: CGRect? {
        battlefieldBackdropNode?.calculateAccumulatedFrame()
    }

    var laneCenterXsForTesting: [CGFloat] {
        BattleLane.allCases.compactMap { enemyGatePoints[$0]?.x }
    }

    func castleGatePointForTesting(lane: BattleLane) -> CGPoint? {
        castleGatePoints[lane]
    }

    func enemyGatePointForTesting(lane: BattleLane) -> CGPoint? {
        enemyGatePoints[lane]
    }

    var soldierLanePlacementsForTesting: [(lane: BattleLane, nodePosition: CGPoint)] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            soldierNodes[soldier.id].map { (lane: soldier.lane, nodePosition: $0.root.position) }
        }
    }
```

- [ ] **Step 4: Run the scene tests**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```
Expected: TEST SUCCEEDED — new tests pass AND the pre-existing layout tests (`commanderHUDKeepsTopClustersAndActionsInsideScene`, `commanderHUDSurvivesCompactLandscapeWithoutOverlap`, the manual-type-menu tests) still pass, because `battlefieldLayoutFrame` keeps the same bounds (the lane field between bottom controls and HUD).

If a compact-size test fails on the new `minimumLaneLength` guard hiding the battlefield, that's acceptable behavior (the guard frames stay consistent) — but verify the failing assertion is about battlefield emptiness, not an overlap regression, before adjusting `minimumLaneLength` downward (floor 44).

- [ ] **Step 5: Run the full unit suite for regressions**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests
```
Expected: TEST SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Rotate battlefield vertical with three marching lanes"
```

---

### Task 9: Lane defense indicators

**Files:**
- Modify: `Pyxis/BattleScene.swift` (fill in `layoutLaneIndicators()`, add `makeLaneIndicator(role:)`)
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `PyxisTests/BattleSceneTests.swift`:

```swift
    @Test func laneIndicatorsMarkFortifiedAndExposedLanesOnly() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // City 1: left fortified, center standard, right exposed.
        let indicators = scene.laneIndicatorsForTesting
        #expect(indicators.count == 2)

        let fortified = try #require(indicators.first { $0.role == .fortified })
        let exposed = try #require(indicators.first { $0.role == .exposed })
        let leftGateX = try #require(scene.enemyGatePointForTesting(lane: .left)?.x)
        let rightGateX = try #require(scene.enemyGatePointForTesting(lane: .right)?.x)

        #expect(abs(fortified.position.x - leftGateX) <= 0.5)
        #expect(abs(exposed.position.x - rightGateX) <= 0.5)
        #expect(indicators.allSatisfy { $0.role != .standard })
    }
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests/laneIndicatorsMarkFortifiedAndExposedLanesOnly
```
Expected: BUILD FAILS — `laneIndicatorsForTesting` not found.

- [ ] **Step 3: Implement**

In `Pyxis/BattleScene.swift`, replace the Task 8 placeholder `layoutLaneIndicators()`:

```swift
    private func layoutLaneIndicators() {
        removeLaneIndicatorNodes()

        let profile = state.currentCityLaneDefenseProfile
        for lane in BattleLane.allCases {
            let role = profile.role(for: lane)
            guard role != .standard, let gate = enemyGatePoints[lane] else {
                continue
            }

            let indicator = makeLaneIndicator(role: role)
            indicator.position = CGPoint(x: gate.x, y: gate.y - 18)
            indicator.zPosition = 2
            environmentLayer.addChild(indicator)
            laneIndicatorNodes.append(indicator)
        }
    }

    private func makeLaneIndicator(role: LaneDefenseRole) -> SKNode {
        let container = SKNode()
        container.name = "laneIndicator-\(role.rawValue)"

        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: 0, y: 9))
        shieldPath.addLine(to: CGPoint(x: 8, y: 5))
        shieldPath.addLine(to: CGPoint(x: 8, y: -2))
        shieldPath.addCurve(
            to: CGPoint(x: 0, y: -10),
            control1: CGPoint(x: 8, y: -6),
            control2: CGPoint(x: 5, y: -9)
        )
        shieldPath.addCurve(
            to: CGPoint(x: -8, y: -2),
            control1: CGPoint(x: -5, y: -9),
            control2: CGPoint(x: -8, y: -6)
        )
        shieldPath.addLine(to: CGPoint(x: -8, y: 5))
        shieldPath.closeSubpath()

        let shield = SKShapeNode(path: shieldPath)
        shield.lineWidth = 1.5

        switch role {
        case .fortified:
            shield.fillColor = GameUITheme.Color.danger
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.7)
        case .exposed:
            shield.fillColor = SKColor(white: 0.55, alpha: 0.55)
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            let crackPath = CGMutablePath()
            crackPath.move(to: CGPoint(x: -2, y: 9))
            crackPath.addLine(to: CGPoint(x: 2, y: 2))
            crackPath.addLine(to: CGPoint(x: -1, y: -3))
            crackPath.addLine(to: CGPoint(x: 2, y: -10))
            let crack = SKShapeNode(path: crackPath)
            crack.strokeColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)
            crack.lineWidth = 2
            crack.zPosition = 1
            container.addChild(crack)
        case .standard:
            break
        }

        container.addChild(shield)
        return container
    }
```

Add the testing accessor to the `#if DEBUG` extension:

```swift
    var laneIndicatorsForTesting: [(role: LaneDefenseRole, position: CGPoint)] {
        laneIndicatorNodes.compactMap { node in
            guard let name = node.name,
                  name.hasPrefix("laneIndicator-"),
                  let role = LaneDefenseRole(rawValue: String(name.dropFirst("laneIndicator-".count)))
            else {
                return nil
            }
            return (role: role, position: node.position)
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Same command as Step 2. Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Show shield indicators on fortified and exposed lanes"
```

---

### Task 10: Full verification, docs, lint

**Files:**
- Modify: `CLAUDE.md` (architecture notes)

- [ ] **Step 1: Run the complete test suite (unit + UI)**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```
Expected: TEST SUCCEEDED. UI tests should pass untouched (no accessibility identifiers or button flows changed). If a UI test fails, inspect whether it asserts battlefield geometry before changing anything.

- [ ] **Step 2: Lint**

```bash
swiftlint lint
```
Expected: no new violations in the touched files.

- [ ] **Step 3: Update CLAUDE.md architecture notes**

In `CLAUDE.md` section "## Architecture":

- In item **3** (`BattleCombatState`), after "Soldier HP and range vary by type." add:

```markdown
Each soldier is randomly assigned one of three `BattleLane`s (`left`/`center`/`right`) at spawn via a seedable internal PRNG (`SplitMix64`); the tower targets a random occupied lane per shot and scales its damage by `Configuration.laneDamageMultipliers`. `LaneDefenseProfile` (`Pyxis/LaneDefenseProfile.swift`) deterministically assigns each city one fortified (1.25× tower damage), one exposed (0.80×), and one standard lane from the city number; `KingdomGameState.currentCityLaneDefenseProfile` exposes it and `BattleScene` feeds it into the combat configuration.
```

- In item **5**'s `BattleScene` bullet, update the description to mention the vertical battlefield, e.g. change "mirrors `TickResult` into UI (HP bar, soldier nodes, conquest popup)" to "mirrors `TickResult` into UI (HP bar, soldier nodes, conquest popup) on a vertical full-screen battlefield (enemy city top, player castle bottom, three marching lanes)".

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Document lane-based battlefield in architecture notes"
```

- [ ] **Step 5: Update the Linear issue**

Mark HPA-50 as done / in review per the user's workflow (ask if unsure).

---

## Self-Review Notes

- **Spec coverage:** vertical layout (Task 8), 3 lanes + random spawn (Task 2), per-lane tower targeting (Task 3), lane damage modifiers (Task 4), per-city deterministic profile (Tasks 5–6), scene wiring (Task 7), full-screen backdrop + floating HUD (Task 8), lane indicators (Task 9), idle progress untouched (no task needed — verified by full suite in Task 10).
- **Known risk:** pre-existing `BattleSceneTests` layout assertions treat `battlefieldLayoutFrame` as the area between HUD and bottom controls; the plan deliberately keeps that frame's bounds identical so those tests stay green. The enemy city sprite extending up behind the HUD is intentional and not part of that frame.
- **Determinism:** RNG is consumed on (a) spawn without explicit lane and (b) tower lane choice when 2+ lanes are occupied in range. Model tests that need exact outcomes either pass explicit lanes or use a fixed seed.
