//
//  TreasuryUpgradeTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// Pure Treasury rules (HPA-670): authoritative metadata, the 1.8-exponent
/// price curve, and `TreasuryState` defaults/clamping.
struct TreasuryUpgradeTests {
    @Test func catalogHasExactlyThreeUpgradesWithAuthoritativeMetadata() {
        #expect(TreasuryUpgrade.allCases == [.warChest, .drillYard, .quartermaster])

        #expect(TreasuryUpgrade.warChest.displayName == "War Chest")
        #expect(TreasuryUpgrade.drillYard.displayName == "Drill Yard")
        #expect(TreasuryUpgrade.quartermaster.displayName == "Quartermaster")

        #expect(TreasuryUpgrade.warChest.baseCost == 12)
        #expect(TreasuryUpgrade.drillYard.baseCost == 16)
        #expect(TreasuryUpgrade.quartermaster.baseCost == 14)

        #expect(TreasuryUpgrade.warChest.maxLevel == 4)
        #expect(TreasuryUpgrade.drillYard.maxLevel == 4)
        #expect(TreasuryUpgrade.quartermaster.maxLevel == 4)

        #expect(TreasuryUpgrade.warChest.effectName == "Conquest gold +10% per level")
        #expect(TreasuryUpgrade.drillYard.effectName == "Soldier attack +5% per level")
        #expect(TreasuryUpgrade.quartermaster.effectName == "Building costs -4% per level")

        #expect(TreasuryUpgrade.warChest.assetName == "treasury-war-chest")
        #expect(TreasuryUpgrade.drillYard.assetName == "treasury-drill-yard")
        #expect(TreasuryUpgrade.quartermaster.assetName == "treasury-quartermaster")
    }

    @Test func priceAtLevelZeroIsTheBaseCost() {
        for upgrade in TreasuryUpgrade.allCases {
            #expect(upgrade.price(forCurrentLevel: 0) == upgrade.baseCost)
        }
    }

    @Test func priceProgressionFollowsTheOnePointEightExponent() {
        let warChest = (0...3).map { TreasuryUpgrade.warChest.price(forCurrentLevel: $0) }
        #expect(warChest == [12, 22, 39, 70])

        let drillYard = (0...3).map { TreasuryUpgrade.drillYard.price(forCurrentLevel: $0) }
        #expect(drillYard == [16, 29, 52, 93])

        let quartermaster = (0...3).map { TreasuryUpgrade.quartermaster.price(forCurrentLevel: $0) }
        #expect(quartermaster == [14, 25, 45, 82])
    }

    /// Campaign-tuned pin (HPA-670 Task 5): all four levels of each track
    /// cost 499 gold in aggregate at starting prices (War Chest 143, Drill
    /// Yard 190, Quartermaster 166). The bought chained campaign showed the
    /// original 40/50/45 ladder with 10/10/8 headroom priced the first
    /// upgrade out of reach until City 7 and starved camps into a City 11
    /// stall; 12/16/14 with 4/4/4 exhausts by about City 10 (see
    /// task-5-report.md). The greedy drain from 499 gold buys every rung and
    /// lands exactly on zero.
    @Test func allFourLevelsMatchCampaignTunedAggregatePrices() {
        let aggregate = TreasuryUpgrade.allCases.map { upgrade in
            (0..<4).map { upgrade.price(forCurrentLevel: $0) }.reduce(0, +)
        }
        #expect(aggregate == [143, 190, 166])
        #expect(aggregate.reduce(0, +) == 499)
    }

    /// Out-of-range current levels clamp into `0...maxLevel`; production
    /// never asks (purchase guards `L < maxLevel`), this only pins the
    /// defensive behavior.
    @Test func priceClampsOutOfRangeCurrentLevels() {
        #expect(TreasuryUpgrade.warChest.price(forCurrentLevel: -3) == 12)
        #expect(TreasuryUpgrade.warChest.price(forCurrentLevel: 10) == 126)
        #expect(TreasuryUpgrade.quartermaster.price(forCurrentLevel: 8) == 147)
    }

    @Test func treasuryStateDefaultsToZeroLevels() {
        let state = TreasuryState()
        for upgrade in TreasuryUpgrade.allCases {
            #expect(state.level(for: upgrade) == 0)
        }
        #expect(state == TreasuryState(warChest: 0, drillYard: 0, quartermaster: 0))
    }

    @Test func treasuryStateInitClampsEveryLevelToZeroThroughMax() {
        #expect(
            TreasuryState(warChest: -3, drillYard: 11, quartermaster: 9)
                == TreasuryState(warChest: 0, drillYard: 4, quartermaster: 4)
        )
    }

    @Test func treasuryStateLevelAccessorsRoundTripAndClamp() {
        var state = TreasuryState()
        state.setLevel(3, for: .warChest)
        state.setLevel(4, for: .quartermaster)
        #expect(state.level(for: .warChest) == 3)
        #expect(state.level(for: .quartermaster) == 4)
        #expect(state.level(for: .drillYard) == 0)

        state.setLevel(99, for: .warChest)
        state.setLevel(-1, for: .quartermaster)
        #expect(state.level(for: .warChest) == 4)
        #expect(state.level(for: .quartermaster) == 0)
    }

    @Test func treasuryStateCodableRoundTrips() throws {
        let original = TreasuryState(warChest: 2, drillYard: 3, quartermaster: 4)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TreasuryState.self, from: data)
        #expect(decoded == original)
    }

    @Test func treasuryStateDecodeClampsOutOfRangeLevels() throws {
        let data = """
        {"warChest": -5, "drillYard": 42, "quartermaster": 4}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TreasuryState.self, from: data)
        #expect(decoded == TreasuryState(warChest: 0, drillYard: 4, quartermaster: 4))
    }
}
