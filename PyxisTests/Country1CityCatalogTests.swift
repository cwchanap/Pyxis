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
        ExpectedDefinition(cityNumber: 1, defenseTrait: .standardWatch, fortifiedLane: .left, exposedLane: .right),
        ExpectedDefinition(cityNumber: 2, defenseTrait: .standardWatch, fortifiedLane: .center, exposedLane: .left),
        ExpectedDefinition(cityNumber: 3, defenseTrait: .arrowTower, fortifiedLane: .right, exposedLane: .center),
        ExpectedDefinition(cityNumber: 4, defenseTrait: .spikedGate, fortifiedLane: .left, exposedLane: .right),
        ExpectedDefinition(cityNumber: 5, defenseTrait: .arrowTower, fortifiedLane: .center, exposedLane: .left),
        ExpectedDefinition(cityNumber: 6, defenseTrait: .stoneWall, fortifiedLane: .right, exposedLane: .center),
        ExpectedDefinition(cityNumber: 7, defenseTrait: .burningOil, fortifiedLane: .left, exposedLane: .right),
        ExpectedDefinition(cityNumber: 8, defenseTrait: .stoneWall, fortifiedLane: .center, exposedLane: .left),
        ExpectedDefinition(cityNumber: 9, defenseTrait: .arcaneWard, fortifiedLane: .right, exposedLane: .center),
        ExpectedDefinition(cityNumber: 10, defenseTrait: .spikedGate, fortifiedLane: .left, exposedLane: .right),
        ExpectedDefinition(cityNumber: 11, defenseTrait: .reinforcedKeep, fortifiedLane: .center, exposedLane: .left),
        ExpectedDefinition(cityNumber: 12, defenseTrait: .burningOil, fortifiedLane: .right, exposedLane: .center),
        ExpectedDefinition(cityNumber: 13, defenseTrait: .arcaneWard, fortifiedLane: .left, exposedLane: .right),
        ExpectedDefinition(cityNumber: 14, defenseTrait: .stoneWall, fortifiedLane: .center, exposedLane: .left),
        ExpectedDefinition(cityNumber: 15, defenseTrait: .reinforcedKeep, fortifiedLane: .right, exposedLane: .center)
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
