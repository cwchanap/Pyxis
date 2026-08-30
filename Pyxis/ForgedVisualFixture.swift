#if DEBUG
enum ForgedVisualFixture: String, CaseIterable, Equatable {
    case battle
    case battleBlocked = "battle-blocked"
    case campEmpty = "camp-empty"
    case campOccupied = "camp-occupied"
    case map
    case mapCountryComplete = "map-country-complete"
    case conquestLive = "conquest-live"
    case conquestIdle = "conquest-idle"

    static let launchArgument = "-pyxis-forged-fixture"

    var preferredTab: GameplayTab {
        switch self {
        case .campEmpty, .campOccupied:
            return .camp
        case .map, .mapCountryComplete:
            return .map
        case .battle, .battleBlocked, .conquestLive, .conquestIdle:
            return .battle
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
        case .campEmpty:
            var state = DevJumpState.make(city: 5)
            state.gold = 1_000
            return state
        case .campOccupied:
            var state = DevJumpState.make(city: 5)
            state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
                1: CityBuilding(type: .barracks, level: 2),
                3: CityBuilding(type: .barracks),
                6: CityBuilding(type: .archeryRange, level: 2),
                8: CityBuilding(type: .barracks),
                11: CityBuilding(type: .archeryRange),
                12: CityBuilding(type: .barracks, level: 3)
            ])
            return state
        case .map:
            var state = DevJumpState.make(city: 3)
            state.completedCityCount = 3
            state.stageStatus = .cityConqueredPendingMap
            return state
        case .mapCountryComplete:
            var state = DevJumpState.make(city: KingdomGameState.firstCountryCityCount)
            state.completedCityCount = KingdomGameState.firstCountryCityCount
            state.stageStatus = .countryComplete
            return state
        case .conquestLive:
            return Self.conquestState(mode: .live)
        case .conquestIdle:
            return Self.conquestState(mode: .idle)
        }
    }

    private static func battleState() -> KingdomGameState {
        var state = DevJumpState.make(city: 3)
        state.gold = 4_200
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 2),
            2: CityBuilding(type: .archeryRange)
        ])
        return state
    }

    private static func conquestState(mode: BattleConquestMode) -> KingdomGameState {
        var state = DevJumpState.make(city: 3)
        state.stageStatus = .cityConqueredPendingMap
        state.pendingBattleResult = BattleResult(
            cityKey: state.currentCityKey,
            conquestMode: mode,
            activeBattleSeconds: 74,
            deployments: mode == .live
                ? [SiegeDeploymentCount(
                    type: .infantry,
                    source: .manual,
                    lane: .center,
                    count: 6
                )]
                : [],
            appliedDamage: mode == .live
                ? [SiegeDamageAttribution(
                    type: .infantry,
                    source: .manual,
                    lane: .center,
                    damage: 640
                )]
                : [],
            losses: mode == .live
                ? [SiegeLossCount(type: .infantry, source: .manual, count: 1)]
                : [],
            idleDamageByType: [],
            mvpSoldierType: mode == .live ? .infantry : nil,
            mvpDamageSharePercent: mode == .live ? 100 : nil,
            usedFavorableUnit: mode == .live,
            usedExposedLane: mode == .live,
            goldEarned: 640
        )
        return state
    }
}
#endif
