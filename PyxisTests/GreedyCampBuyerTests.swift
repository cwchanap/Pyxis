//
//  GreedyCampBuyerTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

/// Deterministic greedy-buyer policy tests (HPA-582 Task 0). The buyer is a
/// test-only balance-harness player, deliberately unlike the player-facing
/// `RecommendedCampRecommendation`, which stops at one unaffordable favored
/// action and returns noAction where no favored type is unlocked.
struct GreedyCampBuyerTests {
    private func makeState(
        city: Int,
        gold: Int,
        cityState: CityBattleState = CityBattleState()
    ) -> KingdomGameState {
        let key = CityKey(countryNumber: 1, cityNumber: city)
        return KingdomGameState(
            gold: gold,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [key.storageKey: cityState]
        )
    }

    /// Buys to exhaustion through the real state mutations, mirroring the
    /// chained campaign's purchase loop, and returns the executed actions.
    private func buyAll(_ state: inout KingdomGameState) -> [GreedyCampBuyer.Action] {
        let purchaseDate = Date(timeIntervalSinceReferenceDate: 0)
        var actions: [GreedyCampBuyer.Action] = []
        while state.stageStatus == .battleActive,
              let action = GreedyCampBuyer.nextAction(for: state) {
            let purchased: Bool
            switch action.kind {
            case .build:
                if case .built = state.buildBuilding(action.type, inSlot: action.slot, at: purchaseDate) {
                    purchased = true
                } else {
                    purchased = false
                }
            case .upgrade:
                if case .upgraded = state.upgradeBuilding(inSlot: action.slot, at: purchaseDate) {
                    purchased = true
                } else {
                    purchased = false
                }
            }
            guard purchased else { break }
            actions.append(action)
        }
        return actions
    }

    @Test("The buyer assembles multiple buildings, favoring unlocked favored types over cheaper ones")
    func buysMultipleBuildingsWithReevaluation() {
        // City 4 (spikedGate) favors Archers; Barracks + Archery Range are unlocked.
        var state = makeState(city: 4, gold: 52)

        let actions = buyAll(&state)

        #expect(actions == [
            GreedyCampBuyer.Action(kind: .build, type: .archeryRange, slot: 1, cost: 18),
            GreedyCampBuyer.Action(kind: .upgrade, type: .archeryRange, slot: 1, cost: 14),
            GreedyCampBuyer.Action(kind: .build, type: .archeryRange, slot: 2, cost: 18)
        ])
        let camp = state.cityBattleStateForCurrentCity
        #expect(camp.buildingCount(for: .archeryRange) == 2)
        #expect(camp.building(inSlot: 1)?.level == 2)
        #expect(state.gold == 2)
    }

    @Test("City 6 assembles a nonempty camp even though no favored type is unlocked")
    func city6BuildsNonemptyCampWithoutUnlockedFavorables() {
        // City 6 (stoneWall) favors Mage + Siege, locked until cities 8 and 11.
        let adviceState = makeState(city: 6, gold: 61)
        guard case .noAction = RecommendedCampRecommendation.make(for: adviceState) else {
            Issue.record("Expected City 6 advice to be noAction (no unlocked favored type)")
            return
        }

        var state = makeState(city: 6, gold: 61)
        let actions = buyAll(&state)

        let camp = state.cityBattleStateForCurrentCity
        #expect(!camp.slots.isEmpty)
        // Cheapest-first re-evaluation: Barracks L1, its cheap L2 upgrade, a second
        // Barracks, its L2 upgrade — all from unlocked types.
        #expect(actions == [
            GreedyCampBuyer.Action(kind: .build, type: .barracks, slot: 1, cost: 15),
            GreedyCampBuyer.Action(kind: .upgrade, type: .barracks, slot: 1, cost: 12),
            GreedyCampBuyer.Action(kind: .build, type: .barracks, slot: 2, cost: 15),
            GreedyCampBuyer.Action(kind: .upgrade, type: .barracks, slot: 2, cost: 12)
        ])
        #expect(state.gold == 7)
        #expect(camp.slots.values.allSatisfy { $0.type != .mageTower && $0.type != .siegeWorkshop })
    }

    @Test("An unaffordable favored recommendation does not block a cheaper legal purchase")
    func unaffordableRecommendationDoesNotBlockCheaperLegalAction() {
        // City 8 (stoneWall) favors the 40-gold Mage Tower; 20 gold cannot buy it.
        let adviceState = makeState(city: 8, gold: 20)
        guard case .saveFor = RecommendedCampRecommendation.make(for: adviceState) else {
            Issue.record("Expected City 8 advice to be saveFor on the unaffordable favored build")
            return
        }

        var state = makeState(city: 8, gold: 20)
        let actions = buyAll(&state)

        #expect(actions.map(\.type) == [.barracks])
        #expect(state.cityBattleStateForCurrentCity.buildingCount(for: .barracks) == 1)
    }

    @Test("Spent gold is conserved across the whole purchase sequence")
    func spentGoldIsConserved() {
        var state = makeState(city: 12, gold: 300)
        let initialGold = state.gold
        let purchaseDate = Date(timeIntervalSinceReferenceDate: 0)
        var actions: [GreedyCampBuyer.Action] = []

        while state.stageStatus == .battleActive,
              let action = GreedyCampBuyer.nextAction(for: state) {
            let goldBefore = state.gold
            let purchased: Bool
            switch action.kind {
            case .build:
                if case .built = state.buildBuilding(action.type, inSlot: action.slot, at: purchaseDate) {
                    purchased = true
                } else {
                    purchased = false
                }
            case .upgrade:
                if case .upgraded = state.upgradeBuilding(inSlot: action.slot, at: purchaseDate) {
                    purchased = true
                } else {
                    purchased = false
                }
            }
            guard purchased else { break }
            #expect(goldBefore - state.gold == action.cost)
            actions.append(action)
        }

        #expect(!actions.isEmpty)
        #expect(initialGold - state.gold == actions.map(\.cost).reduce(0, +))
    }

    @Test("Equal-cost candidates tie-break by lowest slot, deterministically")
    func equalCostTieBreakPrefersLowestSlot() {
        let cityState = CityBattleState(slots: [
            1: CityBuilding(type: .barracks, level: 1),
            2: CityBuilding(type: .barracks, level: 1)
        ])
        let state = makeState(city: 1, gold: 12, cityState: cityState)

        let first = GreedyCampBuyer.nextAction(for: state)
        let second = GreedyCampBuyer.nextAction(for: state)

        #expect(first == GreedyCampBuyer.Action(kind: .upgrade, type: .barracks, slot: 1, cost: 12))
        #expect(first == second)
    }

    @Test("The same starting state produces the same purchase sequence and final state")
    func purchaseSequenceIsDeterministic() {
        var firstState = makeState(city: 4, gold: 52)
        var secondState = makeState(city: 4, gold: 52)

        let firstActions = buyAll(&firstState)
        let secondActions = buyAll(&secondState)

        #expect(!firstActions.isEmpty)
        #expect(firstActions == secondActions)
        #expect(firstState == secondState)
    }
}
