#if DEBUG
enum DevJumpState {
    static let gold = 1_000_000
    /// Camp level the interactive five-tap jump seeds into the jumped city
    /// so the Captain derives a strong level from a real building instead
    /// of a faked soldier upgrade. Not a default: every `make` caller names
    /// its own level — or nil for an empty camp — so capture fixtures can
    /// never silently inherit level-5 spawns or a level-5 Captain.
    static let campLevel = 5

    static func make(city: Int, campLevel: Int?) -> KingdomGameState {
        precondition(
            (1...KingdomGameState.firstCountryCityCount).contains(city),
            "DevJumpState supports Country 1 cities only"
        )

        let slots: [Int: CityBuilding] = campLevel.map {
            [1: CityBuilding(type: .barracks, level: $0)]
        } ?? [:]
        return KingdomGameState(
            gold: gold,
            countryNumber: 1,
            completedCityCount: city - 1,
            stageStatus: .battleActive,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey: CityBattleState(slots: slots)
            ]
        )
    }
}
#endif
