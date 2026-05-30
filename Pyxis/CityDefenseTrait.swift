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
        if advantagedSoldierTypes.contains(soldierType) {
            return 1.25
        }

        if disadvantagedSoldierTypes.contains(soldierType) {
            return 0.80
        }

        return 1.0
    }

    private var advantagedSoldierTypes: [SoldierType] {
        switch self {
        case .standardWatch:
            return []
        case .arrowTower:
            return [.infantry, .cavalry]
        case .spikedGate:
            return [.archer, .mage]
        case .stoneWall:
            return [.mage, .siege]
        case .arcaneWard:
            return [.infantry, .cavalry, .siege]
        case .burningOil:
            return [.archer, .mage, .cavalry]
        case .reinforcedKeep:
            return [.siege]
        }
    }

    private var disadvantagedSoldierTypes: [SoldierType] {
        switch self {
        case .standardWatch:
            return []
        case .arrowTower:
            return [.archer, .mage]
        case .spikedGate:
            return [.infantry, .cavalry]
        case .stoneWall:
            return [.archer]
        case .arcaneWard:
            return [.mage]
        case .burningOil:
            return [.infantry, .siege]
        case .reinforcedKeep:
            return [.archer, .infantry]
        }
    }
}
