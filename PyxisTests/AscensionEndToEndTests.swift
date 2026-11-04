//
//  AscensionEndToEndTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

/// HPA-672 Task 6: the real finale → Ascend → replay-conquest chain in one
/// assertion path. The City 15 killing blow is fought by manual infantry
/// inside a live `BattleCombatState` whose REAL attack events flow through
/// the production `applyLiveSoldierAttacks` seam, the pending report is
/// persisted through the real `KingdomGameStore` and acknowledged through
/// the production Continue path, the Kingdom scene commits through its
/// real two-tap hit frames, and the City 1 replay conquest is fought by
/// manual infantry inside the production `BattleScene` rail. No forged
/// conquest, no artificial reward, no handcrafted lethal event.
@MainActor
struct AscensionEndToEndTests {

    private final class AscendRouteSpy: KingdomSceneRouting {
        private(set) var requestedTabs: [GameplayTab] = []

        func kingdomSceneDidRequestGameplayTab(_ scene: KingdomScene, tab: GameplayTab) -> Bool {
            requestedTabs.append(tab)
            return true
        }

        func kingdomScene(_ scene: KingdomScene, didRequestLayoutGate reason: AppLayoutGateReason) {}
    }

    @Test("Real finale → Continue → Ascend confirm → City 1 manual replay conquest levels owned gear")
    func finaleAcknowledgeAscendAndManualReplayConquestChain() throws {
        // A first full completion in progress: City 15 nearly fallen, every
        // catalog drop owned at Lv1 except this city's own (still unclaimed).
        let city15Drop = try #require(EquipmentCatalog.byCity(15))
        let ownedBeforeFinale = EquipmentCatalog.items
            .filter { $0.id != city15Drop.id }
            .map(\.id)
        var state = SiegeTestSupport.makeBattleState(
            atCity: 15,
            gold: 10,
            keepRemaining: 1,
            ownedEquipmentIDs: ownedBeforeFinale
        )
        // Nearly fallen: every support objective already destroyed, so the
        // Keep is the only live objective on the route.
        SiegeTestSupport.destroySupportObjectives(of: &state)

        // 1. The real killing blow conquers City 15 through the same
        //    simulator path BattleScene drives: manual deploys into a live
        //    `BattleCombatState`, per-tick combat against the authored City
        //    15 snapshot, and the simulator's own attack/loss events
        //    forwarded into the state — no handcrafted lethal event.
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

        #expect(state.stageStatus == .countryComplete)
        let finale = try #require(state.pendingBattleResult)
        // First-ever drop of this city's item: level 1, one typed receipt.
        #expect(finale.equipmentReward == EquipmentReward(itemID: city15Drop.id, level: 1))
        #expect(state.equipmentLevel(for: city15Drop.id) == 1)

        // 2. Continue: persist the pending finale through the real store,
        //    then acknowledge + save — the exact thing BattleScene's
        //    Continue does — before Ascension becomes available.
        let suiteName = "AscensionEndToEnd.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(state)
        let persistedFinale = store.load()
        #expect(persistedFinale.pendingBattleResult?.equipmentReward == finale.equipmentReward)

        state.acknowledgePendingBattleResult()
        #expect(state.pendingBattleResult == nil)
        store.save(state)
        #expect(store.load().pendingBattleResult == nil)

        // 3. Kingdom: Ascend is visible and eligible; the real two-tap
        //    confirm commits and routes to Battle.
        let router = AscendRouteSpy()
        let scene = Self.makeKingdomScene(store: store, router: router)

        #expect(scene.isAscendActionEnabledForTesting)
        #expect(scene.ascendContentTextForTesting()?.requirement == nil)
        scene.handleTouchForTesting(
            at: mid(try #require(scene.ascendSelectorHitFrameForTesting()))
        )
        #expect(scene.selectedSectionForTesting == .ascend)

        let action = try #require(scene.ascendPrimaryActionHitFrameForTesting())
        scene.handleTouchForTesting(at: mid(action))
        #expect(scene.isAscendConfirmationArmedForTesting)
        #expect(router.requestedTabs.isEmpty)

        scene.handleTouchForTesting(at: mid(action))
        #expect(router.requestedTabs == [.battle])

        // 4. The committed save is the fresh replay run with permanent gear:
        //    City 1 battleActive, zero gold, empty Treasury/camp, and every
        //    owned item preserved at Lv1.
        let saved = store.load()
        #expect(saved.ascensionCount == 1)
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.countryNumber == 1)
        #expect(saved.cityNumberInCountry == 1)
        #expect(saved.gold == 0)
        #expect(saved.treasury == TreasuryState())
        #expect(saved.cityBattleStateForCurrentCity.occupiedSlotCount == 0)
        #expect(saved.ownedEquipmentIDs == EquipmentCatalog.items.map(\.id))
        for item in EquipmentCatalog.items {
            #expect(saved.equipmentLevel(for: item.id) == 1)
        }
        // Zero gold, no buildings: manual infantry at level 1 is the only
        // deployable type — the deliberate early-manual opening.
        #expect(saved.manualSpawnableSoldierTypes() == [.infantry])

        // 5. Real replay conquest from the committed save through the
        //    production BattleScene rail: manual spawns only (there is no
        //    camp to buy from), same fixed seed as the balance gate.
        let expectedGoldReward = saved.goldReward(forCity: 1)
        let outcome = Country1SiegeSmoke.run(
            initialState: saved,
            store: store,
            defaults: defaults,
            seed: Country1SiegeSmoke.campaignSeed
        )
        let replay = outcome.finalState
        #expect(outcome.reachedConquest)
        #expect(replay.stageStatus == .cityConqueredPendingMap)
        #expect(replay.cityNumberInCountry == 1)
        // Renown 1 quote: 8 × 1.25 = 10 — the zero-gold opening's income.
        #expect(expectedGoldReward == 10)
        #expect(replay.gold == expectedGoldReward)

        // The owned City 1 drop levels to 2 with one truthful receipt.
        let city1Drop = try #require(EquipmentCatalog.byCity(1))
        let expectedReceipt = EquipmentReward(itemID: city1Drop.id, level: 2)
        let report = try #require(replay.pendingBattleResult)
        #expect(report.equipmentReward == expectedReceipt)
        #expect(replay.equipmentLevel(for: city1Drop.id) == 2)
        for item in EquipmentCatalog.items where item.id != city1Drop.id {
            #expect(replay.equipmentLevel(for: item.id) == 1)
        }
        // Truthful manual-infantry conquest: no buildings existed, so every
        // deployment was a manual infantry soldier.
        #expect(!report.deployments.isEmpty)
        #expect(report.deployments.allSatisfy { $0.type == .infantry && $0.source == .manual })

        // 6. The receipt and level survive persistence.
        let persisted = store.load()
        #expect(persisted.pendingBattleResult?.equipmentReward == expectedReceipt)
        #expect(persisted.equipmentLevel(for: city1Drop.id) == 2)
    }

    private func mid(_ frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private static func makeKingdomScene(
        store: KingdomGameStore,
        router: KingdomSceneRouting
    ) -> KingdomScene {
        let size = CGSize(width: 393, height: 852)
        let scene = KingdomScene(
            size: size,
            store: store,
            router: router,
            safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 0, bottom: 34, right: 0
            )
        )
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: size)))
        return scene
    }
}
