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
        /// Concise tactical objective summary for cities whose authored siege
        /// layout has support objectives (HPA-468 pilot), e.g.
        /// `L Tower · C/R Gate` for Falconridge. `nil` for single-Keep cities;
        /// the node then renders `Open: <exposed lane>`.
        let tacticalFooter: String?
        let status: CountryMapScoutStatus

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
            tacticalFooter: String? = nil,
            status: CountryMapScoutStatus = .attackable
        ) {
            self.cityNumber = cityNumber
            self.displayTitle = displayTitle
            self.defenseTrait = defenseTrait
            self.exposedLane = exposedLane
            self.goldReward = goldReward
            self.flavorText = flavorText
            self.tacticalFooter = tacticalFooter
            self.status = status
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
                tacticalFooter: tacticalFooter(for: definition.siegeLayout),
                status: status
            )
        )
    }

    /// Derives the concise tactical footer from an authored siege layout:
    /// one entry per support objective, lanes joined `/` and kinds abbreviated
    /// (`L Tower · C/R Gate` for Falconridge). Single-Keep layouts have no
    /// support objectives and derive `nil`. Route membership (each lane's
    /// authored route containing the objective's stable ID) is the single
    /// source for lane letters, so the footer always matches the routes
    /// combat and the Battle scene render from.
    static func tacticalFooter(for layout: CitySiegeLayout) -> String? {
        let supportObjectives = layout.objectives.filter { $0.kind != .keep }
        guard !supportObjectives.isEmpty else { return nil }
        return supportObjectives.map { objective -> String in
            let lanes = BattleLane.allCases.filter { lane in
                layout.routes[lane]?.contains(objective.id) == true
            }
            let laneLetters = lanes.map(\.tacticalLetter).joined(separator: "/")
            return "\(laneLetters) \(objective.kind.tacticalName)"
        }
        .joined(separator: " · ")
    }
}

private extension BattleLane {
    var tacticalLetter: String {
        switch self {
        case .left: return "L"
        case .center: return "C"
        case .right: return "R"
        }
    }
}

private extension CitySiegeLayout.ObjectiveKind {
    var tacticalName: String {
        switch self {
        case .keep: return "Keep"
        case .gate: return "Gate"
        case .arrowTower: return "Tower"
        }
    }
}
