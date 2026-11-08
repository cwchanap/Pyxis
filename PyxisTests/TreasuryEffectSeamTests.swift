//
//  TreasuryEffectSeamTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// HPA-670 Task 2: each Treasury effect has exactly one calculation seam.
/// War Chest gold quotes only through `goldReward(forCity:)`, Drill Yard
/// attack only through the single-round `traitAdjustedSoldierAttackPower`
/// fold, Quartermaster prices only through the state-aware `building*Cost`
/// pair. Zero-Treasury results must equal the base formulas exactly.
struct TreasuryEffectSeamTests {
    // MARK: - War Chest (gold seam)

    @Test("War Chest quote rounds once for the current and a scouted city")
    func warChestQuoteRoundsOnce() {
        var state = KingdomGameState()
        state.treasury.warChest = 3

        // Base curve pins: city 1 → 8, city 5 → round(8 × 1.45⁴) = 35.
        #expect(KingdomGameState.baseGoldReward(for: 1) == 8)
        #expect(KingdomGameState.baseGoldReward(for: 5) == 35)

        // Scouted different city: 35 × 1.30 = 45.5 → 46 in ONE round
        // (truncation or double rounding would give 45).
        #expect(state.goldReward(forCity: 5) == 46)

        // Current-city quote: 8 × 1.30 = 10.4 → 10.
        #expect(state.goldReward(forCity: state.cityLevel) == 10)
        #expect(state.currentGoldReward == state.goldReward(forCity: state.cityLevel))
        // Delegation really goes through the adjusted seam, not the base curve.
        #expect(state.currentGoldReward != KingdomGameState.baseGoldReward(for: state.cityLevel))
    }

    @Test("Zero War Chest quote equals the base curve exactly")
    func zeroWarChestQuoteEqualsBase() {
        let state = KingdomGameState()
        for city in Country1CityCatalog.cityRange {
            #expect(state.goldReward(forCity: city) == KingdomGameState.baseGoldReward(for: city))
        }
        #expect(state.currentGoldReward == KingdomGameState.baseGoldReward(for: state.cityLevel))
    }

    @Test("Conquest awards the adjusted quote exactly once")
    func conquestAwardsAdjustedQuote() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 3, gold: 5, keepRemaining: 26)
        state.treasury.warChest = 2

        let quote = state.goldReward(forCity: 3)
        #expect(quote == 20) // base 17 × 1.20 = 20.4 → 20

        let keepID = try #require(SiegeTestSupport.objectiveID(for: .keep, in: state))
        #expect(state.applyObjectiveDamage(26, toObjectiveID: keepID) == 26)

        #expect(state.stageStatus == .cityConqueredPendingMap)
        #expect(state.gold == 5 + quote)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.goldEarned == quote)

        // Exactly once: post-conquest damage awards nothing further.
        #expect(state.applyObjectiveDamage(26, toObjectiveID: keepID) == 0)
        #expect(state.gold == 5 + quote)
    }

    @Test("War Chest >0 quote parity: Map scout card, HUD value and current reward")
    func warChestQuoteParityAcrossMapAndHUD() {
        var state = KingdomGameState(gold: 5, cityNumberInCountry: 6, completedCityCount: 5)
        state.treasury.warChest = 2

        let quote = state.goldReward(forCity: 6)
        #expect(quote == 61) // base 51 × 1.20 = 61.2 → 61
        // The Battle HUD's displayed reward reads the same instance seam.
        #expect(state.currentGoldReward == quote)

        // The Map scout card quotes the same adjusted reward for the city.
        guard case .scout(let scout) = CountryMapScoutCardContent.project(from: state) else {
            Issue.record("expected a scout card projection")
            return
        }
        #expect(scout.cityNumber == 6)
        #expect(scout.goldReward == quote)
        #expect(scout.goldReward != KingdomGameState.baseGoldReward(for: 6))
    }

    @Test("Idle conquest awards the War Chest quote exactly once")
    func idleConquestAwardsWarChestQuoteExactlyOnce() throws {
        // A capped 8-hour armed window + one barracks conquers City 3 —
        // the same shape as the scene-entry idle conquest.
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        state.treasury.warChest = 2
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)

        let quote = state.goldReward(forCity: 3)
        let goldBefore = state.gold

        let result = state.returnFromBackground(at: Date(timeIntervalSinceReferenceDate: 0))

        #expect(result.conqueredCities == 1)
        #expect(result.goldEarned == quote)
        #expect(state.gold == goldBefore + quote)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.conquestMode == .idle)
        #expect(pending.goldEarned == quote)

        // Exactly once: nothing is credited again afterwards.
        _ = state.returnFromBackground(at: Date(timeIntervalSinceReferenceDate: 60))
        #expect(state.gold == goldBefore + quote)
    }

    @Test("Camp settlement conquest awards the War Chest quote exactly once")
    func campSettlementConquestAwardsWarChestQuoteExactlyOnce() throws {
        // A barracks armed with a capped 8-hour window conquers City 3
        // during the pre-action settle of a deliberate Camp build.
        let start = Date(timeIntervalSinceReferenceDate: -100_000)
        var state = KingdomGameState(
            gold: 200,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        state.treasury.warChest = 2
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)

        let quote = state.goldReward(forCity: 3)
        let goldBefore = state.gold

        let result = state.buildBuilding(
            .archeryRange,
            inSlot: 2,
            at: start.addingTimeInterval(100_000)
        )
        guard case .cityConqueredDuringSettlement(let goldEarned, let remainingGold) = result else {
            Issue.record("expected a settlement conquest, got \(result)")
            return
        }

        #expect(goldEarned == quote)
        #expect(state.gold == goldBefore + quote)
        #expect(remainingGold == state.gold)
        let pending = try #require(state.pendingBattleResult)
        #expect(pending.goldEarned == quote)
    }

    // MARK: - Drill Yard (attack seam)

    @Test("Drill Yard folds the upgrade multiplier into the single round")
    func drillYardSingleRoundPin() {
        // Spec illustration: 9 × 0.80 × 1.05 = 7.56 → 8 in one round;
        // rounding the trait first loses the point (round(7.2)=7 → 7).
        let singleRound = Int((9.0 * 0.80 * 1.05).rounded())
        let doubleRound = Int((Double(Int((9.0 * 0.80).rounded())) * 1.05).rounded())
        #expect(singleRound == 8)
        #expect(doubleRound == 7)

        // The same divergence through the real seam at the nearest reachable
        // base (the 1.38ˣ ceiling curve never yields 9): mage level 4 → base
        // 3, arrowTower mage disadvantage 0.80 → round(2.52) = 3, where a
        // double round would keep 2.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, multiplier: 1.05
        ) == 3)
        // The pre-HPA-670 call (default multiplier) is unchanged:
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower
        ) == 2)
    }

    @Test("Drill Yard matrix matches the single-round formula across reachable levels")
    func drillYardVisibilityMatrix() {
        for level in 1...8 {
            let base = KingdomGameState.normalSoldierAttackPower(for: level)
            for soldierType in SoldierType.allCases {
                for trait in CityDefenseTrait.allCases {
                    let traitMultiplier = trait.damageMultiplier(for: soldierType)
                    for drillYard in 0...10 {
                        let upgradeMultiplier = 1.0 + 0.05 * Double(drillYard)
                        let expected = max(1, Int(
                            (Double(base) * traitMultiplier * upgradeMultiplier).rounded()
                        ))
                        #expect(
                            KingdomGameState.traitAdjustedSoldierAttackPower(
                                for: soldierType,
                                level: level,
                                defenseTrait: trait,
                                multiplier: upgradeMultiplier
                            ) == expected,
                            "level \(level), \(soldierType), \(trait), DY \(drillYard)"
                        )
                    }
                }
            }
        }
    }

    @Test("Drill Yard purchases have pinned zero and nonzero visible deltas")
    func drillYardVisibilityPins() {
        // Level 1 (base 1) neutral trait: no visible gain until DY 10.
        for drillYard in 0...9 {
            #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                multiplier: 1.0 + 0.05 * Double(drillYard)
            ) == 1)
        }
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 1, defenseTrait: .standardWatch, multiplier: 1.5
        ) == 2)

        // Level 2 (base 2) neutral: no visible gain through DY 4; the first
        // visible gain is at DY 5 (2 × 1.25 = 2.5 rounds away from zero).
        for drillYard in 0...4 {
            #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                multiplier: 1.0 + 0.05 * Double(drillYard)
            ) == 2)
        }
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 2, defenseTrait: .standardWatch, multiplier: 1.25
        ) == 3)

        // Level 4 (base 3) disadvantaged 0.80: visible from the first level.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, multiplier: 1.0
        ) == 2)
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower, multiplier: 1.05
        ) == 3)
    }

    @Test("Instance attack power floors each bought Drill Yard rank at +1")
    func drillYardInstanceWrapper() {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 20)
        state.treasury.drillYard = 4

        // The static fold stays the raw single-round primitive — City 1 is
        // Standard Watch: base 2 × 1.0 × 1.2 = 2.4 → 2.
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry,
                level: 2,
                defenseTrait: state.currentCityDefenseTrait,
                multiplier: 1.2
            ) == 2
        )

        // The instance seam is the HPA-811 effective attack: each owned
        // rank adds at least +1, so DY4 lifts the same read to 6.
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 2) == 6)
    }

    @Test("Idle settlement consumes the Drill Yard adjusted power at a reachable level")
    func idleSettlementUsesDrillYardPower() {
        func singleSpawnIdleDamage(drillYard: Int) -> KingdomGameState.IdleProgressResult {
            var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil
            state.treasury.drillYard = drillYard

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            return state.returnFromBackground(at: start.addingTimeInterval(150))
        }

        // One level-5 infantry spawn (150 s idle → 15 s active-equivalent →
        // one 10 s barracks interval). City 1 is Standard Watch, so the only
        // difference is the Drill Yard fold. Both pins sit inside the tuned
        // purchasable ranges (barracks level 5, DY 3 of 1...4). The idle
        // path now consumes the same effective attack as live spawns: raw
        // round(4 × 1.15) = 5 is floored by the +1-per-rank rule to 7.
        let baseline = singleSpawnIdleDamage(drillYard: 0)
        let drilled = singleSpawnIdleDamage(drillYard: 3)

        #expect(baseline.conqueredCities == 0)
        #expect(baseline.damageDealt == 4) // DY0: raw and effective agree at 4
        #expect(drilled.conqueredCities == 0)
        #expect(drilled.damageDealt == 7) // effective: 4,5,6,7 across DY 0...3
    }

    @Test("A new live spawn carries the effective Drill Yard attack")
    func liveSpawnAttackMatchesIdleSeam() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 100_000)
        state.treasury.drillYard = 3

        let key = state.currentCityKey
        var cityState = state.cityBattleState(for: key)
        cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
        cityState.setBuilding(CityBuilding(type: .barracks, level: 1), inSlot: 2)
        state.cityBattleStates[key.storageKey] = cityState

        // The live injection path (BattleScene's per-tick spawn) prices each
        // BuildingSpawn through the instance seam exactly once.
        let spawns = state.resolveActiveBuildingSpawns(deltaTime: 10)
        #expect(spawns.map(\.level) == [5, 1])
        #expect(spawns.allSatisfy { $0.soldierType == .infantry })

        var combat = BattleCombatState(configuration: .live(cityLevel: state.cityLevel))
        var attackBySpawnLevel: [Int: Int] = [:]
        for spawn in spawns {
            let id = combat.spawnSoldier(
                type: spawn.soldierType,
                source: .building,
                level: spawn.level,
                attackPower: state.traitAdjustedSoldierAttackPower(
                    for: spawn.soldierType,
                    level: spawn.level
                ),
                lane: state.siegeProgress.selectedLane
            )
            attackBySpawnLevel[spawn.level] = try #require(combat.soldier(id: id)).attackPower
        }

        // DY3 effective attack: the raw single-round values (round(4 × 1.15)
        // = 5; round(1 × 1.15) = 1 — the formerly rounded-away case) sit
        // below the +1-per-rank floor, so the seam live and idle share
        // reads 7 at level 5 and 4 at level 1.
        #expect(attackBySpawnLevel[5] == 7)
        #expect(attackBySpawnLevel[1] == 4)
        // The static primitive keeps the raw percentage for test oracles.
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry,
                level: 5,
                defenseTrait: state.currentCityDefenseTrait,
                multiplier: 1.15
            ) == 5
        )
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry,
                level: 1,
                defenseTrait: state.currentCityDefenseTrait,
                multiplier: 1.15
            ) == 1
        )
    }

    @Test("Soldiers already on the field keep their cached attack after a Drill Yard purchase")
    func deployedSoldiersKeepCachedAttackAfterDrillYardPurchase() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, gold: 100, keepRemaining: 100_000)
        var combat = BattleCombatState(configuration: .live(cityLevel: state.cityLevel))
        let deployedID = combat.spawnSoldier(
            type: .infantry,
            source: .building,
            level: 5,
            attackPower: state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5),
            lane: state.siegeProgress.selectedLane
        )
        // The level-1 case is the one that used to round a paid upgrade
        // away entirely (1 × 1.15 → 1).
        let lowID = combat.spawnSoldier(
            type: .infantry,
            source: .building,
            level: 1,
            attackPower: state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1),
            lane: state.siegeProgress.selectedLane
        )
        // DY 0: level-5 infantry vs Standard Watch → round(4 × 1.0) = 4;
        // level 1 → 1.
        #expect(combat.soldier(id: deployedID)?.attackPower == 4)
        #expect(combat.soldier(id: lowID)?.attackPower == 1)

        // 100 gold buys three Drill Yard levels (16 + 29 + 52 = 97).
        for _ in 0..<3 {
            guard case .purchased = state.purchaseTreasuryUpgrade(.drillYard) else {
                Issue.record("expected the Drill Yard purchase to succeed")
                return
            }
        }
        #expect(state.treasury.drillYard == 3)

        // On-field soldiers keep their spawn-time cached attack; only NEW
        // spawns pick up the effective power (7 at level 5, 4 at level 1).
        #expect(combat.soldier(id: deployedID)?.attackPower == 4)
        #expect(combat.soldier(id: lowID)?.attackPower == 1)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 7)
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 1) == 4)
    }

    // MARK: - HPA-671 attack gear in the same first round

    @Test("Attack gear folds into the trait × Drill Yard single round")
    func attackGearFoldsIntoTheSingleRound() {
        for level in 1...8 {
            let base = KingdomGameState.normalSoldierAttackPower(for: level)
            for soldierType in SoldierType.allCases {
                for trait in CityDefenseTrait.allCases {
                    let traitMultiplier = trait.damageMultiplier(for: soldierType)
                    for drillYard in [0, 2, 4] {
                        let drillMultiplier = 1.0 + 0.05 * Double(drillYard)
                        for hasGear in [false, true] {
                            let gearMultiplier = hasGear ? 1.15 : 1.0
                            let expected = max(1, Int(
                                (Double(base) * traitMultiplier * drillMultiplier * gearMultiplier).rounded()
                            ))
                            #expect(
                                KingdomGameState.traitAdjustedSoldierAttackPower(
                                    for: soldierType,
                                    level: level,
                                    defenseTrait: trait,
                                    multiplier: drillMultiplier * gearMultiplier
                                ) == expected,
                                "level \(level), \(soldierType), \(trait), DY \(drillYard), gear \(hasGear)"
                            )
                        }
                    }
                }
            }
        }
    }

    @Test("Attack gear pin: one round beats trait-first double rounding")
    func attackGearSingleRoundPin() {
        // Mage L4 base 3, arrowTower disadvantage 0.80, DY 1 (× 1.05), gear
        // × 1.15: 3 × 0.80 × 1.05 × 1.15 = 2.898 → 3 in one round. Rounding
        // the trait first (round(2.4) = 2) ends at round(2.415) = 2.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .mage, level: 4, defenseTrait: .arrowTower,
            multiplier: 1.05 * 1.15
        ) == 3)
        let traitRoundedFirst = Int((Double(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .mage, level: 4, defenseTrait: .arrowTower
            )
        ) * 1.05 * 1.15).rounded())
        #expect(traitRoundedFirst == 2)
    }

    @Test("Zero equipment: raw at DY0, bounded effective floor above, capped out-of-range")
    func zeroEquipmentMatchesPreEquipmentFormula() {
        // No gear owned, no Renown. At DY0 the effective value equals the
        // pure trait fold exactly; from DY1 the +1-per-rank floor may lift
        // it above raw; a directly assigned out-of-range level behaves
        // like the purchasable cap instead of over-multiplying.
        var state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 500)
        for drillYard in 0...10 {
            state.treasury.drillYard = drillYard
            let cappedDrillYard = min(drillYard, 4)
            let rawMultiplier = 1.0 + 0.05 * Double(cappedDrillYard)
            for soldierType in SoldierType.allCases {
                let effective = state.traitAdjustedSoldierAttackPower(
                    for: soldierType, level: 5
                )
                let raw = KingdomGameState.traitAdjustedSoldierAttackPower(
                    for: soldierType,
                    level: 5,
                    defenseTrait: state.currentCityDefenseTrait,
                    multiplier: rawMultiplier
                )
                // Effective never drops below the raw percentage…
                #expect(effective >= raw, "\(soldierType) at DY \(drillYard)")
                // … equals it exactly at DY0 …
                if drillYard == 0 {
                    #expect(effective == raw, "\(soldierType) at DY 0")
                }
                // … and the +1-per-rank floor binds exactly: effective
                // never exceeds raw + bought rank.
                #expect(
                    effective <= raw + cappedDrillYard,
                    "\(soldierType) at DY \(drillYard)"
                )
            }
        }
        // Directly assigned DY10 behaves like DY4 (no 1.5× multiplier).
        state.treasury.drillYard = 4
        for soldierType in SoldierType.allCases {
            let atCap = state.traitAdjustedSoldierAttackPower(for: soldierType, level: 5)
            state.treasury.drillYard = 10
            #expect(
                state.traitAdjustedSoldierAttackPower(for: soldierType, level: 5) == atCap,
                "\(soldierType) DY10 == DY4"
            )
            state.treasury.drillYard = 4
        }
    }

    // MARK: - HPA-672 Renown in the same two seams

    @Test("renownMultiplier is 1 + 0.25 × ascension count")
    func renownMultiplierCurve() {
        for (count, expected) in [(0, 1.0), (1, 1.25), (2, 1.5), (4, 2.0), (12, 4.0)] {
            let state = KingdomGameState(ascensionCount: count)
            #expect(state.renownMultiplier == expected, "count \(count)")
        }
    }

    @Test("Renown folds into the single gold round with War Chest and base")
    func renownFoldsIntoTheSingleGoldRound() {
        var state = KingdomGameState(ascensionCount: 1)
        state.treasury.warChest = 3

        // Base 35 × War Chest 1.30 × Renown 1.25 = 56.875 → 57 in ONE round.
        // Rounding the War Chest first (46) then Renown gives round(57.5) = 58.
        #expect(state.goldReward(forCity: 5) == 57)
        #expect(Int((35.0 * 1.30 * 1.25).rounded()) == 57)
        #expect(Int((Double(Int((35.0 * 1.30).rounded())) * 1.25).rounded()) == 58)

        // Current-city quote rides the same single seam.
        #expect(state.currentGoldReward == state.goldReward(forCity: state.cityLevel))
    }

    @Test("Zero Renown gold quote is bit-identical to the War Chest seam; every count scales it")
    func zeroRenownGoldQuoteIdentityAndScaling() {
        let zero = KingdomGameState()
        let one = KingdomGameState(ascensionCount: 1)
        let two = KingdomGameState(ascensionCount: 2)

        for city in Country1CityCatalog.cityRange {
            let base = KingdomGameState.baseGoldReward(for: city)
            #expect(zero.goldReward(forCity: city) == base)
            // 1.25 and 1.5 folds, each still one rounding.
            #expect(one.goldReward(forCity: city) == max(1, Int((Double(base) * 1.25).rounded())))
            #expect(two.goldReward(forCity: city) == max(1, Int((Double(base) * 1.5).rounded())))
        }

        // The spec's City 1 pin: base 8 × 1.25 = 10 at Renown 1.
        #expect(one.goldReward(forCity: 1) == 10)
    }

    @Test("firstRoundAttackMultiplier composes Drill Yard × leveled attack gear × Renown")
    func firstRoundAttackMultiplierComposition() {
        var state = KingdomGameState(
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"],
            equipmentLevelsByID: ["c01-infantry-attack": 2],
            ascensionCount: 1
        )
        state.treasury.drillYard = 2

        // 1.10 × 1.225 × 1.25 = 1.684375.
        #expect(state.firstRoundAttackMultiplier(for: .infantry) == 1.1 * 1.225 * 1.25)
        // An unequipped type drops only the gear factor.
        #expect(state.firstRoundAttackMultiplier(for: .siege) == 1.1 * 1.25)

        // Zero Renown, zero gear, zero Treasury is exactly 1.
        #expect(KingdomGameState().firstRoundAttackMultiplier(for: .infantry) == 1)
    }

    @Test("Renown folds into the single-round attack at low integer levels")
    func renownSingleRoundAttackPin() {
        // Infantry L1 (base 1), Standard Watch, Renown 1, attack gear Lv3
        // (× 1.30): 1 × 1 × 1.25 × 1.30 = 1.625 → 2 in ONE round. Without
        // Renown the same loadout stays 1 (1.3 → 1) — the exact low-level
        // case where the permanent bonus first becomes visible.
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 1, defenseTrait: .standardWatch, multiplier: 1.25 * 1.30
        ) == 2)
        #expect(KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .infantry, level: 1, defenseTrait: .standardWatch, multiplier: 1.30
        ) == 1)
    }

    @Test("A Renown-1 spawn prices identically on the live and idle paths")
    func renownSpawnMatchesAcrossLiveAndIdle() {
        func singleSpawnIdleDamage(ascensionCount: Int) -> Int {
            var state = SiegeTestSupport.makeBattleState(
                atCity: 1,
                keepRemaining: 100_000,
                ascensionCount: ascensionCount
            )
            SiegeTestSupport.destroySupportObjectives(of: &state)
            state.siegeProgress.guardReinforcements = nil

            let key = state.currentCityKey
            var cityState = state.cityBattleState(for: key)
            cityState.setBuilding(CityBuilding(type: .barracks, level: 5), inSlot: 1)
            state.cityBattleStates[key.storageKey] = cityState

            let start = Date(timeIntervalSinceReferenceDate: 0)
            state.enterBackground(at: start)
            return state.returnFromBackground(at: start.addingTimeInterval(150)).damageDealt
        }

        // One level-5 infantry spawn: base 4 × 1.25 = 5 on both paths. The
        // live-spawn parity is the instance seam BattleScene passes into
        // spawnSoldier — same value the idle budget consumed.
        let state = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: 100_000,
            ascensionCount: 1
        )
        #expect(state.traitAdjustedSoldierAttackPower(for: .infantry, level: 5) == 5)
        #expect(singleSpawnIdleDamage(ascensionCount: 1) == 5)
        #expect(singleSpawnIdleDamage(ascensionCount: 0) == 4)
    }

    @Test("Renown never touches city HP, camp prices, spawn rates or soldier HP")
    func renownLeavesEveryOtherBalanceConstantAlone() {
        let zero = SiegeTestSupport.makeBattleState(atCity: 5, gold: 500, keepRemaining: 900)
        let one = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 500,
            keepRemaining: 900,
            ascensionCount: 1
        )

        #expect(one.cityMaxPower == zero.cityMaxPower)
        #expect(one.currentSiegeMaxPowers == zero.currentSiegeMaxPowers)
        for type in BuildingType.allCases {
            #expect(one.buildingBuildCost(for: type) == zero.buildingBuildCost(for: type))
            #expect(
                one.buildingUpgradeCost(for: type, currentLevel: 2)
                    == zero.buildingUpgradeCost(for: type, currentLevel: 2)
            )
        }
        #expect(one.equipmentMaxHPMultiplier(for: .infantry) == zero.equipmentMaxHPMultiplier(for: .infantry))
        // Spawn intervals and the Captain's attack rule are static curves that
        // never read state, so Renown cannot reach them by construction.

        // Gold is the one thing that moves.
        #expect(one.goldReward(forCity: 5) > zero.goldReward(forCity: 5))
    }

    // MARK: - Quartermaster (cost seam)

    @Test("Quartermaster discounts quotes with a single rounding")
    func quartermasterQuoteRoundsOnce() {
        var state = KingdomGameState()
        state.treasury.quartermaster = 4

        // Base pins under the renamed internal helpers.
        #expect(KingdomGameState.baseBuildingBuildCost(for: .mageTower) == 40)
        #expect(KingdomGameState.baseBuildingUpgradeCost(for: .stable, currentLevel: 1) == 22)

        // 40 × 0.84 = 33.6 → 34 in one round (truncation would give 33).
        #expect(state.buildingBuildCost(for: .mageTower) == 34)
        // 22 × 0.84 = 18.48 → 18.
        #expect(state.buildingUpgradeCost(for: .stable, currentLevel: 1) == 18)

        var midState = KingdomGameState()
        midState.treasury.quartermaster = 5
        #expect(midState.buildingBuildCost(for: .barracks) == 12) // 15 × 0.80

        var maxedState = KingdomGameState()
        maxedState.treasury.quartermaster = TreasuryUpgrade.quartermaster.maxLevel
        #expect(maxedState.buildingUpgradeCost(for: .siegeWorkshop, currentLevel: 1) == 35) // 42 × 0.84

        // Zero Quartermaster equals the base curves exactly.
        let fresh = KingdomGameState()
        for type in BuildingType.allCases {
            #expect(fresh.buildingBuildCost(for: type) == KingdomGameState.baseBuildingBuildCost(for: type))
            #expect(
                fresh.buildingUpgradeCost(for: type, currentLevel: 3)
                    == KingdomGameState.baseBuildingUpgradeCost(for: type, currentLevel: 3)
            )
        }
    }

    @Test("Camp display, recommendation, buyer, affordability and debit share one discounted quote")
    func campQuoteChargeParityUnderQuartermaster() throws {
        var state = KingdomGameState(gold: 100, cityNumberInCountry: 5, completedCityCount: 4)
        state.treasury.quartermaster = 3 // × 0.88

        let buildQuote = state.buildingBuildCost(for: .barracks)
        #expect(buildQuote == 13) // 15 × 0.88 = 13.2 → 13

        // Camp selection displays the discounted price.
        let content = CampSelectionContent.project(from: state, selectedSlot: nil)
        let barracksOption = try #require(content.options.first { $0.buildingType == .barracks })
        guard case .available(let displayedCost) = barracksOption.state else {
            Issue.record("expected an available barracks option, got \(barracksOption.state)")
            return
        }
        #expect(displayedCost == buildQuote)

        // The recommendation quotes the same price.
        guard case .ready(let recommendation, _) = RecommendedCampRecommendation.make(for: state) else {
            Issue.record("expected a ready recommendation")
            return
        }
        #expect(recommendation.cost == buildQuote)

        // The balance-harness buyer candidate quotes the same price.
        let buyerAction = try #require(GreedyCampBuyer.nextAction(for: state))
        #expect(buyerAction.cost == buildQuote)

        // The actual debit equals the quote.
        guard case .built(let debited, let remainingGold) = state.buildBuilding(.barracks, inSlot: 1) else {
            Issue.record("expected the barracks build to succeed")
            return
        }
        #expect(debited == buildQuote)
        #expect(remainingGold == 100 - buildQuote)
        #expect(state.gold == remainingGold)

        // Upgrade path: same parity for the inspector, recommendation, buyer and debit.
        let upgradeQuote = state.buildingUpgradeCost(for: .barracks, currentLevel: 1)
        #expect(upgradeQuote == 11) // 12 × 0.88 = 10.56 → 11

        let selected = CampSelectionContent.project(from: state, selectedSlot: 1)
        #expect(selected.inspector?.upgradeCost == upgradeQuote)
        guard case .ready(let upgradeRecommendation, _) = RecommendedCampRecommendation.make(for: state) else {
            Issue.record("expected a ready upgrade recommendation")
            return
        }
        #expect(upgradeRecommendation.kind == .upgrade)
        #expect(upgradeRecommendation.cost == upgradeQuote)
        let upgradeBuyerAction = try #require(GreedyCampBuyer.nextAction(for: state))
        #expect(upgradeBuyerAction.kind == .upgrade)
        #expect(upgradeBuyerAction.cost == upgradeQuote)

        guard case .upgraded(let upgradeDebit, _, let upgradeRemaining) = state.upgradeBuilding(inSlot: 1) else {
            Issue.record("expected the upgrade to succeed")
            return
        }
        #expect(upgradeDebit == upgradeQuote)
        #expect(state.gold == 100 - buildQuote - upgradeQuote)
        #expect(upgradeRemaining == state.gold)
    }

    // MARK: - HPA-811 effective attack (rank-floor projection)

    @Test("Effective attack pins: Soldier Lv1 gains, Lv10 percentage already dominates")
    func effectiveAttackPins() {
        let attackEffect: EquipmentEffect = .attackBonus(0.15)

        // Soldier Lv1, Standard Watch, Renown 0 — the fresh-player case
        // where the old formula rounded every paid upgrade back to 1.
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 0, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            ) == 1
        )
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 1, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            ) == 2
        )
        for (gearRank, expected) in [(1, 2), (2, 3), (3, 4)] {
            #expect(
                KingdomGameState.effectiveSoldierAttackPower(
                    for: .infantry, level: 1, defenseTrait: .standardWatch,
                    drillYardLevel: 0, attackEffect: attackEffect,
                    ownedGearLevel: gearRank, renownMultiplier: 1
                ) == expected,
                "gear rank \(gearRank)"
            )
        }
        // DY1 + gear Lv1: two owned ranks → 3.
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 1, attackEffect: attackEffect, ownedGearLevel: 1,
                renownMultiplier: 1
            ) == 3
        )

        // Soldier Lv10 + DY4 + Lv3 attack item: the raw percentage already
        // dominates — raw and effective agree at 30.
        #expect(
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .infantry, level: 10, defenseTrait: .standardWatch,
                multiplier: 1.2 * 1.30
            ) == 30
        )
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 10, defenseTrait: .standardWatch,
                drillYardLevel: 4, attackEffect: attackEffect, ownedGearLevel: 3,
                renownMultiplier: 1
            ) == 30
        )
    }

    @Test("Every adjacent Drill Yard or attack-gear rank adds at least +1 effective attack")
    func effectiveAttackFloorMatrix() {
        let attackEffect: EquipmentEffect = .attackBonus(0.15)
        for type in SoldierType.allCases {
            for level in 1...19 {
                // All seven traits give every type the 1.25 / 1.0 / 0.80 factors.
                for trait in CityDefenseTrait.allCases {
                    for renown in [1.0, 1.25, 1.5, 2.0] {
                        for drillYard in 0...4 {
                            var previousGearValue = 0
                            for gearRank in 0...3 {
                                let effective = KingdomGameState.effectiveSoldierAttackPower(
                                    for: type, level: level, defenseTrait: trait,
                                    drillYardLevel: drillYard,
                                    attackEffect: attackEffect,
                                    ownedGearLevel: gearRank,
                                    renownMultiplier: renown
                                )
                                if gearRank > 0 {
                                    #expect(
                                        effective > previousGearValue,
                                        Comment(
                                            rawValue: "\(type) Lv\(level) \(trait) renown \(renown) "
                                                + "DY\(drillYard) gear \(gearRank - 1)→\(gearRank)"
                                        )
                                    )
                                }
                                previousGearValue = effective

                                if drillYard > 0 {
                                    let predecessor = KingdomGameState.effectiveSoldierAttackPower(
                                        for: type, level: level, defenseTrait: trait,
                                        drillYardLevel: drillYard - 1,
                                        attackEffect: attackEffect,
                                        ownedGearLevel: gearRank,
                                        renownMultiplier: renown
                                    )
                                    #expect(
                                        effective > predecessor,
                                        Comment(
                                            rawValue: "\(type) Lv\(level) \(trait) renown \(renown) "
                                                + "gear \(gearRank) DY\(drillYard - 1)→\(drillYard)"
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("A rank-0 attack effect is the no-gear baseline, never phantom Lv1")
    func rankZeroAttackEffectIsNoGear() {
        let attackEffect: EquipmentEffect = .attackBonus(0.15)
        let noGear = KingdomGameState.effectiveSoldierAttackPower(
            for: .infantry, level: 1, defenseTrait: .standardWatch,
            drillYardLevel: 0, attackEffect: nil, ownedGearLevel: 0,
            renownMultiplier: 1
        )
        for ownedLevel in [0, -1] {
            #expect(
                KingdomGameState.effectiveSoldierAttackPower(
                    for: .infantry, level: 1, defenseTrait: .standardWatch,
                    drillYardLevel: 0, attackEffect: attackEffect,
                    ownedGearLevel: ownedLevel, renownMultiplier: 1
                ) == noGear,
                "ownedGearLevel \(ownedLevel)"
            )
        }
        // The +15% exists only once a real rank does.
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 0, attackEffect: attackEffect, ownedGearLevel: 1,
                renownMultiplier: 1
            ) == 2
        )
    }

    @Test("Non-attack effects never arm the gear dimension; out-of-band ranks clamp")
    func effectiveAttackInputNormalization() {
        // Toughness / specialist effects at any owned level: no gear
        // dimension, so the value stays the no-gear baseline.
        for effect in [
            EquipmentEffect.maxHPBonus(0.25),
            .specialistBonus(target: .gate, fraction: 0.40)
        ] {
            for ownedLevel in [1, 3] {
                #expect(
                    KingdomGameState.effectiveSoldierAttackPower(
                        for: .infantry, level: 1, defenseTrait: .standardWatch,
                        drillYardLevel: 0, attackEffect: effect,
                        ownedGearLevel: ownedLevel, renownMultiplier: 1
                    ) == 1,
                    "\(effect) at owned level \(ownedLevel)"
                )
            }
        }

        let attackEffect: EquipmentEffect = .attackBonus(0.15)
        // Gear rank >3 clamps to the authored Lv3 cell.
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 0, attackEffect: attackEffect, ownedGearLevel: 10,
                renownMultiplier: 1
            ) == KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 1, defenseTrait: .standardWatch,
                drillYardLevel: 0, attackEffect: attackEffect, ownedGearLevel: 3,
                renownMultiplier: 1
            )
        )
        // Negative Drill Yard behaves like DY0; DY10 behaves like the DY4 cap.
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                drillYardLevel: -3, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            ) == KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                drillYardLevel: 0, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            )
        )
        #expect(
            KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                drillYardLevel: 10, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            ) == KingdomGameState.effectiveSoldierAttackPower(
                for: .infantry, level: 2, defenseTrait: .standardWatch,
                drillYardLevel: 4, attackEffect: nil, ownedGearLevel: 0,
                renownMultiplier: 1
            )
        )
    }
}
