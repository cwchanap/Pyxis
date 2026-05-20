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
        let type: SoldierType
        let source: SoldierSpawnSource
        let level: Int
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

    struct TowerShot: Equatable {
        let soldierID: SoldierID
        let damage: Int
    }

    struct TickResult: Equatable {
        var cityDamage: Int = 0
        var didReachConquest = false
        var soldierAttackIDs: [SoldierID] = []
        var towerShots: [TowerShot] = []
        var damagedSoldierIDs: [SoldierID] = []
        var killedSoldierIDs: [SoldierID] = []
    }

    let configuration: Configuration
    private(set) var soldiers: [Soldier]
    private var nextSoldierID: SoldierID
    private var towerCooldownRemaining: Double

    init(configuration: Configuration) {
        self.configuration = configuration
        self.soldiers = []
        self.nextSoldierID = 1
        self.towerCooldownRemaining = 0
    }

    init(cityLevel: Int) {
        self.init(configuration: .live(cityLevel: cityLevel))
    }

    var livingSoldierCount: Int {
        soldiers.filter(\.isAlive).count
    }

    func livingSoldierCount(source: SoldierSpawnSource) -> Int {
        soldiers.filter { $0.isAlive && $0.source == source }.count
    }

    @discardableResult
    mutating func spawnSoldier(attackPower: Int) -> SoldierID {
        spawnSoldier(type: .infantry, source: .manual, level: 1, attackPower: attackPower)
    }

    @discardableResult
    mutating func spawnSoldier(
        type: SoldierType,
        source: SoldierSpawnSource,
        level: Int,
        attackPower: Int
    ) -> SoldierID {
        let id = nextSoldierID
        nextSoldierID += 1

        let clampedLevel = max(1, level)
        let maxHP = maxHP(for: type, level: clampedLevel)
        soldiers.append(
            Soldier(
                id: id,
                type: type,
                source: source,
                level: clampedLevel,
                maxHP: maxHP,
                currentHP: maxHP,
                defense: max(0, configuration.soldierDefense),
                attackPower: max(1, attackPower),
                attackSpeed: max(0.1, configuration.soldierAttackSpeed),
                attackRange: attackRange(for: type),
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

    @discardableResult
    mutating func tick(deltaTime rawDeltaTime: Double, cityRemainingHP: Int) -> TickResult {
        let deltaTime = clampedDeltaTime(rawDeltaTime)
        guard deltaTime > 0, cityRemainingHP > 0 else {
            return TickResult()
        }

        var result = TickResult()
        var remainingCityHP = max(0, cityRemainingHP)

        towerCooldownRemaining = max(0, towerCooldownRemaining - deltaTime)
        if towerCooldownRemaining <= 0, let targetIndex = towerTargetIndex() {
            let damage = damageAgainstSoldier(soldiers[targetIndex])
            soldiers[targetIndex].currentHP = max(0, soldiers[targetIndex].currentHP - damage)
            let soldierID = soldiers[targetIndex].id
            result.towerShots.append(TowerShot(soldierID: soldierID, damage: damage))
            result.damagedSoldierIDs.append(soldierID)

            if !soldiers[targetIndex].isAlive {
                result.killedSoldierIDs.append(soldierID)
            }

            towerCooldownRemaining = towerAttackInterval()
        }

        for index in soldiers.indices where soldiers[index].isAlive {
            advanceMovement(forSoldierAt: index, deltaTime: deltaTime)

            guard isInAttackRange(soldiers[index]) else {
                continue
            }

            soldiers[index].attackCooldownRemaining -= deltaTime

            if soldiers[index].attackCooldownRemaining <= 0 {
                let appliedDamage = min(soldiers[index].attackPower, remainingCityHP)
                result.cityDamage += appliedDamage
                result.soldierAttackIDs.append(soldiers[index].id)
                remainingCityHP -= appliedDamage
                soldiers[index].attackCooldownRemaining += attackInterval(for: soldiers[index])
            }

            if remainingCityHP <= 0 {
                result.didReachConquest = true
                break
            }
        }

        soldiers.removeAll { !$0.isAlive }

        return result
    }

    private func clampedDeltaTime(_ rawDeltaTime: Double) -> Double {
        min(max(0, rawDeltaTime), max(0.01, configuration.maxDeltaTime))
    }

    private func maxHP(for type: SoldierType, level: Int) -> Int {
        let baseHP: Double
        switch type {
        case .infantry:
            baseHP = Double(max(1, configuration.soldierMaxHP))
        case .archer:
            baseHP = Double(max(1, configuration.soldierMaxHP)) * 0.7
        }

        return max(1, Int((baseHP * pow(1.25, Double(max(1, level) - 1))).rounded()))
    }

    private func attackRange(for type: SoldierType) -> Double {
        switch type {
        case .infantry:
            return min(max(0, configuration.soldierAttackRange), 1)
        case .archer:
            return min(max(0, configuration.soldierAttackRange * 2.2), 1)
        }
    }

    private mutating func advanceMovement(forSoldierAt index: Int, deltaTime: Double) {
        guard !isInAttackRange(soldiers[index]) else {
            return
        }

        let attackPosition = max(0, 1.0 - soldiers[index].attackRange)
        soldiers[index].position = min(
            attackPosition,
            soldiers[index].position + soldiers[index].movementSpeed * deltaTime
        )
    }

    private func isInAttackRange(_ soldier: Soldier) -> Bool {
        soldier.position >= 1.0 - soldier.attackRange
    }

    private func attackInterval(for soldier: Soldier) -> Double {
        1.0 / max(0.1, soldier.attackSpeed)
    }

    private func towerTargetIndex() -> Int? {
        soldiers.indices
            .filter { soldiers[$0].isAlive && isInTowerRange(soldiers[$0]) }
            .max { soldiers[$0].position < soldiers[$1].position }
    }

    private func isInTowerRange(_ soldier: Soldier) -> Bool {
        soldier.position >= 1.0 - configuration.towerAttackRange
    }

    private func damageAgainstSoldier(_ soldier: Soldier) -> Int {
        max(1, max(0, configuration.towerDamage) - soldier.defense)
    }

    private func towerAttackInterval() -> Double {
        1.0 / max(0.1, configuration.towerAttackSpeed)
    }
}
