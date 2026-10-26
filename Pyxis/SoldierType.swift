//
//  SoldierType.swift
//  Pyxis
//

import Foundation

enum SoldierType: String, Codable, CaseIterable, Equatable {
    case infantry
    case archer
    case cavalry
    case mage
    case siege

    var displayName: String {
        switch self {
        case .infantry:
            return "Infantry"
        case .archer:
            return "Archer"
        case .cavalry:
            return "Cavalry"
        case .mage:
            return "Mage"
        case .siege:
            return "Siege"
        }
    }
}

enum SoldierSpawnSource: String, Codable, Equatable {
    case manual
    case building
}

extension SoldierType {
    /// HPA-582 per-objective soldier-role multiplier, applied (and rounded)
    /// at each structure hit on top of the already trait-adjusted cached
    /// attack power — never folded into the cached power itself, so Guard
    /// combat and Captain damage are untouched. All combos default to 1.0.
    func objectiveDamageMultiplier(against kind: CitySiegeLayout.ObjectiveKind) -> Double {
        switch self {
        case .siege:
            kind == .gate || kind == .keep ? 2.0 : 1.0
        case .archer:
            kind == .arrowTower ? 1.5 : 1.0
        case .mage:
            kind == .barracks ? 1.5 : 1.0
        case .infantry, .cavalry:
            1.0
        }
    }
}
