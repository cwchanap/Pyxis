//
//  KingdomAscensionStateTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// HPA-672 Task 1: pure Ascension state, persistence normalization and the
/// `ascend()` reset/keep contract.
struct KingdomAscensionStateTests {
    // MARK: - Defaults and decode normalization

    @Test func freshStateDefaultsToZeroAscensionsAndNoLevels() {
        let state = KingdomGameState()

        #expect(state.ascensionCount == 0)
        #expect(state.equipmentLevelsByID == [:])
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == nil)
    }

    @Test func decodingSaveWithoutAscensionKeysDefaultsZeroCountAndOwnedLevelOne() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive",
          "ownedEquipmentIDs": ["c01-infantry-attack", "c02-archer-attack"]
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.ascensionCount == 0)
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 1)
        #expect(state.equipmentLevel(for: "c02-archer-attack") == 1)
        #expect(state.equipmentLevelsByID == [
            "c01-infantry-attack": 1,
            "c02-archer-attack": 1
        ])
    }

    @Test func decodingClampsNegativeCountAndOutOfRangeLevels() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive",
          "ownedEquipmentIDs": ["c01-infantry-attack", "c02-archer-attack", "c03-infantry-toughness"],
          "equipmentLevelsByID": {
            "c01-infantry-attack": 0,
            "c02-archer-attack": 2,
            "c03-infantry-toughness": 9
          },
          "ascensionCount": -3
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.ascensionCount == 0)
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 1)
        #expect(state.equipmentLevel(for: "c02-archer-attack") == 2)
        #expect(state.equipmentLevel(for: "c03-infantry-toughness") == 3)
    }

    @Test func decodingDropsUnownedAndUnknownLevelKeys() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive",
          "ownedEquipmentIDs": ["c01-infantry-attack"],
          "equipmentLevelsByID": {
            "c01-infantry-attack": 2,
            "c02-archer-attack": 3,
            "ghost-item": 3
          }
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        // Known-but-unowned and unknown IDs never receive a level.
        #expect(state.equipmentLevelsByID == ["c01-infantry-attack": 2])
        #expect(state.equipmentLevel(for: "c02-archer-attack") == nil)
        #expect(state.equipmentLevel(for: "ghost-item") == nil)
    }

    @Test func decodingMalformedAscensionFieldsDefaultsAndKeepsSiblings() throws {
        let data = Data("""
        {
          "gold": 77,
          "stageStatus": "battleActive",
          "treasury": {"warChest": 2, "drillYard": 1, "quartermaster": 0},
          "ownedEquipmentIDs": ["c01-infantry-attack"],
          "equipmentLevelsByID": "junk",
          "ascensionCount": "also junk"
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 77)
        #expect(state.treasury == TreasuryState(warChest: 2, drillYard: 1, quartermaster: 0))
        #expect(state.ascensionCount == 0)
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 1)
    }

    @Test func memberwiseInitNormalizesCountAndLevelsLikeDecode() {
        let state = KingdomGameState(
            ownedEquipmentIDs: ["c01-infantry-attack", "ghost"],
            equipmentLevelsByID: ["c01-infantry-attack": 7, "c02-archer-attack": 3],
            ascensionCount: -1
        )

        #expect(state.ascensionCount == 0)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equipmentLevelsByID == ["c01-infantry-attack": 3])
    }

    // MARK: - Ascension eligibility gates

    @Test func ascendRejectsMidCampaignStagesAsExactNoOp() {
        // Mid-siege, battle-active.
        var battleActive = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 30,
            keepRemaining: 300,
            ownedEquipmentIDs: ["c01-infantry-attack"]
        )
        battleActive.recordSoldierDeployment(type: .infantry, source: .manual, lane: .left)
        let battleActiveBefore = battleActive
        #expect(battleActive.ascend() == .unavailable)
        #expect(battleActive == battleActiveBefore)

        // Between cities, pending-map.
        var pendingMap = KingdomGameState(
            gold: 8,
            cityLevel: 2,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap,
            ascensionCount: 3
        )
        #expect(pendingMap.ascend() == .unavailable)
        #expect(pendingMap == KingdomGameState(
            gold: 8,
            cityLevel: 2,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap,
            ascensionCount: 3
        ))
    }

    @Test func ascendRejectsPendingFinalResultAsExactNoOp() throws {
        // A real City 15 conquest: completeCurrentCity leaves the finale
        // report pending — Ascension must stay gated until it is
        // acknowledged.
        var state = SiegeTestSupport.makeBattleState(atCity: 15, gold: 10, keepRemaining: 1)
        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        let attack = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: state.siegeProgress.selectedLane,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])
        #expect(attack.conqueredCities == 1)
        #expect(state.stageStatus == .countryComplete)
        #expect(state.pendingBattleResult != nil)

        let before = state
        #expect(state.ascend() == .unavailable)
        #expect(state == before)
    }

    @Test func acknowledgedFinaleUnlocksAscension() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 15, gold: 10, keepRemaining: 1)
        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: state.siegeProgress.selectedLane,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])
        state.acknowledgePendingBattleResult()

        #expect(state.ascend() == .ascended(newCount: 1))
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityNumberInCountry == 1)
    }

    @Test func repeatedAscendAfterSuccessIsUnavailableNoOp() {
        var state = Self.makeCompletedCampaignState()
        #expect(state.ascend() == .ascended(newCount: 2))

        let afterFirst = state
        #expect(state.ascend() == .unavailable)
        #expect(state == afterFirst)
    }

    // MARK: - Reset / keep matrix

    @Test func ascendResetsRunStateAndKeepsPermanentFields() {
        var state = Self.makeCompletedCampaignState()
        let ownedBefore = state.ownedEquipmentIDs
        let equippedBefore = state.equippedItemBySoldierType
        let levelsBefore = state.equipmentLevelsByID

        #expect(state.ascend() == .ascended(newCount: 2))

        // Reset to a new run.
        #expect(state.gold == 0)
        #expect(state.countryNumber == 1)
        #expect(state.cityNumberInCountry == 1)
        #expect(state.cityLevel == 1)
        #expect(state.completedCityCount == 0)
        #expect(state.stageStatus == .battleActive)
        #expect(state.cityBattleStates == [:])
        #expect(state.activeSiegeSession == nil)
        #expect(state.pendingBattleResult == nil)
        #expect(state.lastBackgroundedAt == nil)
        #expect(state.treasury == TreasuryState())
        // Fresh City 1 siege per a brand-new game: no damage, authored
        // default lane, no Captain (City 3+) and no Guards (no Barracks).
        #expect(state.siegeProgress == KingdomGameState().siegeProgress)
        #expect(state.siegeProgress.damageByObjectiveID == [:])
        #expect(state.siegeProgress.captain == nil)
        #expect(state.siegeProgress.guardReinforcements == nil)

        // Kept across Ascension.
        #expect(state.ownedEquipmentIDs == ownedBefore)
        #expect(state.equippedItemBySoldierType == equippedBefore)
        #expect(state.equipmentLevelsByID == levelsBefore)
        #expect(state.ascensionCount == 2)
        // The deliberate `None` slots stay absent, chosen slots stay chosen.
        #expect(state.equippedItemBySoldierType["infantry"] == "c01-infantry-attack")
        #expect(state.equippedItemBySoldierType["cavalry"] == nil)
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 2)
        #expect(state.equipmentLevel(for: "c15-siege-keep") == 3)
    }

    @Test func ascendedStateEqualsFreshRunExceptPermanentFields() {
        var state = Self.makeCompletedCampaignState()
        let ownedBefore = state.ownedEquipmentIDs
        let equippedBefore = state.equippedItemBySoldierType
        let levelsBefore = state.equipmentLevelsByID

        _ = state.ascend()

        // Exactly the fresh-run shape with the permanent fields copied and
        // gold explicitly 0 (a brand-new game starts at 15).
        #expect(state == KingdomGameState(
            gold: 0,
            ownedEquipmentIDs: ownedBefore,
            equippedItemBySoldierType: equippedBefore,
            equipmentLevelsByID: levelsBefore,
            ascensionCount: 2
        ))

        let fresh = KingdomGameState()
        #expect(state.siegeProgress == fresh.siegeProgress)
        #expect(state.cityBattleStates == fresh.cityBattleStates)
        #expect(state.activeSiegeSession == fresh.activeSiegeSession)
        #expect(state.pendingBattleResult == fresh.pendingBattleResult)
        #expect(state.lastBackgroundedAt == fresh.lastBackgroundedAt)
        #expect(state.treasury == fresh.treasury)
        #expect(state.countryNumber == fresh.countryNumber)
        #expect(state.cityNumberInCountry == fresh.cityNumberInCountry)
        #expect(state.cityLevel == fresh.cityLevel)
        #expect(state.completedCityCount == fresh.completedCityCount)
        #expect(state.stageStatus == fresh.stageStatus)
        #expect(state.gold == 0)
        #expect(fresh.gold == 15)
    }

    // MARK: - Zero-gold opening (explicit product tradeoff)

    @Test func ascendedZeroGoldRunStillDeploysFreeLevelOneInfantry() {
        var state = Self.makeCompletedCampaignState()
        _ = state.ascend()

        #expect(state.gold == 0)
        // Below the 15-gold Barracks: no buildings, so no other manual type
        // and no idle building production — but infantry stays free at 1.
        #expect(state.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
        #expect(state.manualSoldierLevel(for: .infantry) == 1)
        #expect(state.manualSpawnableSoldierTypes() == [.infantry])
    }

    @Test func beginningOfReplayConquestWorksFromZeroGold() {
        var state = Self.makeCompletedCampaignState()
        _ = state.ascend()
        #expect(state.gold == 0)

        // A real beginning-of-replay conquest through the same simulator
        // path BattleScene drives: manual infantry deploys into a live
        // `BattleCombatState`, per-tick combat against the authored City 1
        // snapshot, and the simulator's own attack/loss events forwarded
        // into the state. No synthetic damage is injected.
        let expectedReward = state.goldReward(forCity: 1)
        var combat = BattleCombatState(
            configuration: .live(
                cityLevel: state.cityLevel,
                laneDamageMultipliers: state.currentCityLaneDefenseProfile.towerDamageMultipliers
            ),
            seed: 582
        )

        let deltaTime = 0.1
        let maxTicks = 1_200 // 120 simulated combat seconds — a bounded run.
        var ticks = 0
        while ticks < maxTicks, state.pendingBattleResult == nil {
            // The Deploy action's exact guard order: type, 10-live cap,
            // then a spent charge — a rejected deploy never consumes one.
            if let level = state.manualSoldierLevel(for: .infantry),
               combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap,
               combat.spendManualDeployCharge() {
                let soldierID = combat.spawnSoldier(
                    type: .infantry,
                    source: .manual,
                    level: level,
                    attackPower: state.traitAdjustedSoldierAttackPower(
                        for: .infantry,
                        level: level
                    ),
                    lane: state.siegeProgress.selectedLane,
                    maxHPMultiplier: state.equipmentMaxHPMultiplier(for: .infantry),
                    specialistBonus: state.equipmentSpecialistBonus(for: .infantry)
                )
                if let soldier = combat.soldier(id: soldierID) {
                    state.recordSoldierDeployment(
                        type: soldier.type,
                        source: soldier.source,
                        lane: soldier.lane
                    )
                }
            }

            let result = combat.tick(deltaTime: deltaTime, siege: state.currentSiegeSnapshot)
            // Same forwarding as BattleScene's tick handling: Captain
            // events excluded, ordinary attacks become persisted city damage.
            let ordinaryAttacks = result.soldierAttacks.filter { !$0.isCaptain }
            let ordinaryLosses = result.soldierLosses.filter { !$0.isCaptain }
            state.recordSoldierLosses(ordinaryLosses)
            if !ordinaryAttacks.isEmpty {
                _ = state.applyLiveSoldierAttacks(ordinaryAttacks)
            }
            ticks += 1
        }

        #expect(state.pendingBattleResult != nil)
        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.gold == expectedReward)
        #expect(state.pendingBattleResult?.cityKey == CityKey(countryNumber: 1, cityNumber: 1))
        // HPA-672: the replay conquest of City 1 levels its already-owned
        // fixed drop (fixture level 2) up to 3 and reports that receipt.
        #expect(
            state.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 3)
        )
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 3)
        #expect(state.ownedEquipmentIDs.count == EquipmentCatalog.items.count)
    }

    // MARK: - Fixtures

    /// A representative completed campaign: Country 1 finished and its
    /// report acknowledged, Treasury purchased, a background timestamp
    /// recorded, all 15 gear items owned with mixed levels, one chosen
    /// slot per some types and a deliberate `None` cavalry slot.
    private static func makeCompletedCampaignState() -> KingdomGameState {
        var state = KingdomGameState(
            gold: 500,
            cityLevel: 15,
            lastBackgroundedAt: Date(timeIntervalSinceReferenceDate: 99_000),
            countryNumber: 1,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete,
            ownedEquipmentIDs: EquipmentCatalog.items.map(\.id),
            equippedItemBySoldierType: [
                "infantry": "c01-infantry-attack",
                "archer": "c02-archer-attack",
                "mage": "c08-mage-attack"
            ],
            equipmentLevelsByID: [
                "c01-infantry-attack": 2,
                "c15-siege-keep": 3
            ],
            ascensionCount: 1
        )
        _ = state.purchaseTreasuryUpgrade(.warChest)
        _ = state.purchaseTreasuryUpgrade(.drillYard)
        _ = state.purchaseTreasuryUpgrade(.drillYard)
        _ = state.purchaseTreasuryUpgrade(.quartermaster)
        return state
    }
}
