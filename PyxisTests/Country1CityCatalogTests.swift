//
//  Country1CityCatalogTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct Country1CityCatalogTests {
    private struct ExpectedDefinition {
        let cityNumber: Int
        let name: String
        let flavorText: String
        let conquestTitle: String
        let defenseTrait: CityDefenseTrait
        let fortifiedLane: BattleLane
        let exposedLane: BattleLane
        let visualFamily: CityVisualFamily
        let siegeLayout: CitySiegeLayout?

        init(
            _ cityNumber: Int,
            name: String,
            flavorText: String,
            conquestTitle: String,
            _ defenseTrait: CityDefenseTrait,
            _ fortifiedLane: BattleLane,
            _ exposedLane: BattleLane,
            _ visualFamily: CityVisualFamily,
            siegeLayout: CitySiegeLayout? = nil
        ) {
            self.cityNumber = cityNumber
            self.name = name
            self.flavorText = flavorText
            self.conquestTitle = conquestTitle
            self.defenseTrait = defenseTrait
            self.fortifiedLane = fortifiedLane
            self.exposedLane = exposedLane
            self.visualFamily = visualFamily
            self.siegeLayout = siegeLayout
        }

        var definition: CityDefinition {
            CityDefinition(
                cityNumber: cityNumber,
                name: name,
                flavorText: flavorText,
                conquestTitle: conquestTitle,
                defenseTrait: defenseTrait,
                laneDefenseProfile: LaneDefenseProfile(
                    fortifiedLane: fortifiedLane,
                    exposedLane: exposedLane
                ),
                visualFamily: visualFamily,
                siegeLayout: siegeLayout
            )
        }
    }

    /// The authored Falconridge tactical siege layout, shared by the
    /// fixture entry and the dedicated pin test.
    private static let falconridgeSiegeLayout = CitySiegeLayout(
        objectives: [
            .init(id: "falconridge.keep", kind: .keep, durabilityWeight: 3, visualLane: .center, visualProgress: 1.0),
            .init(
                id: "falconridge.arrow-tower",
                kind: .arrowTower,
                durabilityWeight: 4,
                visualLane: .left,
                visualProgress: 0.68
            ),
            .init(
                id: "falconridge.ridge-gate",
                kind: .gate,
                durabilityWeight: 1,
                visualLane: .center,
                visualProgress: 0.58
            )
        ],
        routes: [
            .left: ["falconridge.arrow-tower", "falconridge.keep"],
            .center: ["falconridge.ridge-gate", "falconridge.keep"],
            .right: ["falconridge.ridge-gate", "falconridge.keep"]
        ],
        defaultLane: .center,
        defensiveFire: .init(sourceObjectiveID: "falconridge.arrow-tower", coveredLanes: BattleLane.allCases)
    )

    /// The authored Highcrest tactical siege layout (HPA-469 Guard pilot),
    /// shared by the fixture entry and the dedicated pin test.
    private static let highcrestSiegeLayout = CitySiegeLayout(
        objectives: [
            .init(id: "highcrest.keep", kind: .keep, durabilityWeight: 20, visualLane: .center, visualProgress: 1.0),
            .init(id: "highcrest.barracks", kind: .barracks, durabilityWeight: 1, visualLane: .left, visualProgress: 0.72)
        ],
        routes: [
            .left: ["highcrest.barracks", "highcrest.keep"],
            .center: ["highcrest.keep"],
            .right: ["highcrest.keep"]
        ],
        defaultLane: .right,
        defensiveFire: .init(sourceObjectiveID: "highcrest.keep", coveredLanes: BattleLane.allCases)
    )

    private static let expectedDefinitions: [ExpectedDefinition] = [
        .init(1, name: "Willowford", flavorText: "A quiet crossing where the campaign begins.", conquestTitle: "Willowford Secured", .standardWatch, .left, .right, .frontier),
        .init(2, name: "Pinewatch", flavorText: "A hill watchtown guarding the old trade road.", conquestTitle: "Pinewatch Secured", .standardWatch, .center, .left, .frontier),
        .init(
            3,
            name: "Falconridge",
            flavorText: "Arrow towers command the high ridge road.",
            conquestTitle: "Falconridge Silenced",
            .arrowTower,
            .right,
            .left,
            .frontier,
            siegeLayout: falconridgeSiegeLayout
        ),
        .init(4, name: "Bramblegate", flavorText: "Iron spikes guard a narrow frontier gate.", conquestTitle: "Bramblegate Broken", .spikedGate, .left, .right, .frontier),
        .init(
            5,
            name: "Highcrest",
            flavorText: "A proud hill fortress crowns the frontier.",
            conquestTitle: "Highcrest Falls",
            .arrowTower,
            .center,
            .right,
            .frontier,
            siegeLayout: highcrestSiegeLayout
        ),
        .init(6, name: "Granite Pass", flavorText: "Stone walls seal the mountain road ahead.", conquestTitle: "Granite Pass Open", .stoneWall, .right, .center, .frontier),
        .init(7, name: "Emberford", flavorText: "Burning oil guards the bridge inland.", conquestTitle: "Emberford Secured", .burningOil, .left, .right, .ember),
        .init(8, name: "Greywall", flavorText: "Layered stone walls protect a busy town.", conquestTitle: "Greywall Falls", .stoneWall, .center, .left, .frontier),
        .init(9, name: "Runewatch", flavorText: "Arcane wards shimmer over the night road.", conquestTitle: "Runewatch Unbound", .arcaneWard, .right, .center, .arcane),
        .init(10, name: "Ironthorn Gate", flavorText: "A hardened gate blocks the inner road.", conquestTitle: "Ironthorn Gate Broken", .spikedGate, .left, .right, .frontier),
        .init(11, name: "Kingshield Keep", flavorText: "A reinforced fortress guards the royal road.", conquestTitle: "Kingshield Keep Falls", .reinforcedKeep, .center, .left, .frontier),
        .init(12, name: "Ashbridge", flavorText: "Fire cauldrons guard the last crossing.", conquestTitle: "Ashbridge Secured", .burningOil, .right, .center, .ember),
        .init(13, name: "Starveil Citadel", flavorText: "Arcane wards protect the capital heights.", conquestTitle: "Starveil Citadel Falls", .arcaneWard, .left, .right, .arcane),
        .init(14, name: "Stonecrown", flavorText: "Massive stone walls ring the royal seat.", conquestTitle: "Stonecrown Breached", .stoneWall, .center, .left, .frontier),
        .init(15, name: "Crownspire Keep", flavorText: "The final keep rises above the capital.", conquestTitle: "Crownspire Keep Falls", .reinforcedKeep, .right, .center, .royal)
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

    @Test func authoredIdentityFieldsAreNonEmptyAndWithinCoarseLengthBounds() {
        for expected in Self.expectedDefinitions {
            #expect(!expected.name.isEmpty, "City \(expected.cityNumber) name must be non-empty")
            #expect(!expected.flavorText.isEmpty, "City \(expected.cityNumber) flavorText must be non-empty")
            #expect(!expected.conquestTitle.isEmpty, "City \(expected.cityNumber) conquestTitle must be non-empty")

            #expect(expected.name.count <= 18, "City \(expected.cityNumber) name exceeds 18 chars: \(expected.name)")
            #expect(expected.flavorText.count <= 48, "City \(expected.cityNumber) flavorText exceeds 48 chars: \(expected.flavorText)")
            #expect(expected.conquestTitle.count <= 24, "City \(expected.cityNumber) conquestTitle exceeds 24 chars: \(expected.conquestTitle)")
        }

        let actualDefinitions = Country1CityCatalog.definitions
        #expect(actualDefinitions == Self.expectedDefinitions.map(\.definition))
    }

    @Test func authoredCityNamesAreUniqueCaseInsensitively() {
        let loweredNames = Self.expectedDefinitions.map { $0.name.lowercased() }
        #expect(Set(loweredNames).count == loweredNames.count)
    }

    @Test func displayTitleCombinesCityNumberAndAuthoredName() {
        for expected in Self.expectedDefinitions {
            #expect(expected.definition.displayTitle == "City \(expected.cityNumber) · \(expected.name)")
        }

        let actualDefinitions = Country1CityCatalog.definitions
        for definition in actualDefinitions {
            #expect(definition.displayTitle == "City \(definition.cityNumber) · \(definition.name)")
        }
    }

    @Test func falconridgeAuthorsTheTacticalSiegeLayout() {
        #expect(Country1CityCatalog.definition(for: 3).siegeLayout == Self.falconridgeSiegeLayout)
    }

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

    /// Shelter invariant (Highcrest route-balance pass): every soldier type
    /// that stalls at the Barracks must stand inside the Keep's defensive
    /// fire, so Barracks chewers can never chew for free. Geometry:
    /// `barracksProgress − soldierRange ≥ keepProgress − towerAttackRange`.
    /// Ranges are recomputed from the live combat configuration (base 0.12;
    /// archer ×2.2 = 0.264 is the largest).
    @Test func highcrestBarracksStallPositionStaysInsideKeepTowerRangeForEverySoldierType() throws {
        let layout = Country1CityCatalog.definition(for: 5).siegeLayout
        let barracksProgress = try #require(layout.barracksObjective?.visualProgress)
        let keepProgress = layout.keepObjective.visualProgress
        let configuration = BattleCombatState.Configuration.live(cityLevel: 5)
        var combat = BattleCombatState(configuration: configuration)

        for type in SoldierType.allCases {
            let id = combat.spawnSoldier(
                type: type,
                source: .manual,
                level: 1,
                attackPower: 1,
                lane: .left
            )
            let soldierRange = try #require(combat.soldier(id: id)).attackRange
            let stallPosition = barracksProgress - soldierRange
            let towerReach = keepProgress - configuration.towerAttackRange

            #expect(
                stallPosition >= towerReach,
                "\(type) stalls at \(stallPosition), outside Keep tower reach \(towerReach)"
            )
        }
    }

    @Test func highcrestDefensiveFireStaysSourcedFromTheKeepAcrossAllLanes() {
        let fire = Country1CityCatalog.definition(for: 5).siegeLayout.defensiveFire

        #expect(fire.sourceObjectiveID == "highcrest.keep")
        #expect(Set(fire.coveredLanes) == Set(BattleLane.allCases))
    }

    @Test func nonPilotCitiesUseSingleKeepDefaultedToTheirStandardLane() {
        // Cities 3 (Falconridge) and 5 (Highcrest) author tactical layouts.
        for definition in Country1CityCatalog.definitions
        where definition.cityNumber != 3 && definition.cityNumber != 5 {
            #expect(
                definition.siegeLayout == .singleKeep(defaultLane: definition.laneDefenseProfile.standardLane),
                "City \(definition.cityNumber) must use the single-keep siege layout on its standard lane"
            )
        }
    }

    @Test func definitionIfPresentReturnsNilOutsideCityRangeAndTheAuthoredDefinitionInside() {
        #expect(Country1CityCatalog.definitionIfPresent(for: -4) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 0) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 16) == nil)
        #expect(Country1CityCatalog.definitionIfPresent(for: 18) == nil)

        for expected in Self.expectedDefinitions {
            #expect(Country1CityCatalog.definitionIfPresent(for: expected.cityNumber) == expected.definition)
        }
    }
}
