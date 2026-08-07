//
//  DefaultGameplayFeedbackCoordinatorTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
struct DefaultGameplayFeedbackCoordinatorTests {
    @Test func reachableDiscreteEventsEmitCurrentOutputs() {
        struct Case {
            let event: GameplayFeedbackEvent
            let sound: GameplaySoundID
            let haptic: GameplayHapticKind?
        }

        let cases: [Case] = [
            .init(event: .manualDeployment, sound: .deployment, haptic: .lightImpact),
            .init(event: .buildingChanged, sound: .construction, haptic: .mediumImpact),
            .init(event: .invalidAction, sound: .blocked, haptic: .warning),
            .init(event: .goldReward, sound: .goldReward, haptic: nil),
            .init(event: .cityConquest, sound: .cityConquest, haptic: .strongSuccess),
            .init(event: .countryCompletion, sound: .countryCompletion, haptic: .strongSuccess)
        ]

        for testCase in cases {
            let sound = RecordingGameplaySoundOutput()
            let haptics = RecordingGameplayHapticOutput()
            let coordinator = makeCoordinator(
                preferences: RecordingFeedbackPreferencesManager(),
                sound: sound,
                haptics: haptics,
                clock: AdjustableMonotonicClock(now: 0)
            )

            coordinator.emit(testCase.event)

            #expect(sound.calls == [.play(testCase.sound)])
            #expect(haptics.played == testCase.haptic.map { [$0] } ?? [])
        }
    }

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

        #expect(sound.calls == [.play(.deployment)])
        #expect(haptics.played.isEmpty)

        _ = preferences.setHapticsEnabled(true)
        clock.now = 0.001
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [.play(.deployment)])
        #expect(haptics.played == [.lightImpact])

        clock.now = 0.120
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [
            .play(.deployment),
            .play(.deployment)
        ])
        #expect(haptics.played == [.lightImpact])

        clock.now = 0.122
        coordinator.emit(.manualDeployment)

        #expect(sound.calls == [
            .play(.deployment),
            .play(.deployment)
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

        #expect(sound.calls == [.play(.blocked)])
        #expect(haptics.played == [.warning])

        clock.now = 0.500
        coordinator.emit(.invalidAction)

        #expect(sound.calls == [.play(.blocked)])
        #expect(haptics.played == [.warning, .warning])

        clock.now = 0.750
        coordinator.emit(.invalidAction)

        #expect(sound.calls == [
            .play(.blocked),
            .play(.blocked)
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
            .play(.construction),
            .play(.construction)
        ])
        #expect(haptics.played == [
            .mediumImpact,
            .mediumImpact
        ])
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
            .play(.goldReward),
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
            .play(.goldReward),
            .play(.cityConquest),
            .play(.countryCompletion),
            .play(.goldReward),
            .play(.cityConquest),
            .play(.countryCompletion)
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

        coordinator.emitAutomaticCombat(denseAutomaticResult())
        clock.now = 0.150
        coordinator.emitAutomaticCombat(denseAutomaticResult())
        clock.now = 0.300
        coordinator.emitAutomaticCombat(denseAutomaticResult())

        #expect(sound.calls == [
            .play(.soldierDeath),
            .play(.towerFire),
            .play(.attackSiege)
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

        coordinator.emitAutomaticCombat(denseAutomaticResult())
        _ = preferences.setSoundEffectsEnabled(true)
        coordinator.emitAutomaticCombat(denseAutomaticResult())

        #expect(sound.calls == [.play(.soldierDeath)])
        #expect(haptics.played.isEmpty)
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

    private func denseAutomaticResult() -> BattleCombatState.TickResult {
        var result = BattleCombatState.TickResult()
        result.soldierLosses = [
            SoldierLossEvent(
                soldierID: 90,
                type: .infantry,
                source: .manual,
                lane: .left
            )
        ]
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 90, damage: 3)
        ]
        result.soldierAttacks = [
            SoldierAttackEvent(
                soldierID: 1,
                type: .siege,
                source: .manual,
                lane: .left,
                appliedCityDamage: 2
            ),
            SoldierAttackEvent(
                soldierID: 2,
                type: .archer,
                source: .building,
                lane: .center,
                appliedCityDamage: 2
            ),
            SoldierAttackEvent(
                soldierID: 3,
                type: .infantry,
                source: .manual,
                lane: .right,
                appliedCityDamage: 2
            )
        ]
        result.damagedSoldierIDs = [90, 91]
        return result
    }
}

private final class AdjustableMonotonicClock: MonotonicClock {
    var now: TimeInterval

    init(now: TimeInterval) {
        self.now = now
    }
}
