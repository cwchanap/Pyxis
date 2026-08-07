//
//  FeedbackPreferencesStore.swift
//  Pyxis
//

import Foundation

@MainActor
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private let soundKey: String
    private let hapticsKey: String
    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]

    init(
        defaults: UserDefaults,
        keyPrefix: String = "pyxis.feedback"
    ) {
        self.defaults = defaults
        soundKey = "\(keyPrefix).soundEffectsEnabled"
        hapticsKey = "\(keyPrefix).hapticsEnabled"
        current = FeedbackPreferences(
            soundEffectsEnabled: defaults.object(forKey: soundKey) as? Bool ?? true,
            hapticsEnabled: defaults.object(forKey: hapticsKey) as? Bool ?? true
        )
    }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.soundEffectsEnabled != enabled else {
            return current
        }

        current.soundEffectsEnabled = enabled
        defaults.set(enabled, forKey: soundKey)
        notifyObservers()
        return current
    }

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences {
        guard current.hapticsEnabled != enabled else {
            return current
        }

        current.hapticsEnabled = enabled
        defaults.set(enabled, forKey: hapticsKey)
        notifyObservers()
        return current
    }

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation {
        let id = UUID()
        observers[id] = observer
        observer(current)

        return ObservationToken { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    private func notifyObservers() {
        let snapshot = current
        for callback in Array(observers.values) {
            callback(snapshot)
        }
    }
}

private final class ObservationToken: FeedbackPreferencesObservation {
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
