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
            ownedEquipmentIDs: ["c01-infantry-attack"]
        )
        state.treasury.drillYard = 2
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

        var city: Int {
            switch kind {
            case .gate: return 1 // Willowford center route [gate, keep]
            case .keep: return 1 // Willowford right route [keep]
            case .arrowTower: return 3 // Falconridge left route [arrow-tower, keep]
            case .barracks: return 5 // Highcrest left route [barracks, keep]
            }
        }

        var lane: BattleLane {
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
            let gear = equippedItemID.map { ", \($0)" } ?? ", no gear"
            return "\(soldierType) L\(level) vs \(kind)\(gear)"
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

    private func armedParityState(for cell: ParityCell) -> KingdomGameState {
        var state = SiegeTestSupport.makeBattleState(
            atCity: cell.city,
            keepRemaining: 1_000_000, // clamps to the authored max: full Keep
            selectedLane: cell.lane,
            ownedEquipmentIDs: cell.equippedItemID.map { [$0] } ?? []
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
}
