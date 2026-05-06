//
//  KingdomGameState.swift
//  Pyxis
//

import Foundation

struct KingdomGameState: Codable, Equatable {
    static let maxIdleCatchUpSeconds = 8 * 60 * 60

    struct AttackResult: Equatable {
        let damageDealt: Int
        let conqueredCities: Int
        let goldEarned: Int
    }

    var gold: Int
    var cityLevel: Int
    var cityRemainingPower: Int
    var normalSoldierUpgradeLevel: Int
    var lastBackgroundedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case gold
        case cityLevel
        case cityRemainingPower
        case normalSoldierUpgradeLevel
        case lastBackgroundedAt
    }

    init(
        gold: Int = 0,
        cityLevel: Int = 1,
        cityRemainingPower: Int? = nil,
        normalSoldierUpgradeLevel: Int = 1,
        lastBackgroundedAt: Date? = nil
    ) {
        self.gold = max(0, gold)
        self.cityLevel = max(1, cityLevel)
        self.cityRemainingPower = max(1, cityRemainingPower ?? Self.cityMaxPower(for: max(1, cityLevel)))
        self.normalSoldierUpgradeLevel = max(1, normalSoldierUpgradeLevel)
        self.lastBackgroundedAt = lastBackgroundedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.init(
            gold: try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0,
            cityLevel: try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1,
            cityRemainingPower: try container.decodeIfPresent(Int.self, forKey: .cityRemainingPower),
            normalSoldierUpgradeLevel: try container.decodeIfPresent(Int.self, forKey: .normalSoldierUpgradeLevel) ?? 1,
            lastBackgroundedAt: try container.decodeIfPresent(Date.self, forKey: .lastBackgroundedAt)
        )
    }

    var cityMaxPower: Int {
        Self.cityMaxPower(for: cityLevel)
    }

    var currentGoldReward: Int {
        Self.goldReward(for: cityLevel)
    }

    var normalSoldierAttackPower: Int {
        Self.normalSoldierAttackPower(for: normalSoldierUpgradeLevel)
    }

    var normalSoldierUpgradeCost: Int {
        Self.normalSoldierUpgradeCost(for: normalSoldierUpgradeLevel)
    }

    @discardableResult
    mutating func spawnSoldierAttack() -> AttackResult {
        let damage = normalSoldierAttackPower
        cityRemainingPower -= damage

        guard cityRemainingPower <= 0 else {
            return AttackResult(damageDealt: damage, conqueredCities: 0, goldEarned: 0)
        }

        let reward = currentGoldReward
        gold += reward
        cityLevel += 1
        cityRemainingPower = cityMaxPower

        return AttackResult(damageDealt: damage, conqueredCities: 1, goldEarned: reward)
    }

    static func cityMaxPower(for level: Int) -> Int {
        roundedAtLeastOne(20 * pow(2.15, Double(clampedLevel(level) - 1)))
    }

    static func goldReward(for level: Int) -> Int {
        roundedAtLeastOne(8 * pow(1.45, Double(clampedLevel(level) - 1)))
    }

    static func normalSoldierAttackPower(for upgradeLevel: Int) -> Int {
        max(1, Int(ceil(pow(1.38, Double(clampedLevel(upgradeLevel) - 1)))))
    }

    static func normalSoldierUpgradeCost(for upgradeLevel: Int) -> Int {
        roundedAtLeastOne(10 * pow(1.7, Double(clampedLevel(upgradeLevel) - 1)))
    }

    private static func clampedLevel(_ level: Int) -> Int {
        max(1, level)
    }

    private static func roundedAtLeastOne(_ value: Double) -> Int {
        max(1, Int(value.rounded()))
    }
}
