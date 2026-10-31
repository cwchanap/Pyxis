//
//  GreedyCampBuyer.swift
//  PyxisTests
//

import Foundation
@testable import Pyxis

// swiftlint:disable nesting

/// Deterministic test-only greedy camp buyer (HPA-582 Task 0).
///
/// Balance-harness purchasing policy for the chained `Country1SiegeSmoke`
/// campaign: enumerate affordable legal builds/upgrades using existing
/// unlocks, slot/per-type caps and the production cost formulas, prefer
/// affordable actions for favored *unlocked* types (the current city's
/// `CityDefenseTrait`), otherwise any unlocked type, and within the chosen
/// tier take the cheapest candidate with a stable type/action/slot tie-break.
/// Candidates are recomputed after every purchase, so the policy assembles
/// multi-building camps and stops only when nothing legal is affordable.
/// This is intentionally not `RecommendedCampRecommendation` (player advice)
/// and must never become runtime economy AI.
enum GreedyCampBuyer {
    struct Action: Equatable {
        enum Kind: Equatable {
            case build
            case upgrade
        }

        let kind: Kind
        let type: BuildingType
        let slot: Int
        let cost: Int
    }

    /// Next affordable legal purchase for `state`, or nil when nothing legal
    /// is affordable (or the city is not actively under siege).
    static func nextAction(for state: KingdomGameState) -> Action? {
        guard state.stageStatus == .battleActive else {
            return nil
        }

        let favoredTypes = Set(
            state.currentCityDefenseTrait.favorableSoldierTypes.compactMap { buildingType(for: $0) }
        )
        let cityState = state.cityBattleStateForCurrentCity
        var candidates: [Action] = []
        for type in KingdomGameState.unlockedBuildingTypes(forCityNumber: state.cityNumberInCountry) {
            if cityState.buildingCount(for: type) < CityBattleState.maxBuildingsPerType,
               let slot = CityBattleState.slotRange.first(where: { cityState.building(inSlot: $0) == nil }) {
                candidates.append(
                    Action(
                        kind: .build,
                        type: type,
                        slot: slot,
                        cost: state.buildingBuildCost(for: type)
                    )
                )
            }
            for (slot, building) in cityState.slots where building.type == type {
                candidates.append(
                    Action(
                        kind: .upgrade,
                        type: type,
                        slot: slot,
                        cost: state.buildingUpgradeCost(for: type, currentLevel: building.level)
                    )
                )
            }
        }

        let affordable = candidates.filter { $0.cost <= state.gold }
        guard !affordable.isEmpty else {
            return nil
        }

        let favored = affordable.filter { favoredTypes.contains($0.type) }
        let tier = favored.isEmpty ? affordable : favored
        return tier.min(by: compare)
    }

    /// Stable comparator: cheapest first, then `BuildingType.allCases` order,
    /// then build before upgrade, then lowest slot.
    private static func compare(_ lhs: Action, _ rhs: Action) -> Bool {
        if lhs.cost != rhs.cost {
            return lhs.cost < rhs.cost
        }
        let lhsType = BuildingType.allCases.firstIndex(of: lhs.type) ?? 0
        let rhsType = BuildingType.allCases.firstIndex(of: rhs.type) ?? 0
        if lhsType != rhsType {
            return lhsType < rhsType
        }
        if lhs.kind != rhs.kind {
            return lhs.kind == .build
        }
        return lhs.slot < rhs.slot
    }

    private static func buildingType(for soldierType: SoldierType) -> BuildingType? {
        BuildingType.allCases.first { $0.soldierType == soldierType }
    }
}
// swiftlint:enable nesting
