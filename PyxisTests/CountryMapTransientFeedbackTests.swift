//
//  CountryMapTransientFeedbackTests.swift
//  PyxisTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Pyxis

@MainActor
struct CountryMapTransientFeedbackTests {
    @Test func lockedAndCompletedUseExactCopyAndShortDuration() {
        let locked = CountryMapTransientFeedback.locked(cityNumber: 7)
        let completed = CountryMapTransientFeedback.completed(cityNumber: 12)

        #expect(locked.kind == .locked)
        #expect(locked.text == "Emberford is locked")
        #expect(locked.totalDuration == 1.5)
        #expect(locked.fadeDuration == 0.3)

        #expect(completed.kind == .completed)
        #expect(completed.text == "Ashbridge complete")
        #expect(completed.totalDuration == 1.5)
        #expect(completed.fadeDuration == 0.3)
    }

    @Test func flavorIsNonBlockingAndUsesLongDuration() {
        let flavor = CountryMapTransientFeedback.flavor("Stone walls seal the mountain road ahead.")

        #expect(flavor.kind == .flavor)
        #expect(flavor.text == "Stone walls seal the mountain road ahead.")
        #expect(flavor.totalDuration == 2.5)
        #expect(flavor.fadeDuration == 0.3)
    }

    @Test func onlyFlavorDoesNotBlockScoutEntry() {
        #expect(CountryMapTransientFeedback.Kind.flavor.blocksScoutEntry == false)
        #expect(CountryMapTransientFeedback.Kind.locked.blocksScoutEntry == true)
        #expect(CountryMapTransientFeedback.Kind.completed.blocksScoutEntry == true)
        #expect(CountryMapTransientFeedback.Kind.status.blocksScoutEntry == true)
        #expect(CountryMapTransientFeedback.Kind.recoverableError.blocksScoutEntry == true)

        #expect(CountryMapTransientFeedback.flavor("any").kind.blocksScoutEntry == false)
        #expect(CountryMapTransientFeedback.locked(cityNumber: 1).kind.blocksScoutEntry == true)
    }

    @Test func statusAndRecoverableErrorsUseLongDuration() {
        let status = CountryMapTransientFeedback.status("Status")
        let error = CountryMapTransientFeedback.cannotEnterCityYet()

        #expect(status.kind == .status)
        #expect(status.text == "Status")
        #expect(status.totalDuration == 2.5)
        #expect(status.fadeDuration == 0.3)

        #expect(error.kind == .recoverableError)
        #expect(error.text == "Cannot enter city yet.")
        #expect(error.totalDuration == 2.5)
        #expect(error.fadeDuration == 0.3)
    }

    @Test func idleProjectsExistingStatusCopy() throws {
        let pendingState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        )
        let countryCompleteState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )

        #expect(CountryMapTransientFeedback.idle(
            result: .init(elapsedSeconds: 0, damageDealt: 0, conqueredCities: 0, goldEarned: 0),
            state: pendingState
        ) == nil)
        #expect(CountryMapTransientFeedback.idle(
            result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 0, goldEarned: 0),
            state: pendingState
        )?.text == "Buildings dealt 9 idle damage.")
        #expect(CountryMapTransientFeedback.idle(
            result: .init(elapsedSeconds: 10, damageDealt: 0, conqueredCities: 0, goldEarned: 0),
            state: pendingState
        )?.text == "No building damage while away.")
        #expect(CountryMapTransientFeedback.idle(
            result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 1, goldEarned: 4),
            state: pendingState
        )?.text == "Next: Bramblegate")
        #expect(CountryMapTransientFeedback.idle(
            result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 1, goldEarned: 4),
            state: countryCompleteState
        )?.text == "Country 1 conquered at Crownspire Keep.")
    }

    @Test func alphaIsOpaqueUntilTheFinalFadeWindowThenFallsLinearly() {
        var feedback = CountryMapTransientFeedback.locked(cityNumber: 3)

        feedback.advance(by: 1.2)
        #expect(feedback.alpha == 1)

        feedback.advance(by: 0.15)
        #expect(abs(feedback.alpha - 0.5) < 0.001)
        #expect(!feedback.isFinished)

        var exactBoundary = CountryMapTransientFeedback.locked(cityNumber: 3)
        exactBoundary.advance(by: 1.5)
        #expect(exactBoundary.alpha == 0)
        #expect(exactBoundary.isFinished)
        #expect(exactBoundary.elapsed == 1.5)
    }

    @Test func advancementNeverRewindsAndClampsLargeDeltasAtFinished() {
        var feedback = CountryMapTransientFeedback.status("Status")

        feedback.advance(by: 1)
        feedback.advance(by: -4)
        #expect(feedback.elapsed == 1)

        feedback.advance(by: 100)
        #expect(feedback.elapsed == 2.5)
        #expect(feedback.alpha == 0)
        #expect(feedback.isFinished)
    }
}
