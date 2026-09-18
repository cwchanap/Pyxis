//
//  CityDefinition.swift
//  Pyxis
//

enum CityVisualFamily: String, CaseIterable, Equatable {
    case frontier
    case ember
    case arcane
    case royal
}

struct CityDefinition: Equatable {
    let cityNumber: Int
    let name: String
    let flavorText: String
    let conquestTitle: String
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile
    let visualFamily: CityVisualFamily
    /// Authored fail-closed siege layout. Defaults to the standard
    /// single-Keep shape on the profile's standard lane; tactical pilot
    /// cities author a custom layout (Falconridge's tower/gate split,
    /// Highcrest's Guard barracks).
    let siegeLayout: CitySiegeLayout

    var displayTitle: String {
        "City \(cityNumber) · \(name)"
    }

    init(
        cityNumber: Int,
        name: String,
        flavorText: String,
        conquestTitle: String,
        defenseTrait: CityDefenseTrait,
        laneDefenseProfile: LaneDefenseProfile,
        visualFamily: CityVisualFamily,
        siegeLayout: CitySiegeLayout? = nil
    ) {
        self.cityNumber = cityNumber
        self.name = name
        self.flavorText = flavorText
        self.conquestTitle = conquestTitle
        self.defenseTrait = defenseTrait
        self.laneDefenseProfile = laneDefenseProfile
        self.visualFamily = visualFamily
        self.siegeLayout = siegeLayout ?? .singleKeep(defaultLane: laneDefenseProfile.standardLane)
    }
}
