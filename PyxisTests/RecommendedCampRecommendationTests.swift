//
//  RecommendedCampRecommendationTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct RecommendedCampRecommendationTests {
    private func makeState(
        city: Int,
        gold: Int,
        cityState: CityBattleState = CityBattleState(),
        stageStatus: KingdomGameState.StageStatus = .battleActive
    ) -> KingdomGameState {
        let key = CityKey(countryNumber: 1, cityNumber: city)
        return KingdomGameState(
            gold: gold,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            stageStatus: stageStatus,
            cityBattleStates: [key.storageKey: cityState]
        )
    }

    @Test("City 1 recommends the Standard Watch Infantry starter")
    func city1RecommendsInfantryStarter() {
        let state = makeState(city: 1, gold: 15)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
            reason: "Infantry starter"
        ))
    }

    @Test("The same City 1 action becomes Save for when unaffordable")
    func city1BuildBecomesSaveFor() {
        let state = makeState(city: 1, gold: 10)

        #expect(RecommendedCampRecommendation.make(for: state) == .saveFor(
            action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
            missingGold: 5,
            reason: "Infantry starter"
        ))
    }

    @Test("City 5 authored order chooses Infantry before Cavalry")
    func city5PrefersInfantryBeforeCavalry() {
        let state = makeState(city: 5, gold: 100)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
            reason: "Infantry favored"
        ))
    }

    @Test("City 6 does not use the Standard Watch fallback when all favorable buildings are locked")
    func city6LockedFavorablesReturnNoAction() {
        let state = makeState(city: 6, gold: 1_000)

        #expect(RecommendedCampRecommendation.make(for: state) == .noAction(
            message: "No favorable camp action available."
        ))
    }

    @Test("Existing favored building upgrades before building another copy")
    func existingFavoredBuildingChoosesUpgrade() {
        let cityState = CityBattleState(slots: [
            4: CityBuilding(type: .barracks, level: 1)
        ])
        let state = makeState(city: 5, gold: 100, cityState: cityState)
        let expectedCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 1)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .upgrade, buildingType: .barracks, slot: 4, cost: expectedCost),
            reason: "Infantry favored"
        ))
    }

    @Test("Upgrade target is lowest level then lowest slot")
    func upgradeTieBreakIsLevelThenSlot() {
        let cityState = CityBattleState(slots: [
            3: CityBuilding(type: .barracks, level: 2),
            7: CityBuilding(type: .barracks, level: 1),
            5: CityBuilding(type: .barracks, level: 1)
        ])
        let state = makeState(city: 5, gold: 100, cityState: cityState)
        let expectedCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 1)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .upgrade, buildingType: .barracks, slot: 5, cost: expectedCost),
            reason: "Infantry favored"
        ))
    }

    @Test("Unaffordable preferred Barracks upgrade does not substitute Stable")
    func city5SaveForDoesNotSubstituteLaterCandidate() {
        let cityState = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 3)
        ])
        let state = makeState(city: 5, gold: 28, cityState: cityState)
        let upgradeCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 3)

        #expect(upgradeCost > state.gold)
        #expect(KingdomGameState.buildingBuildCost(for: .stable) <= state.gold)
        #expect(RecommendedCampRecommendation.make(for: state) == .saveFor(
            action: .init(kind: .upgrade, buildingType: .barracks, slot: 1, cost: upgradeCost),
            missingGold: upgradeCost - state.gold,
            reason: "Infantry favored"
        ))
    }

    @Test("A new favored building uses the lowest-numbered empty lot")
    func newFavoredBuildingUsesLowestEmptyLot() {
        let cityState = CityBattleState(slots: [
            1: CityBuilding(type: .archeryRange)
        ])
        let state = makeState(city: 5, gold: 100, cityState: cityState)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .build, buildingType: .barracks, slot: 2, cost: 15),
            reason: "Infantry favored"
        ))
    }

    @Test("A capped favored type still chooses its lowest-level lowest-slot upgrade")
    func cappedFavoredTypeChoosesUpgrade() {
        let cityState = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 3),
            2: CityBuilding(type: .barracks, level: 2),
            3: CityBuilding(type: .barracks, level: 4),
            4: CityBuilding(type: .barracks, level: 1),
            5: CityBuilding(type: .barracks, level: 1)
        ])
        let state = makeState(city: 5, gold: 100, cityState: cityState)
        let expectedCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 1)

        #expect(cityState.buildingCount(for: .barracks) == CityBattleState.maxBuildingsPerType)
        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .upgrade, buildingType: .barracks, slot: 4, cost: expectedCost),
            reason: "Infantry favored"
        ))
    }

    @Test("Non-active stage status has no recommendation")
    func nonActiveStageReturnsNoAction() {
        let state = makeState(
            city: 1,
            gold: 100,
            stageStatus: .cityConqueredPendingMap
        )

        #expect(RecommendedCampRecommendation.make(for: state) == .noAction(
            message: "No favorable camp action available."
        ))
    }

    @Test("Identical state produces an identical recommendation")
    func identicalStateProducesIdenticalRecommendation() {
        let state = makeState(city: 5, gold: 100)

        #expect(RecommendedCampRecommendation.make(for: state) == RecommendedCampRecommendation.make(for: state))
    }

    @Test("City 7 keeps Archer first when the later Mage candidate is locked")
    func city7PrefersArcherBeforeLockedMage() {
        let state = makeState(city: 7, gold: 100)

        #expect(RecommendedCampRecommendation.make(for: state) == .ready(
            action: .init(kind: .build, buildingType: .archeryRange, slot: 1, cost: 18),
            reason: "Archer favored"
        ))
    }
}
