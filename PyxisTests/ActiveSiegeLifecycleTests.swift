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
        // 120s) is fully absorbed by the oldest same-lane Guard; four due
        // waves (8 Guards) materialized before any damage was spent.
        let power = state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1)
        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == [
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP - power)
        ] + Array(repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP), count: 7))
        #expect(progress.remainingReserve == 4)
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
        let result = state.returnFromBackground(at: start.addingTimeInterval(30))

        // Buildings exist but the 30s window yields no spawns — the Guard
        // phase must still advance for the credited settlement window.
        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 10)
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

        // The second build settles the 30s Camp window first: no spawns yet,
        // but exactly one due wave materializes before the build lands.
        guard case .built = state.buildBuilding(.barracks, inSlot: 2, at: start.addingTimeInterval(30)) else {
            Issue.record("expected second build to succeed")
            return
        }

        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 10)
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

        // A later Camp build settles only the post-transition 30s interval.
        guard case .built = state.buildBuilding(.barracks, inSlot: 2, at: transition.addingTimeInterval(30)) else {
            Issue.record("expected second build to succeed")
            return
        }

        let progress = try #require(state.siegeProgress.guardReinforcements)
        #expect(progress.waveElapsedSeconds == 4.5) // 4.5 + 30.0 wraps once to 4.5
        #expect(progress.unresolvedGuards == Array(
            repeating: GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            count: 2
        ))
        #expect(progress.remainingReserve == 10)
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

    // MARK: Lifecycle reconstruction & non-pilot regressions (HPA-469 Task 5)

    @Test func backgroundForegroundCycleCannotHealRefillOrRestartGuards() throws {
        let start = Date(timeIntervalSinceReferenceDate: 9_000)
        var state = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 100,
            keepRemaining: 300,
            supportDamage: [.barracks: 10],
            selectedLane: .left
        )
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 4.5,
            remainingReserve: 3,
            unresolvedGuards: [
                GuardSnapshot(lane: .left, remainingHP: 5),
                GuardSnapshot(lane: .right, remainingHP: 9)
            ]
        )
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected build to succeed")
            return
        }

        // Leaving Battle freezes Guard progress verbatim: no heal, no
        // refill, no phase restart.
        state.enterBackground(at: start)
        #expect(state.siegeProgress.guardReinforcements == GuardReinforcementProgress(
            waveElapsedSeconds: 4.5,
            remainingReserve: 3,
            unresolvedGuards: [
                GuardSnapshot(lane: .left, remainingHP: 5),
                GuardSnapshot(lane: .right, remainingHP: 9)
            ]
        ))

        // Returning settles only the post-transition 1s window: the phase
        // carries forward (4.5 → 5.5, no wave due), Guards keep their
        // damaged HP, and the reserve stays partially spent.
        let result = state.returnFromBackground(at: start.addingTimeInterval(1))
        #expect(state.siegeProgress.guardReinforcements == GuardReinforcementProgress(
            waveElapsedSeconds: 5.5,
            remainingReserve: 3,
            unresolvedGuards: [
                GuardSnapshot(lane: .left, remainingHP: 5),
                GuardSnapshot(lane: .right, remainingHP: 9)
            ]
        ))
        #expect(result.damageDealt == 0)
        #expect(result.conqueredCities == 0)
        #expect(state.pendingBattleResult == nil)
    }

    @Test func settlementConquestPendingIsConsumedExactlyOnce() throws {
        let start = Date(timeIntervalSinceReferenceDate: 6_000)
        var state = SiegeTestSupport.makeBattleState(atCity: 5, gold: 100, keepRemaining: 1, selectedLane: .right)
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: 0,
            unresolvedGuards: []
        )
        guard case .built = state.buildBuilding(.barracks, inSlot: 1, at: start) else {
            Issue.record("expected first build to succeed")
            return
        }
        guard case .cityConqueredDuringSettlement = state.buildBuilding(
            .barracks, inSlot: 2, at: start.addingTimeInterval(100)
        ) else {
            Issue.record("expected settlement conquest")
            return
        }

        // The pending result exists exactly once and the second completion
        // is refused without a second award.
        let pending = try #require(state.pendingBattleResult)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        let gold = state.gold
        #expect(state.completeCurrentCity(with: pending).awarded == false)
        #expect(state.gold == gold)

        // Acknowledging clears the pending result exactly once.
        state.acknowledgePendingBattleResult()
        #expect(state.pendingBattleResult == nil)
        state.acknowledgePendingBattleResult()
        #expect(state.pendingBattleResult == nil)
        #expect(state.completeCurrentCity(with: pending).awarded == false)
    }

    @Test func nonPilotCityKeepsNilGuardStateAndUnchangedSiegeFlow() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 2, keepRemaining: 10, selectedLane: .right)

        // Fresh entry carries no Guard scheduler state, and both the wave
        // scheduler and the live-sync seam are no-ops that never materialize
        // Guard state.
        #expect(state.siegeProgress.guardReinforcements == nil)
        #expect(state.advanceActiveGuardReinforcements(deltaTime: 60).isEmpty)
        #expect(state.synchronizeLiveGuardSnapshots([
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP)
        ]) == false)
        #expect(state.siegeProgress.guardReinforcements == nil)

        // The snapshot feeding combat keeps the unchanged single-keep shape:
        // one objective whose defensive fire still covers every lane.
        let snapshot = state.currentSiegeSnapshot
        #expect(snapshot.objectiveRemainingPower.count == 1)
        #expect(snapshot.layout.defensiveFire.coveredLanes == BattleLane.allCases)

        // HPA-468 selected-lane objective combat is unchanged: the .right
        // route spends straight into the Keep, and combat never creates
        // Guard state.
        state.recordSoldierDeployment(type: .infantry, source: .manual, lane: .right)
        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        let keepMax = state.currentSiegeLayout.maxPowerAllocation(totalBudget: state.cityMaxPower)[keepID] ?? 0
        let first = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .right,
                objectiveID: keepID,
                appliedDamage: 4
            )
        ])
        #expect(first.conqueredCities == 0)
        #expect(state.siegeProgress.damageByObjectiveID[keepID] == keepMax - 10 + 4)
        #expect(state.siegeProgress.guardReinforcements == nil)

        // The existing conquest/report flow is unchanged.
        let conquest = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .right,
                objectiveID: keepID,
                appliedDamage: 10
            )
        ])
        #expect(conquest.conqueredCities == 1)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .live)
        #expect(pending.cityKey == CityKey(countryNumber: 1, cityNumber: 2))
        #expect(pending.goldEarned == KingdomGameState.goldReward(for: 2))
        #expect(state.gold == pending.goldEarned)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.activeSiegeSession == nil)
        #expect(state.siegeProgress.guardReinforcements == nil)
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
