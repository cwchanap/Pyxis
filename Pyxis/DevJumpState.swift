#if DEBUG
enum DevJumpState {
    static let gold = 1_000_000
    static let soldierLevel = 15

    static func make(city: Int) -> KingdomGameState {
        precondition(
            (1...KingdomGameState.firstCountryCityCount).contains(city),
            "DevJumpState supports Country 1 cities only"
        )

        return KingdomGameState(
            gold: gold,
            normalSoldierUpgradeLevel: soldierLevel,
            countryNumber: 1,
            completedCityCount: city - 1,
            stageStatus: .battleActive,
            cityBattleStates: [:]
        )
    }
}
#endif
