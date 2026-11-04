//
//  ConquestReportContentTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

private struct AchievementCombination {
    let favorable: Bool
    let exposed: Bool
    let expected: [ConquestReportContent.Achievement]
}

struct ConquestReportContentTests {
    @Test func liveReportUsesTypedTilesInStableOrder() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .live, seconds: 65),
            title: "Falconridge Silenced"
        )
        #expect(content.title == "Falconridge Silenced")
        #expect(content.rewardText == "+1.5K")
        #expect(content.tiles == [
            .mvp(soldierType: .archer, sharePercent: 63),
            .battleTime(seconds: 65),
            .sentLost(sent: 7, lost: 2)
        ])
        #expect(content.achievements == [.favorableUnit, .exposedLane])
    }

    @Test func idleReportUsesDamageTileAndNoDuration() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, seconds: 90_061, mvp: nil, share: nil),
            title: "Falconridge Silenced"
        )
        #expect(content.tiles == [
            .idleDamage(damage: nil),
            .sentLost(sent: 7, lost: 2)
        ])
        #expect(!content.tiles.contains { tile in
            if case .battleTime = tile { return true }
            return false
        })
    }

    @Test("Idle damage tile uses durable damage rows rather than presentation-only fields")
    func idleReportUsesDurableDamageRows() throws {
        let resultJSON = Data("""
        {
          "cityKey": "1-3",
          "conquestMode": "idle",
          "activeBattleSeconds": 0,
          "deployments": [],
          "appliedDamage": [],
          "losses": [],
          "idleDamageByType": [
            {"type": "infantry", "damage": 2}
          ],
          "idleBuildingCount": 2,
          "mvpSoldierType": "infantry",
          "mvpDamageSharePercent": 100,
          "usedFavorableUnit": false,
          "usedExposedLane": false,
          "goldEarned": 17
        }
        """.utf8)
        let result = try JSONDecoder().decode(BattleResult.self, from: resultJSON)
        let content = ConquestReportContent.project(
            from: result,
            title: "Falconridge Silenced"
        )

        #expect(content.tiles == [
            .mvp(soldierType: .infantry, sharePercent: 100),
            .idleDamage(damage: 2),
            .sentLost(sent: 0, lost: 0)
        ])
    }

    @Test func idleReportWithMVPKeepsMVPBeforeDamageAndSentLost() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle),
            title: "Falconridge Silenced"
        )
        #expect(content.tiles == [
            .mvp(soldierType: .archer, sharePercent: 63),
            .idleDamage(damage: nil),
            .sentLost(sent: 7, lost: 2)
        ])
    }

    @Test func missingOrPartialMVPIsOmittedWithoutFiller() {
        for pair in [(SoldierType?.none, Int?.none), (.archer, nil), (nil, 63)] {
            let content = ConquestReportContent.project(
                from: makeResult(mvp: pair.0, share: pair.1),
                title: "Falconridge Silenced"
            )
            #expect(content.tiles.count == 2)
            #expect(!content.tiles.contains { tile in
                if case .mvp = tile { return true }
                return false
            })
        }
    }

    @Test func zeroCountsAndAchievementCombinationsAreStable() {
        let combinations = [
            AchievementCombination(favorable: false, exposed: false, expected: []),
            AchievementCombination(favorable: true, exposed: false, expected: [.favorableUnit]),
            AchievementCombination(favorable: false, exposed: true, expected: [.exposedLane]),
            AchievementCombination(favorable: true, exposed: true, expected: [.favorableUnit, .exposedLane])
        ]
        for combination in combinations {
            let content = ConquestReportContent.project(
                from: makeResult(
                    deployments: 0,
                    losses: 0,
                    favorable: combination.favorable,
                    exposed: combination.exposed
                ),
                title: "Falconridge Silenced"
            )
            #expect(content.tiles.last == .sentLost(sent: 0, lost: 0))
            #expect(content.achievements == combination.expected)
        }
    }

    @Test func callerOwnedTitleIsUsedVerbatim() {
        let content = ConquestReportContent.project(
            from: makeResult(city: 15),
            title: "Crownspire Keep Falls"
        )
        #expect(content.title == "Crownspire Keep Falls")
    }

    @Test func newGearReceiptProjectsToAuthoredCatalogName() {
        let content = ConquestReportContent.project(
            from: makeResult(newGear: "c01-infantry-attack"),
            title: "Willowford Secured"
        )
        #expect(content.newGearLineText == "New gear: Willowford Blade · Lv 1")
    }

    @Test func city15ReceiptProjectsFinaleItemName() {
        let content = ConquestReportContent.project(
            from: makeResult(city: 15, newGear: "c15-siege-keep"),
            title: "Crownspire Keep Falls"
        )
        #expect(content.newGearLineText == "New gear: Crownspire Breaker · Lv 1")
    }

    @Test("Repeat-conquest receipts use the upgrade wording at Lv 2 and Lv 3")
    func upgradeReceiptsProjectLevelAwareUpgradeLines() {
        let lv2 = ConquestReportContent.project(
            from: makeResult(city: 5, newGear: "c05-cavalry-attack", gearLevel: 2),
            title: "Highcrest Taken"
        )
        #expect(lv2.newGearLineText == "Gear upgraded: Highcrest Lance · Lv 2")

        let lv3 = ConquestReportContent.project(
            from: makeResult(city: 13, newGear: "c13-siege-toughness", gearLevel: 3),
            title: "Starveil Taken"
        )
        #expect(lv3.newGearLineText == "Gear upgraded: Starveil Plating · Lv 3")
    }

    @Test("Receipts with out-of-band levels produce no line")
    func invalidReceiptLevelsProduceNoLine() {
        // The grant seam only ever writes levels 1–3 (a capped Lv3 repeat
        // writes no receipt at all); anything else is malformed save data.
        for level in [0, 4] {
            let content = ConquestReportContent.project(
                from: makeResult(newGear: "c01-infantry-attack", gearLevel: level),
                title: "Willowford Secured"
            )
            #expect(content.newGearLineText == nil)
        }
    }

    @Test("A saved Lv 2 receipt restores to the identical upgrade line")
    func restoredUpgradeReceiptRendersTheSameLine() throws {
        let resultJSON = Data("""
        {
          "cityKey": "1-5",
          "conquestMode": "live",
          "activeBattleSeconds": 65,
          "deployments": [],
          "appliedDamage": [],
          "losses": [],
          "idleDamageByType": [],
          "usedFavorableUnit": false,
          "usedExposedLane": false,
          "goldEarned": 8,
          "equipmentReward": {"itemID": "c05-cavalry-attack", "level": 2}
        }
        """.utf8)
        let restored = try JSONDecoder().decode(BattleResult.self, from: resultJSON)
        let restoredLine = ConquestReportContent.project(
            from: restored,
            title: "Highcrest Taken"
        ).newGearLineText
        let freshLine = ConquestReportContent.project(
            from: makeResult(city: 5, newGear: "c05-cavalry-attack", gearLevel: 2),
            title: "Highcrest Taken"
        ).newGearLineText
        #expect(restoredLine == "Gear upgraded: Highcrest Lance · Lv 2")
        #expect(restoredLine == freshLine)
    }

    @Test func unknownGearReceiptProducesNoLine() {
        let content = ConquestReportContent.project(
            from: makeResult(newGear: "c99-unauthored-item"),
            title: "Falconridge Silenced"
        )
        #expect(content.newGearLineText == nil)
    }

    @Test func missingGearReceiptProducesNoLine() {
        let content = ConquestReportContent.project(
            from: makeResult(),
            title: "Falconridge Silenced"
        )
        #expect(content.newGearLineText == nil)
    }

    @Test(arguments: [
        (0.0, "0:00"), (59.9, "0:59"), (60.0, "1:00"),
        (65.0, "1:05"), (3_599.0, "59:59"),
        (3_600.0, "60:00"), (3_612.0, "60:12"),
        (90_000.0, "1500:00"), (90_061.0, "1501:01")
    ])
    func durationGoldenStrings(seconds: TimeInterval, expected: String) {
        let content = ConquestReportContent.project(
            from: makeResult(seconds: seconds),
            title: "Falconridge Silenced"
        )
        #expect(content.tiles[1] == .battleTime(seconds: seconds))
        #expect(content.tiles[1].valueText == expected)
    }

    @Test func invalidDurationsNormalizeToZero() {
        for seconds in [-1.0, .infinity, .nan] {
            let content = ConquestReportContent.project(
                from: makeResult(seconds: seconds),
                title: "Falconridge Silenced"
            )
            #expect(content.tiles[1] == .battleTime(seconds: 0))
            #expect(content.tiles[1].valueText == "0:00")
        }
    }

    @Test func durationsAboveIntRangeSaturateInsteadOfTrapping() {
        let oversized: [TimeInterval] = [TimeInterval(Int.max), TimeInterval(Int.max) * 2, 1e308]
        var produced: [String] = []
        for seconds in oversized {
            let content = ConquestReportContent.project(
                from: makeResult(seconds: seconds),
                title: "Falconridge Silenced"
            )
            #expect(content.tiles[1].valueText.contains(":"))
            produced.append(content.tiles[1].valueText)
        }
        #expect(produced.allSatisfy { $0 == produced[0] })
    }
}

private func makeResult(
    mode: BattleConquestMode = .live,
    seconds: TimeInterval = 65,
    gold: Int = 1500,
    mvp: SoldierType? = .archer,
    share: Int? = 63,
    deployments: Int = 7,
    losses: Int = 2,
    favorable: Bool = true,
    exposed: Bool = true,
    city: Int = 3,
    newGear: String? = nil,
    gearLevel: Int = 1
) -> BattleResult {
    BattleResult(
        cityKey: CityKey(countryNumber: 1, cityNumber: city),
        conquestMode: mode,
        activeBattleSeconds: seconds,
        deployments: deployments > 0
            ? [SiegeDeploymentCount(type: .archer, source: .manual, lane: .left, count: deployments)]
            : [],
        appliedDamage: [],
        losses: losses > 0
            ? [SiegeLossCount(type: .archer, source: .manual, count: losses)]
            : [],
        idleDamageByType: [],
        mvpSoldierType: mvp,
        mvpDamageSharePercent: share,
        usedFavorableUnit: favorable,
        usedExposedLane: exposed,
        goldEarned: gold,
        equipmentReward: newGear.map { EquipmentReward(itemID: $0, level: gearLevel) }
    )
}
