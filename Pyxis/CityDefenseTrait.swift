//
//  CityDefenseTrait.swift
//  Pyxis
//

import Foundation

enum CityDefenseTrait: String, CaseIterable, Equatable {
    case standardWatch
    case arrowTower
    case spikedGate
    case stoneWall
    case arcaneWard
    case burningOil
    case reinforcedKeep

    var displayName: String {
        switch self {
        case .standardWatch:
            return "Standard Watch"
        case .arrowTower:
            return "Arrow Tower"
        case .spikedGate:
            return "Spiked Gate"
        case .stoneWall:
            return "Stone Wall"
        case .arcaneWard:
            return "Arcane Ward"
        case .burningOil:
            return "Burning Oil"
        case .reinforcedKeep:
            return "Reinforced Keep"
        }
    }

    var shortDescription: String {
        switch self {
        case .standardWatch:
            return "No counter modifiers."
        case .arrowTower:
            return "Durable and fast melee troops perform better."
        case .spikedGate:
            return "Ranged troops avoid the gate's melee punishment."
        case .stoneWall:
            return "Magic and siege attacks break through stone."
        case .arcaneWard:
            return "Infantry, Cavalry, and Siege avoid the ward's resistance."
        case .burningOil:
            return "Fast or ranged troops avoid slow close-range losses."
        case .reinforcedKeep:
            return "Siege attacks perform best against the keep."
        }
    }

    var hudText: String {
        "\(displayName): \(shortDescription)"
    }

    func damageMultiplier(for soldierType: SoldierType) -> Double {
        switch self {
        case .standardWatch:
            return 1.0
        case .arrowTower:
            switch soldierType {
            case .infantry, .cavalry:
                return 1.25
            case .archer, .mage:
                return 0.80
            case .siege:
                return 1.0
            }
        case .spikedGate:
            switch soldierType {
            case .archer, .mage:
                return 1.25
            case .infantry, .cavalry:
                return 0.80
            case .siege:
                return 1.0
            }
        case .stoneWall:
            switch soldierType {
            case .mage, .siege:
                return 1.25
            case .archer:
                return 0.80
            case .infantry, .cavalry:
                return 1.0
            }
        case .arcaneWard:
            switch soldierType {
            case .infantry, .cavalry, .siege:
                return 1.25
            case .mage:
                return 0.80
            case .archer:
                return 1.0
            }
        case .burningOil:
            switch soldierType {
            case .archer, .mage, .cavalry:
                return 1.25
            case .infantry, .siege:
                return 0.80
            }
        case .reinforcedKeep:
            switch soldierType {
            case .siege:
                return 1.25
            case .archer, .infantry:
                return 0.80
            case .cavalry, .mage:
                return 1.0
            }
        }
    }
}
