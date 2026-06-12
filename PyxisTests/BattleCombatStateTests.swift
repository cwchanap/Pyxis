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
        #expect(soldier.type == .infantry)
        #expect(soldier.source == .manual)
        #expect(soldier.level == 1)
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

    @Test func infantryAndArcherUseDifferentHPAndAttackRanges() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2)
        let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2)

        let infantrySoldier = try #require(combat.soldier(id: infantry))
        let archerSoldier = try #require(combat.soldier(id: archer))

        #expect(infantrySoldier.type == .infantry)
        #expect(archerSoldier.type == .archer)
        #expect(infantrySoldier.maxHP > archerSoldier.maxHP)
        #expect(infantrySoldier.attackRange < archerSoldier.attackRange)
    }

    @Test func expandedSoldierTypesUseDistinctCombatStats() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2)
        let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2)
        let cavalry = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 2)
        let mage = combat.spawnSoldier(type: .mage, source: .manual, level: 1, attackPower: 2)
        let siege = combat.spawnSoldier(type: .siege, source: .manual, level: 1, attackPower: 2)

        let infantrySoldier = try #require(combat.soldier(id: infantry))
        let archerSoldier = try #require(combat.soldier(id: archer))
        let cavalrySoldier = try #require(combat.soldier(id: cavalry))
        let mageSoldier = try #require(combat.soldier(id: mage))
        let siegeSoldier = try #require(combat.soldier(id: siege))

        #expect(infantrySoldier.maxHP > archerSoldier.maxHP)
        #expect(cavalrySoldier.movementSpeed > infantrySoldier.movementSpeed)
        #expect(mageSoldier.attackRange > infantrySoldier.attackRange)
        #expect(siegeSoldier.attackPower == 2)
        #expect(siegeSoldier.attackSpeed < infantrySoldier.attackSpeed)
        #expect(siegeSoldier.movementSpeed < infantrySoldier.movementSpeed)
    }

    @Test func expandedSoldierTypesMatchLiveCombatStats() throws {
        let expectedStats: [ExpectedSoldierStats] = [
            ExpectedSoldierStats(
                type: .infantry,
                maxHP: 10,
                attackRange: 0.12,
                attackSpeed: 1.0,
                movementSpeed: 0.45
            ),
            ExpectedSoldierStats(
                type: .archer,
                maxHP: 7,
                attackRange: 0.264,
                attackSpeed: 1.0,
                movementSpeed: 0.45
            ),
            ExpectedSoldierStats(
                type: .cavalry,
                maxHP: 9,
                attackRange: 0.12,
                attackSpeed: 1.15,
                movementSpeed: 0.6525
            ),
            ExpectedSoldierStats(
                type: .mage,
                maxHP: 7,
                attackRange: 0.24,
                attackSpeed: 0.85,
                movementSpeed: 0.405
            ),
            ExpectedSoldierStats(
                type: .siege,
                maxHP: 14,
                attackRange: 0.18,
                attackSpeed: 0.55,
                movementSpeed: 0.2475
            )
        ]
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        for expected in expectedStats {
            let id = combat.spawnSoldier(type: expected.type, source: .manual, level: 1, attackPower: 2)
            let soldier = try #require(combat.soldier(id: id))

            #expect(soldier.maxHP == expected.maxHP)
            #expect(isApproximatelyEqual(soldier.attackRange, expected.attackRange))
            #expect(isApproximatelyEqual(soldier.attackSpeed, expected.attackSpeed))
            #expect(isApproximatelyEqual(soldier.movementSpeed, expected.movementSpeed))
        }
    }

    @Test func attackSpeedClampsAfterApplyingSoldierTypeMultiplier() throws {
        let lowAttackSpeedConfiguration = BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 1,
            soldierAttackSpeed: 0.05,
            soldierAttackRange: 0.12,
            soldierMovementSpeed: 0.45,
            towerDamage: 2,
            towerAttackSpeed: 0.8,
            towerAttackRange: 0.55,
            maxDeltaTime: 0.25
        )
        let soldierTypes: [SoldierType] = [.infantry, .archer, .cavalry, .mage, .siege]
        var combat = BattleCombatState(configuration: lowAttackSpeedConfiguration)

        for type in soldierTypes {
            let id = combat.spawnSoldier(type: type, source: .manual, level: 1, attackPower: 2)
            let soldier = try #require(combat.soldier(id: id))

            #expect(soldier.attackSpeed == 0.1)
        }
    }

    @Test func newSoldierTypeLevelsIncreaseHP() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let low = combat.spawnSoldier(type: .siege, source: .building, level: 1, attackPower: 1)
        let high = combat.spawnSoldier(type: .siege, source: .building, level: 4, attackPower: 4)

        let lowSoldier = try #require(combat.soldier(id: low))
        let highSoldier = try #require(combat.soldier(id: high))

        #expect(highSoldier.maxHP > lowSoldier.maxHP)
        #expect(highSoldier.level == 4)
        #expect(highSoldier.attackPower == 4)
    }

    @Test func soldierLevelIncreasesHPAndCarriesSpawnSource() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let low = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1)
        let high = combat.spawnSoldier(type: .infantry, source: .building, level: 3, attackPower: 3)

        let lowSoldier = try #require(combat.soldier(id: low))
        let highSoldier = try #require(combat.soldier(id: high))

        #expect(lowSoldier.source == .building)
        #expect(highSoldier.source == .building)
        #expect(highSoldier.level == 3)
        #expect(highSoldier.maxHP > lowSoldier.maxHP)
        #expect(highSoldier.attackPower == 3)
    }

    @Test func cavalryAndMageHPScaleWithLevel() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let cavalryL1 = combat.spawnSoldier(type: .cavalry, source: .building, level: 1, attackPower: 1)
        let cavalryL3 = combat.spawnSoldier(type: .cavalry, source: .building, level: 3, attackPower: 1)
        let mageL1 = combat.spawnSoldier(type: .mage, source: .building, level: 1, attackPower: 1)
        let mageL3 = combat.spawnSoldier(type: .mage, source: .building, level: 3, attackPower: 1)

        let c1 = try #require(combat.soldier(id: cavalryL1))
        let c3 = try #require(combat.soldier(id: cavalryL3))
        let m1 = try #require(combat.soldier(id: mageL1))
        let m3 = try #require(combat.soldier(id: mageL3))

        // Cavalry: 10 * 0.9 = 9 base → level 3: round(9 * 1.5625) = 14
        #expect(c1.maxHP == 9)
        #expect(c3.maxHP == 14)

        // Mage: 10 * 0.65 = 6.5 base → level 3: round(6.5 * 1.5625) = 10
        #expect(m1.maxHP == 7)
        #expect(m3.maxHP == 10)
    }

    @Test func manualLivingSoldierCountExcludesBuildingSpawnedSoldiers() {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
        _ = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1)
        _ = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1)

        #expect(combat.livingSoldierCount == 3)
        #expect(combat.livingSoldierCount(source: .manual) == 2)
        #expect(combat.livingSoldierCount(source: .building) == 1)
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
        let first = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.tick(deltaTime: 0.7, cityRemainingHP: 20)
        let second = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

        #expect(result.towerShots.count == 1)
        let shot = try #require(result.towerShots.first)
        #expect(shot.soldierID == first)
        #expect(shot.damage == 2)
        #expect(try #require(combat.soldier(id: first)).currentHP == 8)
        #expect(try #require(combat.soldier(id: second)).currentHP == 10)
    }

    @Test func towerTargetsMostAdvancedSoldierWithinChosenLane() throws {
        // Tower range covers the whole field; all soldiers are eligible.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.5,
                towerDamage: 2,
                towerAttackSpeed: 100.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 3
        )
        // Front and back soldier in the same lane; the back one must never be hit
        // while the front one lives, regardless of which lane the RNG picks.
        let front = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = combat.tick(deltaTime: 0.5, cityRemainingHP: 1_000)
        let back = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(result.towerShots.count == 1)
        #expect(try #require(result.towerShots.first).soldierID == front)
        #expect(try #require(combat.soldier(id: back)).currentHP == 10)
    }

    @Test func towerNeverTargetsLaneWithNoSoldierInRange() throws {
        // Tower range 0.40: only soldiers past position 0.60 are eligible.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.7,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.40,
                maxDeltaTime: 1.0
            ),
            seed: 11
        )
        let advanced = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.tick(deltaTime: 1.0, cityRemainingHP: 1_000) // advanced reaches 0.70
        let fresh = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let result = combat.tick(deltaTime: 0.05, cityRemainingHP: 1_000)

        // Only the center lane has a soldier in range; the fresh right-lane
        // soldier (position ~0) must never be chosen.
        #expect(result.towerShots.count == 1)
        #expect(try #require(result.towerShots.first).soldierID == advanced)
        #expect(try #require(combat.soldier(id: fresh)).currentHP == 10)
    }

    @Test func towerSpreadsShotsAcrossOccupiedLanesOverTime() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 1_000,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 1,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 4
        )
        let left = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        let right = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        var hitSoldierIDs = Set<BattleCombatState.SoldierID>()
        for _ in 0..<30 {
            let result = combat.tick(deltaTime: 1.0, cityRemainingHP: 1_000_000)
            for shot in result.towerShots {
                hitSoldierIDs.insert(shot.soldierID)
            }
        }

        // Over 30 shots with a seeded RNG, both occupied lanes get hit.
        #expect(hitSoldierIDs.contains(left))
        #expect(hitSoldierIDs.contains(right))
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
        #expect(combat.soldier(id: id) == nil)

        let laterTick = combat.tick(deltaTime: 0.2, cityRemainingHP: 17)
        #expect(laterTick.cityDamage == 0)
        #expect(laterTick.towerShots.isEmpty)
        #expect(laterTick.soldierAttackIDs.isEmpty)
    }

    @Test func deadSoldiersArePrunedFromActiveCombatants() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 1,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0.5,
                towerDamage: 1,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(attackPower: 1)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

        #expect(result.killedSoldierIDs == [id])
        #expect(combat.livingSoldierCount == 0)
        #expect(combat.soldiers.isEmpty)
        #expect(combat.soldier(id: id) == nil)
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

    @Test func spawnAssignsLaneDeterministicallyFromSeed() throws {
        var first = BattleCombatState(configuration: .live(cityLevel: 1), seed: 99)
        var second = BattleCombatState(configuration: .live(cityLevel: 1), seed: 99)

        var firstLanes: [BattleLane] = []
        var secondLanes: [BattleLane] = []
        for _ in 0..<12 {
            let firstID = first.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
            let secondID = second.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1)
            firstLanes.append(try #require(first.soldier(id: firstID)).lane)
            secondLanes.append(try #require(second.soldier(id: secondID)).lane)
        }

        #expect(firstLanes == secondLanes)
        // 12 spawns across 3 lanes should not all collapse into a single lane.
        #expect(Set(firstLanes).count > 1)
    }

    @Test func spawnHonorsExplicitLane() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1), seed: 1)

        for lane in BattleLane.allCases {
            let id = combat.spawnSoldier(type: .archer, source: .building, level: 2, attackPower: 3, lane: lane)
            #expect(try #require(combat.soldier(id: id)).lane == lane)
        }
    }

    @Test func laneIsFixedForSoldierLifetime() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1), seed: 5)
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        _ = combat.tick(deltaTime: 0.2, cityRemainingHP: 1_000)
        _ = combat.tick(deltaTime: 0.2, cityRemainingHP: 1_000)

        #expect(try #require(combat.soldier(id: id)).lane == .right)
    }

    @Test func fortifiedLaneScalesTowerDamageUp() throws {
        // towerDamage 5, defense 1 → base 4; fortified 1.25× → 5.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.left: 1.25, .center: 1.0, .right: 0.80]
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 5)
        #expect(try #require(combat.soldier(id: id)).currentHP == 15)
    }

    @Test func exposedLaneScalesTowerDamageDown() throws {
        // towerDamage 5, defense 1 → base 4; exposed 0.80× → 3.2 → rounds to 3.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.left: 1.25, .center: 1.0, .right: 0.80]
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 3)
        #expect(try #require(combat.soldier(id: id)).currentHP == 17)
    }

    @Test func missingLaneMultiplierDefaultsToNeutral() throws {
        // Empty map → multiplier 1.0 everywhere; base damage 4 unchanged.
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 4)
    }

    @Test func nonPositiveLaneMultiplierStillDealsMinimumDamage() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 20,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 5,
                towerAttackSpeed: 1.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0,
                laneDamageMultipliers: [.center: -2.0]
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 1_000)

        #expect(try #require(result.towerShots.first).damage == 1)
    }

    private struct ExpectedSoldierStats {
        let type: SoldierType
        let maxHP: Int
        let attackRange: Double
        let attackSpeed: Double
        let movementSpeed: Double
    }

    private func isApproximatelyEqual(
        _ lhs: Double,
        _ rhs: Double,
        tolerance: Double = 0.000_001
    ) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
