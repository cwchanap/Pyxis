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
