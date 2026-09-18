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
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 5)
        state.recordSoldierDeployment(type: .infantry, source: .manual, lane: .center)

        let result = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: try #require(SiegeTestSupport.objectiveID(for: .keep, in: state)),
                appliedDamage: 5
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
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 1)
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .left,
                objectiveID: try #require(SiegeTestSupport.objectiveID(for: .keep, in: state)),
                appliedDamage: 1
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
        var state = SiegeTestSupport.makeBattleState(atCity: 1, gold: 100, keepRemaining: 2)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        #expect(state.buildBuilding(.barracks, inSlot: 2, at: start) == .built(cost: 15, remainingGold: 70))
        state.recordActiveBattleTime(2)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: end)

        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.idleDamageByType.reduce(0) { $0 + $1.damage } == result.damageDealt)
        #expect(pending.idleDamageByType == [
            SiegeIdleDamageByType(type: .infantry, damage: 2)
        ])
        #expect(pending.activeBattleSeconds == 2)
        #expect(pending.goldEarned == result.goldEarned)
        #expect(pending.mvpSoldierType != nil)
    }

    @Test func settlementConquestAttributesDamageByTypeAndMarksIdle() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let settlement = start.addingTimeInterval(100)
        var state = SiegeTestSupport.makeBattleState(atCity: 1, gold: 100, keepRemaining: 1)
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

    // MARK: Abstract settlement Guard absorption (HPA-469)

    @Test func backgroundSettlementMaterializesGuardsBeforeAbstractDamage() throws {
        let start = Date(timeIntervalSinceReferenceDate: 3_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 100, keepRemaining: 1_000, selectedLane: .right)
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(120))

        // One idle spawn (10s active interval at the 1/10 idle rate over
        // 120s) is fully absorbed by the oldest same-lane Guard; the full
        // wave (8 Guards) materialized before any damage was spent.
        let power = state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1)
        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == [
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP - power)
        ] + Array(repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP), count: 7))
        #expect(progress.remainingReserve == 0)
        #expect(progress.waveElapsedSeconds == 0) // 120s wraps into the next phase
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower) // Guard damage is not city damage
        #expect(result.damageDealt == 0)
        #expect(result.conqueredCities == 0)
        #expect(result.goldEarned == 0)
        #expect(state.pendingBattleResult == nil)
    }

    @Test func backgroundSettlementAdvancesGuardPhaseWhenBuildingsYieldNoSpawns() throws {
        let start = Date(timeIntervalSinceReferenceDate: 3_500)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 100, keepRemaining: 1_000, selectedLane: .right)
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(6))

        // Buildings exist but the 6s window yields no spawns — the Guard
        // phase must still advance for the credited settlement window.
        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 6)
        #expect(progress.waveElapsedSeconds == 0)
        #expect(result.damageDealt == 0)
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)
    }

    @Test func campBuildSettlementAdvancesGuardPhaseWhenSpawnsAreEmpty() throws {
        let start = Date(timeIntervalSinceReferenceDate: 4_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 200, keepRemaining: 1_000, selectedLane: .right)
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        // The second build settles the 6s Camp window first: no spawns yet,
        // but exactly one due wave materializes before the build lands.
        guard case .built = state.buildBuilding(.barracks, inSlot: 2, at: start.addingTimeInterval(6)) else {
            Issue.record("expected second build to succeed")
            return
        }

        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 6)
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)
        #expect(state.pendingBattleResult == nil)
    }

    @Test func settlementWithDeadBarracksCreatesNoNewGuards() throws {
        let start = Date(timeIntervalSinceReferenceDate: 4_500)
        var state = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 100,
            keepRemaining: 1_000,
            supportDamage: [.barracks: 1_000],
            selectedLane: .right
        )
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(120))

        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards.isEmpty)
        #expect(progress.remainingReserve == HighcrestGuardRules.totalReserve)
        // The spawn's power spills straight down the direct .right route.
        let power = state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1)
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower - power)
        #expect(result.conqueredCities == 0)
    }

    @Test func campSettlementCanConquerKeepWhileBarracksRemainsAlive() throws {
        let start = Date(timeIntervalSinceReferenceDate: 5_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 100, keepRemaining: 1, selectedLane: .right)
        // Reserve already spent: no Guards can absorb, so spawn power flows
        // through the direct route straight into the dying Keep.
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: 0,
            unresolvedGuards: []
        )
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        let result = state.buildBuilding(.barracks, inSlot: 2, at: start.addingTimeInterval(100))

        guard case .cityConqueredDuringSettlement = result else {
            Issue.record("expected settlement conquest, got \(result)")
            return
        }
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.currentKeepRemainingPower == 0)
        let barracksID = try #require(SiegeTestSupport.objectiveID(for: .barracks, in: state))
        #expect(state.siegeProgress.damageByObjectiveID[barracksID] == nil)
    }

    // MARK: Live-to-settlement Guard time ownership (HPA-469)

    @Test func settlementCreditsOnlyThePostTransitionIntervalToGuardPhase() throws {
        let start = Date(timeIntervalSinceReferenceDate: 7_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 200, keepRemaining: 1_000, selectedLane: .right)
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }

        // Live Battle time advanced the durable wave phase to 4.5s before
        // the player left for Camp.
        _ = state.advanceActiveGuardReinforcements(deltaTime: 4.5)
        #expect(state.siegeProgress.guardReinforcements?.waveElapsedSeconds == 4.5)

        let transition = start.addingTimeInterval(4.5)
        state.markCurrentCityBuildingProgressInactive(at: transition)

        // A later Camp build settles only the post-transition 6s interval.
        guard case .built = state.buildBuilding(.barracks, inSlot: 2, at: transition.addingTimeInterval(6)) else {
            Issue.record("expected second build to succeed")
            return
        }

        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.waveElapsedSeconds == 4.5) // 4.5 + 6.0 wraps once to 4.5
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 6)
    }

    @Test func settlementDoesNotAdvanceGuardPhaseWithoutPlayerBuildings() throws {
        let start = Date(timeIntervalSinceReferenceDate: 8_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, keepRemaining: 1_000, selectedLane: .right)

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(120))

        #expect(result.damageDealt == 0)
        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.waveElapsedSeconds == 0)
        #expect(progress.unresolvedGuards.isEmpty)
        #expect(progress.remainingReserve == HighcrestGuardRules.totalReserve)
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
