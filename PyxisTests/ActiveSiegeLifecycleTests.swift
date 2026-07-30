//
//  ActiveSiegeLifecycleTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct ActiveSiegeLifecycleTests {
    @Test func missingSessionAndPendingDecodeAsNil() throws {
        let state = KingdomGameState(
            gold: 0,
            cityLevel: 1,
            cityRemainingPower: 20,
            normalSoldierUpgradeLevel: 1
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(decoded.activeSiegeSession == nil)
        #expect(decoded.pendingBattleResult == nil)
    }

    @Test func mismatchedSessionCityKeyIsDroppedOnNormalize() {
        let state = KingdomGameState(
            gold: 0,
            cityLevel: 2,
            cityRemainingPower: 20,
            normalSoldierUpgradeLevel: 1,
            cityNumberInCountry: 2,
            completedCityCount: 1,
            stageStatus: .battleActive,
            activeSiegeSession: ActiveSiegeSession(
                cityKey: CityKey(countryNumber: 1, cityNumber: 9)
            )
        )

        #expect(state.activeSiegeSession == nil)
    }

    @Test func pendingResultDroppedWhenBattleActive() {
        let state = KingdomGameState(
            gold: 8,
            cityLevel: 1,
            cityRemainingPower: 20,
            normalSoldierUpgradeLevel: 1,
            stageStatus: .battleActive,
            pendingBattleResult: battleResult(cityNumber: 1, goldEarned: 8)
        )

        #expect(state.pendingBattleResult == nil)
    }

    @Test func startCityClearsStalePendingAndStartsFreshSession() {
        var state = KingdomGameState(
            gold: 10,
            cityLevel: 1,
            cityRemainingPower: 0,
            normalSoldierUpgradeLevel: 1,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap,
            pendingBattleResult: battleResult(
                cityNumber: 1,
                activeBattleSeconds: 1,
                goldEarned: 8
            )
        )

        let entry = state.startCityFromMap(2)

        #expect(entry == .entered(country: 1, city: 2))
        #expect(state.pendingBattleResult == nil)
        #expect(state.activeSiegeSession?.cityKey == CityKey(countryNumber: 1, cityNumber: 2))
        #expect(state.activeSiegeSession?.activeBattleSeconds == 0)
    }

    @Test func acknowledgePendingClearsOnlyPending() {
        var state = KingdomGameState(
            gold: 10,
            cityLevel: 1,
            cityRemainingPower: 0,
            normalSoldierUpgradeLevel: 1,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap,
            pendingBattleResult: battleResult(
                cityNumber: 1,
                activeBattleSeconds: 2,
                mvpSoldierType: .infantry,
                mvpDamageSharePercent: 100,
                goldEarned: 8
            )
        )
        let goldBefore = state.gold
        let completedBefore = state.completedCityCount

        state.acknowledgePendingBattleResult()

        #expect(state.pendingBattleResult == nil)
        #expect(state.gold == goldBefore)
        #expect(state.completedCityCount == completedBefore)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        state.acknowledgePendingBattleResult()
        #expect(state.pendingBattleResult == nil)
    }

    private func battleResult(
        cityNumber: Int,
        activeBattleSeconds: TimeInterval = 3,
        mvpSoldierType: SoldierType? = nil,
        mvpDamageSharePercent: Int? = nil,
        goldEarned: Int
    ) -> BattleResult {
        BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: cityNumber),
            conquestMode: .live,
            activeBattleSeconds: activeBattleSeconds,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: mvpSoldierType,
            mvpDamageSharePercent: mvpDamageSharePercent,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: goldEarned
        )
    }
}
