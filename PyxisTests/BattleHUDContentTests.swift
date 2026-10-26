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
        // City 1 authors a Gate, so its Keep holds only its allocated share of the budget.
        let layout = state.currentCityDefinition.siegeLayout
        let expectedMax = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)[layout.keepObjective.id]
        #expect(content.keepMaxPower == expectedMax)
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

    // MARK: - Trait×role medallion projection (HPA-582)

    private func multiplier(
        _ soldierType: SoldierType,
        in state: KingdomGameState
    ) -> Double {
        let content = BattleHUDContent.project(from: state, manualCount: 0)
        return content.medallions.first { $0.soldierType == soldierType }?.damageMultiplier ?? 0
    }

    @Test func medallionMultiplierCombinesTraitAndRoleForSelectedLaneTarget() {
        // Falconridge's left route opens at the Arrow Tower: the archer's
        // ×0.80 trait penalty stacks with the ×1.5 tower role into a net
        // ×1.20 advantage instead of the lying trait-only ×0.80 pill.
        var state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 35, selectedLane: .left)
        state.siegeProgress.selectedLane = .left

        let archer = multiplier(.archer, in: state)
        #expect(abs(archer - 1.2) < 0.0001)
        #expect(multiplier(.infantry, in: state) == 1.25)
        #expect(multiplier(.cavalry, in: state) == 1.25)
        #expect(multiplier(.mage, in: state) == 0.80)
        #expect(multiplier(.siege, in: state) == 1.0)
    }

    @Test func laneSwitchingRetargetsMedallionMultipliers() {
        // Falconridge's center route opens at the Ridge Gate: the archer's
        // tower role no longer applies (×0.80), while siege doubles against
        // the gate (×2.0).
        var state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 35)
        state.siegeProgress.selectedLane = .center

        #expect(multiplier(.archer, in: state) == 0.80)
        #expect(multiplier(.siege, in: state) == 2.0)
        #expect(multiplier(.infantry, in: state) == 1.25)
    }

    @Test func targetDestructionMovesMedallionMultiplierToNextLiveObjective() {
        // With the tower destroyed, Falconridge's left route resolves to the
        // Keep: the archer's role disappears (×0.80) and siege doubles.
        var state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 35, selectedLane: .left)
        let towerID = SiegeTestSupport.objectiveID(for: .arrowTower, in: state)
        let maxPowers = state.currentSiegeLayout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        state.siegeProgress.damageByObjectiveID[towerID!] = maxPowers[towerID!]

        #expect(multiplier(.archer, in: state) == 0.80)
        #expect(multiplier(.siege, in: state) == 2.0)
    }

    @Test func keepOnlyLaneKeepsTraitOnlyMultipliers() {
        // City 1's right route attacks the Keep directly: infantry and
        // cavalry are neutral everywhere, so the medallions stay trait-only.
        let state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 15, selectedLane: .right)

        #expect(multiplier(.infantry, in: state) == 1.0)
        #expect(multiplier(.cavalry, in: state) == 1.0)
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
        let maxHP = VanguardCaptainRules.maxHP(for: state.captainLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: true
        )

        #expect(content.captainStatus == .ready(currentHP: maxHP, maxHP: maxHP, rallyReady: true))
        #expect(content.captainStatus.isRallyActionable)
    }

    @Test func undeployedCaptainProjectsReadyButRallyIsNotActionable() {
        // A durable-alive Captain with no live actor is Ready but its Rally
        // cannot fire — `rallyReady` carries the distinction so the HUD hit
        // target stays inert (HPA-475).
        let state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        let maxHP = VanguardCaptainRules.maxHP(for: state.captainLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: false
        )

        #expect(content.captainStatus == .ready(currentHP: maxHP, maxHP: maxHP, rallyReady: false))
        #expect(!content.captainStatus.isRallyActionable)
    }

    @Test func deployedCaptainWithLiveTimerProjectsActiveEvenThoughRallyIsDurableConsumed() {
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain?.rallyConsumed = true
        let maxHP = VanguardCaptainRules.maxHP(for: state.captainLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: true,
            rallyRemainingSeconds: 3
        )

        #expect(content.captainStatus == .active(currentHP: maxHP, maxHP: maxHP))
    }

    @Test func liveRallyTimerProjectsActiveWithoutTheDeployedFlag() {
        // Active is the transient timer alone (HPA-475 design contract) —
        // protection rides the captured lane even between durable HP syncs.
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain?.rallyConsumed = true
        let maxHP = VanguardCaptainRules.maxHP(for: state.captainLevel)

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            captainIsDeployed: false,
            rallyRemainingSeconds: 3
        )

        #expect(content.captainStatus == .active(currentHP: maxHP, maxHP: maxHP))
    }

    @Test func durableConsumedRallyWithZeroTimerProjectsUsed() {
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain?.rallyConsumed = true
        let maxHP = VanguardCaptainRules.maxHP(for: state.captainLevel)

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

        #expect(
            content.captainStatus
                == .recovering(seconds: 8, rallyConsumed: true, rallyActive: false)
        )
    }

    @Test func retreatingCaptainDuringLiveRallyProjectsRecoveryAndActiveRally() {
        // A Captain falling inside the 5s window keeps recovery AND the
        // still-running Rally: protection lives on the captured lane, so
        // the status must carry both rather than collapsing to Used
        // (HPA-475).
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: 8,
            rallyConsumed: true
        )

        let content = BattleHUDContent.project(
            from: state,
            manualCount: 0,
            rallyRemainingSeconds: 3
        )

        #expect(
            content.captainStatus
                == .recovering(seconds: 8, rallyConsumed: true, rallyActive: true)
        )
        #expect(!content.captainStatus.isRallyActionable)
    }

    @Test func retreatingCaptainWithUnusedRallyProjectsHeld() {
        // Rally survives the retreat but is not actionable while the
        // Captain is down (HPA-475).
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: 8,
            rallyConsumed: false
        )

        let content = BattleHUDContent.project(from: state, manualCount: 0)

        #expect(
            content.captainStatus
                == .recovering(seconds: 8, rallyConsumed: false, rallyActive: false)
        )
        #expect(!content.captainStatus.isRallyActionable)
    }

    @Test func recoveringStatusQuantizesSubSecondDriftToWholeSeconds() {
        // The scene's Captain cadence skip compares projected statuses, so
        // the projection rounds the countdown up to whole display seconds —
        // sub-second drift must not churn a full HUD apply (HPA-475 review).
        var state = KingdomGameState(cityNumberInCountry: 3, completedCityCount: 2)
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: 8,
            rallyConsumed: false
        )
        let baseline = BattleHUDContent.captainStatus(
            for: state,
            captainIsDeployed: false,
            rallyRemainingSeconds: 0
        )

        state.siegeProgress.captain?.recoveryRemainingSeconds = 7.6
        let drifted = BattleHUDContent.captainStatus(
            for: state,
            captainIsDeployed: false,
            rallyRemainingSeconds: 0
        )

        #expect(baseline == .recovering(seconds: 8, rallyConsumed: false, rallyActive: false))
        #expect(drifted == baseline)

        // Crossing a whole-second boundary does change the status.
        state.siegeProgress.captain?.recoveryRemainingSeconds = 7
        #expect(BattleHUDContent.captainStatus(
            for: state,
            captainIsDeployed: false,
            rallyRemainingSeconds: 0
        ) != baseline)
    }

    @Test func projectsIntegerManualDeployChargesWithFullDefault() {
        let baseline = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 1),
            manualCount: 0
        )
        #expect(baseline.manualDeployCharges == BattleCombatState.ManualDeployRules.maxCharges)

        let drained = BattleHUDContent.project(
            from: KingdomGameState(cityNumberInCountry: 1),
            manualCount: 0,
            manualDeployCharges: 1
        )
        #expect(drained.manualDeployCharges == 1)
    }
}
