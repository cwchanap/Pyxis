//
//  LaneDefenseProfileTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct LaneDefenseProfileTests {
    @Test func everyCityGetsExactlyOneOfEachRole() {
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
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

    @Test func outOfRangeCityNumbersClamp() {
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 0) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: -3) == LaneDefenseProfile.profile(forCityNumber: 1)
        )
        #expect(
            LaneDefenseProfile.profile(forCityNumber: 99)
                == LaneDefenseProfile.profile(forCityNumber: KingdomGameState.firstCountryCityCount)
        )
    }

    @Test func towerDamageMultipliersMatchRoles() {
        let profile = LaneDefenseProfile.profile(forCityNumber: 1)
        let multipliers = profile.towerDamageMultipliers

        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func roleMultiplierValuesMirrorDefenseTraitCurve() {
        #expect(LaneDefenseRole.fortified.towerDamageMultiplier == 1.25)
        #expect(LaneDefenseRole.exposed.towerDamageMultiplier == 0.80)
        #expect(LaneDefenseRole.standard.towerDamageMultiplier == 1.0)
    }
}
