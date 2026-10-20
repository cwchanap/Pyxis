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
    /// Authored fail-closed siege layout, required at construction. Every
    /// Country 1 city authors its own layout in `Country1CityCatalog` (HPA-477),
    /// so no city falls back to a single-Keep shape. `CitySiegeLayout.singleKeep`
    /// remains a fixture for isolated model tests only.
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
        siegeLayout: CitySiegeLayout
    ) {
        self.cityNumber = cityNumber
        self.name = name
        self.flavorText = flavorText
        self.conquestTitle = conquestTitle
        self.defenseTrait = defenseTrait
        self.laneDefenseProfile = laneDefenseProfile
        self.visualFamily = visualFamily
        self.siegeLayout = siegeLayout
    }
}
