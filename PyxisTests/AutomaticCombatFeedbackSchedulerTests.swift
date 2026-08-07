//
//  AutomaticCombatFeedbackSchedulerTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

@MainActor
struct AutomaticCombatFeedbackSchedulerTests {
    @Test func opensGlobalGateAtTheExact150MillisecondBoundary() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.000) == .towerFire)
        #expect(scheduler.selectSound(from: siegeOnlyTickResult(), at: 0.149) == nil)
        #expect(scheduler.selectSound(from: siegeOnlyTickResult(), at: 0.150) == .attackSiege)
    }

    @Test func keepsGlobalGateClosedImmediatelyBeforeTheExact150MillisecondBoundary() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.000) == .towerFire)
        #expect(
            scheduler.selectSound(
                from: siegeOnlyTickResult(),
                at: 0.14999999999999997
            ) == nil
        )
        #expect(scheduler.selectSound(from: siegeOnlyTickResult(), at: 0.150) == .attackSiege)
    }

    @Test func keepsEveryAttackFamilyClosedUntilItsExact200MillisecondBoundary() {
        var meleeScheduler = AutomaticCombatFeedbackScheduler()
        #expect(meleeScheduler.selectSound(from: meleeOnlyTickResult(), at: 0.000) == .attackMelee)
        #expect(meleeScheduler.selectSound(from: meleeOnlyTickResult(), at: 0.150) == nil)
        #expect(meleeScheduler.selectSound(from: meleeOnlyTickResult(), at: 0.200) == .attackMelee)

        var rangedScheduler = AutomaticCombatFeedbackScheduler()
        #expect(rangedScheduler.selectSound(from: rangedOnlyTickResult(), at: 0.000) == .attackRanged)
        #expect(rangedScheduler.selectSound(from: rangedOnlyTickResult(), at: 0.150) == nil)
        #expect(rangedScheduler.selectSound(from: rangedOnlyTickResult(), at: 0.200) == .attackRanged)

        var siegeScheduler = AutomaticCombatFeedbackScheduler()
        #expect(siegeScheduler.selectSound(from: siegeOnlyTickResult(), at: 0.000) == .attackSiege)
        #expect(siegeScheduler.selectSound(from: siegeOnlyTickResult(), at: 0.150) == nil)
        #expect(siegeScheduler.selectSound(from: siegeOnlyTickResult(), at: 0.200) == .attackSiege)
    }

    @Test func keepsTowerGateClosedUntilItsExact250MillisecondBoundary() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.000) == .towerFire)
        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.150) == nil)
        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.250) == .towerFire)
    }

    @Test func sharesThe300MillisecondGateFromDeathToHit() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(
            scheduler.selectSound(from: deathAndHitTickResult(), at: 0.000) == .soldierDeath
        )
        #expect(scheduler.selectSound(from: hitOnlyTickResult(), at: 0.150) == nil)
        #expect(scheduler.selectSound(from: hitOnlyTickResult(), at: 0.300) == .soldierHit)
    }

    @Test func sharesThe300MillisecondGateFromHitToDeath() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: hitOnlyTickResult(), at: 0.000) == .soldierHit)
        #expect(scheduler.selectSound(from: deathOnlyTickResult(), at: 0.150) == nil)
        #expect(scheduler.selectSound(from: deathOnlyTickResult(), at: 0.300) == .soldierDeath)
    }

    @Test func doesNotConsumeTheGlobalWindowWhenOnlyAPresentFamilyIsClosed() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.000) == .towerFire)
        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.150) == nil)
        #expect(scheduler.selectSound(from: siegeOnlyTickResult(), at: 0.150) == .attackSiege)
    }

    @Test func closedGlobalGateDoesNotChangeStarvationState() {
        let dense = denseTickResult()
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.075) == nil)
        #expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
        #expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
    }

    @Test func resetsStarvationWhenNoAttackFamilyIsOpen() {
        let dense = denseTickResult()
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
        #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.150) == .towerFire)
        #expect(scheduler.selectSound(from: dense, at: 0.300) == .soldierDeath)
    }

    @Test func rotatesAttackOnlyEligibleBatchesAcrossAllSounds() {
        let attacks = attackOnlyTickResult()
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: attacks, at: 0.000) == .attackSiege)
        #expect(scheduler.selectSound(from: attacks, at: 0.200) == .attackRanged)
        #expect(scheduler.selectSound(from: attacks, at: 0.400) == .attackMelee)
    }

    @Test func reservesEveryThirdEligibleWindowAndRotatesAttackSounds() {
        let dense = denseTickResult()
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
        #expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
        #expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
        #expect(scheduler.selectSound(from: dense, at: 0.450) == .soldierDeath)
        #expect(scheduler.selectSound(from: dense, at: 0.600) == .towerFire)
        #expect(scheduler.selectSound(from: dense, at: 0.750) == .attackRanged)
        #expect(scheduler.selectSound(from: dense, at: 0.900) == .soldierDeath)
        #expect(scheduler.selectSound(from: dense, at: 1.050) == .towerFire)
        #expect(scheduler.selectSound(from: dense, at: 1.200) == .attackMelee)
    }

    @Test func candidatePriorityRemainsDeathTowerSiegeRangedMeleeHit() {
        #expect(firstSound(from: priorityTick(death: true, tower: true)) == .soldierDeath)
        #expect(firstSound(from: priorityTick(tower: true, attacks: [.siege])) == .towerFire)
        #expect(firstSound(from: priorityTick(attacks: [.siege, .archer])) == .attackSiege)
        #expect(firstSound(from: priorityTick(attacks: [.archer, .infantry])) == .attackRanged)
        #expect(firstSound(from: priorityTick(attacks: [.infantry], nonfatalHit: true)) == .attackMelee)
    }

    @Test func rotatedAttackFallsBackToDefaultWhenNoAttackIsEligible() {
        var scheduler = AutomaticCombatFeedbackScheduler()
        let dense = denseTickResult()

        // Build up attackSkippedEligibleWindows to 2 by selecting non-attacks.
        #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
        #expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)

        // At t=0.300, attackSkippedEligibleWindows is 2 so shouldSelectRotatedAttack
        // is true, but nextEligibleAttack returns nil (no attacks are present), so
        // the default event is selected. Death is eligible and towerFire is not.
        #expect(
            scheduler.selectSound(
                from: priorityTick(death: true, tower: true),
                at: 0.300
            ) == .soldierDeath
        )
    }

    @Test func mapsInfantryAndCavalryToMelee() {
        #expect(firstSound(from: priorityTick(attacks: [.infantry])) == .attackMelee)
        #expect(firstSound(from: priorityTick(attacks: [.cavalry])) == .attackMelee)
    }

    @Test func mapsArcherAndMageToRanged() {
        #expect(firstSound(from: priorityTick(attacks: [.archer])) == .attackRanged)
        #expect(firstSound(from: priorityTick(attacks: [.mage])) == .attackRanged)
    }

    @Test func mapsSiegeToSiege() {
        #expect(firstSound(from: priorityTick(attacks: [.siege])) == .attackSiege)
    }

    @Test func duplicateSameFamilyAttacksCoalesceIntoOneCandidate() {
        #expect(
            firstSound(from: priorityTick(attacks: [.siege, .siege])) == .attackSiege
        )
        #expect(
            firstSound(from: priorityTick(attacks: [.archer, .mage])) == .attackRanged
        )
        #expect(
            firstSound(from: priorityTick(attacks: [.infantry, .cavalry])) == .attackMelee
        )
    }

    @Test func fatalDamagedSoldiersDoNotAlsoYieldHitEligibility() {
        #expect(firstSound(from: fatalHitOnlyTickResult()) == .soldierDeath)
    }

    @Test func emptyTickYieldsNoSound() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.selectSound(from: BattleCombatState.TickResult(), at: 0) == nil)
    }

    private func firstSound(
        from result: BattleCombatState.TickResult
    ) -> GameplaySoundID? {
        var scheduler = AutomaticCombatFeedbackScheduler()
        return scheduler.selectSound(from: result, at: 0)
    }

    private func priorityTick(
        death: Bool = false,
        tower: Bool = false,
        attacks: [SoldierType] = [],
        nonfatalHit: Bool = false
    ) -> BattleCombatState.TickResult {
        var result = BattleCombatState.TickResult()

        if death {
            result.soldierLosses = [
                SoldierLossEvent(
                    soldierID: 90,
                    type: .infantry,
                    source: .manual,
                    lane: .left
                )
            ]
        }

        if tower {
            result.towerShots = [
                BattleCombatState.TowerShot(soldierID: 91, damage: 3)
            ]
        }

        result.soldierAttacks = attacks.enumerated().map { index, type in
            SoldierAttackEvent(
                soldierID: index + 100,
                type: type,
                source: .manual,
                lane: .center,
                appliedCityDamage: 1
            )
        }

        if nonfatalHit {
            result.damagedSoldierIDs = [999]
        }

        return result
    }

    private func towerOnlyTickResult() -> BattleCombatState.TickResult {
        var result = BattleCombatState.TickResult()
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 90, damage: 3)
        ]
        return result
    }

    private func siegeOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(attacks: [.siege])
    }

    private func rangedOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(attacks: [.archer])
    }

    private func meleeOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(attacks: [.infantry])
    }

    private func hitOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(nonfatalHit: true)
    }

    private func deathOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(death: true)
    }

    private func deathAndHitTickResult() -> BattleCombatState.TickResult {
        priorityTick(death: true, nonfatalHit: true)
    }

    private func attackOnlyTickResult() -> BattleCombatState.TickResult {
        priorityTick(attacks: [.siege, .archer, .infantry])
    }

    private func fatalHitOnlyTickResult() -> BattleCombatState.TickResult {
        var result = deathOnlyTickResult()
        result.damagedSoldierIDs = [90]
        return result
    }

    private func denseTickResult() -> BattleCombatState.TickResult {
        var result = BattleCombatState.TickResult()
        result.soldierLosses = [
            SoldierLossEvent(
                soldierID: 90,
                type: .infantry,
                source: .manual,
                lane: .left
            )
        ]
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 90, damage: 3)
        ]
        result.soldierAttacks = [
            SoldierAttackEvent(
                soldierID: 1,
                type: .siege,
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
                type: .infantry,
                source: .manual,
                lane: .right,
                appliedCityDamage: 2
            )
        ]
        result.damagedSoldierIDs = [90, 91]
        return result
    }
}
