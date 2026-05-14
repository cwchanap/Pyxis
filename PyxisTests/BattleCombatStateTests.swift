//
//  BattleCombatStateTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct BattleCombatStateTests {
    @Test func spawningCreatesSoldierWithFullHPAndConfiguredStats() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 12,
                soldierDefense: 3,
                soldierAttackSpeed: 1.5,
                soldierAttackRange: 0.10,
                soldierMovementSpeed: 0.40,
                towerDamage: 4,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.50,
                maxDeltaTime: 0.25
            )
        )

        let id = combat.spawnSoldier(attackPower: 7)

        #expect(combat.livingSoldierCount == 1)
        let soldier = try #require(combat.soldier(id: id))
        #expect(soldier.maxHP == 12)
        #expect(soldier.currentHP == 12)
        #expect(soldier.defense == 3)
        #expect(soldier.attackPower == 7)
        #expect(soldier.attackSpeed == 1.5)
        #expect(soldier.attackRange == 0.10)
        #expect(soldier.movementSpeed == 0.40)
        #expect(soldier.position == 0)
        #expect(soldier.isAlive)
    }

    @Test func liveConfigurationScalesTowerDamageByCityLevel() {
        let cityOne = BattleCombatState.Configuration.live(cityLevel: 1)
        let cityFive = BattleCombatState.Configuration.live(cityLevel: 5)

        #expect(cityOne.soldierMaxHP == 10)
        #expect(cityOne.soldierDefense == 1)
        #expect(cityOne.soldierAttackSpeed == 1.0)
        #expect(cityOne.soldierAttackRange == 0.12)
        #expect(cityOne.soldierMovementSpeed == 0.45)
        #expect(cityOne.towerDamage == 2)
        #expect(cityOne.towerAttackSpeed == 0.8)
        #expect(cityOne.towerAttackRange == 0.55)

        #expect(cityFive.towerDamage > cityOne.towerDamage)
        #expect(cityFive.towerAttackSpeed == cityOne.towerAttackSpeed)
        #expect(cityFive.towerAttackRange == cityOne.towerAttackRange)
    }

    @Test func soldierMovesTowardCityUntilInAttackRange() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.20,
                soldierMovementSpeed: 0.50,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 3)

        let firstTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
        #expect(firstTick.cityDamage == 0)
        #expect(try #require(combat.soldier(id: id)).position == 0.50)

        let secondTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
        let soldier = try #require(combat.soldier(id: id))
        #expect(soldier.position == 0.80)
        #expect(secondTick.cityDamage == 3)
        #expect(secondTick.soldierAttackIDs == [id])
    }

    @Test func soldierAttacksRepeatedlyOnCooldownWhileInRange() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 1,
                soldierAttackSpeed: 2.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 4)

        let firstTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
        #expect(firstTick.cityDamage == 4)
        #expect(firstTick.soldierAttackIDs == [id])

        let cooldownTick = combat.tick(deltaTime: 0.2, cityRemainingHP: 16)
        #expect(cooldownTick.cityDamage == 0)
        #expect(cooldownTick.soldierAttackIDs.isEmpty)

        let secondAttackTick = combat.tick(deltaTime: 0.3, cityRemainingHP: 16)
        #expect(secondAttackTick.cityDamage == 4)
        #expect(secondAttackTick.soldierAttackIDs == [id])
    }

    @Test func emittedCityDamageIsCappedToRemainingHP() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            )
        )
        _ = combat.spawnSoldier(attackPower: 8)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 3)

        #expect(result.cityDamage == 3)
        #expect(result.didReachConquest)
    }

    @Test func towerDamagesLivingSoldierInRangeWithDefenseMinimumOne() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 4,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 1.0,
                towerDamage: 4,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 1)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

        #expect(result.towerShots.count == 1)
        let shot = try #require(result.towerShots.first)
        #expect(shot.soldierID == id)
        #expect(shot.damage == 1)
        #expect(result.damagedSoldierIDs == [id])
        #expect(try #require(combat.soldier(id: id)).currentHP == 9)
    }

    @Test func towerTargetsLivingSoldierClosestToCity() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.5,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.70,
                maxDeltaTime: 1.0
            )
        )
        let first = combat.spawnSoldier(attackPower: 1)
        _ = combat.tick(deltaTime: 0.7, cityRemainingHP: 20)
        let second = combat.spawnSoldier(attackPower: 1)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

        #expect(result.towerShots.count == 1)
        let shot = try #require(result.towerShots.first)
        #expect(shot.soldierID == first)
        #expect(shot.damage == 2)
        #expect(try #require(combat.soldier(id: first)).currentHP == 8)
        #expect(try #require(combat.soldier(id: second)).currentHP == 10)
    }

    @Test func soldierDiesOnlyWhenHPReachesZeroAndStopsActing() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 3,
                soldierDefense: 0,
                soldierAttackSpeed: 10.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 2,
                towerAttackSpeed: 10.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 3)

        let damageTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
        #expect(damageTick.damagedSoldierIDs == [id])
        #expect(damageTick.killedSoldierIDs.isEmpty)
        #expect(damageTick.cityDamage == 3)
        #expect(damageTick.soldierAttackIDs == [id])
        #expect(try #require(combat.soldier(id: id)).currentHP == 1)

        let killTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 17)
        #expect(killTick.killedSoldierIDs == [id])
        #expect(killTick.cityDamage == 0)
        #expect(killTick.soldierAttackIDs.isEmpty)
        #expect(try #require(combat.soldier(id: id)).currentHP == 0)
        #expect(!((try #require(combat.soldier(id: id))).isAlive))

        let laterTick = combat.tick(deltaTime: 0.2, cityRemainingHP: 17)
        #expect(laterTick.cityDamage == 0)
        #expect(laterTick.towerShots.isEmpty)
        #expect(laterTick.soldierAttackIDs.isEmpty)
    }

    @Test func towerWaitsAtReadyWithoutTargetInsteadOfBuildingCooldownDebt() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.2,
                towerDamage: 1,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.40,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 1)

        let firstNoTargetTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
        let secondNoTargetTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
        let entryTick = combat.tick(deltaTime: 1.0, cityRemainingHP: 20)
        #expect(firstNoTargetTick.towerShots.isEmpty)
        #expect(secondNoTargetTick.towerShots.isEmpty)
        #expect(entryTick.towerShots.isEmpty)

        let readyTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
        #expect(readyTick.towerShots.count == 1)
        let shot = try #require(readyTick.towerShots.first)
        #expect(shot.soldierID == id)
        #expect(try #require(combat.soldier(id: id)).currentHP == 9)

        let tooSoonTick = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)
        #expect(tooSoonTick.towerShots.isEmpty)
        #expect(try #require(combat.soldier(id: id)).currentHP == 9)
    }

    @Test func largeTickDeltasAreClamped() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.20,
                soldierMovementSpeed: 1.0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 0.25
            )
        )
        let id = combat.spawnSoldier(attackPower: 1)

        _ = combat.tick(deltaTime: 10.0, cityRemainingHP: 20)

        #expect(try #require(combat.soldier(id: id)).position == 0.25)
    }
}
