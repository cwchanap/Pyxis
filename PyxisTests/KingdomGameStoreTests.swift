//
//  KingdomGameStoreTests.swift
//  PyxisTests
//

import Foundation
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
            cityRemainingPower: 123,
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

    @Test func saveAndLoadRoundTripsPendingMapState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let saved = KingdomGameState(
            gold: 8,
            cityLevel: 2,
            cityRemainingPower: 0,
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
        var saved = KingdomGameState(gold: 0, cityRemainingPower: 5)
        saved.recordSoldierDeployment(type: .archer, source: .manual, lane: .right)
        saved.recordActiveBattleTime(1.5)
        _ = saved.applyLiveSoldierAttacks([
            SoldierAttackEvent(
                soldierID: 1,
                type: .archer,
                source: .manual,
                lane: .right,
                appliedCityDamage: 5
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
        var saved = KingdomGameState(gold: 10, cityRemainingPower: 20)
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
          "cityRemainingPower": 12,
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
        #expect(loaded.cityRemainingPower == 12)
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
          "cityRemainingPower": 12,
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
          "cityRemainingPower": 12,
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
        #expect(loaded.cityRemainingPower == 12)
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
          "cityRemainingPower": 0,
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
        #expect(loaded.cityRemainingPower == 0)
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
