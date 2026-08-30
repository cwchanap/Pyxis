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

    @Test func idleReportUsesBuildingTileAndNoDuration() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, seconds: 90_061, mvp: nil, share: nil),
            title: "Falconridge Silenced"
        )
        #expect(content.tiles == [
            .buildings(count: 0),
            .sentLost(sent: 7, lost: 2)
        ])
        #expect(!content.tiles.contains { tile in
            if case .battleTime = tile { return true }
            return false
        })
    }

    @Test("Idle BUILDINGS tile uses occupied slots rather than damage type rows")
    func idleReportUsesCallerOwnedBuildingCount() {
        let cityState = CityBattleState(slots: [
            1: CityBuilding(type: .barracks),
            2: CityBuilding(type: .barracks)
        ])
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, mvp: nil, share: nil),
            title: "Falconridge Silenced",
            buildingCount: cityState.occupiedSlotCount
        )

        #expect(content.tiles == [
            .buildings(count: 2),
            .sentLost(sent: 7, lost: 2)
        ])
    }

    @Test func idleReportWithMVPKeepsMVPBeforeBuildingsAndSentLost() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle),
            title: "Falconridge Silenced"
        )
        #expect(content.tiles == [
            .mvp(soldierType: .archer, sharePercent: 63),
            .buildings(count: 0),
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
    city: Int = 3
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
        goldEarned: gold
    )
}
