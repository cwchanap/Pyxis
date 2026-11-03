//
//  KingdomEquipmentStateTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct KingdomEquipmentStateTests {
    // MARK: - Defaults and decode normalization

    @Test func freshStateOwnsAndEquipsNothing() {
        let state = KingdomGameState()

        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
    }

    @Test func decodingSaveWithoutEquipmentKeysDefaultsEmpty() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive"
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
    }

    @Test func decodingMalformedEquipmentFieldsDefaultsEmptyAndKeepsSiblings() throws {
        let data = Data("""
        {
          "gold": 77,
          "stageStatus": "battleActive",
          "treasury": {"warChest": 2, "drillYard": 1, "quartermaster": 0},
          "ownedEquipmentIDs": "junk",
          "equippedItemBySoldierType": 42
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.gold == 77)
        #expect(state.treasury == TreasuryState(warChest: 2, drillYard: 1, quartermaster: 0))
        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
    }

    @Test func decodingDropsUnknownAndDuplicateOwnedIDsAndRestoresCityOrder() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive",
          "ownedEquipmentIDs": [
            "c03-infantry-toughness",
            "c02-archer-attack",
            "ghost-item",
            "c01-infantry-attack",
            "c03-infantry-toughness"
          ]
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.ownedEquipmentIDs == [
            "c01-infantry-attack",
            "c02-archer-attack",
            "c03-infantry-toughness"
        ])
    }

    @Test func decodingDropsMalformedKeysUnownedAndMismatchedEquippedSlots() throws {
        let data = Data("""
        {
          "gold": 40,
          "stageStatus": "battleActive",
          "ownedEquipmentIDs": ["c01-infantry-attack", "c02-archer-attack"],
          "equippedItemBySoldierType": {
            "infantry": "c01-infantry-attack",
            "not-a-type": "c01-infantry-attack",
            "archer": "c03-infantry-toughness",
            "cavalry": "c05-cavalry-attack"
          }
        }
        """.utf8)

        let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
    }

    @Test func memberwiseInitNormalizesEquipmentLikeDecode() {
        let state = KingdomGameState(
            ownedEquipmentIDs: ["ghost", "c02-archer-attack", "c01-infantry-attack", "c01-infantry-attack"],
            equippedItemBySoldierType: ["mage": "c01-infantry-attack"]
        )

        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack", "c02-archer-attack"])
        #expect(state.equippedItemBySoldierType == [:])
    }

    @Test func storeRoundTripPreservesOwnedEquippedAndIntentionalUnequip() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")

        var saved = KingdomGameState(
            gold: 999,
            treasury: TreasuryState(warChest: 1, drillYard: 2, quartermaster: 0),
            ownedEquipmentIDs: ["c01-infantry-attack", "c02-archer-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack", "archer": "c02-archer-attack"]
        )
        #expect(saved.equip(itemID: "c02-archer-attack") == .unchanged)

        store.save(saved)
        var loaded = store.load()
        #expect(loaded == saved)
        #expect(loaded.treasury == saved.treasury)
        #expect(loaded.equippedItemBySoldierType == ["infantry": "c01-infantry-attack", "archer": "c02-archer-attack"])

        // An explicit `None` is the absent slot entry and must survive
        // save/reload exactly as an intentional choice.
        #expect(loaded.unequip(soldierType: .infantry) == .success)
        store.save(loaded)
        let reloaded = store.load()
        #expect(reloaded.equippedItemBySoldierType == ["archer": "c02-archer-attack"])
        #expect(reloaded.ownedEquipmentIDs == saved.ownedEquipmentIDs)
    }

    // MARK: - equip / unequip API

    @Test func equipRequiresCatalogItemAndOwnershipAndNeverMutatesOnRejection() {
        var state = KingdomGameState(ownedEquipmentIDs: ["c01-infantry-attack"])

        #expect(state.equip(itemID: "c01-infantry-attack") == .success)
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])

        #expect(state.equip(itemID: "c01-infantry-attack") == .unchanged)
        #expect(state.equip(itemID: "ghost-item") == .rejected)
        #expect(state.equip(itemID: "c03-infantry-toughness") == .rejected)
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
    }

    @Test func everyTypeCyclesItsThreeAuthoredChoicesThroughOneSlot() throws {
        for soldierType in SoldierType.allCases {
            let ownedIDs = EquipmentCatalog.forType(soldierType).map(\.id)
            #expect(ownedIDs.count == 3)

            var state = KingdomGameState(ownedEquipmentIDs: ownedIDs)
            for itemID in ownedIDs {
                #expect(state.equip(itemID: itemID) == .success)
                #expect(state.equippedItemBySoldierType[soldierType.rawValue] == itemID)
                #expect(Set(state.equippedItemBySoldierType.keys) == [soldierType.rawValue])
            }

            #expect(state.unequip(soldierType: soldierType) == .success)
            #expect(state.equippedItemBySoldierType[soldierType.rawValue] == nil)
            #expect(state.unequip(soldierType: soldierType) == .unchanged)
        }
    }

    @Test func unequipOnAnEmptySlotIsAnUnchangedNoOp() {
        var state = KingdomGameState(ownedEquipmentIDs: ["c01-infantry-attack"])

        #expect(state.unequip(soldierType: .infantry) == .unchanged)
        #expect(state.equippedItemBySoldierType == [:])
    }

    @Test func equipAndUnequipAreAvailableInEveryStage() {
        for stage in [
            KingdomGameState.StageStatus.battleActive,
            .cityConqueredPendingMap,
            .countryComplete
        ] {
            var state = KingdomGameState(
                stageStatus: stage,
                ownedEquipmentIDs: ["c01-infantry-attack"]
            )

            #expect(state.equip(itemID: "c01-infantry-attack") == .success)
            #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
            #expect(state.unequip(soldierType: .infantry) == .success)
            #expect(state.equippedItemBySoldierType == [:])
        }
    }

    // MARK: - BattleResult equipment reward receipt (HPA-672)

    @Test func battleResultsDefaultToNoEquipmentReceipt() {
        let session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        #expect(session.finalized(conquestMode: .live, goldEarned: 8).equipmentReward == nil)

        let direct = BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 1),
            conquestMode: .live,
            activeBattleSeconds: 0,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 8
        )
        #expect(direct.equipmentReward == nil)
    }

    @Test func battleResultEncodesAndDecodesTheTypedEquipmentReceipt() throws {
        let result = BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 5),
            conquestMode: .live,
            activeBattleSeconds: 0,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 12,
            equipmentReward: EquipmentReward(itemID: "c05-cavalry-attack", level: 1)
        )

        let data = try JSONEncoder().encode(result)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let receipt = try #require(payload["equipmentReward"] as? [String: Any])
        #expect(receipt["itemID"] as? String == "c05-cavalry-attack")
        #expect(receipt["level"] as? Int == 1)

        let decoded = try JSONDecoder().decode(BattleResult.self, from: data)
        #expect(decoded == result)
        #expect(decoded.equipmentReward == EquipmentReward(itemID: "c05-cavalry-attack", level: 1))
    }

    @Test func persistedResultWithoutReceiptKeyDecodesNil() throws {
        let data = Data("""
        {
          "cityKey": "1-5",
          "conquestMode": "live",
          "activeBattleSeconds": 0,
          "deployments": [],
          "appliedDamage": [],
          "losses": [],
          "idleDamageByType": [],
          "usedFavorableUnit": false,
          "usedExposedLane": false,
          "goldEarned": 12
        }
        """.utf8)

        let result = try JSONDecoder().decode(BattleResult.self, from: data)

        #expect(result.equipmentReward == nil)
        #expect(result.goldEarned == 12)
    }

    // MARK: - HPA-672: the one conquest grant seam (first drop + repeat leveling)

    @Test func liveConquestGrantsCityGearAtLevelOneAutoEquipsFirstItemAndReceiptSurvivesRoundTrip() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 1)
        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))

        let result = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])

        #expect(result.conqueredCities == 1)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        // First-ever infantry item auto-equips.
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
        // A new drop establishes level 1.
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 1)
        #expect(state.equipmentLevelsByID == ["c01-infantry-attack": 1])
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 1))

        // The receipt survives process death (save encode/decode).
        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(
            decoded.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 1)
        )
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(decoded.equipmentLevel(for: "c01-infantry-attack") == 1)

        // Acknowledging clears only the report — gear is account-level.
        decoded.acknowledgePendingBattleResult()
        #expect(decoded.pendingBattleResult == nil)
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(decoded.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
        #expect(decoded.equipmentLevel(for: "c01-infantry-attack") == 1)
    }

    @Test func backgroundIdleConquestGrantsCityGearWithSurvivingReceipt() throws {
        let start = Date(timeIntervalSinceReferenceDate: 2_000)
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 100,
            keepRemaining: 1,
            selectedLane: .right
        )
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(100))

        // 100s idle → 10s effective → one barracks spawn → 1 damage kills the Keep.
        #expect(result.conqueredCities == 1)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 1)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 1))

        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(
            decoded.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 1)
        )
        decoded.acknowledgePendingBattleResult()
        #expect(decoded.pendingBattleResult == nil)
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(decoded.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
    }

    @Test func campBuildSettlementConquestGrantsCityGearWithSurvivingReceipt() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 100,
            keepRemaining: 1,
            selectedLane: .right
        )
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))

        // A second build settles the first barracks' pending production first.
        let result = state.buildBuilding(.barracks, inSlot: 2, at: start.addingTimeInterval(100))

        #expect(result == .cityConqueredDuringSettlement(goldEarned: 8, remainingGold: 93))
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 1))

        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(
            decoded.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 1)
        )
        decoded.acknowledgePendingBattleResult()
        #expect(decoded.pendingBattleResult == nil)
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(decoded.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
    }

    @Test func pinnedSequencePriorOwnershipSuppressesAutoEquipAfterIntentionalNone() throws {
        // Country 1 City 1 — Infantry Attack: first-ever infantry item auto-equips.
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 1)
        var keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])

        // Choose None, then save/reload — the absent entry must survive.
        state.acknowledgePendingBattleResult()
        #expect(state.unequip(soldierType: .infantry) == .success)
        state = try JSONDecoder().decode(KingdomGameState.self, from: JSONEncoder().encode(state))
        #expect(state.equippedItemBySoldierType == [:])

        // Country 1 City 2 — Archer Attack: archer's first item auto-equips;
        // infantry stays explicitly unequipped.
        #expect(state.startCityFromMap(2) == .entered(country: 1, city: 2))
        SiegeTestSupport.setKeepRemaining(1, on: &state)
        keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])
        #expect(state.pendingBattleResult?.equipmentReward == EquipmentReward(itemID: "c02-archer-attack", level: 1))
        #expect(state.equippedItemBySoldierType == ["archer": "c02-archer-attack"])
        #expect(state.equipmentLevel(for: "c02-archer-attack") == 1)

        // Country 1 City 3 — Infantry Toughness: newly owned and reported, but
        // prior infantry ownership suppresses auto-equip (ownership, not slot).
        state.acknowledgePendingBattleResult()
        #expect(state.startCityFromMap(3) == .entered(country: 1, city: 3))
        SiegeTestSupport.setKeepRemaining(1, on: &state)
        keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])

        #expect(state.ownedEquipmentIDs == [
            "c01-infantry-attack",
            "c02-archer-attack",
            "c03-infantry-toughness"
        ])
        #expect(
            state.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c03-infantry-toughness", level: 1)
        )
        #expect(state.equippedItemBySoldierType == ["archer": "c02-archer-attack"])
    }

    // MARK: - HPA-672 repeat-conquest leveling

    @Test func repeatConquestLevelsOwnedGearOneToTwoToThreeThenCaps() throws {
        // Level 1 → 2: receipt reports the new level; gold pays once.
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack"]
        )
        #expect(
            state.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8))
                == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8)
        )
        #expect(state.gold == 48)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 2)
        #expect(state.pendingBattleResult?.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 2))

        // Level 2 → 3 on the next replay.
        state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 2]
        )
        #expect(
            state.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8))
                == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8)
        )
        #expect(state.equipmentLevel(for: "c01-infantry-attack") == 3)
        #expect(state.pendingBattleResult?.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 3))

        // The receipt survives save/relaunch with its upgrade level.
        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(
            decoded.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 3)
        )
        #expect(decoded.equipmentLevel(for: "c01-infantry-attack") == 3)
        decoded.acknowledgePendingBattleResult()
        #expect(decoded.pendingBattleResult == nil)
        #expect(decoded.equipmentLevel(for: "c01-infantry-attack") == 3)
    }

    @Test func cappedLevelThreeRepeatPaysNormalSingleGoldWithoutGearReceipt() {
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 3]
        )

        let completion = state.completeCurrentCity(
            with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8)
        )

        // Normal single gold, no second grant, no receipt, level stays 3.
        #expect(completion == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8))
        #expect(state.gold == 48)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equipmentLevelsByID == ["c01-infantry-attack": 3])
        #expect(state.pendingBattleResult?.equipmentReward == nil)
        #expect(state.pendingBattleResult?.goldEarned == 8)
    }

    @Test func repeatConquestResetsStaleCallerReceiptBeforeComputingAward() {
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack"]
        )

        var stale = makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8)
        stale.equipmentReward = EquipmentReward(itemID: "c05-cavalry-attack", level: 3)

        #expect(
            state.completeCurrentCity(with: stale)
                == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8)
        )
        // The caller-supplied receipt never survives: only the real
        // level-up of this city's fixed item is reported.
        #expect(state.pendingBattleResult?.equipmentReward == EquipmentReward(itemID: "c01-infantry-attack", level: 2))
        #expect(state.equipmentLevel(for: "c05-cavalry-attack") == nil)
    }

    @Test func repeatConquestNeverAutoEquipsNorOverridesChosenOrNoneSlots() {
        // Chosen slot: infantry deliberately runs the City 3 toughness
        // item; upgrading City 1's item must not touch it.
        var chosen = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"],
            equippedItemBySoldierType: ["infantry": "c03-infantry-toughness"]
        )
        _ = chosen.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8))
        #expect(chosen.equipmentLevel(for: "c01-infantry-attack") == 2)
        #expect(chosen.equippedItemBySoldierType == ["infantry": "c03-infantry-toughness"])

        // Deliberate `None`: the absent infantry entry stays absent.
        var none = SiegeTestSupport.makeBattleState(
            atCity: 1,
            gold: 40,
            keepRemaining: 1,
            ownedEquipmentIDs: ["c01-infantry-attack"]
        )
        _ = none.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8))
        #expect(none.equipmentLevel(for: "c01-infantry-attack") == 2)
        #expect(none.equippedItemBySoldierType == [:])
    }

    @Test func country2CompletionEarnsGoldWithoutCountry1GearReceiptOrLevels() throws {
        var state = KingdomGameState(gold: 50, countryNumber: 2, cityNumberInCountry: 1)

        let completion = state.completeCurrentCity(
            with: makeResult(countryNumber: 2, cityNumber: 1, goldEarned: 8)
        )

        #expect(completion == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8))
        #expect(state.gold == 58)
        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
        #expect(state.equipmentLevelsByID == [:])
        #expect(state.pendingBattleResult?.equipmentReward == nil)
        #expect(state.stageStatus == .cityConqueredPendingMap)
    }

    @Test func mismatchedDuplicateAndPausedCompletionsNeverMutateEquipmentOrGold() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, gold: 40, keepRemaining: 1)

        // Out-of-order: a result for another city is rejected wholesale.
        #expect(
            state.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 2, goldEarned: 8))
                == KingdomGameState.CompletionResult(awarded: false, goldEarned: 0)
        )
        #expect(state.gold == 40)
        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
        #expect(state.pendingBattleResult == nil)

        // One valid live completion grants exactly once.
        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        _ = state.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .infantry,
                source: .manual,
                lane: .center,
                objectiveID: keepID,
                appliedDamage: 1
            )
        ])
        let goldAfterGrant = state.gold
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])

        // Duplicate while paused (stage is now .cityConqueredPendingMap): a
        // replayed valid result must not double-award or touch gold.
        #expect(
            state.completeCurrentCity(with: makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8))
                == KingdomGameState.CompletionResult(awarded: false, goldEarned: 0)
        )
        #expect(state.gold == goldAfterGrant)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
        #expect(
            state.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 1)
        )
    }

    private func makeResult(countryNumber: Int, cityNumber: Int, goldEarned: Int) -> BattleResult {
        BattleResult(
            cityKey: CityKey(countryNumber: countryNumber, cityNumber: cityNumber),
            conquestMode: .live,
            activeBattleSeconds: 0,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: goldEarned
        )
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
