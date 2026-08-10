import Testing
@testable import Pyxis

struct Country1MilestoneTierTests {
    @Test("Country 1 milestone cities select the three tiers")
    func selectsMilestoneCities() {
        #expect(Country1MilestoneTier.forCity(5) == .first)
        #expect(Country1MilestoneTier.forCity(10) == .second)
        #expect(
            Country1MilestoneTier.forCity(KingdomGameState.firstCountryCityCount)
                == .finale
        )
    }

    @Test("Ordinary cities are not milestones")
    func ordinaryCitiesReturnNil() {
        for city in [1, 4, 6, 9, 11, 14] {
            #expect(Country1MilestoneTier.forCity(city) == nil)
        }
    }

    @Test("Only finale marks country completion")
    func onlyFinaleMarksCountryCompletion() {
        #expect(Country1MilestoneTier.first.isCountryFinale == false)
        #expect(Country1MilestoneTier.second.isCountryFinale == false)
        #expect(Country1MilestoneTier.finale.isCountryFinale)
    }
}
