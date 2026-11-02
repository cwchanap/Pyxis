//
//  EquipmentEffectTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// HPA-671 Task 3: the three conquest-gear effects consume exactly the
/// existing combat seams. Attack gear folds into the single-round attack
/// power shared by live spawns and idle abstract damage; toughness gear
/// lifts only the live spawn's cached max HP; specialist gear joins the
/// existing second-round role adjustment, snapshotted at spawn so later
/// equip changes never rewrite a live soldier's stats. Idle never gains
/// soldier HP and keeps its one-target-then-raw-spill approximation.
struct EquipmentEffectTests {
    // MARK: - State projections (the single loadout read per effect)

    @Test func equippedItemProjectionsByEffectKind() {
        var state = KingdomGameState(
            ownedEquipmentIDs: [
                "c01-infantry-attack",
                "c03-infantry-toughness",
                "c06-infantry-gate",
                "c04-archer-tower"
            ]
        )

        // Explicit None (absent slot): every projection neutral.
        #expect(state.equippedItem(for: .infantry) == nil)
        #expect(state.equipmentAttackMultiplier(for: .infantry) == 1)
        #expect(state.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(state.equipmentSpecialistBonus(for: .infantry) == nil)

        // Attack: +0.15 folded into the first round, nothing else moves.
        #expect(state.equip(itemID: "c01-infantry-attack") == .success)
        #expect(state.equipmentAttackMultiplier(for: .infantry) == 1.15)
        #expect(state.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(state.equipmentSpecialistBonus(for: .infantry) == nil)
        // One slot per type: another type stays neutral.
        #expect(state.equipmentAttackMultiplier(for: .archer) == 1)
        #expect(state.equipmentSpecialistBonus(for: .archer) == nil)

        // Toughness: +0.25 max HP only.
        #expect(state.equip(itemID: "c03-infantry-toughness") == .success)
        #expect(state.equipmentAttackMultiplier(for: .infantry) == 1)
        #expect(state.equipmentMaxHPMultiplier(for: .infantry) == 1.25)
        #expect(state.equipmentSpecialistBonus(for: .infantry) == nil)

        // Specialist: matching objective kind + 1.40 factor only.
        #expect(state.equip(itemID: "c06-infantry-gate") == .success)
        #expect(state.equipmentAttackMultiplier(for: .infantry) == 1)
        #expect(state.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(
            state.equipmentSpecialistBonus(for: .infantry)
                == SoldierSpecialistBonus(target: .gate, multiplier: 1.4)
        )

        // Unequip returns to neutral for the next spawn.
        #expect(state.unequip(soldierType: .infantry) == .success)
        #expect(state.equippedItem(for: .infantry) == nil)
        #expect(state.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(state.equipmentSpecialistBonus(for: .infantry) == nil)
    }

    // MARK: - Attack gear at the shared seam

    @Test func instanceAttackSeamFoldsEquippedAttackGearIntoTheSingleRound() {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
        state.treasury.drillYard = 2
        state.ownedEquipmentIDs = ["c01-infantry-attack"]
        #expect(state.equip(itemID: "c01-infantry-attack") == .success)

        let expected = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry,
            level: 5,
            defenseTrait: state.currentCityDefenseTrait,
            upgradeMultiplier: 1.1,
            equipmentAttackMultiplier: 1.15
        )
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == expected)
        // Base 4 × 1.10 × 1.15 = 5.06 → 5 in ONE round.
        #expect(expected == 5)

        // Unequipped, the same state returns the exact HPA-670 fold:
        // round(4 × 1.10) = 4.4 → 4.
        #expect(state.unequip(soldierType: .infantry) == .success)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 4)
    }

    @Test func liveCombatSpawnAndIdleDamageShareTheGearFoldedPower() throws {
        // The same shape as the Drill Yard parity test, with the attack
        // item equipped: one level-5 barracks spawn must price at
        // round(4 × 1.15) = 5 (4.6 → 5) on BOTH the live combat spawn and
        // the idle abstract budget.
        func armedState() -> KingdomGameState {
            var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            state.ownedEquipmentIDs = ["c01-infantry-attack"]
            #expect(state.equip(itemID: "c01-infantry-attack") == .success)

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState
            return state
        }

        // Live path: exactly what BattleScene passes into spawnSoldier.
        var liveState = armedState()
        var combat = BattleCombatState(configuration: .live(cityLevel: liveState.cityLevel))
        let id = combat.spawnSoldier(
            type: .infantry,
            source: .building,
            level: 5,
            attackPower: liveState.traitAdjustedSoldierAttackPower(for: .infantry, level: 5),
            lane: liveState.siegeProgress.selectedLane
        )
        #expect(try #require(combat.soldier(id: id)).attackPower == 5)

        // Idle path: the abstract budget for the same loadout.
        var idleState = armedState()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        idleState.enterBackground(at: start)
        let result = idleState.returnFromBackground(at: start.addingTimeInterval(150))
        // First live objective is the Keep (neutral role) → budget 5.
        #expect(result.conqueredCities == 0)
        #expect(result.damageDealt == 5)
    }

    // MARK: - New-spawns-only snapshot

    @Test func equipChangeAfterLiveSpawnNeverRewritesCachedStats() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
        state.ownedEquipmentIDs = ["c06-infantry-gate", "c01-infantry-attack"]
        #expect(state.equip(itemID: "c06-infantry-gate") == .success)

        var combat = BattleCombatState(configuration: .live(cityLevel: state.cityLevel))
        let id = combat.spawnSoldier(
            type: .infantry,
            source: .manual,
            level: 5,
            attackPower: state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5),
            lane: .center,
            maxHPMultiplier: state.equipmentMaxHPMultiplier(for: .infantry),
            specialistBonus: state.equipmentSpecialistBonus(for: .infantry)
        )
        let spawned = try #require(combat.soldier(id: id))
        // Specialist loadout at spawn: plain attack 4, base max HP 24
        // (round(10 × 1.25⁴) = 24), gate snapshot captured.
        #expect(spawned.attackPower == 4)
        #expect(spawned.maxHP == 24)
        #expect(spawned.specialistBonus == SoldierSpecialistBonus(target: .gate, multiplier: 1.4))

        // Swap to the attack item AFTER the spawn: the loadout helpers move
        // (next spawns), the live soldier's cached stats never do.
        #expect(state.equip(itemID: "c01-infantry-attack") == .success)
        #expect(state.equipmentSpecialistBonus(for: .infantry) == nil)
        #expect(state.equipmentAttackMultiplier(for: .infantry) == 1.15)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 5)

        let frozen = try #require(combat.soldier(id: id))
        #expect(frozen.attackPower == 4)
        #expect(frozen.maxHP == 24)
        #expect(frozen.specialistBonus == SoldierSpecialistBonus(target: .gate, multiplier: 1.4))
    }

    // MARK: - Idle parity with the second-round specialist formula

    @Test func idleSpecialistBoostsFirstLiveObjectiveAndSpillsRaw() throws {
        // Willowford, default center lane, route [gate, keep]: gate left at
        // 2 HP, Keep full. One level-5 barracks spawn prices at 4 (Standard
        // Watch, no Treasury). With the Granite Ram equipped the budget is
        // round(4 × 1.0 × 1.40) = 6: the gate caps at its remaining 2 and
        // the Keep absorbs the raw 4 spill — never a second 1.40 pass.
        func settle(equippedItemID: String?) throws -> (applied: Int, gateDamage: Int, keepDamage: Int) {
            var state = SiegeTestSupport.makeBattleState(
                atCity: 1,
                keepRemaining: 15,
                supportDamage: [.gate: 3] // gate 5 − 3 = 2 remaining
            )
            state.siegeProgress.guardReinforcements = nil
            if let equippedItemID {
                state.ownedEquipmentIDs = [equippedItemID]
                #expect(state.equip(itemID: equippedItemID) == .success)
            }

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
            let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
            let gateDamageBefore = state.siegeProgress.damageByObjectiveID[gateID, default: 0]
            let keepDamageBefore = state.siegeProgress.damageByObjectiveID[keepID, default: 0]
            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            let result = state.returnFromBackground(at: start.addingTimeInterval(150))
            #expect(result.conqueredCities == 0)

            let damage = state.siegeProgress.damageByObjectiveID
            return (
                result.damageDealt,
                damage[gateID, default: 0] - gateDamageBefore,
                damage[keepID, default: 0] - keepDamageBefore
            )
        }

        let baseline = try settle(equippedItemID: nil)
        #expect(baseline.applied == 4)
        #expect(baseline.gateDamage == 2)
        #expect(baseline.keepDamage == 2)

        let boosted = try settle(equippedItemID: "c06-infantry-gate")
        #expect(boosted.applied == 6)
        #expect(boosted.gateDamage == 2) // capped at remaining HP, not the 6 budget
        #expect(boosted.keepDamage == 4) // 6 − 2 raw spill, not round(4 × 1.40) = 6
    }

    @Test func idleSpecialistStaysNeutralAgainstNonMatchingFirstLiveObjective() {
        func idleDamage(equipped: Bool) -> Int {
            var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 15)
            // Gate destroyed: the Keep (not the Ram's gate target) is first live.
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            if equipped {
                state.ownedEquipmentIDs = ["c06-infantry-gate"]
                #expect(state.equip(itemID: "c06-infantry-gate") == .success)
            }

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            return state.returnFromBackground(at: start.addingTimeInterval(150)).damageDealt
        }

        #expect(idleDamage(equipped: false) == 4)
        #expect(idleDamage(equipped: true) == 4)
    }

    @Test func toughnessGearNeverBoostsIdleDamage() {
        // Idle does not model soldier HP; the Bulwark must not leak an
        // abstract damage boost into the offline budget.
        func idleDamage(equipped: Bool) -> Int {
            var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 15)
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            if equipped {
                state.ownedEquipmentIDs = ["c03-infantry-toughness"]
                #expect(state.equip(itemID: "c03-infantry-toughness") == .success)
            }

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            return state.returnFromBackground(at: start.addingTimeInterval(150)).damageDealt
        }

        #expect(idleDamage(equipped: false) == 4)
        #expect(idleDamage(equipped: true) == 4)
    }
}
