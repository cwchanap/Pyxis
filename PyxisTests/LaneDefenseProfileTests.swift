//
//  LaneDefenseProfileTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct LaneDefenseProfileTests {
    @Test func everyCityGetsExactlyOneOfEachRole() {
        // Test within first country and beyond to verify cycling works.
        for cityNumber in 1...30 {
            let profile = LaneDefenseProfile.profile(forCityNumber: cityNumber)
            let roles = BattleLane.allCases.map { profile.role(for: $0) }

            #expect(roles.filter { $0 == .fortified }.count == 1)
            #expect(roles.filter { $0 == .exposed }.count == 1)
            #expect(roles.filter { $0 == .standard }.count == 1)
        }
    }

    @Test func assignmentFollowsCityNumberRotation() {
        // City 1: fortified = (1-1) % 3 = 0 (left), exposed = (1+1) % 3 = 2 (right).
        let cityOne = LaneDefenseProfile.profile(forCityNumber: 1)
        #expect(cityOne.role(for: .left) == .fortified)
        #expect(cityOne.role(for: .center) == .standard)
        #expect(cityOne.role(for: .right) == .exposed)

        // City 2: fortified = 1 (center), exposed = 0 (left).
        let cityTwo = LaneDefenseProfile.profile(forCityNumber: 2)
        #expect(cityTwo.role(for: .left) == .exposed)
        #expect(cityTwo.role(for: .center) == .fortified)
        #expect(cityTwo.role(for: .right) == .standard)

        // Consecutive cities differ.
        #expect(cityOne != cityTwo)
    }

    @Test func sameCityNumberAlwaysYieldsSameProfile() {
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 7) == LaneDefenseProfile.profile(forCityNumber: 7)
        )
    }

    @Test func outOfRangeCityNumbersClampToLowerBound() {
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 0) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: -3) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
    }

    @Test func highCityNumbersCycleRatherThanClamp() {
        // City 16 (one past firstCountryCityCount) must get its own cycling profile,
        // not be clamped to city 15's profile.
        let profile16 = LaneDefenseProfile.profile(forCityNumber: 16)
        let profile15 = LaneDefenseProfile.profile(forCityNumber: 15)
        #expect(profile16 != profile15)

        // City 16 follows the rotation: fortified = (16-1) % 3 = 0 (left),
        // exposed = (16+1) % 3 = 2 (right).
        #expect(profile16.role(for: .left) == .fortified)
        #expect(profile16.role(for: .center) == .standard)
        #expect(profile16.role(for: .right) == .exposed)

        // Cities separated by a multiple of 3 share the same profile (natural cycling).
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 1)
                == LaneDefenseProfile.profile(forCityNumber: 4)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 2)
                == LaneDefenseProfile.profile(forCityNumber: 5)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 3)
                == LaneDefenseProfile.profile(forCityNumber: 6)
        )

        // Cities not separated by a multiple of 3 differ.
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 16)
                != LaneDefenseProfile.profile(forCityNumber: 18)
        )
    }

    @Test func towerDamageMultipliersMatchRoles() {
        let profile = LaneDefenseProfile.profile(forCityNumber: 1)
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
            // advantaged/disadvantaged — no neutral 1.0 — so we only check
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
