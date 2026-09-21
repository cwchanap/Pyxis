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

    @Test func freshStateProjectsDefaultLaneAndFullKeepHP() {
        let state = KingdomGameState(cityNumberInCountry: 1)
        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.selectedLane == state.currentCityDefinition.siegeLayout.defaultLane)
        #expect(content.keepMaxPower == KingdomGameState.cityMaxPower(for: 1))
        #expect(content.keepRemainingPower == content.keepMaxPower)
    }

    @Test func projectsSelectedLaneAndDamagedKeepHPFromSiegeProgress() {
        let state = SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 13,
            selectedLane: .right
        )
        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.selectedLane == .right)
        #expect(content.keepRemainingPower == 13)
        // City 3's authored layout splits the budget across keep/gate/tower;
        // the HUD must project the Keep's authored share, not the city total.
        let layout = state.currentCityDefinition.siegeLayout
        let expectedMax = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)[layout.keepObjective.id]
        #expect(content.keepMaxPower == expectedMax)
    }

    @Test func supportObjectiveDamageDoesNotChangeKeepDisplayProjection() {
        // City 3's gate/tower absorb damage before the Keep; Keep displays
        // must read Keep HP only (HPA-468).
        let state = SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 13,
            supportDamage: [.gate: 10, .arrowTower: 10]
        )
        let content = BattleHUDContent.project(from: state, manualCount: 0)

        // Keep display reads Keep HP only: gate/tower damage never moves it.
        #expect(content.keepRemainingPower == 13)
        // The 10-point hits landed on each support objective's route share.
        let layout = state.currentCityDefinition.siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        let supportRemaining = layout.objectives
            .filter { $0.kind != .keep }
            .map { max(0, (maxPowers[$0.id] ?? 0) - 10) }
            .reduce(0, +)
        #expect(SiegeTestSupport.totalObjectiveRemainingPower(of: state) == 13 + supportRemaining)
    }

    // MARK: - HPA-475 Task 4: Captain/Rally projection

    @Test func captainIsUnavailableBelowCityThree() {
        let content = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 2, completedCityCount: 1),
            manualCount: 0
        )

        #expect(content.captainStatus == .unavailable)
    }

    @Test func freshCityThreeCaptainProjectsReadyWithRallyAvailable() {
        let state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        let maxHP = VanguardCaptainRules.maxHP(for: state.normalSoldierUpgradeLevel)

        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.captainStatus == .ready(currentHP: maxHP, maxHP: maxHP, rallyReady: true))
    }

    @Test func deployedCaptainWithLiveTimerProjectsActiveEvenThoughRallyIsDurableConsumed() {
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain?.rallyConsumed = true
        let maxHP = VanguardCaptainRules.maxHP(for: state.normalSoldierUpgradeLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: true,
            rallyRemainingSeconds: 3
        )

        #expect(content.captainStatus == .active(currentHP: maxHP, maxHP: maxHP))
    }

    @Test func durableConsumedRallyWithZeroTimerProjectsUsed() {
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain?.rallyConsumed = true
        let maxHP = VanguardCaptainRules.maxHP(for: state.normalSoldierUpgradeLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: true,
            rallyRemainingSeconds: 0
        )

        #expect(content.captainStatus == .used(currentHP: maxHP, maxHP: maxHP))
    }

    @Test func retreatingCaptainProjectsRecoverySecondsAndRallyBit() {
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: 8,
            rallyConsumed: true
        )

        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(content.captainStatus == .recovering(seconds: 8, rallyConsumed: true))
    }
}
