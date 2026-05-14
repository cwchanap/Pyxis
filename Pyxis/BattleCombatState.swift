//
//  BattleCombatState.swift
//  Pyxis
//

import Foundation

struct BattleCombatState: Equatable {
    typealias SoldierID = Int

    struct Configuration: Equatable {
        let soldierMaxHP: Int
        let soldierDefense: Int
        let soldierAttackSpeed: Double
        let soldierAttackRange: Double
        let soldierMovementSpeed: Double
        let towerDamage: Int
        let towerAttackSpeed: Double
        let towerAttackRange: Double
        let maxDeltaTime: Double

        static func live(cityLevel: Int) -> Configuration {
            let clampedLevel = max(1, cityLevel)

            return Configuration(
                soldierMaxHP: 10,
                soldierDefense: 1,
                soldierAttackSpeed: 1.0,
                soldierAttackRange: 0.12,
                soldierMovementSpeed: 0.45,
                towerDamage: max(2, Int(ceil(1.5 * Double(clampedLevel)))),
                towerAttackSpeed: 0.8,
                towerAttackRange: 0.55,
                maxDeltaTime: 0.25
            )
        }
    }

    struct Soldier: Equatable, Identifiable {
        let id: SoldierID
        let maxHP: Int
        var currentHP: Int
        let defense: Int
        let attackPower: Int
        let attackSpeed: Double
        let attackRange: Double
        let movementSpeed: Double
        var position: Double
        var attackCooldownRemaining: Double

        var isAlive: Bool {
            currentHP > 0
        }
    }

    let configuration: Configuration
    private(set) var soldiers: [Soldier]
    private var nextSoldierID: SoldierID

    init(configuration: Configuration) {
        self.configuration = configuration
        self.soldiers = []
        self.nextSoldierID = 1
    }

    init(cityLevel: Int) {
        self.init(configuration: .live(cityLevel: cityLevel))
    }

    var livingSoldierCount: Int {
        soldiers.filter(\.isAlive).count
    }

    @discardableResult
    mutating func spawnSoldier(attackPower: Int) -> SoldierID {
        let id = nextSoldierID
        nextSoldierID += 1

        soldiers.append(
            Soldier(
                id: id,
                maxHP: max(1, configuration.soldierMaxHP),
                currentHP: max(1, configuration.soldierMaxHP),
                defense: max(0, configuration.soldierDefense),
                attackPower: max(1, attackPower),
                attackSpeed: max(0.1, configuration.soldierAttackSpeed),
                attackRange: min(max(0, configuration.soldierAttackRange), 1),
                movementSpeed: max(0, configuration.soldierMovementSpeed),
                position: 0,
                attackCooldownRemaining: 0
            )
        )

        return id
    }

    func soldier(id: SoldierID) -> Soldier? {
        soldiers.first { $0.id == id }
    }
}
