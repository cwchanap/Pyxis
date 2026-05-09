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
            lastBackgroundedAt: backgroundDate,
            countryNumber: 1,
            cityNumberInCountry: 4,
            completedCityCount: 3,
            stageStatus: .battleActive
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.countryNumber == 1)
        #expect(loaded.cityNumberInCountry == 4)
        #expect(loaded.completedCityCount == 3)
        #expect(loaded.stageStatus == .battleActive)
        #expect(loaded.cityMaxPower == KingdomGameState.cityMaxPower(for: 4))
        #expect(loaded.normalSoldierAttackPower == KingdomGameState.normalSoldierAttackPower(for: 3))
    }

    @Test func saveAndLoadRoundTripsPendingMapState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = KingdomGameState(
            gold: 8,
            cityLevel: 2,
            cityRemainingPower: 0,
            normalSoldierUpgradeLevel: 2,
            countryNumber: 1,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.cityNumberInCountry == 2)
        #expect(loaded.completedCityCount == 2)
        #expect(loaded.stageStatus == .cityConqueredPendingMap)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
