//
//  ConquestReportContent.swift
//  Pyxis
//

import Foundation

struct ConquestReportContent: Equatable {
    enum Achievement: Equatable {
        case favorableUnit
        case exposedLane
    }

    enum StatTile: Equatable {
        case mvp(soldierType: SoldierType, sharePercent: Int)
        case battleTime(seconds: TimeInterval)
        case idleDamage(damage: Int?)
        case sentLost(sent: Int, lost: Int)

        var valueText: String {
            switch self {
            case let .mvp(_, sharePercent):
                return "\(max(0, min(100, sharePercent)))%"
            case let .battleTime(seconds):
                return Self.durationText(seconds)
            case let .idleDamage(damage):
                guard let damage else { return "—" }
                return CompactNumberFormatter.string(from: max(0, damage))
            case let .sentLost(sent, lost):
                let sentText = CompactNumberFormatter.string(from: max(0, sent))
                let lostText = CompactNumberFormatter.string(from: max(0, lost))
                return "\(sentText)/\(lostText)"
            }
        }

        var labelText: String {
            switch self {
            case .mvp:
                return "MVP"
            case .battleTime:
                return "SIEGE"
            case .idleDamage:
                return "IDLE DAMAGE"
            case .sentLost:
                return "SENT/LOST"
            }
        }

        var symbolName: String {
            switch self {
            case let .mvp(soldierType, _):
                switch soldierType {
                case .infantry: return "shield.fill"
                case .archer: return "figure.archery"
                case .cavalry: return "hare.fill"
                case .mage: return "wand.and.stars"
                case .siege: return "hammer.fill"
                }
            case .battleTime:
                return "timer"
            case .idleDamage:
                return "bolt.fill"
            case .sentLost:
                return "person.3.fill"
            }
        }

        private static func durationText(_ raw: TimeInterval) -> String {
            let normalized = ActiveSiegeSession.normalizedActiveBattleSeconds(raw)
            // TimeInterval(Int.max) rounds to 2^63, the first Double outside
            // Int's range. Saturate before converting so corrupted saves do
            // not trap while formatting their report.
            let total = normalized >= TimeInterval(Int.max) ? Int.max : Int(normalized)
            let minutes = total / 60
            let seconds = total % 60
            return "\(minutes):\(String(format: "%02d", seconds))"
        }
    }

    let title: String
    let rewardText: String
    let tiles: [StatTile]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        title: String
    ) -> Self {
        var tiles = [StatTile]()
        if let type = result.mvpSoldierType,
           let percent = result.mvpDamageSharePercent {
            tiles.append(.mvp(soldierType: type, sharePercent: percent))
        }

        switch result.conquestMode {
        case .live:
            let seconds = ActiveSiegeSession.normalizedActiveBattleSeconds(result.activeBattleSeconds)
            tiles.append(.battleTime(seconds: seconds))
        case .idle:
            tiles.append(.idleDamage(damage: result.totalIdleDamage))
        }

        tiles.append(.sentLost(
            sent: result.totalDeploymentCount,
            lost: result.totalLossCount
        ))

        var achievements = [Achievement]()
        if result.usedFavorableUnit { achievements.append(.favorableUnit) }
        if result.usedExposedLane { achievements.append(.exposedLane) }

        return Self(
            title: title,
            rewardText: "+\(CompactNumberFormatter.string(from: result.goldEarned))",
            tiles: tiles,
            achievements: achievements
        )
    }
}
