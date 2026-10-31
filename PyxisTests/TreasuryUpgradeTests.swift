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

        #expect(TreasuryUpgrade.warChest.baseCost == 40)
        #expect(TreasuryUpgrade.drillYard.baseCost == 50)
        #expect(TreasuryUpgrade.quartermaster.baseCost == 45)

        #expect(TreasuryUpgrade.warChest.maxLevel == 10)
        #expect(TreasuryUpgrade.drillYard.maxLevel == 10)
        #expect(TreasuryUpgrade.quartermaster.maxLevel == 8)

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
        let warChest = (0...9).map { TreasuryUpgrade.warChest.price(forCurrentLevel: $0) }
        #expect(warChest == [40, 72, 130, 233, 420, 756, 1360, 2449, 4408, 7934])

        let drillYard = (0...9).map { TreasuryUpgrade.drillYard.price(forCurrentLevel: $0) }
        #expect(drillYard == [50, 90, 162, 292, 525, 945, 1701, 3061, 5510, 9918])

        let quartermaster = (0...7).map { TreasuryUpgrade.quartermaster.price(forCurrentLevel: $0) }
        #expect(quartermaster == [45, 81, 146, 262, 472, 850, 1531, 2755])
    }

    /// Spec pin (HPA-670): the first four levels of each track cost 1,603
    /// gold in aggregate at starting prices (War Chest 475, Drill Yard 594,
    /// Quartermaster 534).
    @Test func firstFourLevelsMatchSpecAggregateStartingPrices() {
        let aggregate = TreasuryUpgrade.allCases.map { upgrade in
            (0..<4).map { upgrade.price(forCurrentLevel: $0) }.reduce(0, +)
        }
        #expect(aggregate == [475, 594, 534])
        #expect(aggregate.reduce(0, +) == 1603)
    }

    /// Out-of-range current levels clamp into `0...maxLevel`; production
    /// never asks (purchase guards `L < maxLevel`), this only pins the
    /// defensive behavior.
    @Test func priceClampsOutOfRangeCurrentLevels() {
        #expect(TreasuryUpgrade.warChest.price(forCurrentLevel: -3) == 40)
        #expect(TreasuryUpgrade.warChest.price(forCurrentLevel: 10) == 14282)
        #expect(TreasuryUpgrade.quartermaster.price(forCurrentLevel: 8) == 4959)
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
                == TreasuryState(warChest: 0, drillYard: 10, quartermaster: 8)
        )
    }

    @Test func treasuryStateLevelAccessorsRoundTripAndClamp() {
        var state = TreasuryState()
        state.setLevel(3, for: .warChest)
        state.setLevel(8, for: .quartermaster)
        #expect(state.level(for: .warChest) == 3)
        #expect(state.level(for: .quartermaster) == 8)
        #expect(state.level(for: .drillYard) == 0)

        state.setLevel(99, for: .warChest)
        state.setLevel(-1, for: .quartermaster)
        #expect(state.level(for: .warChest) == 10)
        #expect(state.level(for: .quartermaster) == 0)
    }

    @Test func treasuryStateCodableRoundTrips() throws {
        let original = TreasuryState(warChest: 2, drillYard: 7, quartermaster: 8)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TreasuryState.self, from: data)
        #expect(decoded == original)
    }

    @Test func treasuryStateDecodeClampsOutOfRangeLevels() throws {
        let data = """
        {"warChest": -5, "drillYard": 42, "quartermaster": 4}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TreasuryState.self, from: data)
        #expect(decoded == TreasuryState(warChest: 0, drillYard: 10, quartermaster: 4))
    }
}
