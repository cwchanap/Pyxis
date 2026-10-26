#if DEBUG
enum DevJumpState {
    static let gold = 1_000_000
    /// Camp level seeded into the jumped city so the Captain derives a
    /// strong level from a real building instead of a faked soldier upgrade.
    static let campLevel = 5

    static func make(city: Int) -> KingdomGameState {
        precondition(
            (1...KingdomGameState.firstCountryCityCount).contains(city),
            "DevJumpState supports Country 1 cities only"
        )

        return KingdomGameState(
            gold: gold,
            countryNumber: 1,
            completedCityCount: city - 1,
            stageStatus: .battleActive,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks, level: campLevel)]
                )
            ]
        )
    }
}
#endif
