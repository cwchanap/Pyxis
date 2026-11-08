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
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: 100_000,
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness"]
        )
        state.treasury.drillYard = 2

        // The static primitive keeps the raw single-round percentage:
        // base 4 × 1.10 = 4.4 → 4; × 1.15 = 5.06 → 5.
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 5,
                defenseTrait: state.currentCityDefenseTrait,
                multiplier: 1.1
            ) == 4
        )
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 5,
                defenseTrait: state.currentCityDefenseTrait,
                multiplier: 1.1 * 1.15
            ) == 5
        )

        // The instance seam is the HPA-811 effective attack: each owned
        // rank adds at least +1 — DY2 alone reads 6 …
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 6)
        // … and DY2 + the Lv1 attack item reads 7.
        #expect(state.equip(itemID: "c01-infantry-attack") == .success)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 7)

        // A non-attack item never arms the gear dimension — the same read
        // returns the DY-only effective.
        #expect(state.equip(itemID: "c03-infantry-toughness") == .success)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 6)

        // Unequipped, back to the DY-only effective.
        #expect(state.unequip(soldierType: .infantry) == .success)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 6)
    }

    @Test func liveCombatSpawnAndIdleDamageShareTheGearFoldedPower() throws {
        // The same shape as the Drill Yard parity test, with the attack
        // item equipped: one level-5 barracks spawn must price at
        // round(4 × 1.15) = 5 (4.6 → 5) on BOTH the live combat spawn and
        // the idle abstract budget.
        func armedState() -> KingdomGameState {
            var state = SiegeTestSupport.makeBattleState(
                atCity: 1,
                keepRemaining: 100_000,
                ownedEquipmentIDs: ["c01-infantry-attack"]
            )
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
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
        var state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: 100_000,
            ownedEquipmentIDs: ["c06-infantry-gate", "c01-infantry-attack"]
        )
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
                supportDamage: [.gate: 3], // gate 5 − 3 = 2 remaining
                ownedEquipmentIDs: equippedItemID.map { [$0] } ?? []
            )
            state.siegeProgress.guardReinforcements = nil
            if let equippedItemID {
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
            var state = SiegeTestSupport.makeBattleState(
                atCity: 1,
                keepRemaining: 15,
                ownedEquipmentIDs: equipped ? ["c06-infantry-gate"] : []
            )
            // Gate destroyed: the Keep (not the Ram's gate target) is first live.
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            if equipped {
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
            var state = SiegeTestSupport.makeBattleState(
                atCity: 1,
                keepRemaining: 15,
                ownedEquipmentIDs: equipped ? ["c03-infantry-toughness"] : []
            )
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            if equipped {
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

    // MARK: - Live/idle parity matrix (plan step 4)

    /// One matrix cell: a soldier type at a level versus one objective kind,
    /// with or without the type's own specialist item equipped. The city/lane
    /// pair is the one whose selected route reaches that kind first, so the
    /// idle budget's first-live-objective key and the live soldier's first
    /// structure target are the same objective.
    private struct ParityCell: CustomStringConvertible {
        let soldierType: SoldierType
        let level: Int
        let kind: CitySiegeLayout.ObjectiveKind
        let equippedItemID: String?
        /// HPA-672: the equipped item's owned level (1...3); `equippedItemID`
        /// nil means no gear regardless of this value.
        var gearLevel: Int = 1
        /// HPA-672: the permanent Renown count folded into the first round.
        var ascensionCount: Int = 0
        /// Fix round: an explicit city/lane pair for cells that must run at a
        /// specific catalog city (an advantaged trait route). The pair must
        /// reach `kind` first, like the kind-derived defaults below.
        var explicitCityAndLane: (city: Int, lane: BattleLane)?

        var city: Int {
            if let explicitCityAndLane {
                return explicitCityAndLane.city
            }
            switch kind {
            case .gate: return 1 // Willowford center route [gate, keep]
            case .keep: return 1 // Willowford right route [keep]
            case .arrowTower: return 3 // Falconridge left route [arrow-tower, keep]
            case .barracks: return 5 // Highcrest left route [barracks, keep]
            }
        }

        var lane: BattleLane {
            if let explicitCityAndLane {
                return explicitCityAndLane.lane
            }
            switch kind {
            case .gate: return .center
            case .keep: return .right
            case .arrowTower, .barracks: return .left
            }
        }

        var buildingType: BuildingType {
            BuildingType.allCases.first { $0.soldierType == soldierType }!
        }

        var description: String {
            let gear = equippedItemID.map { ", \($0) Lv\(gearLevel)" } ?? ", no gear"
            return "\(soldierType) L\(level) vs \(kind) at city \(city)\(gear), renown \(ascensionCount)"
        }
    }

    /// The type's specialist item — the only gear that can match a kind.
    private static func specialistItemID(for soldierType: SoldierType) -> String {
        switch soldierType {
        case .infantry: return "c06-infantry-gate"
        case .archer: return "c04-archer-tower"
        case .cavalry: return "c10-cavalry-barracks"
        case .mage: return "c12-mage-barracks"
        case .siege: return "c15-siege-keep"
        }
    }

    // MARK: - HPA-672 level scaling (one scaling owner)

    /// ×1.5 of an authored binary fraction is not bit-equal to the decimal
    /// literal (0.15 × 1.5 = 0.224999…98), so scaled fractions compare with
    /// an epsilon instead of `==`.
    private func fraction(_ effect: EquipmentEffect) -> Double {
        switch effect {
        case .attackBonus(let fraction), .maxHPBonus(let fraction):
            return fraction
        case .specialistBonus(_, let fraction):
            return fraction
        }
    }

    private func assertNear(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 1e-9
    }

    @Test("scaled(toLevel:) multiplies the authored bonus by 1/1.5/2 and preserves kind and target")
    func scaledToLevelPinsTheThreeScales() {
        #expect(EquipmentEffect.attackBonus(0.15).scaled(toLevel: 1) == .attackBonus(0.15))
        #expect(assertNear(fraction(EquipmentEffect.attackBonus(0.15).scaled(toLevel: 2)), 0.225))
        #expect(assertNear(fraction(EquipmentEffect.attackBonus(0.15).scaled(toLevel: 3)), 0.30))

        #expect(EquipmentEffect.maxHPBonus(0.25).scaled(toLevel: 1) == .maxHPBonus(0.25))
        #expect(assertNear(fraction(EquipmentEffect.maxHPBonus(0.25).scaled(toLevel: 2)), 0.375))
        #expect(assertNear(fraction(EquipmentEffect.maxHPBonus(0.25).scaled(toLevel: 3)), 0.50))

        let specialist = EquipmentEffect.specialistBonus(target: .keep, fraction: 0.40)
        #expect(specialist.scaled(toLevel: 1) == .specialistBonus(target: .keep, fraction: 0.40))
        #expect(assertNear(fraction(specialist.scaled(toLevel: 2)), 0.60))
        #expect(assertNear(fraction(specialist.scaled(toLevel: 3)), 0.80))
        #expect(specialist.scaled(toLevel: 2) != .specialistBonus(target: .gate, fraction: 0.60))

        // Out-of-range levels clamp to the 1...3 band — state normalization
        // already guarantees it, the scaler never amplifies junk.
        #expect(EquipmentEffect.attackBonus(0.15).scaled(toLevel: 0) == .attackBonus(0.15))
        #expect(EquipmentEffect.attackBonus(0.15).scaled(toLevel: 4) == .attackBonus(0.30))
    }

    @Test("equippedEffect(for:) returns the scaled effect at the owned level or nil")
    func equippedEffectReturnsScaledEffectAtOwnedLevel() {
        var state = KingdomGameState(ownedEquipmentIDs: ["c01-infantry-attack"])
        #expect(state.equippedEffect(for: .infantry) == nil)

        #expect(state.equip(itemID: "c01-infantry-attack") == .success)
        #expect(state.equippedEffect(for: .infantry) == .attackBonus(0.15))

        let leveled2 = KingdomGameState(
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 2]
        )
        #expect(assertNear(fraction(leveled2.equippedEffect(for: .infantry) ?? .attackBonus(0)), 0.225))
        let leveled3 = KingdomGameState(
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 3]
        )
        #expect(leveled3.equippedEffect(for: .infantry) == .attackBonus(0.30))

        // A type with no owned gear of its own stays nil.
        #expect(leveled3.equippedEffect(for: .siege) == nil)
    }

    @Test("All three combat projections consume the scaled effect, never a raw catalog fraction")
    func projectionsConsumeTheScaledEffect() {
        let state = KingdomGameState(
            ownedEquipmentIDs: ["c01-infantry-attack", "c03-infantry-toughness", "c06-infantry-gate"],
            equipmentLevelsByID: [
                "c01-infantry-attack": 2,
                "c03-infantry-toughness": 3,
                "c06-infantry-gate": 3
            ]
        )

        // Attack Lv2: +22.5% folded into the first round.
        var attackEquipped = state
        #expect(attackEquipped.equip(itemID: "c01-infantry-attack") == .success)
        #expect(attackEquipped.equipmentAttackMultiplier(for: .infantry) == 1.225)
        #expect(attackEquipped.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(attackEquipped.equipmentSpecialistBonus(for: .infantry) == nil)

        // Toughness Lv3 (capped): +50% max HP only.
        var toughnessEquipped = state
        #expect(toughnessEquipped.equip(itemID: "c03-infantry-toughness") == .success)
        #expect(toughnessEquipped.equipmentAttackMultiplier(for: .infantry) == 1)
        #expect(toughnessEquipped.equipmentMaxHPMultiplier(for: .infantry) == 1.5)

        // Specialist Lv3 (capped): gate target, ×1.80 second round only.
        var specialistEquipped = state
        #expect(specialistEquipped.equip(itemID: "c06-infantry-gate") == .success)
        #expect(specialistEquipped.equipmentAttackMultiplier(for: .infantry) == 1)
        #expect(specialistEquipped.equipmentMaxHPMultiplier(for: .infantry) == 1)
        #expect(
            specialistEquipped.equipmentSpecialistBonus(for: .infantry)
                == SoldierSpecialistBonus(target: .gate, multiplier: 1.8)
        )
    }

    private func armedParityState(for cell: ParityCell) -> KingdomGameState {
        var state = SiegeTestSupport.makeBattleState(
            atCity: cell.city,
            keepRemaining: 1_000_000, // clamps to the authored max: full Keep
            selectedLane: cell.lane,
            ownedEquipmentIDs: cell.equippedItemID.map { [$0] } ?? [],
            equipmentLevelsByID: cell.equippedItemID.map { [$0: cell.gearLevel] } ?? [:],
            ascensionCount: cell.ascensionCount
        )
        // No Guard absorption: the whole budget reaches the route on both paths.
        state.siegeProgress.guardReinforcements = nil
        if let itemID = cell.equippedItemID {
            #expect(state.equip(itemID: itemID) == .success)
        }
        return state
    }

    /// LIVE path: spawn exactly what `BattleScene` spawns, then tick until
    /// the soldier's first structure hit. All objectives sit far above any
    /// budget so `appliedDamage` is the full second-round integer.
    private func liveFirstHitDamage(for cell: ParityCell) throws -> Int {
        let state = armedParityState(for: cell)
        var combat = BattleCombatState(configuration: .live(cityLevel: cell.city))
        let id = combat.spawnSoldier(
            type: cell.soldierType,
            source: .building,
            level: cell.level,
            attackPower: state.traitAdjustedSoldierAttackPower(for: cell.soldierType, level: cell.level),
            lane: cell.lane,
            maxHPMultiplier: 100, // HP is not the parity subject; survive tower fire
            specialistBonus: state.equipmentSpecialistBonus(for: cell.soldierType)
        )

        let layout = state.currentSiegeLayout
        let targetID = try #require(
            SiegeTestSupport.objectiveID(for: cell.kind, in: state),
            "\(cell): the city has no \(cell.kind) objective"
        )
        let snapshot = BattleCombatState.SiegeSnapshot(
            layout: layout,
            objectiveRemainingPower: Dictionary(
                uniqueKeysWithValues: layout.objectives.map { ($0.id, 10_000) }
            )
        )

        for _ in 0..<40 {
            let result = combat.tick(deltaTime: 1.0, siege: snapshot)
            if let hit = result.soldierAttacks.first(where: { $0.soldierID == id }) {
                #expect(hit.objectiveID == targetID, "\(cell): live target was \(hit.objectiveID)")
                return hit.appliedDamage
            }
        }
        Issue.record("\(cell): the live soldier never attacked within 40 ticks")
        return 0
    }

    /// IDLE path: one building-spawn settled through the abstract budget.
    private func idleSettlementDamage(for cell: ParityCell) -> Int {
        var state = armedParityState(for: cell)
        let key = state.currentCityKey
        var cityState = state.cityBattleState(for: key)
        cityState.setBuilding(CityBuilding(type: cell.buildingType, level: cell.level), inSlot: 1)
        state.cityBattleStates[key.storageKey] = cityState

        // interval × 10 + 5 s of wall time is interval + 0.5 s of effective
        // active production at the 1/10 idle rate: exactly one spawn.
        let interval = KingdomGameState.activeSpawnInterval(for: cell.buildingType)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        state.enterBackground(at: start)
        let result = state.returnFromBackground(at: start.addingTimeInterval(interval * 10 + 5))
        #expect(result.conqueredCities == 0, "\(cell)")
        return result.damageDealt
    }

    /// Five types × four objective kinds × low/high levels × gear
    /// on/off: every cell's LIVE first hit and IDLE settlement must land on
    /// the same single second round — cached power × inherent role ×
    /// matching specialist, rounded once.
    @Test func liveAndIdleDamageAgreeAcrossTheSpecialistParityMatrix() throws {
        var roundingDivergenceCells: [String] = []

        for soldierType in SoldierType.allCases {
            for kind in [CitySiegeLayout.ObjectiveKind.keep, .gate, .arrowTower, .barracks] {
                for level in [1, 5] {
                    for equippedItemID in [nil, Self.specialistItemID(for: soldierType)] {
                        let cell = ParityCell(
                            soldierType: soldierType,
                            level: level,
                            kind: kind,
                            equippedItemID: equippedItemID
                        )

                        let armed = armedParityState(for: cell)
                        let power = armed.traitAdjustedSoldierAttackPower(
                            for: cell.soldierType,
                            level: cell.level
                        )
                        let bonus = armed.equipmentSpecialistBonus(for: cell.soldierType)
                        let specialistMultiplier: Double
                        if let bonus, bonus.target == cell.kind {
                            specialistMultiplier = bonus.multiplier
                        } else {
                            specialistMultiplier = 1
                        }
                        let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)

                        // Binding contract: ONE combined second round.
                        let combined = max(
                            1,
                            Int((Double(power) * role * specialistMultiplier).rounded())
                        )
                        // Erroneous alternative: round the role, then the gear.
                        let roleFirst = max(1, Int((Double(power) * role).rounded()))
                        let separatelyRounded = max(
                            1,
                            Int((Double(roleFirst) * specialistMultiplier).rounded())
                        )
                        if separatelyRounded != combined {
                            roundingDivergenceCells.append(
                                "\(cell) → \(combined), not \(separatelyRounded)"
                            )
                        }

                        let live = try liveFirstHitDamage(for: cell)
                        #expect(live == combined, "\(cell): live hit \(live), expected \(combined)")

                        let idle = idleSettlementDamage(for: cell)
                        #expect(idle == combined, "\(cell): idle applied \(idle), expected \(combined)")
                    }
                }
            }
        }

        // The matrix must genuinely distinguish combined from
        // separately-rounded specialist application on both paths.
        #expect(
            roundingDivergenceCells.count >= 3,
            "divergence cells seen: \(roundingDivergenceCells)"
        )
    }

    /// Named low/mid-power cells where rounding the role first changes the
    /// integer; real live ticks and real idle settlement must both land on
    /// the combined round.
    @Test func parityMatrixPinsCombinedRoundingAtLowPowers() throws {
        let cells = [
            // Falconridge archer L1 (trait ×0.80 → cached 1): round(1 × 1.5 × 1.4)
            // = 2, not round(round(1.5) × 1.4) = 3.
            ParityCell(soldierType: .archer, level: 1, kind: .arrowTower, equippedItemID: "c04-archer-tower"),
            // Highcrest mage L1 (trait ×0.80 → cached 1): 2, not 3.
            ParityCell(soldierType: .mage, level: 1, kind: .barracks, equippedItemID: "c12-mage-barracks"),
            // Falconridge archer L5 (cached 3): round(3 × 1.5 × 1.4) = 6, not 7.
            ParityCell(soldierType: .archer, level: 5, kind: .arrowTower, equippedItemID: "c04-archer-tower")
        ]
        for cell in cells {
            let armed = armedParityState(for: cell)
            let power = armed.traitAdjustedSoldierAttackPower(for: cell.soldierType, level: cell.level)
            let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)
            let combined = max(1, Int((Double(power) * role * 1.4).rounded()))
            let roleFirst = max(1, Int((Double(power) * role).rounded()))
            let separatelyRounded = max(1, Int((Double(roleFirst) * 1.4).rounded()))

            #expect(
                combined != separatelyRounded,
                "\(cell): cached \(power) must distinguish the two roundings (\(combined) vs \(separatelyRounded))"
            )
            #expect(try liveFirstHitDamage(for: cell) == combined, "\(cell) live")
            #expect(idleSettlementDamage(for: cell) == combined, "\(cell) idle")
        }
    }

    // MARK: - HPA-672 Renown × leveled gear live/idle parity (plan step 6)

    /// Focused parity matrix over the two new first-round factors: all five
    /// soldier types at the low integer attack level, no gear / matching
    /// specialist at each of levels 1/2/3, and Renown 0 vs 1 — plus the
    /// neutral/disadvantaged/advantaged trait cities the kinds route
    /// through. Every cell's LIVE first hit and IDLE settlement must land on
    /// the same two rounds: cached power = round(base × trait × DY × gear ×
    /// Renown), then round(power × role × specialist).
    @Test func liveAndIdleDamageAgreeWithLeveledGearAndRenown() throws {
        for ascensionCount in [0, 1] {
            for gearLevel in [1, 2, 3] {
                for type in SoldierType.allCases {
                    let kind = Self.specialistKind(for: type)
                    let cell = ParityCell(
                        soldierType: type,
                        level: 1,
                        kind: kind,
                        equippedItemID: Self.specialistItemID(for: type),
                        gearLevel: gearLevel,
                        ascensionCount: ascensionCount
                    )
                    try expectParity(for: cell) { armed in
                        let bonus = armed.equipmentSpecialistBonus(for: cell.soldierType)
                        let specialistMultiplier = bonus?.target == cell.kind ? bonus?.multiplier : 1
                        let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)
                        return (role, specialistMultiplier ?? 1)
                    }

                    // The same cell with the type's ATTACK item instead: the
                    // level scale rides the FIRST round there, never the second.
                    let attackCell = ParityCell(
                        soldierType: type,
                        level: 1,
                        kind: kind,
                        equippedItemID: Self.attackItemID(for: type),
                        gearLevel: gearLevel,
                        ascensionCount: ascensionCount
                    )
                    try expectParity(for: attackCell) { _ in
                        let role = attackCell.soldierType.objectiveDamageMultiplier(against: attackCell.kind)
                        return (role, 1)
                    }
                }
            }

            // No-gear baseline at both counts: only Renown moves the first round.
            for type in SoldierType.allCases {
                let cell = ParityCell(
                    soldierType: type,
                    level: 1,
                    kind: Self.specialistKind(for: type),
                    equippedItemID: nil,
                    ascensionCount: ascensionCount
                )
                try expectParity(for: cell) { _ in
                    let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)
                    return (role, 1)
                }
            }
        }
    }

    /// One low-level cell per trait stance where the two rounds plus Renown
    /// produce distinguishing integers — disadvantaged archer at Falconridge,
    /// neutral infantry at Willowford, advantaged siege at Runewatch (the
    /// arcaneWard trait favours siege and the centre route reaches the Keep
    /// first). The catalog trait multiplier is asserted per cell before
    /// parity, so the advantaged cell can never silently fall back to a
    /// neutral city like the kind-derived default.
    @Test func renownParityCoversNeutralAdvantagedAndDisadvantagedTraits() throws {
        let cells: [(cell: ParityCell, expectedTraitMultiplier: Double)] = [
            (
                ParityCell(
                    soldierType: .infantry, level: 1, kind: .gate,
                    equippedItemID: "c01-infantry-attack", gearLevel: 3, ascensionCount: 1
                ),
                1.0 // Willowford standardWatch: neutral for infantry.
            ),
            (
                ParityCell(
                    soldierType: .archer, level: 1, kind: .arrowTower,
                    equippedItemID: "c04-archer-tower", gearLevel: 3, ascensionCount: 1
                ),
                0.80 // Falconridge arrowTower: archer is disadvantaged.
            ),
            (
                ParityCell(
                    soldierType: .siege, level: 1, kind: .keep,
                    equippedItemID: "c15-siege-keep", gearLevel: 3, ascensionCount: 1,
                    explicitCityAndLane: (city: 9, lane: .center) // Runewatch [keep]
                ),
                1.25 // Runewatch arcaneWard: siege is favoured.
            )
        ]
        for entry in cells {
            let cell = entry.cell
            let trait = Country1CityCatalog.definition(for: cell.city).defenseTrait
            #expect(
                trait.damageMultiplier(for: cell.soldierType) == entry.expectedTraitMultiplier,
                "\(cell): \(trait) must give \(cell.soldierType) ×\(entry.expectedTraitMultiplier)"
            )
            try expectParity(for: cell) { armed in
                let bonus = armed.equipmentSpecialistBonus(for: cell.soldierType)
                let specialistMultiplier = bonus?.target == cell.kind ? bonus?.multiplier : 1
                let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)
                return (role, specialistMultiplier ?? 1)
            }
        }
    }

    /// Fix round: a leveled specialist contributes no second-round bonus on
    /// a NONmatching objective — Lv1/Lv2/Lv3 gear at both Renown counts.
    /// The low integer level uses siege (the ×2 gate role makes any leak
    /// change the integer); the mid-power cell uses archer L5. Each cell
    /// pins the second round to the bare inherent role, and the leak guard
    /// proves the cell could have detected an erroneous specialist fold.
    @Test func leveledSpecialistAddsNoSecondRoundBonusOnNonMatchingObjectives() throws {
        for ascensionCount in [0, 1] {
            for gearLevel in [1, 2, 3] {
                for base in [
                    ParityCell(soldierType: .siege, level: 1, kind: .gate, equippedItemID: nil),
                    ParityCell(soldierType: .archer, level: 5, kind: .gate, equippedItemID: nil)
                ] {
                    let cell = ParityCell(
                        soldierType: base.soldierType,
                        level: base.level,
                        kind: base.kind,
                        equippedItemID: Self.specialistItemID(for: base.soldierType),
                        gearLevel: gearLevel,
                        ascensionCount: ascensionCount
                    )
                    let armed = armedParityState(for: cell)
                    let bonus = armed.equipmentSpecialistBonus(for: cell.soldierType)
                    #expect(
                        bonus?.target != cell.kind,
                        "\(cell): the equipped specialist must not target this objective"
                    )

                    let power = armed.traitAdjustedSoldierAttackPower(
                        for: cell.soldierType,
                        level: cell.level
                    )
                    let role = cell.soldierType.objectiveDamageMultiplier(against: cell.kind)
                    let clean = max(1, Int((Double(power) * role).rounded()))
                    let withLeak = max(
                        1,
                        Int((Double(power) * role * (bonus?.multiplier ?? 1)).rounded())
                    )
                    #expect(
                        clean != withLeak,
                        "\(cell): leak guard — clean \(clean) vs leaked \(withLeak)"
                    )

                    #expect(try liveFirstHitDamage(for: cell) == clean, "\(cell) live")
                    #expect(idleSettlementDamage(for: cell) == clean, "\(cell) idle")
                }
            }
        }
    }

    private static func specialistKind(for type: SoldierType) -> CitySiegeLayout.ObjectiveKind {
        switch type {
        case .infantry: return .gate
        case .archer: return .arrowTower
        case .cavalry, .mage: return .barracks
        case .siege: return .keep
        }
    }

    private static func attackItemID(for type: SoldierType) -> String {
        switch type {
        case .infantry: return "c01-infantry-attack"
        case .archer: return "c02-archer-attack"
        case .cavalry: return "c05-cavalry-attack"
        case .mage: return "c08-mage-attack"
        case .siege: return "c11-siege-attack"
        }
    }

    /// Shared cell check: LIVE first hit and IDLE settlement both equal
    /// round(cachedPower × role × specialist), with cachedPower read through
    /// the real instance seam (trait × DY × gear × Renown in one round).
    private func expectParity(
        for cell: ParityCell,
        secondRoundMultipliers: (KingdomGameState) -> (role: Double, specialist: Double)
    ) throws {
        let armed = armedParityState(for: cell)
        let power = armed.traitAdjustedSoldierAttackPower(for: cell.soldierType, level: cell.level)
        let multipliers = secondRoundMultipliers(armed)
        let combined = max(
            1,
            Int((Double(power) * multipliers.role * multipliers.specialist).rounded())
        )

        #expect(try liveFirstHitDamage(for: cell) == combined, "\(cell) live")
        #expect(idleSettlementDamage(for: cell) == combined, "\(cell) idle")
    }
}
