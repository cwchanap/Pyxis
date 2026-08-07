//
//  FeedbackPreferencesTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

@MainActor
struct FeedbackPreferencesTests {
    @Test func defaultsEnableBothChannels() {
        #expect(FeedbackPreferences() == FeedbackPreferences(
            soundEffectsEnabled: true,
            hapticsEnabled: true
        ))
        #expect(FeedbackPreferences.defaultValue == FeedbackPreferences())
    }

    @Test func systemMonotonicClockReadsAreNonnegativeAndNondecreasing() {
        let clock = SystemMonotonicClock()
        let firstRead = clock.now
        let secondRead = clock.now

        #expect(firstRead >= 0)
        #expect(secondRead >= firstRead)
    }
}
