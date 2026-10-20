#if DEBUG
import Foundation

enum ForgedVisualFixture: String, CaseIterable, Equatable {
    case battle
    case battleBlocked = "battle-blocked"
    case battleFalconridgeRuined = "battle-falconridge-ruined"
    case battleCaptainDeployed = "battle-captain-deployed"
    case battleRallyActive = "battle-rally-active"
    case battleGuardAnimation = "battle-guard-animation"
    case campEmpty = "camp-empty"
    case campOccupied = "camp-occupied"
    case map
    case mapPartial = "map-partial"
    case mapCountryComplete = "map-country-complete"
    case conquestLive = "conquest-live"
    case conquestIdle = "conquest-idle"
    case battleDamaged = "battle-damaged"
    case battleBreached = "battle-breached"
    case battleEmberford = "battle-emberford"
    case battleRunewatch = "battle-runewatch"
    case battleCrownspire = "battle-crownspire"
    case returnDamage = "return-damage"
    case battleHighcrestWave = "battle-highcrest-wave"
    case battleHighcrestGuardDamaged = "battle-highcrest-guard-damaged"
    case battleHighcrestShutdown = "battle-highcrest-shutdown"
    case battleHighcrestFinal = "battle-highcrest-final"
    case battleCrownspireRuined = "battle-crownspire-ruined"
    case battleEmberfordGuards = "battle-emberford-guards"
    case battlePinewatch = "battle-pinewatch"

    static let launchArgument = "-pyxis-forged-fixture"

    var preferredTab: GameplayTab {
        switch self {
        case .campEmpty, .campOccupied:
            return .camp
        case .map, .mapPartial, .mapCountryComplete:
            return .map
        case .battle, .battleBlocked, .battleFalconridgeRuined,
             .battleCaptainDeployed, .battleRallyActive, .battleGuardAnimation, .conquestLive, .conquestIdle,
             .battleDamaged, .battleBreached, .battleEmberford, .battleRunewatch,
             .battleCrownspire, .returnDamage,
             .battleHighcrestWave, .battleHighcrestGuardDamaged,
             .battleHighcrestShutdown, .battleHighcrestFinal,
             .battleCrownspireRuined, .battleEmberfordGuards, .battlePinewatch:
            return .battle
        }
    }

    /// Fixed foreground timestamp for the return-damage fixture so the idle
    /// settlement result is deterministic across launches and captures.
    var foregroundReturnDate: Date? {
        switch self {
        case .returnDamage:
            return Date(timeIntervalSince1970: 4_600)
        default:
            return nil
        }
    }

    init?(launchArguments: [String]) {
        guard let markerIndex = launchArguments.firstIndex(of: Self.launchArgument),
              markerIndex + 1 < launchArguments.count else {
            return nil
        }
        self.init(rawValue: launchArguments[markerIndex + 1])
    }

    func makeState() -> KingdomGameState {
        switch self {
        case .battle, .battleBlocked, .battleFalconridgeRuined:
            return Self.battleState(supportDamage: self == .battleFalconridgeRuined
                ? [.gate: Int.max, .arrowTower: Int.max] : [:])
        case .battleDamaged, .battleBreached:
            // City 1 Keep max = 15 (3:1 Keep share of the 20 budget; the Gate holds 5).
            // Stage bands are fractions of that max: damaged 4...9, breached 1...3.
            return Self.battleState(
                cityNumber: 1,
                keepRemaining: self == .battleBreached ? 2 : 7
            )
        case .battleEmberford, .battleEmberfordGuards, .battlePinewatch,
             .battleRunewatch, .battleCrownspire, .battleCrownspireRuined:
            return Self.cityBattleState(for: self)
        case .battleHighcrestWave, .battleHighcrestGuardDamaged,
             .battleHighcrestShutdown, .battleHighcrestFinal,
             .battleCaptainDeployed, .battleRallyActive, .battleGuardAnimation:
            return Self.highcrestGuardFixtureState(for: self)
        case .returnDamage:
            return Self.returnDamageState()
        case .campEmpty, .campOccupied:
            return Self.campState(occupied: self == .campOccupied)
        case .map, .mapPartial, .mapCountryComplete:
            return Self.mapFixtureState(for: self)
        case .conquestLive, .conquestIdle:
            return Self.conquestState(mode: self == .conquestLive ? .live : .idle)
        }
    }

    /// Highcrest (City 5) Guard-pilot capture states (HPA-469): intact Keep,
    /// durable Guards on the Barracks lane, optional Barracks shutdown damage.
    private static func highcrestGuardFixtureState(for fixture: ForgedVisualFixture) -> KingdomGameState {
        switch fixture {
        case .battleHighcrestWave, .battleCaptainDeployed, .battleRallyActive, .battleGuardAnimation:
            var state = highcrestGuardState(
                guards: [
                    GuardSnapshot(lane: .left, remainingHP: 12),
                    GuardSnapshot(lane: .left, remainingHP: 12)
                ],
                reserve: 6
            )
            if fixture == .battleRallyActive, let captain = state.siegeProgress.captain {
                state.siegeProgress.selectedLane = captain.lane
            }
            return state
        case .battleHighcrestGuardDamaged:
            return highcrestGuardState(
                guards: [
                    GuardSnapshot(lane: .left, remainingHP: 12),
                    GuardSnapshot(lane: .left, remainingHP: 5)
                ],
                reserve: 6
            )
        case .battleHighcrestShutdown:
            return highcrestGuardState(
                guards: [GuardSnapshot(lane: .left, remainingHP: 7)],
                reserve: 6,
                supportDamage: [.barracks: Int.max]
            )
        case .battleHighcrestFinal:
            return highcrestGuardState(
                guards: (1...8).map { GuardSnapshot(lane: .left, remainingHP: 13 - $0) },
                reserve: 0
            )
        default:
            preconditionFailure("Non-Highcrest fixture routed to the Guard-pilot mapper: \(fixture)")
        }
    }

    /// Highcrest (City 5) Guard-pilot capture-state builder: intact Keep,
    /// durable Guards on the Barracks lane, optional Barracks shutdown damage.
    private static func highcrestGuardState(
        guards: [GuardSnapshot],
        reserve: Int,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:]
    ) -> KingdomGameState {
        var state = DevJumpState.make(city: 5)
        seedSiegeProgress(
            keepRemaining: KingdomGameState.cityMaxPower(for: 5),
            supportDamage: supportDamage,
            on: &state
        )
        state.siegeProgress.selectedLane = .left
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: reserve,
            unresolvedGuards: guards
        )
        return state
    }

    private static func campState(occupied: Bool) -> KingdomGameState {
        var state = DevJumpState.make(city: 5)
        if occupied {
            state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
                1: CityBuilding(type: .barracks, level: 2),
                3: CityBuilding(type: .barracks),
                6: CityBuilding(type: .archeryRange, level: 2),
                8: CityBuilding(type: .barracks),
                11: CityBuilding(type: .archeryRange),
                12: CityBuilding(type: .barracks, level: 3)
            ])
        } else {
            state.gold = 1_000
        }
        return state
    }

    private static func mapFixtureState(for fixture: ForgedVisualFixture) -> KingdomGameState {
        switch fixture {
        case .map:
            var state = DevJumpState.make(city: 3)
            state.completedCityCount = 3
            state.stageStatus = .cityConqueredPendingMap
            return state
        case .mapPartial:
            var state = DevJumpState.make(city: 8)
            state.stageStatus = .cityConqueredPendingMap
            return state
        case .mapCountryComplete:
            var state = DevJumpState.make(city: KingdomGameState.firstCountryCityCount)
            state.completedCityCount = KingdomGameState.firstCountryCityCount
            state.stageStatus = .countryComplete
            return state
        default:
            preconditionFailure("mapFixtureState supports map fixtures only")
        }
    }

    /// City 15 ruin capture (five-structure layout): both Gates, the Arrow Tower
    /// (the sole fire source) and the Barracks are destroyed; the Keep is at 60% HP.
    private static func crownspireRuinedState() -> KingdomGameState {
        var state = DevJumpState.make(city: 15)
        seedSiegeProgress(
            keepRemaining: state.currentKeepMaxPower * 3 / 5,
            supportDamage: [.gate: Int.max, .arrowTower: Int.max, .barracks: Int.max],
            on: &state
        )
        return state
    }

    /// Country 1 city-jump battle captures: intact cities come from `DevJumpState`,
    /// plus the Emberford Guard and Crownspire ruin variants.
    private static func cityBattleState(for fixture: ForgedVisualFixture) -> KingdomGameState {
        switch fixture {
        case .battleEmberford:
            return DevJumpState.make(city: 7)
        case .battleEmberfordGuards:
            return emberfordGuardState()
        case .battlePinewatch:
            return DevJumpState.make(city: 2)
        case .battleRunewatch:
            return DevJumpState.make(city: 9)
        case .battleCrownspire:
            return DevJumpState.make(city: 15)
        case .battleCrownspireRuined:
            return crownspireRuinedState()
        default:
            preconditionFailure("Non-city fixture routed to the city-jump mapper: \(fixture)")
        }
    }

    /// City 7 Guard capture: two full-HP Guards on the Barracks (left) lane with
    /// 6 of the 12-Guard reserve left (4 spent); the Barracks and Keep are intact.
    private static func emberfordGuardState() -> KingdomGameState {
        var state = DevJumpState.make(city: 7)
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: 6,
            unresolvedGuards: [
                GuardSnapshot(lane: .left, remainingHP: 12),
                GuardSnapshot(lane: .left, remainingHP: 12)
            ]
        )
        return state
    }

    private static func returnDamageState() -> KingdomGameState {
        var state = DevJumpState.make(city: 3)
        let backgroundAt = Date(timeIntervalSince1970: 1_000)
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: backgroundAt
        )
        state.markCurrentCityBuildingProgressInactive(at: backgroundAt)
        return state
    }

    /// Seeds current-city siege progress with the SiegeTestSupport pattern
    /// (HPA-468): Keep HP is the sole conquest/liveness authority and damage
    /// clamps to each objective's authored maximum. A kind's damage applies to
    /// every objective of that kind (City 15 authors two Gates).
    private static func seedSiegeProgress(
        keepRemaining: Int,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:],
        on state: inout KingdomGameState
    ) {
        let layout = state.currentCityDefinition.siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        func clamp(_ raw: Int, toMax maxPower: Int) -> Int {
            min(max(0, raw), maxPower)
        }

        let keepID = layout.keepObjective.id
        let keepMax = maxPowers[keepID, default: 0]
        let keepDamage = clamp(keepMax - keepRemaining, toMax: keepMax)
        if keepDamage > 0 {
            state.siegeProgress.damageByObjectiveID[keepID] = keepDamage
        } else {
            state.siegeProgress.damageByObjectiveID.removeValue(forKey: keepID)
        }
        for (kind, damage) in supportDamage {
            for objective in layout.objectives where objective.kind == kind {
                let clamped = clamp(damage, toMax: maxPowers[objective.id, default: 0])
                if clamped > 0 {
                    state.siegeProgress.damageByObjectiveID[objective.id] = clamped
                }
            }
        }
    }

    private static func battleState(
        cityNumber: Int = 3,
        keepRemaining: Int? = nil,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:]
    ) -> KingdomGameState {
        var state = DevJumpState.make(city: cityNumber)
        state.gold = 4_200
        if keepRemaining != nil || !supportDamage.isEmpty {
            seedSiegeProgress(
                keepRemaining: keepRemaining ?? state.currentKeepRemainingPower,
                supportDamage: supportDamage,
                on: &state
            )
        }
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 2),
            2: CityBuilding(type: .archeryRange)
        ])
        return state
    }

    private static func conquestState(mode: BattleConquestMode) -> KingdomGameState {
        var state = DevJumpState.make(city: 3)

        guard mode == .live else {
            let backgroundAt = Date(timeIntervalSince1970: 1_000)
            let cityKey = state.currentCityKey
            // Nearly-dead City 3 for the pilot layout: the Ridge Gate is
            // already destroyed so the idle budget lands on the Keep at 1 HP
            // and the single seeded spawn conquers (idle attribution = 1).
            seedSiegeProgress(
                keepRemaining: 1,
                supportDamage: [.gate: Int.max],
                on: &state
            )
            state.cityBattleStates[cityKey.storageKey] = CityBattleState(
                slots: [
                    1: CityBuilding(type: .barracks),
                    2: CityBuilding(type: .barracks)
                ],
                lastBuildingProgressResolvedAt: backgroundAt
            )
            state.markCurrentCityBuildingProgressInactive(at: backgroundAt)
            _ = state.returnFromBackground(
                at: backgroundAt.addingTimeInterval(30_000)
            )
            return state
        }

        state.stageStatus = .cityConqueredPendingMap
        state.pendingBattleResult = BattleResult(
            cityKey: state.currentCityKey,
            conquestMode: .live,
            activeBattleSeconds: 74,
            deployments: [SiegeDeploymentCount(
                type: .infantry,
                source: .manual,
                lane: .center,
                count: 6
            )],
            appliedDamage: [SiegeDamageAttribution(
                type: .infantry,
                source: .manual,
                lane: .center,
                damage: 640
            )],
            losses: [SiegeLossCount(type: .infantry, source: .manual, count: 1)],
            idleDamageByType: [],
            mvpSoldierType: .infantry,
            mvpDamageSharePercent: 100,
            usedFavorableUnit: true,
            usedExposedLane: true,
            goldEarned: 640
        )
        return state
    }
}
#endif
