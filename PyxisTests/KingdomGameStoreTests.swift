//
//  KingdomGameStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct KingdomGameStoreTests {
    @Test func loadReturnsFreshStateWhenNoSaveExists() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")

        let state = store.load()

        #expect(state == KingdomGameState())
    }

    @Test func saveAndLoadRoundTripsMutableState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let backgroundDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let saved = KingdomGameState(
            gold: 42,
            cityLevel: 4,
            cityRemainingPower: 123,
            normalSoldierUpgradeLevel: 3,
            lastBackgroundedAt: backgroundDate
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.cityMaxPower == KingdomGameState.cityMaxPower(for: 4))
        #expect(loaded.normalSoldierAttackPower == KingdomGameState.normalSoldierAttackPower(for: 3))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
