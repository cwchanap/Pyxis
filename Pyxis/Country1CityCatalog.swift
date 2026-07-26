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
        CityDefinition(cityNumber: 1, defenseTrait: .standardWatch, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)),
        CityDefinition(cityNumber: 2, defenseTrait: .standardWatch, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)),
        CityDefinition(cityNumber: 3, defenseTrait: .arrowTower, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)),
        CityDefinition(cityNumber: 4, defenseTrait: .spikedGate, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)),
        CityDefinition(cityNumber: 5, defenseTrait: .arrowTower, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)),
        CityDefinition(cityNumber: 6, defenseTrait: .stoneWall, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)),
        CityDefinition(cityNumber: 7, defenseTrait: .burningOil, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)),
        CityDefinition(cityNumber: 8, defenseTrait: .stoneWall, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)),
        CityDefinition(cityNumber: 9, defenseTrait: .arcaneWard, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)),
        CityDefinition(cityNumber: 10, defenseTrait: .spikedGate, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)),
        CityDefinition(cityNumber: 11, defenseTrait: .reinforcedKeep, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)),
        CityDefinition(cityNumber: 12, defenseTrait: .burningOil, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)),
        CityDefinition(cityNumber: 13, defenseTrait: .arcaneWard, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)),
        CityDefinition(cityNumber: 14, defenseTrait: .stoneWall, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)),
        CityDefinition(cityNumber: 15, defenseTrait: .reinforcedKeep, laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center)
        )
    ]

    static func definition(for cityNumber: Int) -> CityDefinition {
        let clampedCityNumber = min(max(cityRange.lowerBound, cityNumber), cityRange.upperBound)
        return definitions[clampedCityNumber - cityRange.lowerBound]
    }
}
