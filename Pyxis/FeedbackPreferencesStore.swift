//
//  FeedbackPreferencesStore.swift
//  Pyxis
//

import Foundation

final class FeedbackPreferencesStore {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private let key: String
    private let encode: (FeedbackPreferences) throws -> Data

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
