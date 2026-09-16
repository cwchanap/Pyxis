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

        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 7, lane: .center)

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

        let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2, lane: .center)
        let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2, lane: .center)

        let infantrySoldier = try #require(combat.soldier(id: infantry))
        let archerSoldier = try #require(combat.soldier(id: archer))

        #expect(infantrySoldier.type == .infantry)
        #expect(archerSoldier.type == .archer)
        #expect(infantrySoldier.maxHP > archerSoldier.maxHP)
        #expect(infantrySoldier.attackRange < archerSoldier.attackRange)
    }

    @Test func expandedSoldierTypesUseDistinctCombatStats() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let infantry = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2, lane: .center)
        let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 2, lane: .center)
        let cavalry = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 2, lane: .center)
        let mage = combat.spawnSoldier(type: .mage, source: .manual, level: 1, attackPower: 2, lane: .center)
        let siege = combat.spawnSoldier(type: .siege, source: .manual, level: 1, attackPower: 2, lane: .center)

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
            let id = combat.spawnSoldier(type: expected.type, source: .manual, level: 1, attackPower: 2, lane: .center)
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
            let id = combat.spawnSoldier(type: type, source: .manual, level: 1, attackPower: 2, lane: .center)
            let soldier = try #require(combat.soldier(id: id))

            #expect(soldier.attackSpeed == 0.1)
        }
    }

    @Test func newSoldierTypeLevelsIncreaseHP() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let low = combat.spawnSoldier(type: .siege, source: .building, level: 1, attackPower: 1, lane: .center)
        let high = combat.spawnSoldier(type: .siege, source: .building, level: 4, attackPower: 4, lane: .center)

        let lowSoldier = try #require(combat.soldier(id: low))
        let highSoldier = try #require(combat.soldier(id: high))

        #expect(highSoldier.maxHP > lowSoldier.maxHP)
        #expect(highSoldier.level == 4)
        #expect(highSoldier.attackPower == 4)
    }

    @Test func soldierLevelIncreasesHPAndCarriesSpawnSource() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))

        let low = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1, lane: .center)
        let high = combat.spawnSoldier(type: .infantry, source: .building, level: 3, attackPower: 3, lane: .center)

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

        let cavalryL1 = combat.spawnSoldier(type: .cavalry, source: .building, level: 1, attackPower: 1, lane: .center)
        let cavalryL3 = combat.spawnSoldier(type: .cavalry, source: .building, level: 3, attackPower: 1, lane: .center)
        let mageL1 = combat.spawnSoldier(type: .mage, source: .building, level: 1, attackPower: 1, lane: .center)
        let mageL3 = combat.spawnSoldier(type: .mage, source: .building, level: 3, attackPower: 1, lane: .center)

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

        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1, lane: .center)

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

    // MARK: - Objective targeting and movement (HPA-468 §3.2)

    @Test func soldierMovesTowardObjectiveUntilInAttackRange() throws {
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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 3, lane: .center)
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 20)

        let firstTick = combat.tick(deltaTime: 1.0, siege: snapshot)
        #expect(firstTick.soldierAttacks.isEmpty)
        #expect(try #require(combat.soldier(id: id)).position == 0.50)

        let secondTick = combat.tick(deltaTime: 1.0, siege: snapshot)
        let soldier = try #require(combat.soldier(id: id))
        // Stop position is the referenced objective's visualProgress minus range.
        #expect(soldier.position == max(0, 1.0 - 0.20))
        #expect(secondTick.soldierAttacks.map(\.appliedDamage) == [3])
        #expect(secondTick.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.singleKeepID])
    }

    @Test func leftSoldierStopsAtTowerWhileCenterAndRightStopAtGate() throws {
        var combat = BattleCombatState(configuration: .live(cityLevel: 1))
        let left = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        let center = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let right = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let snapshot = SiegeFixtures.falconridgeSnapshot()
        // The live configuration clamps every tick to maxDeltaTime 0.25s, so
        // five 0.5s ticks (1.25s of sim time) are needed to reach the stops.
        for _ in 0..<5 {
            _ = combat.tick(deltaTime: 0.5, siege: snapshot)
        }

        // Tower at 0.68, Gate at 0.58, soldier range 0.12.
        #expect(try #require(combat.soldier(id: left)).position == max(0, 0.68 - 0.12))
        #expect(try #require(combat.soldier(id: center)).position == max(0, 0.58 - 0.12))
        #expect(try #require(combat.soldier(id: right)).position == max(0, 0.58 - 0.12))
    }

    @Test func soldiersContinueToNextObjectiveAfterTargetDies() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.12,
                soldierMovementSpeed: 1.0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            )
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 5, lane: .left)

        // Tower has only 3 HP; one attack destroys it.
        let towerKill = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.falconridgeSnapshot(towerRemaining: 3))
        #expect(towerKill.soldierAttacks == [
            SoldierAttackEvent(
                soldierID: id,
                type: .infantry,
                source: .manual,
                lane: .left,
                objectiveID: SiegeFixtures.towerID,
                appliedDamage: 3
            )
        ])

        // Next tick resolves the next route objective: the Keep.
        let keepAttack = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.falconridgeSnapshot(towerRemaining: 0))
        #expect(keepAttack.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.keepID])
        #expect(keepAttack.soldierAttacks.map(\.appliedDamage) == [5])
    }

    @Test func sameTickAttacksCannotOverkillOneObjective() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        let first = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 5, lane: .center)
        let second = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 5, lane: .center)

        // Gate has 3 HP: the first soldier kills it, the second spills to the
        // Keep in the same tick. The gate never takes more than its remaining HP.
        let result = combat.tick(
            deltaTime: 0.1,
            siege: SiegeFixtures.falconridgeSnapshot(towerRemaining: 0, gateRemaining: 3)
        )

        #expect(result.soldierAttacks == [
            SoldierAttackEvent(
                soldierID: first,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: SiegeFixtures.gateID,
                appliedDamage: 3
            ),
            SoldierAttackEvent(
                soldierID: second,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: SiegeFixtures.keepID,
                appliedDamage: 5
            )
        ])
        #expect(!result.didReachConquest)
    }

    @Test func keepZeroConquersWhileOptionalStructuresSurvive() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 8, lane: .center)

        // The still-living Tower (46 HP) never blocks conquest: the route is
        // gate → keep, and the gate falls first.
        // One attack interval (1.0s) separates the gate-fall tick from the
        // keep-conquest tick.
        let gateTick = combat.tick(
            deltaTime: 1.0,
            siege: SiegeFixtures.falconridgeSnapshot(keepRemaining: 3, gateRemaining: 3)
        )
        #expect(!gateTick.didReachConquest)

        let conquestTick = combat.tick(
            deltaTime: 1.0,
            siege: SiegeFixtures.falconridgeSnapshot(keepRemaining: 3, gateRemaining: 0)
        )
        #expect(conquestTick.didReachConquest)
    }

    @Test func manualAndBuildingSourcesShareRouteTargeting() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 1.0,
                soldierMovementSpeed: 0,
                towerDamage: 0,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        let manual = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let building = combat.spawnSoldier(type: .infantry, source: .building, level: 1, attackPower: 1, lane: .center)

        // One attack interval (1.0s) separates the two route advances.
        let firstTick = combat.tick(
            deltaTime: 1.0,
            siege: SiegeFixtures.falconridgeSnapshot(towerRemaining: 0, gateRemaining: 2)
        )
        #expect(firstTick.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.gateID, SiegeFixtures.gateID])
        #expect(firstTick.soldierAttacks.map(\.source) == [.manual, .building])
        #expect(Set(firstTick.soldierAttacks.map(\.soldierID)) == [manual, building])

        // Both sources advance to the Keep once the shared gate is gone.
        let secondTick = combat.tick(
            deltaTime: 1.0,
            siege: SiegeFixtures.falconridgeSnapshot(towerRemaining: 0, gateRemaining: 0)
        )
        #expect(secondTick.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.keepID, SiegeFixtures.keepID])
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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 4, lane: .center)
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 20)

        let firstTick = combat.tick(deltaTime: 0.1, siege: snapshot)
        #expect(firstTick.soldierAttacks.map(\.appliedDamage) == [4])
        #expect(firstTick.soldierAttacks.map(\.soldierID) == [id])

        let cooldownTick = combat.tick(deltaTime: 0.2, siege: snapshot)
        #expect(cooldownTick.soldierAttacks.isEmpty)

        let secondAttackTick = combat.tick(deltaTime: 0.3, siege: snapshot)
        #expect(secondAttackTick.soldierAttacks.map(\.appliedDamage) == [4])
        #expect(secondAttackTick.soldierAttacks.map(\.soldierID) == [id])
    }

    @Test func attackOverkillIsClampedToObjectiveRemaining() {
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
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 8, lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 3))

        #expect(result.soldierAttacks.map(\.appliedDamage) == [3])
        #expect(result.didReachConquest)
    }

    @Test func soldierAttackEventUsesClampedAppliedDamageOnOverkill() {
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
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 10, lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 3))

        #expect(result.soldierAttacks == [
            SoldierAttackEvent(
                soldierID: id,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: SiegeFixtures.singleKeepID,
                appliedDamage: 3
            )
        ])
        #expect(result.didReachConquest)
    }

    // MARK: - Source-relative defensive fire (HPA-468 §3.3)

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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))

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
        _ = combat.tick(deltaTime: 0.7, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))
        let second = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))

        #expect(result.towerShots.count == 1)
        let shot = try #require(result.towerShots.first)
        #expect(shot.soldierID == first)
        #expect(shot.damage == 2)
        #expect(try #require(combat.soldier(id: first)).currentHP == 8)
        #expect(try #require(combat.soldier(id: second)).currentHP == 10)
    }

    @Test func towerTargetsMostAdvancedSoldierWithinChosenLane() throws {
        // Defensive fire covers the whole field; all soldiers are eligible.
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
        // while the front one lives. Both are in .left so occupiedLanes == [.left]
        // and the fire always targets that lane's most advanced soldier.
        let front = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = combat.tick(deltaTime: 0.5, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))
        let back = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(result.towerShots.count == 1)
        #expect(try #require(result.towerShots.first).soldierID == front)
        #expect(try #require(combat.soldier(id: back)).currentHP == 10)
    }

    @Test func towerNeverTargetsLaneWithNoSoldierInRange() throws {
        // Fire range 0.40 against the Keep source at 1.0: only soldiers past
        // position 0.60 are eligible.
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
        // advanced reaches 0.70
        _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))
        let fresh = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

        let result = combat.tick(deltaTime: 0.05, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

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
            let result = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000_000))
            for shot in result.towerShots {
                hitSoldierIDs.insert(shot.soldierID)
            }
        }

        // Over 30 shots with a seeded RNG, both occupied lanes get hit.
        #expect(hitSoldierIDs.contains(left))
        #expect(hitSoldierIDs.contains(right))
    }

    @Test func falconridgeDefensiveFireBeginsAtSourceRelativeThreshold() {
        // Falconridge source (Tower) progress 0.68, range 0.55 → threshold 0.13.
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 100,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 2,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0.55,
            maxDeltaTime: 1.0
        )

        var atThreshold = BattleCombatState(configuration: config, seed: 1)
        _ = atThreshold.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        // The first tick crosses the 0.13 threshold (defensive fire checks the
        // pre-move position); the next tick fires from the crossed position.
        _ = atThreshold.tick(deltaTime: 0.13, siege: SiegeFixtures.falconridgeSnapshot())
        let reached = atThreshold.tick(deltaTime: 0.1, siege: SiegeFixtures.falconridgeSnapshot())
        #expect(reached.towerShots.count == 1)

        var justShort = BattleCombatState(configuration: config, seed: 1)
        _ = justShort.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = justShort.tick(deltaTime: 0.12, siege: SiegeFixtures.falconridgeSnapshot())
        let short = justShort.tick(deltaTime: 0.1, siege: SiegeFixtures.falconridgeSnapshot())
        #expect(short.towerShots.isEmpty)
    }

    @Test func leftRouteArcherAttackingTowerRemainsInsideCoverage() throws {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.12,
                soldierMovementSpeed: 1.0,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.55,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .left)

        // Archer stops at 0.68 - 0.264 ≈ 0.416, well past the 0.13 threshold.
        // Fire checks the pre-move position, so the shot lands on the tick
        // after the archer advances into range.
        _ = combat.tick(deltaTime: 0.5, siege: SiegeFixtures.falconridgeSnapshot())
        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.falconridgeSnapshot())

        #expect(result.towerShots.count == 1)
    }

    @Test func deadTowerEmitsNoLaterShots() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 100,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 1.0,
                towerDamage: 2,
                towerAttackSpeed: 1.0,
                towerAttackRange: 0.55,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)

        let deadTower = SiegeFixtures.falconridgeSnapshot(towerRemaining: 0)
        let firstTick = combat.tick(deltaTime: 1.0, siege: deadTower)
        let laterTick = combat.tick(deltaTime: 1.0, siege: deadTower)

        #expect(firstTick.towerShots.isEmpty)
        #expect(laterTick.towerShots.isEmpty)
    }

    @Test func nonPilotKeepSourcePreservesCurrentThreshold() {
        // Single-Keep source at 1.0 with range 0.55 keeps the legacy 0.45 origin.
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 100,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 2,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0.55,
            maxDeltaTime: 1.0
        )

        var atThreshold = BattleCombatState(configuration: config, seed: 1)
        _ = atThreshold.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        // Cross the legacy 0.45 threshold, then fire from it (fire checks the
        // pre-move position).
        _ = atThreshold.tick(deltaTime: 0.45, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))
        let reached = atThreshold.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))
        #expect(reached.towerShots.count == 1)

        var justShort = BattleCombatState(configuration: config, seed: 1)
        _ = justShort.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = justShort.tick(deltaTime: 0.44, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))
        let short = justShort.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))
        #expect(short.towerShots.isEmpty)
    }

    @Test func defensiveFireOnlyCoversAuthoredLanes() throws {
        let towerID = "coverage.tower"
        let keepID = "coverage.keep"
        let layout = CitySiegeLayout(
            objectives: [
                .init(id: keepID, kind: .keep, durabilityWeight: 1, visualLane: .center, visualProgress: 1.0),
                .init(id: towerID, kind: .arrowTower, durabilityWeight: 1, visualLane: .left, visualProgress: 0.68)
            ],
            routes: [
                .left: [towerID, keepID],
                .center: [keepID],
                .right: [keepID]
            ],
            defaultLane: .center,
            defensiveFire: .init(sourceObjectiveID: towerID, coveredLanes: [.left])
        )
        func snapshot() -> BattleCombatState.SiegeSnapshot {
            BattleCombatState.SiegeSnapshot(
                layout: layout,
                objectiveRemainingPower: [keepID: 20, towerID: 23]
            )
        }
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 100,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 2,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0.55,
            maxDeltaTime: 1.0
        )

        var uncovered = BattleCombatState(configuration: config, seed: 1)
        _ = uncovered.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        // First tick advances into range (fire checks the pre-move position),
        // second tick evaluates coverage at the advanced position.
        _ = uncovered.tick(deltaTime: 1.0, siege: snapshot())
        let uncoveredTick = uncovered.tick(deltaTime: 0.1, siege: snapshot())
        #expect(uncoveredTick.towerShots.isEmpty)

        var covered = BattleCombatState(configuration: config, seed: 1)
        _ = covered.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = covered.tick(deltaTime: 1.0, siege: snapshot())
        let coveredTick = covered.tick(deltaTime: 0.1, siege: snapshot())
        #expect(coveredTick.towerShots.count == 1)
    }

    // MARK: - Soldier lifecycle

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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 3, lane: .center)
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 20)

        let damageTick = combat.tick(deltaTime: 0.1, siege: snapshot)
        #expect(damageTick.damagedSoldierIDs == [id])
        #expect(damageTick.soldierLosses.isEmpty)
        #expect(damageTick.soldierAttacks.map(\.appliedDamage) == [3])
        #expect(damageTick.soldierAttacks.map(\.soldierID) == [id])
        #expect(try #require(combat.soldier(id: id)).currentHP == 1)

        let killTick = combat.tick(deltaTime: 0.1, siege: snapshot)
        #expect(killTick.soldierLosses.map(\.soldierID) == [id])
        #expect(killTick.soldierAttacks.isEmpty)
        #expect(combat.soldier(id: id) == nil)

        let laterTick = combat.tick(deltaTime: 0.2, siege: snapshot)
        #expect(laterTick.towerShots.isEmpty)
        #expect(laterTick.soldierAttacks.isEmpty)
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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))

        #expect(result.soldierLosses.map(\.soldierID) == [id])
        #expect(combat.livingSoldierCount == 0)
        #expect(combat.soldiers.isEmpty)
        #expect(combat.soldier(id: id) == nil)
    }

    @Test func soldierLossEventEmittedBeforePrune() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 1,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0,
                soldierMovementSpeed: 0,
                towerDamage: 10,
                towerAttackSpeed: 100.0,
                towerAttackRange: 1.0,
                maxDeltaTime: 1.0
            ),
            seed: 1
        )
        let id = combat.spawnSoldier(
            type: .archer,
            source: .building,
            level: 2,
            attackPower: 1,
            lane: .left
        )

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))

        #expect(result.soldierLosses == [
            SoldierLossEvent(
                soldierID: id,
                type: .archer,
                source: .building,
                lane: .left
            )
        ])
        #expect(combat.soldier(id: id) == nil)
        #expect(result.damagedSoldierIDs.contains(id))
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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 20)

        let firstNoTargetTick = combat.tick(deltaTime: 1.0, siege: snapshot)
        let secondNoTargetTick = combat.tick(deltaTime: 1.0, siege: snapshot)
        let entryTick = combat.tick(deltaTime: 1.0, siege: snapshot)
        #expect(firstNoTargetTick.towerShots.isEmpty)
        #expect(secondNoTargetTick.towerShots.isEmpty)
        #expect(entryTick.towerShots.isEmpty)

        let readyTick = combat.tick(deltaTime: 0.1, siege: snapshot)
        #expect(readyTick.towerShots.count == 1)
        let shot = try #require(readyTick.towerShots.first)
        #expect(shot.soldierID == id)
        #expect(try #require(combat.soldier(id: id)).currentHP == 9)

        let tooSoonTick = combat.tick(deltaTime: 0.1, siege: snapshot)
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
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)

        _ = combat.tick(deltaTime: 10.0, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 20))

        #expect(try #require(combat.soldier(id: id)).position == 0.25)
    }

    // MARK: - Explicit spawn lanes (HPA-468 §3.4)

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
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000)

        _ = combat.tick(deltaTime: 0.2, siege: snapshot)
        _ = combat.tick(deltaTime: 0.2, siege: snapshot)

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

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

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

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

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

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

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

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(try #require(result.towerShots.first).damage == 1)
    }

    @Test func singleOccupiedLaneDoesNotConsumeRNG() throws {
        // When only one lane has soldiers in defensive-fire range, the lane
        // short-circuit must NOT advance the RNG. Verify by aligning two
        // same-seed states on an identical single-lane shot, then comparing
        // their subsequent multi-lane random lane choice.
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 100,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 0,
            towerDamage: 1,
            towerAttackSpeed: 1.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
        let snapshot = SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000)

        var stateA = BattleCombatState(configuration: config, seed: 42)
        _ = stateA.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let shotA = stateA.tick(deltaTime: 0.1, siege: snapshot)
        #expect(shotA.towerShots.count == 1) // confirm fire actually happened

        var stateB = BattleCombatState(configuration: config, seed: 42)
        _ = stateB.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let shotB = stateB.tick(deltaTime: 0.1, siege: snapshot)
        #expect(shotB.towerShots.count == 1)

        // Both states now add two more occupied lanes and re-fire on the same
        // tick. If the single-lane shots consumed no RNG, the seeded choice
        // among three lanes is identical in both states.
        var targetA: Set<BattleCombatState.SoldierID> = []
        var targetB: Set<BattleCombatState.SoldierID> = []
        for _ in 0..<8 {
            _ = stateA.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
            _ = stateA.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
            _ = stateB.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
            _ = stateB.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

            let tickA = stateA.tick(deltaTime: 1.0, siege: snapshot)
            let tickB = stateB.tick(deltaTime: 1.0, siege: snapshot)
            guard let chosenA = tickA.towerShots.first?.soldierID,
                  let chosenB = tickB.towerShots.first?.soldierID else {
                continue
            }
            targetA.insert(chosenA)
            targetB.insert(chosenB)
        }

        // Every round picked the same lane-side target in both states; over
        // eight rounds the choice varied (both lanes exercised) while staying
        // identical between the two states.
        #expect(targetA == targetB)
        #expect(targetA.count > 1)
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

/// Test fixtures for the ephemeral siege snapshot input (HPA-468).
private enum SiegeFixtures {
    static var keepID: String { falconridgeID(.keep) }
    static var towerID: String { falconridgeID(.arrowTower) }
    static var gateID: String { falconridgeID(.gate) }

    /// Keep objective ID of the non-pilot single-Keep layout (distinct from
    /// Falconridge's `"falconridge.keep"`); use with `singleKeepSnapshot`.
    static var singleKeepID: String {
        CitySiegeLayout.singleKeep(defaultLane: .center).keepObjective.id
    }

    static func falconridgeID(_ kind: CitySiegeLayout.ObjectiveKind) -> String {
        Country1CityCatalog.definition(for: 3).siegeLayout.objectives.first { $0.kind == kind }!.id
    }

    static func singleKeepSnapshot(keepRemaining: Int) -> BattleCombatState.SiegeSnapshot {
        let layout = CitySiegeLayout.singleKeep(defaultLane: .center)
        return BattleCombatState.SiegeSnapshot(
            layout: layout,
            objectiveRemainingPower: [layout.keepObjective.id: max(0, keepRemaining)]
        )
    }

    static func falconridgeSnapshot(
        keepRemaining: Int = 35,
        towerRemaining: Int = 46,
        gateRemaining: Int = 11
    ) -> BattleCombatState.SiegeSnapshot {
        BattleCombatState.SiegeSnapshot(
            layout: Country1CityCatalog.definition(for: 3).siegeLayout,
            objectiveRemainingPower: [
                falconridgeID(.keep): max(0, keepRemaining),
                falconridgeID(.arrowTower): max(0, towerRemaining),
                falconridgeID(.gate): max(0, gateRemaining)
            ]
        )
    }
}
