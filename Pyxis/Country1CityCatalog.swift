//
//  Country1CityCatalog.swift
//  Pyxis
//

enum Country1CityCatalog {
    static let cityRange = 1...15

    /// The authored order is also the lookup index. A duplicated fortified /
    /// exposed lane is a programmer error and fails through
    /// `LaneDefenseProfile`'s invariant precondition during static initialization.
    static let definitions: [CityDefinition] = [
        CityDefinition(
            cityNumber: 1,
            name: "Willowford",
            flavorText: "A quiet crossing where the campaign begins.",
            conquestTitle: "Willowford Secured",
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 2,
            name: "Pinewatch",
            flavorText: "A hill watchtown guarding the old trade road.",
            conquestTitle: "Pinewatch Secured",
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 3,
            name: "Falconridge",
            flavorText: "Arrow towers command the high ridge road.",
            conquestTitle: "Falconridge Silenced",
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 4,
            name: "Bramblegate",
            flavorText: "Iron spikes guard a narrow frontier gate.",
            conquestTitle: "Bramblegate Broken",
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 5,
            name: "Highcrest",
            flavorText: "A proud hill fortress crowns the frontier.",
            conquestTitle: "Highcrest Falls",
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 6,
            name: "Granite Pass",
            flavorText: "Stone walls seal the mountain road ahead.",
            conquestTitle: "Granite Pass Open",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 7,
            name: "Emberford",
            flavorText: "Burning oil guards the bridge inland.",
            conquestTitle: "Emberford Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 8,
            name: "Greywall",
            flavorText: "Layered stone walls protect a busy town.",
            conquestTitle: "Greywall Falls",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 9,
            name: "Runewatch",
            flavorText: "Arcane wards shimmer over the night road.",
            conquestTitle: "Runewatch Unbound",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 10,
            name: "Ironthorn Gate",
            flavorText: "A hardened gate blocks the inner road.",
            conquestTitle: "Ironthorn Gate Broken",
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 11,
            name: "Kingshield Keep",
            flavorText: "A reinforced fortress guards the royal road.",
            conquestTitle: "Kingshield Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 12,
            name: "Ashbridge",
            flavorText: "Fire cauldrons guard the last crossing.",
            conquestTitle: "Ashbridge Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        ),
        CityDefinition(
            cityNumber: 13,
            name: "Starveil Citadel",
            flavorText: "Arcane wards protect the capital heights.",
            conquestTitle: "Starveil Citadel Falls",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        ),
        CityDefinition(
            cityNumber: 14,
            name: "Stonecrown",
            flavorText: "Massive stone walls ring the royal seat.",
            conquestTitle: "Stonecrown Breached",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)
        ),
        CityDefinition(
            cityNumber: 15,
            name: "Crownspire Keep",
            flavorText: "The final keep rises above the capital.",
            conquestTitle: "Crownspire Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        )
    ]

    static func definition(for cityNumber: Int) -> CityDefinition {
        let clampedCityNumber = min(max(cityRange.lowerBound, cityNumber), cityRange.upperBound)
        return definitions[clampedCityNumber - cityRange.lowerBound]
    }

    /// Non-clamping display fallback lookup. Returns `nil` for city numbers
    /// outside `cityRange`; gameplay must keep using the clamped
    /// `definition(for:)`.
    static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
        guard cityRange.contains(cityNumber) else { return nil }
        return definitions[cityNumber - cityRange.lowerBound]
    }
}
