//
//  BattleHUDContentTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct BattleHUDContentTests {
    @Test func cityOneEmptyProjectsStarterAndLockedUnits() {
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 1),
            manualCount: 0
        )

        #expect(content.medallions.count == SoldierType.allCases.count)
        #expect(content.medallions.map(\.soldierType) == SoldierType.allCases)
        #expect(content.medallions[0].availability == .available(level: 1))
        #expect(content.medallions[1].availability == .locked(unlocksAtCity: 2))
        #expect(content.medallions[2].availability == .locked(unlocksAtCity: 5))
        #expect(content.medallions[3].availability == .locked(unlocksAtCity: 8))
        #expect(content.medallions[4].availability == .locked(unlocksAtCity: 11))
    }

    @Test func cityFiveEmptyProjectsUnlockedUnbuiltUnits() {
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4),
            manualCount: 0
        )

        #expect(content.medallions[0].availability == .available(level: 1))
        #expect(content.medallions[1].availability == .unbuilt)
        #expect(content.medallions[2].availability == .unbuilt)
        #expect(content.medallions[3].availability == .locked(unlocksAtCity: 8))
        #expect(content.medallions[4].availability == .locked(unlocksAtCity: 11))
    }

    @Test func builtUnitsUseHighestExistingBuildingLevel() {
        var state = KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4)
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 2),
            2: CityBuilding(type: .barracks, level: 4),
            3: CityBuilding(type: .archeryRange, level: 3)
        ])

        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.medallions[0].availability == .available(level: 4))
        #expect(content.medallions[1].availability == .available(level: 3))
    }

    @Test func manualCountDisablesCampAndMapButAttentionStaysIndependent() {
        let state = KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4)
        let empty = BattleHUDContent.project(from: state, manualCount: 0)
        let occupied = BattleHUDContent.project(from: state, manualCount: 1)

        #expect(empty.enabledTabs == [.battle, .camp, .map])
        #expect(occupied.enabledTabs == [.battle])
        #expect(empty.showsCampAttention)
        #expect(occupied.showsCampAttention)
    }

    @Test func traitMultiplierComesFromCurrentCityTrait() {
        let state = KingdomGameState(cityNumberInCountry: 5, completedCityCount: 4)
        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.medallions[0].damageMultiplier == 1.25)
        #expect(content.medallions[1].damageMultiplier == 0.80)
        #expect(content.medallions[2].damageMultiplier == 1.25)
    }

    @Test func projectsAuthoredLaneDefenseProfileForCurrentCity() {
        let state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.laneDefenseProfile.exposedLane == .left)
        #expect(content.laneDefenseProfile.fortifiedLane == .right)
        #expect(content.laneDefenseProfile.role(for: .center) == .standard)
    }
}
