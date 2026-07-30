//
//  BattleResultModels.swift
//  Pyxis
//

import Foundation

struct SiegeDeploymentCount: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var lane: BattleLane
    var count: Int
}

struct SiegeDamageAttribution: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var lane: BattleLane
    var damage: Int
}

struct SiegeLossCount: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var count: Int
}

struct SiegeIdleDamageByType: Codable, Equatable {
    var type: SoldierType
    var damage: Int
}

enum BattleConquestMode: String, Codable, Equatable {
    case live
    case idle
}

struct ActiveSiegeSession: Codable, Equatable {
    var cityKey: CityKey
    var activeBattleSeconds: TimeInterval
    var deployments: [SiegeDeploymentCount]
    var appliedDamage: [SiegeDamageAttribution]
    var losses: [SiegeLossCount]
    var idleDamageByType: [SiegeIdleDamageByType]
    var usedFavorableUnit: Bool
    var usedExposedLane: Bool

    private enum CodingKeys: String, CodingKey {
        case cityKey
        case activeBattleSeconds
        case deployments
        case appliedDamage
        case losses
        case idleDamageByType
        case usedFavorableUnit
        case usedExposedLane
    }

    init(cityKey: CityKey) {
        self.cityKey = cityKey
        self.activeBattleSeconds = 0
        self.deployments = []
        self.appliedDamage = []
        self.losses = []
        self.idleDamageByType = []
        self.usedFavorableUnit = false
        self.usedExposedLane = false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityKey = try container.decode(CityKey.self, forKey: .cityKey)
        activeBattleSeconds = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .activeBattleSeconds
        ) ?? 0
        deployments = try container.decodeIfPresent(
            [SiegeDeploymentCount].self,
            forKey: .deployments
        ) ?? []
        appliedDamage = try container.decodeIfPresent(
            [SiegeDamageAttribution].self,
            forKey: .appliedDamage
        ) ?? []
        losses = try container.decodeIfPresent([SiegeLossCount].self, forKey: .losses) ?? []
        idleDamageByType = try container.decodeIfPresent(
            [SiegeIdleDamageByType].self,
            forKey: .idleDamageByType
        ) ?? []
        usedFavorableUnit = try container.decodeIfPresent(
            Bool.self,
            forKey: .usedFavorableUnit
        ) ?? false
        usedExposedLane = try container.decodeIfPresent(
            Bool.self,
            forKey: .usedExposedLane
        ) ?? false
        normalizeRows()
    }

    func encode(to encoder: Encoder) throws {
        var normalized = self
        normalized.normalizeRows()

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(normalized.cityKey, forKey: .cityKey)
        try container.encode(normalized.activeBattleSeconds, forKey: .activeBattleSeconds)
        try container.encode(normalized.deployments, forKey: .deployments)
        try container.encode(normalized.appliedDamage, forKey: .appliedDamage)
        try container.encode(normalized.losses, forKey: .losses)
        try container.encode(normalized.idleDamageByType, forKey: .idleDamageByType)
        try container.encode(normalized.usedFavorableUnit, forKey: .usedFavorableUnit)
        try container.encode(normalized.usedExposedLane, forKey: .usedExposedLane)
    }

    mutating func recordDeployment(
        type: SoldierType,
        source: SoldierSpawnSource,
        lane: BattleLane,
        favorableTypes: [SoldierType],
        exposedLane: BattleLane
    ) {
        deployments.append(
            SiegeDeploymentCount(type: type, source: source, lane: lane, count: 1)
        )
        deployments = normalizedDeployments(deployments)
        usedFavorableUnit = usedFavorableUnit || favorableTypes.contains(type)
        usedExposedLane = usedExposedLane || lane == exposedLane
    }

    mutating func recordAttack(_ event: SoldierAttackEvent) {
        guard event.appliedCityDamage > 0 else {
            return
        }

        appliedDamage.append(
            SiegeDamageAttribution(
                type: event.type,
                source: event.source,
                lane: event.lane,
                damage: event.appliedCityDamage
            )
        )
        appliedDamage = normalizedDamageAttribution(appliedDamage)
    }

    mutating func recordLoss(_ event: SoldierLossEvent) {
        losses.append(SiegeLossCount(type: event.type, source: event.source, count: 1))
        losses = normalizedLosses(losses)
    }

    mutating func recordIdleDamage(type: SoldierType, appliedDamage: Int) {
        guard appliedDamage > 0 else {
            return
        }

        idleDamageByType.append(SiegeIdleDamageByType(type: type, damage: appliedDamage))
        idleDamageByType = normalizedIdleDamage(idleDamageByType)
    }

    mutating func advanceActiveBattleTime(_ delta: TimeInterval) {
        guard delta > 0 else {
            return
        }
        activeBattleSeconds += delta
    }

    func finalized(conquestMode: BattleConquestMode, goldEarned: Int) -> BattleResult {
        var damageByType: [SoldierType: Int] = [:]
        for row in appliedDamage {
            damageByType[row.type, default: 0] += row.damage
        }
        for row in idleDamageByType {
            damageByType[row.type, default: 0] += row.damage
        }

        let totalDamage = damageByType.values.reduce(0, +)
        var mvpType: SoldierType?
        var mvpDamage = 0
        for type in SoldierType.allCases {
            let damage = damageByType[type, default: 0]
            if damage > mvpDamage {
                mvpType = type
                mvpDamage = damage
            }
        }
        let mvpPercent = mvpType.map { _ in (mvpDamage * 100) / totalDamage }

        return BattleResult(
            cityKey: cityKey,
            conquestMode: conquestMode,
            activeBattleSeconds: activeBattleSeconds,
            deployments: deployments,
            appliedDamage: appliedDamage,
            losses: losses,
            idleDamageByType: idleDamageByType,
            mvpSoldierType: mvpType,
            mvpDamageSharePercent: mvpPercent,
            usedFavorableUnit: usedFavorableUnit,
            usedExposedLane: usedExposedLane,
            goldEarned: goldEarned
        )
    }

    private mutating func normalizeRows() {
        deployments = normalizedDeployments(deployments)
        appliedDamage = normalizedDamageAttribution(appliedDamage)
        losses = normalizedLosses(losses)
        idleDamageByType = normalizedIdleDamage(idleDamageByType)
    }
}

struct BattleResult: Codable, Equatable {
    var cityKey: CityKey
    var conquestMode: BattleConquestMode
    var activeBattleSeconds: TimeInterval
    var deployments: [SiegeDeploymentCount]
    var appliedDamage: [SiegeDamageAttribution]
    var losses: [SiegeLossCount]
    var idleDamageByType: [SiegeIdleDamageByType]
    var mvpSoldierType: SoldierType?
    var mvpDamageSharePercent: Int?
    var usedFavorableUnit: Bool
    var usedExposedLane: Bool
    var goldEarned: Int

    private enum CodingKeys: String, CodingKey {
        case cityKey
        case conquestMode
        case activeBattleSeconds
        case deployments
        case appliedDamage
        case losses
        case idleDamageByType
        case mvpSoldierType
        case mvpDamageSharePercent
        case usedFavorableUnit
        case usedExposedLane
        case goldEarned
    }

    init(
        cityKey: CityKey,
        conquestMode: BattleConquestMode,
        activeBattleSeconds: TimeInterval,
        deployments: [SiegeDeploymentCount],
        appliedDamage: [SiegeDamageAttribution],
        losses: [SiegeLossCount],
        idleDamageByType: [SiegeIdleDamageByType],
        mvpSoldierType: SoldierType?,
        mvpDamageSharePercent: Int?,
        usedFavorableUnit: Bool,
        usedExposedLane: Bool,
        goldEarned: Int
    ) {
        self.cityKey = cityKey
        self.conquestMode = conquestMode
        self.activeBattleSeconds = activeBattleSeconds
        self.deployments = normalizedDeployments(deployments)
        self.appliedDamage = normalizedDamageAttribution(appliedDamage)
        self.losses = normalizedLosses(losses)
        self.idleDamageByType = normalizedIdleDamage(idleDamageByType)
        self.mvpSoldierType = mvpSoldierType
        self.mvpDamageSharePercent = mvpDamageSharePercent
        self.usedFavorableUnit = usedFavorableUnit
        self.usedExposedLane = usedExposedLane
        self.goldEarned = goldEarned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            cityKey: try container.decode(CityKey.self, forKey: .cityKey),
            conquestMode: try container.decode(BattleConquestMode.self, forKey: .conquestMode),
            activeBattleSeconds: try container.decode(
                TimeInterval.self,
                forKey: .activeBattleSeconds
            ),
            deployments: try container.decode(
                [SiegeDeploymentCount].self,
                forKey: .deployments
            ),
            appliedDamage: try container.decode(
                [SiegeDamageAttribution].self,
                forKey: .appliedDamage
            ),
            losses: try container.decode([SiegeLossCount].self, forKey: .losses),
            idleDamageByType: try container.decode(
                [SiegeIdleDamageByType].self,
                forKey: .idleDamageByType
            ),
            mvpSoldierType: try container.decodeIfPresent(
                SoldierType.self,
                forKey: .mvpSoldierType
            ),
            mvpDamageSharePercent: try container.decodeIfPresent(
                Int.self,
                forKey: .mvpDamageSharePercent
            ),
            usedFavorableUnit: try container.decode(Bool.self, forKey: .usedFavorableUnit),
            usedExposedLane: try container.decode(Bool.self, forKey: .usedExposedLane),
            goldEarned: try container.decode(Int.self, forKey: .goldEarned)
        )
    }

    func encode(to encoder: Encoder) throws {
        let normalized = BattleResult(
            cityKey: cityKey,
            conquestMode: conquestMode,
            activeBattleSeconds: activeBattleSeconds,
            deployments: deployments,
            appliedDamage: appliedDamage,
            losses: losses,
            idleDamageByType: idleDamageByType,
            mvpSoldierType: mvpSoldierType,
            mvpDamageSharePercent: mvpDamageSharePercent,
            usedFavorableUnit: usedFavorableUnit,
            usedExposedLane: usedExposedLane,
            goldEarned: goldEarned
        )
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(normalized.cityKey, forKey: .cityKey)
        try container.encode(normalized.conquestMode, forKey: .conquestMode)
        try container.encode(normalized.activeBattleSeconds, forKey: .activeBattleSeconds)
        try container.encode(normalized.deployments, forKey: .deployments)
        try container.encode(normalized.appliedDamage, forKey: .appliedDamage)
        try container.encode(normalized.losses, forKey: .losses)
        try container.encode(normalized.idleDamageByType, forKey: .idleDamageByType)
        try container.encodeIfPresent(normalized.mvpSoldierType, forKey: .mvpSoldierType)
        try container.encodeIfPresent(
            normalized.mvpDamageSharePercent,
            forKey: .mvpDamageSharePercent
        )
        try container.encode(normalized.usedFavorableUnit, forKey: .usedFavorableUnit)
        try container.encode(normalized.usedExposedLane, forKey: .usedExposedLane)
        try container.encode(normalized.goldEarned, forKey: .goldEarned)
    }
}

private func normalizedDeployments(
    _ rows: [SiegeDeploymentCount]
) -> [SiegeDeploymentCount] {
    var result: [SiegeDeploymentCount] = []
    for row in rows where row.count > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source && $0.lane == row.lane
        }) {
            result[index].count += row.count
        } else {
            result.append(row)
        }
    }
    return result.sorted { lhs, rhs in
        rowSortKey(type: lhs.type, source: lhs.source, lane: lhs.lane)
            < rowSortKey(type: rhs.type, source: rhs.source, lane: rhs.lane)
    }
}

private func normalizedDamageAttribution(
    _ rows: [SiegeDamageAttribution]
) -> [SiegeDamageAttribution] {
    var result: [SiegeDamageAttribution] = []
    for row in rows where row.damage > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source && $0.lane == row.lane
        }) {
            result[index].damage += row.damage
        } else {
            result.append(row)
        }
    }
    return result.sorted { lhs, rhs in
        rowSortKey(type: lhs.type, source: lhs.source, lane: lhs.lane)
            < rowSortKey(type: rhs.type, source: rhs.source, lane: rhs.lane)
    }
}

private func normalizedLosses(_ rows: [SiegeLossCount]) -> [SiegeLossCount] {
    var result: [SiegeLossCount] = []
    for row in rows where row.count > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source
        }) {
            result[index].count += row.count
        } else {
            result.append(row)
        }
    }
    return result.sorted { lhs, rhs in
        rowSortKey(type: lhs.type, source: lhs.source)
            < rowSortKey(type: rhs.type, source: rhs.source)
    }
}

private func normalizedIdleDamage(
    _ rows: [SiegeIdleDamageByType]
) -> [SiegeIdleDamageByType] {
    var result: [SiegeIdleDamageByType] = []
    for row in rows where row.damage > 0 {
        if let index = result.firstIndex(where: { $0.type == row.type }) {
            result[index].damage += row.damage
        } else {
            result.append(row)
        }
    }
    return result.sorted {
        soldierTypeOrder($0.type) < soldierTypeOrder($1.type)
    }
}

private func rowSortKey(
    type: SoldierType,
    source: SoldierSpawnSource,
    lane: BattleLane? = nil
) -> (Int, String, Int) {
    (soldierTypeOrder(type), source.rawValue, lane?.rawValue ?? 0)
}

private func soldierTypeOrder(_ type: SoldierType) -> Int {
    SoldierType.allCases.firstIndex(of: type) ?? SoldierType.allCases.endIndex
}
