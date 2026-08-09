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

        init(
            _ cityNumber: Int,
            _ name: String,
            _ flavorText: String,
            _ conquestTitle: String,
            _ defenseTrait: CityDefenseTrait,
            _ fortifiedLane: BattleLane,
            _ exposedLane: BattleLane
        ) {
            self.cityNumber = cityNumber
            self.name = name
            self.flavorText = flavorText
            self.conquestTitle = conquestTitle
            self.defenseTrait = defenseTrait
            self.fortifiedLane = fortifiedLane
            self.exposedLane = exposedLane
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
                )
            )
        }
    }

    private static let expectedDefinitions: [ExpectedDefinition] = [
        .init(1, "Willowford", "A quiet crossing where the campaign begins.", "Willowford Secured", .standardWatch, .left, .right),
        .init(2, "Pinewatch", "A hill watchtown guarding the old trade road.", "Pinewatch Secured", .standardWatch, .center, .left),
        .init(3, "Falconridge", "Arrow towers command the high ridge road.", "Falconridge Silenced", .arrowTower, .right, .center),
        .init(4, "Bramblegate", "Iron spikes guard a narrow frontier gate.", "Bramblegate Broken", .spikedGate, .left, .right),
        .init(5, "Highcrest", "A proud hill fortress crowns the frontier.", "Highcrest Falls", .arrowTower, .center, .left),
        .init(6, "Granite Pass", "Stone walls seal the mountain road ahead.", "Granite Pass Open", .stoneWall, .right, .center),
        .init(7, "Emberford", "Burning oil guards the bridge inland.", "Emberford Secured", .burningOil, .left, .right),
        .init(8, "Greywall", "Layered stone walls protect a busy town.", "Greywall Falls", .stoneWall, .center, .left),
        .init(9, "Runewatch", "Arcane wards shimmer over the night road.", "Runewatch Unbound", .arcaneWard, .right, .center),
        .init(10, "Ironthorn Gate", "A hardened gate blocks the inner road.", "Ironthorn Gate Broken", .spikedGate, .left, .right),
        .init(11, "Kingshield Keep", "A reinforced fortress guards the royal road.", "Kingshield Keep Falls", .reinforcedKeep, .center, .left),
        .init(12, "Ashbridge", "Fire cauldrons guard the last crossing.", "Ashbridge Secured", .burningOil, .right, .center),
        .init(13, "Starveil Citadel", "Arcane wards protect the capital heights.", "Starveil Citadel Falls", .arcaneWard, .left, .right),
        .init(14, "Stonecrown", "Massive stone walls ring the royal seat.", "Stonecrown Breached", .stoneWall, .center, .left),
        .init(15, "Crownspire Keep", "The final keep rises above the capital.", "Crownspire Keep Falls", .reinforcedKeep, .right, .center)
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
