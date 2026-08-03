//
//  FeedbackPreferences.swift
//  Pyxis
//

import Foundation

struct FeedbackPreferences: Codable, Equatable {
    static let defaultValue = FeedbackPreferences()

    var soundEffectsEnabled: Bool
    var hapticsEnabled: Bool

    init(
        soundEffectsEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.soundEffectsEnabled = soundEffectsEnabled
        self.hapticsEnabled = hapticsEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case soundEffectsEnabled
        case hapticsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEffectsEnabled =
            (try? container.decode(Bool.self, forKey: .soundEffectsEnabled)) ?? true
        hapticsEnabled =
            (try? container.decode(Bool.self, forKey: .hapticsEnabled)) ?? true
    }
}

protocol FeedbackPreferencesObservation: AnyObject {
    func cancel()
}

protocol FeedbackPreferencesManaging: AnyObject {
    var current: FeedbackPreferences { get }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation
}
