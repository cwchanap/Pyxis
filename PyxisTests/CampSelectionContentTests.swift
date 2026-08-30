//
//  CampSelectionContentTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct CampSelectionContentTests {
    @Test func emptyLotProjectsAllBuildingTypesInEnumOrder() {
        let content = CampSelectionContent.project(
            from: KingdomGameState(gold: 100, cityNumberInCountry: 5, completedCityCount: 4),
            selectedSlot: 3
        )

        #expect(content.options.map(\.buildingType) == BuildingType.allCases)
        #expect(content.options.count == 5)
        #expect(content.options[0].state == .available(cost: 15))
        #expect(content.options[1].state == .available(cost: 18))
        #expect(content.options[2].state == .available(cost: 28))
        #expect(content.options[3].state == .locked(unlocksAtCity: 8))
        #expect(content.options[4].state == .locked(unlocksAtCity: 11))
    }

    @Test func optionStateUsesLockedThenCappedThenAffordabilityPrecedence() {
        var state = KingdomGameState(gold: 0, cityNumberInCountry: 5, completedCityCount: 4)
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
            1: CityBuilding(type: .barracks),
            2: CityBuilding(type: .barracks),
            3: CityBuilding(type: .barracks),
            4: CityBuilding(type: .barracks),
            5: CityBuilding(type: .barracks)
        ])

        let content = CampSelectionContent.project(from: state, selectedSlot: 6)

        #expect(content.option(for: .barracks)?.state == .capped(maximum: 5))
        #expect(content.option(for: .archeryRange)?.state == .unaffordable(cost: 18, currentGold: 0))
        #expect(content.option(for: .mageTower)?.state == .locked(unlocksAtCity: 8))
    }

    @Test func recommendationEmphasisRequiresExactSlotTypeAndAction() {
        let state = KingdomGameState(gold: 100)
        let exact = CampSelectionContent.project(from: state, selectedSlot: 1)
        let differentLot = CampSelectionContent.project(from: state, selectedSlot: 2)

        #expect(exact.option(for: .barracks)?.isRecommended == true)
        #expect(differentLot.options.allSatisfy { !$0.isRecommended })
    }

    @Test func occupiedInspectorContainsAuthoredBuildingDetailsAndRealUpgradeCost() {
        var state = KingdomGameState(gold: 320)
        _ = state.buildBuilding(.barracks, inSlot: 1)
        _ = state.upgradeBuilding(inSlot: 1)

        let content = CampSelectionContent.project(from: state, selectedSlot: 1)
        let inspector = content.inspector

        #expect(inspector?.buildingAssetName == "building-barracks")
        #expect(inspector?.buildingName == "Barracks")
        #expect(inspector?.level == 2)
        #expect(inspector?.lotNumber == 1)
        #expect(inspector?.producedSoldier == .infantry)
        #expect(inspector?.upgradeCost == KingdomGameState.buildingUpgradeCost(
            for: .barracks,
            currentLevel: 2
        ))
        #expect(inspector?.action == .upgrade(cost: inspector?.upgradeCost ?? 0))
    }

    @Test func recommendationEmphasisForUpgradeRequiresExactOccupiedSlotAndAction() {
        var state = KingdomGameState(gold: 100)
        _ = state.buildBuilding(.barracks, inSlot: 1)
        _ = state.buildBuilding(.barracks, inSlot: 2)

        let exact = CampSelectionContent.project(from: state, selectedSlot: 1)
        let differentLot = CampSelectionContent.project(from: state, selectedSlot: 2)

        #expect(exact.inspector?.isRecommended == true)
        #expect(differentLot.inspector?.isRecommended == false)
    }
}
