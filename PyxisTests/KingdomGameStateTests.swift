//
//  KingdomGameStateTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct KingdomGameStateTests {
    @Test func formulasMatchMVPBalanceCurve() {
        #expect(KingdomGameState.cityMaxPower(for: 1) == 20)
        #expect(KingdomGameState.cityMaxPower(for: 2) == 43)
        #expect(KingdomGameState.cityMaxPower(for: 3) == 92)
        #expect(KingdomGameState.cityMaxPower(for: 10) == 19633)

        #expect(KingdomGameState.goldReward(for: 1) == 8)
        #expect(KingdomGameState.goldReward(for: 2) == 12)

        #expect(KingdomGameState.normalSoldierAttackPower(for: 1) == 1)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 2) == 2)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 4) == 3)

        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 1) == 10)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 2) == 17)
    }

    @Test func formulasClampInvalidLevelsToOne() {
        #expect(KingdomGameState.cityMaxPower(for: 0) == 20)
        #expect(KingdomGameState.goldReward(for: 0) == 8)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 0) == 1)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 0) == 10)
    }

    @Test func decodingInvalidPersistedStateClampsValues() throws {
        let data = """
        {
          "gold": -25,
          "cityLevel": 0,
          "cityRemainingPower": -9,
          "normalSoldierUpgradeLevel": 0,
          "lastBackgroundedAt": null,
          "countryNumber": 0,
          "cityNumberInCountry": 0,
          "completedCityCount": -3,
          "stageStatus": "battleActive"
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 0)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 1)
        #expect(state.normalSoldierUpgradeLevel == 1)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.completedCityCount == 0)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func decodingOldPrototypeSaveInfersCampaignProgressFromCityLevel() throws {
        let data = """
        {
          "gold": 40,
          "cityLevel": 4,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 2
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 40)
        #expect(state.cityLevel == 4)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 3)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityRemainingPower == 12)
    }

    @Test func decodingInvalidStageStatusFallsBackWithoutDiscardingRecoverableFields() throws {
        let data = """
        {
          "gold": 40,
          "cityLevel": 4,
          "cityRemainingPower": 12,
          "normalSoldierUpgradeLevel": 2,
          "countryNumber": 1,
          "cityNumberInCountry": 4,
          "completedCityCount": 3,
          "stageStatus": "renamedStatus"
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 40)
        #expect(state.cityLevel == 4)
        #expect(state.cityRemainingPower == 12)
        #expect(state.normalSoldierUpgradeLevel == 2)
        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 3)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func countryCompleteInitializationNormalizesCompletedCityCount() {
        let state = KingdomGameState(
            cityLevel: 4,
            countryNumber: 1,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .countryComplete
        )

        #expect(state.completedCityCount == KingdomGameState.firstCountryCityCount)
        #expect(state.cityNumberInCountry == KingdomGameState.firstCountryCityCount)
        #expect(state.cityLevel == KingdomGameState.firstCountryCityCount)
        #expect(state.stageStatus == .countryComplete)
        #expect(state.mapStatus(for: 15) == .completed)
        #expect(state.hasNextCityInCountry == false)
    }

    @Test func pendingMapStateIncludesCurrentCityInCompletedCount() {
        let state = KingdomGameState(
            cityLevel: 4,
            cityRemainingPower: 0,
            countryNumber: 1,
            cityNumberInCountry: 4,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )

        #expect(state.cityLevel == 4)
        #expect(state.cityNumberInCountry == 4)
        #expect(state.completedCityCount == 4)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.mapStatus(for: 4) == .completed)
        #expect(state.mapStatus(for: 5) == .unlocked)
    }

    @Test func activeBattleNormalizesAwayFromCompletedCity() {
        let state = KingdomGameState(
            cityLevel: 2,
            cityRemainingPower: 11,
            countryNumber: 1,
            cityNumberInCountry: 2,
            completedCityCount: 5,
            stageStatus: .battleActive
        )

        #expect(state.cityNumberInCountry == 6)
        #expect(state.cityLevel == 6)
        #expect(state.completedCityCount == 5)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityRemainingPower == 11)
        #expect(state.mapStatus(for: 5) == .completed)
        #expect(state.mapStatus(for: 6) == .unlocked)
    }

    @Test func firstLaunchStartsBattleReadyAtCountryOneCityOne() {
        let state = KingdomGameState()

        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.completedCityCount == 0)
        #expect(state.cityLevel == 1)
        #expect(state.stageStatus == .battleActive)
        #expect(state.displayCityTitle == "Country 1 - City 1")
        #expect(state.mapStatus(for: 1) == .unlocked)
        #expect(state.mapStatus(for: 2) == .locked)
    }

    @Test func spawningSoldierDamagesCurrentCity() {
        var state = KingdomGameState(cityRemainingPower: 20)

        let result = state.spawnSoldierAttack()

        #expect(result.damageDealt == 1)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.cityRemainingPower == 19)
        #expect(state.cityLevel == 1)
        #expect(state.gold == 0)
    }

    @Test func foregroundConquestMarksCurrentCityConqueredAndPausesCombat() {
        var state = KingdomGameState(cityRemainingPower: 1)

        let result = state.spawnSoldierAttack()

        #expect(result.attackApplied)
        #expect(result.damageDealt == 1)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.mapStatus(for: 1) == .completed)
        #expect(state.mapStatus(for: 2) == .unlocked)
    }

    @Test func combatActionIsRejectedAfterCityIsConquered() {
        var state = KingdomGameState(cityRemainingPower: 1)

        _ = state.spawnSoldierAttack()
        let blockedResult = state.spawnSoldierAttack()

        #expect(!blockedResult.attackApplied)
        #expect(blockedResult.damageDealt == 0)
        #expect(blockedResult.conqueredCities == 0)
        #expect(blockedResult.goldEarned == 0)
        #expect(state.gold == 8)
        #expect(state.completedCityCount == 1)
        #expect(state.cityRemainingPower == 0)
    }

    @Test func spawnConquersCityAndGrantsGoldWithoutStartingNextCity() {
        var state = KingdomGameState(cityRemainingPower: 1)

        let result = state.spawnSoldierAttack()

        #expect(result.damageDealt == 1)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityLevel == 1)
        #expect(state.completedCityCount == 1)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func foregroundSpawnDoesNotCarryOverExcessDamageIntoNextCity() {
        var state = KingdomGameState(cityRemainingPower: 1, normalSoldierUpgradeLevel: 4)

        let result = state.spawnSoldierAttack()

        #expect(result.damageDealt == 3)
        #expect(result.conqueredCities == 1)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func liveCombatDamageReducesCurrentCityHP() {
        var state = KingdomGameState(cityRemainingPower: 20)

        let result = state.applyLiveCombatDamage(6)

        #expect(result.attackApplied)
        #expect(result.damageDealt == 6)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.cityRemainingPower == 14)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func liveCombatDamageIsCappedAndConquersCurrentCity() {
        var state = KingdomGameState(cityRemainingPower: 3)

        let result = state.applyLiveCombatDamage(9)

        #expect(result.attackApplied)
        #expect(result.damageDealt == 3)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func liveCombatDamageIsRejectedWhenBattleIsPaused() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.spawnSoldierAttack()

        let result = state.applyLiveCombatDamage(5)

        #expect(!result.attackApplied)
        #expect(result.damageDealt == 0)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func startingNextUnlockedCityAdvancesAndRestoresFullHP() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.spawnSoldierAttack()

        let result = state.startCityFromMap(2)

        #expect(result == .entered(country: 1, city: 2))
        #expect(state.cityNumberInCountry == 2)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(state.stageStatus == .battleActive)
    }

    @Test func startingCurrentActiveCityDoesNotResetHP() {
        var state = KingdomGameState(cityLevel: 2, cityRemainingPower: 17, cityNumberInCountry: 2, completedCityCount: 1)

        let result = state.startCityFromMap(2)

        #expect(result == .entered(country: 1, city: 2))
        #expect(state.cityNumberInCountry == 2)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == 17)
        #expect(state.stageStatus == .battleActive)
    }

    @Test func lockedFutureCityEntryIsRejected() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.spawnSoldierAttack()

        let result = state.startCityFromMap(3)

        #expect(result == .locked)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.cityLevel == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func completedCityEntryIsRejected() {
        var state = KingdomGameState(cityRemainingPower: 1)
        _ = state.spawnSoldierAttack()

        let result = state.startCityFromMap(1)

        #expect(result == .alreadyCompleted)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func cityFifteenConquestCompletesCountry() {
        var state = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 1,
            countryNumber: 1,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )

        let result = state.spawnSoldierAttack()

        #expect(result.conqueredCities == 1)
        #expect(state.completedCityCount == 15)
        #expect(state.stageStatus == .countryComplete)
        #expect(state.mapStatus(for: 15) == .completed)
        #expect(state.startCityFromMap(15) == .countryComplete)
    }

    @Test func successfulUpgradeSpendsGoldAndRaisesAttackPower() {
        var state = KingdomGameState(gold: 30)

        let result = state.upgradeNormalSoldier()

        #expect(result == .upgraded(cost: 10, newAttackPower: 2))
        #expect(state.gold == 20)
        #expect(state.normalSoldierUpgradeLevel == 2)
        #expect(state.normalSoldierAttackPower == 2)
    }

    @Test func failedUpgradeDoesNotMutateState() {
        let original = KingdomGameState(gold: 9)
        var state = original

        let result = state.upgradeNormalSoldier()

        #expect(result == .insufficientGold(cost: 10, currentGold: 9))
        #expect(state == original)
    }

    @Test func upgradeIsRejectedWhenBattleIsPausedForMap() {
        let original = KingdomGameState(
            gold: 30,
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        var state = original

        _ = state.upgradeNormalSoldier()

        #expect(state == original)
    }

    @Test func idleCatchUpAppliesAutomaticDamageAndClearsTimestamp() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let end = start.addingTimeInterval(5)
        var state = KingdomGameState(cityRemainingPower: 20)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 5)
        #expect(result.damageDealt == 5)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.cityRemainingPower == 15)
        #expect(state.lastBackgroundedAt == nil)
    }

    @Test func idleCatchUpConquersOnlyCurrentCityAndStops() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(cityRemainingPower: 10)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 80)
        #expect(result.damageDealt == 10)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleCatchUpDoesNothingWhenBattleIsPausedForMap() {
        let start = Date(timeIntervalSinceReferenceDate: 2_500)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(cityRemainingPower: 1)

        _ = state.spawnSoldierAttack()
        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result == .none)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleCatchUpDoesNothingWhenCountryIsComplete() {
        let start = Date(timeIntervalSinceReferenceDate: 2_600)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(
            gold: 100,
            cityLevel: 15,
            cityRemainingPower: 0,
            countryNumber: 1,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result == .none)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.gold == 100)
        #expect(state.completedCityCount == 15)
        #expect(state.cityRemainingPower == 0)
        #expect(state.stageStatus == .countryComplete)
    }

    @Test func idleConquestRewardIsGrantedOnResume() {
        let start = Date(timeIntervalSinceReferenceDate: 2_700)
        let end = start.addingTimeInterval(20)
        var state = KingdomGameState(cityRemainingPower: 5)

        state.enterBackground(at: start)
        #expect(state.gold == 0)
        #expect(state.cityRemainingPower == 5)

        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 20)
        #expect(result.damageDealt == 5)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityRemainingPower == 0)
        #expect(state.completedCityCount == 1)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleCatchUpCannotBeAppliedTwice() {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let end = start.addingTimeInterval(5)
        var state = KingdomGameState(cityRemainingPower: 20)

        state.enterBackground(at: start)
        _ = state.returnFromBackground(at: end)
        let secondResult = state.returnFromBackground(at: end.addingTimeInterval(5))

        #expect(secondResult.elapsedSeconds == 0)
        #expect(secondResult.damageDealt == 0)
        #expect(state.cityRemainingPower == 15)
    }

    @Test func idleCatchUpIsCappedAtEightHours() {
        let start = Date(timeIntervalSinceReferenceDate: 4_000)
        let end = start.addingTimeInterval(Double(KingdomGameState.maxIdleCatchUpSeconds + 120))
        var state = KingdomGameState(cityRemainingPower: 30_000)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == KingdomGameState.maxIdleCatchUpSeconds)
        #expect(result.damageDealt == KingdomGameState.maxIdleCatchUpSeconds)
    }
}
