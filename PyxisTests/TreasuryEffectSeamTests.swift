//
//  TreasuryEffectSeamTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// HPA-670 Task 2: each Treasury effect has exactly one calculation seam.
/// War Chest gold quotes only through `goldReward(forCity:)`, Drill Yard
/// attack only through the single-round `traitAdjustedSoldierAttackPower`
/// fold, Quartermaster prices only through the state-aware `building*Cost`
/// pair. Zero-Treasury results must equal the base formulas exactly.
struct TreasuryEffectSeamTests {
    // MARK: - War Chest (gold seam)

    @Test("War Chest quote rounds once for the current and a scouted city")
    func warChestQuoteRoundsOnce() {
        var state = KingdomGameState()
        state.treasury.warChest = 3

        // Base curve pins: city 1 → 8, city 5 → round(8 × 1.45⁴) = 35.
        #expect(KingdomGameState.baseGoldReward(for: 1) == 8)
        #expect(KingdomGameState.baseGoldReward(for: 5) == 35)

        // Scouted different city: 35 × 1.30 = 45.5 → 46 in ONE round
        // (truncation or double rounding would give 45).
        #expect(state.goldReward(forCity: 5) == 46)

        // Current-city quote: 8 × 1.30 = 10.4 → 10.
        #expect(state.goldReward(forCity: state.cityLevel) == 10)
        #expect(state.currentGoldReward == state.goldReward(forCity: state.cityLevel))
        // Delegation really goes through the adjusted seam, not the base curve.
        #expect(state.currentGoldReward != KingdomGameState.baseGoldReward(for: state.cityLevel))
    }

    @Test("Zero War Chest quote equals the base curve exactly")
    func zeroWarChestQuoteEqualsBase() {
        let state = KingdomGameState()
        for city in Country1CityCatalog.cityRange {
            #expect(state.goldReward(forCity: city) == KingdomGameState.baseGoldReward(for: city))
        }
        #expect(state.currentGoldReward == KingdomGameState.baseGoldReward(for: state.cityLevel))
    }

    @Test("Conquest awards the adjusted quote exactly once")
    func conquestAwardsAdjustedQuote() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 3, gold: 5, keepRemaining: 26)
        state.treasury.warChest = 2

        let quote = state.goldReward(forCity: 3)
        #expect(quote == 20) // base 17 × 1.20 = 20.4 → 20

        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        #expect(state.applyObjectiveDamage(26, toObjectiveID: keepID) == 26)

        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.gold == 5 + quote)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.goldEarned == quote)

        // Exactly once: post-conquest damage awards nothing further.
        #expect(state.applyObjectiveDamage(26, toObjectiveID: keepID) == 0)
        #expect(state.gold == 5 + quote)
    }

    // MARK: - Drill Yard (attack seam)

    @Test("Drill Yard folds the upgrade multiplier into the single round")
    func drillYardSingleRoundPin() {
        // Spec illustration: 9 × 0.80 × 1.05 = 7.56 → 8 in one round;
        // rounding the trait first loses the point (round(7.2)=7 → 7).
        let singleRound = Int((9.0 * 0.80 * 1.05).rounded())
        let doubleRound = Int((Double(Int((9.0 * 0.80).rounded())) * 1.05).rounded())
        #expect(singleRound == 8)
        #expect(doubleRound == 7)

        // The same divergence through the real seam at the nearest reachable
        // base (the 1.38ˣ ceiling curve never yields 9): mage level 4 → base
        // 3, arrowTower mage disadvantage 0.80 → round(2.52) = 3, where a
        // double round would keep 2.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, upgradeMultiplier: 1.05
        ) == 3)
        // The pre-HPA-670 call (default multiplier) is unchanged:
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower
        ) == 2)
    }

    @Test("Drill Yard matrix matches the single-round formula across reachable levels")
    func drillYardVisibilityMatrix() {
        for level in 1...8 {
            let base = KingdomGameState.normalSoldierAttackPower(for: level)
            for soldierType in SoldierType.allCases {
                for trait in CityDefenseTrait.allCases {
                    let traitMultiplier = trait.damageMultiplier(for: soldierType)
                    for drillYard in 0...10 {
                        let upgradeMultiplier = 1.0 + 0.05 * Double(drillYard)
                        let expected = max(1, Int(
                            (Double(base) * traitMultiplier * upgradeMultiplier).rounded()
                        ))
                        #expect(
                            KingdomGameState.traitAdjustedSoldierAttackPower(
                                for: soldierType,
                                level: level,
                                defenseTrait: trait,
                                upgradeMultiplier: upgradeMultiplier
                            ) == expected,
                            "level \(level), \(soldierType), \(trait), DY \(drillYard)"
                        )
                    }
                }
            }
        }
    }

    @Test("Drill Yard purchases have pinned zero and nonzero visible deltas")
    func drillYardVisibilityPins() {
        // Level 1 (base 1) neutral trait: no visible gain until DY 10.
        for drillYard in 0...9 {
            #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                upgradeMultiplier: 1.0 + 0.05 * Double(drillYard)
            ) == 1)
        }
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 1, defenseTrait: .standardWatch, upgradeMultiplier: 1.5
        ) == 2)

        // Level 2 (base 2) neutral: no visible gain through DY 4; the first
        // visible gain is at DY 5 (2 × 1.25 = 2.5 rounds away from zero).
        for drillYard in 0...4 {
            #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                upgradeMultiplier: 1.0 + 0.05 * Double(drillYard)
            ) == 2)
        }
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 2, defenseTrait: .standardWatch, upgradeMultiplier: 1.25
        ) == 3)

        // Level 4 (base 3) disadvantaged 0.80: visible from the first level.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, upgradeMultiplier: 1.0
        ) == 2)
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, upgradeMultiplier: 1.05
        ) == 3)
    }

    @Test("Instance attack power applies the Drill Yard level on the current trait")
    func drillYardInstanceWrapper() {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 20)
        state.treasury.drillYard = 4

        let expected = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry,
            level: 2,
            defenseTrait: state.currentCityDefenseTrait,
            upgradeMultiplier: 1.2
        )
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 2) == expected)
        // City 1 is Standard Watch: base 2 × 1.0 × 1.2 = 2.4 → 2 — a paid
        // level with no visible gain yet, exactly the "no damage change yet"
        // case the Kingdom row must surface.
        #expect(expected == 2)
    }

    @Test("Idle settlement consumes the Drill Yard adjusted power")
    func idleSettlementUsesDrillYardPower() {
        func singleSpawnIdleDamage(drillYard: Int) -> KingdomGameState.IdleProgressResult {
            var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            state.treasury.drillYard = drillYard

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            return state.returnFromBackground(at: start.addingTimeInterval(150))
        }

        // One level-1 infantry spawn (150 s idle → 15 s active-equivalent →
        // one 10 s barracks interval). City 1 is Standard Watch, so the only
        // difference is the Drill Yard fold.
        let baseline = singleSpawnIdleDamage(drillYard: 0)
        let drilled = singleSpawnIdleDamage(drillYard: 10)

        #expect(baseline.conqueredCities == 0)
        #expect(baseline.damageDealt == 1) // round(1 × 1.0) = 1
        #expect(drilled.conqueredCities == 0)
        #expect(drilled.damageDealt == 2) // round(1 × 1.5) = 2
    }

    // MARK: - Quartermaster (cost seam)

    @Test("Quartermaster discounts quotes with a single rounding")
    func quartermasterQuoteRoundsOnce() {
        var state = KingdomGameState()
        state.treasury.quartermaster = 4

        // Base pins under the renamed internal helpers.
        #expect(KingdomGameState.baseBuildingBuildCost(for: .mageTower) == 40)
        #expect(KingdomGameState.baseBuildingUpgradeCost(for: .stable, currentLevel: 1) == 22)

        // 40 × 0.84 = 33.6 → 34 in one round (truncation would give 33).
        #expect(state.buildingBuildCost(for: .mageTower) == 34)
        // 22 × 0.84 = 18.48 → 18.
        #expect(state.buildingUpgradeCost(for: .stable, currentLevel: 1) == 18)

        var midState = KingdomGameState()
        midState.treasury.quartermaster = 5
        #expect(midState.buildingBuildCost(for: .barracks) == 12) // 15 × 0.80

        var maxedState = KingdomGameState()
        maxedState.treasury.quartermaster = TreasuryUpgrade.quartermaster.maxLevel
        #expect(maxedState.buildingUpgradeCost(for: .siegeWorkshop, currentLevel: 1) == 35) // 42 × 0.84

        // Zero Quartermaster equals the base curves exactly.
        let fresh = KingdomGameState()
        for type in BuildingType.allCases {
            #expect(fresh.buildingBuildCost(for: type) == KingdomGameState.baseBuildingBuildCost(for: type))
            #expect(
                fresh.buildingUpgradeCost(for: type, currentLevel: 3)
                    == KingdomGameState.baseBuildingUpgradeCost(for: type, currentLevel: 3)
            )
        }
    }

    @Test("Camp display, recommendation, buyer, affordability and debit share one discounted quote")
    func campQuoteChargeParityUnderQuartermaster() throws {
        var state = KingdomGameState(gold: 100, cityNumberInCountry: 5, completedCityCount: 4)
        state.treasury.quartermaster = 3 // × 0.88

        let buildQuote = state.buildingBuildCost(for: .barracks)
        #expect(buildQuote == 13) // 15 × 0.88 = 13.2 → 13

        // Camp selection displays the discounted price.
        let content = CampSelectionContent.project(from: state, selectedSlot: nil)
        let barracksOption = try #require(content.options.first { $0.buildingType == .barracks })
        guard case .available(let displayedCost) = barracksOption.state else {
            Issue.record("expected an available barracks option, got \(barracksOption.state)")
            return
        }
        #expect(displayedCost == buildQuote)

        // The recommendation quotes the same price.
        guard case .ready(let recommendation, _) = RecommendedCampRecommendation.make(for: state) else {
            Issue.record("expected a ready recommendation")
            return
        }
        #expect(recommendation.cost == buildQuote)

        // The balance-harness buyer candidate quotes the same price.
        let buyerAction = try #require(GreedyCampBuyer.nextAction(for: state))
        #expect(buyerAction.cost == buildQuote)

        // The actual debit equals the quote.
        guard case .built(let debited, let remainingGold) = state.buildBuilding(.barracks, inSlot: 1) else {
            Issue.record("expected the barracks build to succeed")
            return
        }
        #expect(debited == buildQuote)
        #expect(remainingGold == 100 - buildQuote)
        #expect(state.gold == remainingGold)

        // Upgrade path: same parity for the inspector, recommendation, buyer and debit.
        let upgradeQuote = state.buildingUpgradeCost(for: .barracks, currentLevel: 1)
        #expect(upgradeQuote == 11) // 12 × 0.88 = 10.56 → 11

        let selected = CampSelectionContent.project(from: state, selectedSlot: 1)
        #expect(selected.inspector?.upgradeCost == upgradeQuote)
        guard case .ready(let upgradeRecommendation, _) = RecommendedCampRecommendation.make(for: state) else {
            Issue.record("expected a ready upgrade recommendation")
            return
        }
        #expect(upgradeRecommendation.kind == .upgrade)
        #expect(upgradeRecommendation.cost == upgradeQuote)
        let upgradeBuyerAction = try #require(GreedyCampBuyer.nextAction(for: state))
        #expect(upgradeBuyerAction.kind == .upgrade)
        #expect(upgradeBuyerAction.cost == upgradeQuote)

        guard case .upgraded(let upgradeDebit, _, let upgradeRemaining) = state.upgradeBuilding(inSlot: 1) else {
            Issue.record("expected the upgrade to succeed")
            return
        }
        #expect(upgradeDebit == upgradeQuote)
        #expect(state.gold == 100 - buildQuote - upgradeQuote)
        #expect(upgradeRemaining == state.gold)
    }
}
