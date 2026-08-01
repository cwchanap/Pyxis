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

    /// Index of the "Gold earned" line within `summaryLines`. `project`
    /// always emits gold first, so this is 0; exposing it keeps the gold-burst
    /// anchor coupled to the gold line's semantic identity rather than to a
    /// positional assumption that would silently drift if the line order
    /// ever changed.
    static let goldLineIndex = 0

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
        let normalized = ActiveSiegeSession.normalizedActiveBattleSeconds(raw)
        // Int(normalized) traps when normalized exceeds Int's representable
        // range. `normalized` is already finite and non-negative, so the only
        // remaining overflow is a finite value above Int.max. Saturate it:
        // TimeInterval(Int.max) rounds up to 2^63 (the first Double outside
        // Int's range), so any value >= that threshold clamps to Int.max,
        // and every smaller Double converts safely. Formatting a saturated
        // value yields an enormous hour count, which is the intended display
        // for a corrupted/oversized persisted duration.
        let total = normalized >= TimeInterval(Int.max) ? Int.max : Int(normalized)
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
