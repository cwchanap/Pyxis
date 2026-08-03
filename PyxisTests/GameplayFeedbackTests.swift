//
//  GameplayFeedbackTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct GameplayFeedbackTests {
    @Test func everySemanticEventAndPayloadIsConstructibleAndEquatable() {
        let events: [GameplayFeedbackEvent] = [
            .manualDeployment,
            .soldierAttack(.melee),
            .soldierAttack(.ranged),
            .soldierAttack(.siege),
            .towerFire,
            .soldierDamage(.hit),
            .soldierDamage(.death),
            .buildingChanged,
            .invalidAction,
            .goldReward,
            .cityConquest,
            .countryCompletion,
            .fortifiedLaneWarning
        ]

        #expect(events.count == 13)
        #expect(events[0] == .manualDeployment)
        #expect(events[1] == .soldierAttack(.melee))
        #expect(events[6] == .soldierDamage(.death))
        #expect(events[12] == .fortifiedLaneWarning)
    }

    @Test func attackAllCasesIsACompleteSetWithoutOrderSemantics() {
        let categories = SoldierAttackSoundCategory.allCases

        #expect(categories.count == 3)
        #expect(categories.contains(.melee))
        #expect(categories.contains(.ranged))
        #expect(categories.contains(.siege))
    }

    @Test func recorderKeepsDiscreteAndAutomaticCallsDistinctAndOrdered() {
        let recorder = RecordingGameplayFeedbackProvider()
        let automatic: [GameplayFeedbackEvent] = [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ]

        recorder.emit(.manualDeployment)
        recorder.emitAutomaticCombat(automatic)
        recorder.emitAutomaticCombat([])

        #expect(recorder.calls == [
            .discrete(.manualDeployment),
            .automatic(automatic),
            .automatic([])
        ])
    }

    @Test func noOpProviderAcceptsEveryEntryPoint() {
        let provider = NoOpGameplayFeedbackProvider()

        provider.emit(.countryCompletion)
        provider.emitAutomaticCombat([
            .towerFire,
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ])
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
        case automatic([GameplayFeedbackEvent])
    }

    private(set) var calls: [Call] = []

    func emit(_ event: GameplayFeedbackEvent) {
        calls.append(.discrete(event))
    }

    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {
        calls.append(.automatic(orderedEvents))
    }
}

private struct ManualMonotonicClock: MonotonicClock {
    var now: TimeInterval
}
