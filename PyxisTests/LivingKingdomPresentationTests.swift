//
//  LivingKingdomPresentationTests.swift
//  PyxisTests
//

import Testing
import UIKit
@testable import Pyxis

@Suite("Living Kingdom presentation")
struct LivingKingdomPresentationTests {
    @Test(arguments: [
        (13, LivingKingdomPresentation.FortressStage.intact),
        (12, .damaged),
        (6, .damaged),
        (5, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func cityOneUsesExactBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let maximum = KingdomGameState.cityMaxPower(for: 1)
        #expect(maximum == 20)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: remaining,
            maxHP: maximum,
            hasPendingConquest: false
        ).stage == expected)
    }

    @Test(arguments: [
        (35, LivingKingdomPresentation.FortressStage.intact),
        (22, .intact),
        (21, .damaged),
        (9, .damaged),
        (8, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func cityThreeUsesKeepMaxThirtyFiveBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 35)
        let maximum = state.currentKeepMaxPower
        #expect(maximum == 35)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: remaining,
            maxHP: maximum,
            hasPendingConquest: false
        ).stage == expected)
    }

    @Test func freshFalconridgeKeepProjectsIntactThirtyFiveOfThirtyFive() {
        let state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 35)

        #expect(state.currentKeepMaxPower == 35)
        #expect(state.currentKeepRemainingPower == 35)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: false
        ).stage == .intact)
    }

    @Test func falconridgeSupportObjectiveDamageDoesNotChangeFortressStage() {
        // Gate (11) and Tower (46) fully destroyed; the Keep stays untouched.
        let state = SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 35,
            supportDamage: [.gate: 11, .arrowTower: 46]
        )

        #expect(state.currentKeepRemainingPower == 35)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: false
        ).stage == .intact)
    }

    @Test func nonPilotSingleKeepCitiesKeepMaxEqualsTotalCityPower() {
        for city in Country1CityCatalog.cityRange where city != 3 {
            let state = SiegeTestSupport.makeBattleState(
                atCity: city,
                keepRemaining: KingdomGameState.cityMaxPower(for: city)
            )

            #expect(state.currentKeepMaxPower == state.cityMaxPower)
            #expect(state.currentKeepRemainingPower == state.cityMaxPower)
        }
    }

    @Test func pendingConquestProjectsConqueredStageEvenWithPositiveHP() {
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: KingdomGameState.cityMaxPower(for: 1),
            maxHP: KingdomGameState.cityMaxPower(for: 1),
            hasPendingConquest: true
        ).stage == .conquered)
    }

    @Test func projectedFamilyMatchesAuthoredCatalogFamily() {
        for city in Country1CityCatalog.cityRange {
            let family = Country1CityCatalog.definition(for: city).visualFamily
            #expect(LivingKingdomPresentation.battle(
                cityNumber: city,
                remainingHP: 1,
                maxHP: 1,
                hasPendingConquest: false
            ).family == family)
        }

        #expect(Country1CityCatalog.definition(for: 11).visualFamily == .frontier)
    }

    @Test func everyFortressAssetResolves() {
        for family in CityVisualFamily.allCases {
            for stage in LivingKingdomPresentation.FortressStage.allCases {
                let battle = LivingKingdomPresentation.Battle(family: family, stage: stage)
                #expect(
                    UIImage(named: battle.fortressAssetName) != nil,
                    "Missing fortress asset: \(battle.fortressAssetName)"
                )
            }
        }
    }

    @Test func frontierHasNoBattlefieldTreatmentAndThemedTreatmentsResolve() {
        for family in CityVisualFamily.allCases {
            let battle = LivingKingdomPresentation.Battle(family: family, stage: .intact)
            if family == .frontier {
                #expect(battle.battlefieldTreatmentAssetName == nil)
            } else {
                let treatment = battle.battlefieldTreatmentAssetName
                #expect(treatment != nil)
                #expect(
                    treatment.flatMap { UIImage(named: $0) } != nil,
                    "Missing battlefield treatment asset: \(treatment ?? "nil")"
                )
            }
        }
    }

    @Test func fxMetadataIsLockedAndAssetsResolve() {
        #expect(LivingKingdomPresentation.TransitionEffect.breach.frameNames == [
            "lk-fx-breach-01", "lk-fx-breach-02", "lk-fx-breach-03",
            "lk-fx-breach-04", "lk-fx-breach-05", "lk-fx-breach-06"
        ])
        #expect(LivingKingdomPresentation.TransitionEffect.breach.secondsPerFrame == 0.05)
        #expect(LivingKingdomPresentation.TransitionEffect.collapse.frameNames == [
            "lk-fx-collapse-01", "lk-fx-collapse-02", "lk-fx-collapse-03",
            "lk-fx-collapse-04", "lk-fx-collapse-05", "lk-fx-collapse-06"
        ])
        #expect(LivingKingdomPresentation.TransitionEffect.collapse.secondsPerFrame == 0.07)

        let allFrameNames = LivingKingdomPresentation.TransitionEffect.breach.frameNames
            + LivingKingdomPresentation.TransitionEffect.collapse.frameNames
        for name in allFrameNames {
            #expect(UIImage(named: name) != nil, "Missing FX asset: \(name)")
        }
    }

    @Test func skippedStagesProduceNoTransitionEffect() {
        #expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .damaged) == nil)
        #expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .breached) == .breach)
        #expect(LivingKingdomPresentation.transitionEffect(from: .damaged, to: .breached) == .breach)
        #expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .conquered) == .collapse)
        #expect(LivingKingdomPresentation.transitionEffect(from: .breached, to: .conquered) == .collapse)
        #expect(LivingKingdomPresentation.transitionEffect(from: .conquered, to: .conquered) == nil)
    }

    @Test func mapProjectionClampsAndSequencesCaravans() {
        #expect(LivingKingdomPresentation.map(completedCityCount: -3).securedCityNumbers == [])
        #expect(LivingKingdomPresentation.map(completedCityCount: 1).caravanSegmentStartCityNumbers == [])
        #expect(LivingKingdomPresentation.map(completedCityCount: 2).caravanSegmentStartCityNumbers == [1])
        #expect(LivingKingdomPresentation.map(completedCityCount: 4).caravanSegmentStartCityNumbers == [1, 2])
        #expect(LivingKingdomPresentation.map(completedCityCount: 99).securedCityNumbers == Array(1...15))
        #expect(LivingKingdomPresentation.map(completedCityCount: 99).caravanSegmentStartCityNumbers == [1, 2])
        #expect(
            LivingKingdomPresentation.map(completedCityCount: 6).routeSixToSevenAssetName
                == "lk-map-route-6-7-worn"
        )
        #expect(
            LivingKingdomPresentation.map(completedCityCount: 7).routeSixToSevenAssetName
                == "lk-map-route-6-7-repaired"
        )
    }
}
