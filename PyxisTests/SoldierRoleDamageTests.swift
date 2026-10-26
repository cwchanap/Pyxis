//
//  SoldierRoleDamageTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// Pure role-table tests for `SoldierType.objectiveDamageMultiplier(against:)`
/// (HPA-582 Decision 2). Pins the full 5×4 soldier/objective table, the
/// trait×role product, and the explicit two-step rounding contract: the
/// trait-adjusted integer attack power is preserved, and the role multiplier
/// is applied and rounded again per structure hit.
struct SoldierRoleDamageTests {
    private func role(_ soldier: SoldierType, _ kind: CitySiegeLayout.ObjectiveKind) -> Double {
        soldier.objectiveDamageMultiplier(against: kind)
    }

    // MARK: - Full 5×4 role table

    @Test func siegeDoublesGateAndKeepOnly() {
        #expect(role(.siege, .gate) == 2.0)
        #expect(role(.siege, .keep) == 2.0)
        #expect(role(.siege, .arrowTower) == 1.0)
        #expect(role(.siege, .barracks) == 1.0)
    }

    @Test func archerBoostsArrowTowerOnly() {
        #expect(role(.archer, .arrowTower) == 1.5)
        #expect(role(.archer, .gate) == 1.0)
        #expect(role(.archer, .keep) == 1.0)
        #expect(role(.archer, .barracks) == 1.0)
    }

    @Test func mageBoostsBarracksOnly() {
        #expect(role(.mage, .barracks) == 1.5)
        #expect(role(.mage, .gate) == 1.0)
        #expect(role(.mage, .keep) == 1.0)
        #expect(role(.mage, .arrowTower) == 1.0)
    }

    @Test func infantryAndCavalryAreNeutralAgainstEveryObjective() {
        for kind in [CitySiegeLayout.ObjectiveKind.keep, .gate, .arrowTower, .barracks] {
            #expect(role(.infantry, kind) == 1.0)
            #expect(role(.cavalry, kind) == 1.0)
        }
    }

    @Test func roleTableCoversAllFiveSoldierTypesAgainstAllFourObjectives() {
        let expected: [SoldierType: [CitySiegeLayout.ObjectiveKind: Double]] = [
            .infantry: [.keep: 1.0, .gate: 1.0, .arrowTower: 1.0, .barracks: 1.0],
            .archer: [.keep: 1.0, .gate: 1.0, .arrowTower: 1.5, .barracks: 1.0],
            .cavalry: [.keep: 1.0, .gate: 1.0, .arrowTower: 1.0, .barracks: 1.0],
            .mage: [.keep: 1.0, .gate: 1.0, .arrowTower: 1.0, .barracks: 1.5],
            .siege: [.keep: 2.0, .gate: 2.0, .arrowTower: 1.0, .barracks: 1.0]
        ]
        for (soldierType, kinds) in expected {
            for (kind, multiplier) in kinds {
                #expect(soldierType.objectiveDamageMultiplier(against: kind) == multiplier)
            }
        }
    }

    // MARK: - Trait×role product examples

    @Test func falconridgeArcherVersusTowerIsAdvantageousNotPenalized() {
        // The concrete misleading-copy case: Falconridge's arrowTower trait
        // penalizes archers (×0.80), but the archer's tower role (×1.5)
        // yields a net advantage of ×1.20 — a trait-only ×0.80 pill lies.
        let product = CityDefenseTrait.arrowTower.damageMultiplier(for: .archer)
            * role(.archer, .arrowTower)
        #expect(abs(product - 1.2) < 0.0001)
        #expect(product > 1)
    }

    @Test func kingshieldSiegeVersusGateStacksFavorableTraitWithRole() {
        let product = CityDefenseTrait.reinforcedKeep.damageMultiplier(for: .siege)
            * role(.siege, .gate)
        #expect(product == 2.50)
    }

    @Test func mageRoleNeverStacksWithMageDisadvantageIntoAdvantage() {
        // Runewatch's arcaneWard penalizes mages; vs the Keep the mage has no
        // role, so the product stays penalized.
        let product = CityDefenseTrait.arcaneWard.damageMultiplier(for: .mage)
            * role(.mage, .keep)
        #expect(product == 0.80)
    }

    // MARK: - Two-step rounding (trait round, then role round)

    /// The production pipeline: `traitAdjustedSoldierAttackPower` produces the
    /// cached integer power (already rounded once); the structure hit applies
    /// the role multiplier and rounds again. This differs from rounding
    /// `base × trait × role` once — pinned here for L1 and L2.
    private func twoStepDamage(
        soldierType: SoldierType,
        level: Int,
        trait: CityDefenseTrait,
        kind: CitySiegeLayout.ObjectiveKind
    ) -> Int {
        let cachedPower = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: soldierType,
            level: level,
            defenseTrait: trait
        )
        return max(1, Int((Double(cachedPower) * role(soldierType, kind)).rounded()))
    }

    private func singleStepDamage(
        soldierType: SoldierType,
        level: Int,
        trait: CityDefenseTrait,
        kind: CitySiegeLayout.ObjectiveKind
    ) -> Int {
        let base = KingdomGameState.soldierAttackPower(for: soldierType, level: level)
        let product = Double(base) * trait.damageMultiplier(for: soldierType) * role(soldierType, kind)
        return max(1, Int(product.rounded()))
    }

    @Test func levelOneTraitFavoredSiegeGateTwoStepRoundsBelowSingleStep() {
        // L1 siege, reinforcedKeep (×1.25): cached = round(1 × 1.25) = 1;
        // two-step = round(1 × 2.0) = 2. Single-step would give
        // round(1 × 1.25 × 2.0) = round(2.5) = 3.
        #expect(KingdomGameState.soldierAttackPower(for: .siege, level: 1) == 1)
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(for: .siege, level: 1, defenseTrait: .reinforcedKeep) == 1
        )
        #expect(twoStepDamage(soldierType: .siege, level: 1, trait: .reinforcedKeep, kind: .gate) == 2)
        #expect(
            twoStepDamage(soldierType: .siege, level: 1, trait: .reinforcedKeep, kind: .gate)
                != singleStepDamage(soldierType: .siege, level: 1, trait: .reinforcedKeep, kind: .gate)
        )
    }

    @Test func levelTwoDisadvantagedArcherTowerTwoStepRoundsAboveSingleStep() {
        // L2 archer, arrowTower trait (×0.80): cached = round(2 × 0.80) = 2;
        // two-step = round(2 × 1.5) = 3. Single-step would give
        // round(2 × 0.80 × 1.5) = round(2.4) = 2.
        #expect(KingdomGameState.soldierAttackPower(for: .archer, level: 2) == 2)
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(for: .archer, level: 2, defenseTrait: .arrowTower) == 2
        )
        #expect(twoStepDamage(soldierType: .archer, level: 2, trait: .arrowTower, kind: .arrowTower) == 3)
        #expect(
            twoStepDamage(soldierType: .archer, level: 2, trait: .arrowTower, kind: .arrowTower)
                != singleStepDamage(soldierType: .archer, level: 2, trait: .arrowTower, kind: .arrowTower)
        )
    }

    @Test func levelOneNeutralRoleMatchesSingleStepExactly() {
        // Infantry carries no role anywhere: two-step and single-step agree,
        // pinning that neutral roles never perturb existing trait rounding.
        for kind in [CitySiegeLayout.ObjectiveKind.keep, .gate, .arrowTower, .barracks] {
            #expect(
                twoStepDamage(soldierType: .infantry, level: 1, trait: .standardWatch, kind: kind)
                    == singleStepDamage(soldierType: .infantry, level: 1, trait: .standardWatch, kind: kind)
            )
        }
    }
}
