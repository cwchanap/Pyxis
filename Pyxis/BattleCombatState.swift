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
        let laneDamageMultipliers: [BattleLane: Double]

        init(
            soldierMaxHP: Int,
            soldierDefense: Int,
            soldierAttackSpeed: Double,
            soldierAttackRange: Double,
            soldierMovementSpeed: Double,
            towerDamage: Int,
            towerAttackSpeed: Double,
            towerAttackRange: Double,
            maxDeltaTime: Double,
            laneDamageMultipliers: [BattleLane: Double] = [:]
        ) {
            self.soldierMaxHP = soldierMaxHP
            self.soldierDefense = soldierDefense
            self.soldierAttackSpeed = soldierAttackSpeed
            self.soldierAttackRange = soldierAttackRange
            self.soldierMovementSpeed = soldierMovementSpeed
            self.towerDamage = towerDamage
            self.towerAttackSpeed = towerAttackSpeed
            self.towerAttackRange = towerAttackRange
            self.maxDeltaTime = maxDeltaTime
            self.laneDamageMultipliers = laneDamageMultipliers
        }

        static func live(
            cityLevel: Int,
            laneDamageMultipliers: [BattleLane: Double] = [:]
        ) -> Configuration {
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
                maxDeltaTime: 0.25,
                laneDamageMultipliers: laneDamageMultipliers
            )
        }
    }

    struct Soldier: Equatable, Identifiable {
        let id: SoldierID
        let type: SoldierType
        let source: SoldierSpawnSource
        let level: Int
        let lane: BattleLane
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
    private var rng: SplitMix64

    init(configuration: Configuration, seed: UInt64) {
        self.configuration = configuration
        self.soldiers = []
        self.nextSoldierID = 1
        self.towerCooldownRemaining = 0
        self.rng = SplitMix64(seed: seed)
    }

    init(configuration: Configuration) {
        self.init(configuration: configuration, seed: UInt64.random(in: .min ... .max))
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
        attackPower: Int,
        lane: BattleLane? = nil
    ) -> SoldierID {
        let id = nextSoldierID
        nextSoldierID += 1

        let assignedLane = lane ?? (BattleLane.allCases.randomElement(using: &rng) ?? .center)
        let clampedLevel = max(1, level)
        let maxHP = maxHP(for: type, level: clampedLevel)
        soldiers.append(
            Soldier(
                id: id,
                type: type,
                source: source,
                level: clampedLevel,
                lane: assignedLane,
                maxHP: maxHP,
                currentHP: maxHP,
                defense: max(0, configuration.soldierDefense),
                attackPower: max(1, attackPower),
                attackSpeed: attackSpeed(for: type),
                attackRange: attackRange(for: type),
                movementSpeed: movementSpeed(for: type),
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
        let baseConfigurationHP = Double(max(1, configuration.soldierMaxHP))
        let multiplier: Double
        switch type {
        case .infantry:
            multiplier = 1.0
        case .archer:
            multiplier = 0.7
        case .cavalry:
            multiplier = 0.9
        case .mage:
            multiplier = 0.65
        case .siege:
            multiplier = 1.35
        }

        let baseHP = baseConfigurationHP * multiplier
        return max(1, Int((baseHP * pow(1.25, Double(max(1, level) - 1))).rounded()))
    }

    private func attackRange(for type: SoldierType) -> Double {
        let baseRange = min(max(0, configuration.soldierAttackRange), 1)
        switch type {
        case .infantry:
            return baseRange
        case .archer:
            return min(baseRange * 2.2, 1)
        case .cavalry:
            return baseRange
        case .mage:
            return min(baseRange * 2.0, 1)
        case .siege:
            return min(baseRange * 1.5, 1)
        }
    }

    private func attackSpeed(for type: SoldierType) -> Double {
        let multiplier: Double
        switch type {
        case .infantry, .archer:
            multiplier = 1.0
        case .cavalry:
            multiplier = 1.15
        case .mage:
            multiplier = 0.85
        case .siege:
            multiplier = 0.55
        }

        return max(0.1, configuration.soldierAttackSpeed * multiplier)
    }

    /// Per-type attack interval (1 / attackSpeed) for the current configuration.
    /// Exposed so BattleScene can determine whether a hit reaction can finish
    /// before the next attack tick — only cavalry's 0.9s hit exceeds its
    /// ~0.87s attack interval, so only cavalry needs the attack-while-hit
    /// suppression guard. See `playSoldierAnimation` for the rationale.
    func attackInterval(for type: SoldierType) -> Double {
        1.0 / attackSpeed(for: type)
    }

    private func movementSpeed(for type: SoldierType) -> Double {
        let baseSpeed = max(0, configuration.soldierMovementSpeed)
        switch type {
        case .infantry, .archer:
            return baseSpeed
        case .cavalry:
            return baseSpeed * 1.45
        case .mage:
            return baseSpeed * 0.9
        case .siege:
            return baseSpeed * 0.55
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

    private mutating func towerTargetIndex() -> Int? {
        let inRangeIndices = soldiers.indices.filter {
            soldiers[$0].isAlive && isInTowerRange(soldiers[$0])
        }
        guard !inRangeIndices.isEmpty else {
            return nil
        }

        let occupiedLanes = BattleLane.allCases.filter { lane in
            inRangeIndices.contains { soldiers[$0].lane == lane }
        }
        // Only consume RNG when there is a real choice, so single-lane
        // scenarios stay byte-for-byte deterministic.
        let targetLane = occupiedLanes.count == 1
            ? occupiedLanes[0]
            : (occupiedLanes.randomElement(using: &rng) ?? occupiedLanes[0])

        return inRangeIndices
            .filter { soldiers[$0].lane == targetLane }
            .max { soldiers[$0].position < soldiers[$1].position }
    }

    private func isInTowerRange(_ soldier: Soldier) -> Bool {
        soldier.position >= 1.0 - configuration.towerAttackRange
    }

    private func damageAgainstSoldier(_ soldier: Soldier) -> Int {
        let baseDamage = max(1, max(0, configuration.towerDamage) - soldier.defense)
        let laneMultiplier = max(0, configuration.laneDamageMultipliers[soldier.lane] ?? 1.0)
        return max(1, Int((Double(baseDamage) * laneMultiplier).rounded()))
    }

    private func towerAttackInterval() -> Double {
        1.0 / max(0.1, configuration.towerAttackSpeed)
    }
}
