//
//  GameplayFeedbackPolicyTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct GameplayFeedbackPolicyTests {
    @Test func semanticEventsMapToTheirApprovedOutputDirectives() {
        struct Mapping {
            let event: GameplayFeedbackEvent
            let directive: GameplayFeedbackDirective
        }

        let mappings: [Mapping] = [
            Mapping(
                event: .manualDeployment,
                directive: GameplayFeedbackDirective(
                    sound: .deployment,
                    soundClass: .nonAutomatic,
                    soundGate: .deploymentSound,
                    haptic: .lightImpact,
                    hapticGate: .deploymentHaptic
                )
            ),
            Mapping(
                event: .buildingChanged,
                directive: GameplayFeedbackDirective(
                    sound: .construction,
                    soundClass: .nonAutomatic,
                    soundGate: .constructionSound,
                    haptic: .mediumImpact,
                    hapticGate: .constructionHaptic
                )
            ),
            Mapping(
                event: .invalidAction,
                directive: GameplayFeedbackDirective(
                    sound: .blocked,
                    soundClass: .nonAutomatic,
                    soundGate: .invalidSound,
                    haptic: .warning,
                    hapticGate: .invalidHaptic
                )
            ),
            Mapping(
                event: .goldReward,
                directive: GameplayFeedbackDirective(
                    sound: .goldReward,
                    soundClass: .nonAutomatic,
                    soundGate: nil,
                    haptic: nil,
                    hapticGate: nil
                )
            ),
            Mapping(
                event: .cityConquest,
                directive: GameplayFeedbackDirective(
                    sound: .cityConquest,
                    soundClass: .nonAutomatic,
                    soundGate: nil,
                    haptic: .strongSuccess,
                    hapticGate: nil
                )
            ),
            Mapping(
                event: .countryCompletion,
                directive: GameplayFeedbackDirective(
                    sound: .countryCompletion,
                    soundClass: .nonAutomatic,
                    soundGate: nil,
                    haptic: .strongSuccess,
                    hapticGate: nil
                )
            )
        ]

        for mapping in mappings {
            #expect(GameplayFeedbackPolicy.directive(for: mapping.event) == mapping.directive)
        }
    }

    @Test func preferenceManagerSkipsStaleOuterSnapshotAfterReentrantUpdate() {
        let manager = RecordingFeedbackPreferencesManager()
        let outerSnapshot = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: true
        )
        let newestSnapshot = FeedbackPreferences(
            soundEffectsEnabled: false,
            hapticsEnabled: false
        )
        var firstObserverHasTriggeredUpdate = false
        var snapshotsReceivedByLaterObserver: [FeedbackPreferences] = []

        let firstObservation = manager.observe { preferences in
            guard preferences == outerSnapshot,
                  !firstObserverHasTriggeredUpdate
            else {
                return
            }

            firstObserverHasTriggeredUpdate = true
            _ = manager.setHapticsEnabled(false)
        }
        let laterObservation = manager.observe { preferences in
            snapshotsReceivedByLaterObserver.append(preferences)
        }

        withExtendedLifetime((firstObservation, laterObservation)) {
            _ = manager.setSoundEffectsEnabled(false)
        }

        #expect(snapshotsReceivedByLaterObserver == [
            .defaultValue,
            newestSnapshot
        ])
    }
}
