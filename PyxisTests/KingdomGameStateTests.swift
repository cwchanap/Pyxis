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
}
