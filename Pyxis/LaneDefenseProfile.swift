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
struct LaneDefenseProfile: Equatable {
    let roles: [BattleLane: LaneDefenseRole]

    func role(for lane: BattleLane) -> LaneDefenseRole {
        roles[lane] ?? .standard
    }

    var towerDamageMultipliers: [BattleLane: Double] {
        roles.mapValues(\.towerDamageMultiplier)
    }

    static func profile(forCityNumber cityNumber: Int) -> LaneDefenseProfile {
        // TODO: When multi-country support expands beyond firstCountryCityCount,
        // cycle the profile by country (e.g., shift the base offset per country)
        // instead of clamping to the last city's profile.
        let clamped = min(max(1, cityNumber), KingdomGameState.firstCountryCityCount)
        let fortifiedIndex = (clamped - 1) % 3
        let exposedIndex = (clamped + 1) % 3

        var roles: [BattleLane: LaneDefenseRole] = [:]
        for lane in BattleLane.allCases {
            switch lane.rawValue {
            case fortifiedIndex:
                roles[lane] = .fortified
            case exposedIndex:
                roles[lane] = .exposed
            default:
                roles[lane] = .standard
            }
        }

        return LaneDefenseProfile(roles: roles)
    }
}
