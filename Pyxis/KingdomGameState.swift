//
//  KingdomGameState.swift
//  Pyxis
//

import Foundation

struct KingdomGameState: Codable, Equatable {
    static let maxIdleCatchUpSeconds = 8 * 60 * 60
    static let maxActiveBuildingSpawnDeltaSeconds = 60.0
    static let idleBuildingProductionScale = 10.0
    static let firstCountryCityCount = 15
    static let manualSoldierCap = 10

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

    enum BuildBuildingResult: Equatable {
        case built(cost: Int, remainingGold: Int)
        case insufficientGold(cost: Int, currentGold: Int)
        case invalidSlot
        case slotOccupied
        case typeCapReached(maximum: Int)
        case unavailable
    }

    enum UpgradeBuildingResult: Equatable {
        case upgraded(cost: Int, newLevel: Int, remainingGold: Int)
        case insufficientGold(cost: Int, currentGold: Int)
        case invalidSlot
        case missingBuilding
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
    var cityBattleStates: [String: CityBattleState]

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
        case cityBattleStates
    }

    private struct CityBattleStateCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
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
        stageStatus: StageStatus = .battleActive,
        cityBattleStates: [String: CityBattleState] = [:]
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

        var normalizedCityBattleStates: [String: CityBattleState] = [:]
        for (key, value) in cityBattleStates {
            guard let cityKey = CityKey(storageKey: key), cityKey.cityNumber > normalizedCompletedCityCount else {
                continue
            }

            var normalizedValue = value
            normalizedValue.normalize()
            normalizedCityBattleStates[cityKey.storageKey] = normalizedValue
        }
        self.cityBattleStates = normalizedCityBattleStates

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
            stageStatus: decodedStageStatus,
            cityBattleStates: Self.decodeCityBattleStates(from: container)
        )
    }

    private static func decodeCityBattleStates(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> [String: CityBattleState] {
        guard let cityStatesContainer = try? container.nestedContainer(
            keyedBy: CityBattleStateCodingKey.self,
            forKey: .cityBattleStates
        ) else {
            return [:]
        }

        var decodedStates: [String: CityBattleState] = [:]
        for key in cityStatesContainer.allKeys {
            guard CityKey(storageKey: key.stringValue) != nil,
                  let cityState = try? cityStatesContainer.decode(CityBattleState.self, forKey: key) else {
                continue
            }

            decodedStates[key.stringValue] = cityState
        }

        return decodedStates
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

    var currentCityKey: CityKey {
        CityKey(countryNumber: countryNumber, cityNumber: cityNumberInCountry)
    }

    var cityBattleStateForCurrentCity: CityBattleState {
        cityBattleState(for: currentCityKey)
    }

    func cityBattleState(for key: CityKey) -> CityBattleState {
        cityBattleStates[key.storageKey] ?? CityBattleState()
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
    mutating func applyLiveCombatDamage(_ rawDamage: Int) -> AttackResult {
        guard stageStatus == .battleActive else {
            return .blocked
        }

        let damage = max(0, rawDamage)
        guard damage > 0 else {
            return AttackResult(attackApplied: true, damageDealt: 0, conqueredCities: 0, goldEarned: 0)
        }

        let appliedDamage = min(damage, cityRemainingPower)
        cityRemainingPower -= appliedDamage

        guard cityRemainingPower <= 0 else {
            return AttackResult(attackApplied: true, damageDealt: appliedDamage, conqueredCities: 0, goldEarned: 0)
        }

        let reward = completeCurrentCity()

        return AttackResult(attackApplied: true, damageDealt: appliedDamage, conqueredCities: 1, goldEarned: reward)
    }

    @discardableResult
    mutating func buildBuilding(
        _ type: BuildingType,
        inSlot slot: Int,
        at date: Date? = nil
    ) -> BuildBuildingResult {
        guard stageStatus == .battleActive else {
            return .unavailable
        }

        guard CityBattleState.slotRange.contains(slot) else {
            return .invalidSlot
        }

        let key = currentCityKey
        var cityState = cityBattleState(for: key)

        guard cityState.building(inSlot: slot) == nil else {
            return .slotOccupied
        }

        guard cityState.buildingCount(for: type) < CityBattleState.maxBuildingsPerType else {
            return .typeCapReached(maximum: CityBattleState.maxBuildingsPerType)
        }

        let cost = Self.buildingBuildCost(for: type)
        guard gold >= cost else {
            return .insufficientGold(cost: cost, currentGold: gold)
        }

        let resolvedDate = date ?? Date()
        settleCurrentCityBuildingProgress(at: resolvedDate)
        // Re-fetch city state after settling may have mutated it
        // (settle may conquer the city, changing stageStatus)
        guard stageStatus == .battleActive else {
            return .unavailable
        }
        cityState = cityBattleState(for: key)

        gold -= cost
        cityState.setBuilding(CityBuilding(type: type), inSlot: slot)
        cityState.lastBuildingProgressResolvedAt = resolvedDate
        cityBattleStates[key.storageKey] = cityState

        return .built(cost: cost, remainingGold: gold)
    }

    @discardableResult
    mutating func upgradeBuilding(inSlot slot: Int, at date: Date = Date()) -> UpgradeBuildingResult {
        guard stageStatus == .battleActive else {
            return .unavailable
        }

        guard CityBattleState.slotRange.contains(slot) else {
            return .invalidSlot
        }

        let key = currentCityKey
        var cityState = cityBattleState(for: key)

        guard var building = cityState.building(inSlot: slot) else {
            return .missingBuilding
        }

        let cost = Self.buildingUpgradeCost(for: building.type, currentLevel: building.level)
        guard gold >= cost else {
            return .insufficientGold(cost: cost, currentGold: gold)
        }

        settleCurrentCityBuildingProgress(at: date)
        // Re-fetch city state and building after settling may have mutated them
        // (settle may conquer the city, changing stageStatus)
        guard stageStatus == .battleActive else {
            return .unavailable
        }
        cityState = cityBattleState(for: key)
        guard var updatedBuilding = cityState.building(inSlot: slot) else {
            return .missingBuilding
        }

        gold -= cost
        updatedBuilding.level += 1
        cityState.setBuilding(updatedBuilding, inSlot: slot)
        cityBattleStates[key.storageKey] = cityState

        return .upgraded(cost: cost, newLevel: updatedBuilding.level, remainingGold: gold)
    }

    @discardableResult
    mutating func resolveActiveBuildingSpawns(deltaTime rawDeltaTime: Double) -> [BuildingSpawn] {
        guard stageStatus == .battleActive else {
            return []
        }

        let deltaTime = min(max(0, rawDeltaTime), Self.maxActiveBuildingSpawnDeltaSeconds)
        guard deltaTime > 0 else {
            return []
        }

        let key = currentCityKey
        var cityState = cityBattleState(for: key)
        guard cityState.occupiedSlotCount > 0 else {
            return []
        }

        let spawns = Self.resolveBuildingSpawns(in: &cityState, effectiveActiveSeconds: deltaTime)
        cityBattleStates[key.storageKey] = cityState
        return spawns
    }

    mutating func markCurrentCityBuildingProgressInactive(at date: Date) {
        guard stageStatus == .battleActive else {
            lastBackgroundedAt = date
            return
        }

        lastBackgroundedAt = date
        let key = currentCityKey
        var cityState = cityBattleState(for: key)
        if cityState.occupiedSlotCount > 0 {
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
        }
    }

    /// Resolves any pending building spawns and applies the resulting damage
    /// to the current city, then advances the progress timestamp to `date`.
    /// Used before mutating buildings (build/upgrade) so that existing buildings
    /// receive credit for only the time they were actually present/at their old level.
    private mutating func settleCurrentCityBuildingProgress(at date: Date) {
        guard stageStatus == .battleActive else { return }

        let key = currentCityKey
        var cityState = cityBattleState(for: key)
        guard let lastResolved = cityState.lastBuildingProgressResolvedAt else {
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
            return
        }

        let rawElapsed = date.timeIntervalSince(lastResolved)
        guard rawElapsed > 0 else {
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
            return
        }

        let elapsedSeconds = min(rawElapsed, Double(Self.maxIdleCatchUpSeconds))
        let effectiveActive = elapsedSeconds / Self.idleBuildingProductionScale
        let spawns = Self.resolveBuildingSpawns(in: &cityState, effectiveActiveSeconds: effectiveActive)

        let totalDamage = spawns.reduce(0) { total, spawn in
            total + Self.soldierAttackPower(for: spawn.soldierType, level: spawn.level)
        }

        if totalDamage > 0 {
            let appliedDamage = min(totalDamage, cityRemainingPower)
            cityRemainingPower -= appliedDamage

            if totalDamage >= cityRemainingPower + appliedDamage {
                _ = completeCurrentCity()
                return
            }
        }

        cityState.lastBuildingProgressResolvedAt = date
        cityBattleStates[key.storageKey] = cityState
    }

    @discardableResult
    mutating func resolveCurrentCityBuildingIdleProgress(at date: Date) -> IdleProgressResult {
        guard stageStatus == .battleActive else {
            lastBackgroundedAt = nil
            return .none
        }

        let key = currentCityKey
        var cityState = cityBattleState(for: key)
        guard let backgroundedAt = lastBackgroundedAt else {
            return .none
        }

        lastBackgroundedAt = nil

        let resolvedStart = cityState.lastBuildingProgressResolvedAt ?? backgroundedAt
        let rawElapsed = Int(date.timeIntervalSince(resolvedStart))
        let elapsedSeconds = min(max(0, rawElapsed), Self.maxIdleCatchUpSeconds)
        guard elapsedSeconds > 0 else {
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
            return .none
        }

        let totalPotentialDamage: Int
        if cityState.occupiedSlotCount > 0 {
            let spawns = Self.resolveBuildingSpawns(
                in: &cityState,
                effectiveActiveSeconds: Double(elapsedSeconds) / Self.idleBuildingProductionScale
            )
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
            totalPotentialDamage = spawns.reduce(0) { total, spawn in
                total + Self.soldierAttackPower(for: spawn.soldierType, level: spawn.level)
            }
        } else {
            totalPotentialDamage = 0
        }

        guard totalPotentialDamage > 0 else {
            return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: 0, conqueredCities: 0, goldEarned: 0)
        }

        let appliedDamage = min(totalPotentialDamage, cityRemainingPower)
        guard totalPotentialDamage >= cityRemainingPower else {
            cityRemainingPower -= totalPotentialDamage
            return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: totalPotentialDamage, conqueredCities: 0, goldEarned: 0)
        }

        let reward = completeCurrentCity()
        return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: appliedDamage, conqueredCities: 1, goldEarned: reward)
    }

    mutating func enterBackground(at date: Date) {
        markCurrentCityBuildingProgressInactive(at: date)
    }

    @discardableResult
    mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
        resolveCurrentCityBuildingIdleProgress(at: date)
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

    static func buildingBuildCost(for type: BuildingType) -> Int {
        switch type {
        case .barracks:
            return 15
        case .archeryRange:
            return 18
        }
    }

    static func buildingUpgradeCost(for type: BuildingType, currentLevel: Int) -> Int {
        let base: Double
        switch type {
        case .barracks:
            base = 12
        case .archeryRange:
            base = 14
        }

        return roundedAtLeastOne(base * pow(1.65, Double(clampedLevel(currentLevel) - 1)))
    }

    static func activeSpawnInterval(for type: BuildingType) -> Double {
        switch type {
        case .barracks:
            return 10
        case .archeryRange:
            return 12
        }
    }

    static func soldierAttackPower(for _: SoldierType, level: Int) -> Int {
        normalSoldierAttackPower(for: level)
    }

    private static func clampedLevel(_ level: Int) -> Int {
        max(1, level)
    }

    private static func roundedAtLeastOne(_ value: Double) -> Int {
        max(1, Int(value.rounded()))
    }

    private static func resolveBuildingSpawns(
        in cityState: inout CityBattleState,
        effectiveActiveSeconds: Double
    ) -> [BuildingSpawn] {
        guard effectiveActiveSeconds > 0 else {
            return []
        }

        var spawns: [BuildingSpawn] = []

        for slot in cityState.slots.keys.sorted() {
            guard var building = cityState.slots[slot] else {
                continue
            }

            building.spawnTimerElapsed += effectiveActiveSeconds
            let interval = activeSpawnInterval(for: building.type)

            while building.spawnTimerElapsed >= interval {
                building.spawnTimerElapsed -= interval
                spawns.append(BuildingSpawn(soldierType: building.type.soldierType, level: building.level, sourceSlot: slot))
            }

            cityState.slots[slot] = building
        }

        return spawns
    }

    private mutating func completeCurrentCity() -> Int {
        let reward = currentGoldReward
        gold += reward
        cityRemainingPower = 0
        cityBattleStates.removeValue(forKey: currentCityKey.storageKey)
        completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

        if completedCityCount >= Self.firstCountryCityCount {
            stageStatus = .countryComplete
        } else {
            stageStatus = .cityConqueredPendingMap
        }

        return reward
    }
}
