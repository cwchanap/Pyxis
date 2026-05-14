# Live Tower Combat Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add real-time tower defense to Pyxis battles so spawned soldiers have HP, DEF, attack speed, attack range, movement speed, and remain in battle until killed or the city is conquered.

**Architecture:** Keep durable campaign and economy rules in `KingdomGameState`. Add a SpriteKit-free `BattleCombatState` for temporary live battle simulation, then have `BattleScene` render and drive that model from `update(_:)`. Live soldiers are not persisted; city HP, gold, upgrades, idle catch-up, and map gates remain durable.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, `UserDefaults`, Xcode file-system-synchronized groups.

---

## Current Project Notes

- Spec: `docs/superpowers/specs/2026-05-14-live-tower-combat-design.md`
- Main battle scene: `Pyxis/BattleScene.swift`
- Durable model: `Pyxis/KingdomGameState.swift`
- Unit tests use Swift Testing under `PyxisTests/`.
- UI tests use XCTest under `PyxisUITests/`.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`; new Swift files under `Pyxis/` and `PyxisTests/` should be picked up without editing `Pyxis.xcodeproj/project.pbxproj`.
- Keep `KingdomGameState` and the new `BattleCombatState` free of `SpriteKit` and `UIKit` imports.
- Preserve the existing player contract: the player only taps `Spawn Soldier`; soldiers automatically move, attack, and take tower damage.
- Preserve the attack-power-only upgrade button in this slice.
- Preserve idle catch-up as abstract city damage capped at 8 hours. Do not simulate live soldiers while backgrounded.

## Verification Commands

Use focused tests while implementing:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Run the full suite before finishing:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

If `iPhone 16` is not available locally, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun with an available iOS Simulator destination.

---

### Task 1: Add Live Combat Spawn And Stat Model

**Files:**
- Create: `Pyxis/BattleCombatState.swift`
- Create: `PyxisTests/BattleCombatStateTests.swift`

**Step 1: Write the failing spawn/stat tests**

Create `PyxisTests/BattleCombatStateTests.swift`:

```swift
//
//  BattleCombatStateTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct BattleCombatStateTests {
    @Test func spawningCreatesSoldierWithFullHPAndConfiguredStats() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 12,
                soldierDefense: 3,
                soldierAttackSpeed: 1.5,
                soldierAttackRange: 0.10,
                soldierMovementSpeed: 0.40,
                towerDamage: 4,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.50,
                maxDeltaTime: 0.25
            )
        )

        let id = combat.spawnSoldier(attackPower: 7)

        #expect(combat.livingSoldierCount == 1)
        let soldier = try #require(combat.soldier(id: id))
        #expect(soldier.maxHP == 12)
        #expect(soldier.currentHP == 12)
        #expect(soldier.defense == 3)
        #expect(soldier.attackPower == 7)
        #expect(soldier.attackSpeed == 1.5)
        #expect(soldier.attackRange == 0.10)
        #expect(soldier.movementSpeed == 0.40)
        #expect(soldier.position == 0)
        #expect(soldier.isAlive)
    }

    @Test func liveConfigurationScalesTowerDamageByCityLevel() {
        let cityOne = BattleCombatState.Configuration.live(cityLevel: 1)
        let cityFive = BattleCombatState.Configuration.live(cityLevel: 5)

        #expect(cityOne.soldierMaxHP == 10)
        #expect(cityOne.soldierDefense == 1)
        #expect(cityOne.soldierAttackSpeed == 1.0)
        #expect(cityOne.soldierAttackRange == 0.12)
        #expect(cityOne.soldierMovementSpeed == 0.45)
        #expect(cityOne.towerDamage == 2)
        #expect(cityOne.towerAttackSpeed == 0.8)
        #expect(cityOne.towerAttackRange == 0.55)

        #expect(cityFive.towerDamage > cityOne.towerDamage)
        #expect(cityFive.towerAttackSpeed == cityOne.towerAttackSpeed)
        #expect(cityFive.towerAttackRange == cityOne.towerAttackRange)
    }
}
```

**Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: FAIL at compile time because `BattleCombatState` does not exist.

**Step 3: Add the minimal combat model and stat configuration**

Create `Pyxis/BattleCombatState.swift`:

```swift
//
//  BattleCombatState.swift
//  Pyxis
//

import Foundation

struct BattleCombatState: Equatable {
    typealias SoldierID = Int

    struct Configuration: Equatable {
        let soldierMaxHP: Int
        let soldierDefense: Int
        let soldierAttackSpeed: Double
        let soldierAttackRange: Double
        let soldierMovementSpeed: Double
        let towerDamage: Int
        let towerAttackSpeed: Double
        let towerAttackRange: Double
        let maxDeltaTime: Double

        static func live(cityLevel: Int) -> Configuration {
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
                maxDeltaTime: 0.25
            )
        }
    }

    struct Soldier: Equatable, Identifiable {
        let id: SoldierID
        let maxHP: Int
        var currentHP: Int
        let defense: Int
        let attackPower: Int
        let attackSpeed: Double
        let attackRange: Double
        let movementSpeed: Double
        var position: Double
        var attackCooldownRemaining: Double

        var isAlive: Bool {
            currentHP > 0
        }
    }

    let configuration: Configuration
    private(set) var soldiers: [Soldier]
    private var nextSoldierID: SoldierID

    init(configuration: Configuration) {
        self.configuration = configuration
        self.soldiers = []
        self.nextSoldierID = 1
    }

    init(cityLevel: Int) {
        self.init(configuration: .live(cityLevel: cityLevel))
    }

    var livingSoldierCount: Int {
        soldiers.filter(\.isAlive).count
    }

    @discardableResult
    mutating func spawnSoldier(attackPower: Int) -> SoldierID {
        let id = nextSoldierID
        nextSoldierID += 1

        soldiers.append(
            Soldier(
                id: id,
                maxHP: max(1, configuration.soldierMaxHP),
                currentHP: max(1, configuration.soldierMaxHP),
                defense: max(0, configuration.soldierDefense),
                attackPower: max(1, attackPower),
                attackSpeed: max(0.1, configuration.soldierAttackSpeed),
                attackRange: min(max(0, configuration.soldierAttackRange), 1),
                movementSpeed: max(0, configuration.soldierMovementSpeed),
                position: 0,
                attackCooldownRemaining: 0
            )
        )

        return id
    }

    func soldier(id: SoldierID) -> Soldier? {
        soldiers.first { $0.id == id }
    }
}
```

**Step 4: Run the focused tests to verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Add live combat soldier model"
```

---

### Task 2: Add Soldier Movement And Repeated City Attacks

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

**Step 1: Add failing movement and attack tests**

Append these tests inside `BattleCombatStateTests`:

```swift
@Test func soldierMovesTowardCityUntilInAttackRange() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 1,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0.20,
            soldierMovementSpeed: 0.50,
            towerDamage: 0,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0,
            maxDeltaTime: 1.0
        )
    )
    let id = combat.spawnSoldier(attackPower: 3)

    let firstTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
    #expect(firstTick.cityDamage == 0)
    #expect(try #require(combat.soldier(id: id)).position == 0.50)

    let secondTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
    let soldier = try #require(combat.soldier(id: id))
    #expect(soldier.position == 0.80)
    #expect(secondTick.cityDamage == 3)
    #expect(secondTick.soldierAttackIDs == [id])
}

@Test func soldierAttacksRepeatedlyOnCooldownWhileInRange() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 1,
            soldierAttackSpeed: 2.0,
            soldierAttackRange: 1.0,
            soldierMovementSpeed: 0,
            towerDamage: 0,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0,
            maxDeltaTime: 1.0
        )
    )
    let id = combat.spawnSoldier(attackPower: 4)

    let firstTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
    #expect(firstTick.cityDamage == 4)
    #expect(firstTick.soldierAttackIDs == [id])

    let cooldownTick = combat.tick(deltaTime: 0.2, cityRemainingHP: 16)
    #expect(cooldownTick.cityDamage == 0)
    #expect(cooldownTick.soldierAttackIDs.isEmpty)

    let secondAttackTick = combat.tick(deltaTime: 0.3, cityRemainingHP: 16)
    #expect(secondAttackTick.cityDamage == 4)
    #expect(secondAttackTick.soldierAttackIDs == [id])
}

@Test func emittedCityDamageIsCappedToRemainingHP() {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 1,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 1.0,
            soldierMovementSpeed: 0,
            towerDamage: 0,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0,
            maxDeltaTime: 1.0
        )
    )
    _ = combat.spawnSoldier(attackPower: 8)

    let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 3)

    #expect(result.cityDamage == 3)
    #expect(result.didReachConquest)
}
```

**Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: FAIL because `tick(deltaTime:cityRemainingHP:)` and `TickResult` do not exist.

**Step 3: Implement tick result, movement, attack range, and attack cooldowns**

Update `Pyxis/BattleCombatState.swift`.

Add this nested result type:

```swift
struct TickResult: Equatable {
    var cityDamage: Int = 0
    var didReachConquest = false
    var soldierAttackIDs: [SoldierID] = []
    var towerShots: [TowerShot] = []
    var damagedSoldierIDs: [SoldierID] = []
    var killedSoldierIDs: [SoldierID] = []
}
```

Temporarily define `TowerShot` so later tower work can fill it in:

```swift
struct TowerShot: Equatable {
    let soldierID: SoldierID
    let damage: Int
}
```

Add the tick implementation:

```swift
@discardableResult
mutating func tick(deltaTime rawDeltaTime: Double, cityRemainingHP: Int) -> TickResult {
    let deltaTime = clampedDeltaTime(rawDeltaTime)
    guard deltaTime > 0, cityRemainingHP > 0 else {
        return TickResult()
    }

    var result = TickResult()
    var remainingCityHP = max(0, cityRemainingHP)

    for index in soldiers.indices where soldiers[index].isAlive {
        advanceMovement(forSoldierAt: index, deltaTime: deltaTime)

        guard isInAttackRange(soldiers[index]) else {
            continue
        }

        soldiers[index].attackCooldownRemaining -= deltaTime

        if soldiers[index].attackCooldownRemaining <= 0 {
            let appliedDamage = min(soldiers[index].attackPower, remainingCityHP)
            result.cityDamage += appliedDamage
            result.soldierAttackIDs.append(soldiers[index].id)
            remainingCityHP -= appliedDamage
            soldiers[index].attackCooldownRemaining += attackInterval(for: soldiers[index])
        }

        if remainingCityHP <= 0 {
            result.didReachConquest = true
            break
        }
    }

    return result
}

private func clampedDeltaTime(_ rawDeltaTime: Double) -> Double {
    min(max(0, rawDeltaTime), max(0.01, configuration.maxDeltaTime))
}

private mutating func advanceMovement(forSoldierAt index: Int, deltaTime: Double) {
    guard !isInAttackRange(soldiers[index]) else {
        return
    }

    let attackPosition = max(0, 1.0 - soldiers[index].attackRange)
    soldiers[index].position = min(
        attackPosition,
        soldiers[index].position + soldiers[index].movementSpeed * deltaTime
    )
}

private func isInAttackRange(_ soldier: Soldier) -> Bool {
    soldier.position >= 1.0 - soldier.attackRange
}

private func attackInterval(for soldier: Soldier) -> Double {
    1.0 / max(0.1, soldier.attackSpeed)
}
```

**Step 4: Run the focused tests to verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Add live combat movement and attacks"
```

---

### Task 3: Add Tower Targeting, Soldier Damage, And Death

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

**Step 1: Add failing tower tests**

Append these tests inside `BattleCombatStateTests`:

```swift
@Test func towerDamagesLivingSoldierInRangeWithDefenseMinimumOne() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 4,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 4,
            towerAttackSpeed: 1.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
    )
    let id = combat.spawnSoldier(attackPower: 1)

    let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

    #expect(result.towerShots == [BattleCombatState.TowerShot(soldierID: id, damage: 1)])
    #expect(result.damagedSoldierIDs == [id])
    #expect(try #require(combat.soldier(id: id)).currentHP == 9)
}

@Test func towerTargetsLivingSoldierClosestToCity() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 0.5,
            towerDamage: 2,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0.70,
            maxDeltaTime: 1.0
        )
    )
    let first = combat.spawnSoldier(attackPower: 1)
    _ = combat.tick(deltaTime: 0.7, cityRemainingHP: 20)
    let second = combat.spawnSoldier(attackPower: 1)

    let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

    #expect(result.towerShots == [BattleCombatState.TowerShot(soldierID: first, damage: 2)])
    #expect(try #require(combat.soldier(id: first)).currentHP == 8)
    #expect(try #require(combat.soldier(id: second)).currentHP == 10)
}

@Test func soldierDiesOnlyWhenHPReachesZeroAndStopsActing() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 2,
            soldierDefense: 0,
            soldierAttackSpeed: 10.0,
            soldierAttackRange: 1.0,
            soldierMovementSpeed: 0,
            towerDamage: 2,
            towerAttackSpeed: 10.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
    )
    let id = combat.spawnSoldier(attackPower: 3)

    let killTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
    #expect(killTick.killedSoldierIDs == [id])
    #expect(try #require(combat.soldier(id: id)).currentHP == 0)
    #expect(!((try #require(combat.soldier(id: id))).isAlive))

    let laterTick = combat.tick(deltaTime: 0.2, cityRemainingHP: 20)
    #expect(laterTick.cityDamage == 0)
    #expect(laterTick.towerShots.isEmpty)
    #expect(laterTick.soldierAttackIDs.isEmpty)
}

@Test func largeTickDeltasAreClamped() throws {
    var combat = BattleCombatState(
        configuration: BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0.20,
            soldierMovementSpeed: 1.0,
            towerDamage: 0,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0,
            maxDeltaTime: 0.25
        )
    )
    let id = combat.spawnSoldier(attackPower: 1)

    _ = combat.tick(deltaTime: 10.0, cityRemainingHP: 20)

    #expect(try #require(combat.soldier(id: id)).position == 0.25)
}
```

**Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: FAIL because tower damage and soldier death are not implemented.

**Step 3: Add tower cooldown state and targeting**

Update `Pyxis/BattleCombatState.swift`.

Add this stored property:

```swift
private var towerCooldownRemaining: Double
```

Initialize it to `0` in both initializers.

Update `tick(deltaTime:cityRemainingHP:)` so tower damage resolves before soldier attacks:

```swift
towerCooldownRemaining -= deltaTime
if towerCooldownRemaining <= 0, let targetIndex = towerTargetIndex() {
    let damage = damageAgainstSoldier(soldiers[targetIndex])
    soldiers[targetIndex].currentHP = max(0, soldiers[targetIndex].currentHP - damage)
    let soldierID = soldiers[targetIndex].id
    result.towerShots.append(TowerShot(soldierID: soldierID, damage: damage))
    result.damagedSoldierIDs.append(soldierID)

    if !soldiers[targetIndex].isAlive {
        result.killedSoldierIDs.append(soldierID)
    }

    towerCooldownRemaining += towerAttackInterval()
}
```

Add helper methods:

```swift
private func towerTargetIndex() -> Int? {
    soldiers.indices
        .filter { soldiers[$0].isAlive && isInTowerRange(soldiers[$0]) }
        .max { soldiers[$0].position < soldiers[$1].position }
}

private func isInTowerRange(_ soldier: Soldier) -> Bool {
    soldier.position >= 1.0 - configuration.towerAttackRange
}

private func damageAgainstSoldier(_ soldier: Soldier) -> Int {
    max(1, max(0, configuration.towerDamage) - soldier.defense)
}

private func towerAttackInterval() -> Double {
    1.0 / max(0.1, configuration.towerAttackSpeed)
}
```

Make sure the existing movement/attack loop skips soldiers that died from tower damage in the same tick.

**Step 4: Run the focused tests to verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Add tower attacks to live combat"
```

---

### Task 4: Add Durable Live Combat City Damage

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

**Step 1: Add failing durable damage tests**

Append these tests inside `KingdomGameStateTests`:

```swift
@Test func liveCombatDamageReducesCurrentCityHP() {
    var state = KingdomGameState(cityRemainingPower: 20)

    let result = state.applyLiveCombatDamage(6)

    #expect(result.attackApplied)
    #expect(result.damageDealt == 6)
    #expect(result.conqueredCities == 0)
    #expect(result.goldEarned == 0)
    #expect(state.cityRemainingPower == 14)
    #expect(state.stageStatus == .battleActive)
}

@Test func liveCombatDamageIsCappedAndConquersCurrentCity() {
    var state = KingdomGameState(cityRemainingPower: 3)

    let result = state.applyLiveCombatDamage(9)

    #expect(result.attackApplied)
    #expect(result.damageDealt == 3)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.cityRemainingPower == 0)
    #expect(state.completedCityCount == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}

@Test func liveCombatDamageIsRejectedWhenBattleIsPaused() {
    var state = KingdomGameState(cityRemainingPower: 1)
    _ = state.spawnSoldierAttack()

    let result = state.applyLiveCombatDamage(5)

    #expect(!result.attackApplied)
    #expect(result.damageDealt == 0)
    #expect(state.gold == 8)
    #expect(state.cityRemainingPower == 0)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}
```

**Step 2: Run focused tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: FAIL because `applyLiveCombatDamage(_:)` does not exist.

**Step 3: Implement capped live combat damage**

Update `Pyxis/KingdomGameState.swift`.

Add the method:

```swift
@discardableResult
mutating func applyLiveCombatDamage(_ rawDamage: Int) -> AttackResult {
    guard stageStatus == .battleActive else {
        return .blocked
    }

    let damage = max(0, rawDamage)
    guard damage > 0 else {
        return AttackResult(attackApplied: true, damageDealt: 0, conqueredCities: 0, goldEarned: 0)
    }

    let appliedDamage = min(damage, cityRemainingPower)
    cityRemainingPower -= appliedDamage

    guard cityRemainingPower <= 0 else {
        return AttackResult(attackApplied: true, damageDealt: appliedDamage, conqueredCities: 0, goldEarned: 0)
    }

    let reward = completeCurrentCity()

    return AttackResult(attackApplied: true, damageDealt: appliedDamage, conqueredCities: 1, goldEarned: reward)
}
```

Extract the duplicated conquest mutation from `spawnSoldierAttack()` and `returnFromBackground(at:)` into a private helper:

```swift
private mutating func completeCurrentCity() -> Int {
    let reward = currentGoldReward
    gold += reward
    cityRemainingPower = 0
    completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

    if completedCityCount >= Self.firstCountryCityCount {
        stageStatus = .countryComplete
    } else {
        stageStatus = .cityConqueredPendingMap
    }

    return reward
}
```

Keep `spawnSoldierAttack()` behavior compatible with existing tests. It may still return the full soldier attack power in `damageDealt`; `applyLiveCombatDamage(_:)` returns the capped applied damage used by live combat.

**Step 4: Run focused model tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add durable live combat city damage"
```

---

### Task 5: Replace Pending Impact Scene Tests With Live Combat Tests

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify later: `Pyxis/BattleScene.swift`

**Step 1: Rewrite scene tests around live combat semantics**

In `PyxisTests/BattleSceneTests.swift`, replace tests that use `pendingSoldierAttackCountForTesting` and `completeFirstPendingSoldierAttackForTesting()` with live-combat tests.

Keep:

- `battleSceneDisplaysCampaignCityTitle`
- `closingConquestPopupRequestsCountryMapRoute`
- `closingConquestPopupWithoutRouterKeepsPopupVisible`

Replace the other combat tests with:

```swift
@Test func tappingSpawnCreatesLiveCombatSoldierWithoutImmediateCityDamage() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()

    #expect(scene.liveSoldierCountForTesting == 1)
    #expect(scene.cityRemainingPowerForTesting == 20)
    #expect(store.load().cityRemainingPower == 20)
}

@Test func combatTickCanDamageDurableCityHPAndSaveIt() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3.0)

    #expect(scene.liveSoldierCountForTesting == 1)
    #expect(store.load().cityRemainingPower < 20)
}

@Test func towerDamageCanKillAndRemoveVisibleSoldier() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 18.0)

    #expect(scene.liveSoldierCountForTesting == 0)
}

@Test func liveCombatConquestClearsSoldiersAndShowsPopup() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1, normalSoldierUpgradeLevel: 4))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3.0)

    let savedState = store.load()
    #expect(scene.liveSoldierCountForTesting == 0)
    #expect(scene.isConquestPopupVisibleForTesting)
    #expect(savedState.gold == 8)
    #expect(savedState.completedCityCount == 1)
    #expect(savedState.stageStatus == .cityConqueredPendingMap)
}

@Test func idleConquestClearsLiveSoldiersBeforeShowingPopup() throws {
    let store = try makeStore(
        initialState: KingdomGameState(
            cityRemainingPower: 1,
            lastBackgroundedAt: Date(timeIntervalSinceNow: -2)
        )
    )
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()
    #expect(scene.liveSoldierCountForTesting == 1)

    NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

    let savedState = store.load()
    #expect(scene.liveSoldierCountForTesting == 0)
    #expect(scene.isConquestPopupVisibleForTesting)
    #expect(savedState.gold == 8)
    #expect(savedState.completedCityCount == 1)
    #expect(savedState.stageStatus == .cityConqueredPendingMap)
}
```

Update the popup tests so they conquer through live combat:

```swift
scene.spawnSoldierForTesting()
scene.advanceCombatForTesting(deltaTime: 3.0)
```

**Step 2: Run focused scene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because `liveSoldierCountForTesting` and `advanceCombatForTesting(deltaTime:)` do not exist, and scene still uses pending impact nodes.

**Step 3: Commit the failing test update**

```bash
git add PyxisTests/BattleSceneTests.swift
git commit -m "Update battle scene tests for live combat"
```

---

### Task 6: Integrate Live Combat Into `BattleScene`

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Test: `PyxisTests/BattleSceneTests.swift`

**Step 1: Add live combat properties**

In `Pyxis/BattleScene.swift`, remove the old pending-impact properties after this task has replacement code:

```swift
private var pendingSoldiers: [SKNode] = []
private let animationConfiguration = SoldierAnimationConfiguration.live
```

Add:

```swift
private var combat: BattleCombatState
private var lastUpdateTime: TimeInterval?
private var soldierNodes: [BattleCombatState.SoldierID: SoldierNodeBundle] = [:]
```

Add a render bundle near the existing private helper structs:

```swift
private struct SoldierNodeBundle {
    let root: SKNode
    let hpBarBackground: SKShapeNode
    let hpBarFill: SKShapeNode
}
```

Initialize `combat` in both initializers after loading state:

```swift
self.combat = BattleCombatState(cityLevel: self.state.cityLevel)
```

For `required init?(coder:)`, create the loaded state first, then initialize `combat` from it.

**Step 2: Drive combat from SpriteKit update**

Add:

```swift
override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)

    defer {
        lastUpdateTime = currentTime
    }

    guard let lastUpdateTime else {
        return
    }

    guard state.stageStatus == .battleActive, !isConquestPopupVisible else {
        return
    }

    advanceCombat(deltaTime: currentTime - lastUpdateTime)
}
```

Add:

```swift
private func advanceCombat(deltaTime: TimeInterval) {
    let result = combat.tick(deltaTime: deltaTime, cityRemainingHP: state.cityRemainingPower)
    applyCombatResult(result)
    syncSoldierNodes()
}

private func applyCombatResult(_ result: BattleCombatState.TickResult) {
    for towerShot in result.towerShots {
        playTowerShot(at: towerShot.soldierID)
    }

    for soldierID in result.soldierAttackIDs {
        playSoldierAttackFeedback(for: soldierID)
    }

    for soldierID in result.killedSoldierIDs {
        removeSoldierNode(id: soldierID, animated: true)
    }

    guard result.cityDamage > 0 else {
        return
    }

    let damageResult = state.applyLiveCombatDamage(result.cityDamage)
    let conqueredCity = damageResult.conqueredCities > 0

    if conqueredCity {
        clearLiveCombat()
        feedbackText = "\(state.displayCityTitle) conquered! +\(damageResult.goldEarned) gold."
    } else {
        feedbackText = "Soldiers dealt \(damageResult.damageDealt) damage."
    }

    store.save(state)
    redraw()

    if conqueredCity {
        playCityConquestFeedback()
        showConquestPopup(goldEarned: damageResult.goldEarned)
    } else {
        playCityHitFeedback()
    }
}
```

**Step 3: Change spawn to add a live soldier**

Replace `spawnSoldier()` body with:

```swift
private func spawnSoldier() {
    guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
        return
    }

    let soldierID = combat.spawnSoldier(attackPower: state.normalSoldierAttackPower)
    createSoldierNode(id: soldierID)
    syncSoldierNodes()
}
```

Add:

```swift
private func createSoldierNode(id: BattleCombatState.SoldierID) {
    let root = SKNode()
    root.name = BattleAssetName.normalSoldier

    let body = makeSoldierNode()
    root.addChild(body)

    let hpBackground = SKShapeNode()
    hpBackground.fillColor = SKColor(white: 0.05, alpha: 0.9)
    hpBackground.strokeColor = SKColor(white: 1.0, alpha: 0.3)
    hpBackground.lineWidth = 1

    let hpFill = SKShapeNode()
    hpFill.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.38, alpha: 1.0)
    hpFill.strokeColor = .clear

    root.addChild(hpBackground)
    root.addChild(hpFill)
    soldierLayer.addChild(root)
    soldierNodes[id] = SoldierNodeBundle(root: root, hpBarBackground: hpBackground, hpBarFill: hpFill)
}
```

**Step 4: Render soldier positions and HP bars**

Add:

```swift
private func syncSoldierNodes() {
    let liveSoldiers = combat.soldiers.filter(\.isAlive)
    let liveIDs = Set(liveSoldiers.map(\.id))

    for id in soldierNodes.keys where !liveIDs.contains(id) {
        removeSoldierNode(id: id, animated: false)
    }

    for soldier in liveSoldiers {
        if soldierNodes[soldier.id] == nil {
            createSoldierNode(id: soldier.id)
        }

        guard let bundle = soldierNodes[soldier.id] else {
            continue
        }

        bundle.root.position = pointForSoldierPosition(soldier.position)
        fitBattleNode(bundle.root, targetHeight: max(28, min(42, size.height * 0.05)))
        layoutSoldierHPBar(bundle, soldier: soldier)
    }
}

private func pointForSoldierPosition(_ position: Double) -> CGPoint {
    let clamped = CGFloat(min(max(0, position), 1))
    return CGPoint(
        x: castleGatePoint.x + (enemyGatePoint.x - castleGatePoint.x) * clamped,
        y: castleGatePoint.y + (enemyGatePoint.y - castleGatePoint.y) * clamped
    )
}

private func layoutSoldierHPBar(_ bundle: SoldierNodeBundle, soldier: BattleCombatState.Soldier) {
    let width: CGFloat = 28
    let height: CGFloat = 5
    let y: CGFloat = 36
    let percent = CGFloat(soldier.currentHP) / CGFloat(max(1, soldier.maxHP))

    bundle.hpBarBackground.path = CGPath(
        roundedRect: CGRect(x: -width / 2, y: y, width: width, height: height),
        cornerWidth: height / 2,
        cornerHeight: height / 2,
        transform: nil
    )
    bundle.hpBarFill.path = CGPath(
        roundedRect: CGRect(x: -width / 2, y: y, width: max(1, width * percent), height: height),
        cornerWidth: height / 2,
        cornerHeight: height / 2,
        transform: nil
    )
}
```

Update `layoutBattlefield(...)` so it calls `syncSoldierNodes()` instead of iterating `pendingSoldiers`.

**Step 5: Add clearing and visual feedback helpers**

Add:

```swift
private func clearLiveCombat() {
    combat = BattleCombatState(cityLevel: state.cityLevel)

    for id in Array(soldierNodes.keys) {
        removeSoldierNode(id: id, animated: false)
    }
}

private func removeSoldierNode(id: BattleCombatState.SoldierID, animated: Bool) {
    guard let bundle = soldierNodes.removeValue(forKey: id) else {
        return
    }

    bundle.root.removeAllActions()

    if animated {
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let remove = SKAction.removeFromParent()
        bundle.root.run(SKAction.sequence([fade, remove]))
    } else {
        bundle.root.removeFromParent()
    }
}
```

Add simple no-crash feedback helpers:

```swift
private func playTowerShot(at soldierID: BattleCombatState.SoldierID) {
    guard let bundle = soldierNodes[soldierID] else {
        return
    }

    let shot = SKShapeNode(circleOfRadius: 4)
    shot.fillColor = SKColor(red: 1.0, green: 0.28, blue: 0.18, alpha: 1.0)
    shot.strokeColor = .clear
    shot.position = enemyGatePoint
    shot.zPosition = 45
    effectsLayer.addChild(shot)

    let move = SKAction.move(to: bundle.root.position, duration: 0.12)
    let remove = SKAction.removeFromParent()
    shot.run(SKAction.sequence([move, remove]))
}

private func playSoldierAttackFeedback(for soldierID: BattleCombatState.SoldierID) {
    guard let bundle = soldierNodes[soldierID] else {
        return
    }

    let lunge = SKAction.moveBy(x: 8, y: 0, duration: 0.06)
    let back = SKAction.moveBy(x: -8, y: 0, duration: 0.08)
    bundle.root.run(SKAction.sequence([lunge, back]), withKey: "soldierAttackFeedback")
}
```

**Step 6: Update background and idle behavior**

In `sceneDidEnterBackground(_:)`, clear live soldiers after saving the background timestamp:

```swift
clearLiveCombat()
```

In `sceneWillEnterForeground(_:)`, replace `clearPendingSoldierAttacks()` with `clearLiveCombat()`.

**Step 7: Add test hooks**

Replace the old `#if DEBUG` pending-soldier hooks with:

```swift
var liveSoldierCountForTesting: Int {
    combat.livingSoldierCount
}

func advanceCombatForTesting(deltaTime: TimeInterval) {
    var remaining = max(0, deltaTime)

    while remaining > 0 {
        let step = min(remaining, 0.1)
        advanceCombat(deltaTime: step)
        remaining -= step
    }
}
```

Remove `pendingSoldierAttackCountForTesting` and `completeFirstPendingSoldierAttackForTesting()` unless a transitional compile fix needs them temporarily. The final tests should use the live-combat hooks only.

**Step 8: Run focused scene tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

**Step 9: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Integrate live combat into battle scene"
```

---

### Task 7: Polish Labels, Layout, And Compatibility Tests

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Step 1: Add or update scene assertions for readable status**

Add a test to `BattleSceneTests`:

```swift
@Test func battleSceneDisplaysLiveSoldierCount() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 0")

    scene.spawnSoldierForTesting()

    #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 1")
}
```

**Step 2: Run focused scene tests to verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because the live combat status label and test hook do not exist.

**Step 3: Add a compact live combat status label**

In `BattleScene`, add:

```swift
private let liveCombatStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
```

Configure it in `buildInterface()`:

```swift
configureLabel(liveCombatStatusLabel, fontSize: 15, color: SKColor(red: 0.86, green: 0.92, blue: 1.0, alpha: 1.0))
liveCombatStatusLabel.zPosition = 100
addChild(liveCombatStatusLabel)
```

In `redraw()`, set:

```swift
liveCombatStatusLabel.text = "Soldiers: \(combat.livingSoldierCount)"
```

Place it in `layoutInterface()` between the city HP label and HP bar, tightening the HP gap if needed:

```swift
liveCombatStatusLabel.position = CGPoint(x: centerX, y: cityHPLabel.position.y - 22)
hpBarBackground.position = CGPoint(x: centerX, y: liveCombatStatusLabel.position.y - hpLabelToBarGap)
```

Include it in font reset and fitting:

```swift
liveCombatStatusLabel.fontSize = 15
fitLabel(liveCombatStatusLabel, maxWidth: contentWidth)
```

Add the test hook:

```swift
var liveCombatStatusTextForTesting: String? {
    liveCombatStatusLabel.text
}
```

Call `redraw()` after spawning a soldier so the label updates immediately.

**Step 4: Run focused scene tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

**Step 5: Run focused combat model tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Show live soldier battle status"
```

---

### Task 8: Full Regression Verification

**Files:**
- No code changes expected.

**Step 1: Run all unit and UI tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: PASS.

If `iPhone 16` is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun the full test command with an available simulator.

**Step 2: Check the worktree**

Run:

```bash
git status --short
```

Expected: clean or only intentionally uncommitted verification artifacts. There should be no generated build products staged.

**Step 3: Manual simulator smoke checklist**

Launch the app from Xcode or the simulator and verify:

- City 1 battle opens directly.
- Tapping `Spawn Soldier` creates a visible soldier.
- Multiple taps create multiple visible soldiers.
- Soldiers walk toward the city and stop near attack range.
- Soldiers keep attacking until killed or conquest happens.
- Soldier HP bars decrease when tower shots land.
- Dead soldiers disappear.
- City HP decreases from repeated soldier attacks.
- The conquest popup still appears when the city reaches 0 HP.
- Closing the conquest popup still routes to the country map.
- Entering the next city resets live combat and starts the next city battle.

**Step 4: Final commit if any verification fixes were needed**

If fixes were required during verification:

```bash
git add Pyxis PyxisTests
git commit -m "Fix live combat verification issues"
```

If no fixes were required, do not create an empty commit.
