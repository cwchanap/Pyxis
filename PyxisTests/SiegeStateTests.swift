//
//  SiegeStateTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct SiegeStateTests {
    /// Falconridge's authored layout, read from the catalog so the pins
    /// exercise the real authoring site.
    private static var falconridge: CitySiegeLayout {
        Country1CityCatalog.definition(for: 3).siegeLayout
    }

    /// Minimal two-objective pilot layout (Keep + Gate) for allocation and
    /// spillover math that Falconridge's exact 4:2:2 split cannot express.
    private static func makeKeepAndGateLayout() -> CitySiegeLayout {
        CitySiegeLayout(
            objectives: [
                .init(id: "test.keep", kind: .keep, durabilityWeight: 1, visualLane: .center, visualProgress: 1.0),
                .init(id: "test.gate", kind: .gate, durabilityWeight: 2, visualLane: .center, visualProgress: 0.5)
            ],
            routes: [
                .left: ["test.gate", "test.keep"],
                .center: ["test.gate", "test.keep"],
                .right: ["test.gate", "test.keep"]
            ],
            defaultLane: .center,
            defensiveFire: .init(sourceObjectiveID: "test.keep", coveredLanes: BattleLane.allCases)
        )
    }

    // MARK: Construction (fail-closed invariants)

    // Authored invariant violations (zero or multiple keeps, empty/duplicate
    // IDs, non-positive weights, out-of-range progress, missing lanes, empty
    // or dangling or backward routes, dangling fire source, repeated fire
    // coverage) trap via `precondition` inside `CitySiegeLayout.init`,
    // matching the LaneDefenseProfile house style. Traps cannot be
    // intercepted in-process, so these suites pin every constructible-valid
    // behavior instead; invalid catalog authoring crashes static
    // initialization loudly instead of silently normalizing.

    @Test func singleKeepEmitsValidThreeLaneContent() {
        for defaultLane in BattleLane.allCases {
            let layout = CitySiegeLayout.singleKeep(defaultLane: defaultLane)

            #expect(layout.objectives.count == 1)
            #expect(layout.keepObjective.kind == .keep)
            #expect(layout.keepObjective.id == "keep")
            #expect(layout.keepObjective.visualProgress == 1.0)

            #expect(Set(layout.routes.keys) == Set(BattleLane.allCases))
            for lane in BattleLane.allCases {
                #expect(layout.routes[lane] == ["keep"])
            }

            #expect(layout.defaultLane == defaultLane)
            #expect(layout.defensiveFire.sourceObjectiveID == "keep")
            #expect(layout.defensiveFire.coveredLanes.count == BattleLane.allCases.count)
            #expect(Set(layout.defensiveFire.coveredLanes) == Set(BattleLane.allCases))
        }
    }

    // MARK: Falconridge pins

    @Test func falconridgePinsAuthoredObjectiveStructure() {
        let layout = Self.falconridge

        let keep = layout.objective(id: "falconridge.keep")
        #expect(keep?.kind == .keep)
        #expect(keep?.durabilityWeight == 4)
        #expect(keep?.visualLane == .center)
        #expect(keep?.visualProgress == 1.0)

        let tower = layout.objective(id: "falconridge.arrow-tower")
        #expect(tower?.kind == .arrowTower)
        #expect(tower?.durabilityWeight == 2)
        #expect(tower?.visualLane == .left)
        #expect(tower?.visualProgress == 0.68)

        let gate = layout.objective(id: "falconridge.ridge-gate")
        #expect(gate?.kind == .gate)
        #expect(gate?.durabilityWeight == 2)
        // R3 (binding ruling): the Gate's visualLane is center; the
        // center/right span is derived from routes by the scene, not
        // authored metadata.
        #expect(gate?.visualLane == .center)
        #expect(gate?.visualProgress == 0.58)
    }

    @Test func falconridgePinsRoutesDefaultLaneAndDefensiveFire() {
        let layout = Self.falconridge

        #expect(layout.routes == [
            .left: ["falconridge.arrow-tower", "falconridge.keep"],
            .center: ["falconridge.ridge-gate", "falconridge.keep"],
            .right: ["falconridge.ridge-gate", "falconridge.keep"]
        ])
        #expect(layout.defaultLane == .center)
        #expect(layout.defensiveFire.sourceObjectiveID == "falconridge.arrow-tower")
        #expect(layout.defensiveFire.coveredLanes.count == BattleLane.allCases.count)
        #expect(Set(layout.defensiveFire.coveredLanes) == Set(BattleLane.allCases))
    }

    @Test func falconridgeAllocatesCityMaxPowerNinetyTwoAs46And23And23() {
        let allocation = Self.falconridge.maxPowerAllocation(totalBudget: 92)

        #expect(allocation == [
            "falconridge.keep": 46,
            "falconridge.arrow-tower": 23,
            "falconridge.ridge-gate": 23
        ])
        #expect(allocation.values.reduce(0, +) == 92)
    }

    @Test func falconridgeFirstLiveTargetWalksEachRouteInOrder() {
        let layout = Self.falconridge
        let maxPowers = layout.maxPowerAllocation(totalBudget: 92)

        // Fresh city: left starts at the Tower, center/right at the Gate.
        #expect(layout.firstLiveObjectiveID(for: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
            == "falconridge.arrow-tower")
        #expect(layout.firstLiveObjectiveID(for: .center, maxPowers: maxPowers, damageByObjectiveID: [:])
            == "falconridge.ridge-gate")
        #expect(layout.firstLiveObjectiveID(for: .right, maxPowers: maxPowers, damageByObjectiveID: [:])
            == "falconridge.ridge-gate")

        // Tower dead: left falls through to the Keep.
        var damage = ["falconridge.arrow-tower": 23]
        #expect(layout.firstLiveObjectiveID(for: .left, maxPowers: maxPowers, damageByObjectiveID: damage)
            == "falconridge.keep")

        // Gate damaged but alive: center still targets the Gate.
        damage = ["falconridge.ridge-gate": 10]
        #expect(layout.firstLiveObjectiveID(for: .center, maxPowers: maxPowers, damageByObjectiveID: damage)
            == "falconridge.ridge-gate")

        // Everything dead: no live target anywhere.
        damage = [
            "falconridge.arrow-tower": 23,
            "falconridge.ridge-gate": 23,
            "falconridge.keep": 46
        ]
        #expect(layout.firstLiveObjectiveID(for: .left, maxPowers: maxPowers, damageByObjectiveID: damage) == nil)
        #expect(layout.firstLiveObjectiveID(for: .center, maxPowers: maxPowers, damageByObjectiveID: damage) == nil)
    }

    // MARK: HP allocation and remaining power

    @Test func maxPowerAllocationSumsExactlyToBudgetAndRemainderGoesToKeep() {
        // 4:2:2 of 93 floors to 46/23/23 (sum 92); the spare point goes to the Keep.
        let falconridgeAllocation = Self.falconridge.maxPowerAllocation(totalBudget: 93)
        #expect(falconridgeAllocation["falconridge.keep"] == 47)
        #expect(falconridgeAllocation["falconridge.arrow-tower"] == 23)
        #expect(falconridgeAllocation["falconridge.ridge-gate"] == 23)
        #expect(falconridgeAllocation.values.reduce(0, +) == 93)

        // 1:2 of 10 floors to 3/6 (sum 9); the spare point goes to the Keep.
        let allocation = Self.makeKeepAndGateLayout().maxPowerAllocation(totalBudget: 10)
        #expect(allocation["test.keep"] == 4)
        #expect(allocation["test.gate"] == 6)
        #expect(allocation.values.reduce(0, +) == 10)

        #expect(
            CitySiegeLayout.singleKeep(defaultLane: .left).maxPowerAllocation(totalBudget: 7) == ["keep": 7]
        )
    }

    @Test func keepRemainingPowerIsTheConquestAuthorityAndClampsAtZero() {
        let layout = Self.falconridge
        let maxPowers = layout.maxPowerAllocation(totalBudget: 92)

        #expect(layout.keepRemainingPower(maxPowers: maxPowers, damageByObjectiveID: [:]) == 46)

        // Gate/Tower damage never touches Keep HP.
        #expect(
            layout.keepRemainingPower(
                maxPowers: maxPowers,
                damageByObjectiveID: ["falconridge.ridge-gate": 23, "falconridge.arrow-tower": 23]
            ) == 46
        )

        #expect(layout.keepRemainingPower(maxPowers: maxPowers, damageByObjectiveID: ["falconridge.keep": 20]) == 26)

        // Overkill damage clamps at zero, never negative.
        #expect(layout.keepRemainingPower(maxPowers: maxPowers, damageByObjectiveID: ["falconridge.keep": 99]) == 0)

        let remaining = layout.remainingPower(maxPowers: maxPowers, damageByObjectiveID: ["falconridge.ridge-gate": 30])
        #expect(remaining == [
            "falconridge.keep": 46,
            "falconridge.arrow-tower": 23,
            "falconridge.ridge-gate": 0
        ])
    }

    // MARK: Route damage budget

    @Test func damageBudgetSpendsInRouteOrderAndSpillsOnlyAfterObjectiveDies() {
        let layout = Self.falconridge
        let maxPowers = layout.maxPowerAllocation(totalBudget: 92)

        // Budget smaller than the blocker's remaining HP: no spill.
        var spend = layout.spendDamageBudget(10, along: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
        #expect(spend.appliedByObjectiveID == ["falconridge.arrow-tower": 10])
        #expect(spend.damageByObjectiveID == ["falconridge.arrow-tower": 10])

        // Exact kill: the blocker dies and nothing spills.
        spend = layout.spendDamageBudget(23, along: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
        #expect(spend.appliedByObjectiveID == ["falconridge.arrow-tower": 23])
        #expect(layout.keepRemainingPower(maxPowers: maxPowers, damageByObjectiveID: spend.damageByObjectiveID) == 46)

        // Overkill spills into the Keep only after the blocker dies.
        spend = layout.spendDamageBudget(30, along: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
        #expect(spend.appliedByObjectiveID == ["falconridge.arrow-tower": 23, "falconridge.keep": 7])

        // Full route: Tower 23 + Keep 46 = 69; excess past the Keep is dropped.
        spend = layout.spendDamageBudget(100, along: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
        #expect(spend.appliedByObjectiveID == ["falconridge.arrow-tower": 23, "falconridge.keep": 46])
        #expect(layout.keepRemainingPower(maxPowers: maxPowers, damageByObjectiveID: spend.damageByObjectiveID) == 0)

        // Pre-damaged blocker absorbs only its remaining HP; remainder spills.
        spend = layout.spendDamageBudget(20, along: .left, maxPowers: maxPowers, damageByObjectiveID: [
            "falconridge.arrow-tower": 10
        ])
        #expect(spend.appliedByObjectiveID == ["falconridge.arrow-tower": 13, "falconridge.keep": 7])

        // Zero budget is a no-op.
        spend = layout.spendDamageBudget(0, along: .left, maxPowers: maxPowers, damageByObjectiveID: [:])
        #expect(spend.appliedByObjectiveID.isEmpty)
        #expect(spend.damageByObjectiveID.isEmpty)
    }

    // MARK: Persisted progress value

    @Test func siegeProgressRoundTripsThroughCodable() throws {
        let progress = SiegeProgress(
            selectedLane: .right,
            damageByObjectiveID: ["falconridge.keep": 5, "falconridge.ridge-gate": 23]
        )

        let data = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(SiegeProgress.self, from: data)

        #expect(decoded == progress)
    }
}
