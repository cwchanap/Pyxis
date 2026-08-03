//
//  FeedbackPreferencesTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct FeedbackPreferencesTests {
    @Test func defaultsEnableBothChannels() {
        #expect(FeedbackPreferences() == FeedbackPreferences(
            soundEffectsEnabled: true,
            hapticsEnabled: true
        ))
        #expect(FeedbackPreferences.defaultValue == FeedbackPreferences())
    }

    @Test func allBooleanCombinationsRoundTrip() throws {
        let values = [
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: false),
            FeedbackPreferences(soundEffectsEnabled: false, hapticsEnabled: true),
            FeedbackPreferences(soundEffectsEnabled: true, hapticsEnabled: false),
            FeedbackPreferences(soundEffectsEnabled: true, hapticsEnabled: true)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for value in values {
            let data = try encoder.encode(value)
            #expect(try decoder.decode(FeedbackPreferences.self, from: data) == value)
        }
    }

    @Test func encodedObjectContainsExactlyTheApprovedKeys() throws {
        let data = try JSONEncoder().encode(FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        ))
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == Set([
            "soundEffectsEnabled",
            "hapticsEnabled"
        ]))
        #expect(object["soundEffectsEnabled"] as? Bool == false)
        #expect(object["hapticsEnabled"] as? Bool == true)
    }

    @Test func missingAndWrongTypedFieldsFailOpenIndependently() throws {
        let data = Data(#"""
        {
          "soundEffectsEnabled": false,
          "hapticsEnabled": "invalid",
          "futureField": 42
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(FeedbackPreferences.self, from: data)

        #expect(decoded.soundEffectsEnabled == false)
        #expect(decoded.hapticsEnabled == true)
    }

    @Test func missingSoundFieldPreservesValidHapticField() throws {
        let data = Data(#"{"hapticsEnabled": false}"#.utf8)

        let decoded = try JSONDecoder().decode(FeedbackPreferences.self, from: data)

        #expect(decoded.soundEffectsEnabled == true)
        #expect(decoded.hapticsEnabled == false)
    }
}

@inline(never)
private func assertHPA389ConsumerContract(
    defaults: UserDefaults,
    manager: FeedbackPreferencesManaging,
    observation: FeedbackPreferencesObservation,
    provider: GameplayFeedbackProviding,
    clock: MonotonicClock
) {
    _ = FeedbackPreferences()
    _ = FeedbackPreferences.defaultValue
    _ = FeedbackPreferences(
        soundEffectsEnabled: false,
        hapticsEnabled: false
    )
    _ = FeedbackPreferencesStore(
        defaults: defaults,
        key: "compile-only.feedback"
    )

    _ = manager.current
    _ = manager.setSoundEffectsEnabled(true)
    _ = manager.setHapticsEnabled(true)
    let returnedObservation = manager.observe { _ in }
    returnedObservation.cancel()
    observation.cancel()

    let discreteEvents: [GameplayFeedbackEvent] = [
        .manualDeployment,
        .buildingChanged,
        .invalidAction,
        .goldReward,
        .cityConquest,
        .countryCompletion,
        .fortifiedLaneWarning
    ]
    discreteEvents.forEach { provider.emit($0) }

    provider.emitAutomaticCombat([
        .soldierDamage(.death),
        .towerFire,
        .soldierAttack(.siege),
        .soldierAttack(.ranged),
        .soldierAttack(.melee),
        .soldierDamage(.hit)
    ])

    _ = SoldierAttackSoundCategory.allCases
    _ = clock.now
}
