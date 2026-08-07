//
//  GameplayFeedbackTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct GameplayFeedbackTests {
    @Test func everyDiscreteSemanticEventIsConstructibleAndEquatable() {
        let events: [GameplayFeedbackEvent] = [
            .manualDeployment,
            .buildingChanged,
            .invalidAction,
            .goldReward,
            .cityConquest,
            .countryCompletion
        ]

        #expect(events.count == 6)
        #expect(events[0] == .manualDeployment)
        #expect(events[5] == .countryCompletion)
    }

    @Test func recorderKeepsDiscreteAndAutomaticCallsDistinctAndOrdered() {
        let recorder = RecordingGameplayFeedbackProvider()
        let automatic = BattleCombatState.TickResult()

        recorder.emit(.manualDeployment)
        recorder.emitAutomaticCombat(automatic)
        recorder.emitAutomaticCombat(BattleCombatState.TickResult())

        #expect(recorder.calls == [
            .discrete(.manualDeployment),
            .automatic,
            .automatic
        ])
    }

    @Test func noOpProviderAcceptsEveryEntryPoint() {
        let provider = NoOpGameplayFeedbackProvider()

        provider.emit(.countryCompletion)
        provider.emitAutomaticCombat(BattleCombatState.TickResult())
    }

    @Test func manualClockAdvancesWithoutSleeping() {
        var clock = ManualMonotonicClock(now: 1.25)

        #expect(clock.now == 1.25)
        clock.now = 9.5
        #expect(clock.now == 9.5)
    }
}

private final class RecordingGameplayFeedbackProvider: GameplayFeedbackProviding {
    enum Call: Equatable {
        case discrete(GameplayFeedbackEvent)
        case automatic
    }

    private(set) var calls: [Call] = []

    func emit(_ event: GameplayFeedbackEvent) {
        calls.append(.discrete(event))
    }

    func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
        calls.append(.automatic)
    }
}
