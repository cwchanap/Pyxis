//
//  BattleResultModelsTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct BattleResultModelsTests {
    @Test func deploymentMergesRowsAndFlipsMarkers() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        session.recordDeployment(
            type: .mage,
            source: .manual,
            lane: .right,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )
        session.recordDeployment(
            type: .mage,
            source: .manual,
            lane: .right,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )
        session.recordDeployment(
            type: .infantry,
            source: .building,
            lane: .left,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )

        #expect(session.usedFavorableUnit)
        #expect(session.usedExposedLane)
        #expect(session.deployments == [
            SiegeDeploymentCount(type: .infantry, source: .building, lane: .left, count: 1),
            SiegeDeploymentCount(type: .mage, source: .manual, lane: .right, count: 2),
        ])
    }

    @Test func markersDoNotFlipFromDamageAlone() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 2))
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 1,
                type: .mage,
                source: .manual,
                lane: .right,
                appliedCityDamage: 5
            )
        )

        #expect(!session.usedFavorableUnit)
        #expect(!session.usedExposedLane)
    }

    @Test func mvpUsesHighestDamageThenAllCasesOrder() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 3))
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 1,
                type: .cavalry,
                source: .manual,
                lane: .center,
                appliedCityDamage: 4
            )
        )
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 2,
                type: .infantry,
                source: .manual,
                lane: .left,
                appliedCityDamage: 4
            )
        )

        let result = session.finalized(conquestMode: .live, goldEarned: 10)

        #expect(result.mvpSoldierType == .infantry)
        #expect(result.mvpDamageSharePercent == 50)
        #expect(result.goldEarned == 10)
        #expect(result.conquestMode == .live)
    }

    @Test func mvpNilWhenNoAttributableDamage() {
        let session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 4))

        let result = session.finalized(conquestMode: .idle, goldEarned: 8)

        #expect(result.mvpSoldierType == nil)
        #expect(result.mvpDamageSharePercent == nil)
        #expect(result.conquestMode == .idle)
    }

    @Test func idleDamageMergesByType() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 5))
        session.recordIdleDamage(type: .archer, appliedDamage: 3)
        session.recordIdleDamage(type: .archer, appliedDamage: 2)
        session.recordIdleDamage(type: .siege, appliedDamage: 1)

        #expect(session.idleDamageByType == [
            SiegeIdleDamageByType(type: .archer, damage: 5),
            SiegeIdleDamageByType(type: .siege, damage: 1),
        ])

        let result = session.finalized(conquestMode: .idle, goldEarned: 1)
        #expect(result.mvpSoldierType == .archer)
        #expect(result.mvpDamageSharePercent == 83)
    }

    @Test func activeBattleTimeIgnoresNonPositiveDelta() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        session.advanceActiveBattleTime(1.25)
        session.advanceActiveBattleTime(-4)
        session.advanceActiveBattleTime(0)

        #expect(session.activeBattleSeconds == 1.25)
    }

    @Test func cityKeyAndBattleLaneRoundTrip() throws {
        let key = CityKey(countryNumber: 1, cityNumber: 7)
        let encodedKey = try JSONEncoder().encode(key)
        let decodedKey = try JSONDecoder().decode(CityKey.self, from: encodedKey)
        #expect(decodedKey == key)

        let laneData = try JSONEncoder().encode(BattleLane.right)
        #expect(try JSONDecoder().decode(BattleLane.self, from: laneData) == .right)
    }

    @Test func decodedActiveBattleSecondsAreClampedNonNegativeAndFinite() throws {
        let negativeSessionJSON = """
        {
          "cityKey": "1-1",
          "activeBattleSeconds": -12.5,
          "deployments": [],
          "appliedDamage": [],
          "losses": [],
          "idleDamageByType": [],
          "usedFavorableUnit": false,
          "usedExposedLane": false
        }
        """.data(using: .utf8)!
        let session = try JSONDecoder().decode(ActiveSiegeSession.self, from: negativeSessionJSON)
        #expect(session.activeBattleSeconds == 0)

        let nanResult = BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 1),
            conquestMode: .live,
            activeBattleSeconds: .nan,
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
        #expect(nanResult.activeBattleSeconds == 0)

        let encodedNegativeResult = """
        {
          "cityKey": "1-2",
          "conquestMode": "idle",
          "activeBattleSeconds": -3,
          "deployments": [],
          "appliedDamage": [],
          "losses": [],
          "idleDamageByType": [],
          "usedFavorableUnit": false,
          "usedExposedLane": false,
          "goldEarned": 8
        }
        """.data(using: .utf8)!
        let decodedResult = try JSONDecoder().decode(BattleResult.self, from: encodedNegativeResult)
        #expect(decodedResult.activeBattleSeconds == 0)
    }
}
