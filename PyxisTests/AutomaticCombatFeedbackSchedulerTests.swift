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

        #expect(scheduler.select(from: [.towerFire], at: 0.000) == .towerFire)
        #expect(scheduler.select(from: [.soldierAttack(.siege)], at: 0.149) == nil)
        #expect(scheduler.select(from: [.soldierAttack(.siege)], at: 0.150) == .soldierAttack(.siege))
    }

    @Test func keepsGlobalGateClosedImmediatelyBeforeTheExact150MillisecondBoundary() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: [.towerFire], at: 0.000) == .towerFire)
        #expect(
            scheduler.select(
                from: [.soldierAttack(.siege)],
                at: 0.14999999999999997
            ) == nil
        )
        #expect(scheduler.select(from: [.soldierAttack(.siege)], at: 0.150) == .soldierAttack(.siege))
    }

    @Test func keepsEveryAttackCategoryClosedUntilItsExact200MillisecondBoundary() {
        var meleeScheduler = AutomaticCombatFeedbackScheduler()
        #expect(meleeScheduler.select(from: [.soldierAttack(.melee)], at: 0.000) == .soldierAttack(.melee))
        #expect(meleeScheduler.select(from: [.soldierAttack(.melee)], at: 0.150) == nil)
        #expect(meleeScheduler.select(from: [.soldierAttack(.melee)], at: 0.200) == .soldierAttack(.melee))

        var rangedScheduler = AutomaticCombatFeedbackScheduler()
        #expect(rangedScheduler.select(from: [.soldierAttack(.ranged)], at: 0.000) == .soldierAttack(.ranged))
        #expect(rangedScheduler.select(from: [.soldierAttack(.ranged)], at: 0.150) == nil)
        #expect(rangedScheduler.select(from: [.soldierAttack(.ranged)], at: 0.200) == .soldierAttack(.ranged))

        var siegeScheduler = AutomaticCombatFeedbackScheduler()
        #expect(siegeScheduler.select(from: [.soldierAttack(.siege)], at: 0.000) == .soldierAttack(.siege))
        #expect(siegeScheduler.select(from: [.soldierAttack(.siege)], at: 0.150) == nil)
        #expect(siegeScheduler.select(from: [.soldierAttack(.siege)], at: 0.200) == .soldierAttack(.siege))
    }

    @Test func keepsTowerGateClosedUntilItsExact250MillisecondBoundary() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: [.towerFire], at: 0.000) == .towerFire)
        #expect(scheduler.select(from: [.towerFire], at: 0.150) == nil)
        #expect(scheduler.select(from: [.towerFire], at: 0.250) == .towerFire)
    }

    @Test func sharesThe300MillisecondGateFromDeathToHit() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(
            scheduler.select(
                from: [.soldierDamage(.death), .soldierDamage(.hit)],
                at: 0.000
            ) == .soldierDamage(.death)
        )
        #expect(scheduler.select(from: [.soldierDamage(.hit)], at: 0.150) == nil)
        #expect(scheduler.select(from: [.soldierDamage(.hit)], at: 0.300) == .soldierDamage(.hit))
    }

    @Test func sharesThe300MillisecondGateFromHitToDeath() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: [.soldierDamage(.hit)], at: 0.000) == .soldierDamage(.hit))
        #expect(scheduler.select(from: [.soldierDamage(.death)], at: 0.150) == nil)
        #expect(scheduler.select(from: [.soldierDamage(.death)], at: 0.300) == .soldierDamage(.death))
    }

    @Test func doesNotConsumeTheGlobalWindowWhenOnlyAPresentCategoryIsClosed() {
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: [.towerFire], at: 0.000) == .towerFire)
        #expect(scheduler.select(from: [.towerFire], at: 0.150) == nil)
        #expect(scheduler.select(from: [.soldierAttack(.siege)], at: 0.150) == .soldierAttack(.siege))
    }

    @Test func doesNotChangeStarvationStateWhileTheGlobalGateIsClosed() {
        let dense = denseEvents
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: dense, at: 0.000) == .soldierDamage(.death))
        #expect(scheduler.select(from: [.towerFire], at: 0.075) == nil)
        #expect(scheduler.select(from: dense, at: 0.150) == .towerFire)
        #expect(scheduler.select(from: dense, at: 0.300) == .soldierAttack(.siege))
    }

    @Test func resetsStarvationWhenNoAttackCategoryIsOpen() {
        let dense = denseEvents
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: dense, at: 0.000) == .soldierDamage(.death))
        #expect(scheduler.select(from: [.towerFire], at: 0.150) == .towerFire)
        #expect(scheduler.select(from: dense, at: 0.300) == .soldierDamage(.death))
    }

    @Test func rotatesAttackOnlyEligibleBatchesAcrossAllCategories() {
        let attacks: [GameplayFeedbackEvent] = [
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee)
        ]
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: attacks, at: 0.000) == .soldierAttack(.siege))
        #expect(scheduler.select(from: attacks, at: 0.200) == .soldierAttack(.ranged))
        #expect(scheduler.select(from: attacks, at: 0.400) == .soldierAttack(.melee))
    }

    @Test func reservesEveryThirdEligibleWindowAndRotatesAttackCategories() {
        let dense = denseEvents
        var scheduler = AutomaticCombatFeedbackScheduler()

        #expect(scheduler.select(from: dense, at: 0.000) == .soldierDamage(.death))
        #expect(scheduler.select(from: dense, at: 0.150) == .towerFire)
        #expect(scheduler.select(from: dense, at: 0.300) == .soldierAttack(.siege))
        #expect(scheduler.select(from: dense, at: 0.450) == .soldierDamage(.death))
        #expect(scheduler.select(from: dense, at: 0.600) == .towerFire)
        #expect(scheduler.select(from: dense, at: 0.750) == .soldierAttack(.ranged))
        #expect(scheduler.select(from: dense, at: 0.900) == .soldierDamage(.death))
        #expect(scheduler.select(from: dense, at: 1.050) == .towerFire)
        #expect(scheduler.select(from: dense, at: 1.200) == .soldierAttack(.melee))
    }

    private var denseEvents: [GameplayFeedbackEvent] {
        [
            .soldierDamage(.death),
            .towerFire,
            .soldierAttack(.siege),
            .soldierAttack(.ranged),
            .soldierAttack(.melee),
            .soldierDamage(.hit)
        ]
    }
}
