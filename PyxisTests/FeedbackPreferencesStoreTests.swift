//
//  FeedbackPreferencesStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct FeedbackPreferencesStoreTests {
    @Test func missingDataLoadsEnabledDefaults() throws {
        let context = try makeStore()

        #expect(context.store.current == .defaultValue)
    }

    @Test func settersPreserveSiblingAndRoundTrip() throws {
        let context = try makeStore()

        #expect(context.store.setSoundEffectsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect(context.store.setHapticsEnabled(false) == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )
        #expect(reloaded.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        ))
    }

    @Test func persistedPartialObjectUsesFieldLevelTolerance() throws {
        let context = try makeStore()
        context.defaults.set(
            Data(#"{"soundEffectsEnabled":false,"hapticsEnabled":"bad"}"#.utf8),
            forKey: context.key
        )

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == nil)
    }

    @Test func invalidRootBacksUpOriginalBytesAndDefaults() throws {
        let context = try makeStore()
        let corrupt = Data("{ invalid json".utf8)
        context.defaults.set(corrupt, forKey: context.key)

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == .defaultValue)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == corrupt)
    }

    @Test func nonKeyedRootUsesTheCorruptBackupPath() throws {
        let context = try makeStore()
        let nonKeyedRoot = Data(#"[true,false]"#.utf8)
        context.defaults.set(nonKeyedRoot, forKey: context.key)

        let reloaded = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(reloaded.current == .defaultValue)
        #expect(
            context.defaults.data(forKey: "\(context.key).corrupt") == nonKeyedRoot
        )
    }

    @Test func laterCorruptionOverwritesSingleBackupAndValidWritesKeepIt() throws {
        let context = try makeStore()
        let first = Data("first-invalid".utf8)
        let second = Data("second-invalid".utf8)

        context.defaults.set(first, forKey: context.key)
        _ = FeedbackPreferencesStore(defaults: context.defaults, key: context.key)
        context.defaults.set(second, forKey: context.key)
        let recovered = FeedbackPreferencesStore(
            defaults: context.defaults,
            key: context.key
        )

        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
        _ = recovered.setSoundEffectsEnabled(false)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
        _ = FeedbackPreferencesStore(defaults: context.defaults, key: context.key)
        #expect(context.defaults.data(forKey: "\(context.key).corrupt") == second)
    }

    @Test func preferenceWritesDoNotTouchCampaignState() throws {
        let context = try makeStore()
        let campaign = Data("campaign".utf8)
        context.defaults.set(campaign, forKey: "pyxis.kingdomGameState")

        _ = context.store.setHapticsEnabled(false)

        #expect(context.defaults.data(forKey: "pyxis.kingdomGameState") == campaign)
    }

    @Test func isolatedStoreNeverWritesItsKeyToStandardDefaults() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        UserDefaults.standard.removeObject(forKey: key)

        let store = FeedbackPreferencesStore(defaults: defaults, key: key)

        #expect(UserDefaults.standard.object(forKey: key) == nil)
        _ = store.setSoundEffectsEnabled(false)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }

    @Test func unchangedSetterSkipsEncodingAndPersistencePath() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        var encodeCount = 0
        let store = FeedbackPreferencesStore(
            defaults: defaults,
            key: key,
            encode: { value in
                encodeCount += 1
                return try JSONEncoder().encode(value)
            }
        )

        _ = store.setSoundEffectsEnabled(true)
        #expect(encodeCount == 0)
        _ = store.setSoundEffectsEnabled(false)
        #expect(encodeCount == 1)
        _ = store.setSoundEffectsEnabled(false)
        #expect(encodeCount == 1)
    }

    @Test func encodingFailureKeepsMemoryAndLastPersistedSnapshot() throws {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        defaults.set(
            try JSONEncoder().encode(FeedbackPreferences()),
            forKey: key
        )
        let store = FeedbackPreferencesStore(
            defaults: defaults,
            key: key,
            encode: { _ in throw TestEncodingError.failed }
        )

        #expect(store.setSoundEffectsEnabled(false).soundEffectsEnabled == false)
        #expect(store.current.soundEffectsEnabled == false)

        let reloaded = FeedbackPreferencesStore(defaults: defaults, key: key)
        #expect(reloaded.current == .defaultValue)
    }

    private func makeStore() throws -> StoreContext {
        let defaults = try makeDefaults()
        let key = "feedback.\(UUID().uuidString)"
        return StoreContext(
            store: FeedbackPreferencesStore(defaults: defaults, key: key),
            defaults: defaults,
            key: key
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct StoreContext {
    let store: FeedbackPreferencesStore
    let defaults: UserDefaults
    let key: String
}

private enum TestEncodingError: Error {
    case failed
}
