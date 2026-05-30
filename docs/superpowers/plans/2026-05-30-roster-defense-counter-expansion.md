# Roster Defense Counter Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand Pyxis from Infantry/Archer battles into a five-unit roster with per-city defense traits, building-level unit scaling, unlock pacing, and light counter modifiers in live and idle damage.

**Architecture:** Keep durable rules in pure Swift models and keep SpriteKit scenes as presentation/controllers. `KingdomGameState` owns unlocks, manual unit levels, defense trait lookup, trait-adjusted damage, idle damage, and build validation; `BattleCombatState` stays transient and receives already adjusted attack power. Scene work consumes these model APIs instead of duplicating rules.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, Xcode project with `PBXFileSystemSynchronizedRootGroup`.

---

## Source Spec

- Design spec: `docs/superpowers/specs/2026-05-30-roster-defense-counter-expansion-design.md`

## File Structure

- Modify: `Pyxis/SoldierType.swift`
  - Expand `SoldierType` to five cases.
  - Keep display names centralized.
- Modify: `Pyxis/CityBuildingState.swift`
  - Expand `BuildingType` to five cases.
  - Add building-to-soldier mapping and short display text.
  - Extend `BuildBuildingResult` only in `KingdomGameState`, not here.
- Create: `Pyxis/CityDefenseTrait.swift`
  - Pure Swift enum for authored city traits, display names, descriptions, and damage modifiers.
- Modify: `Pyxis/KingdomGameState.swift`
  - Add building unlock APIs.
  - Add `lockedBuilding` result.
  - Remove battle global upgrade usage while preserving decode compatibility for `normalSoldierUpgradeLevel`.
  - Add manual spawn level lookup.
  - Add trait-adjusted soldier damage helpers.
  - Apply adjusted damage in active and idle building paths.
- Modify: `Pyxis/BattleCombatState.swift`
  - Add stats for Cavalry, Mage, and Siege using the existing live combat fields.
- Modify: `Pyxis/BattleScene.swift`
  - Remove Upgrade button flow.
  - Show defense trait in HUD.
  - Build a dynamic manual unit menu from current-city built buildings.
  - Block manual spawn until a matching building exists.
  - Spawn manual units at highest matching building level.
  - Spawn building units with trait-adjusted attack power.
- Modify: `Pyxis/BuildingViewScene.swift`
  - Replace fixed Barracks/Archery buttons with dynamic build buttons for all five building types.
  - Show locked building types as disabled with unlock feedback.
  - Keep building upgrades as the unit-scaling path.
- Modify: `Pyxis/CountryMapScene.swift`
  - Show defense trait text for completed and unlocked visible cities.
- Modify tests:
  - `PyxisTests/KingdomGameStateTests.swift`
  - `PyxisTests/BattleCombatStateTests.swift`
  - `PyxisTests/BattleSceneTests.swift`
  - `PyxisTests/BuildingViewSceneTests.swift`
  - `PyxisTests/CountryMapSceneTests.swift`

## Verification Commands

Use the local simulator that exists. This repo has previously verified reliably with iPhone 17:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleCombatStateTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/CountryMapSceneTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

If that simulator is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

and substitute a listed iOS Simulator destination.

---

### Task 1: Expand Pure Type Catalogs And Defense Traits

**Files:**
- Modify: `Pyxis/SoldierType.swift`
- Modify: `Pyxis/CityBuildingState.swift`
- Create: `Pyxis/CityDefenseTrait.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Write failing type catalog tests**

Add these tests near the existing formula tests in `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func expandedSoldierCatalogHasDisplayNames() {
    #expect(SoldierType.allCases == [.infantry, .archer, .cavalry, .mage, .siege])
    #expect(SoldierType.infantry.displayName == "Infantry")
    #expect(SoldierType.archer.displayName == "Archer")
    #expect(SoldierType.cavalry.displayName == "Cavalry")
    #expect(SoldierType.mage.displayName == "Mage")
    #expect(SoldierType.siege.displayName == "Siege")
}

@Test func expandedBuildingCatalogMapsToSoldierTypes() {
    #expect(BuildingType.allCases == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop])
    #expect(BuildingType.barracks.displayName == "Barracks")
    #expect(BuildingType.archeryRange.displayName == "Archery Range")
    #expect(BuildingType.stable.displayName == "Stable")
    #expect(BuildingType.mageTower.displayName == "Mage Tower")
    #expect(BuildingType.siegeWorkshop.displayName == "Siege Workshop")

    #expect(BuildingType.barracks.shortDisplayName == "Barracks")
    #expect(BuildingType.archeryRange.shortDisplayName == "Archery")
    #expect(BuildingType.stable.shortDisplayName == "Stable")
    #expect(BuildingType.mageTower.shortDisplayName == "Mage")
    #expect(BuildingType.siegeWorkshop.shortDisplayName == "Siege")

    #expect(BuildingType.barracks.soldierType == .infantry)
    #expect(BuildingType.archeryRange.soldierType == .archer)
    #expect(BuildingType.stable.soldierType == .cavalry)
    #expect(BuildingType.mageTower.soldierType == .mage)
    #expect(BuildingType.siegeWorkshop.soldierType == .siege)
}

@Test func cityDefenseTraitsExposeDisplayAndCounterMetadata() {
    #expect(CityDefenseTrait.allCases == [
        .standardWatch,
        .arrowTower,
        .spikedGate,
        .stoneWall,
        .arcaneWard,
        .burningOil,
        .reinforcedKeep
    ])

    #expect(CityDefenseTrait.standardWatch.displayName == "Standard Watch")
    #expect(CityDefenseTrait.arrowTower.displayName == "Arrow Tower")
    #expect(CityDefenseTrait.spikedGate.displayName == "Spiked Gate")
    #expect(CityDefenseTrait.stoneWall.displayName == "Stone Wall")
    #expect(CityDefenseTrait.arcaneWard.displayName == "Arcane Ward")
    #expect(CityDefenseTrait.burningOil.displayName == "Burning Oil")
    #expect(CityDefenseTrait.reinforcedKeep.displayName == "Reinforced Keep")

    #expect(CityDefenseTrait.standardWatch.damageMultiplier(for: .infantry) == 1.0)
    #expect(CityDefenseTrait.arrowTower.damageMultiplier(for: .cavalry) == 1.25)
    #expect(CityDefenseTrait.arrowTower.damageMultiplier(for: .archer) == 0.80)
    #expect(CityDefenseTrait.spikedGate.damageMultiplier(for: .mage) == 1.25)
    #expect(CityDefenseTrait.spikedGate.damageMultiplier(for: .infantry) == 0.80)
    #expect(CityDefenseTrait.stoneWall.damageMultiplier(for: .siege) == 1.25)
    #expect(CityDefenseTrait.arcaneWard.damageMultiplier(for: .mage) == 0.80)
    #expect(CityDefenseTrait.burningOil.damageMultiplier(for: .siege) == 0.80)
    #expect(CityDefenseTrait.reinforcedKeep.damageMultiplier(for: .siege) == 1.25)
}
```

- [ ] **Step 2: Run catalog tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests/expandedSoldierCatalogHasDisplayNames -only-testing:PyxisTests/KingdomGameStateTests/expandedBuildingCatalogMapsToSoldierTypes -only-testing:PyxisTests/KingdomGameStateTests/cityDefenseTraitsExposeDisplayAndCounterMetadata
```

Expected: FAIL because `CityDefenseTrait`, new soldier cases, new building cases, and `shortDisplayName` do not exist.

- [ ] **Step 3: Expand `SoldierType`**

In `Pyxis/SoldierType.swift`, replace the `SoldierType` enum with:

```swift
enum SoldierType: String, Codable, CaseIterable, Equatable {
    case infantry
    case archer
    case cavalry
    case mage
    case siege

    var displayName: String {
        switch self {
        case .infantry:
            return "Infantry"
        case .archer:
            return "Archer"
        case .cavalry:
            return "Cavalry"
        case .mage:
            return "Mage"
        case .siege:
            return "Siege"
        }
    }
}
```

Keep `SoldierSpawnSource` unchanged.

- [ ] **Step 4: Expand `BuildingType`**

In `Pyxis/CityBuildingState.swift`, replace `BuildingType` with:

```swift
enum BuildingType: String, Codable, CaseIterable, Equatable {
    case barracks
    case archeryRange
    case stable
    case mageTower
    case siegeWorkshop

    var displayName: String {
        switch self {
        case .barracks:
            return "Barracks"
        case .archeryRange:
            return "Archery Range"
        case .stable:
            return "Stable"
        case .mageTower:
            return "Mage Tower"
        case .siegeWorkshop:
            return "Siege Workshop"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .barracks:
            return "Barracks"
        case .archeryRange:
            return "Archery"
        case .stable:
            return "Stable"
        case .mageTower:
            return "Mage"
        case .siegeWorkshop:
            return "Siege"
        }
    }

    var soldierType: SoldierType {
        switch self {
        case .barracks:
            return .infantry
        case .archeryRange:
            return .archer
        case .stable:
            return .cavalry
        case .mageTower:
            return .mage
        case .siegeWorkshop:
            return .siege
        }
    }
}
```

- [ ] **Step 5: Add `CityDefenseTrait`**

Create `Pyxis/CityDefenseTrait.swift`:

```swift
//
//  CityDefenseTrait.swift
//  Pyxis
//

import Foundation

enum CityDefenseTrait: String, CaseIterable, Equatable {
    case standardWatch
    case arrowTower
    case spikedGate
    case stoneWall
    case arcaneWard
    case burningOil
    case reinforcedKeep

    var displayName: String {
        switch self {
        case .standardWatch:
            return "Standard Watch"
        case .arrowTower:
            return "Arrow Tower"
        case .spikedGate:
            return "Spiked Gate"
        case .stoneWall:
            return "Stone Wall"
        case .arcaneWard:
            return "Arcane Ward"
        case .burningOil:
            return "Burning Oil"
        case .reinforcedKeep:
            return "Reinforced Keep"
        }
    }

    var shortDescription: String {
        switch self {
        case .standardWatch:
            return "No counter modifiers."
        case .arrowTower:
            return "Durable and fast melee troops perform better."
        case .spikedGate:
            return "Ranged troops avoid the gate's melee punishment."
        case .stoneWall:
            return "Magic and siege attacks break through stone."
        case .arcaneWard:
            return "Non-magic troops avoid the ward's resistance."
        case .burningOil:
            return "Fast or ranged troops avoid slow close-range losses."
        case .reinforcedKeep:
            return "Siege attacks perform best against the keep."
        }
    }

    var hudText: String {
        "\(displayName): \(shortDescription)"
    }

    func damageMultiplier(for soldierType: SoldierType) -> Double {
        switch self {
        case .standardWatch:
            return 1.0
        case .arrowTower:
            switch soldierType {
            case .infantry, .cavalry:
                return 1.25
            case .archer, .mage:
                return 0.80
            case .siege:
                return 1.0
            }
        case .spikedGate:
            switch soldierType {
            case .archer, .mage:
                return 1.25
            case .infantry, .cavalry:
                return 0.80
            case .siege:
                return 1.0
            }
        case .stoneWall:
            switch soldierType {
            case .mage, .siege:
                return 1.25
            case .archer:
                return 0.80
            case .infantry, .cavalry:
                return 1.0
            }
        case .arcaneWard:
            switch soldierType {
            case .infantry, .cavalry, .siege:
                return 1.25
            case .mage:
                return 0.80
            case .archer:
                return 1.0
            }
        case .burningOil:
            switch soldierType {
            case .archer, .mage, .cavalry:
                return 1.25
            case .infantry, .siege:
                return 0.80
            }
        case .reinforcedKeep:
            switch soldierType {
            case .siege:
                return 1.25
            case .archer, .infantry:
                return 0.80
            case .cavalry, .mage:
                return 1.0
            }
        }
    }
}
```

- [ ] **Step 6: Run catalog tests and verify pass**

Run the same command from Step 2.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/SoldierType.swift Pyxis/CityBuildingState.swift Pyxis/CityDefenseTrait.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Expand unit and defense catalogs"
```

---

### Task 2: Add Unlocks, Manual Unit Levels, Costs, And Defense Progression

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Write failing unlock and manual-level tests**

Add these tests to `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func buildingUnlocksProgressAcrossCountryOne() {
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 1) == [.barracks])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 2) == [.barracks, .archeryRange])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 4) == [.barracks, .archeryRange])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 5) == [.barracks, .archeryRange, .stable])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 8) == [.barracks, .archeryRange, .stable, .mageTower])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 11) == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop])
    #expect(KingdomGameState.unlockedBuildingTypes(forCityNumber: 99) == [.barracks, .archeryRange, .stable, .mageTower, .siegeWorkshop])
}

@Test func buildingCostsCoverExpandedCatalog() {
    #expect(KingdomGameState.buildingBuildCost(for: .barracks) == 15)
    #expect(KingdomGameState.buildingBuildCost(for: .archeryRange) == 18)
    #expect(KingdomGameState.buildingBuildCost(for: .stable) == 28)
    #expect(KingdomGameState.buildingBuildCost(for: .mageTower) == 40)
    #expect(KingdomGameState.buildingBuildCost(for: .siegeWorkshop) == 55)

    #expect(KingdomGameState.buildingUpgradeCost(for: .stable, currentLevel: 1) == 22)
    #expect(KingdomGameState.buildingUpgradeCost(for: .mageTower, currentLevel: 1) == 30)
    #expect(KingdomGameState.buildingUpgradeCost(for: .siegeWorkshop, currentLevel: 1) == 42)
}

@Test func activeSpawnIntervalsCoverExpandedCatalog() {
    #expect(KingdomGameState.activeSpawnInterval(for: .barracks) == 10)
    #expect(KingdomGameState.activeSpawnInterval(for: .archeryRange) == 12)
    #expect(KingdomGameState.activeSpawnInterval(for: .stable) == 14)
    #expect(KingdomGameState.activeSpawnInterval(for: .mageTower) == 16)
    #expect(KingdomGameState.activeSpawnInterval(for: .siegeWorkshop) == 20)
}

@Test func lockedBuildingsCannotBeBuiltBeforeUnlockCity() {
    var state = KingdomGameState(gold: 500, cityNumberInCountry: 4, completedCityCount: 3)

    #expect(state.buildBuilding(.stable, inSlot: 1) == .lockedBuilding(unlocksAtCity: 5))
    #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
    #expect(state.gold == 500)
}

@Test func unlockedBuildingsCanBeBuiltAtUnlockCity() {
    var state = KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)

    #expect(state.buildBuilding(.stable, inSlot: 1) == .built(cost: 28, remainingGold: 472))
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .stable)
}

@Test func manualSoldierLevelRequiresMatchingCurrentCityBuilding() {
    var state = KingdomGameState(gold: 500, cityNumberInCountry: 8, completedCityCount: 7)

    #expect(state.manualSoldierLevel(for: .mage) == nil)

    #expect(state.buildBuilding(.mageTower, inSlot: 1) == .built(cost: 40, remainingGold: 460))
    #expect(state.manualSoldierLevel(for: .mage) == 1)

    #expect(state.buildBuilding(.mageTower, inSlot: 2) == .built(cost: 40, remainingGold: 420))
    #expect(state.upgradeBuilding(inSlot: 2) == .upgraded(cost: 30, newLevel: 2, remainingGold: 390))
    #expect(state.manualSoldierLevel(for: .mage) == 2)
}

@Test func currentCityDefenseTraitUsesAuthoredProgression() {
    let expected: [Int: CityDefenseTrait] = [
        1: .standardWatch,
        2: .standardWatch,
        3: .arrowTower,
        4: .spikedGate,
        5: .arrowTower,
        6: .stoneWall,
        7: .burningOil,
        8: .stoneWall,
        9: .arcaneWard,
        10: .spikedGate,
        11: .reinforcedKeep,
        12: .burningOil,
        13: .arcaneWard,
        14: .stoneWall,
        15: .reinforcedKeep
    ]

    for (cityNumber, trait) in expected {
        #expect(KingdomGameState.defenseTrait(forCityNumber: cityNumber) == trait)
    }

    let state = KingdomGameState(cityNumberInCountry: 11, completedCityCount: 10)
    #expect(state.currentCityDefenseTrait == .reinforcedKeep)
}
```

- [ ] **Step 2: Run unlock tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests/buildingUnlocksProgressAcrossCountryOne -only-testing:PyxisTests/KingdomGameStateTests/buildingCostsCoverExpandedCatalog -only-testing:PyxisTests/KingdomGameStateTests/activeSpawnIntervalsCoverExpandedCatalog -only-testing:PyxisTests/KingdomGameStateTests/lockedBuildingsCannotBeBuiltBeforeUnlockCity -only-testing:PyxisTests/KingdomGameStateTests/unlockedBuildingsCanBeBuiltAtUnlockCity -only-testing:PyxisTests/KingdomGameStateTests/manualSoldierLevelRequiresMatchingCurrentCityBuilding -only-testing:PyxisTests/KingdomGameStateTests/currentCityDefenseTraitUsesAuthoredProgression
```

Expected: FAIL because new APIs and `.lockedBuilding` do not exist.

- [ ] **Step 3: Add `lockedBuilding` build result**

In `Pyxis/KingdomGameState.swift`, add a new case to `BuildBuildingResult`:

```swift
case lockedBuilding(unlocksAtCity: Int)
```

- [ ] **Step 4: Add unlock and trait APIs**

In `KingdomGameState`, add these static helpers near the existing formula helpers:

```swift
static func unlockedBuildingTypes(forCityNumber cityNumber: Int) -> [BuildingType] {
    let city = min(max(1, cityNumber), firstCountryCityCount)
    return BuildingType.allCases.filter { city >= unlockCity(for: $0) }
}

static func unlockCity(for buildingType: BuildingType) -> Int {
    switch buildingType {
    case .barracks:
        return 1
    case .archeryRange:
        return 2
    case .stable:
        return 5
    case .mageTower:
        return 8
    case .siegeWorkshop:
        return 11
    }
}

func isBuildingTypeUnlocked(_ buildingType: BuildingType) -> Bool {
    Self.unlockedBuildingTypes(forCityNumber: cityNumberInCountry).contains(buildingType)
}

static func defenseTrait(forCityNumber cityNumber: Int) -> CityDefenseTrait {
    switch min(max(1, cityNumber), firstCountryCityCount) {
    case 1, 2:
        return .standardWatch
    case 3, 5:
        return .arrowTower
    case 4, 10:
        return .spikedGate
    case 6, 8, 14:
        return .stoneWall
    case 7, 12:
        return .burningOil
    case 9, 13:
        return .arcaneWard
    case 11, 15:
        return .reinforcedKeep
    default:
        return .standardWatch
    }
}

var currentCityDefenseTrait: CityDefenseTrait {
    Self.defenseTrait(forCityNumber: cityNumberInCountry)
}

func manualSoldierLevel(for soldierType: SoldierType) -> Int? {
    let matchingLevels = cityBattleStateForCurrentCity.slots.values
        .filter { $0.type.soldierType == soldierType }
        .map(\.level)
    return matchingLevels.max()
}

func manualSpawnableSoldierTypes() -> [SoldierType] {
    SoldierType.allCases.filter { manualSoldierLevel(for: $0) != nil }
}
```

- [ ] **Step 5: Gate building construction by unlock**

In `buildBuilding(_:inSlot:at:)`, after the slot validity guard and before fetching city state, add:

```swift
guard isBuildingTypeUnlocked(type) else {
    return .lockedBuilding(unlocksAtCity: Self.unlockCity(for: type))
}
```

- [ ] **Step 6: Extend cost and spawn interval formulas**

Replace `buildingBuildCost(for:)` with:

```swift
static func buildingBuildCost(for type: BuildingType) -> Int {
    switch type {
    case .barracks:
        return 15
    case .archeryRange:
        return 18
    case .stable:
        return 28
    case .mageTower:
        return 40
    case .siegeWorkshop:
        return 55
    }
}
```

Replace `buildingUpgradeCost(for:currentLevel:)` base switch with:

```swift
let base: Double
switch type {
case .barracks:
    base = 12
case .archeryRange:
    base = 14
case .stable:
    base = 22
case .mageTower:
    base = 30
case .siegeWorkshop:
    base = 42
}
```

Replace `activeSpawnInterval(for:)` with:

```swift
static func activeSpawnInterval(for type: BuildingType) -> Double {
    switch type {
    case .barracks:
        return 10
    case .archeryRange:
        return 12
    case .stable:
        return 14
    case .mageTower:
        return 16
    case .siegeWorkshop:
        return 20
    }
}
```

- [ ] **Step 7: Update existing switch handling for build result**

Search:

```bash
rg -n "BuildBuildingResult|buildBuilding\\(|\\.slotOccupied|\\.typeCapReached" Pyxis PyxisTests
```

Every switch over `BuildBuildingResult` must handle:

```swift
case let .lockedBuilding(unlocksAtCity):
    feedbackText = "\(type.displayName) unlocks at City \(unlocksAtCity)."
```

For tests comparing exact build results, keep existing Barracks/Archery results unchanged.

- [ ] **Step 8: Run unlock tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add building unlock and defense progression rules"
```

---

### Task 3: Apply Counter-Adjusted Damage In Live Inputs And Idle Building Damage

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Write failing damage modifier tests**

Add these tests to `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func traitAdjustedSoldierAttackPowerUsesCounterMultiplier() {
    #expect(KingdomGameState.soldierAttackPower(for: .infantry, level: 1) == 1)
    #expect(KingdomGameState.soldierAttackPower(for: .siege, level: 4) == 3)

    #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
        for: .siege,
        level: 4,
        defenseTrait: .reinforcedKeep
    ) == 4)

    #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
        for: .archer,
        level: 4,
        defenseTrait: .reinforcedKeep
    ) == 2)

    #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
        for: .infantry,
        level: 1,
        defenseTrait: .reinforcedKeep
    ) == 1)
}

@Test func idleDamageUsesCurrentCityDefenseTraitCounters() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let end = start.addingTimeInterval(1_000)
    var state = KingdomGameState(
        gold: 500,
        cityRemainingPower: 100,
        lastBackgroundedAt: start,
        cityNumberInCountry: 11,
        completedCityCount: 10
    )

    #expect(state.buildBuilding(.siegeWorkshop, inSlot: 1, at: start) == .built(cost: 55, remainingGold: 445))
    #expect(state.upgradeBuilding(inSlot: 1, at: start) == .upgraded(cost: 42, newLevel: 2, remainingGold: 403))
    #expect(state.upgradeBuilding(inSlot: 1, at: start) == .upgraded(cost: 69, newLevel: 3, remainingGold: 334))
    state.enterBackground(at: start)

    let result = state.returnFromBackground(at: end)

    #expect(state.currentCityDefenseTrait == .reinforcedKeep)
    #expect(result.elapsedSeconds == 1000)
    #expect(result.damageDealt == 15)
    #expect(state.cityRemainingPower == 85)
}

@Test func idleDamagePenaltyStillDealsAtLeastOneWhenBaseDamageIsPositive() {
    let start = Date(timeIntervalSinceReferenceDate: 2_000)
    let end = start.addingTimeInterval(1_000)
    var state = KingdomGameState(
        gold: 500,
        cityRemainingPower: 100,
        lastBackgroundedAt: start,
        cityNumberInCountry: 11,
        completedCityCount: 10
    )

    #expect(state.buildBuilding(.archeryRange, inSlot: 1, at: start) == .built(cost: 18, remainingGold: 482))
    state.enterBackground(at: start)

    let result = state.returnFromBackground(at: end)

    #expect(state.currentCityDefenseTrait == .reinforcedKeep)
    #expect(result.damageDealt > 0)
}
```

- [ ] **Step 2: Run damage tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests/traitAdjustedSoldierAttackPowerUsesCounterMultiplier -only-testing:PyxisTests/KingdomGameStateTests/idleDamageUsesCurrentCityDefenseTraitCounters -only-testing:PyxisTests/KingdomGameStateTests/idleDamagePenaltyStillDealsAtLeastOneWhenBaseDamageIsPositive
```

Expected: FAIL because `traitAdjustedSoldierAttackPower` does not exist and idle damage still uses unmodified damage.

- [ ] **Step 3: Add trait-adjusted damage helper**

In `KingdomGameState`, replace the current `soldierAttackPower(for:level:)` helper with this pair:

```swift
static func soldierAttackPower(for _: SoldierType, level: Int) -> Int {
    normalSoldierAttackPower(for: level)
}

static func traitAdjustedSoldierAttackPower(
    for soldierType: SoldierType,
    level: Int,
    defenseTrait: CityDefenseTrait
) -> Int {
    let baseDamage = soldierAttackPower(for: soldierType, level: level)
    guard baseDamage > 0 else {
        return 0
    }

    let adjusted = Double(baseDamage) * defenseTrait.damageMultiplier(for: soldierType)
    return max(1, Int(adjusted.rounded()))
}

func traitAdjustedSoldierAttackPower(for soldierType: SoldierType, level: Int) -> Int {
    Self.traitAdjustedSoldierAttackPower(
        for: soldierType,
        level: level,
        defenseTrait: currentCityDefenseTrait
    )
}
```

- [ ] **Step 4: Apply trait-adjusted damage in settlement and idle**

In `settleCurrentCityBuildingProgress(at:)`, replace:

```swift
let totalDamage = spawns.reduce(0) { total, spawn in
    total + Self.soldierAttackPower(for: spawn.soldierType, level: spawn.level)
}
```

with:

```swift
let defenseTrait = currentCityDefenseTrait
let totalDamage = spawns.reduce(0) { total, spawn in
    total + Self.traitAdjustedSoldierAttackPower(
        for: spawn.soldierType,
        level: spawn.level,
        defenseTrait: defenseTrait
    )
}
```

In `resolveCurrentCityBuildingIdleProgress(at:)`, replace the `totalPotentialDamage` reduce block with the same trait-adjusted helper:

```swift
let defenseTrait = currentCityDefenseTrait
totalPotentialDamage = spawns.reduce(0) { total, spawn in
    total + Self.traitAdjustedSoldierAttackPower(
        for: spawn.soldierType,
        level: spawn.level,
        defenseTrait: defenseTrait
    )
}
```

- [ ] **Step 5: Run damage tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Apply city defense counters to building damage"
```

---

### Task 4: Add Live Combat Stats For New Soldier Types

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`

- [ ] **Step 1: Write failing live-stat tests**

Add these tests to `PyxisTests/BattleCombatStateTests.swift`:

```swift
@Test func expandedSoldierTypesUseDistinctCombatStats() throws {
    var combat = BattleCombatState(configuration: .live(cityLevel: 1))

    let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2)
    let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2)
    let cavalry = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 2)
    let mage = combat.spawnSoldier(type: .mage, source: .manual, level: 1, attackPower: 2)
    let siege = combat.spawnSoldier(type: .siege, source: .manual, level: 1, attackPower: 2)

    let infantrySoldier = try #require(combat.soldier(id: infantry))
    let archerSoldier = try #require(combat.soldier(id: archer))
    let cavalrySoldier = try #require(combat.soldier(id: cavalry))
    let mageSoldier = try #require(combat.soldier(id: mage))
    let siegeSoldier = try #require(combat.soldier(id: siege))

    #expect(infantrySoldier.maxHP > archerSoldier.maxHP)
    #expect(cavalrySoldier.movementSpeed > infantrySoldier.movementSpeed)
    #expect(mageSoldier.attackRange > infantrySoldier.attackRange)
    #expect(siegeSoldier.attackPower == 2)
    #expect(siegeSoldier.attackSpeed < infantrySoldier.attackSpeed)
    #expect(siegeSoldier.movementSpeed < infantrySoldier.movementSpeed)
}

@Test func newSoldierTypeLevelsIncreaseHP() throws {
    var combat = BattleCombatState(configuration: .live(cityLevel: 1))

    let low = combat.spawnSoldier(type: .siege, source: .building, level: 1, attackPower: 1)
    let high = combat.spawnSoldier(type: .siege, source: .building, level: 4, attackPower: 4)

    let lowSoldier = try #require(combat.soldier(id: low))
    let highSoldier = try #require(combat.soldier(id: high))

    #expect(highSoldier.maxHP > lowSoldier.maxHP)
    #expect(highSoldier.level == 4)
    #expect(highSoldier.attackPower == 4)
}
```

- [ ] **Step 2: Run live-stat tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleCombatStateTests/expandedSoldierTypesUseDistinctCombatStats -only-testing:PyxisTests/BattleCombatStateTests/newSoldierTypeLevelsIncreaseHP
```

Expected: FAIL because `BattleCombatState` switch statements are not exhaustive or new type stats are not implemented.

- [ ] **Step 3: Add per-type HP**

Replace `maxHP(for:level:)` with:

```swift
private func maxHP(for type: SoldierType, level: Int) -> Int {
    let baseConfigurationHP = Double(max(1, configuration.soldierMaxHP))
    let baseHP: Double
    switch type {
    case .infantry:
        baseHP = baseConfigurationHP
    case .archer:
        baseHP = baseConfigurationHP * 0.7
    case .cavalry:
        baseHP = baseConfigurationHP * 0.9
    case .mage:
        baseHP = baseConfigurationHP * 0.65
    case .siege:
        baseHP = baseConfigurationHP * 1.35
    }

    return max(1, Int((baseHP * pow(1.25, Double(max(1, level) - 1))).rounded()))
}
```

- [ ] **Step 4: Add per-type range, speed, and attack-speed helpers**

Replace `attackRange(for:)` with:

```swift
private func attackRange(for type: SoldierType) -> Double {
    let baseRange = min(max(0, configuration.soldierAttackRange), 1)
    switch type {
    case .infantry:
        return baseRange
    case .archer:
        return min(baseRange * 2.2, 1)
    case .cavalry:
        return baseRange
    case .mage:
        return min(baseRange * 2.0, 1)
    case .siege:
        return min(baseRange * 1.5, 1)
    }
}
```

Add these helpers below `attackRange(for:)`:

```swift
private func attackSpeed(for type: SoldierType) -> Double {
    let baseSpeed = max(0.1, configuration.soldierAttackSpeed)
    switch type {
    case .infantry:
        return baseSpeed
    case .archer:
        return baseSpeed
    case .cavalry:
        return baseSpeed * 1.15
    case .mage:
        return baseSpeed * 0.85
    case .siege:
        return baseSpeed * 0.55
    }
}

private func movementSpeed(for type: SoldierType) -> Double {
    let baseSpeed = max(0, configuration.soldierMovementSpeed)
    switch type {
    case .infantry:
        return baseSpeed
    case .archer:
        return baseSpeed
    case .cavalry:
        return baseSpeed * 1.45
    case .mage:
        return baseSpeed * 0.9
    case .siege:
        return baseSpeed * 0.55
    }
}
```

- [ ] **Step 5: Use per-type speed helpers during spawn**

In `spawnSoldier(type:source:level:attackPower:)`, replace:

```swift
attackSpeed: max(0.1, configuration.soldierAttackSpeed),
attackRange: attackRange(for: type),
movementSpeed: max(0, configuration.soldierMovementSpeed),
```

with:

```swift
attackSpeed: attackSpeed(for: type),
attackRange: attackRange(for: type),
movementSpeed: movementSpeed(for: type),
```

- [ ] **Step 6: Run live-stat tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "Add combat stats for expanded roster"
```

---

### Task 5: Convert Building View To Five Dynamic Build Actions

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Write failing Building View tests**

Update `selectingEmptySlotExposesBuildActions` and add new tests in `PyxisTests/BuildingViewSceneTests.swift`:

```swift
@Test func selectingEmptySlotExposesUnlockedAndLockedBuildActions() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4))
    let scene = makeScene(store: store, router: RouteSpy())

    scene.selectSlotForTesting(3)

    #expect(scene.selectedSlotForTesting == 3)
    #expect(scene.buildButtonTextsForTesting == [
        "Build Barracks",
        "Build Archery",
        "Build Stable",
        "Mage City 8",
        "Siege City 11"
    ])
    #expect(scene.canBuildForTesting(.barracks))
    #expect(scene.canBuildForTesting(.archeryRange))
    #expect(scene.canBuildForTesting(.stable))
    #expect(!scene.canBuildForTesting(.mageTower))
    #expect(!scene.canBuildForTesting(.siegeWorkshop))
    #expect(!scene.canUpgradeSelectedSlotForTesting)
}

@Test func lockedBuildActionShowsUnlockFeedback() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 500, cityNumberInCountry: 4, completedCityCount: 3))
    let scene = makeScene(store: store, router: RouteSpy())

    scene.selectSlotForTesting(3)
    scene.buildSelectedSlotForTesting(.stable)

    #expect(scene.feedbackTextForTesting == "Stable unlocks at City 5.")
    #expect(store.load().cityBattleStateForCurrentCity.occupiedSlotCount == 0)
}

@Test func newBuildingTypesUseReadableSlotLabelsAndColors() throws {
    var initial = KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
    #expect(initial.buildBuilding(.stable, inSlot: 1) == .built(cost: 28, remainingGold: 472))
    #expect(initial.buildBuilding(.mageTower, inSlot: 2) == .built(cost: 40, remainingGold: 432))
    #expect(initial.buildBuilding(.siegeWorkshop, inSlot: 3) == .built(cost: 55, remainingGold: 377))
    let store = try makeStore(initialState: initial)
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.slotTextForTesting(1)?.contains("Stable") == true)
    #expect(scene.slotTextForTesting(2)?.contains("Mage Tower") == true)
    #expect(scene.slotTextForTesting(3)?.contains("Siege Workshop") == true)
}
```

Update old assertions that call `canBuildBarracksForTesting`, `canBuildArcheryRangeForTesting`, `buildBarracksTextForTesting`, or `buildArcheryTextForTesting` to use:

```swift
scene.canBuildForTesting(.barracks)
scene.canBuildForTesting(.archeryRange)
scene.buildButtonTextsForTesting
```

- [ ] **Step 2: Run Building View tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests
```

Expected: FAIL because the scene has fixed two-button build UI and old test hooks.

- [ ] **Step 3: Replace fixed build buttons with dynamic build button storage**

In `BuildingViewScene`, replace the fixed `buildBarracksButton` and `buildArcheryButton` properties with:

```swift
private struct BuildButtonBundle {
    let type: BuildingType
    let button: SKNode
    let background: SKShapeNode
    let label: SKLabelNode
}

private var buildButtonBundles: [BuildingType: BuildButtonBundle] = [:]
```

Keep `upgradeButton` and `battleButton`.

- [ ] **Step 4: Create five build buttons in `buildInterface()`**

Replace the two fixed `configureButton` calls for Barracks/Archery with:

```swift
for type in BuildingType.allCases {
    let button = SKNode()
    let background = SKShapeNode()
    let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    configureButton(
        button,
        background: background,
        label: label,
        name: buttonName(for: type),
        color: buildColor(for: type)
    )
    button.zPosition = GameUITheme.Z.hud + 1
    addChild(button)
    buildButtonBundles[type] = BuildButtonBundle(
        type: type,
        button: button,
        background: background,
        label: label
    )
}
```

Add helpers:

```swift
private func buttonName(for type: BuildingType) -> String {
    "build-\(type.rawValue)-button"
}

private func buildingType(forButtonName name: String) -> BuildingType? {
    BuildingType.allCases.first { buttonName(for: $0) == name }
}

private func buildColor(for type: BuildingType) -> SKColor {
    switch type {
    case .barracks:
        return GameUITheme.Color.spawn
    case .archeryRange:
        return SKColor(red: 0.12, green: 0.55, blue: 0.48, alpha: 1.0)
    case .stable:
        return SKColor(red: 0.44, green: 0.32, blue: 0.18, alpha: 1.0)
    case .mageTower:
        return SKColor(red: 0.34, green: 0.24, blue: 0.62, alpha: 1.0)
    case .siegeWorkshop:
        return SKColor(red: 0.50, green: 0.28, blue: 0.18, alpha: 1.0)
    }
}
```

- [ ] **Step 5: Update touch handling for dynamic buttons**

In `touchesEnded`, replace fixed build cases with:

```swift
if let buttonName = buttonName(at: point), let type = buildingType(forButtonName: buttonName) {
    buildSelectedSlot(type)
    return
}

switch buttonName(at: point) {
case ButtonName.upgrade:
    upgradeSelectedSlot()
case ButtonName.battle:
    requestBattle()
default:
    break
}
```

Update `buttonName(at:)` to include dynamic build names:

```swift
private func buttonName(at point: CGPoint) -> String? {
    let dynamicBuildNames = Set(BuildingType.allCases.map { buttonName(for: $0) })
    for node in nodes(at: point) {
        if let name = node.name, dynamicBuildNames.contains(name) {
            return name
        }

        switch node.name {
        case ButtonName.upgrade, ButtonName.battle:
            return node.name
        default:
            continue
        }
    }

    return nil
}
```

- [ ] **Step 6: Layout five build buttons plus Upgrade/Battle**

In `layoutInterface()`, replace the two-row fixed button layout with:

```swift
let buttonHeight: CGFloat = compactHeight ? 30 : 34
let buttonGap: CGFloat = 6
let columns = 3
let rows = 3
let buttonWidth = (contentWidth - buttonGap * CGFloat(columns - 1)) / CGFloat(columns)
let firstRowY = actionCenterY + actionHeight * 0.17

let orderedBuildTypes = BuildingType.allCases
for (index, type) in orderedBuildTypes.enumerated() {
    guard let bundle = buildButtonBundles[type] else {
        continue
    }

    let row = index / columns
    let column = index % columns
    let x = size.width / 2 - contentWidth / 2 + buttonWidth / 2 + CGFloat(column) * (buttonWidth + buttonGap)
    let y = firstRowY - CGFloat(row) * (buttonHeight + buttonGap)
    layoutButton(
        bundle.button,
        background: bundle.background,
        size: CGSize(width: buttonWidth, height: buttonHeight),
        position: CGPoint(x: x, y: y)
    )
    fitLabel(bundle.label, maxWidth: buttonWidth - 12)
}

let bottomButtonWidth = (contentWidth - buttonGap) / 2
let bottomY = actionCenterY - actionHeight * 0.36
layoutButton(
    upgradeButton,
    background: upgradeBackground,
    size: CGSize(width: bottomButtonWidth, height: buttonHeight),
    position: CGPoint(x: size.width / 2 - bottomButtonWidth / 2 - buttonGap / 2, y: bottomY)
)
layoutButton(
    battleButton,
    background: battleBackground,
    size: CGSize(width: bottomButtonWidth, height: buttonHeight),
    position: CGPoint(x: size.width / 2 + bottomButtonWidth / 2 + buttonGap / 2, y: bottomY)
)
```

Set `actionHeight` to at least `176` in regular height and `158` in compact height so the extra row fits:

```swift
let actionHeight: CGFloat = compactHeight ? 158 : 176
```

- [ ] **Step 7: Redraw dynamic labels and colors**

In `redraw()`, replace fixed build label/color logic with:

```swift
for type in BuildingType.allCases {
    guard let bundle = buildButtonBundles[type] else {
        continue
    }

    if state.isBuildingTypeUnlocked(type) {
        bundle.label.text = "Build \(type.shortDisplayName)"
    } else {
        bundle.label.text = "\(type.shortDisplayName) City \(KingdomGameState.unlockCity(for: type))"
    }

    bundle.background.fillColor = canBuild(type) ? buildColor(for: type) : GameUITheme.Color.upgradeUnavailable
}
```

In `redrawSlot(_:)`, add fill colors for all building types:

```swift
switch building.type {
case .barracks:
    node.fillColor = SKColor(red: 0.16, green: 0.36, blue: 0.62, alpha: 0.95)
case .archeryRange:
    node.fillColor = SKColor(red: 0.16, green: 0.46, blue: 0.36, alpha: 0.95)
case .stable:
    node.fillColor = SKColor(red: 0.44, green: 0.32, blue: 0.18, alpha: 0.95)
case .mageTower:
    node.fillColor = SKColor(red: 0.34, green: 0.24, blue: 0.62, alpha: 0.95)
case .siegeWorkshop:
    node.fillColor = SKColor(red: 0.50, green: 0.28, blue: 0.18, alpha: 0.95)
}
```

- [ ] **Step 8: Update `canBuild` and feedback**

At the top of `canBuild(_:)`, after selected-slot checks, add:

```swift
guard state.isBuildingTypeUnlocked(type) else {
    return false
}
```

In `buildSelectedSlot(_:)`, handle locked results:

```swift
case let .lockedBuilding(unlocksAtCity):
    feedbackText = "\(type.displayName) unlocks at City \(unlocksAtCity)."
```

- [ ] **Step 9: Update debug test hooks**

In the `#if DEBUG` extension, replace fixed build text/canBuild hooks with:

```swift
var buildButtonTextsForTesting: [String] {
    BuildingType.allCases.compactMap { buildButtonBundles[$0]?.label.text }
}

func canBuildForTesting(_ type: BuildingType) -> Bool {
    canBuild(type)
}
```

Keep these legacy hooks during the first edit so existing assertions still compile:

```swift
var canBuildBarracksForTesting: Bool { canBuild(.barracks) }
var canBuildArcheryRangeForTesting: Bool { canBuild(.archeryRange) }
var buildBarracksTextForTesting: String? { buildButtonBundles[.barracks]?.label.text }
var buildArcheryTextForTesting: String? { buildButtonBundles[.archeryRange]?.label.text }
```

After the test file is updated, run:

```bash
rg -n "canBuildBarracksForTesting|canBuildArcheryRangeForTesting|buildBarracksTextForTesting|buildArcheryTextForTesting" PyxisTests
```

If the command prints no matches, delete the four legacy hooks before committing this task. If it prints matches, update those assertions to `canBuildForTesting(_:)` or `buildButtonTextsForTesting`, then delete the four legacy hooks.

Update `BuildingLayoutFrames` to include:

```swift
let buildButtonFrames: [BuildingType: CGRect]
```

and populate it:

```swift
buildButtonFrames: Dictionary(
    uniqueKeysWithValues: buildButtonBundles.compactMap { type, bundle in
        sceneFrame(for: bundle.button).map { (type, $0) }
    }
)
```

- [ ] **Step 10: Run Building View tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "Show expanded unit buildings in city view"
```

---

### Task 6: Update Battle Scene For Build-Unlocked Manual Spawning And Trait HUD

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Write failing Battle Scene tests**

Add these tests to `PyxisTests/BattleSceneTests.swift`:

```swift
@Test func battleSceneShowsDefenseTraitAndRemovesUpgradeAction() throws {
    let store = try makeStore(initialState: KingdomGameState(cityNumberInCountry: 11, completedCityCount: 10))
    let scene = makeScene(store: store)

    #expect(scene.defenseTraitTextForTesting?.contains("Reinforced Keep") == true)
    #expect(scene.isUpgradeButtonVisibleForTesting == false)
}

@Test func manualSpawnRequiresMatchingCurrentCityBuilding() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 500, cityRemainingPower: 20))
    let scene = makeScene(store: store)

    #expect(scene.manualSpawnableSoldierTypesForTesting.isEmpty)

    scene.spawnSoldierForTesting()

    #expect(scene.liveSoldierCountForTesting == 0)
    #expect(scene.feedbackTextForTesting == "Build a unit building first.")
}

@Test func manualSelectorUsesBuiltCurrentCityUnitsOnly() throws {
    var initial = KingdomGameState(gold: 500, cityNumberInCountry: 8, completedCityCount: 7)
    #expect(initial.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 485))
    #expect(initial.buildBuilding(.mageTower, inSlot: 2) == .built(cost: 40, remainingGold: 445))
    let store = try makeStore(initialState: initial)
    let scene = makeScene(store: store)

    #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry, .mage])

    scene.selectManualSoldierTypeForTesting(.mage)
    scene.spawnSoldierForTesting()

    #expect(scene.selectedManualSoldierTypeForTesting == .mage)
    #expect(scene.liveSoldierTypesForTesting == [.mage])
}

@Test func manualSpawnUsesHighestMatchingBuildingLevelAndTraitAdjustedDamage() throws {
    var initial = KingdomGameState(gold: 500, cityRemainingPower: 20, cityNumberInCountry: 11, completedCityCount: 10)
    #expect(initial.buildBuilding(.siegeWorkshop, inSlot: 1) == .built(cost: 55, remainingGold: 445))
    #expect(initial.buildBuilding(.siegeWorkshop, inSlot: 2) == .built(cost: 55, remainingGold: 390))
    #expect(initial.upgradeBuilding(inSlot: 2) == .upgraded(cost: 42, newLevel: 2, remainingGold: 348))
    #expect(initial.upgradeBuilding(inSlot: 2) == .upgraded(cost: 69, newLevel: 3, remainingGold: 279))
    let store = try makeStore(initialState: initial)
    let scene = makeScene(store: store)

    scene.selectManualSoldierTypeForTesting(.siege)
    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 5.0)

    #expect(scene.liveSoldierLevelsForTesting == [3])
    #expect(store.load().cityRemainingPower < 20)
}

@Test func buildingSpawnUsesTraitAdjustedAttackPower() throws {
    let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
    let interval = KingdomGameState.activeSpawnInterval(for: .siegeWorkshop)
    let cityState = CityBattleState(
        slots: [1: CityBuilding(type: .siegeWorkshop, level: 3, spawnTimerElapsed: interval - 0.1)]
    )
    let store = try makeStore(
        initialState: KingdomGameState(
            gold: 500,
            cityRemainingPower: 20,
            cityNumberInCountry: 11,
            completedCityCount: 10,
            cityBattleStates: [cityKey.storageKey: cityState]
        )
    )
    let scene = makeScene(store: store)

    scene.advanceCombatForTesting(deltaTime: 0.2)

    #expect(scene.buildingLiveSoldierCountForTesting == 1)
    #expect(scene.liveSoldierTypesForTesting == [.siege])
    #expect(scene.liveSoldierAttackPowersForTesting == [3])
}
```

Delete these old tests that depend on battle `Upgrade`:

- `upgradeButtonCommunicatesAffordabilityWithoutBlockingTapFeedback`
- `insufficientGoldRunsUpgradeDeniedFeedback`
- `unavailableUpgradeRunsDeniedFeedbackWhenNoBattleIsActive`

Update old tests that spawn without a building by seeding a Barracks:

```swift
private func stateWithBarracks(
    gold: Int = 100,
    cityRemainingPower: Int = 20,
    cityNumberInCountry: Int = 1,
    completedCityCount: Int = 0
) -> KingdomGameState {
    var state = KingdomGameState(
        gold: gold,
        cityRemainingPower: cityRemainingPower,
        cityNumberInCountry: cityNumberInCountry,
        completedCityCount: completedCityCount
    )
    _ = state.buildBuilding(.barracks, inSlot: 1)
    return state
}
```

Use that helper for existing tests that call `scene.spawnSoldierForTesting()` and expect a soldier.

- [ ] **Step 2: Run Battle Scene tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL because BattleScene still has the global Upgrade button, fixed two-option selector, and old manual level rules.

- [ ] **Step 3: Replace fixed manual menu buttons with dynamic bundles**

In `BattleScene`, replace fixed `manualTypeInfantryButton` and `manualTypeArcherButton` properties with:

```swift
private struct ManualTypeButtonBundle {
    let type: SoldierType
    let button: SKNode
    let background: SKShapeNode
    let label: SKLabelNode
}

private var manualTypeButtonBundles: [SoldierType: ManualTypeButtonBundle] = [:]
```

Add helpers:

```swift
private func manualTypeButtonName(for type: SoldierType) -> String {
    "manualType-\(type.rawValue)"
}

private func soldierType(forManualTypeButtonName name: String) -> SoldierType? {
    SoldierType.allCases.first { manualTypeButtonName(for: $0) == name }
}
```

- [ ] **Step 4: Remove Upgrade button action from BattleScene**

Remove:

- `ButtonName.upgrade`
- `upgradeButton`, `upgradeButtonBackground`, `upgradeButtonLabel`
- `upgradeSoldier()`
- `playUpgradeSuccessFeedback(newAttackPower:)`
- `playUpgradeDeniedFeedback()`
- upgrade button configuration, layout, redraw, test hooks, and touch handling

Delete `EffectName.upgradeDenied` and `EffectName.upgradeSuccess` after removing the upgrade button and upgrade feedback methods.

In `BattleLayoutFrames`, remove:

```swift
let upgradeButton: CGRect
let upgradeButtonLabel: CGRect
```

Update existing layout tests to assert `buildButton` or battlefield bounds instead of upgrade frames.

- [ ] **Step 5: Add defense trait label**

Add:

```swift
private let defenseTraitLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
```

Configure it in `buildInterface()`:

```swift
configureLabel(defenseTraitLabel, fontSize: 12, color: GameUITheme.Color.textSecondary)
addChild(defenseTraitLabel)
defenseTraitLabel.zPosition = GameUITheme.Z.hud
```

Place it in the right HUD below the HP bar or in the left HUD after live status:

```swift
defenseTraitLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY - metrics.hudHeight * 0.43)
```

Replace the HUD height with:

```swift
let hudHeight: CGFloat = compactHeight ? 74 : 92
```

In `redraw()`:

```swift
defenseTraitLabel.text = state.currentCityDefenseTrait.displayName
```

- [ ] **Step 6: Create dynamic manual menu buttons**

In `buildInterface()`, after configuring `manualTypeButton`, create one menu button for every soldier type:

```swift
for type in SoldierType.allCases {
    let button = SKNode()
    let background = SKShapeNode()
    let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    configureButton(
        button,
        background: background,
        label: label,
        name: manualTypeButtonName(for: type),
        color: SKColor(red: 0.18, green: 0.34, blue: 0.42, alpha: 1.0)
    )
    button.zPosition = GameUITheme.Z.hud + 1
    addChild(button)
    manualTypeButtonBundles[type] = ManualTypeButtonBundle(type: type, button: button, background: background, label: label)
}
```

- [ ] **Step 7: Add spawnable-unit reconciliation**

Add:

```swift
private var manualSpawnableSoldierTypes: [SoldierType] {
    state.manualSpawnableSoldierTypes()
}

private func reconcileSelectedManualSoldierType() {
    let spawnable = manualSpawnableSoldierTypes
    guard !spawnable.contains(selectedManualSoldierType) else {
        return
    }

    selectedManualSoldierType = spawnable.first ?? .infantry
    isManualTypeMenuOpen = false
}
```

Call `reconcileSelectedManualSoldierType()` at the start of `redraw()` and after lifecycle foreground resolution.

- [ ] **Step 8: Layout dynamic manual menu**

Replace `layoutManualTypeMenu` with:

```swift
private func layoutManualTypeMenu(selectorPosition: CGPoint, selectorSize: CGSize, itemSize: CGSize) {
    let itemGap: CGFloat = 4
    let spawnable = manualSpawnableSoldierTypes
    let selectorMaxX = selectorPosition.x + selectorSize.width / 2

    for (index, type) in SoldierType.allCases.enumerated() {
        guard let bundle = manualTypeButtonBundles[type] else {
            continue
        }

        let visibleIndex = spawnable.firstIndex(of: type)
        if let visibleIndex {
            let x = selectorMaxX + itemGap + itemSize.width / 2 + CGFloat(visibleIndex) * (itemSize.width + itemGap)
            layoutButton(
                bundle.button,
                background: bundle.background,
                size: itemSize,
                position: CGPoint(x: x, y: selectorPosition.y)
            )
        } else {
            layoutButton(
                bundle.button,
                background: bundle.background,
                size: itemSize,
                position: CGPoint(x: selectorMaxX + itemGap + itemSize.width / 2 + CGFloat(index) * (itemSize.width + itemGap), y: selectorPosition.y)
            )
        }
    }
}
```

Update `manualTypeMenuItemSize` to divide by at most the spawnable count:

```swift
let visibleCount = max(1, manualSpawnableSoldierTypes.count)
let fittedWidth = (rightEdge - selectorMaxX - itemGap * CGFloat(visibleCount)) / CGFloat(visibleCount)
```

- [ ] **Step 9: Redraw dynamic manual menu**

In `redraw()`, replace fixed Infantry/Archer label and color logic with:

```swift
reconcileSelectedManualSoldierType()
let spawnable = manualSpawnableSoldierTypes
manualTypeButtonLabel.text = spawnable.isEmpty ? "No Units" : selectedManualSoldierType.displayName

for type in SoldierType.allCases {
    guard let bundle = manualTypeButtonBundles[type] else {
        continue
    }

    bundle.label.text = type.displayName
    bundle.background.fillColor = selectedManualSoldierType == type
        ? GameUITheme.Color.spawn
        : SKColor(red: 0.18, green: 0.34, blue: 0.42, alpha: 1.0)
    bundle.button.isHidden = !isManualTypeMenuOpen || !spawnable.contains(type)
}

spawnButtonLabel.text = spawnable.isEmpty ? "Build Unit" : "Spawn \(selectedManualSoldierType.displayName)"
buildButtonLabel.text = "Build"
```

Remove:

```swift
soldierAttackLabel.text = "Soldier Attack: \(compactNumber(state.normalSoldierAttackPower))"
upgradeButtonLabel.text = ...
upgradeButtonBackground.fillColor = ...
```

Replace the attack label with:

```swift
soldierAttackLabel.text = "Trait: \(state.currentCityDefenseTrait.displayName)"
```

- [ ] **Step 10: Update touch handling**

In `touchesEnded`, replace fixed manual type cases with:

```swift
if let buttonName = buttonName(at: touch.location(in: self)),
   let type = soldierType(forManualTypeButtonName: buttonName) {
    selectManualSoldierType(type)
    return
}

switch buttonName(at: touch.location(in: self)) {
case ButtonName.manualType:
    toggleManualTypeMenu()
case ButtonName.spawn:
    isManualTypeMenuOpen = false
    spawnSoldier()
case ButtonName.build:
    isManualTypeMenuOpen = false
    requestBuildingView()
case ButtonName.popupContinue:
    isManualTypeMenuOpen = false
    closeConquestPopup()
default:
    if isManualTypeMenuOpen {
        isManualTypeMenuOpen = false
        redraw()
    }
}
```

Update `buttonName(at:)` priority:

```swift
let priority = SoldierType.allCases.map { manualTypeButtonName(for: $0) } + [
    ButtonName.manualType,
    ButtonName.spawn,
    ButtonName.build,
    ButtonName.popupContinue
]
```

- [ ] **Step 11: Update manual and building spawn attack power**

In `advanceCombat(deltaTime:)`, replace building spawn attack power with:

```swift
attackPower: state.traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
```

In `spawnSoldier()`, replace the spawn body with:

```swift
guard let level = state.manualSoldierLevel(for: selectedManualSoldierType) else {
    feedbackText = "Build a unit building first."
    redraw()
    return
}

let soldierID = combat.spawnSoldier(
    type: selectedManualSoldierType,
    source: .manual,
    level: level,
    attackPower: state.traitAdjustedSoldierAttackPower(
        for: selectedManualSoldierType,
        level: level
    )
)
createSoldierNode(id: soldierID)
syncSoldierNodes()
updateLiveCombatStatusLabel()
```

- [ ] **Step 12: Guard selecting unavailable unit types**

Replace `selectManualSoldierType(_:)` with:

```swift
private func selectManualSoldierType(_ type: SoldierType) {
    guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
        return
    }

    guard manualSpawnableSoldierTypes.contains(type) else {
        feedbackText = "Build \(type.displayName) first."
        isManualTypeMenuOpen = false
        redraw()
        return
    }

    selectedManualSoldierType = type
    isManualTypeMenuOpen = false
    redraw()
}
```

- [ ] **Step 13: Update debug test hooks**

Add:

```swift
var defenseTraitTextForTesting: String? {
    defenseTraitLabel.text
}

var isUpgradeButtonVisibleForTesting: Bool {
    false
}

var manualSpawnableSoldierTypesForTesting: [SoldierType] {
    manualSpawnableSoldierTypes
}

var liveSoldierLevelsForTesting: [Int] {
    combat.soldiers.filter(\.isAlive).map(\.level)
}

var liveSoldierAttackPowersForTesting: [Int] {
    combat.soldiers.filter(\.isAlive).map(\.attackPower)
}
```

Update `BattleLayoutFrames` to remove upgrade fields and add:

```swift
let buildButton: CGRect
let defenseTraitLabel: CGRect
let manualTypeMenuButtons: [SoldierType: CGRect]
```

- [ ] **Step 14: Run Battle Scene tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 15: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Gate battle spawning by unit buildings"
```

---

### Task 7: Show Defense Traits On Country Map

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

- [ ] **Step 1: Write failing country-map trait tests**

Add these tests to `PyxisTests/CountryMapSceneTests.swift`:

```swift
@Test func mapShowsTraitForUnlockedCityInFeedback() throws {
    let store = try makeStore(initialState: KingdomGameState(
        cityRemainingPower: 0,
        cityNumberInCountry: 4,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap
    ))
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.feedbackTextForTesting.contains("Spiked Gate"))
}

@Test func selectingVisibleCityReportsDefenseTrait() throws {
    let store = try makeStore(initialState: KingdomGameState(
        cityRemainingPower: 0,
        cityNumberInCountry: 4,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap
    ))
    let scene = makeScene(store: store, router: RouteSpy())

    scene.enterCityForTesting(5)

    #expect(scene.feedbackTextForTesting == "City 5 is locked.")
}
```

Keep `enteringLockedCityDoesNotMutateOrRoute` expecting `"City 3 is locked."` because locked future cities do not reveal future traits in this slice.

- [ ] **Step 2: Run country-map tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: FAIL because default map feedback does not include defense trait text.

- [ ] **Step 3: Add trait-aware feedback helper**

In `CountryMapScene`, replace `defaultFeedbackText(for:)` with:

```swift
private func defaultFeedbackText(for state: KingdomGameState) -> String {
    if state.stageStatus == .countryComplete {
        return "Country \(state.countryNumber) conquered."
    }

    let unlockedCity = min(state.completedCityCount + 1, KingdomGameState.firstCountryCityCount)
    let trait = KingdomGameState.defenseTrait(forCityNumber: unlockedCity)
    return "City \(unlockedCity): \(trait.displayName)"
}
```

In `enterCity(_:)`, for `.alreadyCompleted`, set:

```swift
let trait = KingdomGameState.defenseTrait(forCityNumber: cityNumber)
feedbackText = "City \(cityNumber) complete. \(trait.displayName)."
```

Keep locked feedback as:

```swift
feedbackText = "City \(cityNumber) is locked."
```

- [ ] **Step 4: Run country-map tests and verify pass**

Run the command from Step 2.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "Show city defense traits on map"
```

---

### Task 8: Integrate Save Compatibility And Full Regression Pass

**Files:**
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Add save compatibility regression**

Add this test to `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func decodingOldTwoUnitBuildingSaveStillSucceeds() throws {
    let data = """
    {
      "gold": 100,
      "cityLevel": 2,
      "cityRemainingPower": 20,
      "normalSoldierUpgradeLevel": 4,
      "countryNumber": 1,
      "cityNumberInCountry": 2,
      "completedCityCount": 1,
      "stageStatus": "battleActive",
      "cityBattleStates": {
        "1-2": {
          "slots": {
            "1": {
              "type": "barracks",
              "level": 2,
              "spawnTimerElapsed": 3
            },
            "2": {
              "type": "archeryRange",
              "level": 1,
              "spawnTimerElapsed": 4
            }
          },
          "lastBuildingProgressResolvedAt": null
        }
      }
    }
    """.data(using: .utf8)!

    let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
    #expect(state.cityBattleStateForCurrentCity.building(inSlot: 2)?.type == .archeryRange)
    #expect(state.normalSoldierUpgradeLevel == 4)
    #expect(state.currentCityDefenseTrait == .standardWatch)
}
```

- [ ] **Step 2: Run full focused model and scene suites**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/BattleCombatStateTests -only-testing:PyxisTests/BuildingViewSceneTests -only-testing:PyxisTests/BattleSceneTests -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: PASS. Any failure means an earlier task drifted from its stated contract; stop, repair the specific failing assertion, and rerun this command before continuing.

- [ ] **Step 3: Run full test suite**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

Expected: PASS.

- [ ] **Step 4: Optional lint**

Run if SwiftLint is installed locally:

```bash
swiftlint lint
```

Expected: no new lint failures. If `swiftlint` is not installed, record that in the final implementation summary.

- [ ] **Step 5: Manual simulator smoke**

Run the app on an available simulator and check:

- City 1 allows Barracks and Infantry after building Barracks.
- City 2 unlocks Archery Range.
- City 5 unlocks Stable.
- City 8 unlocks Mage Tower.
- City 11 unlocks Siege Workshop.
- Battle HUD shows the current defense trait.
- Map feedback shows the next unlocked city's defense trait.
- Manual spawn is blocked before building a matching unit building.
- Building idle damage still resolves and can conquer the current city only.
- Conquest clears current-city buildings and routes to the country map.

- [ ] **Step 6: Commit final regression updates**

```bash
git add Pyxis PyxisTests
git commit -m "Verify expanded roster integration"
```

If Step 2 and Step 3 required no code changes after the previous commits, skip this commit and note that no final regression commit was needed.

---

## Implementation Notes

- Do not edit `Pyxis.xcodeproj/project.pbxproj` to register new Swift files. This project uses `PBXFileSystemSynchronizedRootGroup`, so files dropped into `Pyxis/` and `PyxisTests/` are picked up automatically.
- Keep `normalSoldierUpgradeLevel` in `KingdomGameState` for decode compatibility even after removing the battle Upgrade button.
- Do not persist city defense traits in saves. Traits are authored by city number for this slice.
- Do not make `BattleCombatState` depend on `KingdomGameState`. Pass adjusted attack power into `spawnSoldier`.
- Do not simulate tower shots, movement, deaths, or live soldiers during idle damage.
- Keep all new gameplay rules in pure Swift model files before exposing them in SpriteKit scenes.

## Self-Review Checklist

- Spec coverage:
  - Five-unit roster: Tasks 1, 4, 5, 6.
  - One building per unit: Tasks 1, 2, 5.
  - Progressive unlocks: Tasks 2, 5.
  - Remove global battle upgrade: Task 6.
  - Building level as main scaling: Tasks 2, 6.
  - Manual requires matching building: Tasks 2, 6.
  - Authored defense traits: Tasks 1, 2, 7.
  - Counters in live and idle damage: Tasks 3, 6.
  - Save compatibility: Task 8.
- Type consistency:
  - `CityDefenseTrait` is pure Swift and not persisted.
  - `manualSoldierLevel(for:)` returns `Int?`.
  - `manualSpawnableSoldierTypes()` returns `[SoldierType]`.
  - `traitAdjustedSoldierAttackPower(for:level:defenseTrait:)` is static; instance wrapper uses current city trait.
- Verification:
  - Every model change has a failing Swift Testing test first.
  - Scene changes are covered by focused SpriteKit tests.
  - Full suite runs after integration.
