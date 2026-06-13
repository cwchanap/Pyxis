//
//  LaneDefenseProfile.swift
//  Pyxis
//

import Foundation

/// How strongly the city tower punishes soldiers in a given lane.
enum LaneDefenseRole: String, CaseIterable, Equatable {
    case fortified
    case exposed
    case standard

    /// Multiplier on tower→soldier damage. Mirrors CityDefenseTrait's
    /// 1.25× / 0.80× balance values (which scale soldier→city damage).
    var towerDamageMultiplier: Double {
        switch self {
        case .fortified:
            return 1.25
        case .exposed:
            return 0.80
        case .standard:
            return 1.0
        }
    }
}

/// Per-city deterministic assignment of one role per battle lane.
///
/// Stores only the two non-standard lanes; the remaining lane is implicitly
/// `.standard`. This makes the "exactly one fortified / one exposed / one
/// standard" invariant unbreakable by construction — there is no dictionary
/// that can be missing keys or hold duplicate roles.
struct LaneDefenseProfile: Equatable {
    let fortifiedLane: BattleLane
    let exposedLane: BattleLane

    /// The lane that is neither fortified nor exposed.
    /// Safe because ``init(fortifiedLane:exposedLane:)`` enforces that the two differ.
    var standardLane: BattleLane {
        BattleLane.allCases.first { $0 != fortifiedLane && $0 != exposedLane }!
    }

    init(fortifiedLane: BattleLane, exposedLane: BattleLane) {
        precondition(fortifiedLane != exposedLane, "fortifiedLane and exposedLane must be different lanes")
        self.fortifiedLane = fortifiedLane
        self.exposedLane = exposedLane
    }

    func role(for lane: BattleLane) -> LaneDefenseRole {
        if lane == fortifiedLane {
            return .fortified
        }
        if lane == exposedLane {
            return .exposed
        }
        return .standard
    }

    var towerDamageMultipliers: [BattleLane: Double] {
        var multipliers: [BattleLane: Double] = [:]
        for lane in BattleLane.allCases {
            multipliers[lane] = role(for: lane).towerDamageMultiplier
        }
        return multipliers
    }

    static func profile(forCityNumber cityNumber: Int) -> LaneDefenseProfile {
        let safe = max(1, cityNumber)
        let fortifiedIndex = (safe - 1) % 3
        let exposedIndex = (safe + 1) % 3

        let fortified = BattleLane.allCases.first { $0.rawValue == fortifiedIndex }!
        let exposed = BattleLane.allCases.first { $0.rawValue == exposedIndex }!

        return LaneDefenseProfile(fortifiedLane: fortified, exposedLane: exposed)
    }
}
