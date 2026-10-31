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
    var lastBackgroundedAt: Date?
    var countryNumber: Int
    var cityNumberInCountry: Int
    var completedCityCount: Int
    var stageStatus: StageStatus
    var cityBattleStates: [String: CityBattleState]
    var activeSiegeSession: ActiveSiegeSession?
    var pendingBattleResult: BattleResult?
    var treasury: TreasuryState

    private enum CodingKeys: String, CodingKey {
        case gold
        case cityLevel
        case siegeProgress
        case lastBackgroundedAt
        case countryNumber
        case cityNumberInCountry
        case completedCityCount
        case stageStatus
        case cityBattleStates
        case activeSiegeSession
        case pendingBattleResult
        case treasury
    }

    /// Decode-only tombstone keys (HPA-582). `normalSoldierUpgradeLevel`
    /// was a non-optional, always-encoded field until the rebalance
    /// deleted it, so a payload still carrying it was necessarily written
    /// under the 2.15 `cityMaxPower` curve — the epoch marker that tells
    /// decode to rescale absolute siege damage into the 1.85 curve. Never
    /// stored, never encoded.
    private enum LegacyCurveCodingKeys: String, CodingKey {
        case normalSoldierUpgradeLevel
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
        lastBackgroundedAt: Date? = nil,
        countryNumber: Int = 1,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        stageStatus: StageStatus = .battleActive,
        cityBattleStates: [String: CityBattleState] = [:],
        activeSiegeSession: ActiveSiegeSession? = nil,
        pendingBattleResult: BattleResult? = nil,
        treasury: TreasuryState = TreasuryState()
    ) {
        self.init(
            gold: gold,
            cityLevel: cityLevel,
            siegeProgress: siegeProgress,
            lastBackgroundedAt: lastBackgroundedAt,
            countryNumber: countryNumber,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount,
            stageStatus: stageStatus,
            cityBattleStates: cityBattleStates,
            activeSiegeSession: activeSiegeSession,
            pendingBattleResult: pendingBattleResult,
            treasury: treasury,
            persistedSiegeDamageUnderLegacyCurve: false
        )
    }

    /// Decode-only normalization entry point (HPA-582): the memberwise init
    /// plus `persistedSiegeDamageUnderLegacyCurve`, the decode tombstone flag
    /// that rescales siege progress written under the pre-rebalance 2.15
    /// `cityMaxPower` curve. Kept off the public init so in-code
    /// construction can never opt into a decode-era migration.
    private init(
        gold: Int = 15,
        cityLevel: Int = 1,
        siegeProgress: SiegeProgress? = nil,
        lastBackgroundedAt: Date? = nil,
        countryNumber: Int = 1,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        stageStatus: StageStatus = .battleActive,
        cityBattleStates: [String: CityBattleState] = [:],
        activeSiegeSession: ActiveSiegeSession? = nil,
        pendingBattleResult: BattleResult? = nil,
        treasury: TreasuryState,
        persistedSiegeDamageUnderLegacyCurve: Bool
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
        self.lastBackgroundedAt = lastBackgroundedAt
        self.countryNumber = clampedCountryNumber
        self.cityNumberInCountry = normalizedCityNumber
        self.completedCityCount = normalizedCompletedCityCount
        self.stageStatus = resolvedStatus
        self.treasury = treasury

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

        // Camp-derived Captain level: self isn't fully initialized yet, so
        // the shared rule reads the already-normalized current-city battle
        // state directly.
        let captainLevel = Self.captainLevel(
            for: normalizedCityBattleStates[
                CityKey(countryNumber: clampedCountryNumber, cityNumber: normalizedCityNumber).storageKey
            ]
        )

        let totalBudget = Self.cityMaxPower(for: normalizedCityLevel)
        let normalizedSiege = Self.normalizedSiegeProgress(
            siegeProgress,
            layout: Country1CityCatalog.definition(for: normalizedCityNumber).siegeLayout,
            totalBudget: totalBudget,
            persistedBudget: persistedSiegeDamageUnderLegacyCurve
                ? Self.legacyCityMaxPower(for: normalizedCityLevel)
                : totalBudget,
            requiresLivingKeep: resolvedStatus == .battleActive
        )
        self.siegeProgress = Self.normalizedCaptainProgress(
            normalizedSiege,
            cityNumber: normalizedCityNumber,
            captainLevel: captainLevel,
            stageIsActive: resolvedStatus == .battleActive
        )

        let normalizedCurrentCityKey = CityKey(
            countryNumber: clampedCountryNumber,
            cityNumber: normalizedCityNumber
        )
        if resolvedStatus == .battleActive,
           activeSiegeSession?.cityKey == normalizedCurrentCityKey {
            // A legacy-curve save also left the live session's recorded
            // damage in 2.15-curve units; rescale by the same budget ratio
            // so report attributions stay consistent with the rescaled
            // siege damage they are measured against (HPA-582).
            self.activeSiegeSession = persistedSiegeDamageUnderLegacyCurve
                ? activeSiegeSession?.damageRescaledForBudgetChange(
                    from: Self.legacyCityMaxPower(for: normalizedCityLevel),
                    to: totalBudget
                )
                : activeSiegeSession
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

        // HPA-582 epoch marker: a payload still carrying the deleted
        // `normalSoldierUpgradeLevel` field predates the 1.85
        // `cityMaxPower` curve, so its absolute siege damage is in legacy
        // units and must be rescaled during normalization.
        let persistedSiegeDamageUnderLegacyCurve = (
            try? decoder.container(keyedBy: LegacyCurveCodingKeys.self)
        )?.contains(.normalSoldierUpgradeLevel) ?? false

        self.init(
            gold: try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0,
            cityLevel: try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1,
            siegeProgress: (try? container.decodeIfPresent(SiegeProgress.self, forKey: .siegeProgress)) ?? nil,
            lastBackgroundedAt: try container.decodeIfPresent(Date.self, forKey: .lastBackgroundedAt),
            countryNumber: try container.decodeIfPresent(Int.self, forKey: .countryNumber) ?? 1,
            cityNumberInCountry: try container.decodeIfPresent(Int.self, forKey: .cityNumberInCountry)
                ?? min(max(1, try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1), Self.firstCountryCityCount),
            completedCityCount: try container.decodeIfPresent(Int.self, forKey: .completedCityCount)
                ?? min(max(0, (try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1) - 1), Self.firstCountryCityCount),
            stageStatus: decodedStageStatus,
            cityBattleStates: Self.decodeCityBattleStates(from: container),
            activeSiegeSession: decodedSession,
            pendingBattleResult: decodedPending,
            treasury: (
                try? container.decodeIfPresent(TreasuryState.self, forKey: .treasury)
            ) ?? TreasuryState(),
            persistedSiegeDamageUnderLegacyCurve: persistedSiegeDamageUnderLegacyCurve
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
    /// lane with zero damage. The one discarded-ID exception is the
    /// pre-rollout `"keep"` key (HPA-477): it migrates onto the authored
    /// Keep via `migratedLegacyKeepDamage` instead of resetting an
    /// in-progress siege to full HP. `persistedBudget` is the total HP
    /// budget the damage was written under — `legacyCityMaxPower` for a
    /// pre-rebalance save (see the `normalSoldierUpgradeLevel` decode
    /// tombstone), `totalBudget` otherwise — and
    /// `rescaledPersistedSiegeDamage` carries each objective's damaged
    /// fraction across the 2.15→1.85 curve change so a late-city partial
    /// siege from an older build keeps its proportion instead of
    /// clamping to 1 HP under the much smaller new maxima (HPA-582).
    /// When `requiresLivingKeep` is set (`.battleActive`),
    /// a fully-damaged Keep is clamped to leave 1 HP: no real flow persists
    /// that shape — conquest finalizes exactly once and moves the stage out
    /// of `.battleActive` — so a dead-Keep-active save is a crafted/corrupt
    /// save that would no-op combat forever. Recovery treats it as
    /// nearly-conquered instead of fabricating a conquest reward.
    /// A city whose authored layout has a Barracks (Highcrest and the later
    /// Barracks cities) additionally normalizes its Guard reinforcement state
    /// into the authored tuning ranges (HPA-469); every other city normalizes
    /// reinforcement progress to nil.
    private static func normalizedSiegeProgress(
        _ progress: SiegeProgress?,
        layout: CitySiegeLayout,
        totalBudget: Int,
        persistedBudget: Int,
        requiresLivingKeep: Bool
    ) -> SiegeProgress {
        let maxPowers = layout.maxPowerAllocation(totalBudget: totalBudget)
        var damageByObjectiveID: [String: Int] = [:]
        for (objectiveID, rawDamage) in migratedLegacyKeepDamage(
            rescaledPersistedSiegeDamage(
                progress?.damageByObjectiveID ?? [:],
                layout: layout,
                maxPowers: maxPowers,
                persistedBudget: persistedBudget,
                totalBudget: totalBudget
            ),
            layout: layout,
            maxPowers: maxPowers,
            persistedBudget: persistedBudget
        ) {
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
                ? (progress?.guardReinforcements?.normalizedForCountry1()
                    ?? GuardReinforcementProgress.freshCountry1())
                : nil,
            captain: progress?.captain
        )
    }

    /// Rescales absolute siege damage persisted under the pre-HPA-582
    /// `cityMaxPower` curve (growth 2.15) into current-curve units: each
    /// known objective keeps its damaged fraction (`damage ×
    /// newMax / oldMax`) so an older late-city save stays proportionally
    /// besieged instead of clamping near-dead under the much smaller 1.85
    /// maxima, and `rescaledPersistedObjectiveDamage` additionally
    /// preserves liveness — decode must never destroy a structure that was
    /// alive when the save was written, nor erase recorded damage by
    /// rounding it to zero. The legacy `"keep"` key is left raw
    /// when it is foreign to the layout — its units are the whole
    /// persisted budget, which `migratedLegacyKeepDamage` already carries
    /// over by remaining fraction. A current-curve save passes through
    /// untouched (`persistedBudget == totalBudget`).
    private static func rescaledPersistedSiegeDamage(
        _ damageByObjectiveID: [String: Int],
        layout: CitySiegeLayout,
        maxPowers: [String: Int],
        persistedBudget: Int,
        totalBudget: Int
    ) -> [String: Int] {
        guard persistedBudget != totalBudget else { return damageByObjectiveID }
        let persistedMaxPowers = layout.maxPowerAllocation(totalBudget: persistedBudget)
        let legacyKeyIsForeign = layout.keepObjective.id != CitySiegeLayout.singleKeepObjectiveID
        var rescaled = damageByObjectiveID
        for (objectiveID, damage) in damageByObjectiveID {
            if legacyKeyIsForeign, objectiveID == CitySiegeLayout.singleKeepObjectiveID {
                continue
            }
            guard let persistedMax = persistedMaxPowers[objectiveID], persistedMax > 0,
                  let maxPower = maxPowers[objectiveID] else {
                continue
            }
            rescaled[objectiveID] = rescaledPersistedObjectiveDamage(
                damage,
                persistedMax: persistedMax,
                newMax: maxPower
            )
        }
        return rescaled
    }

    /// One objective's persisted damage carried across the curve change
    /// with liveness preserved (HPA-582): an objective recorded as
    /// destroyed (`damage >= persistedMax`) stays destroyed, and a living
    /// one keeps at least 1 HP — the raw half-away rounding could round a
    /// nearly-destroyed support objective up to its full new maximum and
    /// kill it during decode without any attack. Recorded nonzero damage
    /// likewise never rounds down to pristine. The proportional value is
    /// then clamped inside the open interval (0, newMax), or to 0 when the
    /// new maximum cannot represent a partial point.
    private static func rescaledPersistedObjectiveDamage(
        _ damage: Int,
        persistedMax: Int,
        newMax: Int
    ) -> Int {
        guard damage > 0 else { return damage }
        guard damage < persistedMax else { return newMax }
        let scaled = Int((Double(damage) * Double(newMax) / Double(persistedMax)).rounded())
        return min(max(1, scaled), max(0, newMax - 1))
    }

    /// Maps the pre-rollout `"keep"` damage key onto the authored Keep for
    /// `normalizedSiegeProgress` (HPA-477). Before the Country 1 tactical
    /// rollout every city used the default `singleKeep` layout, so
    /// persisted damage lived under that one objective ID while the
    /// re-authored layouts use city-specific Keep IDs. The legacy Keep's
    /// remaining-HP fraction carries over — copying absolute damage would
    /// over-reward, since the authored Keep holds only its
    /// durability-weight share of the same total budget. `persistedBudget`
    /// is the budget the save was written under (HPA-582): a pre-rebalance
    /// save's legacy Keep spanned the old 2.15-curve total, not today's,
    /// so the fraction must be measured against it. A fully-spent
    /// legacy Keep migrates as fully damaged and the `requiresLivingKeep`
    /// clamp recovers it as nearly-conquered, matching the existing
    /// crafted-save policy. Maps without the legacy key, or a layout whose
    /// authored Keep still uses the `singleKeep` ID (the test fixture
    /// shape), pass through untouched.
    private static func migratedLegacyKeepDamage(
        _ damageByObjectiveID: [String: Int],
        layout: CitySiegeLayout,
        maxPowers: [String: Int],
        persistedBudget: Int
    ) -> [String: Int] {
        let keepID = layout.keepObjective.id
        let legacyKeepID = CitySiegeLayout.singleKeepObjectiveID
        guard keepID != legacyKeepID, let legacyDamage = damageByObjectiveID[legacyKeepID] else {
            return damageByObjectiveID
        }

        var migrated = damageByObjectiveID
        migrated.removeValue(forKey: legacyKeepID)
        let legacyKeepMax = max(1, persistedBudget) // the old single Keep held the whole persisted-era budget
        let remainingFraction = Double(max(0, legacyKeepMax - max(0, legacyDamage))) / Double(legacyKeepMax)
        let keepMaxPower = maxPowers[keepID] ?? 0
        let migratedDamage = keepMaxPower - Int((remainingFraction * Double(keepMaxPower)).rounded())
        migrated[keepID] = max(migrated[keepID] ?? 0, migratedDamage)
        return migrated
    }

    /// Applies the City 3+ Captain rules (HPA-475) after generic siege
    /// normalization, so a constructed `KingdomGameState` carries honest
    /// Captain HP before any scene/HUD reads it. The Captain exists only in
    /// an active City 3+ siege; fresh entries seed full HP on the selected
    /// lane; persisted HP clamps to the camp-derived maximum; and
    /// HP 0 + recovery 0 means recovery already completed — restore full HP
    /// on the current selected lane.
    private static func normalizedCaptainProgress(
        _ progress: SiegeProgress,
        cityNumber: Int,
        captainLevel: Int,
        stageIsActive: Bool
    ) -> SiegeProgress {
        var progress = progress
        guard stageIsActive, VanguardCaptainRules.isAvailable(cityNumber: cityNumber) else {
            progress.captain = nil
            return progress
        }
        let currentMaxHP = VanguardCaptainRules.maxHP(for: captainLevel)
        if var captain = progress.captain {
            captain = captain.normalizedForCaptain()
            captain.remainingHP = min(captain.remainingHP, currentMaxHP)
            if captain.remainingHP == 0, captain.recoveryRemainingSeconds == 0 {
                captain.remainingHP = currentMaxHP
                captain.lane = progress.selectedLane
            }
            progress.captain = captain
        } else {
            progress.captain = .freshCaptain(
                selectedLane: progress.selectedLane,
                captainLevel: captainLevel
            )
        }
        return progress
    }

    var currentGoldReward: Int {
        goldReward(forCity: cityLevel)
    }

    /// The one War-Chest-adjusted conquest quote for any city (HPA-670):
    /// base curve × (1 + 0.10 × warChestLevel), rounded once. The Map Scout
    /// card, Battle HUD, live settlement and idle/Camp results all consume
    /// this seam — no other multiplication site exists.
    func goldReward(forCity level: Int) -> Int {
        Self.roundedAtLeastOne(
            Double(Self.baseGoldReward(for: level)) * (1.0 + 0.10 * Double(treasury.warChest))
        )
    }

    var currentCityKey: CityKey {
        CityKey(countryNumber: countryNumber, cityNumber: cityNumberInCountry)
    }

    var cityBattleStateForCurrentCity: CityBattleState {
        cityBattleState(for: currentCityKey)
    }

    /// Captain level derives from the current camp on every read (HPA-582):
    /// the highest level across ALL buildings of any type, falling back to 1
    /// for an empty camp. No storage field — never persisted, never migrated.
    var captainLevel: Int {
        Self.captainLevel(for: cityBattleStateForCurrentCity)
    }

    /// The single camp-derived Captain-level rule (HPA-582): highest
    /// building level in the camp, fallback 1 for an empty or absent camp —
    /// shared by the `captainLevel` projection and init-time normalization,
    /// which runs before self is usable.
    private static func captainLevel(for cityState: CityBattleState?) -> Int {
        cityState?.slots.values.map(\.level).max() ?? 1
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
                ? GuardReinforcementProgress.freshCountry1()
                : nil,
            captain: VanguardCaptainRules.isAvailable(cityNumber: cityNumber)
                ? .freshCaptain(
                    selectedLane: entryLayout.defaultLane,
                    captainLevel: captainLevel
                )
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

    // MARK: Vanguard Captain (HPA-475)

    /// Records a live Captain retreat: HP drops to 0 and the full recovery
    /// clock starts, preserving the last live lane. A retreating captain
    /// cannot re-die. Creates no damage/reward/conquest side effects.
    mutating func recordCaptainRetreat() {
        guard stageStatus == .battleActive,
              var captain = siegeProgress.captain,
              captain.remainingHP > 0 else {
            return
        }
        captain.remainingHP = 0
        captain.recoveryRemainingSeconds = VanguardCaptainRules.recoverySeconds
        siegeProgress.captain = captain
    }

    /// Advances Captain recovery by a non-negative delta while the siege is
    /// active and the Captain is down. BattleScene is responsible for calling
    /// this only from live ticks with their clamped combat delta; Camp, Map,
    /// and background settlement do not call it. Crossing zero restores
    /// current max HP on the current selected lane exactly once.
    /// Returns whether recovery completed.
    @discardableResult
    mutating func advanceCaptainRecovery(deltaTime: Double) -> Bool {
        guard deltaTime >= 0,
              stageStatus == .battleActive,
              var captain = siegeProgress.captain,
              captain.remainingHP == 0 else {
            return false
        }
        captain.recoveryRemainingSeconds = max(0, captain.recoveryRemainingSeconds - deltaTime)
        guard captain.recoveryRemainingSeconds == 0 else {
            siegeProgress.captain = captain
            return false
        }
        captain.remainingHP = VanguardCaptainRules.maxHP(for: captainLevel)
        captain.lane = siegeProgress.selectedLane
        siegeProgress.captain = captain
        return true
    }

    /// Consumes the once-per-siege Rally. Succeeds only while the Captain
    /// is deployed (not retreating) and Rally is still unused; later
    /// requests — manual or automatic — are rejected.
    @discardableResult
    mutating func consumeVanguardRally() -> Bool {
        guard stageStatus == .battleActive,
              let captain = siegeProgress.captain,
              captain.remainingHP > 0,
              !captain.rallyConsumed else {
            return false
        }
        siegeProgress.captain?.rallyConsumed = true
        return true
    }

    /// Persists a living Captain's lane and HP, clamped to the current
    /// camp-derived maximum. Never resurrects a retreating captain —
    /// retreats flow through `recordCaptainRetreat`. Returns whether
    /// durable state changed.
    @discardableResult
    mutating func synchronizeLiveCaptain(lane: BattleLane, remainingHP: Int) -> Bool {
        guard stageStatus == .battleActive,
              var captain = siegeProgress.captain,
              captain.remainingHP > 0,
              remainingHP > 0 else {
            return false
        }
        let clampedHP = min(remainingHP, VanguardCaptainRules.maxHP(for: captainLevel))
        guard captain.lane != lane || captain.remainingHP != clampedHP else {
            return false
        }
        captain.lane = lane
        captain.remainingHP = clampedHP
        siegeProgress.captain = captain
        return true
    }

    mutating func recordSoldierLosses(_ events: [SoldierLossEvent]) {
        guard stageStatus == .battleActive else {
            return
        }

        mutateActiveSiegeSession { session in
            for event in events where !event.isCaptain {
                session.recordLoss(event)
            }
        }
    }

    /// Applies live soldier attacks against their authored objectives
    /// (HPA-468): unknown objective IDs are rejected, damage clamps to each
    /// objective's remaining HP, and existing siege attribution records the
    /// clamped amounts. Conquest finalizes exactly once when Keep HP reaches
    /// zero — never off the legacy scalar. Captain-flagged events are
    /// ignored at this seam (HPA-475): Captain damage applies through
    /// `applyObjectiveDamage` and never enters report attribution, no matter
    /// what the caller passed.
    @discardableResult
    mutating func applyLiveSoldierAttacks(_ events: [SoldierAttackEvent]) -> AttackResult {
        guard stageStatus == .battleActive else {
            return .blocked
        }

        var totalApplied = 0

        for event in events where !event.isCaptain {
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

        let cost = buildingBuildCost(for: type)
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
        // No Captain HP preservation here: a fresh building is always level
        // 1, so a build can never raise the camp-derived captainLevel and
        // the max-HP delta is always zero. `upgradeBuilding` keeps the
        // delta hand-off — it is the only mutation that can grow the max.

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

        let cost = buildingUpgradeCost(for: building.type, currentLevel: building.level)
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

        let captainMaxHPBefore = VanguardCaptainRules.maxHP(for: captainLevel)
        gold -= cost
        updatedBuilding.level += 1
        cityState.setBuilding(updatedBuilding, inSlot: slot)
        cityBattleStates[key.storageKey] = cityState
        preserveLivingCaptainHPThroughCampGrowth(previousMaxHP: captainMaxHPBefore)

        return .upgraded(cost: cost, newLevel: updatedBuilding.level, remainingGold: gold)
    }

    /// The only Treasury purchase mutation (HPA-670): max level is checked
    /// before affordability, the computed next price is subtracted exactly
    /// once, and exactly one level increments. No stage gate — purchases are
    /// valid in `battleActive`, `cityConqueredPendingMap` and
    /// `countryComplete`; a rejection never mutates state.
    @discardableResult
    mutating func purchaseTreasuryUpgrade(_ upgrade: TreasuryUpgrade) -> TreasuryPurchaseResult {
        let currentLevel = treasury.level(for: upgrade)
        guard currentLevel < upgrade.maxLevel else {
            return .maxLevel
        }

        let cost = upgrade.price(forCurrentLevel: currentLevel)
        guard gold >= cost else {
            return .insufficientGold
        }

        gold -= cost
        treasury.setLevel(currentLevel + 1, for: upgrade)
        return .purchased(cost: cost, newLevel: currentLevel + 1, remainingGold: gold)
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

    /// Materializes due Country 1 Guard reinforcement waves (HPA-469) with
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
        let dueOpportunities = Int(totalElapsed / Country1GuardRules.waveIntervalSeconds)
        progress.waveElapsedSeconds = totalElapsed.truncatingRemainder(
            dividingBy: Country1GuardRules.waveIntervalSeconds
        )
        let spawnCount = min(
            progress.remainingReserve,
            dueOpportunities * Country1GuardRules.guardsPerWave
        )
        progress.remainingReserve -= spawnCount
        let spawned = Array(
            repeating: GuardSnapshot(
                lane: siegeProgress.selectedLane,
                remainingHP: Country1GuardRules.maxHP
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
    /// `unresolvedGuards`. Returns whether durable state changed; a city without
    /// a Barracks objective is always unchanged.
    @discardableResult
    mutating func synchronizeLiveGuardSnapshots(_ snapshots: [GuardSnapshot]) -> Bool {
        guard currentSiegeLayout.barracksObjective != nil,
              var progress = siegeProgress.guardReinforcements else {
            return false
        }
        progress.unresolvedGuards = snapshots
        let normalized = progress.normalizedForCountry1()
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

        // Layout and max powers are invariant for the whole spawn batch —
        // only the damage map advances between iterations.
        let layout = currentSiegeLayout
        let maxPowers = currentSiegeMaxPowers

        for spawn in spawns {
            let power = traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
            guard power > 0 else { continue }

            let leftover = spendDamageOnSelectedLaneGuards(power)
            guard leftover > 0 else { continue }

            // HPA-582: one role multiplier per spawn, keyed to the first live
            // objective on the selected lane, before the unchanged route-budget
            // helper. Bounded approximation: the boosted budget's spill past
            // that objective stays raw. Neutral roles reproduce the old call.
            let firstLiveKind = layout.firstLiveObjectiveID(
                for: siegeProgress.selectedLane,
                maxPowers: maxPowers,
                damageByObjectiveID: damageByObjectiveID
            ).flatMap { layout.objective(id: $0)?.kind }
            let budget = spawn.soldierType.roleAdjustedDamage(
                power: leftover,
                against: firstLiveKind
            )

            let (spentDamage, appliedByObjectiveID) = layout.spendDamageBudget(
                budget,
                along: siegeProgress.selectedLane,
                maxPowers: maxPowers,
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

    /// HPA-582: a successful camp upgrade may have raised the derived
    /// Captain max HP — a build cannot (new buildings are always level 1,
    /// so only `upgradeBuilding` calls this) — hand a LIVING Captain the
    /// max delta (clamped to the new
    /// max) so damage taken — not absolute HP — survives the purchase. A down
    /// Captain waits for the recovery flow; reads/decodes/reconstruction never
    /// call this, so repeated scene reconstruction never re-awards the delta.
    private mutating func preserveLivingCaptainHPThroughCampGrowth(previousMaxHP: Int) {
        let newMaxHP = VanguardCaptainRules.maxHP(for: captainLevel)
        let delta = newMaxHP - previousMaxHP
        guard delta > 0,
              var captain = siegeProgress.captain,
              captain.remainingHP > 0 else {
            return
        }
        captain.remainingHP = min(captain.remainingHP + delta, newMaxHP)
        siegeProgress.captain = captain
    }

    // 1.85 (was 2.15, HPA-582 Task 4): keep late-campaign sieges inside the
    // 900 s smoke bound with margin — HP growth must track the 1.45 gold-reward
    // curve or elapsed time diverges geometrically (City 14/15 stalls at 2.15;
    // 1.95 left City 15 at 859/900 s).
    static func cityMaxPower(for level: Int) -> Int {
        roundedAtLeastOne(20 * pow(1.85, Double(clampedLevel(level) - 1)))
    }

    /// The pre-HPA-582 `cityMaxPower` curve (growth 2.15), kept only to
    /// rescale in-progress siege damage persisted by builds that still
    /// encoded `normalSoldierUpgradeLevel` — see the decode tombstone and
    /// `rescaledPersistedSiegeDamage`. Never used for live balance.
    private static func legacyCityMaxPower(for level: Int) -> Int {
        roundedAtLeastOne(20 * pow(2.15, Double(clampedLevel(level) - 1)))
    }

    /// The zero-Treasury base curve (HPA-670 rename from `goldReward`).
    /// Player-facing quotes must use `goldReward(forCity:)` instead.
    static func baseGoldReward(for level: Int) -> Int {
        roundedAtLeastOne(8 * pow(1.45, Double(clampedLevel(level) - 1)))
    }

    static func normalSoldierAttackPower(for level: Int) -> Int {
        max(1, Int(ceil(pow(1.38, Double(clampedLevel(level) - 1)))))
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

    /// Per-objective HP maxima for the current city's authored layout,
    /// split from `cityMaxPower` by durability weight. Rebuilt on read —
    /// callers inside hot loops should hoist it (see
    /// `applyAbstractBuildingSpawnDamage`).
    var currentSiegeMaxPowers: [String: Int] {
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

    /// The zero-Treasury base price curves (HPA-670 rename from
    /// `buildingBuildCost`/`buildingUpgradeCost`). Quoting and charging must
    /// go through the state-aware `buildingBuildCost`/`buildingUpgradeCost`
    /// instance methods instead.
    static func baseBuildingBuildCost(for type: BuildingType) -> Int {
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

    static func baseBuildingUpgradeCost(for type: BuildingType, currentLevel: Int) -> Int {
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

    /// The only quoted/charged camp prices (HPA-670): base × Quartermaster
    /// discount (1 − 0.04 × quartermasterLevel), rounded once, min 1. Camp
    /// display, affordability, the recommendation, the balance-harness buyer
    /// and the actual debit all consume these — no other multiplication site
    /// exists.
    func buildingBuildCost(for type: BuildingType) -> Int {
        Self.roundedAtLeastOne(Double(Self.baseBuildingBuildCost(for: type)) * quartermasterPriceFactor)
    }

    func buildingUpgradeCost(for type: BuildingType, currentLevel: Int) -> Int {
        Self.roundedAtLeastOne(
            Double(Self.baseBuildingUpgradeCost(for: type, currentLevel: currentLevel)) * quartermasterPriceFactor
        )
    }

    private var quartermasterPriceFactor: Double {
        1.0 - 0.04 * Double(treasury.quartermaster)
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

    /// The shared live/abstract attack seam with the Drill Yard multiplier
    /// folded into the single round (HPA-670): the default `upgradeMultiplier`
    /// of 1 reproduces the pre-Treasury result exactly. Never round this
    /// result again downstream — the separate role-multiplier hit round is
    /// the only permitted second rounding.
    static func traitAdjustedSoldierAttackPower(
        for soldierType: SoldierType,
        level: Int,
        defenseTrait: CityDefenseTrait,
        upgradeMultiplier: Double = 1
    ) -> Int {
        let baseDamage = soldierAttackPower(for: soldierType, level: level)
        guard baseDamage > 0 else { return 0 }

        // One round for trait × upgrade together: an intermediate round loses
        // damage (9 × 0.80 × 1.05 rounds to 8 once, to 7 if rounded twice).
        let adjustedDamage = Int(
            (Double(baseDamage) * defenseTrait.damageMultiplier(for: soldierType) * upgradeMultiplier).rounded()
        )
        return max(1, adjustedDamage)
    }

    func traitAdjustedSoldierAttackPower(for soldierType: SoldierType, level: Int) -> Int {
        Self.traitAdjustedSoldierAttackPower(
            for: soldierType,
            level: level,
            defenseTrait: currentCityDefenseTrait,
            upgradeMultiplier: 1.0 + 0.05 * Double(treasury.drillYard)
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
        // Non-active stages never carry a Captain — the same rule
        // `normalizedCaptainProgress` enforces on init/decode holds after a
        // live conquest too.
        siegeProgress.captain = nil
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
