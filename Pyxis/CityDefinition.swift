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

    var displayTitle: String {
        "City \(cityNumber) · \(name)"
    }
}
