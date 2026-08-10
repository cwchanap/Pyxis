//
//  RecommendedCampRecommendation.swift
//  Pyxis
//

// swiftlint:disable nesting
enum RecommendedCampRecommendation: Equatable {
    struct Action: Equatable {
        enum Kind: Equatable {
            case build
            case upgrade
        }

        let kind: Kind
        let buildingType: BuildingType
        let slot: Int
        let cost: Int
    }

    case ready(action: Action, reason: String)
    case saveFor(action: Action, missingGold: Int, reason: String)
    case noAction(message: String)

    static func make(for state: KingdomGameState) -> RecommendedCampRecommendation {
        guard state.stageStatus == .battleActive else {
            return .noAction(message: "No favorable camp action available.")
        }

        let trait = state.currentCityDefenseTrait
        let candidates: [SoldierType] = trait == .standardWatch
            ? [.infantry]
            : trait.favorableSoldierTypes

        let cityState = state.cityBattleStateForCurrentCity

        for soldierType in candidates {
            guard let buildingType = BuildingType.allCases.first(where: {
                $0.soldierType == soldierType
            }), state.isBuildingTypeUnlocked(buildingType) else {
                continue
            }

            let existing = cityState.slots.compactMap { slot, building -> (Int, CityBuilding)? in
                building.type == buildingType ? (slot, building) : nil
            }

            let action: Action?
            if let target = existing.min(by: { lhs, rhs in
                lhs.1.level == rhs.1.level
                    ? lhs.0 < rhs.0
                    : lhs.1.level < rhs.1.level
            }) {
                action = Action(
                    kind: .upgrade,
                    buildingType: buildingType,
                    slot: target.0,
                    cost: KingdomGameState.buildingUpgradeCost(
                        for: buildingType,
                        currentLevel: target.1.level
                    )
                )
            } else if cityState.buildingCount(for: buildingType) < CityBattleState.maxBuildingsPerType,
                      let emptySlot = CityBattleState.slotRange.first(where: {
                          cityState.building(inSlot: $0) == nil
                      }) {
                action = Action(
                    kind: .build,
                    buildingType: buildingType,
                    slot: emptySlot,
                    cost: KingdomGameState.buildingBuildCost(for: buildingType)
                )
            } else {
                action = nil
            }

            guard let action else { continue }

            let reason = trait == .standardWatch
                ? "Infantry starter"
                : "\(soldierType.displayName) favored"

            if state.gold >= action.cost {
                return .ready(action: action, reason: reason)
            }

            return .saveFor(
                action: action,
                missingGold: action.cost - state.gold,
                reason: reason
            )
        }

        return .noAction(message: "No favorable camp action available.")
    }
}
// swiftlint:enable nesting
