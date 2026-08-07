//
//  GameplayFeedbackTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct GameplayFeedbackTests {
    @Test func noOpProviderAcceptsBothEntryPoints() {
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
