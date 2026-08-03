//
//  CombatFeedbackProjectorTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

@MainActor
struct CombatFeedbackProjectorTests {
    @Test func projectsDenseTickInDeathTowerSiegeRangedMeleeHitOrder() {
        var result = BattleCombatState.TickResult()
        result.soldierLosses = [
            SoldierLossEvent(soldierID: 90, type: .infantry, source: .manual, lane: .left)
        ]
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 90, damage: 3)
        ]
        result.soldierAttacks = [
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
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
                type: .siege,
                source: .manual,
                lane: .right,
                appliedCityDamage: 2
            )
        ]
        result.damagedSoldierIDs = [90, 91]

        #expect(CombatFeedbackProjector.events(from: result) == [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ])
    }

    @Test func coalescesDuplicateTickSignalsIntoOneEventPerKind() {
        var result = BattleCombatState.TickResult()
        result.soldierLosses = [
            SoldierLossEvent(soldierID: 10, type: .infantry, source: .manual, lane: .left),
            SoldierLossEvent(soldierID: 11, type: .mage, source: .building, lane: .right)
        ]
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 10, damage: 3),
            BattleCombatState.TowerShot(soldierID: 11, damage: 3)
        ]
        result.soldierAttacks = [
            SoldierAttackEvent(soldierID: 1, type: .siege, source: .manual, lane: .left, appliedCityDamage: 2),
            SoldierAttackEvent(soldierID: 2, type: .siege, source: .building, lane: .center, appliedCityDamage: 2),
            SoldierAttackEvent(soldierID: 3, type: .archer, source: .manual, lane: .right, appliedCityDamage: 2),
            SoldierAttackEvent(soldierID: 4, type: .mage, source: .building, lane: .left, appliedCityDamage: 2),
            SoldierAttackEvent(soldierID: 5, type: .infantry, source: .manual, lane: .center, appliedCityDamage: 2),
            SoldierAttackEvent(soldierID: 6, type: .cavalry, source: .building, lane: .right, appliedCityDamage: 2)
        ]
        result.damagedSoldierIDs = [10, 11, 12, 12]

        #expect(CombatFeedbackProjector.events(from: result) == [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ])
    }

    @Test func mapsEverySoldierTypeToItsApprovedAttackCategory() {
        var infantry = BattleCombatState.TickResult()
        infantry.soldierAttacks = [
            SoldierAttackEvent(soldierID: 1, type: .infantry, source: .manual, lane: .left, appliedCityDamage: 1)
        ]
        #expect(CombatFeedbackProjector.events(from: infantry) == [.soldierAttack(.melee)])

        var cavalry = BattleCombatState.TickResult()
        cavalry.soldierAttacks = [
            SoldierAttackEvent(soldierID: 2, type: .cavalry, source: .manual, lane: .center, appliedCityDamage: 1)
        ]
        #expect(CombatFeedbackProjector.events(from: cavalry) == [.soldierAttack(.melee)])

        var archer = BattleCombatState.TickResult()
        archer.soldierAttacks = [
            SoldierAttackEvent(soldierID: 3, type: .archer, source: .manual, lane: .right, appliedCityDamage: 1)
        ]
        #expect(CombatFeedbackProjector.events(from: archer) == [.soldierAttack(.ranged)])

        var mage = BattleCombatState.TickResult()
        mage.soldierAttacks = [
            SoldierAttackEvent(soldierID: 4, type: .mage, source: .building, lane: .left, appliedCityDamage: 1)
        ]
        #expect(CombatFeedbackProjector.events(from: mage) == [.soldierAttack(.ranged)])

        var siege = BattleCombatState.TickResult()
        siege.soldierAttacks = [
            SoldierAttackEvent(soldierID: 5, type: .siege, source: .building, lane: .center, appliedCityDamage: 1)
        ]
        #expect(CombatFeedbackProjector.events(from: siege) == [.soldierAttack(.siege)])
    }

    @Test func excludesFatalDamagedSoldiersFromHitFeedback() {
        var result = BattleCombatState.TickResult()
        result.damagedSoldierIDs = [41, 42]
        result.soldierLosses = [
            SoldierLossEvent(soldierID: 41, type: .infantry, source: .manual, lane: .left),
            SoldierLossEvent(soldierID: 42, type: .archer, source: .building, lane: .right)
        ]

        #expect(CombatFeedbackProjector.events(from: result) == [
            .soldierDamage(.death)
        ])
    }
}
