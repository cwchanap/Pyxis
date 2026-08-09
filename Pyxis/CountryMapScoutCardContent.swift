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
        let flavorText: String
    }

    case scout(Scout)
    case countryComplete(countryNumber: Int, finalCityName: String)

    static func project(from state: KingdomGameState) -> Self {
        let finalCityName = Country1CityCatalog.definition(for: 15).name
        guard state.stageStatus != .countryComplete else {
            return .countryComplete(
                countryNumber: state.countryNumber,
                finalCityName: finalCityName
            )
        }

        guard let cityNumber = state.unlockedMapCityNumber else {
            assertionFailure("An incomplete normalized map must have one unlocked city")
            return .countryComplete(
                countryNumber: state.countryNumber,
                finalCityName: finalCityName
            )
        }

        let definition = Country1CityCatalog.definition(for: cityNumber)
        return .scout(
            Scout(
                cityNumber: cityNumber,
                displayTitle: definition.displayTitle,
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: cityNumber),
                flavorText: definition.flavorText
            )
        )
    }
}
