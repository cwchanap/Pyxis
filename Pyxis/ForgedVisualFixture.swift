#if DEBUG
import Foundation

enum ForgedVisualFixture: String, CaseIterable, Equatable {
    case battle
    case battleBlocked = "battle-blocked"
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

    static let launchArgument = "-pyxis-forged-fixture"

    var preferredTab: GameplayTab {
        switch self {
        case .campEmpty, .campOccupied:
            return .camp
        case .map, .mapPartial, .mapCountryComplete:
            return .map
        case .battle, .battleBlocked, .conquestLive, .conquestIdle,
             .battleDamaged, .battleBreached, .battleEmberford, .battleRunewatch,
             .battleCrownspire, .returnDamage:
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
        case .battle, .battleBlocked:
            return Self.battleState()
        case .battleDamaged, .battleBreached:
            // City 1 max HP = 20: 12 is the damaged threshold, 5 the breached one.
            return Self.battleState(
                cityNumber: 1,
                remainingPower: self == .battleBreached ? 5 : 12
            )
        case .battleEmberford:
            return DevJumpState.make(city: 7)
        case .battleRunewatch:
            return DevJumpState.make(city: 9)
        case .battleCrownspire:
            return DevJumpState.make(city: 15)
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

    private static func battleState(
        cityNumber: Int = 3,
        remainingPower: Int? = nil
    ) -> KingdomGameState {
        var state = DevJumpState.make(city: cityNumber)
        state.gold = 4_200
        state.cityRemainingPower = remainingPower ?? state.cityMaxPower
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
            state.cityRemainingPower = 1
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
