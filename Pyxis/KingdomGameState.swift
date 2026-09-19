//
//  KingdomGameState.swift
//  Pyxis
//

import Foundation

struct KingdomGameState: Codable, Equatable {
    static let maxIdleCatchUpSeconds = 8 * 60 * 60
    static let maxActiveBuildingSpawnDeltaSeconds = 60.0
    static let idleBuildingProductionScale = 10.0
    static let firstCountryCityCount = Country1CityCatalog.cityRange.count
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

    struct CompletionResult: Equatable {
        let awarded: Bool
        let goldEarned: Int
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
        case lockedBuilding(unlocksAtCity: Int)
        case slotOccupied
        case typeCapReached(maximum: Int)
        case cityConqueredDuringSettlement(goldEarned: Int, remainingGold: Int)
        case unavailable
    }

    enum UpgradeBuildingResult: Equatable {
        case upgraded(cost: Int, newLevel: Int, remainingGold: Int)
        case insufficientGold(cost: Int, currentGold: Int)
        case invalidSlot
        case missingBuilding
        case cityConqueredDuringSettlement(goldEarned: Int, remainingGold: Int)
        case unavailable
    }

    /// Explicit settle-before-select lane selection outcome (HPA-468).
    enum AssaultLaneSelectionResult: Equatable {
        case unavailable
        case unchanged(idleProgress: IdleProgressResult)
        case selected(idleProgress: IdleProgressResult)
        case conqueredDuringSettlement(IdleProgressResult)
    }

    var gold: Int
    var cityLevel: Int
    var siegeProgress: SiegeProgress
    var normalSoldierUpgradeLevel: Int
    var lastBackgroundedAt: Date?
    var countryNumber: Int
    var cityNumberInCountry: Int
    var completedCityCount: Int
    var stageStatus: StageStatus
    var cityBattleStates: [String: CityBattleState]
    var activeSiegeSession: ActiveSiegeSession?
    var pendingBattleResult: BattleResult?

    private enum CodingKeys: String, CodingKey {
        case gold
        case cityLevel
        case siegeProgress
        case normalSoldierUpgradeLevel
        case lastBackgroundedAt
        case countryNumber
        case cityNumberInCountry
        case completedCityCount
        case stageStatus
        case cityBattleStates
        case activeSiegeSession
        case pendingBattleResult
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
        gold: Int = 15,
        cityLevel: Int = 1,
        siegeProgress: SiegeProgress? = nil,
        normalSoldierUpgradeLevel: Int = 1,
        lastBackgroundedAt: Date? = nil,
        countryNumber: Int = 1,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        stageStatus: StageStatus = .battleActive,
        cityBattleStates: [String: CityBattleState] = [:],
        activeSiegeSession: ActiveSiegeSession? = nil,
        pendingBattleResult: BattleResult? = nil
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

        self.siegeProgress = Self.normalizedSiegeProgress(
            siegeProgress,
            layout: Country1CityCatalog.definition(for: normalizedCityNumber).siegeLayout,
            totalBudget: Self.cityMaxPower(for: normalizedCityLevel),
            requiresLivingKeep: resolvedStatus == .battleActive
        )

        let normalizedCurrentCityKey = CityKey(
            countryNumber: clampedCountryNumber,
            cityNumber: normalizedCityNumber
        )
        if resolvedStatus == .battleActive,
           activeSiegeSession?.cityKey == normalizedCurrentCityKey {
            self.activeSiegeSession = activeSiegeSession
        } else {
            self.activeSiegeSession = nil
        }

        if resolvedStatus != .battleActive,
           pendingBattleResult?.cityKey == normalizedCurrentCityKey {
            self.pendingBattleResult = pendingBattleResult
        } else {
            self.pendingBattleResult = nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStageStatus: StageStatus
        let decodedSession = (
            try? container.decodeIfPresent(ActiveSiegeSession.self, forKey: .activeSiegeSession)
        ) ?? nil
        let decodedPending = (
            try? container.decodeIfPresent(BattleResult.self, forKey: .pendingBattleResult)
        ) ?? nil

        if let rawStageStatus = try? container.decodeIfPresent(String.self, forKey: .stageStatus) {
            decodedStageStatus = StageStatus(rawValue: rawStageStatus) ?? .battleActive
        } else {
            decodedStageStatus = .battleActive
        }

        self.init(
            gold: try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0,
            cityLevel: try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1,
            siegeProgress: (try? container.decodeIfPresent(SiegeProgress.self, forKey: .siegeProgress)) ?? nil,
            normalSoldierUpgradeLevel: try container.decodeIfPresent(Int.self, forKey: .normalSoldierUpgradeLevel) ?? 1,
            lastBackgroundedAt: try container.decodeIfPresent(Date.self, forKey: .lastBackgroundedAt),
            countryNumber: try container.decodeIfPresent(Int.self, forKey: .countryNumber) ?? 1,
            cityNumberInCountry: try container.decodeIfPresent(Int.self, forKey: .cityNumberInCountry)
                ?? min(max(1, try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1), Self.firstCountryCityCount),
            completedCityCount: try container.decodeIfPresent(Int.self, forKey: .completedCityCount)
                ?? min(max(0, (try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1) - 1), Self.firstCountryCityCount),
            stageStatus: decodedStageStatus,
            cityBattleStates: Self.decodeCityBattleStates(from: container),
            activeSiegeSession: decodedSession,
            pendingBattleResult: decodedPending
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

    /// Forgiving normalization of persisted siege progress (HPA-468):
    /// unknown objective IDs are discarded, damage clamps to authored
    /// maxima, and a missing progress falls back to the authored default
    /// lane with zero damage. When `requiresLivingKeep` is set (`.battleActive`),
    /// a fully-damaged Keep is clamped to leave 1 HP: no real flow persists
    /// that shape — conquest finalizes exactly once and moves the stage out
    /// of `.battleActive` — so a dead-Keep-active save is a crafted/corrupt
    /// save that would no-op combat forever. Recovery treats it as
    /// nearly-conquered instead of fabricating a conquest reward.
    /// Highcrest (the authored Barracks layout) additionally normalizes its
    /// Guard reinforcement state into the authored tuning ranges (HPA-469);
    /// every other city normalizes reinforcement progress to nil.
    private static func normalizedSiegeProgress(
        _ progress: SiegeProgress?,
        layout: CitySiegeLayout,
        totalBudget: Int,
        requiresLivingKeep: Bool
    ) -> SiegeProgress {
        let maxPowers = layout.maxPowerAllocation(totalBudget: totalBudget)
        var damageByObjectiveID: [String: Int] = [:]
        for (objectiveID, rawDamage) in progress?.damageByObjectiveID ?? [:] {
            guard let maxPower = maxPowers[objectiveID] else { continue }
            damageByObjectiveID[objectiveID] = min(max(0, rawDamage), maxPower)
        }
        if requiresLivingKeep {
            let keepID = layout.keepObjective.id
            let keepMaxPower = maxPowers[keepID] ?? 0
            if keepMaxPower > 0, damageByObjectiveID[keepID, default: 0] >= keepMaxPower {
                damageByObjectiveID[keepID] = keepMaxPower - 1
            }
        }
        return SiegeProgress(
            selectedLane: progress?.selectedLane ?? layout.defaultLane,
            damageByObjectiveID: damageByObjectiveID,
            guardReinforcements: layout.barracksObjective != nil
                ? (progress?.guardReinforcements?.normalizedForHighcrest()
                    ?? GuardReinforcementProgress.freshHighcrest())
                : nil
        )
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

    var unlockedMapCityNumber: Int? {
        Country1CityCatalog.cityRange.first {
            mapStatus(for: $0) == .unlocked
        }
    }

    func displayCityTitle(for cityNumber: Int) -> String {
        if countryNumber == 1,
           let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) {
            return definition.name
        }
        return "Country \(countryNumber) - City \(cityNumber)"
    }

    var displayCityTitle: String {
        displayCityTitle(for: cityNumberInCountry)
    }

    /// Caller-owned conquest title with no ambient state: the authored
    /// `definition.conquestTitle` for Country 1 in-range cities, and the
    /// legacy `"Country N - City M Conquered"` fallback otherwise.
    static func displayConquestTitle(for cityKey: CityKey) -> String {
        guard cityKey.countryNumber == 1,
              let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
            return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
        }
        return definition.conquestTitle
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
        let entryLayout = currentCityDefinition.siegeLayout
        siegeProgress = SiegeProgress(
            selectedLane: entryLayout.defaultLane,
            damageByObjectiveID: [:],
            guardReinforcements: entryLayout.barracksObjective != nil
                ? GuardReinforcementProgress.freshHighcrest()
                : nil
        )
        stageStatus = .battleActive
        lastBackgroundedAt = nil
        pendingBattleResult = nil
        activeSiegeSession = ActiveSiegeSession(cityKey: currentCityKey)

        return .entered(country: countryNumber, city: cityNumberInCountry)
    }

    mutating func recordSoldierDeployment(
        type: SoldierType,
        source: SoldierSpawnSource,
        lane: BattleLane
    ) {
        guard stageStatus == .battleActive else {
            return
        }

        let favorableTypes = currentCityDefenseTrait.favorableSoldierTypes
        let exposedLane = currentCityLaneDefenseProfile.exposedLane
        mutateActiveSiegeSession { session in
            session.recordDeployment(
                type: type,
                source: source,
                lane: lane,
                favorableTypes: favorableTypes,
                exposedLane: exposedLane
            )
        }
    }

    mutating func recordActiveBattleTime(_ delta: TimeInterval) {
        guard stageStatus == .battleActive else {
            return
        }

        mutateActiveSiegeSession { session in
            session.advanceActiveBattleTime(delta)
        }
    }

    mutating func acknowledgePendingBattleResult() {
        pendingBattleResult = nil
    }

    mutating func recordSoldierLosses(_ events: [SoldierLossEvent]) {
        guard stageStatus == .battleActive else {
            return
        }

        mutateActiveSiegeSession { session in
            for event in events {
                session.recordLoss(event)
            }
        }
    }

    /// Applies live soldier attacks against their authored objectives
    /// (HPA-468): unknown objective IDs are rejected, damage clamps to each
    /// objective's remaining HP, and existing siege attribution records the
    /// clamped amounts. Conquest finalizes exactly once when Keep HP reaches
    /// zero — never off the legacy scalar.
    @discardableResult
    mutating func applyLiveSoldierAttacks(_ events: [SoldierAttackEvent]) -> AttackResult {
        guard stageStatus == .battleActive else {
            return .blocked
        }

        var totalApplied = 0

        for event in events {
            let applied = clampedObjectiveDamage(event.appliedDamage, objectiveID: event.objectiveID)
            guard applied > 0 else {
                continue
            }

            siegeProgress.damageByObjectiveID[event.objectiveID, default: 0] += applied
            mutateActiveSiegeSession { session in
                session.recordAttack(
                    SoldierAttackEvent(
                        soldierID: event.soldierID,
                        type: event.type,
                        source: event.source,
                        lane: event.lane,
                        objectiveID: event.objectiveID,
                        appliedDamage: applied
                    )
                )
            }
            totalApplied += applied

            if currentKeepRemainingPower <= 0 {
                break
            }
        }

        guard totalApplied > 0,
              currentKeepRemainingPower <= 0 else {
            return AttackResult(
                attackApplied: true,
                damageDealt: totalApplied,
                conqueredCities: 0,
                goldEarned: 0
            )
        }

        let completion = finalizeConquestWhenKeepDestroyed(conquestMode: .live)

        return AttackResult(
            attackApplied: true,
            damageDealt: totalApplied,
            conqueredCities: completion.awarded ? 1 : 0,
            goldEarned: completion.goldEarned
        )
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

        guard isBuildingTypeUnlocked(type) else {
            return .lockedBuilding(unlocksAtCity: Self.unlockCity(for: type))
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

        let rewardBeforeSettle = currentGoldReward
        let resolvedDate = date ?? Date()
        settleCurrentCityBuildingProgress(at: resolvedDate)
        // Re-fetch city state after settling may have mutated it
        // (settle may conquer the city, changing stageStatus)
        guard stageStatus == .battleActive else {
            if stageStatus == .cityConqueredPendingMap || stageStatus == .countryComplete {
                return .cityConqueredDuringSettlement(goldEarned: rewardBeforeSettle, remainingGold: gold)
            }
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

        guard let building = cityState.building(inSlot: slot) else {
            return .missingBuilding
        }

        let cost = Self.buildingUpgradeCost(for: building.type, currentLevel: building.level)
        guard gold >= cost else {
            return .insufficientGold(cost: cost, currentGold: gold)
        }

        let rewardBeforeSettle = currentGoldReward
        settleCurrentCityBuildingProgress(at: date)
        // Re-fetch city state and building after settling may have mutated them
        // (settle may conquer the city, changing stageStatus)
        guard stageStatus == .battleActive else {
            if stageStatus == .cityConqueredPendingMap || stageStatus == .countryComplete {
                return .cityConqueredDuringSettlement(goldEarned: rewardBeforeSettle, remainingGold: gold)
            }
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

        // Cap deltaTime to 60s. Beyond that (debugger pause, extreme frame stall) the
        // excess time is silently dropped rather than queued. This prevents a single huge
        // burst of spawns after a long stall. The idle catch-up path handles extended absences.
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

    /// Materializes due Highcrest Guard reinforcement waves (HPA-469) with
    /// O(1) due-opportunity arithmetic: `waveElapsedSeconds` carries the
    /// sub-interval phase, each elapsed interval becomes `guardsPerWave`
    /// full-HP Guards on the currently selected lane drawn from the
    /// remaining reserve. A dead Barracks or Keep stops new spawns; living
    /// Guards are never touched. Returns the newly spawned snapshots in
    /// order (oldest first).
    mutating func advanceActiveGuardReinforcements(deltaTime: Double) -> [GuardSnapshot] {
        guard stageStatus == .battleActive,
              currentKeepRemainingPower > 0,
              currentSiegeLayout.barracksObjective != nil,
              var progress = siegeProgress.guardReinforcements else {
            return []
        }
        if let barracks = currentSiegeLayout.barracksObjective {
            let barracksRemaining = (currentSiegeMaxPowers[barracks.id] ?? 0)
                - (siegeProgress.damageByObjectiveID[barracks.id] ?? 0)
            guard barracksRemaining > 0 else { return [] }
        }

        let totalElapsed = progress.waveElapsedSeconds + max(0, deltaTime)
        let dueOpportunities = Int(totalElapsed / HighcrestGuardRules.waveIntervalSeconds)
        progress.waveElapsedSeconds = totalElapsed.truncatingRemainder(
            dividingBy: HighcrestGuardRules.waveIntervalSeconds
        )
        let spawnCount = min(
            progress.remainingReserve,
            dueOpportunities * HighcrestGuardRules.guardsPerWave
        )
        progress.remainingReserve -= spawnCount
        let spawned = Array(
            repeating: GuardSnapshot(
                lane: siegeProgress.selectedLane,
                remainingHP: HighcrestGuardRules.maxHP
            ),
            count: spawnCount
        )
        progress.unresolvedGuards.append(contentsOf: spawned)
        siegeProgress.guardReinforcements = progress
        return spawned
    }

    /// Reconciles live combat's Guard snapshots into durable siege progress
    /// (HPA-469): incoming lane/HP values are normalized with the same
    /// totalReserve-derived rule as decode and the normalized snapshots replace
    /// `unresolvedGuards`. Returns whether durable state changed; non-pilot
    /// cities are always unchanged.
    @discardableResult
    mutating func synchronizeLiveGuardSnapshots(_ snapshots: [GuardSnapshot]) -> Bool {
        guard currentSiegeLayout.barracksObjective != nil,
              var progress = siegeProgress.guardReinforcements else {
            return false
        }
        progress.unresolvedGuards = snapshots
        let normalized = progress.normalizedForHighcrest()
        guard normalized != siegeProgress.guardReinforcements else {
            return false
        }
        siegeProgress.guardReinforcements = normalized
        return true
    }

    /// Spends `budget` against the oldest unresolved Guards on the selected
    /// lane first (HPA-469); guards on other lanes are untouched and dead
    /// guards are removed. Returns the leftover budget after Guard
    /// absorption.
    private mutating func spendDamageOnSelectedLaneGuards(_ budget: Int) -> Int {
        var leftover = budget
        guard leftover > 0, var progress = siegeProgress.guardReinforcements else {
            return leftover
        }
        var guards = progress.unresolvedGuards
        for index in guards.indices
        where leftover > 0 && guards[index].lane == siegeProgress.selectedLane {
            let absorbed = min(leftover, guards[index].remainingHP)
            guards[index].remainingHP -= absorbed
            leftover -= absorbed
        }
        guards.removeAll { $0.remainingHP <= 0 }
        progress.unresolvedGuards = guards
        siegeProgress.guardReinforcements = progress
        return leftover
    }

    /// Applies abstract building-spawn damage with per-type idle attribution
    /// (HPA-468 §3.6): each spawn becomes one trait-adjusted damage budget
    /// spent first against the oldest unresolved Guards on the selected lane
    /// (HPA-469 — Guard absorption is not city damage), then down the
    /// selected route where the first living objective absorbs up to its
    /// remaining HP and the remainder spills only after it dies. Due-window
    /// Guards materialize before the first spawn's damage whenever the
    /// current city has player buildings. Conquest is keyed on Keep HP
    /// alone. The 8-hour cap, 1/10 rate, no-buildings/no-progress rule,
    /// at-most-one-city conquest, and reward/report semantics live in the
    /// callers and are unchanged.
    /// Returns (totalApplied, conquered, goldEarned).
    private mutating func applyAbstractBuildingSpawnDamage(
        _ spawns: [BuildingSpawn],
        elapsedSeconds: Double,
        conquestMode: BattleConquestMode
    ) -> (applied: Int, conquered: Bool, goldEarned: Int) {
        var appliedTotal = 0
        var damageByObjectiveID = siegeProgress.damageByObjectiveID

        if cityBattleState(for: currentCityKey).occupiedSlotCount > 0 {
            _ = advanceActiveGuardReinforcements(deltaTime: elapsedSeconds)
        }

        for spawn in spawns {
            let power = traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
            guard power > 0 else { continue }

            let leftover = spendDamageOnSelectedLaneGuards(power)
            guard leftover > 0 else { continue }

            let (spentDamage, appliedByObjectiveID) = currentSiegeLayout.spendDamageBudget(
                leftover,
                along: siegeProgress.selectedLane,
                maxPowers: currentSiegeMaxPowers,
                damageByObjectiveID: damageByObjectiveID
            )
            damageByObjectiveID = spentDamage

            let applied = appliedByObjectiveID.values.reduce(0, +)
            guard applied > 0 else { continue }

            mutateActiveSiegeSession { session in
                session.recordIdleDamage(type: spawn.soldierType, appliedDamage: applied)
            }
            appliedTotal += applied
        }
        siegeProgress.damageByObjectiveID = damageByObjectiveID

        guard appliedTotal > 0 else {
            return (appliedTotal, false, 0)
        }

        let completion = finalizeConquestWhenKeepDestroyed(conquestMode: conquestMode)
        return (appliedTotal, completion.awarded, completion.goldEarned)
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

        let damageResult = applyAbstractBuildingSpawnDamage(
            spawns,
            elapsedSeconds: elapsedSeconds,
            conquestMode: .idle
        )
        if damageResult.conquered {
            return
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

        let spawns: [BuildingSpawn]
        if cityState.occupiedSlotCount > 0 {
            spawns = Self.resolveBuildingSpawns(
                in: &cityState,
                effectiveActiveSeconds: Double(elapsedSeconds) / Self.idleBuildingProductionScale
            )
            cityState.lastBuildingProgressResolvedAt = date
            cityBattleStates[key.storageKey] = cityState
        } else {
            spawns = []
        }

        // No player buildings means no credited progress at all — and never
        // a Guard-wave advance in isolation. Buildings whose spawn list is
        // empty still settle so the Guard phase advances for the credited
        // settlement window (HPA-469).
        guard cityState.occupiedSlotCount > 0 else {
            return IdleProgressResult(elapsedSeconds: elapsedSeconds, damageDealt: 0, conqueredCities: 0, goldEarned: 0)
        }

        let damageResult = applyAbstractBuildingSpawnDamage(
            spawns,
            elapsedSeconds: Double(elapsedSeconds),
            conquestMode: .idle
        )
        return IdleProgressResult(
            elapsedSeconds: elapsedSeconds,
            damageDealt: damageResult.applied,
            conqueredCities: damageResult.conquered ? 1 : 0,
            goldEarned: damageResult.goldEarned
        )
    }

    mutating func enterBackground(at date: Date) {
        markCurrentCityBuildingProgressInactive(at: date)
    }

    @discardableResult
    mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
        resolveCurrentCityBuildingIdleProgress(at: date)
    }

    /// Settle-before-select lane selection (HPA-468): any armed inactive
    /// interval is settled using the OLD lane first; if that settlement
    /// conquers the city the selection is left unchanged. No armed interval
    /// means no synthetic work.
    @discardableResult
    mutating func selectAssaultLane(_ lane: BattleLane, at date: Date) -> AssaultLaneSelectionResult {
        guard stageStatus == .battleActive else {
            return .unavailable
        }

        let idleProgress = resolveCurrentCityBuildingIdleProgress(at: date)
        guard stageStatus == .battleActive else {
            return .conqueredDuringSettlement(idleProgress)
        }

        guard lane != siegeProgress.selectedLane else {
            return .unchanged(idleProgress: idleProgress)
        }

        siegeProgress.selectedLane = lane
        return .selected(idleProgress: idleProgress)
    }

    /// Applies live objective damage with validation (HPA-468): unknown
    /// objective IDs are rejected and damage clamps to the objective's
    /// remaining HP. Finalizes conquest exactly once when Keep HP reaches
    /// zero. Returns the applied damage.
    @discardableResult
    mutating func applyObjectiveDamage(_ requestedDamage: Int, toObjectiveID objectiveID: String) -> Int {
        guard stageStatus == .battleActive, requestedDamage > 0 else {
            return 0
        }

        let applied = clampedObjectiveDamage(requestedDamage, objectiveID: objectiveID)
        guard applied > 0 else {
            return 0
        }

        siegeProgress.damageByObjectiveID[objectiveID, default: 0] += applied

        finalizeConquestWhenKeepDestroyed(conquestMode: .live)
        return applied
    }

    /// Damage actually absorbed by `objectiveID`, clamped to its remaining
    /// HP; unknown IDs absorb nothing.
    private func clampedObjectiveDamage(_ requestedDamage: Int, objectiveID: String) -> Int {
        let maxPowers = currentSiegeMaxPowers
        guard let maxPower = maxPowers[objectiveID] else {
            return 0
        }
        let remaining = max(0, maxPower - (siegeProgress.damageByObjectiveID[objectiveID] ?? 0))
        return min(max(0, requestedDamage), remaining)
    }

    /// Spends an abstract (idle) damage budget down `lane`'s authored route
    /// using the shared route rule (HPA-468): the first living objective
    /// absorbs up to its remaining HP and the remainder spills only after it
    /// dies; anything left once the Keep dies is dropped. Finalizes conquest
    /// exactly once when Keep HP reaches zero. Returns the total applied
    /// damage.
    @discardableResult
    mutating func spendRouteDamageBudget(_ budget: Int, lane: BattleLane) -> Int {
        guard stageStatus == .battleActive, budget > 0 else {
            return 0
        }

        let (damageByObjectiveID, appliedByObjectiveID) = currentSiegeLayout.spendDamageBudget(
            budget,
            along: lane,
            maxPowers: currentSiegeMaxPowers,
            damageByObjectiveID: siegeProgress.damageByObjectiveID
        )
        siegeProgress.damageByObjectiveID = damageByObjectiveID

        finalizeConquestWhenKeepDestroyed(conquestMode: .idle)
        return appliedByObjectiveID.values.reduce(0, +)
    }

    /// Completes the current city exactly once when the Keep reaches zero;
    /// optional structures are never fabricated destroyed. Later calls are
    /// no-ops via the stage gate in `completeCurrentCity`.
    @discardableResult
    private mutating func finalizeConquestWhenKeepDestroyed(conquestMode: BattleConquestMode) -> CompletionResult {
        guard stageStatus == .battleActive, currentKeepRemainingPower <= 0 else {
            return CompletionResult(awarded: false, goldEarned: 0)
        }

        let reward = currentGoldReward
        let cityKey = currentCityKey
        ensureSession()
        let result = (activeSiegeSession ?? ActiveSiegeSession(cityKey: cityKey))
            .finalized(conquestMode: conquestMode, goldEarned: reward)
        return completeCurrentCity(with: result)
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

    static func unlockedBuildingTypes(forCityNumber cityNumber: Int) -> [BuildingType] {
        let city = min(max(1, cityNumber), firstCountryCityCount)
        return BuildingType.allCases.filter { city >= unlockCity(for: $0) }
    }

    static func unlockCity(for buildingType: BuildingType) -> Int {
        switch buildingType {
        case .barracks:
            return 1
        case .archeryRange:
            return 2
        case .stable:
            return 5
        case .mageTower:
            return 8
        case .siegeWorkshop:
            return 11
        }
    }

    func isBuildingTypeUnlocked(_ buildingType: BuildingType) -> Bool {
        Self.unlockedBuildingTypes(forCityNumber: cityNumberInCountry).contains(buildingType)
    }

    static func defenseTrait(forCityNumber cityNumber: Int) -> CityDefenseTrait {
        Country1CityCatalog.definition(for: cityNumber).defenseTrait
    }

    var currentCityDefinition: CityDefinition {
        Country1CityCatalog.definition(for: cityNumberInCountry)
    }

    var currentCityDefenseTrait: CityDefenseTrait {
        currentCityDefinition.defenseTrait
    }

    var currentCityLaneDefenseProfile: LaneDefenseProfile {
        currentCityDefinition.laneDefenseProfile
    }

    // MARK: Siege authority (HPA-468)

    var currentSiegeLayout: CitySiegeLayout {
        currentCityDefinition.siegeLayout
    }

    private var currentSiegeMaxPowers: [String: Int] {
        currentSiegeLayout.maxPowerAllocation(totalBudget: cityMaxPower)
    }

    /// Authored Keep maximum for the current city's layout.
    var currentKeepMaxPower: Int {
        currentSiegeMaxPowers[currentSiegeLayout.keepObjective.id] ?? 0
    }

    /// Keep HP is the sole conquest/liveness authority (HPA-468).
    var currentKeepRemainingPower: Int {
        currentSiegeLayout.keepRemainingPower(
            maxPowers: currentSiegeMaxPowers,
            damageByObjectiveID: siegeProgress.damageByObjectiveID
        )
    }

    /// Ephemeral current-siege snapshot for the live combat simulator
    /// (HPA-468): the authored layout plus each objective's remaining HP,
    /// rebuilt from persisted progress on every read. Combat never writes
    /// objective damage itself; `applyLiveSoldierAttacks` owns that.
    var currentSiegeSnapshot: BattleCombatState.SiegeSnapshot {
        let layout = currentSiegeLayout
        let maxPowers = currentSiegeMaxPowers
        return BattleCombatState.SiegeSnapshot(
            layout: layout,
            objectiveRemainingPower: layout.remainingPower(
                maxPowers: maxPowers,
                damageByObjectiveID: siegeProgress.damageByObjectiveID
            )
        )
    }

    func manualSoldierLevel(for soldierType: SoldierType) -> Int? {
        let matchingLevels = cityBattleStateForCurrentCity.slots.values
            .filter { $0.type.soldierType == soldierType }
            .map(\.level)

        if let maxLevel = matchingLevels.max() {
            return maxLevel
        }

        // Fallback: infantry is always available at level 1 as the starter
        // unit type, preventing a soft-lock when a new city has no buildings
        // and the player cannot afford a Barracks.
        if soldierType == .infantry {
            return 1
        }

        return nil
    }

    func manualSpawnableSoldierTypes() -> [SoldierType] {
        SoldierType.allCases.filter { manualSoldierLevel(for: $0) != nil }
    }

    static func buildingBuildCost(for type: BuildingType) -> Int {
        switch type {
        case .barracks:
            return 15
        case .archeryRange:
            return 18
        case .stable:
            return 28
        case .mageTower:
            return 40
        case .siegeWorkshop:
            return 55
        }
    }

    static func buildingUpgradeCost(for type: BuildingType, currentLevel: Int) -> Int {
        let base: Double
        switch type {
        case .barracks:
            base = 12
        case .archeryRange:
            base = 14
        case .stable:
            base = 22
        case .mageTower:
            base = 30
        case .siegeWorkshop:
            base = 42
        }

        return roundedAtLeastOne(base * pow(1.65, Double(clampedLevel(currentLevel) - 1)))
    }

    static func activeSpawnInterval(for type: BuildingType) -> Double {
        switch type {
        case .barracks:
            return 10
        case .archeryRange:
            return 12
        case .stable:
            return 14
        case .mageTower:
            return 16
        case .siegeWorkshop:
            return 20
        }
    }

    static func soldierAttackPower(for _: SoldierType, level: Int) -> Int {
        normalSoldierAttackPower(for: level)
    }

    static func traitAdjustedSoldierAttackPower(
        for soldierType: SoldierType,
        level: Int,
        defenseTrait: CityDefenseTrait
    ) -> Int {
        let baseDamage = soldierAttackPower(for: soldierType, level: level)
        guard baseDamage > 0 else { return 0 }

        let adjustedDamage = Int((Double(baseDamage) * defenseTrait.damageMultiplier(for: soldierType)).rounded())
        return max(1, adjustedDamage)
    }

    func traitAdjustedSoldierAttackPower(for soldierType: SoldierType, level: Int) -> Int {
        Self.traitAdjustedSoldierAttackPower(
            for: soldierType,
            level: level,
            defenseTrait: currentCityDefenseTrait
        )
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

            let spawnCount = Int(building.spawnTimerElapsed / interval)
            if spawnCount > 0 {
                building.spawnTimerElapsed -= Double(spawnCount) * interval
                for _ in 0..<spawnCount {
                    spawns.append(BuildingSpawn(soldierType: building.type.soldierType, level: building.level, sourceSlot: slot))
                }
            }

            cityState.slots[slot] = building
        }

        return spawns
    }

    private mutating func ensureSession() {
        guard activeSiegeSession == nil else {
            return
        }

        activeSiegeSession = ActiveSiegeSession(cityKey: currentCityKey)
    }

    private mutating func mutateActiveSiegeSession(
        _ body: (inout ActiveSiegeSession) -> Void
    ) {
        ensureSession()
        guard var session = activeSiegeSession else {
            return
        }
        body(&session)
        activeSiegeSession = session
    }

    @discardableResult
    mutating func completeCurrentCity(with result: BattleResult) -> CompletionResult {
        guard stageStatus == .battleActive,
              result.cityKey == currentCityKey else {
            return CompletionResult(awarded: false, goldEarned: 0)
        }

        gold += result.goldEarned
        cityBattleStates.removeValue(forKey: currentCityKey.storageKey)
        activeSiegeSession = nil
        pendingBattleResult = result
        completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

        if completedCityCount >= Self.firstCountryCityCount {
            stageStatus = .countryComplete
        } else {
            stageStatus = .cityConqueredPendingMap
        }

        // HPA-367: Chronicle write hooks here (no-op in HPA-363).

        return CompletionResult(awarded: true, goldEarned: result.goldEarned)
    }
}
