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
        activeBattleSeconds = Self.normalizedActiveBattleSeconds(
            try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .activeBattleSeconds
            ) ?? 0
        )
        let decodedDeployments = try container.decodeIfPresent(
            [SiegeDeploymentCount].self,
            forKey: .deployments
        ) ?? []
        let decodedAppliedDamage = try container.decodeIfPresent(
            [SiegeDamageAttribution].self,
            forKey: .appliedDamage
        ) ?? []
        let decodedLosses = try container.decodeIfPresent(
            [SiegeLossCount].self,
            forKey: .losses
        ) ?? []
        let decodedIdleDamage = try container.decodeIfPresent(
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

        do {
            deployments = try normalizedDeployments(decodedDeployments, overflow: .throwError)
            appliedDamage = try normalizedDamageAttribution(decodedAppliedDamage, overflow: .throwError)
            losses = try normalizedLosses(decodedLosses, overflow: .throwError)
            idleDamageByType = try normalizedIdleDamage(decodedIdleDamage, overflow: .throwError)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Siege session row aggregation overflowed",
                    underlyingError: error
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var normalized = self
        normalized.normalizeRowsSaturating()

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
        deployments = saturatingNormalizedDeployments(deployments)
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
        appliedDamage = saturatingNormalizedDamageAttribution(appliedDamage)
    }

    mutating func recordLoss(_ event: SoldierLossEvent) {
        losses.append(SiegeLossCount(type: event.type, source: event.source, count: 1))
        losses = saturatingNormalizedLosses(losses)
    }

    mutating func recordIdleDamage(type: SoldierType, appliedDamage: Int) {
        guard appliedDamage > 0 else {
            return
        }

        idleDamageByType.append(SiegeIdleDamageByType(type: type, damage: appliedDamage))
        idleDamageByType = saturatingNormalizedIdleDamage(idleDamageByType)
    }

    mutating func advanceActiveBattleTime(_ delta: TimeInterval) {
        guard delta > 0 else {
            return
        }
        activeBattleSeconds = Self.normalizedActiveBattleSeconds(activeBattleSeconds + delta)
    }

    static func normalizedActiveBattleSeconds(_ value: TimeInterval) -> TimeInterval {
        value.isFinite ? max(0, value) : 0
    }

    func finalized(
        conquestMode: BattleConquestMode,
        goldEarned: Int
    ) -> BattleResult {
        // Use Decimal so many distinct Int.max rows for the same type (different
        // source/lane) keep exact relative magnitude for MVP ranking and share.
        var damageByType: [SoldierType: Decimal] = [:]
        for row in appliedDamage {
            damageByType[row.type, default: 0] += Decimal(row.damage)
        }
        for row in idleDamageByType {
            damageByType[row.type, default: 0] += Decimal(row.damage)
        }

        let totalDamage = damageByType.values.reduce(Decimal(0), +)
        var mvpType: SoldierType?
        var mvpDamage = Decimal(0)
        for type in SoldierType.allCases {
            let damage = damageByType[type, default: 0]
            if damage > mvpDamage {
                mvpType = type
                mvpDamage = damage
            }
        }
        let mvpPercent = mvpDamageSharePercent(mvpDamage: mvpDamage, totalDamage: totalDamage)

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

    /// Live/encode path: saturates on overflow. Decode uses throwing aggregation instead.
    private mutating func normalizeRowsSaturating() {
        deployments = saturatingNormalizedDeployments(deployments)
        appliedDamage = saturatingNormalizedDamageAttribution(appliedDamage)
        losses = saturatingNormalizedLosses(losses)
        idleDamageByType = saturatingNormalizedIdleDamage(idleDamageByType)
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
        self.activeBattleSeconds = ActiveSiegeSession.normalizedActiveBattleSeconds(activeBattleSeconds)
        self.deployments = saturatingNormalizedDeployments(deployments)
        self.appliedDamage = saturatingNormalizedDamageAttribution(appliedDamage)
        self.losses = saturatingNormalizedLosses(losses)
        self.idleDamageByType = saturatingNormalizedIdleDamage(idleDamageByType)
        self.mvpSoldierType = mvpSoldierType
        self.mvpDamageSharePercent = mvpDamageSharePercent
        self.usedFavorableUnit = usedFavorableUnit
        self.usedExposedLane = usedExposedLane
        self.goldEarned = goldEarned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedDeployments = try container.decode([SiegeDeploymentCount].self, forKey: .deployments)
        let decodedAppliedDamage = try container.decode(
            [SiegeDamageAttribution].self,
            forKey: .appliedDamage
        )
        let decodedLosses = try container.decode([SiegeLossCount].self, forKey: .losses)
        let decodedIdleDamage = try container.decode(
            [SiegeIdleDamageByType].self,
            forKey: .idleDamageByType
        )

        let mergedDeployments: [SiegeDeploymentCount]
        let mergedAppliedDamage: [SiegeDamageAttribution]
        let mergedLosses: [SiegeLossCount]
        let mergedIdleDamage: [SiegeIdleDamageByType]
        do {
            mergedDeployments = try normalizedDeployments(decodedDeployments, overflow: .throwError)
            mergedAppliedDamage = try normalizedDamageAttribution(
                decodedAppliedDamage,
                overflow: .throwError
            )
            mergedLosses = try normalizedLosses(decodedLosses, overflow: .throwError)
            mergedIdleDamage = try normalizedIdleDamage(decodedIdleDamage, overflow: .throwError)
        } catch {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "BattleResult row aggregation overflowed",
                    underlyingError: error
                )
            )
        }

        self.init(
            cityKey: try container.decode(CityKey.self, forKey: .cityKey),
            conquestMode: try container.decode(BattleConquestMode.self, forKey: .conquestMode),
            activeBattleSeconds: try container.decode(
                TimeInterval.self,
                forKey: .activeBattleSeconds
            ),
            deployments: mergedDeployments,
            appliedDamage: mergedAppliedDamage,
            losses: mergedLosses,
            idleDamageByType: mergedIdleDamage,
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

private enum SiegeAggregationOverflow: Error {
    case integerOverflow
}

private enum SiegeIntOverflowPolicy {
    case throwError
    case saturate
}

private func mvpDamageSharePercent(mvpDamage: Decimal, totalDamage: Decimal) -> Int? {
    guard mvpDamage > 0, totalDamage > 0 else {
        return nil
    }
    if mvpDamage >= totalDamage {
        return 100
    }

    // Truncating integer percent: floor((mvp * 100) / total).
    var percent = (mvpDamage * Decimal(100)) / totalDamage
    var rounded = Decimal()
    NSDecimalRound(&rounded, &percent, 0, .down)
    return NSDecimalNumber(decimal: rounded).intValue
}

private func addSiegeInts(
    _ lhs: Int,
    _ rhs: Int,
    overflow policy: SiegeIntOverflowPolicy
) throws -> Int {
    let (sum, didOverflow) = lhs.addingReportingOverflow(rhs)
    if !didOverflow {
        return sum
    }
    switch policy {
    case .throwError:
        throw SiegeAggregationOverflow.integerOverflow
    case .saturate:
        return Int.max
    }
}

private func saturatingNormalizedDeployments(
    _ rows: [SiegeDeploymentCount]
) -> [SiegeDeploymentCount] {
    (try? normalizedDeployments(rows, overflow: .saturate)) ?? []
}

private func saturatingNormalizedDamageAttribution(
    _ rows: [SiegeDamageAttribution]
) -> [SiegeDamageAttribution] {
    (try? normalizedDamageAttribution(rows, overflow: .saturate)) ?? []
}

private func saturatingNormalizedLosses(_ rows: [SiegeLossCount]) -> [SiegeLossCount] {
    (try? normalizedLosses(rows, overflow: .saturate)) ?? []
}

private func saturatingNormalizedIdleDamage(
    _ rows: [SiegeIdleDamageByType]
) -> [SiegeIdleDamageByType] {
    (try? normalizedIdleDamage(rows, overflow: .saturate)) ?? []
}

private func normalizedDeployments(
    _ rows: [SiegeDeploymentCount],
    overflow policy: SiegeIntOverflowPolicy
) throws -> [SiegeDeploymentCount] {
    var result: [SiegeDeploymentCount] = []
    for row in rows where row.count > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source && $0.lane == row.lane
        }) {
            result[index].count = try addSiegeInts(
                result[index].count,
                row.count,
                overflow: policy
            )
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
    _ rows: [SiegeDamageAttribution],
    overflow policy: SiegeIntOverflowPolicy
) throws -> [SiegeDamageAttribution] {
    var result: [SiegeDamageAttribution] = []
    for row in rows where row.damage > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source && $0.lane == row.lane
        }) {
            result[index].damage = try addSiegeInts(
                result[index].damage,
                row.damage,
                overflow: policy
            )
        } else {
            result.append(row)
        }
    }
    return result.sorted { lhs, rhs in
        rowSortKey(type: lhs.type, source: lhs.source, lane: lhs.lane)
            < rowSortKey(type: rhs.type, source: rhs.source, lane: rhs.lane)
    }
}

private func normalizedLosses(
    _ rows: [SiegeLossCount],
    overflow policy: SiegeIntOverflowPolicy
) throws -> [SiegeLossCount] {
    var result: [SiegeLossCount] = []
    for row in rows where row.count > 0 {
        if let index = result.firstIndex(where: {
            $0.type == row.type && $0.source == row.source
        }) {
            result[index].count = try addSiegeInts(
                result[index].count,
                row.count,
                overflow: policy
            )
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
    _ rows: [SiegeIdleDamageByType],
    overflow policy: SiegeIntOverflowPolicy
) throws -> [SiegeIdleDamageByType] {
    var result: [SiegeIdleDamageByType] = []
    for row in rows where row.damage > 0 {
        if let index = result.firstIndex(where: { $0.type == row.type }) {
            result[index].damage = try addSiegeInts(
                result[index].damage,
                row.damage,
                overflow: policy
            )
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

extension BattleResult {
    var totalDeploymentCount: Int {
        deployments.reduce(0) { total, row in
            let (sum, overflowed) = total.addingReportingOverflow(row.count)
            return overflowed ? Int.max : sum
        }
    }

    var totalLossCount: Int {
        losses.reduce(0) { total, row in
            let (sum, overflowed) = total.addingReportingOverflow(row.count)
            return overflowed ? Int.max : sum
        }
    }

    var totalIdleDamage: Int? {
        guard !idleDamageByType.isEmpty else { return nil }
        return idleDamageByType.reduce(0) { total, row in
            let (sum, overflowed) = total.addingReportingOverflow(row.damage)
            return overflowed ? Int.max : sum
        }
    }
}
