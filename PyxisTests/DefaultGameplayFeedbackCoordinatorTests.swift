//
//  DefaultGameplayFeedbackCoordinatorTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
struct DefaultGameplayFeedbackCoordinatorTests {
    @Test func deploymentSoundAndHapticGatesAreIndependentWhenHapticsAreReenabled() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager(
            current: FeedbackPreferences(
                soundEffectsEnabled: true,
                hapticsEnabled: false
            )
        )
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [.play(.deployment, .nonAutomatic)])
        #expect(haptics.played.isEmpty)

        _ = preferences.setHapticsEnabled(true)
        clock.now = 0.001
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [.play(.deployment, .nonAutomatic)])
        #expect(haptics.played == [.lightImpact])

        clock.now = 0.120
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [
            .play(.deployment, .nonAutomatic),
            .play(.deployment, .nonAutomatic)
        ])
        #expect(haptics.played == [.lightImpact])

        clock.now = 0.122
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [
            .play(.deployment, .nonAutomatic),
            .play(.deployment, .nonAutomatic)
        ])
        #expect(haptics.played == [.lightImpact, .lightImpact])
    }

    @Test func invalidSoundAndHapticGatesAreIndependentWhenSoundIsReenabled() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager(
            current: FeedbackPreferences(
                soundEffectsEnabled: false,
                hapticsEnabled: true
            )
        )
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.invalidAction)

        #expect(sound.calls.isEmpty)
        #expect(haptics.played == [.warning])

        _ = preferences.setSoundEffectsEnabled(true)
        clock.now = 0.250
        coordinator.emit(.invalidAction)

        #expect(sound.calls == [.play(.blocked, .nonAutomatic)])
        #expect(haptics.played == [.warning])

        clock.now = 0.500
        coordinator.emit(.invalidAction)

        #expect(sound.calls == [.play(.blocked, .nonAutomatic)])
        #expect(haptics.played == [.warning, .warning])

        clock.now = 0.750
        coordinator.emit(.invalidAction)

        #expect(sound.calls == [
            .play(.blocked, .nonAutomatic),
            .play(.blocked, .nonAutomatic)
        ])
        #expect(haptics.played == [.warning, .warning])
    }

    @Test func constructionFeedbackUsesIts250MillisecondGateForSoundAndHaptic() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.buildingChanged)
        clock.now = 0.100
        coordinator.emit(.buildingChanged)
        clock.now = 0.250
        coordinator.emit(.buildingChanged)

        #expect(sound.calls == [
            .play(.construction, .nonAutomatic),
            .play(.construction, .nonAutomatic)
        ])
        #expect(haptics.played == [
            .mediumImpact,
            .mediumImpact
        ])
    }

    @Test func fortifiedWarningSoundUsesIts750MillisecondGate() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.fortifiedLaneWarning)
        clock.now = 0.749_999_999_999_999_9
        coordinator.emit(.fortifiedLaneWarning)
        clock.now = 0.750
        coordinator.emit(.fortifiedLaneWarning)

        #expect(sound.calls == [
            .play(.fortifiedWarning, .nonAutomatic),
            .play(.fortifiedWarning, .nonAutomatic)
        ])
        #expect(haptics.played.isEmpty)
    }

    @Test func disablingSoundImmediatelyStopsAllActiveSound() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.goldReward)
        _ = preferences.setSoundEffectsEnabled(false)

        #expect(sound.calls == [
            .play(.goldReward, .nonAutomatic),
            .stopAllAndDeactivate
        ])
        #expect(haptics.played.isEmpty)
    }

    @Test func outcomesAreNotTimeGated() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emit(.goldReward)
        coordinator.emit(.cityConquest)
        coordinator.emit(.countryCompletion)
        coordinator.emit(.goldReward)
        coordinator.emit(.cityConquest)
        coordinator.emit(.countryCompletion)

        #expect(sound.calls == [
            .play(.goldReward, .nonAutomatic),
            .play(.cityConquest, .nonAutomatic),
            .play(.countryCompletion, .nonAutomatic),
            .play(.goldReward, .nonAutomatic),
            .play(.cityConquest, .nonAutomatic),
            .play(.countryCompletion, .nonAutomatic)
        ])
        #expect(haptics.played == [
            .strongSuccess,
            .strongSuccess,
            .strongSuccess,
            .strongSuccess
        ])
    }

    @Test func automaticCombatDelegatesOnlyOneSchedulerSelectedSound() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emitAutomaticCombat(denseAutomaticEvents)
        clock.now = 0.150
        coordinator.emitAutomaticCombat(denseAutomaticEvents)
        clock.now = 0.300
        coordinator.emitAutomaticCombat(denseAutomaticEvents)

        #expect(sound.calls == [
            .play(.soldierDeath, .automaticCombat),
            .play(.towerFire, .automaticCombat),
            .play(.attackSiege, .automaticCombat)
        ])
        #expect(haptics.played.isEmpty)
    }

    @Test func disabledSoundDoesNotAdvanceTheAutomaticCombatScheduler() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = RecordingFeedbackPreferencesManager(
            current: FeedbackPreferences(
                soundEffectsEnabled: false,
                hapticsEnabled: true
            )
        )
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: preferences,
            sound: sound,
            haptics: haptics,
            clock: clock
        )

        coordinator.emitAutomaticCombat(denseAutomaticEvents)
        _ = preferences.setSoundEffectsEnabled(true)
        coordinator.emitAutomaticCombat(denseAutomaticEvents)

        #expect(sound.calls == [.play(.soldierDeath, .automaticCombat)])
        #expect(haptics.played.isEmpty)
    }

    @Test func retainsOnePreferenceObservationAndCancelsItOnDeinit() {
        let clock = AdjustableMonotonicClock(now: 0)
        let preferences = ObservationCountingPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        do {
            let coordinator = makeCoordinator(
                preferences: preferences,
                sound: sound,
                haptics: haptics,
                clock: clock
            )

            #expect(preferences.observationCount == 1)
            #expect(preferences.cancellationCount == 0)
            withExtendedLifetime(coordinator) {}
        }

        #expect(preferences.cancellationCount == 1)
    }

    private func makeCoordinator(
        preferences: FeedbackPreferencesManaging,
        sound: GameplaySoundOutput,
        haptics: GameplayHapticOutput,
        clock: MonotonicClock
    ) -> DefaultGameplayFeedbackCoordinator {
        DefaultGameplayFeedbackCoordinator(
            preferences: preferences,
            soundOutput: sound,
            hapticOutput: haptics,
            clock: clock
        )
    }

    private var denseAutomaticEvents: [GameplayFeedbackEvent] {
        [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ]
    }
}

private final class AdjustableMonotonicClock: MonotonicClock {
    var now: TimeInterval

    init(now: TimeInterval) {
        self.now = now
    }
}

private final class ObservationCountingPreferencesManager: FeedbackPreferencesManaging {
    private(set) var current = FeedbackPreferences.defaultValue
    private(set) var observationCount = 0
    private(set) var cancellationCount = 0
    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]

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
        observationCount += 1
        observers[id] = observer
        observer(current)

        return ObservationCountingToken { [weak self] in
            guard let self,
                  observers.removeValue(forKey: id) != nil
            else {
                return
            }
            cancellationCount += 1
        }
    }

    private func commit(_ updated: FeedbackPreferences) {
        current = updated
        let callbacks = Array(observers.values)
        callbacks.forEach { $0(updated) }
    }
}

private final class ObservationCountingToken: FeedbackPreferencesObservation {
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
