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
    private(set) var current: FeedbackPreferences

    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]
    private var observerOrder: [UUID] = []

    init(current: FeedbackPreferences = .defaultValue) {
        self.current = current
    }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.soundEffectsEnabled != enabled else {
            return current
        }

        current.soundEffectsEnabled = enabled
        notifyObservers()
        return current
    }

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.hapticsEnabled != enabled else {
            return current
        }

        current.hapticsEnabled = enabled
        notifyObservers()
        return current
    }

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation {
        let id = UUID()
        observers[id] = observer
        observerOrder.append(id)
        observer(current)

        return RecordingFeedbackPreferencesObservation { [weak self] in
            self?.observers.removeValue(forKey: id)
            self?.observerOrder.removeAll { $0 == id }
        }
    }

    private func notifyObservers() {
        let snapshot = current

        for id in observerOrder {
            observers[id]?(snapshot)
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
