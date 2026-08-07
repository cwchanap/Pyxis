//
//  DefaultGameplayFeedbackCoordinator.swift
//  Pyxis
//

import Foundation

final class DefaultGameplayFeedbackCoordinator: GameplayFeedbackProviding {
    private let preferences: FeedbackPreferencesManaging
    private let soundOutput: GameplaySoundOutput
    private let hapticOutput: GameplayHapticOutput
    private let clock: MonotonicClock

    private var currentPreferences: FeedbackPreferences
    private var preferenceObservation: FeedbackPreferencesObservation?
    private var lastDiscreteOutputAt: [GameplayGateID: TimeInterval] = [:]
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
        preferenceObservation?.cancel()
    }

    func emit(_ event: GameplayFeedbackEvent) {
        let directive = GameplayFeedbackPolicy.directive(for: event)

        if let sound = directive.sound,
           let soundClass = directive.soundClass {
            emitSound(sound, soundClass: soundClass, gate: directive.soundGate)
        }

        if let haptic = directive.haptic {
            emitHaptic(haptic, gate: directive.hapticGate)
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

        soundOutput.play(sound, soundClass: .automaticCombat)
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
        soundClass: GameplaySoundClass,
        gate: GameplayGateID?
    ) {
        guard currentPreferences.soundEffectsEnabled else {
            return
        }

        if let gate {
            let now = clock.now
            guard isGateOpen(gate, at: now) else {
                return
            }
            lastDiscreteOutputAt[gate] = now
        }

        soundOutput.play(sound, soundClass: soundClass)
    }

    private func emitHaptic(_ haptic: GameplayHapticKind, gate: GameplayGateID?) {
        guard currentPreferences.hapticsEnabled else {
            return
        }

        if let gate {
            let now = clock.now
            guard isGateOpen(gate, at: now) else {
                return
            }
            lastDiscreteOutputAt[gate] = now
        }

        hapticOutput.play(haptic)
    }

    private func isGateOpen(_ gate: GameplayGateID, at now: TimeInterval) -> Bool {
        guard let lastOutputAt = lastDiscreteOutputAt[gate] else {
            return true
        }
        return now >= lastOutputAt + Self.interval(for: gate)
    }

    private static func interval(for gate: GameplayGateID) -> TimeInterval {
        switch gate {
        case .deploymentSound, .deploymentHaptic:
            0.120
        case .constructionSound, .constructionHaptic:
            0.250
        case .invalidSound, .invalidHaptic:
            0.500
        case .fortifiedWarningSound:
            0.750
        }
    }
}
