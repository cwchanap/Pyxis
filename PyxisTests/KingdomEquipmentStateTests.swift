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

    // MARK: - HPA-671 Task 2: the one conquest grant seam

    @Test func liveConquestGrantsCityGearAutoEquipsFirstItemAndReceiptSurvivesRoundTrip() throws {
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
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.newEquipmentItemID == "c01-infantry-attack")

        // The receipt survives process death (save encode/decode).
        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(decoded.pendingBattleResult?.newEquipmentItemID == "c01-infantry-attack")
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])

        // Acknowledging clears only the report — gear is account-level.
        decoded.acknowledgePendingBattleResult()
        #expect(decoded.pendingBattleResult == nil)
        #expect(decoded.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(decoded.equippedItemBySoldierType == ["infantry": "c01-infantry-attack"])
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
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.newEquipmentItemID == "c01-infantry-attack")

        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(decoded.pendingBattleResult?.newEquipmentItemID == "c01-infantry-attack")
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
        #expect(pending.newEquipmentItemID == "c01-infantry-attack")

        var decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(decoded.pendingBattleResult?.newEquipmentItemID == "c01-infantry-attack")
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
        #expect(state.pendingBattleResult?.newEquipmentItemID == "c02-archer-attack")
        #expect(state.equippedItemBySoldierType == ["archer": "c02-archer-attack"])

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
        #expect(state.pendingBattleResult?.newEquipmentItemID == "c03-infantry-toughness")
        #expect(state.equippedItemBySoldierType == ["archer": "c02-archer-attack"])
    }

    @Test func country2CompletionEarnsGoldWithoutCountry1GearOrReceipt() throws {
        var state = KingdomGameState(gold: 50, countryNumber: 2, cityNumberInCountry: 1)

        let completion = state.completeCurrentCity(
            with: makeResult(countryNumber: 2, cityNumber: 1, goldEarned: 8)
        )

        #expect(completion == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8))
        #expect(state.gold == 58)
        #expect(state.ownedEquipmentIDs == [])
        #expect(state.equippedItemBySoldierType == [:])
        #expect(state.pendingBattleResult?.newEquipmentItemID == nil)
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
        #expect(state.pendingBattleResult?.newEquipmentItemID == "c01-infantry-attack")
    }

    @Test func alreadyOwnedCatalogRewardPaysGoldAndScrubsStaleReceipt() throws {
        // A VALID active conquest of City 1 whose catalog reward is already
        // owned: gold pays normally, ownership/loadout are unchanged, and
        // the seam scrubs even a caller-set stale receipt instead of
        // re-reporting the owned item.
        var state = SiegeTestSupport.makeBattleState(atCity: 1, gold: 40, keepRemaining: 1)
        state.ownedEquipmentIDs = ["c01-infantry-attack"]
        state.equippedItemBySoldierType = [:]

        var stale = makeResult(countryNumber: 1, cityNumber: 1, goldEarned: 8)
        stale.newEquipmentItemID = "c01-infantry-attack"

        #expect(
            state.completeCurrentCity(with: stale)
                == KingdomGameState.CompletionResult(awarded: true, goldEarned: 8)
        )
        #expect(state.gold == 48)
        #expect(state.ownedEquipmentIDs == ["c01-infantry-attack"])
        #expect(state.equippedItemBySoldierType == [:])
        #expect(state.pendingBattleResult?.newEquipmentItemID == nil)
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
