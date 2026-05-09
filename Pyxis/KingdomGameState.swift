//
//  KingdomGameState.swift
//  Pyxis
//

import Foundation

struct KingdomGameState: Codable, Equatable {
    static let maxIdleCatchUpSeconds = 8 * 60 * 60
    static let firstCountryCityCount = 15

    enum StageStatus: String, Codable, Equatable {
        case battleActive
        case cityConqueredPendingMap
        case countryComplete
    }

    enum MapCityStatus: Equatable {
        case completed
        case unlocked
        case locked
    }

    enum CityEntryResult: Equatable {
        case entered(country: Int, city: Int)
        case locked
        case alreadyCompleted
        case countryComplete
    }

    struct AttackResult: Equatable {
        let attackApplied: Bool
        let damageDealt: Int
        let conqueredCities: Int
        let goldEarned: Int

        static let blocked = AttackResult(
            attackApplied: false,
            damageDealt: 0,
            conqueredCities: 0,
            goldEarned: 0
        )
    }

    struct IdleProgressResult: Equatable {
        let elapsedSeconds: Int
        let damageDealt: Int
        let conqueredCities: Int
        let goldEarned: Int

        static let none = IdleProgressResult(
            elapsedSeconds: 0,
            damageDealt: 0,
            conqueredCities: 0,
            goldEarned: 0
        )
    }

    enum UpgradeResult: Equatable {
        case upgraded(cost: Int, newAttackPower: Int)
        case insufficientGold(cost: Int, currentGold: Int)
        case unavailable
    }

    var gold: Int
    var cityLevel: Int
    var cityRemainingPower: Int
    var normalSoldierUpgradeLevel: Int
    var lastBackgroundedAt: Date?
    var countryNumber: Int
    var cityNumberInCountry: Int
    var completedCityCount: Int
    var stageStatus: StageStatus

    private enum CodingKeys: String, CodingKey {
        case gold
        case cityLevel
        case cityRemainingPower
        case normalSoldierUpgradeLevel
        case lastBackgroundedAt
        case countryNumber
        case cityNumberInCountry
        case completedCityCount
        case stageStatus
    }

    init(
        gold: Int = 0,
        cityLevel: Int = 1,
        cityRemainingPower: Int? = nil,
        normalSoldierUpgradeLevel: Int = 1,
        lastBackgroundedAt: Date? = nil,
        countryNumber: Int = 1,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        stageStatus: StageStatus = .battleActive
    ) {
        let clampedCountryNumber = max(1, countryNumber)
        let clampedCompletedCityCount = min(max(0, completedCityCount), Self.firstCountryCityCount)
        let clampedCityNumber = min(max(1, cityNumberInCountry), Self.firstCountryCityCount)
        let clampedCityLevel = max(1, cityLevel)
        var resolvedStatus: StageStatus
        var normalizedCompletedCityCount = clampedCompletedCityCount
        var normalizedCityNumber = clampedCityNumber
        var normalizedCityLevel = clampedCityLevel

        if clampedCompletedCityCount >= Self.firstCountryCityCount || stageStatus == .countryComplete {
            resolvedStatus = .countryComplete
        } else if stageStatus == .cityConqueredPendingMap {
            resolvedStatus = .cityConqueredPendingMap
        } else {
            resolvedStatus = .battleActive
        }

        switch resolvedStatus {
        case .battleActive:
            normalizedCityNumber = min(normalizedCompletedCityCount + 1, Self.firstCountryCityCount)
            normalizedCityLevel = normalizedCityNumber
        case .cityConqueredPendingMap:
            normalizedCompletedCityCount = min(
                Self.firstCountryCityCount,
                max(normalizedCompletedCityCount, normalizedCityNumber)
            )
            if normalizedCompletedCityCount >= Self.firstCountryCityCount {
                resolvedStatus = .countryComplete
                normalizedCityNumber = Self.firstCountryCityCount
                normalizedCityLevel = Self.firstCountryCityCount
            } else {
                normalizedCityLevel = normalizedCityNumber
            }
        case .countryComplete:
            normalizedCompletedCityCount = Self.firstCountryCityCount
            normalizedCityNumber = Self.firstCountryCityCount
            normalizedCityLevel = Self.firstCountryCityCount
        }

        self.gold = max(0, gold)
        self.cityLevel = normalizedCityLevel
        self.normalSoldierUpgradeLevel = max(1, normalSoldierUpgradeLevel)
        self.lastBackgroundedAt = lastBackgroundedAt
        self.countryNumber = clampedCountryNumber
        self.cityNumberInCountry = normalizedCityNumber
        self.completedCityCount = normalizedCompletedCityCount
        self.stageStatus = resolvedStatus

        if resolvedStatus == .battleActive {
            self.cityRemainingPower = max(1, cityRemainingPower ?? Self.cityMaxPower(for: normalizedCityLevel))
        } else {
            self.cityRemainingPower = max(0, cityRemainingPower ?? 0)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStageStatus: StageStatus

        if let rawStageStatus = try? container.decodeIfPresent(String.self, forKey: .stageStatus) {
            decodedStageStatus = StageStatus(rawValue: rawStageStatus) ?? .battleActive
        } else {
            decodedStageStatus = .battleActive
        }

        self.init(
            gold: try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0,
            cityLevel: try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1,
            cityRemainingPower: try container.decodeIfPresent(Int.self, forKey: .cityRemainingPower),
            normalSoldierUpgradeLevel: try container.decodeIfPresent(Int.self, forKey: .normalSoldierUpgradeLevel) ?? 1,
            lastBackgroundedAt: try container.decodeIfPresent(Date.self, forKey: .lastBackgroundedAt),
            countryNumber: try container.decodeIfPresent(Int.self, forKey: .countryNumber) ?? 1,
            cityNumberInCountry: try container.decodeIfPresent(Int.self, forKey: .cityNumberInCountry)
                ?? min(max(1, try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1), Self.firstCountryCityCount),
            completedCityCount: try container.decodeIfPresent(Int.self, forKey: .completedCityCount)
                ?? min(max(0, (try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1) - 1), Self.firstCountryCityCount),
            stageStatus: decodedStageStatus
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

    var displayCityTitle: String {
        "Country \(countryNumber) - City \(cityNumberInCountry)"
    }

    var hasNextCityInCountry: Bool {
        completedCityCount < Self.firstCountryCityCount
    }

    func mapStatus(for cityNumber: Int) -> MapCityStatus {
        guard (1...Self.firstCountryCityCount).contains(cityNumber) else {
            return .locked
        }

        if cityNumber <= completedCityCount {
            return .completed
        }

        if stageStatus != .countryComplete && cityNumber == completedCityCount + 1 {
            return .unlocked
        }

        return .locked
    }

    @discardableResult
    mutating func startCityFromMap(_ cityNumber: Int) -> CityEntryResult {
        guard stageStatus != .countryComplete else {
            return .countryComplete
        }

        guard (1...Self.firstCountryCityCount).contains(cityNumber) else {
            return .locked
        }

        if stageStatus == .battleActive && cityNumber == cityNumberInCountry {
            return .entered(country: countryNumber, city: cityNumberInCountry)
        }

        if cityNumber <= completedCityCount {
            return .alreadyCompleted
        }

        guard cityNumber == completedCityCount + 1 else {
            return .locked
        }

        cityNumberInCountry = cityNumber
        cityLevel = completedCityCount + 1
        cityRemainingPower = cityMaxPower
        stageStatus = .battleActive
        lastBackgroundedAt = nil

        return .entered(country: countryNumber, city: cityNumberInCountry)
    }

    @discardableResult
    mutating func spawnSoldierAttack() -> AttackResult {
        guard stageStatus == .battleActive else {
            return .blocked
        }

        let damage = normalSoldierAttackPower
        cityRemainingPower -= damage

        guard cityRemainingPower <= 0 else {
            return AttackResult(attackApplied: true, damageDealt: damage, conqueredCities: 0, goldEarned: 0)
        }

        let reward = currentGoldReward
        gold += reward
        cityRemainingPower = 0
        completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

        if completedCityCount >= Self.firstCountryCityCount {
            stageStatus = .countryComplete
        } else {
            stageStatus = .cityConqueredPendingMap
        }

        return AttackResult(attackApplied: true, damageDealt: damage, conqueredCities: 1, goldEarned: reward)
    }

    mutating func enterBackground(at date: Date) {
        lastBackgroundedAt = date
    }

    @discardableResult
    mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
        guard let lastBackgroundedAt else {
            return .none
        }

        self.lastBackgroundedAt = nil

        guard stageStatus == .battleActive else {
            return .none
        }

        let rawElapsed = Int(date.timeIntervalSince(lastBackgroundedAt))
        let elapsedSeconds = min(max(0, rawElapsed), Self.maxIdleCatchUpSeconds)

        guard elapsedSeconds > 0 else {
            return .none
        }

        let totalPotentialDamage = elapsedSeconds * normalSoldierAttackPower
        let appliedDamage = min(totalPotentialDamage, cityRemainingPower)

        guard totalPotentialDamage >= cityRemainingPower else {
            cityRemainingPower -= totalPotentialDamage
            return IdleProgressResult(
                elapsedSeconds: elapsedSeconds,
                damageDealt: totalPotentialDamage,
                conqueredCities: 0,
                goldEarned: 0
            )
        }

        let reward = currentGoldReward
        gold += reward
        cityRemainingPower = 0
        completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

        if completedCityCount >= Self.firstCountryCityCount {
            stageStatus = .countryComplete
        } else {
            stageStatus = .cityConqueredPendingMap
        }

        return IdleProgressResult(
            elapsedSeconds: elapsedSeconds,
            damageDealt: appliedDamage,
            conqueredCities: 1,
            goldEarned: reward
        )
    }

    @discardableResult
    mutating func upgradeNormalSoldier() -> UpgradeResult {
        guard stageStatus == .battleActive else {
            return .unavailable
        }

        let cost = normalSoldierUpgradeCost

        guard gold >= cost else {
            return .insufficientGold(cost: cost, currentGold: gold)
        }

        gold -= cost
        normalSoldierUpgradeLevel += 1

        return .upgraded(cost: cost, newAttackPower: normalSoldierAttackPower)
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
