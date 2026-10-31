//
//  TreasuryUpgrade.swift
//  Pyxis
//

import Foundation

/// The three persistent Kingdom upgrades (HPA-670). This file is the single
/// authoritative place for each track's base cost, max level, display and
/// effect names, and the placeholder asset name — deliberately kept out of
/// the already-large `KingdomGameState.swift`. There is no perk/modifier
/// system: each effect gets exactly one calculation seam (Task 2).
enum TreasuryUpgrade: String, Codable, CaseIterable, Equatable {
    case warChest
    case drillYard
    case quartermaster

    static let priceExponent = 1.8

    var displayName: String {
        switch self {
        case .warChest:
            return "War Chest"
        case .drillYard:
            return "Drill Yard"
        case .quartermaster:
            return "Quartermaster"
        }
    }

    /// Per-level effect wording, pinned to the spec's effect-at-level-L table.
    var effectName: String {
        switch self {
        case .warChest:
            return "Conquest gold +10% per level"
        case .drillYard:
            return "Soldier attack +5% per level"
        case .quartermaster:
            return "Building costs -4% per level"
        }
    }

    var baseCost: Int {
        switch self {
        case .warChest:
            return 40
        case .drillYard:
            return 50
        case .quartermaster:
            return 45
        }
    }

    var maxLevel: Int {
        switch self {
        case .warChest:
            return 10
        case .drillYard:
            return 10
        case .quartermaster:
            return 8
        }
    }

    /// Asset the Kingdom tab attempts first; a missing image falls back to
    /// one shared vector placeholder glyph (HPA-673 owns final imagery).
    var assetName: String {
        switch self {
        case .warChest:
            return "treasury-war-chest"
        case .drillYard:
            return "treasury-drill-yard"
        case .quartermaster:
            return "treasury-quartermaster"
        }
    }

    /// Price of the next level from current level L:
    /// `max(1, round(baseCost × 1.8^L))`, clamped to a positive integer.
    func price(forCurrentLevel level: Int) -> Int {
        let current = min(max(0, level), maxLevel)
        return max(1, Int((Double(baseCost) * pow(Self.priceExponent, Double(current))).rounded()))
    }
}

/// Per-upgrade levels for the three Treasury tracks, persisted under the
/// single top-level `treasury` key of `KingdomGameState`. The initializer
/// clamps every level to `0...maxLevel`; decode falls back to zero for a
/// missing or malformed value — no schema versioning, no migration layer.
struct TreasuryState: Codable, Equatable {
    var warChest: Int
    var drillYard: Int
    var quartermaster: Int

    init(warChest: Int = 0, drillYard: Int = 0, quartermaster: Int = 0) {
        self.warChest = Self.clamp(warChest, for: .warChest)
        self.drillYard = Self.clamp(drillYard, for: .drillYard)
        self.quartermaster = Self.clamp(quartermaster, for: .quartermaster)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            warChest: (try? container.decodeIfPresent(Int.self, forKey: .warChest)) ?? 0,
            drillYard: (try? container.decodeIfPresent(Int.self, forKey: .drillYard)) ?? 0,
            quartermaster: (try? container.decodeIfPresent(Int.self, forKey: .quartermaster)) ?? 0
        )
    }

    func level(for upgrade: TreasuryUpgrade) -> Int {
        switch upgrade {
        case .warChest:
            return warChest
        case .drillYard:
            return drillYard
        case .quartermaster:
            return quartermaster
        }
    }

    mutating func setLevel(_ level: Int, for upgrade: TreasuryUpgrade) {
        switch upgrade {
        case .warChest:
            warChest = Self.clamp(level, for: .warChest)
        case .drillYard:
            drillYard = Self.clamp(level, for: .drillYard)
        case .quartermaster:
            quartermaster = Self.clamp(level, for: .quartermaster)
        }
    }

    private static func clamp(_ level: Int, for upgrade: TreasuryUpgrade) -> Int {
        min(max(0, level), upgrade.maxLevel)
    }

    private enum CodingKeys: String, CodingKey {
        case warChest
        case drillYard
        case quartermaster
    }
}

/// Result of `KingdomGameState.purchaseTreasuryUpgrade(_:)` — the only
/// Treasury purchase mutation. Max level is checked before affordability;
/// a rejection never spends gold or changes a level.
enum TreasuryPurchaseResult: Equatable {
    case purchased(cost: Int, newLevel: Int, remainingGold: Int)
    case insufficientGold
    case maxLevel
}
