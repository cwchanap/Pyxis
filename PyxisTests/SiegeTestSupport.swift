//
//  SiegeTestSupport.swift
//  PyxisTests
//

import Foundation
@testable import Pyxis

/// Test-only support for the tactical siege pilot (HPA-468).
///
/// Builds current-city battle states by Keep remaining HP, optional
/// support-objective damage, and optional selected lane. Stable objective
/// IDs are resolved from the current authored layout projection so suites
/// never spread `"*.keep"`-style literals. Aggregate objective remaining
/// math intentionally lives here only — production exposes Keep HP as the
/// sole conquest/liveness authority.
enum SiegeTestSupport {
    /// Resolves the first objective of `kind` in the current city's authored
    /// layout, or nil when the layout has no such objective.
    static func objectiveID(
        for kind: CitySiegeLayout.ObjectiveKind,
        in state: KingdomGameState
    ) -> String? {
        state.currentCityDefinition.siegeLayout.objectives.first { $0.kind == kind }?.id
    }

    /// Aggregate remaining HP across all current-city objectives. Test-only:
    /// production intentionally exposes Keep HP alone.
    static func totalObjectiveRemainingPower(of state: KingdomGameState) -> Int {
        let layout = state.currentCityDefinition.siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)
        return layout
            .remainingPower(
                maxPowers: maxPowers,
                damageByObjectiveID: state.siegeProgress.damageByObjectiveID
            )
            .values
            .reduce(0, +)
    }

    /// Builds a battle-active current-city state whose Keep sits at
    /// `keepRemaining` HP (clamped to `0...currentKeepMaxPower`), with
    /// optional damage applied to support objectives (clamped to each
    /// objective's authored maximum) and an optional selected lane.
    ///
    /// Undamaged objectives carry no damage entry.
    static func makeBattleState(
        atCity cityNumber: Int = 1,
        gold: Int = 0,
        keepRemaining: Int,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:],
        selectedLane: BattleLane? = nil
    ) -> KingdomGameState {
        var state = KingdomGameState(
            gold: gold,
            cityNumberInCountry: cityNumber,
            completedCityCount: cityNumber - 1
        )

        let layout = state.currentCityDefinition.siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)

        var damageByObjectiveID: [String: Int] = [:]
        let keepID = layout.keepObjective.id
        let keepDamage = clampedDamage(
            maxPowers[keepID, default: 0] - keepRemaining,
            toMax: maxPowers[keepID, default: 0]
        )
        if keepDamage > 0 {
            damageByObjectiveID[keepID] = keepDamage
        }
        for (kind, damage) in supportDamage {
            guard let objectiveID = objectiveID(for: kind, in: state) else {
                continue // no such support objective in this layout
            }
            let clamped = clampedDamage(damage, toMax: maxPowers[objectiveID, default: 0])
            if clamped > 0 {
                damageByObjectiveID[objectiveID] = clamped
            }
        }

        // Match `startCityFromMap` entry state: a freshly entered Highcrest
        // carries fresh full-reserve Guard progress; other cities carry nil.
        state.siegeProgress = SiegeProgress(
            selectedLane: selectedLane ?? layout.defaultLane,
            damageByObjectiveID: damageByObjectiveID,
            guardReinforcements: layout.barracksObjective != nil
                ? GuardReinforcementProgress.freshHighcrest()
                : nil
        )
        return state
    }

    /// Aligns an already-constructed state's siege progress so the current
    /// city's Keep sits at `keepRemaining` HP (clamped to `0...currentKeepMaxPower`).
    /// Suites that build states with buildings/sessions use this after
    /// constructing the state instead of the deprecated scalar.
    static func setKeepRemaining(_ keepRemaining: Int, on state: inout KingdomGameState) {
        let layout = state.currentCityDefinition.siegeLayout
        let keepID = layout.keepObjective.id
        let keepMax = layout.maxPowerAllocation(totalBudget: state.cityMaxPower)[keepID] ?? 0
        let keepDamage = clampedDamage(keepMax - keepRemaining, toMax: keepMax)
        if keepDamage > 0 {
            state.siegeProgress.damageByObjectiveID[keepID] = keepDamage
        } else {
            state.siegeProgress.damageByObjectiveID.removeValue(forKey: keepID)
        }
    }

    private static func clampedDamage(_ rawDamage: Int, toMax maxPower: Int) -> Int {
        min(max(0, rawDamage), maxPower)
    }
}
