//
//  FeedbackPreferencesStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
struct FeedbackPreferencesStoreTests {
    @Test func missingKeysLoadEnabledDefaults() throws {
        let context = try makeStore()

        #expect(context.store.current == .defaultValue)
        #expect(context.defaults.object(forKey: soundKey(for: context)) == nil)
        #expect(context.defaults.object(forKey: hapticsKey(for: context)) == nil)
    }

    @Test func settersPersistTheirBooleanAndPreserveSibling() throws {
        let context = try makeStore()

        #expect(context.store.setSoundEffectsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect((context.defaults.object(forKey: soundKey(for: context)) as? Bool) == false)
        #expect(context.store.current.hapticsEnabled)

        #expect(context.store.setHapticsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))
        #expect((context.defaults.object(forKey: soundKey(for: context)) as? Bool) == false)
        #expect((context.defaults.object(forKey: hapticsKey(for: context)) as? Bool) == false)
    }

    @Test func unchangedSetterDoesNotNotify() throws {
        let context = try makeStore()
        var snapshots: [FeedbackPreferences] = []
        let token = context.store.observe { snapshots.append($0) }

        _ = context.store.setSoundEffectsEnabled(true)
        _ = context.store.setHapticsEnabled(true)

        #expect(snapshots == [.defaultValue])
        withExtendedLifetime(token) {}
    }

    @Test func observerGetsCurrentThenDistinctUpdatesSynchronously() throws {
        let context = try makeStore()
        var snapshots: [FeedbackPreferences] = []
        let token = context.store.observe { snapshots.append($0) }

        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setHapticsEnabled(false)

        #expect(snapshots == [
            .defaultValue,
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true),
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: false)
        ])
        withExtendedLifetime(token) {}
    }

    @Test func cancellationStopsFutureUpdates() throws {
        let context = try makeStore()
        var callbackCount = 0
        let token = context.store.observe { _ in callbackCount += 1 }

        token.cancel()
        token.cancel()
        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setHapticsEnabled(false)

        #expect(callbackCount == 1)
    }

    @Test func isolatedStoreDoesNotTouchCampaignStateOrStandardDefaults() throws {
        let defaults = try makeDefaults()
        let prefix = "feedback.\(UUID().uuidString)"
        let campaignState = Data("campaign".utf8)
        defaults.set(campaignState, forKey: "pyxis.kingdomGameState")

        let store = FeedbackPreferencesStore(defaults: defaults, keyPrefix: prefix)
        _ = store.setSoundEffectsEnabled(false)
        _ = store.setHapticsEnabled(false)

        #expect(defaults.data(forKey: "pyxis.kingdomGameState") == campaignState)
        #expect(UserDefaults.standard.object(
            forKey: "\(prefix).soundEffectsEnabled"
        ) == nil)
        #expect(UserDefaults.standard.object(
            forKey: "\(prefix).hapticsEnabled"
        ) == nil)
    }

    @Test func persistedValuesRoundTripAcrossStoreRecreation() throws {
        let context = try makeStore()
        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setHapticsEnabled(false)

        let recreated = FeedbackPreferencesStore(
            defaults: context.defaults,
            keyPrefix: context.prefix
        )

        #expect(recreated.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))
    }

    private func makeStore() throws -> StoreContext {
        let defaults = try makeDefaults()
        let prefix = "feedback.\(UUID().uuidString)"
        return StoreContext(
            store: FeedbackPreferencesStore(defaults: defaults, keyPrefix: prefix),
            defaults: defaults,
            prefix: prefix
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func soundKey(for context: StoreContext) -> String {
        "\(context.prefix).soundEffectsEnabled"
    }

    private func hapticsKey(for context: StoreContext) -> String {
        "\(context.prefix).hapticsEnabled"
    }
}

private struct StoreContext {
    let store: FeedbackPreferencesStore
    let defaults: UserDefaults
    let prefix: String
}
