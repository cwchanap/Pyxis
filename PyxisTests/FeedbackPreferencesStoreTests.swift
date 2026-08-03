//
//  FeedbackPreferencesStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
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

    @Test func observeImmediatelyDeliversCurrentAndDistinctUpdatesBeforeReturn() throws {
        let context = try makeStore()
        var snapshots: [FeedbackPreferences] = []
        let token = context.store.observe { snapshots.append($0) }

        #expect(snapshots == [.defaultValue])
        _ = context.store.setSoundEffectsEnabled(false)
        #expect(snapshots == [
            .defaultValue,
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true)
        ])
        _ = context.store.setSoundEffectsEnabled(false)
        #expect(snapshots.count == 2)
        withExtendedLifetime(token) {}
    }

    @Test func explicitCancellationIsIdempotent() throws {
        let context = try makeStore()
        var count = 0
        let token = context.store.observe { _ in count += 1 }

        token.cancel()
        token.cancel()
        _ = context.store.setHapticsEnabled(false)

        #expect(count == 1)
    }

    @Test func selfCancellationPreventsNestedAndFutureCallbacks() throws {
        let context = try makeStore()
        var count = 0
        var token: FeedbackPreferencesObservation?

        token = context.store.observe { preferences in
            count += 1
            guard preferences.soundEffectsEnabled == false else { return }
            token?.cancel()
            _ = context.store.setHapticsEnabled(false)
        }

        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setSoundEffectsEnabled(true)

        #expect(count == 2)
    }

    @Test func tokenReleaseUnregistersObserver() throws {
        let context = try makeStore()
        var count = 0
        weak var weakToken: AnyObject?

        do {
            let token = context.store.observe { _ in count += 1 }
            weakToken = token
        }

        #expect(weakToken == nil)
        _ = context.store.setSoundEffectsEnabled(false)
        #expect(count == 1)
    }

    @Test func tokenDoesNotRetainStore() throws {
        let defaults = try makeDefaults()
        var store: FeedbackPreferencesStore? = FeedbackPreferencesStore(
            defaults: defaults,
            key: "feedback.\(UUID().uuidString)"
        )
        weak var weakStore = store
        var token: FeedbackPreferencesObservation? = store?.observe { _ in }

        store = nil

        #expect(weakStore == nil)
        token?.cancel()
        token = nil
    }

    @Test func crossCancellationCanRemoveObserverBeforeFutureUpdates() throws {
        let context = try makeStore()
        var cancelledObserverCount = 0
        let cancelledToken = context.store.observe { _ in
            cancelledObserverCount += 1
        }
        let cancellingToken = context.store.observe { _ in
            cancelledToken.cancel()
        }

        _ = context.store.setHapticsEnabled(false)

        #expect(cancelledObserverCount == 1)
        withExtendedLifetime(cancellingToken) {}
    }

    @Test func nestedSetterDuringInitialDeliveryDoesNotResendStaleInitialState() throws {
        let context = try makeStore()
        var snapshots: [FeedbackPreferences] = []

        let token = context.store.observe { preferences in
            snapshots.append(preferences)
            if preferences == .defaultValue {
                _ = context.store.setSoundEffectsEnabled(false)
            }
        }

        #expect(snapshots == [
            .defaultValue,
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true)
        ])
        withExtendedLifetime(token) {}
    }

    @Test func nestedUpdatesNeverDeliverAStaleSnapshotAfterANewerOne() throws {
        let context = try makeStore()
        let versionOne = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        )
        let versionTwo = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        )
        var firstSnapshots: [FeedbackPreferences] = []
        var secondSnapshots: [FeedbackPreferences] = []

        let firstToken = context.store.observe { preferences in
            firstSnapshots.append(preferences)
            if preferences == versionOne {
                _ = context.store.setHapticsEnabled(false)
            }
        }
        let secondToken = context.store.observe { preferences in
            secondSnapshots.append(preferences)
        }

        _ = context.store.setSoundEffectsEnabled(false)

        #expect(isNondecreasing(firstSnapshots, versionOne: versionOne, versionTwo: versionTwo))
        #expect(isNondecreasing(secondSnapshots, versionOne: versionOne, versionTwo: versionTwo))
        #expect(firstSnapshots.last == versionTwo)
        #expect(secondSnapshots.last == versionTwo)
        withExtendedLifetime((firstToken, secondToken)) {}
    }

    @Test func monotonicityHelperRejectsUnknownSnapshots() {
        let versionOne = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        )
        let versionTwo = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        )
        let unexpectedSnapshot = FeedbackPreferences(
            soundEffectsEnabled: true,
            hapticsEnabled: false
        )

        #expect(!isNondecreasing(
            [.defaultValue, versionOne, unexpectedSnapshot, versionTwo],
            versionOne: versionOne,
            versionTwo: versionTwo
        ))
    }

    @Test func callbackArgumentRemainsVersionSpecificWhileCurrentIsLatest() throws {
        let context = try makeStore()
        let versionOne = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        )
        let versionTwo = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        )
        var observedArgumentAfterNestedUpdate: FeedbackPreferences?
        var observedCurrentAfterNestedUpdate: FeedbackPreferences?

        let token = context.store.observe { preferences in
            guard preferences == versionOne else { return }
            _ = context.store.setHapticsEnabled(false)
            observedArgumentAfterNestedUpdate = preferences
            observedCurrentAfterNestedUpdate = context.store.current
        }

        _ = context.store.setSoundEffectsEnabled(false)

        #expect(observedArgumentAfterNestedUpdate == versionOne)
        #expect(observedCurrentAfterNestedUpdate == versionTwo)
        withExtendedLifetime(token) {}
    }

    @Test func reentrantRegistrationGetsImmediateLatestStateAndSkipsOuterCapture() throws {
        let context = try makeStore()
        let versionOne = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        )
        let versionTwo = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        )
        var outerSnapshots: [FeedbackPreferences] = []
        var innerSnapshots: [FeedbackPreferences] = []
        var innerToken: FeedbackPreferencesObservation?

        let outerToken = context.store.observe { preferences in
            outerSnapshots.append(preferences)
            if preferences == versionOne, innerToken == nil {
                innerToken = context.store.observe { innerSnapshots.append($0) }
            }
        }

        _ = context.store.setSoundEffectsEnabled(false)
        _ = context.store.setHapticsEnabled(false)

        #expect(outerSnapshots == [.defaultValue, versionOne, versionTwo])
        #expect(innerSnapshots == [versionOne, versionTwo])
        withExtendedLifetime((outerToken, innerToken)) {}
    }

    @Test func duplicateClosureRegistrationsAreIndependent() throws {
        let context = try makeStore()
        var callbackCount = 0
        let callback: (FeedbackPreferences) -> Void = { _ in callbackCount += 1 }

        let first = context.store.observe(callback)
        let second = context.store.observe(callback)
        _ = context.store.setHapticsEnabled(false)

        #expect(callbackCount == 4)
        first.cancel()
        _ = context.store.setSoundEffectsEnabled(false)
        #expect(callbackCount == 5)
        withExtendedLifetime(second) {}
    }

    @Test func encodingFailureStillDeliversNewInMemorySnapshot() throws {
        let defaults = try makeDefaults()
        let store = FeedbackPreferencesStore(
            defaults: defaults,
            key: "feedback.\(UUID().uuidString)",
            encode: { _ in throw TestEncodingError.failed }
        )
        var snapshots: [FeedbackPreferences] = []
        let token = store.observe { snapshots.append($0) }

        _ = store.setSoundEffectsEnabled(false)

        #expect(snapshots.last == FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        withExtendedLifetime(token) {}
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

@MainActor
private func isNondecreasing(
    _ snapshots: [FeedbackPreferences],
    versionOne: FeedbackPreferences,
    versionTwo: FeedbackPreferences
) -> Bool {
    let ranks = snapshots.compactMap { snapshot -> Int? in
        if snapshot == .defaultValue { return 0 }
        if snapshot == versionOne { return 1 }
        if snapshot == versionTwo { return 2 }
        return nil
    }
    guard ranks.count == snapshots.count else { return false }
    return zip(ranks, ranks.dropFirst()).allSatisfy { pair in
        pair.0 <= pair.1
    }
}
