//
//  KingdomGameStoreTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

struct KingdomGameStoreTests {
    @Test func loadReturnsFreshStateWhenNoSaveExists() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")

        let state = store.load()

        #expect(state == KingdomGameState())
    }

    @Test func saveAndLoadRoundTripsMutableState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let backgroundDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let saved = KingdomGameState(
            gold: 42,
            cityLevel: 4,
            normalSoldierUpgradeLevel: 3,
            lastBackgroundedAt: backgroundDate,
            countryNumber: 1,
            cityNumberInCountry: 4,
            completedCityCount: 3,
            stageStatus: .battleActive
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.countryNumber == 1)
        #expect(loaded.cityNumberInCountry == 4)
        #expect(loaded.completedCityCount == 3)
        #expect(loaded.stageStatus == .battleActive)
        #expect(loaded.cityMaxPower == KingdomGameState.cityMaxPower(for: 4))
        #expect(loaded.normalSoldierAttackPower == KingdomGameState.normalSoldierAttackPower(for: 3))
    }

    @Test func saveAndLoadRoundTripsSiegeProgress() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = SiegeTestSupport.makeBattleState(
            atCity: 3,
            gold: 30,
            keepRemaining: 20,
            supportDamage: [.gate: 4, .arrowTower: 6],
            selectedLane: .right
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.siegeProgress.selectedLane == .right)
        #expect(loaded.currentKeepRemainingPower == 20)
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: loaded))
        #expect(loaded.siegeProgress.damageByObjectiveID[gateID] == 4)
    }

    /// The Task 5 regression seed: mid-wave phase, partial reserve, two
    /// damaged Guards, and a damaged-but-alive Barracks.
    private static func makeHighcrestGuardSeedState() -> KingdomGameState {
        let layout = Country1CityCatalog.definition(for: 5).siegeLayout
        let barracksMax = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))[
            layout.barracksObjective?.id ?? ""
        ] ?? 0
        var state = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 30,
            keepRemaining: 300,
            supportDamage: [.barracks: barracksMax / 2],
            selectedLane: .left
        )
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 4.5,
            remainingReserve: 3,
            unresolvedGuards: [
                GuardSnapshot(lane: .left, remainingHP: 5),
                GuardSnapshot(lane: .right, remainingHP: 9)
            ]
        )
        return state
    }

    @Test func saveAndLoadRoundTripsHighcrestGuardReinforcements() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = Self.makeHighcrestGuardSeedState()

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        let guards = try #require(loaded.siegeProgress.guardReinforcements)
        #expect(guards.waveElapsedSeconds == 4.5)
        #expect(guards.remainingReserve == 3)
        #expect(guards.unresolvedGuards == [
            GuardSnapshot(lane: .left, remainingHP: 5),
            GuardSnapshot(lane: .right, remainingHP: 9)
        ])
        // The Barracks reloads damaged but alive.
        let barracksID = try #require(SiegeTestSupport.objectiveID(for: .barracks, in: loaded))
        let maxPowers = loaded.currentSiegeLayout.maxPowerAllocation(totalBudget: loaded.cityMaxPower)
        #expect(loaded.currentSiegeSnapshot.objectiveRemainingPower[barracksID]
            == (maxPowers[barracksID] ?? 0) - ((maxPowers[barracksID] ?? 0) / 2))
    }

    @Test func saveAndLoadRoundTripsVanguardCaptainProgress() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")

        // Damaged-but-alive: durable lane + HP + Rally bit; recovery is 0.
        var saved = SiegeTestSupport.makeBattleState(
            atCity: 3,
            gold: 30,
            keepRemaining: 20,
            selectedLane: .center
        )
        saved.siegeProgress.captain = VanguardCaptainProgress(
            lane: .left,
            remainingHP: 9,
            recoveryRemainingSeconds: 0,
            rallyConsumed: true
        )

        store.save(saved)
        var loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.siegeProgress.captain == VanguardCaptainProgress(
            lane: .left,
            remainingHP: 9,
            recoveryRemainingSeconds: 0,
            rallyConsumed: true
        ))

        // Retreating: HP 0 plus the persisted recovery clock survive.
        saved.siegeProgress.captain = VanguardCaptainProgress(
            lane: .right,
            remainingHP: 0,
            recoveryRemainingSeconds: 4.5,
            rallyConsumed: true
        )

        store.save(saved)
        loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.siegeProgress.captain == VanguardCaptainProgress(
            lane: .right,
            remainingHP: 0,
            recoveryRemainingSeconds: 4.5,
            rallyConsumed: true
        ))
    }

    @MainActor
    @Test("Reloaded Highcrest Guard state reconstructs Battle Guards at Keep progress")
    func reloadedHighcrestGuardStateReconstructsBattleAtKeepProgress() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = Self.makeHighcrestGuardSeedState()

        store.save(saved)
        let loaded = store.load()

        // Durable values survive the round trip exactly.
        let durable = try #require(loaded.siegeProgress.guardReinforcements)
        #expect(durable.waveElapsedSeconds == 4.5)
        #expect(durable.remainingReserve == 3)
        #expect(durable.unresolvedGuards == [
            GuardSnapshot(lane: .left, remainingHP: 5),
            GuardSnapshot(lane: .right, remainingHP: 9)
        ])

        // Battle reconstruction (the scene loads from the store itself)
        // recreates both Guards at Keep progress with their persisted,
        // unhealed HP and fresh transient IDs in persisted lane order.
        let scene = BattleScene(size: CGSize(width: 390, height: 844), store: store)
        let guards = scene.livingGuardsForTesting
        #expect(guards.map(\.id) == [1, 2])
        #expect(guards.map(\.lane) == [.left, .right])
        #expect(guards.map(\.currentHP) == [5, 9])
        let keepProgress = loaded.currentSiegeLayout.keepObjective.visualProgress
        #expect(guards.map(\.position) == [keepProgress, keepProgress])
        #expect(scene.gameStateForTesting.siegeProgress.guardReinforcements == durable)
    }

    @Test func saveAndLoadRoundTripsPendingMapState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = KingdomGameState(
            gold: 8,
            cityLevel: 2,
            normalSoldierUpgradeLevel: 2,
            countryNumber: 1,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.cityNumberInCountry == 2)
        #expect(loaded.completedCityCount == 2)
        #expect(loaded.stageStatus == .cityConqueredPendingMap)
    }

    @Test func liveConquestPendingResultSurvivesRelaunch() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        var saved = SiegeTestSupport.makeBattleState(gold: 0, keepRemaining: 5)
        saved.recordSoldierDeployment(type: .archer, source: .manual, lane: .right)
        saved.recordActiveBattleTime(1.5)
        _ = saved.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .archer,
                source: .manual,
                lane: .right,
                objectiveID: try #require(SiegeTestSupport.objectiveID(for: .keep, in: saved)),
                appliedDamage: 5
            )
        ])
        let expectedPending = try #require(saved.pendingBattleResult)

        store.save(saved)
        let loaded = store.load()

        #expect(loaded.pendingBattleResult == expectedPending)
        #expect(loaded.stageStatus == .cityConqueredPendingMap)
        #expect(loaded.activeSiegeSession == nil)
    }

    @Test func backgroundAndRelaunchPreserveActiveSiegeSession() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let backgroundDate = Date(timeIntervalSinceReferenceDate: 20_000)
        var saved = KingdomGameState(gold: 10)
        saved.recordSoldierDeployment(type: .mage, source: .building, lane: .left)
        saved.recordActiveBattleTime(2.5)
        let expectedSession = try #require(saved.activeSiegeSession)

        saved.enterBackground(at: backgroundDate)
        #expect(saved.activeSiegeSession == expectedSession)
        store.save(saved)
        let loaded = store.load()

        #expect(loaded.stageStatus == .battleActive)
        #expect(loaded.activeSiegeSession == expectedSession)
        #expect(loaded.activeSiegeSession?.deployments == expectedSession.deployments)
        #expect(loaded.activeSiegeSession?.activeBattleSeconds == 2.5)
    }

    @Test func saveAndLoadRoundTripsCityBuildingState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        var saved = KingdomGameState(gold: 100)
        #expect(saved.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 85))
        #expect(saved.upgradeBuilding(inSlot: 5) == .upgraded(cost: 12, newLevel: 2, remainingGold: 73))

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 5)?.type == .barracks)
        #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 5)?.level == 2)
    }

    @Test func loadDropsMalformedCityBuildingEntriesWithoutDiscardingSave() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let data = """
        {
          "gold": 64,
          "cityLevel": 1,
          "normalSoldierUpgradeLevel": 3,
          "lastBackgroundedAt": null,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {
            "1-1": {
              "slots": {
                "1": {
                  "type": "barracks",
                  "level": 2,
                  "spawnTimerElapsed": 1.5
                },
                "junk": {
                  "type": "archeryRange",
                  "level": 1,
                  "spawnTimerElapsed": 0
                },
                "2": {
                  "type": "unknown",
                  "level": 1,
                  "spawnTimerElapsed": 0
                }
              },
              "lastBuildingProgressResolvedAt": null
            }
          }
        }
        """.data(using: .utf8)!
        defaults.set(data, forKey: "state")

        let loaded = store.load()

        #expect(loaded.gold == 64)
        #expect(loaded.normalSoldierUpgradeLevel == 3)
        #expect(loaded.cityBattleStateForCurrentCity.occupiedSlotCount == 1)
        #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
        #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 1)?.level == 2)
        #expect(loaded.cityBattleStateForCurrentCity.building(inSlot: 2) == nil)
    }

    @Test func loadDropsOverflowingActiveSiegeSessionWithoutCrashing() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        // Two matching deployment rows whose counts overflow Int when merged.
        let nearMax = Int.max - 1
        let data = """
        {
          "gold": 64,
          "cityLevel": 1,
          "normalSoldierUpgradeLevel": 3,
          "lastBackgroundedAt": null,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {},
          "activeSiegeSession": {
            "cityKey": "1-1",
            "activeBattleSeconds": 1,
            "deployments": [
              {
                "type": "infantry",
                "source": "manual",
                "lane": 1,
                "count": \(nearMax)
              },
              {
                "type": "infantry",
                "source": "manual",
                "lane": 1,
                "count": 2
              }
            ],
            "appliedDamage": [],
            "losses": [],
            "idleDamageByType": [],
            "usedFavorableUnit": false,
            "usedExposedLane": false
          }
        }
        """.data(using: .utf8)!
        defaults.set(data, forKey: "state")

        let loaded = store.load()

        #expect(loaded.gold == 64)
        #expect(loaded.stageStatus == .battleActive)
        #expect(loaded.activeSiegeSession == nil)
    }

    @Test func loadDropsMalformedActiveSiegeSessionWithoutDiscardingSave() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let data = """
        {
          "gold": 64,
          "cityLevel": 1,
          "normalSoldierUpgradeLevel": 3,
          "lastBackgroundedAt": null,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 0,
          "stageStatus": "battleActive",
          "cityBattleStates": {},
          "activeSiegeSession": "bogus"
        }
        """.data(using: .utf8)!
        defaults.set(data, forKey: "state")

        let loaded = store.load()

        #expect(loaded.gold == 64)
        #expect(loaded.normalSoldierUpgradeLevel == 3)
        #expect(loaded.stageStatus == .battleActive)
        #expect(loaded.activeSiegeSession == nil)
    }

    @Test func loadDropsMalformedPendingBattleResultWithoutDiscardingSave() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let data = """
        {
          "gold": 72,
          "cityLevel": 1,
          "normalSoldierUpgradeLevel": 4,
          "lastBackgroundedAt": null,
          "countryNumber": 1,
          "cityNumberInCountry": 1,
          "completedCityCount": 1,
          "stageStatus": "cityConqueredPendingMap",
          "cityBattleStates": {},
          "pendingBattleResult": "bogus"
        }
        """.data(using: .utf8)!
        defaults.set(data, forKey: "state")

        let loaded = store.load()

        #expect(loaded.gold == 72)
        #expect(loaded.normalSoldierUpgradeLevel == 4)
        #expect(loaded.stageStatus == .cityConqueredPendingMap)
        #expect(loaded.pendingBattleResult == nil)
    }

    @Test func loadReturnsFreshStateAndBacksUpCorruptData() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let corruptData = Data("{ not valid json !!!".utf8)
        defaults.set(corruptData, forKey: "state")

        let loaded = store.load()

        #expect(loaded == KingdomGameState())
        let backup = defaults.data(forKey: "state.corrupt")
        #expect(backup == corruptData)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
