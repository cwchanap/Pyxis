//
//  ConquestReportContent.swift
//  Pyxis
//

import Foundation

struct ConquestReportContent: Equatable {
    enum Achievement: Equatable { case favorableUnit, exposedLane }
    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        cityTitle: String,
        isCountryComplete: Bool
    ) -> Self {
        let title = isCountryComplete
            ? "Country \(result.cityKey.countryNumber) Conquered"
            : "\(cityTitle) Conquered"
        var lines = [
            "Gold earned: +\(CompactNumberFormatter.string(from: result.goldEarned))"
        ]
        switch result.conquestMode {
        case .live:
            lines.append("Battle time: \(durationText(result.activeBattleSeconds))")
        case .idle:
            lines.append("Conquered by your buildings")
        }
        if let type = result.mvpSoldierType,
           let percent = result.mvpDamageSharePercent {
            lines.append("MVP: \(type.displayName) · \(percent)%")
        }
        lines.append(
            "Deployed: \(CompactNumberFormatter.string(from: result.totalDeploymentCount))"
                + " · Lost: \(CompactNumberFormatter.string(from: result.totalLossCount))"
        )
        var achievements = [Achievement]()
        if result.usedFavorableUnit { achievements.append(.favorableUnit) }
        if result.usedExposedLane { achievements.append(.exposedLane) }
        return Self(title: title, summaryLines: lines, achievements: achievements)
    }

    private static func durationText(_ raw: TimeInterval) -> String {
        let total = Int(ActiveSiegeSession.normalizedActiveBattleSeconds(raw))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours == 0, minutes == 0 { return "\(seconds)s" }
        if hours == 0 {
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
        }
        var parts = ["\(hours)h"]
        if minutes > 0 || seconds > 0 {
            parts.append(String(format: "%02dm", minutes))
        }
        if seconds > 0 {
            parts.append(String(format: "%02ds", seconds))
        }
        return parts.joined(separator: " ")
    }
}
