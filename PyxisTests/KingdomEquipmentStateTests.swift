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

    // MARK: - BattleResult new-gear receipt

    @Test func battleResultsDefaultToNoEquipmentReceipt() {
        let session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        #expect(session.finalized(conquestMode: .live, goldEarned: 8).newEquipmentItemID == nil)

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
        #expect(direct.newEquipmentItemID == nil)
    }

    @Test func battleResultEncodesAndDecodesTheEquipmentReceipt() throws {
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
            newEquipmentItemID: "c05-cavalry-attack"
        )

        let data = try JSONEncoder().encode(result)
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(payload["newEquipmentItemID"] as? String == "c05-cavalry-attack")

        let decoded = try JSONDecoder().decode(BattleResult.self, from: data)
        #expect(decoded == result)
        #expect(decoded.newEquipmentItemID == "c05-cavalry-attack")
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

        #expect(result.newEquipmentItemID == nil)
        #expect(result.goldEarned == 12)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
