# City Building View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a current-city Building View with a 25-slot city grid, Barracks and Archery Range construction/upgrades, type-selectable manual spawning, building-spawned soldiers, and building-based idle damage.

**Architecture:** Keep durable city building data in pure Swift models owned by `KingdomGameState`, keyed by city identity for future simultaneous city attacks. Keep live soldiers transient in `BattleCombatState` and rendered only by `BattleScene`; add `BuildingViewScene` as a SpriteKit management scene routed by `GameViewController`.

**Tech Stack:** Swift 5, SpriteKit, UIKit routing through `GameViewController`, Swift Testing for unit tests, XCTest only for UI-test targets, Xcode synchronized root groups.

---

## File Structure

- Create `Pyxis/SoldierType.swift`: shared pure Swift enums for `SoldierType` and `SoldierSpawnSource`.
- Create `Pyxis/CityBuildingState.swift`: pure Swift building types, per-city grid state, building costs, spawn timer resolution, normalization helpers.
- Modify `Pyxis/KingdomGameState.swift`: add city-keyed building storage, build/upgrade APIs, active building spawn resolution, building-based idle resolution, conquest cleanup, decoding normalization.
- Modify `Pyxis/BattleCombatState.swift`: add soldier type/source/level fields, type-aware HP/range stats, manual-source counting, and a backward-compatible spawn overload.
- Create `Pyxis/BuildingViewScene.swift`: 25-slot SpriteKit city-grid scene with build, upgrade, feedback, and route back to battle.
- Modify `Pyxis/BattleScene.swift`: add Build route, manual soldier type dropdown, manual cap enforcement, active building spawn ticking, and testing hooks.
- Modify `Pyxis/GameViewController.swift`: route Battle -> Building View -> Battle.
- Modify `PyxisTests/KingdomGameStateTests.swift`: durable building, idle, conquest cleanup, and save-normalization coverage.
- Modify `PyxisTests/BattleCombatStateTests.swift`: soldier type/source and manual cap support coverage.
- Modify `PyxisTests/BattleSceneTests.swift`: selector, manual cap, building spawn, and Build route coverage.
- Create `PyxisTests/BuildingViewSceneTests.swift`: grid, build/upgrade, cap/insufficient-gold feedback, and routing coverage.
- Modify `PyxisTests/KingdomGameStoreTests.swift`: round-trip city building state coverage.

---

### Task 1: Add City Building Domain Model

**Files:**
- Create: `Pyxis/SoldierType.swift`
- Create: `Pyxis/CityBuildingState.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`

- [ ] **Step 1: Write failing building-state tests**

Add these tests to `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func currentCityStartsWithEmptyBuildingGrid() {
    let state = KingdomGameState()
    let cityState = state.cityBattleStateForCurrentCity

    #expect(cityState.slotCount == 25)
    #expect(cityState.occupiedSlotCount == 0)
    #expect(cityState.buildingCount(for: .barracks) == 0)
    #expect(cityState.buildingCount(for: .archeryRange) == 0)
}

@Test func buildingConsumesGoldAndOccupiesSelectedSlot() {
    var state = KingdomGameState(gold: 100)

    let result = state.buildBuilding(.barracks, inSlot: 7, at: Date(timeIntervalSinceReferenceDate: 100))

    #expect(result == .built(cost: 15, remainingGold: 85))
    #expect(state.gold == 85)
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 7)?.type == .barracks)
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 7)?.level == 1)
}

@Test func buildingRejectsInvalidOccupiedUnaffordableAndTypeCapCases() {
    var state = KingdomGameState(gold: 200)

    #expect(state.buildBuilding(.barracks, inSlot: 0) == .invalidSlot)
    #expect(state.buildBuilding(.barracks, inSlot: 26) == .invalidSlot)

    #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 185))
    #expect(state.buildBuilding(.archeryRange, inSlot: 1) == .slotOccupied)

    #expect(state.buildBuilding(.barracks, inSlot: 2) == .built(cost: 15, remainingGold: 170))
    #expect(state.buildBuilding(.barracks, inSlot: 3) == .built(cost: 15, remainingGold: 155))
    #expect(state.buildBuilding(.barracks, inSlot: 4) == .built(cost: 15, remainingGold: 140))
    #expect(state.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 125))
    #expect(state.buildBuilding(.barracks, inSlot: 6) == .typeCapReached(maximum: 5))

    var poorState = KingdomGameState(gold: 14)
    #expect(poorState.buildBuilding(.barracks, inSlot: 1) == .insufficientGold(cost: 15, currentGold: 14))
    #expect(poorState.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
}

@Test func upgradingBuildingConsumesGoldAndIncreasesLevel() {
    var state = KingdomGameState(gold: 100)
    #expect(state.buildBuilding(.archeryRange, inSlot: 4) == .built(cost: 18, remainingGold: 82))

    let result = state.upgradeBuilding(inSlot: 4)

    #expect(result == .upgraded(cost: 14, newLevel: 2, remainingGold: 68))
    #expect(state.gold == 68)
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 4)?.level == 2)
}

@Test func upgradingRejectsMissingBuildingAndInsufficientGold() {
    var state = KingdomGameState(gold: 100)

    #expect(state.upgradeBuilding(inSlot: 3) == .missingBuilding)

    #expect(state.buildBuilding(.archeryRange, inSlot: 3) == .built(cost: 18, remainingGold: 82))
    state.gold = 0

    #expect(state.upgradeBuilding(inSlot: 3) == .insufficientGold(cost: 14, currentGold: 0))
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 3)?.level == 1)
}

@Test func buildingStateIsIsolatedByCityAndClearedAfterConquest() {
    var state = KingdomGameState(gold: 200, cityRemainingPower: 1)
    #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 185))

    _ = state.applyLiveCombatDamage(1)

    #expect(state.stageStatus == .cityConqueredPendingMap)
    #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 1)).occupiedSlotCount == 0)

    _ = state.startCityFromMap(2)
    #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
    #expect(state.buildBuilding(.archeryRange, inSlot: 1) == .built(cost: 18, remainingGold: 175))
    #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 2)).building(inSlot: 1)?.type == .archeryRange)
}
```

Add this round-trip test to `PyxisTests/KingdomGameStoreTests.swift`:

```swift
@Test func saveAndLoadRoundTripsCityBuildingState() throws {
    let defaults = try makeDefaults()
    let store = KingdomGameStore(defaults: defaults, key: "state")
    var saved = KingdomGameState(gold: 100)
    #expect(saved.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 85))
    #expect(saved.upgradeBuilding(inSlot: 5) == .upgraded(cost: 12, newLevel: 2, remainingGold: 73))

    store.save(saved)
    let loaded = store.load()

    #expect(loaded == saved)
    #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 5)?.type == .barracks)
    #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 5)?.level == 2)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/KingdomGameStoreTests
```

Expected: FAIL because `CityKey`, `BuildingType`, city building APIs, and result enums do not exist yet.

- [ ] **Step 3: Add soldier and building domain files**

Create `Pyxis/SoldierType.swift`:

```swift
//
//  SoldierType.swift
//  Pyxis
//

import Foundation

enum SoldierType: String, Codable, CaseIterable, Equatable {
    case infantry
    case archer

    var displayName: String {
        switch self {
        case .infantry:
            return "Infantry"
        case .archer:
            return "Archer"
        }
    }
}

enum SoldierSpawnSource: String, Codable, Equatable {
    case manual
    case building
}
```

Create `Pyxis/CityBuildingState.swift`:

```swift
//
//  CityBuildingState.swift
//  Pyxis
//

import Foundation

struct CityKey: Codable, Equatable, Hashable {
    let countryNumber: Int
    let cityNumber: Int

    init(countryNumber: Int, cityNumber: Int) {
        self.countryNumber = max(1, countryNumber)
        self.cityNumber = min(max(1, cityNumber), KingdomGameState.firstCountryCityCount)
    }

    init?(storageKey: String) {
        let parts = storageKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else {
            return nil
        }

        self.init(countryNumber: parts[0], cityNumber: parts[1])
    }

    var storageKey: String {
        "\(countryNumber)-\(cityNumber)"
    }
}

enum BuildingType: String, Codable, CaseIterable, Equatable {
    case barracks
    case archeryRange

    var displayName: String {
        switch self {
        case .barracks:
            return "Barracks"
        case .archeryRange:
            return "Archery Range"
        }
    }

    var soldierType: SoldierType {
        switch self {
        case .barracks:
            return .infantry
        case .archeryRange:
            return .archer
        }
    }
}

struct CityBuilding: Codable, Equatable {
    let type: BuildingType
    var level: Int
    var spawnTimerElapsed: Double

    init(type: BuildingType, level: Int = 1, spawnTimerElapsed: Double = 0) {
        self.type = type
        self.level = max(1, level)
        self.spawnTimerElapsed = max(0, spawnTimerElapsed)
    }

    func normalized() -> CityBuilding {
        CityBuilding(type: type, level: level, spawnTimerElapsed: spawnTimerElapsed)
    }
}

struct BuildingSpawn: Equatable {
    let soldierType: SoldierType
    let level: Int
    let sourceSlot: Int
}

struct CityBattleState: Codable, Equatable {
    static let slotRange = 1...25
    static let maxBuildingsPerType = 5

    var slots: [Int: CityBuilding]
    var lastBuildingProgressResolvedAt: Date?

    init(slots: [Int: CityBuilding] = [:], lastBuildingProgressResolvedAt: Date? = nil) {
        self.slots = slots
        self.lastBuildingProgressResolvedAt = lastBuildingProgressResolvedAt
        normalize()
    }

    var slotCount: Int {
        Self.slotRange.count
    }

    var occupiedSlotCount: Int {
        slots.count
    }

    func building(inSlot slot: Int) -> CityBuilding? {
        slots[slot]
    }

    func buildingCount(for type: BuildingType) -> Int {
        slots.values.filter { $0.type == type }.count
    }

    mutating func setBuilding(_ building: CityBuilding, inSlot slot: Int) {
        guard Self.slotRange.contains(slot) else {
            return
        }

        slots[slot] = building.normalized()
        normalize()
    }

    mutating func removeAllBuildings() {
        slots.removeAll()
        lastBuildingProgressResolvedAt = nil
    }

    mutating func normalize() {
        var normalizedSlots: [Int: CityBuilding] = [:]
        var counts: [BuildingType: Int] = [:]

        for slot in slots.keys.sorted() where Self.slotRange.contains(slot) {
            guard let building = slots[slot]?.normalized() else {
                continue
            }

            let count = counts[building.type, default: 0]
            guard count < Self.maxBuildingsPerType else {
                continue
            }

            normalizedSlots[slot] = building
            counts[building.type] = count + 1
        }

        slots = normalizedSlots
    }
}
```

- [ ] **Step 4: Extend `KingdomGameState` with building storage and operations**

Modify `Pyxis/KingdomGameState.swift`:

Add result enums inside `KingdomGameState`:

```swift
enum BuildBuildingResult: Equatable {
    case built(cost: Int, remainingGold: Int)
    case insufficientGold(cost: Int, currentGold: Int)
    case invalidSlot
    case slotOccupied
    case typeCapReached(maximum: Int)
    case unavailable
}

enum UpgradeBuildingResult: Equatable {
    case upgraded(cost: Int, newLevel: Int, remainingGold: Int)
    case insufficientGold(cost: Int, currentGold: Int)
    case invalidSlot
    case missingBuilding
    case unavailable
}
```

Add the stored property and coding key:

```swift
var cityBattleStates: [String: CityBattleState]
```

```swift
case cityBattleStates
```

Add `cityBattleStates: [String: CityBattleState] = [:]` to the initializer and pass it from `init(from:)`.

Normalize the new storage in the initializer with this block after `stageStatus` is resolved:

```swift
var normalizedCityBattleStates: [String: CityBattleState] = [:]
for (key, value) in cityBattleStates {
    guard let cityKey = CityKey(storageKey: key), cityKey.cityNumber > normalizedCompletedCityCount else {
        continue
    }

    var normalizedValue = value
    normalizedValue.normalize()
    normalizedCityBattleStates[cityKey.storageKey] = normalizedValue
}
self.cityBattleStates = normalizedCityBattleStates
```

Add these computed properties and methods:

```swift
static let manualSoldierCap = 10

var currentCityKey: CityKey {
    CityKey(countryNumber: countryNumber, cityNumber: cityNumberInCountry)
}

var cityBattleStateForCurrentCity: CityBattleState {
    cityBattleState(for: currentCityKey)
}

func cityBattleState(for key: CityKey) -> CityBattleState {
    cityBattleStates[key.storageKey] ?? CityBattleState()
}

@discardableResult
mutating func buildBuilding(
    _ type: BuildingType,
    inSlot slot: Int,
    at date: Date? = nil
) -> BuildBuildingResult {
    guard stageStatus == .battleActive else {
        return .unavailable
    }

    guard CityBattleState.slotRange.contains(slot) else {
        return .invalidSlot
    }

    let key = currentCityKey
    var cityState = cityBattleState(for: key)

    guard cityState.building(inSlot: slot) == nil else {
        return .slotOccupied
    }

    guard cityState.buildingCount(for: type) < CityBattleState.maxBuildingsPerType else {
        return .typeCapReached(maximum: CityBattleState.maxBuildingsPerType)
    }

    let cost = Self.buildingBuildCost(for: type)
    guard gold >= cost else {
        return .insufficientGold(cost: cost, currentGold: gold)
    }

    gold -= cost
    cityState.setBuilding(CityBuilding(type: type), inSlot: slot)
    if cityState.lastBuildingProgressResolvedAt == nil {
        cityState.lastBuildingProgressResolvedAt = date
    }
    cityBattleStates[key.storageKey] = cityState

    return .built(cost: cost, remainingGold: gold)
}

@discardableResult
mutating func upgradeBuilding(inSlot slot: Int) -> UpgradeBuildingResult {
    guard stageStatus == .battleActive else {
        return .unavailable
    }

    guard CityBattleState.slotRange.contains(slot) else {
        return .invalidSlot
    }

    let key = currentCityKey
    var cityState = cityBattleState(for: key)

    guard var building = cityState.building(inSlot: slot) else {
        return .missingBuilding
    }

    let cost = Self.buildingUpgradeCost(for: building.type, currentLevel: building.level)
    guard gold >= cost else {
        return .insufficientGold(cost: cost, currentGold: gold)
    }

    gold -= cost
    building.level += 1
    cityState.setBuilding(building, inSlot: slot)
    cityBattleStates[key.storageKey] = cityState

    return .upgraded(cost: cost, newLevel: building.level, remainingGold: gold)
}

static func buildingBuildCost(for type: BuildingType) -> Int {
    switch type {
    case .barracks:
        return 15
    case .archeryRange:
        return 18
    }
}

static func buildingUpgradeCost(for type: BuildingType, currentLevel: Int) -> Int {
    let base: Double
    switch type {
    case .barracks:
        base = 12
    case .archeryRange:
        base = 14
    }

    return roundedAtLeastOne(base * pow(1.65, Double(clampedLevel(currentLevel) - 1)))
}
```

In `completeCurrentCity()`, remove conquered-city building state before returning the reward:

```swift
cityBattleStates.removeValue(forKey: currentCityKey.storageKey)
```

- [ ] **Step 5: Run tests to verify Task 1 passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/KingdomGameStoreTests
```

Expected: PASS for the new building-state and store tests.

- [ ] **Step 6: Commit Task 1**

```bash
git add Pyxis/SoldierType.swift Pyxis/CityBuildingState.swift Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift PyxisTests/KingdomGameStoreTests.swift
git commit -m "Add city building state model"
```

---

### Task 2: Replace Global Idle Damage With Building-Based Idle Damage

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write failing idle tests**

Replace old idle expectations in `PyxisTests/KingdomGameStateTests.swift` so no-building idle does no damage:

```swift
@Test func idleCatchUpDoesNoDamageWithoutBuildingsAndClearsTimestamp() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let end = start.addingTimeInterval(5_000)
    var state = KingdomGameState(cityRemainingPower: 20)

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result == .none)
    #expect(state.cityRemainingPower == 20)
    #expect(state.lastBackgroundedAt == nil)
}
```

Add these tests:

```swift
@Test func buildingIdleDamageUsesSlowerBuildingProductionAndPreservesPartialProgress() {
    let start = Date(timeIntervalSinceReferenceDate: 2_000)
    let end = start.addingTimeInterval(100)
    var state = KingdomGameState(gold: 100, cityRemainingPower: 50)
    #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == 100)
    #expect(result.damageDealt == 1)
    #expect(result.conqueredCities == 0)
    #expect(state.cityRemainingPower == 49)
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.spawnTimerElapsed == 0)
}

@Test func buildingIdleDamageCanConquerCurrentCity() {
    let start = Date(timeIntervalSinceReferenceDate: 3_000)
    let end = start.addingTimeInterval(1_000)
    var state = KingdomGameState(gold: 100, cityRemainingPower: 2)
    #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
    #expect(state.buildBuilding(.archeryRange, inSlot: 2, at: start) == .built(cost: 18, remainingGold: 67))

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == 1_000)
    #expect(result.damageDealt == 2)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.cityRemainingPower == 0)
    #expect(state.completedCityCount == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
    #expect(state.cityBattleState(for: CityKey(countryNumber: 1, cityNumber: 1)).occupiedSlotCount == 0)
}

@Test func activeBuildingSpawnsAdvanceTimersAndEmitSpawnEvents() {
    var state = KingdomGameState(gold: 100, cityRemainingPower: 30)
    #expect(state.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))
    #expect(state.buildBuilding(.archeryRange, inSlot: 2) == .built(cost: 18, remainingGold: 67))

    let firstTick = state.resolveActiveBuildingSpawns(deltaTime: 9.9)
    #expect(firstTick.isEmpty)

    let secondTick = state.resolveActiveBuildingSpawns(deltaTime: 0.1)
    #expect(secondTick == [BuildingSpawn(soldierType: .infantry, level: 1, sourceSlot: 1)])

    let thirdTick = state.resolveActiveBuildingSpawns(deltaTime: 2.0)
    #expect(thirdTick == [BuildingSpawn(soldierType: .archer, level: 1, sourceSlot: 2)])
}
```

Update `PyxisTests/BattleSceneTests.swift` by replacing `idleConquestClearsLiveSoldiersBeforeShowingPopup` setup with a state that has a building:

```swift
let start = Date(timeIntervalSinceNow: -1_000)
var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
#expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
let store = try makeStore(initialState: initialState)
```

- [ ] **Step 2: Run idle tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because idle still uses `normalSoldierAttackPower` and `resolveActiveBuildingSpawns(deltaTime:)` does not exist.

- [ ] **Step 3: Implement building spawn timer and idle damage APIs**

Add to `KingdomGameState.swift`:

```swift
@discardableResult
mutating func resolveActiveBuildingSpawns(deltaTime rawDeltaTime: Double) -> [BuildingSpawn] {
    guard stageStatus == .battleActive else {
        return []
    }

    let deltaTime = min(max(0, rawDeltaTime), 1.0)
    guard deltaTime > 0 else {
        return []
    }

    let key = currentCityKey
    var cityState = cityBattleState(for: key)
    let spawns = Self.resolveBuildingSpawns(in: &cityState, effectiveActiveSeconds: deltaTime)
    cityBattleStates[key.storageKey] = cityState
    return spawns
}

mutating func markCurrentCityBuildingProgressInactive(at date: Date) {
    guard stageStatus == .battleActive else {
        lastBackgroundedAt = date
        return
    }

    lastBackgroundedAt = date
    let key = currentCityKey
    var cityState = cityBattleState(for: key)
    if cityState.occupiedSlotCount > 0 {
        cityState.lastBuildingProgressResolvedAt = date
        cityBattleStates[key.storageKey] = cityState
    }
}

@discardableResult
mutating func resolveCurrentCityBuildingIdleProgress(at date: Date) -> IdleProgressResult {
    guard stageStatus == .battleActive else {
        lastBackgroundedAt = nil
        return .none
    }

    let key = currentCityKey
    var cityState = cityBattleState(for: key)
    guard cityState.occupiedSlotCount > 0 else {
        lastBackgroundedAt = nil
        return .none
    }

    let resolvedStart = cityState.lastBuildingProgressResolvedAt ?? lastBackgroundedAt ?? date
    let rawElapsed = Int(date.timeIntervalSince(resolvedStart))
    let elapsedSeconds = min(max(0, rawElapsed), Self.maxIdleCatchUpSeconds)
    guard elapsedSeconds > 0 else {
        lastBackgroundedAt = nil
        cityState.lastBuildingProgressResolvedAt = date
        cityBattleStates[key.storageKey] = cityState
        return .none
    }

    let spawns = Self.resolveBuildingSpawns(in: &cityState, effectiveActiveSeconds: Double(elapsedSeconds) / 10.0)
    cityState.lastBuildingProgressResolvedAt = date
    cityBattleStates[key.storageKey] = cityState
    lastBackgroundedAt = nil

    let totalPotentialDamage = spawns.reduce(0) { total, spawn in
        total + Self.soldierAttackPower(for: spawn.soldierType, level: spawn.level)
    }

    guard totalPotentialDamage > 0 else {
        return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: 0, conqueredCities: 0, goldEarned: 0)
    }

    let appliedDamage = min(totalPotentialDamage, cityRemainingPower)
    guard totalPotentialDamage >= cityRemainingPower else {
        cityRemainingPower -= totalPotentialDamage
        return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: totalPotentialDamage, conqueredCities: 0, goldEarned: 0)
    }

    let reward = completeCurrentCity()
    return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: appliedDamage, conqueredCities: 1, goldEarned: reward)
}

static func activeSpawnInterval(for type: BuildingType) -> Double {
    switch type {
    case .barracks:
        return 10
    case .archeryRange:
        return 12
    }
}

static func soldierAttackPower(for type: SoldierType, level: Int) -> Int {
    normalSoldierAttackPower(for: level)
}

private static func resolveBuildingSpawns(
    in cityState: inout CityBattleState,
    effectiveActiveSeconds: Double
) -> [BuildingSpawn] {
    guard effectiveActiveSeconds > 0 else {
        return []
    }

    var spawns: [BuildingSpawn] = []

    for slot in cityState.slots.keys.sorted() {
        guard var building = cityState.slots[slot] else {
            continue
        }

        building.spawnTimerElapsed += effectiveActiveSeconds
        let interval = activeSpawnInterval(for: building.type)

        while building.spawnTimerElapsed >= interval {
            building.spawnTimerElapsed -= interval
            spawns.append(BuildingSpawn(soldierType: building.type.soldierType, level: building.level, sourceSlot: slot))
        }

        cityState.slots[slot] = building
    }

    return spawns
}
```

Change `enterBackground(at:)`:

```swift
mutating func enterBackground(at date: Date) {
    markCurrentCityBuildingProgressInactive(at: date)
}
```

Change `returnFromBackground(at:)` to call only building idle progress:

```swift
@discardableResult
mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
    resolveCurrentCityBuildingIdleProgress(at: date)
}
```

- [ ] **Step 4: Update BattleScene lifecycle calls**

In `Pyxis/BattleScene.swift`, keep the existing selector methods but rely on the new model behavior:

```swift
@objc private func sceneDidEnterBackground(_ notification: Notification) {
    state.enterBackground(at: Date())
    store.save(state)
    clearLiveCombat()
}

@objc private func sceneWillEnterForeground(_ notification: Notification) {
    let result = state.returnFromBackground(at: Date())
    store.save(state)

    if result.elapsedSeconds > 0 {
        if result.conqueredCities > 0 {
            clearLiveCombat()
            feedbackText = "Buildings conquered \(state.displayCityTitle)."
        } else if result.damageDealt > 0 {
            feedbackText = "Buildings dealt \(compactNumber(result.damageDealt)) idle damage."
        } else {
            feedbackText = "No building damage while away."
        }
    }

    redraw()

    if result.conqueredCities > 0 {
        showConquestPopup(goldEarned: result.goldEarned)
    }
}
```

- [ ] **Step 5: Run idle tests to verify Task 2 passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS for building idle and lifecycle tests. Existing old idle tests should now expect no damage without buildings.

- [ ] **Step 6: Commit Task 2**

```bash
git add Pyxis/KingdomGameState.swift Pyxis/BattleScene.swift PyxisTests/KingdomGameStateTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "Replace idle damage with building progress"
```

---

### Task 3: Make Live Combat Soldier-Type And Source Aware

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

- [ ] **Step 1: Write failing combat tests**

Add to `PyxisTests/BattleCombatStateTests.swift`:

```swift
@Test func infantryAndArcherUseDifferentHPAndAttackRanges() throws {
    var combat = BattleCombatState(configuration: .live(cityLevel: 1))

    let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2)
    let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2)

    let infantrySoldier = try #require(combat.soldier(id: infantry))
    let archerSoldier = try #require(combat.soldier(id: archer))

    #expect(infantrySoldier.type == .infantry)
    #expect(archerSoldier.type == .archer)
    #expect(infantrySoldier.maxHP > archerSoldier.maxHP)
    #expect(infantrySoldier.attackRange < archerSoldier.attackRange)
}

@Test func soldierLevelIncreasesHPAndCarriesSpawnSource() throws {
    var combat = BattleCombatState(configuration: .live(cityLevel: 1))

    let low = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1)
    let high = combat.spawnSoldier(type: .infantry, source: .building, level: 3, attackPower: 3)

    let lowSoldier = try #require(combat.soldier(id: low))
    let highSoldier = try #require(combat.soldier(id: high))

    #expect(lowSoldier.source == .building)
    #expect(highSoldier.source == .building)
    #expect(highSoldier.level == 3)
    #expect(highSoldier.maxHP > lowSoldier.maxHP)
    #expect(highSoldier.attackPower == 3)
}

@Test func manualLivingSoldierCountExcludesBuildingSpawnedSoldiers() {
    var combat = BattleCombatState(configuration: .live(cityLevel: 1))

    _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
    _ = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1)
    _ = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1)

    #expect(combat.livingSoldierCount == 3)
    #expect(combat.livingSoldierCount(source: .manual) == 2)
    #expect(combat.livingSoldierCount(source: .building) == 1)
}
```

- [ ] **Step 2: Run combat tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: FAIL because `BattleCombatState.Soldier` does not expose type/source/level and the new spawn overload does not exist.

- [ ] **Step 3: Implement type-aware soldier spawning**

Modify `Pyxis/BattleCombatState.swift`:

Add properties to `Soldier`:

```swift
let type: SoldierType
let source: SoldierSpawnSource
let level: Int
```

Add count helper:

```swift
func livingSoldierCount(source: SoldierSpawnSource) -> Int {
    soldiers.filter { $0.isAlive && $0.source == source }.count
}
```

Replace `spawnSoldier(attackPower:)` with a delegating overload and a full overload:

```swift
@discardableResult
mutating func spawnSoldier(attackPower: Int) -> SoldierID {
    spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: attackPower)
}

@discardableResult
mutating func spawnSoldier(
    type: SoldierType,
    source: SoldierSpawnSource,
    level: Int,
    attackPower: Int
) -> SoldierID {
    let id = nextSoldierID
    nextSoldierID += 1

    let clampedLevel = max(1, level)
    soldiers.append(
        Soldier(
            id: id,
            type: type,
            source: source,
            level: clampedLevel,
            maxHP: maxHP(for: type, level: clampedLevel),
            currentHP: maxHP(for: type, level: clampedLevel),
            defense: max(0, configuration.soldierDefense),
            attackPower: max(1, attackPower),
            attackSpeed: max(0.1, configuration.soldierAttackSpeed),
            attackRange: attackRange(for: type),
            movementSpeed: max(0, configuration.soldierMovementSpeed),
            position: 0,
            attackCooldownRemaining: 0
        )
    )

    return id
}

private func maxHP(for type: SoldierType, level: Int) -> Int {
    let baseHP: Double
    switch type {
    case .infantry:
        baseHP = Double(max(1, configuration.soldierMaxHP))
    case .archer:
        baseHP = Double(max(1, configuration.soldierMaxHP)) * 0.7
    }

    return max(1, Int((baseHP * pow(1.25, Double(max(1, level) - 1))).rounded()))
}

private func attackRange(for type: SoldierType) -> Double {
    switch type {
    case .infantry:
        return min(max(0, configuration.soldierAttackRange), 1)
    case .archer:
        return min(max(0, configuration.soldierAttackRange * 2.2), 1)
    }
}
```

- [ ] **Step 4: Update existing combat test expectations**

In `spawningCreatesSoldierWithFullHPAndConfiguredStats`, keep the existing `spawnSoldier(attackPower:)` call and add:

```swift
#expect(soldier.type == .infantry)
#expect(soldier.source == .manual)
#expect(soldier.level == 1)
```

The existing HP, defense, attack speed, range, movement, tower, and cooldown behavior should remain valid for default Infantry.

- [ ] **Step 5: Run combat tests to verify Task 3 passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleCombatStateTests
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Add typed soldier combat sources"
```

---

### Task 4: Add Building View Scene And Routing

**Files:**
- Create: `Pyxis/BuildingViewScene.swift`
- Create: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `Pyxis/GameViewController.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write failing Building View tests**

Create `PyxisTests/BuildingViewSceneTests.swift`:

```swift
//
//  BuildingViewSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BuildingViewSceneTests {
    @Test func gridRendersTwentyFiveSelectableSlots() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.buildingSlotCountForTesting == 25)
        #expect(scene.slotNodeCountForTesting == 25)
        #expect(scene.selectedSlotForTesting == nil)
    }

    @Test func selectingEmptySlotExposesBuildActions() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)

        #expect(scene.selectedSlotForTesting == 3)
        #expect(scene.canBuildBarracksForTesting)
        #expect(scene.canBuildArcheryRangeForTesting)
        #expect(!scene.canUpgradeSelectedSlotForTesting)
    }

    @Test func buildingUpdatesStoreSlotAndGoldLabel() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(store.load().gold == 85)
        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 3)?.type == .barracks)
        #expect(scene.goldTextForTesting == "Gold: 85")
        #expect(scene.slotTextForTesting(3)?.contains("Barracks") == true)
    }

    @Test func occupiedSlotExposesUpgradeAction() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(4)
        scene.buildSelectedSlotForTesting(.archeryRange)
        scene.selectSlotForTesting(4)

        #expect(!scene.canBuildBarracksForTesting)
        #expect(!scene.canBuildArcheryRangeForTesting)
        #expect(scene.canUpgradeSelectedSlotForTesting)

        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 4)?.level == 2)
    }

    @Test func typeCapAndInsufficientGoldShowFeedback() throws {
        var initial = KingdomGameState(gold: 75)
        #expect(initial.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 60))
        #expect(initial.buildBuilding(.barracks, inSlot: 2) == .built(cost: 15, remainingGold: 45))
        #expect(initial.buildBuilding(.barracks, inSlot: 3) == .built(cost: 15, remainingGold: 30))
        #expect(initial.buildBuilding(.barracks, inSlot: 4) == .built(cost: 15, remainingGold: 15))
        #expect(initial.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 0))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(6)
        scene.buildSelectedSlotForTesting(.barracks)
        #expect(scene.feedbackTextForTesting == "Barracks limit reached.")

        scene.buildSelectedSlotForTesting(.archeryRange)
        #expect(scene.feedbackTextForTesting == "Need 18 gold. You have 0.")
    }

    @Test func backToBattleRoutesThroughRouter() throws {
        let store = try makeStore(initialState: KingdomGameState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBattleForTesting()

        #expect(router.didRequestBattle)
    }

    private final class RouteSpy: BuildingViewSceneRouting {
        private(set) var didRequestBattle = false

        func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) {
            didRequestBattle = true
        }
    }

    private func makeScene(store: KingdomGameStore, router: BuildingViewSceneRouting?) -> BuildingViewScene {
        let size = CGSize(width: 390, height: 844)
        let scene = BuildingViewScene(size: size, store: store, router: router)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
```

Add this test to `PyxisTests/BattleSceneTests.swift`:

```swift
@Test func buildButtonRequestsBuildingViewRoute() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
    let router = RouteSpy()
    let scene = makeScene(store: store, router: router)

    scene.requestBuildingViewForTesting()

    #expect(router.didRequestBuildingView)
}
```

Update the local `RouteSpy` in `BattleSceneTests.swift`:

```swift
private final class RouteSpy: BattleSceneRouting {
    private(set) var didRequestCountryMap = false
    private(set) var didRequestBuildingView = false

    func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
        didRequestCountryMap = true
    }

    func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
        didRequestBuildingView = true
    }
}
```

- [ ] **Step 2: Run scene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because `BuildingViewScene`, `BuildingViewSceneRouting`, and Battle routing do not exist.

- [ ] **Step 3: Implement `BuildingViewScene`**

Create `Pyxis/BuildingViewScene.swift` with this structure:

```swift
//
//  BuildingViewScene.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

protocol BuildingViewSceneRouting: AnyObject {
    func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene)
}

final class BuildingViewScene: SKScene {
    private enum NodeName {
        static let slotPrefix = "buildingSlot-"
        static let buildBarracks = "buildBarracksButton"
        static let buildArchery = "buildArcheryButton"
        static let upgrade = "upgradeBuildingButton"
        static let back = "backToBattleButton"
    }

    private let store: KingdomGameStore
    private weak var router: BuildingViewSceneRouting?
    private var state: KingdomGameState
    private var selectedSlot: Int?
    private var didBuildInterface = false

    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let feedbackLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let gridLayer = SKNode()
    private let actionLayer = SKNode()
    private var slotNodes: [Int: SKShapeNode] = [:]
    private var slotLabels: [Int: SKLabelNode] = [:]
    private let buildBarracksButton = SKNode()
    private let buildArcheryButton = SKNode()
    private let upgradeButton = SKNode()
    private let backButton = SKNode()
    private var feedbackText = "Select a city lot."

    init(size: CGSize, store: KingdomGameStore = .shared, router: BuildingViewSceneRouting? = nil) {
        self.store = store
        self.router = router
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.state = KingdomGameStore.shared.load()
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.11, blue: 0.13, alpha: 1)
        state = store.load()

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        redraw()
        layoutInterface()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }

        if let slot = slot(at: point) {
            selectSlot(slot)
            return
        }

        for node in nodes(at: point) {
            switch node.name {
            case NodeName.buildBarracks:
                buildSelectedSlot(.barracks)
                return
            case NodeName.buildArchery:
                buildSelectedSlot(.archeryRange)
                return
            case NodeName.upgrade:
                upgradeSelectedSlot()
                return
            case NodeName.back:
                requestBattle()
                return
            default:
                continue
            }
        }
    }
}
```

Add private helpers in the same file:

```swift
private extension BuildingViewScene {
    func buildInterface() {
        addChild(gridLayer)
        addChild(actionLayer)
        addChild(titleLabel)
        addChild(goldLabel)
        addChild(feedbackLabel)

        configureLabel(titleLabel, size: 26, color: GameUITheme.Color.textPrimary)
        configureLabel(goldLabel, size: 19, color: GameUITheme.Color.gold)
        configureLabel(feedbackLabel, size: 15, color: GameUITheme.Color.textSecondary)

        for slot in CityBattleState.slotRange {
            let node = SKShapeNode(rect: .zero, cornerRadius: 8)
            node.name = "\(NodeName.slotPrefix)\(slot)"
            node.lineWidth = 2
            gridLayer.addChild(node)
            slotNodes[slot] = node

            let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(label, size: 11, color: GameUITheme.Color.textPrimary)
            label.name = node.name
            gridLayer.addChild(label)
            slotLabels[slot] = label
        }

        configureButton(buildBarracksButton, name: NodeName.buildBarracks, title: "Build Barracks")
        configureButton(buildArcheryButton, name: NodeName.buildArchery, title: "Build Archery")
        configureButton(upgradeButton, name: NodeName.upgrade, title: "Upgrade")
        configureButton(backButton, name: NodeName.back, title: "Battle")
    }

    func configureLabel(_ label: SKLabelNode, size: CGFloat, color: SKColor) {
        label.fontSize = size
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }

    func configureButton(_ button: SKNode, name: String, title: String) {
        button.name = name
        let background = SKShapeNode(rectOf: CGSize(width: 150, height: 42), cornerRadius: 8)
        background.name = name
        background.fillColor = GameUITheme.Color.spawn
        background.strokeColor = GameUITheme.Color.panelStroke
        background.lineWidth = 1.5

        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        configureLabel(label, size: 14, color: GameUITheme.Color.textPrimary)
        label.text = title
        label.name = name

        button.addChild(background)
        button.addChild(label)
        actionLayer.addChild(button)
    }

    func layoutInterface() {
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - GameUITheme.topUnsafeInset(sceneSize: size, view: view) - 34)
        goldLabel.position = CGPoint(x: size.width / 2, y: titleLabel.position.y - 34)
        feedbackLabel.position = CGPoint(x: size.width / 2, y: GameUITheme.bottomUnsafeInset(sceneSize: size, view: view) + 112)

        let gridWidth = min(size.width - 32, 420)
        let cellGap: CGFloat = 8
        let cellSize = (gridWidth - cellGap * 4) / 5
        let gridHeight = cellSize * 5 + cellGap * 4
        let gridOrigin = CGPoint(x: (size.width - gridWidth) / 2, y: feedbackLabel.position.y + 36)

        for slot in CityBattleState.slotRange {
            let index = slot - 1
            let row = 4 - index / 5
            let column = index % 5
            let rect = CGRect(
                x: gridOrigin.x + CGFloat(column) * (cellSize + cellGap),
                y: gridOrigin.y + CGFloat(row) * (cellSize + cellGap),
                width: cellSize,
                height: cellSize
            )
            slotNodes[slot]?.path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            slotLabels[slot]?.position = CGPoint(x: rect.midX, y: rect.midY)
        }

        let actionY = max(42, GameUITheme.bottomUnsafeInset(sceneSize: size, view: view) + 44)
        buildBarracksButton.position = CGPoint(x: size.width * 0.25, y: actionY)
        buildArcheryButton.position = CGPoint(x: size.width * 0.75, y: actionY)
        upgradeButton.position = CGPoint(x: size.width * 0.25, y: actionY + 52)
        backButton.position = CGPoint(x: size.width * 0.75, y: actionY + 52)

        _ = gridHeight
    }

    func redraw() {
        titleLabel.text = "\(state.displayCityTitle) Build Grid"
        goldLabel.text = "Gold: \(state.gold)"
        feedbackLabel.text = feedbackText

        let cityState = state.cityBattleStateForCurrentCity
        for slot in CityBattleState.slotRange {
            let building = cityState.building(inSlot: slot)
            let selected = selectedSlot == slot
            slotNodes[slot]?.fillColor = fillColor(for: building, selected: selected)
            slotNodes[slot]?.strokeColor = selected ? GameUITheme.Color.gold : GameUITheme.Color.panelStroke
            slotLabels[slot]?.text = text(for: building, slot: slot)
        }
    }

    func fillColor(for building: CityBuilding?, selected: Bool) -> SKColor {
        guard let building else {
            return selected ? SKColor(red: 0.35, green: 0.28, blue: 0.16, alpha: 1) : SKColor(red: 0.20, green: 0.24, blue: 0.21, alpha: 1)
        }

        switch building.type {
        case .barracks:
            return SKColor(red: 0.17, green: 0.35, blue: 0.22, alpha: 1)
        case .archeryRange:
            return SKColor(red: 0.16, green: 0.27, blue: 0.38, alpha: 1)
        }
    }

    func text(for building: CityBuilding?, slot: Int) -> String {
        guard let building else {
            return "Lot \(slot)"
        }

        switch building.type {
        case .barracks:
            return "Barracks\nLv \(building.level)"
        case .archeryRange:
            return "Archery\nLv \(building.level)"
        }
    }

    func slot(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            guard let name = node.name, name.hasPrefix(NodeName.slotPrefix) else {
                continue
            }
            return Int(name.dropFirst(NodeName.slotPrefix.count))
        }
        return nil
    }

    func selectSlot(_ slot: Int) {
        selectedSlot = slot
        feedbackText = state.cityBattleStateForCurrentCity.building(inSlot: slot) == nil
            ? "Choose a building for Lot \(slot)."
            : "Upgrade or inspect Lot \(slot)."
        redraw()
    }

    func buildSelectedSlot(_ type: BuildingType) {
        guard let selectedSlot else {
            feedbackText = "Select a city lot first."
            redraw()
            return
        }

        let result = state.buildBuilding(type, inSlot: selectedSlot, at: Date())
        switch result {
        case let .built(_, remainingGold):
            feedbackText = "\(type.displayName) built. Gold: \(remainingGold)."
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
        case .invalidSlot:
            feedbackText = "Select a valid city lot."
        case .slotOccupied:
            feedbackText = "That lot is occupied."
        case .typeCapReached:
            feedbackText = "\(type.displayName) limit reached."
        case .unavailable:
            feedbackText = "Enter a city before building."
        }

        store.save(state)
        redraw()
    }

    func upgradeSelectedSlot() {
        guard let selectedSlot else {
            feedbackText = "Select a building first."
            redraw()
            return
        }

        let result = state.upgradeBuilding(inSlot: selectedSlot)
        switch result {
        case let .upgraded(_, newLevel, _):
            feedbackText = "Building upgraded to Lv \(newLevel)."
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
        case .invalidSlot:
            feedbackText = "Select a valid city lot."
        case .missingBuilding:
            feedbackText = "Build on this lot first."
        case .unavailable:
            feedbackText = "Enter a city before upgrading."
        }

        store.save(state)
        redraw()
    }

    func requestBattle() {
        store.save(state)
        router?.buildingViewSceneDidRequestBattle(self)
    }
}
```

Add DEBUG testing hooks:

```swift
#if DEBUG
extension BuildingViewScene {
    var buildingSlotCountForTesting: Int { CityBattleState.slotRange.count }
    var slotNodeCountForTesting: Int { slotNodes.count }
    var selectedSlotForTesting: Int? { selectedSlot }
    var goldTextForTesting: String? { goldLabel.text }
    var feedbackTextForTesting: String { feedbackText }

    var canBuildBarracksForTesting: Bool {
        guard let selectedSlot else { return false }
        return state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) == nil
    }

    var canBuildArcheryRangeForTesting: Bool {
        canBuildBarracksForTesting
    }

    var canUpgradeSelectedSlotForTesting: Bool {
        guard let selectedSlot else { return false }
        return state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) != nil
    }

    func selectSlotForTesting(_ slot: Int) {
        selectSlot(slot)
    }

    func buildSelectedSlotForTesting(_ type: BuildingType) {
        buildSelectedSlot(type)
    }

    func upgradeSelectedSlotForTesting() {
        upgradeSelectedSlot()
    }

    func requestBattleForTesting() {
        requestBattle()
    }

    func slotTextForTesting(_ slot: Int) -> String? {
        slotLabels[slot]?.text
    }
}
#endif
```

- [ ] **Step 4: Add routing from Battle to Building View**

Modify `BattleSceneRouting` in `Pyxis/BattleScene.swift`:

```swift
protocol BattleSceneRouting: AnyObject {
    func battleSceneDidRequestCountryMap(_ scene: BattleScene)
    func battleSceneDidRequestBuildingView(_ scene: BattleScene)
}
```

Add a private method:

```swift
private func requestBuildingView() {
    guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
        return
    }

    state.markCurrentCityBuildingProgressInactive(at: Date())
    store.save(state)
    router?.battleSceneDidRequestBuildingView(self)
}
```

Add DEBUG hook:

```swift
func requestBuildingViewForTesting() {
    requestBuildingView()
}
```

Modify `Pyxis/GameViewController.swift`:

```swift
private func presentBuildingViewScene(in view: SKView) {
    let scene = BuildingViewScene(size: view.bounds.size, store: store, router: self)
    scene.scaleMode = .resizeFill
    view.presentScene(scene)
}
```

Add Battle route:

```swift
func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
    guard let view = self.view as? SKView else {
        return
    }

    presentBuildingViewScene(in: view)
}
```

Add Building route:

```swift
extension GameViewController: BuildingViewSceneRouting {
    func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentBattleScene(in: view)
    }
}
```

- [ ] **Step 5: Run scene tests to verify Task 4 passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS for Building View routing and grid tests. If multiline labels do not render as expected in SKLabelNode, replace embedded newlines in `text(for:)` with `"Barracks Lv \(level)"` and update the test to check that string.

- [ ] **Step 6: Commit Task 4**

```bash
git add Pyxis/BuildingViewScene.swift Pyxis/BattleScene.swift Pyxis/GameViewController.swift PyxisTests/BuildingViewSceneTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "Add city building view scene"
```

---

### Task 5: Integrate Manual Type Selector, Manual Cap, And Active Building Spawns

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write failing BattleScene integration tests**

Add to `PyxisTests/BattleSceneTests.swift`:

```swift
@Test func manualSelectorChangesSpawnedSoldierType() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    #expect(scene.selectedManualSoldierTypeForTesting == .infantry)

    scene.selectManualSoldierTypeForTesting(.archer)
    scene.spawnSoldierForTesting()

    #expect(scene.selectedManualSoldierTypeForTesting == .archer)
    #expect(scene.liveSoldierTypesForTesting == [.archer])
}

@Test func manualSpawnCapBlocksEleventhManualSoldier() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 200))
    let scene = makeScene(store: store)

    for _ in 0..<10 {
        scene.spawnSoldierForTesting()
    }

    #expect(scene.liveSoldierCountForTesting == 10)

    scene.spawnSoldierForTesting()

    #expect(scene.liveSoldierCountForTesting == 10)
    #expect(scene.feedbackTextForTesting == "Manual squad is full.")
}

@Test func activeBuildingTimerCreatesBuildingSpawnedSoldierWithoutConsumingManualCap() throws {
    var initialState = KingdomGameState(gold: 100, cityRemainingPower: 200)
    #expect(initialState.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))
    let store = try makeStore(initialState: initialState)
    let scene = makeScene(store: store)

    for _ in 0..<10 {
        scene.spawnSoldierForTesting()
    }

    #expect(scene.manualLiveSoldierCountForTesting == 10)

    scene.advanceCombatForTesting(deltaTime: 10.0)

    #expect(scene.liveSoldierCountForTesting > 10)
    #expect(scene.manualLiveSoldierCountForTesting == 10)
    #expect(scene.buildingLiveSoldierCountForTesting > 0)
}
```

- [ ] **Step 2: Run BattleScene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because selector hooks, manual source counts, and active building spawning are not integrated.

- [ ] **Step 3: Add BattleScene state and UI nodes**

In `Pyxis/BattleScene.swift`, add button names:

```swift
static let build = "buildButton"
static let manualType = "manualSoldierTypeButton"
static let manualTypeInfantry = "manualTypeInfantry"
static let manualTypeArcher = "manualTypeArcher"
```

Add properties:

```swift
private var selectedManualSoldierType: SoldierType = .infantry
private var isManualTypeMenuVisible = false
private let buildButton = SKNode()
private let buildButtonBackground = SKShapeNode()
private let buildButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private let manualTypeButton = SKNode()
private let manualTypeButtonBackground = SKShapeNode()
private let manualTypeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private let manualTypeMenu = SKNode()
private let manualInfantryOption = SKNode()
private let manualArcherOption = SKNode()
```

In `buildInterface()`, configure the buttons with the existing `configureButton(_:background:label:name:color:)` helper:

```swift
configureButton(
    buildButton,
    background: buildButtonBackground,
    label: buildButtonLabel,
    name: ButtonName.build,
    color: SKColor(red: 0.18, green: 0.44, blue: 0.34, alpha: 1.0)
)
configureButton(
    manualTypeButton,
    background: manualTypeButtonBackground,
    label: manualTypeButtonLabel,
    name: ButtonName.manualType,
    color: SKColor(red: 0.18, green: 0.30, blue: 0.44, alpha: 1.0)
)
configureManualTypeMenu()
addChild(buildButton)
addChild(manualTypeButton)
addChild(manualTypeMenu)
```

Add menu helper:

```swift
private func configureManualTypeMenu() {
    manualTypeMenu.zPosition = GameUITheme.Z.hud + 2
    manualTypeMenu.isHidden = true
    configureMenuOption(manualInfantryOption, name: ButtonName.manualTypeInfantry, title: "Infantry")
    configureMenuOption(manualArcherOption, name: ButtonName.manualTypeArcher, title: "Archer")
    manualTypeMenu.addChild(manualInfantryOption)
    manualTypeMenu.addChild(manualArcherOption)
}

private func configureMenuOption(_ node: SKNode, name: String, title: String) {
    node.name = name
    let background = SKShapeNode(rectOf: CGSize(width: 128, height: 34), cornerRadius: 7)
    background.name = name
    background.fillColor = GameUITheme.Color.panelFill
    background.strokeColor = GameUITheme.Color.panelStroke
    background.lineWidth = 1
    let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    configureLabel(label, fontSize: 13, color: GameUITheme.Color.textPrimary)
    label.text = title
    label.name = name
    node.addChild(background)
    node.addChild(label)
}
```

- [ ] **Step 4: Wire selector, Build route, manual cap, and building spawns**

Update `touchesEnded` switch:

```swift
case ButtonName.build:
    requestBuildingView()
case ButtonName.manualType:
    toggleManualTypeMenu()
case ButtonName.manualTypeInfantry:
    selectManualSoldierType(.infantry)
case ButtonName.manualTypeArcher:
    selectManualSoldierType(.archer)
```

Add helpers:

```swift
private func toggleManualTypeMenu() {
    isManualTypeMenuVisible.toggle()
    manualTypeMenu.isHidden = !isManualTypeMenuVisible
}

private func selectManualSoldierType(_ type: SoldierType) {
    selectedManualSoldierType = type
    isManualTypeMenuVisible = false
    manualTypeMenu.isHidden = true
    feedbackText = "Manual spawn: \(type.displayName)."
    redraw()
}
```

Update `spawnSoldier()`:

```swift
private func spawnSoldier() {
    guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
        return
    }

    guard combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap else {
        feedbackText = "Manual squad is full."
        redraw()
        return
    }

    let soldierID = combat.spawnSoldier(
        type: selectedManualSoldierType,
        source: .manual,
        level: state.normalSoldierUpgradeLevel,
        attackPower: KingdomGameState.soldierAttackPower(for: selectedManualSoldierType, level: state.normalSoldierUpgradeLevel)
    )
    createSoldierNode(id: soldierID)
    syncSoldierNodes()
    updateLiveCombatStatusLabel()
}
```

Add building spawns before the combat tick in `advanceCombat(deltaTime:)`:

```swift
let buildingSpawns = state.resolveActiveBuildingSpawns(deltaTime: deltaTime)
for spawn in buildingSpawns {
    let soldierID = combat.spawnSoldier(
        type: spawn.soldierType,
        source: .building,
        level: spawn.level,
        attackPower: KingdomGameState.soldierAttackPower(for: spawn.soldierType, level: spawn.level)
    )
    createSoldierNode(id: soldierID)
}
if !buildingSpawns.isEmpty {
    store.save(state)
}
```

Keep the existing call `let result = combat.tick(deltaTime: deltaTime, cityRemainingHP: state.cityRemainingPower)` after this block.

- [ ] **Step 5: Layout new controls without overlapping existing HUD**

In `redraw()`:

```swift
spawnButtonLabel.text = "Spawn \(selectedManualSoldierType.displayName)"
manualTypeButtonLabel.text = selectedManualSoldierType.displayName
buildButtonLabel.text = "Build"
```

In `layoutInterface()`, place the selector above the spawn button and the build button above the upgrade button:

```swift
let secondaryButtonHeight: CGFloat = metrics.compactHeight ? 32 : 38
layoutButton(
    manualTypeButton,
    background: manualTypeButtonBackground,
    size: CGSize(width: min(132, metrics.spawnButtonWidth), height: secondaryButtonHeight),
    position: CGPoint(x: spawnButton.position.x, y: buttonY + metrics.buttonHeight / 2 + secondaryButtonHeight / 2 + 6)
)
layoutButton(
    buildButton,
    background: buildButtonBackground,
    size: CGSize(width: min(132, metrics.upgradeButtonWidth), height: secondaryButtonHeight),
    position: CGPoint(x: upgradeButton.position.x, y: buttonY + metrics.buttonHeight / 2 + secondaryButtonHeight / 2 + 6)
)
manualTypeMenu.position = CGPoint(x: manualTypeButton.position.x, y: manualTypeButton.position.y + secondaryButtonHeight + 22)
manualInfantryOption.position = CGPoint(x: 0, y: 18)
manualArcherOption.position = CGPoint(x: 0, y: -18)
```

Reduce available battlefield bottom if needed by passing the top of secondary controls as the effective action top:

```swift
let actionTopY = max(buttonTopY, manualTypeButton.position.y + secondaryButtonHeight / 2, buildButton.position.y + secondaryButtonHeight / 2)
layoutBattlefield(
    contentWidth: metrics.contentWidth,
    hpBarBottomY: hudBottomY,
    spawnButtonTopY: actionTopY,
    feedbackY: feedbackY
)
```

- [ ] **Step 6: Add DEBUG hooks**

Add to the existing DEBUG extension in `Pyxis/BattleScene.swift`:

```swift
var selectedManualSoldierTypeForTesting: SoldierType {
    selectedManualSoldierType
}

var manualLiveSoldierCountForTesting: Int {
    combat.livingSoldierCount(source: .manual)
}

var buildingLiveSoldierCountForTesting: Int {
    combat.livingSoldierCount(source: .building)
}

var liveSoldierTypesForTesting: [SoldierType] {
    combat.soldiers.filter(\.isAlive).map(\.type)
}

func selectManualSoldierTypeForTesting(_ type: SoldierType) {
    selectManualSoldierType(type)
}
```

- [ ] **Step 7: Run BattleScene tests to verify Task 5 passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 8: Commit Task 5**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Integrate building spawns into battle"
```

---

### Task 6: Full Verification And Polish Pass

**Files:**
- Modify only files touched by failing tests or layout defects found in this task.

- [ ] **Step 1: Run focused model suites**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/BattleCombatStateTests -only-testing:PyxisTests/KingdomGameStoreTests
```

Expected: PASS.

- [ ] **Step 2: Run focused scene suites**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests -only-testing:PyxisTests/BuildingViewSceneTests -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: PASS.

- [ ] **Step 3: Run full test suite**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

Expected: PASS. If `iPhone 17` is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun the full suite with an available iOS Simulator destination.

- [ ] **Step 4: Inspect final diff scope**

Run:

```bash
git status -sb
git diff --stat
```

Expected: only planned files changed:

```text
Pyxis/SoldierType.swift
Pyxis/CityBuildingState.swift
Pyxis/KingdomGameState.swift
Pyxis/BattleCombatState.swift
Pyxis/BuildingViewScene.swift
Pyxis/BattleScene.swift
Pyxis/GameViewController.swift
PyxisTests/KingdomGameStateTests.swift
PyxisTests/KingdomGameStoreTests.swift
PyxisTests/BattleCombatStateTests.swift
PyxisTests/BattleSceneTests.swift
PyxisTests/BuildingViewSceneTests.swift
```

- [ ] **Step 5: Commit verification fixes if any were needed**

If Step 1, Step 2, or Step 3 required code changes, commit those changes:

```bash
git add Pyxis PyxisTests
git commit -m "Polish city building view integration"
```

If no changes were needed, do not create an empty commit.

---

## Self-Review Checklist

- Spec coverage:
  - 25-slot city grid: Task 1 model, Task 4 scene.
  - Any empty slot build: Task 1 and Task 4.
  - 5 buildings per type per city: Task 1.
  - Global gold construction/upgrades: Task 1.
  - Infantry and Archer: Task 3 and Task 5.
  - Manual selector: Task 5.
  - Shared manual cap 10: Task 3 and Task 5.
  - Building-spawned live soldiers: Task 2 model, Task 5 scene integration.
  - Building-based idle damage replacing old idle damage: Task 2.
  - No queued soldiers: Task 2 converts idle spawns directly to damage.
  - City-keyed isolation for future simultaneous cities: Task 1 storage shape and tests.
  - Building data clears after conquest: Task 1 and Task 2 tests.

- Placeholder scan:
  - No `TBD`, `TODO`, or unspecified implementation steps remain.
  - Every test step includes concrete test code.
  - Every implementation step names concrete files, types, methods, and commands.

- Type consistency:
  - `SoldierType`, `SoldierSpawnSource`, `BuildingType`, `CityKey`, `CityBuilding`, `CityBattleState`, and `BuildingSpawn` are introduced before later tasks reference them.
  - `BuildBuildingResult` and `UpgradeBuildingResult` names match test expectations.
  - `BattleSceneRouting` and `BuildingViewSceneRouting` signatures match router spies and `GameViewController`.
