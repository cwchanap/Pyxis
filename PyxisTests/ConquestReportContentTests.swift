//
//  ConquestReportContentTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct ConquestReportContentTests {
    @Test func liveReportUsesPersistedResultFields() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .live, seconds: 65),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.title == "Country 1 - City 3 Conquered")
        #expect(content.summaryLines == [
            "Gold earned: +1.5K",
            "Battle time: 1m 5s",
            "MVP: Archer · 63%",
            "Deployed: 7 · Lost: 2"
        ])
        #expect(content.achievements == [.favorableUnit, .exposedLane])
    }

    @Test func idleReportUsesBuildingCopyAndNoDuration() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, seconds: 90_061),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.summaryLines[1] == "Conquered by your buildings")
        #expect(!content.summaryLines.contains { $0.contains("Battle time") })
    }

    @Test func missingOrPartialMVPIsOmitted() {
        for pair in [(SoldierType?.none, Int?.none), (.archer, nil), (nil, 63)] {
            let content = ConquestReportContent.project(
                from: makeResult(mvp: pair.0, share: pair.1),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines.count == 3)
            #expect(!content.summaryLines.contains { $0.hasPrefix("MVP:") })
        }
    }

    @Test func zeroCountsAndAchievementCombinationsAreStable() {
        let combinations: [(Bool, Bool, [ConquestReportContent.Achievement])] = [
            (false, false, []),
            (true, false, [.favorableUnit]),
            (false, true, [.exposedLane]),
            (true, true, [.favorableUnit, .exposedLane])
        ]
        for combination in combinations {
            let content = ConquestReportContent.project(
                from: makeResult(
                    deployments: 0,
                    losses: 0,
                    favorable: combination.0,
                    exposed: combination.1
                ),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines.last == "Deployed: 0 · Lost: 0")
            #expect(content.achievements == combination.2)
        }
    }

    @Test func countryCompleteIgnoresCityTitle() {
        let content = ConquestReportContent.project(
            from: makeResult(city: 15),
            cityTitle: "Ignored",
            isCountryComplete: true
        )
        #expect(content.title == "Country 1 Conquered")
    }

    @Test(arguments: [
        (0.0, "0s"), (59.9, "59s"), (60.0, "1m"),
        (65.0, "1m 5s"), (3_599.0, "59m 59s"),
        (3_600.0, "1h"), (3_612.0, "1h 00m 12s"),
        (3_660.0, "1h 01m"), (3_672.0, "1h 01m 12s"),
        (90_000.0, "25h"), (90_061.0, "25h 01m 01s")
    ])
    func durationGoldenStrings(seconds: TimeInterval, expected: String) {
        let content = ConquestReportContent.project(
            from: makeResult(seconds: seconds),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.summaryLines[1] == "Battle time: \(expected)")
    }

    @Test func invalidDurationsNormalizeToZero() {
        for seconds in [-1.0, .infinity, .nan] {
            let content = ConquestReportContent.project(
                from: makeResult(seconds: seconds),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines[1] == "Battle time: 0s")
        }
    }

    @Test func durationsAboveIntRangeSaturateInsteadOfTrapping() {
        // A finite Double above Int's representable range must not trap the
        // Int(_:) conversion; it saturates to Int.max and formats as hours.
        let oversized: [TimeInterval] = [TimeInterval(Int.max), TimeInterval(Int.max) * 2, 1e308]
        var produced: [String] = []
        for seconds in oversized {
            let content = ConquestReportContent.project(
                from: makeResult(seconds: seconds),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines[1].hasPrefix("Battle time: "))
            #expect(content.summaryLines[1].contains("h"))
            produced.append(content.summaryLines[1])
        }
        // All oversized values saturate to the same Int.max-derived string.
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
