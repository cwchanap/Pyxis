//
//  FeedbackPreferencesStore.swift
//  Pyxis
//

import Foundation

@MainActor
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private struct ObserverRecord {
        let callback: (FeedbackPreferences) -> Void
        var lastDeliveredVersion: UInt64
    }

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private let key: String
    private let encode: (FeedbackPreferences) throws -> Data
    private var version: UInt64 = 0
    private var observers: [UUID: ObserverRecord] = [:]
    private var observerOrder: [UUID] = []

    convenience init(
        defaults: UserDefaults,
        key: String = "pyxis.feedbackPreferences"
    ) {
        self.init(
            defaults: defaults,
            key: key,
            encode: { try JSONEncoder().encode($0) }
        )
    }

    init(
        defaults: UserDefaults,
        key: String,
        encode: @escaping (FeedbackPreferences) throws -> Data,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.key = key
        self.encode = encode
        current = Self.load(defaults: defaults, key: key, decoder: decoder)
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
        let snapshot = current
        observer(snapshot)

        return ObservationToken { [weak self] in
            self?.observers.removeValue(forKey: id)
            self?.observerOrder.removeAll { $0 == id }
        }
    }

    private func commit(_ updated: FeedbackPreferences) {
        current = updated
        do {
            defaults.set(try encode(updated), forKey: key)
        } catch {
            NSLog(
                "[Pyxis] Failed to encode FeedbackPreferences: %@",
                error.localizedDescription
            )
        }

        version += 1
        let deliveryVersion = version
        let snapshot = updated
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

    private static func load(
        defaults: UserDefaults,
        key: String,
        decoder: JSONDecoder
    ) -> FeedbackPreferences {
        guard let data = defaults.data(forKey: key) else {
            return .defaultValue
        }

        do {
            return try decoder.decode(FeedbackPreferences.self, from: data)
        } catch {
            NSLog(
                "[Pyxis] Failed to decode FeedbackPreferences: %@",
                error.localizedDescription
            )
            defaults.set(data, forKey: "\(key).corrupt")
            return .defaultValue
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
