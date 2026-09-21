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
        // short-circuit must NOT advance the RNG. stateA takes a real
        // single-lane shot; same-seed stateB is the control and skips that
        // tick entirely, so it never enters the lane-choice path. The states
        // stay equivalent for the comparison: movement speed is 0 so
        // positions match, and each comparison tick lasts the full tower
        // interval so both towers fire despite A's post-shot cooldown. If
        // the single-lane branch ever consumes RNG, A's stream sits a draw
        // ahead of B's and the multi-lane choices below diverge.
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
        // No single-lane tick for the control: B's RNG stays at the shared
        // pre-shot position.

        // Both states now add two more occupied lanes and re-fire on the same
        // tick. If A's single-lane shot consumed no RNG, the seeded choice
        // among three lanes is identical in both states; if it did, A's
        // stream is offset from B's and the per-round choices diverge.
        // Per-round comparison is required: aggregated sets stay equal even
        // when the streams are offset, because both still cover the lanes.
        var choicesA: [BattleCombatState.SoldierID] = []
        var choicesB: [BattleCombatState.SoldierID] = []
        for _ in 0..<8 {
            _ = stateA.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
            _ = stateA.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
            _ = stateB.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
            _ = stateB.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)

            let tickA = stateA.tick(deltaTime: 1.0, siege: snapshot)
            let tickB = stateB.tick(deltaTime: 1.0, siege: snapshot)
            choicesA.append(try #require(tickA.towerShots.first?.soldierID))
            choicesB.append(try #require(tickB.towerShots.first?.soldierID))
        }

        // Every round picked the same target in both states; over eight
        // rounds the choice varied (both lanes exercised) while staying
        // identical between the two states.
        #expect(choicesA == choicesB)
        #expect(Set(choicesA).count > 1)
    }

    // MARK: - Lane-local Guards (HPA-469)

    private func guardCombatConfiguration(soldierMaxHP: Int = 10) -> BattleCombatState.Configuration {
        BattleCombatState.Configuration(
            soldierMaxHP: soldierMaxHP,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0.12,
            soldierMovementSpeed: 0.40,
            towerDamage: 0,
            towerAttackSpeed: 1.0,
            towerAttackRange: 0,
            maxDeltaTime: 1.0
        )
    }

    @Test func restoredGuardKeepsLaneAndHPButStartsAtKeepProgress() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let snapshot = SiegeFixtures.highcrestSnapshot()

        let guardID = combat.restoreGuard(GuardSnapshot(lane: .right, remainingHP: 5), siege: snapshot)

        #expect(combat.guards.count == 1)
        let restored = combat.guards[0]
        #expect(restored.id == guardID)
        #expect(restored.lane == .right)
        #expect(restored.currentHP == 5)
        #expect(restored.maxHP == HighcrestGuardRules.maxHP)
        #expect(restored.position == snapshot.layout.keepObjective.visualProgress)
        #expect(combat.guardSnapshots == [GuardSnapshot(lane: .right, remainingHP: 5)])
    }

    @Test func rightLaneSoldierBeyondBarracksStillMeetsLaterKeepSpawnedGuard() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let soldier = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2, lane: .right)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }

        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var metGuard = false
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if !result.guardAttacks.isEmpty {
                metGuard = true
                #expect(result.guardAttacks.map(\.soldierID) == [soldier])
                #expect(result.guardAttacks.map(\.appliedDamage) == [HighcrestGuardRules.attackPower])
                break
            }
        }

        #expect(metGuard)
        #expect(try #require(combat.soldier(id: soldier)).currentHP == 10 - HighcrestGuardRules.attackPower)
    }

    @Test func guardNeverDescendsBelowBarracksProgress() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        for _ in 0..<5 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
            #expect(combat.guards[0].position >= SiegeFixtures.highcrestBarracksProgress)
        }
        #expect(combat.guards[0].position == SiegeFixtures.highcrestBarracksProgress)
    }

    @Test func guardWithoutBarracksLayoutClosesToItsOwnRangeOfTheSoldier() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let soldier = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .center)
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000)
        )

        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))
        }

        // No barracks objective → floor 0: the guard closes past where the
        // Highcrest Barracks would stand, up to its own attack range.
        let soldierPosition = try #require(combat.soldier(id: soldier)).position
        #expect(combat.guards[0].position < SiegeFixtures.highcrestBarracksProgress)
        #expect(combat.guards[0].position - soldierPosition <= HighcrestGuardRules.attackRange + 0.001)
    }

    @Test func soldierAndGuardMovementNeverCross() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 100))
        // The archer stalls at the Barracks on the .left route; the Guard
        // descends from the Keep to its Barracks floor + range stop and can
        // never cross the parked archer.
        let soldier = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .left)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        combat.restoreGuard(
            GuardSnapshot(lane: .left, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var guardReachedStop = false
        for _ in 0..<12 {
            _ = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            let soldierPosition = try #require(combat.soldier(id: soldier)).position
            let guardPosition = combat.guards[0].position
            #expect(guardPosition > soldierPosition)
            #expect(guardPosition - soldierPosition >= HighcrestGuardRules.attackRange - 0.001)
            if abs(guardPosition - soldierPosition - HighcrestGuardRules.attackRange) < 0.001 {
                guardReachedStop = true
            }
        }
        #expect(guardReachedStop)
    }

    /// Guard-engagement invariant (Highcrest route-balance pass): a Guard
    /// clamped at the Barracks floor attacks an archer stalled at the
    /// Barracks stall position (`barracksProgress − archerRange`), so
    /// Barracks chewers are never unopposed once a Guard is on the lane.
    @Test func floorClampedGuardAttacksArcherStalledAtBarracksStallPosition() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let archer = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .left)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        // The archer is parked exactly at its own range below the Barracks.
        let archerRange = try #require(combat.soldier(id: archer)).attackRange
        let stallPosition = SiegeFixtures.highcrestBarracksProgress - archerRange
        #expect(combat.soldier(id: archer)?.position == stallPosition)

        combat.restoreGuard(
            GuardSnapshot(lane: .left, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var guardAttacks = 0
        for _ in 0..<12 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            guardAttacks += result.guardAttacks.count
            if guardAttacks > 0 {
                #expect(result.guardAttacks.allSatisfy { $0.soldierID == archer })
                break
            }
        }

        #expect(guardAttacks >= 1)
    }

    @Test func guardAttacksOnlyTheForemostSoldierInItsLane() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let foremost = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .right)
        _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        let trailing = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
        _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var attack: BattleCombatState.GuardAttackEvent?
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if let first = result.guardAttacks.first {
                #expect(result.guardAttacks.count == 1)
                attack = first
                break
            }
        }

        #expect(try #require(attack).soldierID == foremost)
        let trailingActor = try #require(combat.soldier(id: trailing))
        #expect(trailingActor.currentHP == trailingActor.maxHP)
        let foremostActor = try #require(combat.soldier(id: foremost))
        #expect(foremostActor.currentHP == foremostActor.maxHP - HighcrestGuardRules.attackPower)
    }

    @Test func guardNeverTargetsAnotherLaneOrPlayerCastle() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let soldier = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .center)
        let soldierFullHP = try #require(combat.soldier(id: soldier)).maxHP
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var lastResult: BattleCombatState.TickResult?
        for _ in 0..<2 {
            let result = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
            #expect(result.guardAttacks.isEmpty)
            #expect(result.damagedSoldierIDs.isEmpty)
            #expect(try #require(combat.soldier(id: soldier)).currentHP == soldierFullHP)
            lastResult = result
        }

        // The center-lane soldier damages the castle only through its own
        // soldier attacks; the right-lane guard holds at Keep progress.
        let final = try #require(lastResult)
        #expect(!final.soldierAttacks.isEmpty)
        #expect(final.soldierAttacks.allSatisfy { $0.soldierID == soldier })
        #expect(combat.guards[0].position == SiegeFixtures.highcrestSnapshot().layout.keepObjective.visualProgress)
    }

    @Test func deadGuardEmitsOneLossAndSurvivorsResumeStructureTargeting() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let soldier = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 6, lane: .right)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        let guardID = combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: 3),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var killResult: BattleCombatState.TickResult?
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if !result.guardLosses.isEmpty {
                killResult = result
                break
            }
        }

        let kill = try #require(killResult)
        #expect(kill.guardLosses == [BattleCombatState.GuardLossEvent(guardID: guardID, lane: .right)])
        #expect(kill.soldierAttacks.isEmpty)
        #expect(combat.guardSnapshots.isEmpty)

        // A full attack interval later the survivor's cooldown is ready again.
        let next = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        #expect(next.guardLosses.isEmpty)
        #expect(next.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.highcrestKeepID])
        #expect(try #require(combat.soldier(id: soldier)).isAlive)
    }

    @Test func livingGuardStillFunctionsAfterBarracksDestruction() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        _ = combat.spawnSoldier(type: .archer, source: .manual, level: 1, attackPower: 1, lane: .right)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot(barracksRemaining: 0))
        }
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot(barracksRemaining: 0)
        )

        var attacked = false
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot(barracksRemaining: 0))
            if !result.guardAttacks.isEmpty {
                attacked = true
                break
            }
        }

        #expect(attacked)
    }

    @Test func keepDestructionWinsImmediatelyWithoutGuardCleanup() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 30, lane: .right)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        combat.restoreGuard(
            GuardSnapshot(lane: .left, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot(keepRemaining: 20))

        #expect(result.didReachConquest)
        #expect(result.soldierAttacks.map(\.objectiveID) == [SiegeFixtures.highcrestKeepID])
        #expect(result.guardLosses.isEmpty)
        #expect(combat.guardSnapshots == [GuardSnapshot(lane: .left, remainingHP: HighcrestGuardRules.maxHP)])
    }

    @Test func emptyGuardRosterPreservesExistingTowerMovementAttackBehavior() {
        var combat = BattleCombatState(
            configuration: BattleCombatState.Configuration(
                soldierMaxHP: 10,
                soldierDefense: 0,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.12,
                soldierMovementSpeed: 0.40,
                towerDamage: 2,
                towerAttackSpeed: 100.0,
                towerAttackRange: 0.55,
                maxDeltaTime: 1.0
            )
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 3, lane: .center)

        var shots = 0
        var attacks = 0
        for _ in 0..<3 {
            let result = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
            shots += result.towerShots.count
            attacks += result.soldierAttacks.count
            #expect(result.guardAttacks.isEmpty)
            #expect(result.guardHits.isEmpty)
            #expect(result.guardLosses.isEmpty)
        }

        #expect(shots >= 1)
        #expect(attacks >= 1)
        #expect(combat.guardSnapshots.isEmpty)
    }

    @Test func eachSoldierTypeAttacksClosingGuardWithinItsOwnRangeBeforeRetaliation() throws {
        // marchTicks marches the soldier toward the Keep before the Guard
        // exists; closingDelta then closes the Guard from Keep progress just
        // far enough that the soldier's OWN range is satisfied while the
        // Guard's wider 0.28 range is not (the Guard resolves its attacks
        // before the soldier advances this tick, so the pre-advance gap must
        // stay above 0.28).
        let cases: [GuardClosingChoreography] = [
            .init(type: .infantry, marchTicks: 1, closingDelta: 0.70),
            .init(type: .archer, marchTicks: 1, closingDelta: 0.50),
            .init(type: .cavalry, marchTicks: 1, closingDelta: 0.42),
            .init(type: .mage, marchTicks: 1, closingDelta: 0.65),
            .init(type: .siege, marchTicks: 2, closingDelta: 0.80)
        ]

        for testCase in cases {
            var combat = BattleCombatState(configuration: guardCombatConfiguration())
            let soldier = combat.spawnSoldier(
                type: testCase.type,
                source: .manual,
                level: 1,
                attackPower: 2,
                lane: .right
            )
            for _ in 0..<testCase.marchTicks {
                _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
            }
            combat.restoreGuard(
                GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
                siege: SiegeFixtures.highcrestSnapshot()
            )

            let result = combat.tick(deltaTime: testCase.closingDelta, siege: SiegeFixtures.highcrestSnapshot())

            #expect(result.guardHits.map(\.soldierID) == [soldier])
            #expect(result.guardHits.map(\.type) == [testCase.type])
            #expect(result.guardHits.map(\.appliedDamage) == [2])
            #expect(result.guardAttacks.isEmpty)
            #expect(try #require(combat.guardSnapshots.first).remainingHP
                == HighcrestGuardRules.maxHP - 2)
        }
    }

    @Test func guardKillsFlowOnlyThroughExistingSoldierDamageEvents() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let soldier = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
        for _ in 0..<2 {
            _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        }
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        // March the guard down onto the parked soldier until a guard attack
        // kills it; that damage must surface only through the existing
        // damagedSoldierIDs / soldierLosses channels.
        var killedByGuard = false
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            #expect(result.soldierAttacks.isEmpty || result.soldierAttacks.allSatisfy { $0.soldierID == soldier })
            if !result.soldierLosses.isEmpty {
                killedByGuard = true
                #expect(result.soldierLosses.map(\.soldierID) == [soldier])
                #expect(result.damagedSoldierIDs.contains(soldier))
                #expect(!result.guardAttacks.isEmpty)
                break
            }
        }

        #expect(killedByGuard)
    }

    // MARK: - Vanguard Captain (HPA-475)

    @Test func ordinarySpawnedSoldierIsNotCaptain() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2, lane: .center)

        #expect(try #require(combat.soldier(id: id)).isCaptain == false)
        #expect(combat.captainSoldier == nil)
    }

    @Test func spawnCaptainCreatesExactlyOneFlaggedSoldierAndSecondCallIsNoOp() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress.freshCaptain(selectedLane: .left, upgradeLevel: 1)

        let firstID = combat.spawnCaptain(progress: progress, upgradeLevel: 1)
        let secondID = combat.spawnCaptain(progress: progress, upgradeLevel: 1)

        #expect(firstID != nil)
        #expect(secondID == firstID)
        #expect(combat.soldiers.filter(\.isCaptain).count == 1)
        #expect(combat.captainSoldier?.id == firstID)
    }

    @Test func captainRestoresPersistedLaneAndHPAtPositionZero() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress(
            lane: .right,
            remainingHP: 7,
            recoveryRemainingSeconds: 0,
            rallyConsumed: false
        )

        let spawned = combat.spawnCaptain(progress: progress, upgradeLevel: 2)
        let id = try #require(spawned)
        let captain = try #require(combat.soldier(id: id))

        #expect(captain.lane == .right)
        #expect(captain.currentHP == 7)
        #expect(captain.position == 0)
    }

    @Test func captainClampsRestoredHPToCaptainMax() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 999,
            recoveryRemainingSeconds: 0,
            rallyConsumed: false
        )

        let spawned = combat.spawnCaptain(progress: progress, upgradeLevel: 2)
        let id = try #require(spawned)
        let captain = try #require(combat.soldier(id: id))

        #expect(captain.maxHP == VanguardCaptainRules.maxHP(for: 2))
        #expect(captain.currentHP == VanguardCaptainRules.maxHP(for: 2))
    }

    @Test func captainUsesInfantryRuntimeStatsButCaptainHPAndAttackFormulas() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 2)

        let spawned = combat.spawnCaptain(progress: progress, upgradeLevel: 2)
        let captainID = try #require(spawned)
        let infantryID = combat.spawnSoldier(
            type: .infantry,
            source: .manual,
            level: 2,
            attackPower: KingdomGameState.normalSoldierAttackPower(for: 2),
            lane: .center
        )
        let captain = try #require(combat.soldier(id: captainID))
        let infantry = try #require(combat.soldier(id: infantryID))

        #expect(captain.type == .infantry)
        #expect(captain.source == .manual)
        #expect(captain.level == 2)
        #expect(captain.movementSpeed == infantry.movementSpeed)
        #expect(captain.attackRange == infantry.attackRange)
        #expect(captain.attackSpeed == infantry.attackSpeed)
        #expect(captain.defense == infantry.defense)
        // Captain formulas, not the configuration soldier curve.
        #expect(captain.maxHP == VanguardCaptainRules.maxHP(for: 2))
        #expect(captain.maxHP != infantry.maxHP)
        #expect(captain.attackPower == VanguardCaptainRules.attackPower(for: 2))
    }

    @Test func secondSpawnCaptainWithDifferentLaneDoesNotMoveLiveCaptain() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress.freshCaptain(selectedLane: .left, upgradeLevel: 1)
        let spawned = combat.spawnCaptain(progress: progress, upgradeLevel: 1)
        let id = try #require(spawned)

        let relane = VanguardCaptainProgress(
            lane: .right,
            remainingHP: 3,
            recoveryRemainingSeconds: 0,
            rallyConsumed: false
        )
        let secondID = combat.spawnCaptain(progress: relane, upgradeLevel: 1)

        #expect(secondID == id)
        let captain = try #require(combat.soldier(id: id))
        #expect(captain.lane == .left)
        #expect(captain.currentHP == VanguardCaptainRules.maxHP(for: 1))
    }

    @Test func spawnCaptainWithDepletedHPDeploysNothing() {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress(
            lane: .center,
            remainingHP: 0,
            recoveryRemainingSeconds: VanguardCaptainRules.recoverySeconds,
            rallyConsumed: false
        )

        let id = combat.spawnCaptain(progress: progress, upgradeLevel: 1)

        #expect(id == nil)
        #expect(combat.captainSoldier == nil)
    }

    @Test func captainMarchesRouteHitsGuardThenStructureThroughExistingLoop() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let progress = VanguardCaptainProgress.freshCaptain(selectedLane: .right, upgradeLevel: 1)
        let spawned = combat.spawnCaptain(progress: progress, upgradeLevel: 1)
        let captainID = try #require(spawned)
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: 2),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var sawCaptainGuardHit = false
        var sawCaptainStructureAttack = false
        for _ in 0..<60 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if result.guardHits.contains(where: { $0.soldierID == captainID }) {
                sawCaptainGuardHit = true
                #expect(result.guardHits.allSatisfy { $0.type == .infantry })
            }
            if result.soldierAttacks.contains(where: {
                $0.soldierID == captainID && $0.objectiveID == SiegeFixtures.highcrestKeepID
            }) {
                sawCaptainStructureAttack = true
                #expect(result.soldierAttacks.allSatisfy { $0.isCaptain })
                break
            }
        }

        #expect(sawCaptainGuardHit)
        #expect(sawCaptainStructureAttack)
        #expect(try #require(combat.captainSoldier).isCaptain)
    }

    @Test func guardTargetsCaptainOverEqualPositionOrdinarySoldier() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let ordinary = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let spawned = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        let captainID = try #require(spawned)
        // One tick so both equal-speed infantry sit at the same position.
        _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.highcrestSnapshot())
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var attack: BattleCombatState.GuardAttackEvent?
        for _ in 0..<20 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if let first = result.guardAttacks.first {
                #expect(result.guardAttacks.count == 1)
                attack = first
                break
            }
        }

        #expect(try #require(attack).soldierID == captainID)
        let ordinaryActor = try #require(combat.soldier(id: ordinary))
        #expect(ordinaryActor.currentHP == ordinaryActor.maxHP)
    }

    @Test func towerTargetsCaptainOverEqualPositionOrdinarySoldier() throws {
        let towerID = "captain.tie.tower"
        let keepID = "captain.tie.keep"
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
        let snapshot = BattleCombatState.SiegeSnapshot(
            layout: layout,
            objectiveRemainingPower: [keepID: 20, towerID: 23]
        )
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 100,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 2,
            towerAttackSpeed: 1.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )

        var combat = BattleCombatState(configuration: config, seed: 1)
        let ordinary = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        let spawned = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .left, upgradeLevel: 1),
            upgradeLevel: 1
        )
        let captainID = try #require(spawned)

        let result = combat.tick(deltaTime: 1.0, siege: snapshot)

        #expect(result.towerShots.count == 1)
        #expect(result.towerShots[0].soldierID == captainID)
        #expect(result.damagedSoldierIDs == [captainID])
        let ordinaryActor = try #require(combat.soldier(id: ordinary))
        #expect(ordinaryActor.currentHP == ordinaryActor.maxHP)
    }

    @Test func towerKillEmitsFlaggedCaptainLossWithoutOrdinaryCountChange() throws {
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 10,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0.12,
            soldierMovementSpeed: 0.40,
            towerDamage: 999,
            towerAttackSpeed: 1.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
        var combat = BattleCombatState(configuration: config, seed: 1)
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        let spawned = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .left, upgradeLevel: 1),
            upgradeLevel: 1
        )
        let captainID = try #require(spawned)

        let result = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.falconridgeSnapshot())

        #expect(result.soldierLosses.map(\.soldierID) == [captainID])
        #expect(result.soldierLosses.map(\.isCaptain) == [true])
        // Retreat never enters ordinary soldier counts.
        #expect(combat.livingSoldierCount == 1)
        #expect(combat.captainSoldier == nil)
    }

    @Test func livingSoldierCountsExcludeCaptain() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )

        #expect(combat.livingSoldierCount == 1)
        #expect(combat.livingSoldierCount(source: .manual) == 1)
    }

    @Test func ordinaryAttackEventsDefaultToFalseCaptainFlag() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 2, lane: .right)

        var ordinaryAttack: SoldierAttackEvent?
        for _ in 0..<30 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if let attack = result.soldierAttacks.first(where: { $0.soldierID == id }) {
                ordinaryAttack = attack
                break
            }
        }

        let attack = try #require(ordinaryAttack)
        #expect(attack.objectiveID == SiegeFixtures.highcrestKeepID)
        #expect(attack.isCaptain == false)
        // Explicit defaulted initializers keep existing constructors concise.
        #expect(
            SoldierLossEvent(soldierID: 1, type: .infantry, source: .manual, lane: .center).isCaptain == false
        )
    }

    // MARK: - Rally (HPA-475 Task 3)

    private func towerRallyConfiguration(
        towerDamage: Int,
        soldierMaxHP: Int = 20,
        defense: Int = 1,
        laneMultipliers: [BattleLane: Double] = [:]
    ) -> BattleCombatState.Configuration {
        BattleCombatState.Configuration(
            soldierMaxHP: soldierMaxHP,
            soldierDefense: defense,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 0,
            towerDamage: towerDamage,
            towerAttackSpeed: 1.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 5.0,
            laneDamageMultipliers: laneMultipliers
        )
    }

    @Test func startRallyArmsFiveSecondTimer() {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5))

        #expect(combat.rallyRemainingSeconds == 0)
        combat.startRally(lane: .center)

        #expect(combat.rallyRemainingSeconds == VanguardCaptainRules.rallyDurationSeconds)
        #expect(combat.rallyRemainingSeconds == 5.0)
    }

    @Test func rallyTimerExpiresDeterministicallyAndProtectionEndsWithIt() throws {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5), seed: 1)
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        combat.startRally(lane: .center)

        let first = combat.tick(deltaTime: 2.5, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))
        let second = combat.tick(deltaTime: 2.5, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(combat.rallyRemainingSeconds == 0)
        // Protected hit: base 4 × 0.70 = 2.8 → 3; expired hit: full 4.
        #expect(try #require(first.towerShots.first).damage == 3)
        #expect(try #require(second.towerShots.first).damage == 4)
        #expect(try #require(combat.soldier(id: id)).currentHP == 13)
    }

    @Test func startRallyWhileActiveDoesNotStackOrRestart() {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5))
        combat.startRally(lane: .center)
        _ = combat.tick(deltaTime: 1.0, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        combat.startRally(lane: .center)

        // The running timer is neither extended nor reset to 5s.
        #expect(combat.rallyRemainingSeconds == 4.0)
    }

    @Test func rallyReducesTowerDamageOnlyInCapturedLane() throws {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5), seed: 1)
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        combat.startRally(lane: .left)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(try #require(result.towerShots.first).damage == 3)
        #expect(try #require(combat.soldier(id: id)).currentHP == 17)
    }

    @Test func rallyDoesNotReduceTowerDamageOffLane() throws {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5), seed: 1)
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
        combat.startRally(lane: .left)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(try #require(result.towerShots.first).damage == 4)
        #expect(try #require(combat.soldier(id: id)).currentHP == 16)
    }

    @Test func rallyNeverReducesCaptainTowerDamage() throws {
        var combat = BattleCombatState(configuration: towerRallyConfiguration(towerDamage: 5), seed: 1)
        let spawned = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        let captainID = try #require(spawned)
        combat.startRally(lane: .center)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(try #require(result.towerShots.first).damage == 4)
        let captain = try #require(combat.soldier(id: captainID))
        #expect(captain.currentHP == captain.maxHP - 4)
    }

    @Test func rallyTowerReductionPinsNeutralLaneTable() throws {
        // One round of (base × 1.0 × 0.70): 1→1, 2→1, 3→2, 4→3.
        for (baseDamage, expectedDamage) in [(1, 1), (2, 1), (3, 2), (4, 3)] {
            var combat = BattleCombatState(
                configuration: towerRallyConfiguration(towerDamage: baseDamage, defense: 0),
                seed: 1
            )
            _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
            combat.startRally(lane: .center)

            let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

            #expect(try #require(result.towerShots.first).damage == expectedDamage)
        }
    }

    @Test func rallyFoldsIntoLaneMultiplierBeforeSingleRound() throws {
        // base 6 × fortified 1.25 × rally 0.70 = 5.25 → 5 in one rounding.
        // Rounding lane damage first (8) then Rally would give 6.
        var combat = BattleCombatState(
            configuration: towerRallyConfiguration(
                towerDamage: 7,
                laneMultipliers: [.left: 1.25, .center: 1.0, .right: 0.80]
            ),
            seed: 1
        )
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .left)
        combat.startRally(lane: .left)

        let result = combat.tick(deltaTime: 0.1, siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000))

        #expect(try #require(result.towerShots.first).damage == 5)
    }

    @Test func rallyReducesGuardDamageBeforeHPClamp() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 8))
        let id = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .center)
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )
        combat.startRally(lane: .center)

        var appliedDamages: [Int] = []
        for _ in 0..<50 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            appliedDamages.append(contentsOf: result.guardAttacks.map(\.appliedDamage))
            if !result.soldierLosses.isEmpty {
                break
            }
        }

        // 3 × 0.70 = 2.1 → 2 before the current-HP clamp: 8→6→4→2, then the
        // killing hit at pre-HP 2 clamps to 2 and kills. Clamping first would
        // give min(3,2)=2 → round(2×0.7)=1 on that hit: [2, 2, 2, 1].
        #expect(appliedDamages == [2, 2, 2, 2])
        #expect(combat.soldier(id: id) == nil)
    }

    @Test func rallyDoesNotReduceGuardDamageOffLane() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 11))
        _ = combat.spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: 1, lane: .right)
        combat.restoreGuard(
            GuardSnapshot(lane: .right, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )
        combat.startRally(lane: .left)

        var firstAttack: BattleCombatState.GuardAttackEvent?
        for _ in 0..<50 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if let attack = result.guardAttacks.first {
                firstAttack = attack
                break
            }
        }

        #expect(try #require(firstAttack).appliedDamage == 3)
    }

    @Test func rallyNeverReducesGuardDamageToCaptain() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration())
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )
        combat.startRally(lane: .center)

        var firstAttack: BattleCombatState.GuardAttackEvent?
        for _ in 0..<50 {
            let result = combat.tick(deltaTime: 0.25, siege: SiegeFixtures.highcrestSnapshot())
            if let attack = result.guardAttacks.first {
                firstAttack = attack
                break
            }
        }

        #expect(try #require(firstAttack).appliedDamage == 3)
    }

    /// Auto-Rally harness facts (HPA-475): same-lane soldiers converge to
    /// one stall point, where the Task-2 tie-break makes the Captain tank
    /// forever — so the choreography must produce the threshold crossing on
    /// an early hit while the ordinary soldier is still strictly foremost.
    /// Cavalry's 1.45× march speed keeps it ahead until the stall.
    @Test func autoRallyRequestedWhenSameLaneOrdinaryCrossesHalfFromTowerHit() throws {
        // Cavalry 5 HP (half 2.5); tower fires every tick (interval 0.25s):
        // tick 1 hits the Captain on the spawn tie, tick 2 hits the ahead-
        // cavalry for 5→2 (crossing), tick 3 kills the below-half cavalry.
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 5,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 3,
            towerAttackSpeed: 4.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
        var combat = BattleCombatState(configuration: config, seed: 1)
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )

        var requestCount = 0
        for _ in 0..<20 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
                #expect(result.towerShots.allSatisfy { $0.damage == 3 })
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 1)
    }

    @Test func autoRallyRequestedWhenSameLaneOrdinaryCrossesHalfFromGuardHit() throws {
        // Cavalry 5 HP (half 2.5): the first Guard hit (tick 5, 1.25s) lands
        // before the stall tie → 5→2 crossing. After the tie the Captain
        // tanks, so no further ordinary hits can re-request.
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 5))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var requestCount = 0
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
                #expect(result.guardAttacks.allSatisfy { $0.appliedDamage == 3 })
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 1)
    }

    @Test func autoRallyNotRequestedWhenHitKillsFromAtOrAboveHalf() throws {
        // towerDamage 5 kills the 5-HP cavalry from full (≥ half) on tick 2
        // while the Captain (hit for 5 on the tick-1 spawn tie) stays alive.
        let config = BattleCombatState.Configuration(
            soldierMaxHP: 5,
            soldierDefense: 0,
            soldierAttackSpeed: 1.0,
            soldierAttackRange: 0,
            soldierMovementSpeed: 1.0,
            towerDamage: 5,
            towerAttackSpeed: 4.0,
            towerAttackRange: 1.0,
            maxDeltaTime: 1.0
        )
        var combat = BattleCombatState(configuration: config, seed: 1)
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        let spawnedCaptainID = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        let captainID = try #require(spawnedCaptainID)

        let result = combat.tick(
            deltaTime: 0.25,
            siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000),
            rallyAutoTriggerAvailable: true
        )
        let secondResult = combat.tick(
            deltaTime: 0.25,
            siege: SiegeFixtures.singleKeepSnapshot(keepRemaining: 1_000),
            rallyAutoTriggerAvailable: true
        )

        #expect(!result.shouldAutoActivateRally)
        #expect(!secondResult.shouldAutoActivateRally)
        #expect(secondResult.soldierLosses.map(\.soldierID) == [cavalryID])
        #expect(try #require(combat.soldier(id: captainID)).isAlive)
    }

    @Test func autoRallyNotRequestedForWrongLaneSoldier() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 10))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .left)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .left, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var requestCount = 0
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 0)
    }

    @Test func autoRallyNotRequestedWithoutActiveCaptain() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 10))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var requestCount = 0
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 0)
    }

    @Test func autoRallyNotRequestedWhenTriggerUnavailable() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 10))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var requestCount = 0
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: false
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 0)
    }

    @Test func autoRallyNotRequestedWhileRallyAlreadyActive() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 10))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )
        combat.startRally(lane: .center)

        var requestCount = 0
        var appliedDamages: [Int] = []
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
            }
            appliedDamages.append(contentsOf: result.guardAttacks.map(\.appliedDamage))
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        // The cavalry (maxHP 9, half 4.5) crosses below half mid-sequence
        // (7→4) while Rally is active — a hit that would otherwise qualify —
        // but an active Rally never requests. The first contact hit is
        // Rally-reduced (2); exact later-hit timing is incidental guard-
        // march choreography and stays unpinned.
        #expect(requestCount == 0)
        #expect(appliedDamages.contains(2))
    }

    @Test func autoRallyRequestsAtMostOncePerTickAndLaterSameTickHitsStayUnprotected() throws {
        var combat = BattleCombatState(configuration: guardCombatConfiguration(soldierMaxHP: 10))
        let cavalryID = combat.spawnSoldier(type: .cavalry, source: .manual, level: 1, attackPower: 1, lane: .center)
        _ = combat.spawnCaptain(
            progress: VanguardCaptainProgress.freshCaptain(selectedLane: .center, upgradeLevel: 1),
            upgradeLevel: 1
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )
        combat.restoreGuard(
            GuardSnapshot(lane: .center, remainingHP: HighcrestGuardRules.maxHP),
            siege: SiegeFixtures.highcrestSnapshot()
        )

        var requestCount = 0
        for _ in 0..<50 {
            let result = combat.tick(
                deltaTime: 0.25,
                siege: SiegeFixtures.highcrestSnapshot(),
                rallyAutoTriggerAvailable: true
            )
            if result.shouldAutoActivateRally {
                requestCount += 1
                // Both same-tick Guard hits land at full power: the first
                // hit crossed the threshold, the second stayed unprotected.
                #expect(result.guardAttacks.count == 2)
                #expect(result.guardAttacks.allSatisfy { $0.appliedDamage == 3 })
            }
            if combat.soldier(id: cavalryID) == nil {
                break
            }
        }

        #expect(requestCount == 1)
    }

    private struct GuardClosingChoreography {
        let type: SoldierType
        let marchTicks: Int
        let closingDelta: Double
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

    static func highcrestID(_ kind: CitySiegeLayout.ObjectiveKind) -> String {
        Country1CityCatalog.definition(for: 5).siegeLayout.objectives.first { $0.kind == kind }!.id
    }

    static var highcrestKeepID: String { highcrestID(.keep) }

    static var highcrestBarracksProgress: Double {
        Country1CityCatalog.definition(for: 5).siegeLayout.barracksObjective!.visualProgress
    }

    static func highcrestSnapshot(
        keepRemaining: Int = 1_000,
        barracksRemaining: Int = 25
    ) -> BattleCombatState.SiegeSnapshot {
        BattleCombatState.SiegeSnapshot(
            layout: Country1CityCatalog.definition(for: 5).siegeLayout,
            objectiveRemainingPower: [
                highcrestID(.keep): max(0, keepRemaining),
                highcrestID(.barracks): max(0, barracksRemaining)
            ]
        )
    }
}
