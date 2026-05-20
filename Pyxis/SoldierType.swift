//
//  SoldierType.swift
//  Pyxis
//

import Foundation

enum SoldierType: String, Codable, CaseIterable, Equatable {
    case infantry
    case archer

    var displayName: String {
        switch self {
        case .infantry:
            return "Infantry"
        case .archer:
            return "Archer"
        }
    }
}

enum SoldierSpawnSource: String, Codable, Equatable {
    case manual
    case building
}
