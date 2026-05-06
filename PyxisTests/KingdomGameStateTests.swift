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
          "lastBackgroundedAt": null
        }
        """.data(using: .utf8)!

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 0)
        #expect(state.cityLevel == 1)
        #expect(state.cityRemainingPower == 1)
        #expect(state.normalSoldierUpgradeLevel == 1)
        #expect(state.lastBackgroundedAt == nil)
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

    @Test func spawnConquersCityAndGrantsGold() {
        var state = KingdomGameState(cityRemainingPower: 1)

        let result = state.spawnSoldierAttack()

        #expect(result.damageDealt == 1)
        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == 8)
        #expect(state.gold == 8)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
    }

    @Test func foregroundSpawnDoesNotCarryOverExcessDamage() {
        var state = KingdomGameState(cityRemainingPower: 1, normalSoldierUpgradeLevel: 4)

        let result = state.spawnSoldierAttack()

        #expect(result.damageDealt == 3)
        #expect(result.conqueredCities == 1)
        #expect(state.cityLevel == 2)
        #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
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

    @Test func idleCatchUpCanConquerMultipleCitiesWithCarryOverDamage() {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        let end = start.addingTimeInterval(80)
        var state = KingdomGameState(cityRemainingPower: 10)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        #expect(result.elapsedSeconds == 80)
        #expect(result.damageDealt == 80)
        #expect(result.conqueredCities == 2)
        #expect(result.goldEarned == 20)
        #expect(state.cityLevel == 3)
        #expect(state.cityRemainingPower == 65)
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
