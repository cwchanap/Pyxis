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
            #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)
            #expect(state.gold == DevJumpState.gold)
            #expect(state.normalSoldierUpgradeLevel == DevJumpState.soldierLevel)
            #expect(state.cityBattleStates.isEmpty)
            #expect(state.activeSiegeSession == nil)
            #expect(state.pendingBattleResult == nil)
            #expect(state.lastBackgroundedAt == nil)
        }
    }

    @Test("Fresh City 5 jump materializes normalized Guard progress with no special-casing")
    func highcrestJumpMaterializesNormalizedGuardProgress() throws {
        let state = DevJumpState.make(city: 5)
        let layout = state.currentSiegeLayout

        // Plain state materialization through the standard init
        // normalization: fresh full-reserve Highcrest progress, living
        // Barracks and Keep, no checkpoint or migration residue.
        #expect(state.siegeProgress.guardReinforcements == GuardReinforcementProgress.freshHighcrest())
        #expect(state.siegeProgress.guardReinforcements == GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: HighcrestGuardRules.totalReserve,
            unresolvedGuards: []
        ))
        #expect(state.siegeProgress.selectedLane == layout.defaultLane)
        #expect(state.siegeProgress.damageByObjectiveID.isEmpty)
        let barracksID = try #require(SiegeTestSupport.objectiveID(for: .barracks, in: state))
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        #expect(state.currentSiegeSnapshot.objectiveRemainingPower[barracksID]
            == maxPowers[barracksID])
        #expect(state.currentKeepRemainingPower == state.currentKeepMaxPower)

        // Repeated jumps are deterministic (no hidden migration state).
        #expect(DevJumpState.make(city: 5) == state)
    }

    @Test("Non-pilot city jumps carry no Guard state")
    func nonPilotCityJumpCarriesNoGuardState() {
        let state = DevJumpState.make(city: 1)

        #expect(state.siegeProgress.guardReinforcements == nil)
    }
}
#endif
