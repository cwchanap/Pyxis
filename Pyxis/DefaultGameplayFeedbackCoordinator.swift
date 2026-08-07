//
//  DefaultGameplayFeedbackCoordinator.swift
//  Pyxis
//

import Foundation

@MainActor
final class DefaultGameplayFeedbackCoordinator: GameplayFeedbackProviding {
    private let preferences: FeedbackPreferencesManaging
    private let soundOutput: GameplaySoundOutput
    private let hapticOutput: GameplayHapticOutput
    private let clock: MonotonicClock

    private var currentPreferences: FeedbackPreferences
    private var preferenceObservation: FeedbackPreferencesObservation?
    private var lastSoundAt: [GameplayFeedbackEvent: TimeInterval] = [:]
    private var lastHapticAt: [GameplayFeedbackEvent: TimeInterval] = [:]
    private var automaticCombatScheduler = AutomaticCombatFeedbackScheduler()

    init(
        preferences: FeedbackPreferencesManaging,
        soundOutput: GameplaySoundOutput,
        hapticOutput: GameplayHapticOutput,
        clock: MonotonicClock
    ) {
        self.preferences = preferences
        self.soundOutput = soundOutput
        self.hapticOutput = hapticOutput
        self.clock = clock
        currentPreferences = preferences.current
        preferenceObservation = nil
        preferenceObservation = preferences.observe { [weak self] updatedPreferences in
            self?.apply(updatedPreferences)
        }
    }

    deinit {
        MainActor.assumeIsolated { preferenceObservation?.cancel() }
    }

    func emit(_ event: GameplayFeedbackEvent) {
        switch event {
        case .manualDeployment:
            emitSound(.deployment, for: event, interval: 0.120)
            emitHaptic(.lightImpact, for: event, interval: 0.120)

        case .buildingChanged:
            emitSound(.construction, for: event, interval: 0.250)
            emitHaptic(.mediumImpact, for: event, interval: 0.250)

        case .invalidAction:
            emitSound(.blocked, for: event, interval: 0.500)
            emitHaptic(.warning, for: event, interval: 0.500)

        case .goldReward:
            emitSound(.goldReward)

        case .cityConquest:
            emitSound(.cityConquest)
            emitHaptic(.strongSuccess)

        case .countryCompletion:
            emitSound(.countryCompletion)
            emitHaptic(.strongSuccess)
        }
    }

    func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
        guard currentPreferences.soundEffectsEnabled,
              let sound = automaticCombatScheduler.selectSound(
                  from: result,
                  at: clock.now
              )
        else {
            return
        }

        soundOutput.play(sound)
    }

    private func apply(_ updatedPreferences: FeedbackPreferences) {
        let shouldDeactivateSound =
            currentPreferences.soundEffectsEnabled && !updatedPreferences.soundEffectsEnabled
        currentPreferences = updatedPreferences

        if shouldDeactivateSound {
            soundOutput.stopAllAndDeactivate()
        }
    }

    private func emitSound(
        _ sound: GameplaySoundID,
        for event: GameplayFeedbackEvent,
        interval: TimeInterval
    ) {
        guard currentPreferences.soundEffectsEnabled else {
            return
        }

        let now = clock.now
        if let lastOutputAt = lastSoundAt[event], now < lastOutputAt + interval {
            return
        }

        lastSoundAt[event] = now
        soundOutput.play(sound)
    }

    private func emitSound(_ sound: GameplaySoundID) {
        guard currentPreferences.soundEffectsEnabled else {
            return
        }

        soundOutput.play(sound)
    }

    private func emitHaptic(
        _ haptic: GameplayHapticKind,
        for event: GameplayFeedbackEvent,
        interval: TimeInterval
    ) {
        guard currentPreferences.hapticsEnabled else {
            return
        }

        let now = clock.now
        if let lastOutputAt = lastHapticAt[event], now < lastOutputAt + interval {
            return
        }

        lastHapticAt[event] = now
        hapticOutput.play(haptic)
    }

    private func emitHaptic(_ haptic: GameplayHapticKind) {
        guard currentPreferences.hapticsEnabled else {
            return
        }

        hapticOutput.play(haptic)
    }
}
