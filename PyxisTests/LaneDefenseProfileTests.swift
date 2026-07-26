//
//  LaneDefenseProfileTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct LaneDefenseProfileTests {
    @Test func rolesAreDerivedFromFortifiedAndExposedLanes() {
        let profile = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)

        #expect(profile.role(for: .left) == .fortified)
        #expect(profile.role(for: .center) == .standard)
        #expect(profile.role(for: .right) == .exposed)
        #expect(profile.standardLane == .center)
    }

    @Test func equalityUsesFortifiedAndExposedLanes() {
        let leftRight = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        let matching = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        let centerLeft = LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left)

        #expect(leftRight == matching)
        #expect(leftRight != centerLeft)
    }

    @Test func towerDamageMultipliersMatchRoles() {
        let profile = LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right)
        let multipliers = profile.towerDamageMultipliers

        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func laneRoleMultipliersMatchCityDefenseTraitBalanceValues() {
        // LaneDefenseRole.towerDamageMultiplier is documented to mirror
        // CityDefenseTrait's 1.25× / 0.80× balance curve. Cross-asserting
        // against the trait's actual damageMultiplier(for:) output prevents
        // silent divergence when one side is rebalanced without the other.
        for trait in CityDefenseTrait.allCases {
            let multipliers = Set(SoldierType.allCases.map { trait.damageMultiplier(for: $0) })

            // Non-standard traits have at least two distinct multipliers.
            // Their max must match fortified and their min must match exposed.
            // (Some traits like burningOil cover all soldier types with
            // favorable/disadvantaged — no neutral 1.0 — so we only check
            // the extrema when modifiers exist.)
            guard multipliers.count > 1 else {
                continue
            }
            #expect(
                multipliers.max() == LaneDefenseRole.fortified.towerDamageMultiplier,
                "Trait \(trait) max multiplier drifted from fortified"
            )
            #expect(
                multipliers.min() == LaneDefenseRole.exposed.towerDamageMultiplier,
                "Trait \(trait) min multiplier drifted from exposed"
            )
        }
    }
}
