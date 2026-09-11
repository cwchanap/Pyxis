//
//  LivingKingdomPresentation.swift
//  Pyxis
//

import Foundation

enum LivingKingdomPresentation {
    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable {
        case breach, collapse

        var frameNames: [String] {
            switch self {
            case .breach:
                return [
                    "lk-fx-breach-01", "lk-fx-breach-02", "lk-fx-breach-03",
                    "lk-fx-breach-04", "lk-fx-breach-05", "lk-fx-breach-06"
                ]
            case .collapse:
                return [
                    "lk-fx-collapse-01", "lk-fx-collapse-02", "lk-fx-collapse-03",
                    "lk-fx-collapse-04", "lk-fx-collapse-05", "lk-fx-collapse-06"
                ]
            }
        }

        var secondsPerFrame: TimeInterval {
            switch self {
            case .breach: 0.05
            case .collapse: 0.07
            }
        }
    }

    struct Battle: Equatable {
        let family: CityVisualFamily
        let stage: FortressStage

        var fortressAssetName: String {
            "lk-city-\(family.rawValue)-\(stage.rawValue)"
        }

        var battlefieldTreatmentAssetName: String? {
            family == .frontier ? nil : "lk-battlefield-\(family.rawValue)"
        }
    }

    struct Map: Equatable {
        let securedCityNumbers: [Int]
        let caravanSegmentStartCityNumbers: [Int]
        let routeSixToSevenAssetName: String
    }

    static func battle(
        cityNumber: Int,
        remainingHP: Int,
        maxHP: Int,
        hasPendingConquest: Bool
    ) -> Battle {
        let maximum = max(1, maxHP)
        let remaining = max(0, remainingHP)
        let stage: FortressStage
        if hasPendingConquest || remaining == 0 {
            stage = .conquered
        } else if remaining * 5 > maximum * 3 {
            stage = .intact
        } else if remaining * 4 > maximum {
            stage = .damaged
        } else {
            stage = .breached
        }
        return Battle(
            family: Country1CityCatalog.definition(for: cityNumber).visualFamily,
            stage: stage
        )
    }

    static func transitionEffect(
        from old: FortressStage,
        to new: FortressStage
    ) -> TransitionEffect? {
        guard old != new else { return nil }
        switch new {
        case .breached: return .breach
        case .conquered: return .collapse
        case .intact, .damaged: return nil
        }
    }

    static func map(completedCityCount: Int) -> Map {
        let completed = min(KingdomGameState.firstCountryCityCount, max(0, completedCityCount))
        let secured = completed == 0 ? [] : Array(1...completed)
        let eligibleStarts = completed <= 1 ? [] : Array(1..<completed)
        return Map(
            securedCityNumbers: secured,
            caravanSegmentStartCityNumbers: Array(eligibleStarts.prefix(2)),
            routeSixToSevenAssetName: completed >= 7
                ? "lk-map-route-6-7-repaired"
                : "lk-map-route-6-7-worn"
        )
    }
}
