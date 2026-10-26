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
        (10, LivingKingdomPresentation.FortressStage.intact),
        (9, .damaged),
        (4, .damaged),
        (3, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func cityOneUsesExactBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        // City 1's Keep holds its 3:1 share of the 20-HP budget; the Gate holds the rest.
        let state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: remaining)
        let layout = state.currentSiegeLayout
        let allocatedKeepMax = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)[layout.keepObjective.id]
        #expect(allocatedKeepMax == 15)
        #expect(state.currentKeepMaxPower == allocatedKeepMax)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: false
        ).stage == expected)
    }

    // City 3's budget under 1.85 growth is 68 (round(20 * 1.85^2)); its Keep's
    // floored 3/8 share plus the allocation remainder gives a 26-HP Keep-max.
    // Stage edges use the integer policy: intact while remaining*5 > max*3,
    // damaged while remaining*4 > max.
    @Test(arguments: [
        (26, LivingKingdomPresentation.FortressStage.intact),
        (16, .intact),
        (15, .damaged),
        (7, .damaged),
        (6, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func cityThreeUsesKeepMaxTwentySixBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 26)
        let maximum = state.currentKeepMaxPower
        #expect(maximum == 26)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: remaining,
            maxHP: maximum,
            hasPendingConquest: false
        ).stage == expected)
    }

    @Test func freshFalconridgeKeepProjectsIntactTwentySixOfTwentySix() {
        let state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 26)

        #expect(state.currentKeepMaxPower == 26)
        #expect(state.currentKeepRemainingPower == 26)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: false
        ).stage == .intact)
    }

    @Test func falconridgeSupportObjectiveDamageDoesNotChangeFortressStage() {
        // Gate (8) and Tower (34) fully destroyed; the Keep stays untouched.
        let state = SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 26,
            supportDamage: [.gate: 8, .arrowTower: 34]
        )

        #expect(state.currentKeepRemainingPower == 26)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: state.currentKeepRemainingPower,
            maxHP: state.currentKeepMaxPower,
            hasPendingConquest: false
        ).stage == .intact)
    }

    @Test func singleKeepFixtureHoldsTheWholeBudgetOnItsKeep() {
        // Model-level: the single-Keep fixture gives its Keep the whole city budget. No catalog
        // city uses that shape now, so the budget split is pinned on the value itself.
        let layout = CitySiegeLayout.singleKeep(defaultLane: .center)
        let budget = KingdomGameState.cityMaxPower(for: 1)

        #expect(layout.maxPowerAllocation(totalBudget: budget) == [layout.keepObjective.id: budget])
    }

    @Test func keepOnlyLaneSplitsTheCityBudgetAcrossItsAuthoredObjectives() {
        // Real catalog check: City 1's .right route is the Keep alone. The Keep holds only its
        // authored share, and the Gate holds the rest of the city budget.
        let state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: KingdomGameState.cityMaxPower(for: 1),
            selectedLane: .right
        )
        let layout = state.currentSiegeLayout

        #expect(layout.routes[.right] == [layout.keepObjective.id])
        #expect(state.currentKeepMaxPower < state.cityMaxPower)
        #expect(SiegeTestSupport.totalObjectiveRemainingPower(of: state) == state.cityMaxPower)
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)
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
