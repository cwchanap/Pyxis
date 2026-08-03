//
//  GameplayFeedbackTestDoubles.swift
//  PyxisTests
//

import Foundation
@testable import Pyxis

struct ManualMonotonicClock: MonotonicClock {
    var now: TimeInterval
}

final class RecordingFeedbackPreferencesManager: FeedbackPreferencesManaging {
    private struct ObserverRecord {
        let callback: (FeedbackPreferences) -> Void
        var lastDeliveredVersion: UInt64
    }

    private(set) var current: FeedbackPreferences

    private var version: UInt64 = 0
    private var observers: [UUID: ObserverRecord] = [:]
    private var observerOrder: [UUID] = []

    init(current: FeedbackPreferences = .defaultValue) {
        self.current = current
    }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.soundEffectsEnabled != enabled else {
            return current
        }

        var updated = current
        updated.soundEffectsEnabled = enabled
        commit(updated)
        return current
    }

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.hapticsEnabled != enabled else {
            return current
        }

        var updated = current
        updated.hapticsEnabled = enabled
        commit(updated)
        return current
    }

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation {
        let id = UUID()
        observers[id] = ObserverRecord(
            callback: observer,
            lastDeliveredVersion: version
        )
        observerOrder.append(id)
        observer(current)

        return RecordingFeedbackPreferencesObservation { [weak self] in
            self?.observers.removeValue(forKey: id)
            self?.observerOrder.removeAll { $0 == id }
        }
    }

    private func commit(_ updated: FeedbackPreferences) {
        current = updated
        version += 1
        let deliveryVersion = version
        let snapshot = current
        let observerIDs = observerOrder

        for id in observerIDs {
            guard var record = observers[id],
                  record.lastDeliveredVersion < deliveryVersion
            else {
                continue
            }

            record.lastDeliveredVersion = deliveryVersion
            observers[id] = record
            record.callback(snapshot)
        }
    }
}

final class RecordingGameplaySoundOutput: GameplaySoundOutput {
    enum Call: Equatable {
        case prepareIfNeeded
        case play(GameplaySoundID, GameplaySoundClass)
        case stopAllAndDeactivate
    }

    private(set) var calls: [Call] = []

    func prepareIfNeeded() {
        calls.append(.prepareIfNeeded)
    }

    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass) {
        calls.append(.play(sound, soundClass))
    }

    func stopAllAndDeactivate() {
        calls.append(.stopAllAndDeactivate)
    }
}

final class RecordingGameplayHapticOutput: GameplayHapticOutput {
    private(set) var played: [GameplayHapticKind] = []

    func play(_ kind: GameplayHapticKind) {
        played.append(kind)
    }
}

private final class RecordingFeedbackPreferencesObservation: FeedbackPreferencesObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let action = cancellation
        cancellation = nil
        action?()
    }

    deinit {
        cancel()
    }
}
