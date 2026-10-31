//
//  Country1CampaignTreasuryTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// Harness-policy tests for the bought/free Treasury campaign variants
/// (HPA-670 Task 5). The deterministic simulations themselves are env-gated
/// smoke evidence (see `Country1SiegeSmokeTests`); these always-on tests pin
/// the pieces the evidence relies on: the cheapest-affordable Treasury
/// policy, the real-mutation buy loop, and the extended campaign line.
@MainActor
struct Country1CampaignTreasuryTests {
    private func makeState(city: Int, gold: Int) -> KingdomGameState {
        let key = CityKey(countryNumber: 1, cityNumber: city)
        return KingdomGameState(
            gold: gold,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [key.storageKey: CityBattleState()]
        )
    }

    // MARK: - GreedyTreasuryBuyer policy

    @Test("The cheapest affordable Treasury level wins, deterministically")
    func cheapestAffordableUpgradeWins() {
        // From 0/0/0 with 12 gold only War Chest is affordable; with 15 gold it
        // is still War Chest (12) over Quartermaster (14) and Drill Yard (16).
        let state12 = makeState(city: 1, gold: 12)
        #expect(GreedyTreasuryBuyer.nextAffordableUpgrade(for: state12) == .warChest)

        let state15 = makeState(city: 1, gold: 15)
        #expect(GreedyTreasuryBuyer.nextAffordableUpgrade(for: state15) == .warChest)
    }

    @Test("The policy returns nil below the cheapest price and when every track is maxed")
    func nilWhenUnaffordableOrMaxed() {
        let broke = makeState(city: 1, gold: 11)
        #expect(GreedyTreasuryBuyer.nextAffordableUpgrade(for: broke) == nil)

        var maxed = makeState(city: 1, gold: 99_999)
        maxed.treasury = TreasuryState(
            warChest: TreasuryUpgrade.warChest.maxLevel,
            drillYard: TreasuryUpgrade.drillYard.maxLevel,
            quartermaster: TreasuryUpgrade.quartermaster.maxLevel
        )
        #expect(GreedyTreasuryBuyer.nextAffordableUpgrade(for: maxed) == nil)
    }

    @Test("A maxed track is skipped even when it would be cheapest")
    func maxedTrackIsSkipped() {
        // With War Chest maxed, the cheapest affordable next level is
        // Quartermaster L1 (14) over Drill Yard L1 (16).
        var state = makeState(city: 1, gold: 14)
        state.treasury = TreasuryState(
            warChest: TreasuryUpgrade.warChest.maxLevel,
            drillYard: 0,
            quartermaster: 0
        )
        #expect(GreedyTreasuryBuyer.nextAffordableUpgrade(for: state) == .quartermaster)
    }

    // MARK: - Bought-variant buy loop

    @Test("The buy loop purchases through the real mutation to the tuned 4/4/4 aggregate")
    func buyLoopUsesRealMutationToSpecAggregate() {
        var state = makeState(city: 1, gold: 499)

        let spend = Country1SiegeSmoke.buyTreasuryUpgradesBeforeCamp(for: &state)

        #expect(spend == 499)
        #expect(state.treasury == TreasuryState(warChest: 4, drillYard: 4, quartermaster: 4))
        #expect(state.gold == 0)
    }

    @Test("The buy loop spends nothing when no level is affordable")
    func buyLoopSpendsNothingWhenUnaffordable() {
        var state = makeState(city: 1, gold: 11)

        let spend = Country1SiegeSmoke.buyTreasuryUpgradesBeforeCamp(for: &state)

        #expect(spend == 0)
        #expect(state.treasury == TreasuryState())
        #expect(state.gold == 11)
    }

    // MARK: - Campaign line extension

    @Test("The campaign line carries treasury levels, spends, elapsed and outcome markers")
    func campaignLineCarriesTreasurySpendsAndStallMarkers() {
        let record = Country1CampaignCityRecord(
            city: 7,
            lane: .center,
            camp: [.init(type: .barracks, level: 3)],
            startGold: 162,
            treasurySpend: 85,
            treasury: TreasuryState(warChest: 1, drillYard: 1, quartermaster: 1),
            campSpend: 47,
            endGold: 30,
            elapsedSeconds: 44.2,
            troopLosses: 12,
            reachedConquest: true
        )

        let line = Country1SiegeSmoke.campaignLine(for: record)

        #expect(line.hasPrefix("COUNTRY1_SMOKE campaign=1 city=7 "))
        #expect(line.contains("treasury=1/1/1"))
        #expect(line.contains("startGold=162"))
        #expect(line.contains("treasurySpend=85"))
        #expect(line.contains("campSpend=47"))
        #expect(line.contains("endGold=30"))
        #expect(line.contains("outcome=conquered"))
        #expect(line.contains("elapsed=44.2"))
        #expect(line.contains("losses=12"))
    }
}
