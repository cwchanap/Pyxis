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

    @Test func liveAttacksAttributeDamageAndFinalizePendingResult() throws {
        var state = KingdomGameState(
            gold: 0,
            cityLevel: 1,
            cityRemainingPower: 5,
            normalSoldierUpgradeLevel: 1
        )
        state.recordSoldierDeployment(type: .infantry, source: .manual, lane: .center)

        let result = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                appliedCityDamage: 5
            )
        ])

        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == state.pendingBattleResult?.goldEarned)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .live)
        #expect(pending.cityKey == CityKey(countryNumber: 1, cityNumber: 1))
        #expect(pending.mvpSoldierType == .infantry)
        #expect(pending.goldEarned == KingdomGameState.goldReward(for: 1))
        #expect(state.gold == pending.goldEarned)
        #expect(state.activeSiegeSession == nil)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func completeCurrentCityRejectsDuplicate() throws {
        var state = KingdomGameState(
            gold: 0,
            cityLevel: 1,
            cityRemainingPower: 1,
            normalSoldierUpgradeLevel: 1
        )
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .left,
                appliedCityDamage: 1
            )
        ])
        let pending = try #require(state.pendingBattleResult)
        let gold = state.gold

        let second = state.completeCurrentCity(with: pending)

        #expect(second.awarded == false)
        #expect(state.gold == gold)
    }

    @Test func recordLossesDoNotRunOnEmptyAndMergeByTypeSource() {
        var state = KingdomGameState(
            gold: 0,
            cityLevel: 1,
            cityRemainingPower: 20,
            normalSoldierUpgradeLevel: 1
        )

        state.recordSoldierLosses([
            SoldierLossEvent(
                soldierID: 1,
                type: .archer,
                source: .building,
                lane: .left
            ),
            SoldierLossEvent(
                soldierID: 2,
                type: .archer,
                source: .building,
                lane: .right
            ),
        ])

        #expect(state.activeSiegeSession?.losses == [
            SiegeLossCount(type: .archer, source: .building, count: 2)
        ])
    }

    @Test func idleConquestAttributesDamageByTypeAndMarksIdle() throws {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        let end = start.addingTimeInterval(1_000)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 2)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        #expect(state.buildBuilding(.barracks, inSlot: 2, at: start) == .built(cost: 15, remainingGold: 70))

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.idleDamageByType.reduce(0) { $0 + $1.damage } == result.damageDealt)
        #expect(pending.idleDamageByType == [
            SiegeIdleDamageByType(type: .infantry, damage: 2)
        ])
        #expect(pending.activeBattleSeconds == 0)
        #expect(pending.goldEarned == result.goldEarned)
        #expect(pending.mvpSoldierType != nil)
    }

    @Test func settlementConquestAttributesDamageByTypeAndMarksIdle() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let settlement = start.addingTimeInterval(100)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 1)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        let result = state.buildBuilding(.barracks, inSlot: 2, at: settlement)

        #expect(result == .cityConqueredDuringSettlement(goldEarned: 8, remainingGold: 93))
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.idleDamageByType == [
            SiegeIdleDamageByType(type: .infantry, damage: 1)
        ])
        #expect(pending.activeBattleSeconds == 0)
        #expect(pending.goldEarned == 8)
        #expect(pending.mvpSoldierType == .infantry)
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
