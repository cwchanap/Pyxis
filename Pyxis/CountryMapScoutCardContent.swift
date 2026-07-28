//
//  CountryMapScoutCardContent.swift
//  Pyxis
//

enum CountryMapScoutCardContent: Equatable {
    struct Scout: Equatable {
        let cityNumber: Int
        let displayTitle: String
        let defenseTrait: CityDefenseTrait
        let exposedLane: BattleLane
        let goldReward: Int
    }

    case scout(Scout)
    case countryComplete(countryNumber: Int)

    static func project(from state: KingdomGameState) -> Self {
        guard state.stageStatus != .countryComplete else {
            return .countryComplete(countryNumber: state.countryNumber)
        }

        guard let cityNumber = state.unlockedMapCityNumber else {
            assertionFailure("An incomplete normalized map must have one unlocked city")
            return .countryComplete(countryNumber: state.countryNumber)
        }

        let definition = Country1CityCatalog.definition(for: cityNumber)
        return .scout(
            Scout(
                cityNumber: cityNumber,
                displayTitle: state.displayCityTitle(for: cityNumber),
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: cityNumber)
            )
        )
    }
}
