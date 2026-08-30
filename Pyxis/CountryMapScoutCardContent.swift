//
//  CountryMapScoutCardContent.swift
//  Pyxis
//

enum CountryMapScoutStatus: Equatable {
    case attackable
    case current
    case completed
    case locked
}

enum CountryMapScoutCardContent: Equatable {
    struct Scout: Equatable {
        let cityNumber: Int
        let displayTitle: String
        let defenseTrait: CityDefenseTrait
        let exposedLane: BattleLane
        let goldReward: Int
        let flavorText: String
        let status: CountryMapScoutStatus

        var state: CountryMapScoutStatus {
            status
        }

        var actionTitle: String? {
            switch status {
            case .attackable:
                return "MARCH"
            case .current:
                return "RETURN"
            case .completed, .locked:
                return nil
            }
        }

        init(
            cityNumber: Int,
            displayTitle: String,
            defenseTrait: CityDefenseTrait,
            exposedLane: BattleLane,
            goldReward: Int,
            flavorText: String,
            status: CountryMapScoutStatus = .attackable
        ) {
            self.cityNumber = cityNumber
            self.displayTitle = displayTitle
            self.defenseTrait = defenseTrait
            self.exposedLane = exposedLane
            self.goldReward = goldReward
            self.flavorText = flavorText
            self.status = status
        }

        init(
            cityNumber: Int,
            displayTitle: String,
            defenseTrait: CityDefenseTrait,
            exposedLane: BattleLane,
            goldReward: Int,
            flavorText: String,
            state: CountryMapScoutStatus
        ) {
            self.init(
                cityNumber: cityNumber,
                displayTitle: displayTitle,
                defenseTrait: defenseTrait,
                exposedLane: exposedLane,
                goldReward: goldReward,
                flavorText: flavorText,
                status: state
            )
        }
    }

    case scout(Scout)
    case countryComplete(countryNumber: Int, finalCityName: String)

    static func project(
        from state: KingdomGameState,
        selectedCityNumber: Int? = nil
    ) -> Self {
        let finalCityName = Country1CityCatalog.definition(for: 15).name
        guard state.stageStatus != .countryComplete else {
            return .countryComplete(
                countryNumber: state.countryNumber,
                finalCityName: finalCityName
            )
        }

        let cityNumber = selectedCityNumber
            ?? state.unlockedMapCityNumber
            ?? state.cityNumberInCountry
        guard Country1CityCatalog.cityRange.contains(cityNumber) else {
            assertionFailure("An incomplete normalized map must have one unlocked city")
            return .countryComplete(
                countryNumber: state.countryNumber,
                finalCityName: finalCityName
            )
        }

        let definition = Country1CityCatalog.definition(for: cityNumber)
        let status: CountryMapScoutStatus
        if state.stageStatus == .battleActive && cityNumber == state.cityNumberInCountry {
            status = .current
        } else {
            switch state.mapStatus(for: cityNumber) {
            case .completed:
                status = .completed
            case .unlocked:
                status = .attackable
            case .locked:
                status = .locked
            }
        }
        return .scout(
            Scout(
                cityNumber: cityNumber,
                displayTitle: definition.displayTitle,
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: cityNumber),
                flavorText: definition.flavorText,
                status: status
            )
        )
    }
}
