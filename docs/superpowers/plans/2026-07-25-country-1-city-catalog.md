# Country 1 City Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize Country 1's 15 authored defense traits and lane profiles in one immutable pure-model catalog while preserving campaign and combat behavior.

**Architecture:** Add a framework-free `CityDefinition` value and a caseless `Country1CityCatalog` namespace containing the ordered 15-city dataset. `KingdomGameState` projects current-city and compatibility APIs from that catalog, while the obsolete country-agnostic lane lookup is removed so `LaneDefenseProfile` remains a generic value type.

**Tech Stack:** Swift 5, Swift Testing, Xcode project with `PBXFileSystemSynchronizedRootGroup`, Foundation-only pure models.

## Global Constraints

- Source design: `docs/superpowers/specs/2026-07-25-country-1-city-catalog-design.md`.
- Country 1 contains exactly 15 definitions covering city numbers `1...15` in ascending order.
- Each definition stores only `cityNumber`, `defenseTrait`, and `laneDefenseProfile`.
- All 15 trait and lane values must match the pre-migration behavior exactly.
- `Country1CityCatalog.definition(for:)` is non-optional and clamps every input to `1...15`.
- `CityDefinition`, `Country1CityCatalog`, `CityDefenseTrait`, and `LaneDefenseProfile` must not import SpriteKit or UIKit.
- Favorable and disadvantaged soldier lists remain computed from `CityDefenseTrait`; they are not duplicated in city definitions.
- Gold rewards, building unlocks, save data, campaign flow, combat balance, idle damage, scenes, and routing remain unchanged.
- Remove `LaneDefenseProfile.profile(forCityNumber:)`; `KingdomGameState.currentCityLaneDefenseProfile` is the supported current-city access.
- Preserve `KingdomGameState.defenseTrait(forCityNumber:)`, `currentCityDefenseTrait`, and `currentCityLaneDefenseProfile`.
- Do not edit `Pyxis.xcodeproj/project.pbxproj`; synchronized root groups discover new Swift files automatically.
- Always disable parallel testing. Prefer XcodeBuildMCP after `session_show_defaults`; direct `xcodebuild` commands below are the fallback.
- If the iPhone 17 simulator is unavailable, run `xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations` and substitute an available iOS Simulator destination.
- No new UI test is required because presentation and interaction do not change.

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Pyxis/CityDefinition.swift` | Create | Immutable per-city authored combat metadata value |
| `Pyxis/Country1CityCatalog.swift` | Create | Ordered Country 1 definitions and clamped lookup |
| `Pyxis/CityDefenseTrait.swift` | Modify | Internal read-only favorable/disadvantaged semantics |
| `Pyxis/LaneDefenseProfile.swift` | Modify | Generic lane-profile value only; remove city-number lookup |
| `Pyxis/KingdomGameState.swift` | Modify | Project campaign compatibility/current-city APIs from the catalog |
| `PyxisTests/Country1CityCatalogTests.swift` | Create | Single expected fixture, catalog invariants, clamping, parity, and compatibility |
| `PyxisTests/KingdomGameStateTests.swift` | Modify | Trait-list semantics and independent current-city historical anchors |
| `PyxisTests/LaneDefenseProfileTests.swift` | Modify | Test the generic value type without the removed rotation helper |
| `CLAUDE.md` | Modify | Describe the catalog as the authored lane-profile source |

---

### Task 1: Expose Trait-Derived Soldier Semantics

**Files:**
- Modify: `Pyxis/CityDefenseTrait.swift:59-107`
- Modify: `PyxisTests/KingdomGameStateTests.swift:58-119`

**Interfaces:**
- Consumes: `CityDefenseTrait`, `SoldierType`, and `damageMultiplier(for:)`.
- Produces: `var favorableSoldierTypes: [SoldierType]` and `var disadvantagedSoldierTypes: [SoldierType]`, both internal computed get-only properties.

- [ ] **Step 1: Extend the existing trait test with exact favorable and disadvantaged lists**

In `cityDefenseTraitsExposeDisplayAndCounterMetadata`, add this fixture and assertion block after the existing exact multiplier assertions:

```swift
let expectedCounterLists: [
    (trait: CityDefenseTrait, favorable: [SoldierType], disadvantaged: [SoldierType])
] = [
    (.standardWatch, [], []),
    (.arrowTower, [.infantry, .cavalry], [.archer, .mage]),
    (.spikedGate, [.archer, .mage], [.infantry, .cavalry]),
    (.stoneWall, [.mage, .siege], [.archer]),
    (.arcaneWard, [.infantry, .cavalry, .siege], [.mage]),
    (.burningOil, [.archer, .mage, .cavalry], [.infantry, .siege]),
    (.reinforcedKeep, [.siege], [.archer, .infantry])
]

#expect(expectedCounterLists.map(\.trait) == CityDefenseTrait.allCases)
for (trait, favorable, disadvantaged) in expectedCounterLists {
    #expect(trait.favorableSoldierTypes == favorable)
    #expect(trait.disadvantagedSoldierTypes == disadvantaged)

    for soldierType in SoldierType.allCases {
        let expectedMultiplier: Double
        if favorable.contains(soldierType) {
            expectedMultiplier = 1.25
        } else if disadvantaged.contains(soldierType) {
            expectedMultiplier = 0.80
        } else {
            expectedMultiplier = 1.0
        }
        #expect(trait.damageMultiplier(for: soldierType) == expectedMultiplier)
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Preferred: use XcodeBuildMCP `test_sim` with
`extraArgs: ["-parallel-testing-enabled", "NO", "-only-testing:PyxisTests/KingdomGameStateTests/cityDefenseTraitsExposeDisplayAndCounterMetadata"]`.

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests/cityDefenseTraitsExposeDisplayAndCounterMetadata
```

Expected: build failure because `favorableSoldierTypes` does not exist and `disadvantagedSoldierTypes` is private.

- [ ] **Step 3: Rename and expose the computed trait properties**

In `CityDefenseTrait.swift`, update `damageMultiplier(for:)` and the two computed properties:

```swift
func damageMultiplier(for soldierType: SoldierType) -> Double {
    if favorableSoldierTypes.contains(soldierType) {
        return 1.25
    }

    if disadvantagedSoldierTypes.contains(soldierType) {
        return 0.80
    }

    return 1.0
}

var favorableSoldierTypes: [SoldierType] {
    switch self {
    case .standardWatch:
        return []
    case .arrowTower:
        return [.infantry, .cavalry]
    case .spikedGate:
        return [.archer, .mage]
    case .stoneWall:
        return [.mage, .siege]
    case .arcaneWard:
        return [.infantry, .cavalry, .siege]
    case .burningOil:
        return [.archer, .mage, .cavalry]
    case .reinforcedKeep:
        return [.siege]
    }
}

var disadvantagedSoldierTypes: [SoldierType] {
    switch self {
    case .standardWatch:
        return []
    case .arrowTower:
        return [.archer, .mage]
    case .spikedGate:
        return [.infantry, .cavalry]
    case .stoneWall:
        return [.archer]
    case .arcaneWard:
        return [.mage]
    case .burningOil:
        return [.infantry, .siege]
    case .reinforcedKeep:
        return [.archer, .infantry]
    }
}
```

- [ ] **Step 4: Re-run the focused test and verify it passes**

Run the same focused test command from Step 2.

Expected: PASS with all seven trait lists and all derived multipliers unchanged.

- [ ] **Step 5: Commit the trait-semantic slice**

```bash
git add Pyxis/CityDefenseTrait.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "refactor: expose city defense counter lists"
```

---

### Task 2: Add the Immutable Country 1 Catalog

**Files:**
- Create: `Pyxis/CityDefinition.swift`
- Create: `Pyxis/Country1CityCatalog.swift`
- Create: `PyxisTests/Country1CityCatalogTests.swift`

**Interfaces:**
- Consumes: `CityDefenseTrait`, `LaneDefenseProfile`, and `BattleLane`.
- Produces: `CityDefinition`, `Country1CityCatalog.cityRange`, `Country1CityCatalog.definitions`, and `Country1CityCatalog.definition(for:)`.

- [ ] **Step 1: Add one independent expected fixture and catalog invariant tests**

Create `PyxisTests/Country1CityCatalogTests.swift`:

```swift
//
//  Country1CityCatalogTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct Country1CityCatalogTests {
    private struct ExpectedDefinition {
        let cityNumber: Int
        let defenseTrait: CityDefenseTrait
        let fortifiedLane: BattleLane
        let exposedLane: BattleLane

        var definition: CityDefinition {
            CityDefinition(
                cityNumber: cityNumber,
                defenseTrait: defenseTrait,
                laneDefenseProfile: LaneDefenseProfile(
                    fortifiedLane: fortifiedLane,
                    exposedLane: exposedLane
                )
            )
        }
    }

    private static let expectedDefinitions: [ExpectedDefinition] = [
        ExpectedDefinition(
            cityNumber: 1,
            defenseTrait: .standardWatch,
            fortifiedLane: .left,
            exposedLane: .right
        ),
        ExpectedDefinition(
            cityNumber: 2,
            defenseTrait: .standardWatch,
            fortifiedLane: .center,
            exposedLane: .left
        ),
        ExpectedDefinition(
            cityNumber: 3,
            defenseTrait: .arrowTower,
            fortifiedLane: .right,
            exposedLane: .center
        ),
        ExpectedDefinition(
            cityNumber: 4,
            defenseTrait: .spikedGate,
            fortifiedLane: .left,
            exposedLane: .right
        ),
        ExpectedDefinition(
            cityNumber: 5,
            defenseTrait: .arrowTower,
            fortifiedLane: .center,
            exposedLane: .left
        ),
        ExpectedDefinition(
            cityNumber: 6,
            defenseTrait: .stoneWall,
            fortifiedLane: .right,
            exposedLane: .center
        ),
        ExpectedDefinition(
            cityNumber: 7,
            defenseTrait: .burningOil,
            fortifiedLane: .left,
            exposedLane: .right
        ),
        ExpectedDefinition(
            cityNumber: 8,
            defenseTrait: .stoneWall,
            fortifiedLane: .center,
            exposedLane: .left
        ),
        ExpectedDefinition(
            cityNumber: 9,
            defenseTrait: .arcaneWard,
            fortifiedLane: .right,
            exposedLane: .center
        ),
        ExpectedDefinition(
            cityNumber: 10,
            defenseTrait: .spikedGate,
            fortifiedLane: .left,
            exposedLane: .right
        ),
        ExpectedDefinition(
            cityNumber: 11,
            defenseTrait: .reinforcedKeep,
            fortifiedLane: .center,
            exposedLane: .left
        ),
        ExpectedDefinition(
            cityNumber: 12,
            defenseTrait: .burningOil,
            fortifiedLane: .right,
            exposedLane: .center
        ),
        ExpectedDefinition(
            cityNumber: 13,
            defenseTrait: .arcaneWard,
            fortifiedLane: .left,
            exposedLane: .right
        ),
        ExpectedDefinition(
            cityNumber: 14,
            defenseTrait: .stoneWall,
            fortifiedLane: .center,
            exposedLane: .left
        ),
        ExpectedDefinition(
            cityNumber: 15,
            defenseTrait: .reinforcedKeep,
            fortifiedLane: .right,
            exposedLane: .center
        )
    ]

    @Test func catalogIsCompleteUniqueOrderedAndMatchesAuthoredCombatMetadata() {
        let expectedNumbers = Self.expectedDefinitions.map(\.cityNumber)
        let actualDefinitions = Country1CityCatalog.definitions
        let actualNumbers = actualDefinitions.map(\.cityNumber)

        #expect(expectedNumbers == Array(Country1CityCatalog.cityRange))
        #expect(actualDefinitions.count == Country1CityCatalog.cityRange.count)
        #expect(actualNumbers == expectedNumbers)
        #expect(Set(actualNumbers).count == actualNumbers.count)
        #expect(actualDefinitions == Self.expectedDefinitions.map(\.definition))
    }

    @Test func definitionLookupClampsToCountryOneBounds() {
        let cityOne = Self.expectedDefinitions[0].definition
        let cityFifteen = Self.expectedDefinitions[14].definition

        #expect(Country1CityCatalog.definition(for: -4) == cityOne)
        #expect(Country1CityCatalog.definition(for: 0) == cityOne)
        #expect(Country1CityCatalog.definition(for: 1) == cityOne)
        #expect(Country1CityCatalog.definition(for: 15) == cityFifteen)
        #expect(Country1CityCatalog.definition(for: 16) == cityFifteen)
        #expect(Country1CityCatalog.definition(for: 18) == cityFifteen)
    }

    @Test func everyAuthoredProfileHasExactlyOneLaneOfEachRole() {
        for definition in Country1CityCatalog.definitions {
            let roles = BattleLane.allCases.map {
                definition.laneDefenseProfile.role(for: $0)
            }

            #expect(roles.filter { $0 == .fortified }.count == 1)
            #expect(roles.filter { $0 == .exposed }.count == 1)
            #expect(roles.filter { $0 == .standard }.count == 1)
        }
    }
}
```

- [ ] **Step 2: Run the new suite and verify it fails**

Preferred: use XcodeBuildMCP `test_sim` with
`extraArgs: ["-parallel-testing-enabled", "NO", "-only-testing:PyxisTests/Country1CityCatalogTests"]`.

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests
```

Expected: build failure because `CityDefinition` and `Country1CityCatalog` do not exist.

- [ ] **Step 3: Add the immutable city-definition value**

Create `Pyxis/CityDefinition.swift`:

```swift
//
//  CityDefinition.swift
//  Pyxis
//

struct CityDefinition: Equatable {
    let cityNumber: Int
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile
}
```

- [ ] **Step 4: Add the complete ordered catalog and clamped lookup**

Create `Pyxis/Country1CityCatalog.swift`:

```swift
//
//  Country1CityCatalog.swift
//  Pyxis
//

enum Country1CityCatalog {
    static let cityRange = 1...15

    /// The authored order is also the lookup index. A duplicated fortified /
    /// exposed lane is a programmer error and fails through
    /// `LaneDefenseProfile`'s invariant precondition during static initialization.
    static let definitions: [CityDefinition] = [
        CityDefinition(
            cityNumber: 1,
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 2,
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 3,
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 4,
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 5,
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 6,
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 7,
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 8,
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 9,
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 10,
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 11,
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 12,
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 13,
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 14,
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 15,
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        )
    ]

    static func definition(for cityNumber: Int) -> CityDefinition {
        let clampedCityNumber = min(max(cityRange.lowerBound, cityNumber), cityRange.upperBound)
        return definitions[clampedCityNumber - cityRange.lowerBound]
    }
}
```

- [ ] **Step 5: Re-run the catalog suite and verify it passes**

Run the same focused test command from Step 2.

Expected: PASS for exact 15-city parity, ordering, uniqueness, role invariants, and clamping.

- [ ] **Step 6: Commit the catalog slice**

```bash
git add Pyxis/CityDefinition.swift Pyxis/Country1CityCatalog.swift PyxisTests/Country1CityCatalogTests.swift
git commit -m "feat: add Country 1 city catalog"
```

---

### Task 3: Migrate Runtime Access And Remove The Rotation Lookup

**Files:**
- Modify: `Pyxis/KingdomGameState.swift:12,665-692`
- Modify: `Pyxis/LaneDefenseProfile.swift:28-77`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift:277-315`
- Modify: `PyxisTests/LaneDefenseProfileTests.swift:9-122`
- Modify: `CLAUDE.md:69`

**Interfaces:**
- Consumes: `Country1CityCatalog.definition(for:)`, `Country1CityCatalog.cityRange`, and the `CityDefinition` fields.
- Produces: `KingdomGameState.currentCityDefinition`; catalog-backed `defenseTrait(forCityNumber:)`, `currentCityDefenseTrait`, and `currentCityLaneDefenseProfile`; a generic `LaneDefenseProfile` with no city-number lookup.

- [ ] **Step 1: Add compatibility tests against the independent catalog fixture**

Add this test inside `Country1CityCatalogTests`:

```swift
@Test func kingdomGameStateCompatibilityAccessorsProjectAuthoredDefinitions() {
    for expected in Self.expectedDefinitions {
        let state = KingdomGameState(
            cityNumberInCountry: expected.cityNumber,
            completedCityCount: expected.cityNumber - 1
        )

        #expect(
            KingdomGameState.defenseTrait(forCityNumber: expected.cityNumber)
                == expected.defenseTrait
        )
        #expect(state.currentCityDefinition == expected.definition)
        #expect(state.currentCityDefenseTrait == expected.defenseTrait)
        #expect(
            state.currentCityLaneDefenseProfile
                == expected.definition.laneDefenseProfile
        )
    }

    #expect(KingdomGameState.defenseTrait(forCityNumber: -4) == .standardWatch)
    #expect(KingdomGameState.defenseTrait(forCityNumber: 18) == .reinforcedKeep)
}
```

Keep `KingdomGameStateTests.currentCityDefenseTraitUsesAuthoredProgression`
unchanged so its independent 15-city trait dictionary remains a historical
anchor.

- [ ] **Step 2: Rewrite the current-city lane test with independent expected values**

Replace `currentCityLaneDefenseProfileFollowsCityNumber` with:

```swift
@Test func currentCityLaneDefenseProfileUsesAuthoredProgression() {
    let cityOne = KingdomGameState(gold: 0, cityRemainingPower: 10)
    #expect(
        cityOne.currentCityLaneDefenseProfile
            == LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
    )

    let cityFive = KingdomGameState(
        gold: 0,
        cityRemainingPower: 10,
        cityNumberInCountry: 5,
        completedCityCount: 4
    )
    #expect(
        cityFive.currentCityLaneDefenseProfile
            == LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
    )
}
```

- [ ] **Step 3: Refocus `LaneDefenseProfileTests` on the generic value type**

Delete these lookup-owned tests:

```text
everyCityGetsExactlyOneOfEachRole
assignmentFollowsCityNumberRotation
sameCityNumberAlwaysYieldsSameProfile
outOfRangeCityNumbersClampToLowerBound
highCityNumbersCycleRatherThanClamp
```

Add direct value tests:

```swift
@Test func rolesAreDerivedFromFortifiedAndExposedLanes() {
    let profile = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)

    #expect(profile.role(for: .left) == .fortified)
    #expect(profile.role(for: .center) == .standard)
    #expect(profile.role(for: .right) == .exposed)
    #expect(profile.standardLane == .center)
}

@Test func equalityUsesFortifiedAndExposedLanes() {
    let leftRight = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
    let matching = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
    let centerLeft = LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)

    #expect(leftRight == matching)
    #expect(leftRight != centerLeft)
}
```

Change `towerDamageMultipliersMatchRoles` to construct its profile directly:

```swift
@Test func towerDamageMultipliersMatchRoles() {
    let profile = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
    let multipliers = profile.towerDamageMultipliers

    #expect(multipliers[.left] == 1.25)
    #expect(multipliers[.center] == 1.0)
    #expect(multipliers[.right] == 0.80)
}
```

In `laneRoleMultipliersMatchCityDefenseTraitBalanceValues`, change the comment
phrase `advantaged/disadvantaged` to `favorable/disadvantaged`; retain the test
logic unchanged.

- [ ] **Step 4: Run the new compatibility test and verify it fails**

Preferred: use XcodeBuildMCP `test_sim` with
`extraArgs: ["-parallel-testing-enabled", "NO", "-only-testing:PyxisTests/Country1CityCatalogTests/kingdomGameStateCompatibilityAccessorsProjectAuthoredDefinitions"]`.

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests/kingdomGameStateCompatibilityAccessorsProjectAuthoredDefinitions
```

Expected: build failure because `KingdomGameState.currentCityDefinition` does not exist.

- [ ] **Step 5: Route `KingdomGameState` through the catalog**

Replace the Country 1 count constant:

```swift
static let firstCountryCityCount = Country1CityCatalog.cityRange.count
```

Replace the trait/lane lookup block with:

```swift
static func defenseTrait(forCityNumber cityNumber: Int) -> CityDefenseTrait {
    Country1CityCatalog.definition(for: cityNumber).defenseTrait
}

var currentCityDefinition: CityDefinition {
    Country1CityCatalog.definition(for: cityNumberInCountry)
}

var currentCityDefenseTrait: CityDefenseTrait {
    currentCityDefinition.defenseTrait
}

var currentCityLaneDefenseProfile: LaneDefenseProfile {
    currentCityDefinition.laneDefenseProfile
}
```

This removes the old trait switch and its local clamp; the catalog performs the
single shared clamp.

- [ ] **Step 6: Remove the obsolete lane lookup**

In `LaneDefenseProfile.swift`, remove:

```swift
static func profile(forCityNumber cityNumber: Int) -> LaneDefenseProfile {
    let safe = max(1, cityNumber)
    let fortifiedIndex = (safe - 1) % 3
    let exposedIndex = (safe + 1) % 3

    let fortified = BattleLane.allCases.first { $0.rawValue == fortifiedIndex }!
    let exposed = BattleLane.allCases.first { $0.rawValue == exposedIndex }!

    return LaneDefenseProfile(fortifiedLane: fortified, exposedLane: exposed)
}
```

Update the type documentation to describe a value, not a city-number formula:

```swift
/// An authored assignment of one defense role per battle lane.
///
/// Stores only the two non-standard lanes; the remaining lane is implicitly
/// `.standard`. This makes the "exactly one fortified / one exposed / one
/// standard" invariant unbreakable by construction.
```

- [ ] **Step 7: Update the current architecture documentation**

In `CLAUDE.md`, replace the lane-profile portion of the `BattleCombatState`
architecture paragraph with:

```markdown
`Country1CityCatalog` owns each authored city's `LaneDefenseProfile`: one
fortified lane (1.25× tower damage), one exposed lane (0.80×), and one standard
lane. `KingdomGameState.currentCityLaneDefenseProfile` projects the active
city's catalog definition, and `BattleScene` feeds its multipliers into the
combat configuration.
```

Keep historical specs and implementation plans unchanged.

- [ ] **Step 8: Run the focused model suites**

Preferred: use XcodeBuildMCP `test_sim` with:

```text
extraArgs:
  - -parallel-testing-enabled
  - NO
  - -only-testing:PyxisTests/Country1CityCatalogTests
  - -only-testing:PyxisTests/KingdomGameStateTests
  - -only-testing:PyxisTests/LaneDefenseProfileTests
```

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/LaneDefenseProfileTests
```

Expected: PASS. The historical trait table, explicit current-city lane anchors,
catalog parity, bounds, and generic lane-profile behavior all remain green.

- [ ] **Step 9: Run lint**

```bash
swiftlint lint
```

Expected: exit status 0 with no new violations.

- [ ] **Step 10: Run the complete unit-test target**

Preferred: use XcodeBuildMCP `test_sim` with
`extraArgs: ["-parallel-testing-enabled", "NO", "-only-testing:PyxisTests"]`.

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: PASS with campaign, combat, idle, map, building, save, and scene-model
behavior unchanged.

- [ ] **Step 11: Review the final diff for forbidden scope**

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Expected:

- No changes to `project.pbxproj`.
- No SpriteKit/UIKit imports in the new model files.
- No changes to save coding keys, gold formulas, building unlock rules, scene
  behavior, or UI tests.
- Only the files listed in this task and the earlier task commits are changed.

- [ ] **Step 12: Commit the runtime migration**

```bash
git add \
  CLAUDE.md \
  Pyxis/KingdomGameState.swift \
  Pyxis/LaneDefenseProfile.swift \
  PyxisTests/Country1CityCatalogTests.swift \
  PyxisTests/KingdomGameStateTests.swift \
  PyxisTests/LaneDefenseProfileTests.swift
git commit -m "refactor: route Country 1 combat metadata through catalog"
```
