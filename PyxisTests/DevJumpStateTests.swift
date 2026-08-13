import Testing
@testable import Pyxis

#if DEBUG
struct DevJumpStateTests {
    @Test("Every Country 1 dev jump creates a fresh active battle")
    func everyCountry1CityCreatesFreshActiveBattle() {
        for city in 1...KingdomGameState.firstCountryCityCount {
            let state = DevJumpState.make(city: city)

            #expect(state.countryNumber == 1)
            #expect(state.completedCityCount == city - 1)
            #expect(state.cityNumberInCountry == city)
            #expect(state.cityLevel == city)
            #expect(state.stageStatus == .battleActive)
            #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: city))
            #expect(state.gold == DevJumpState.gold)
            #expect(state.normalSoldierUpgradeLevel == DevJumpState.soldierLevel)
            #expect(state.cityBattleStates.isEmpty)
            #expect(state.activeSiegeSession == nil)
            #expect(state.pendingBattleResult == nil)
            #expect(state.lastBackgroundedAt == nil)
        }
    }
}
#endif
