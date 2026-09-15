//
//  BattleCombatState.swift
//  Pyxis
//

import Foundation

struct SoldierAttackEvent: Equatable {
    let soldierID: BattleCombatState.SoldierID
    let type: SoldierType
    let source: SoldierSpawnSource
    let lane: BattleLane
    /// The authored objective this attack landed on (HPA-468). Transitional
    /// empty default exists only for untouched compile-continuity callers;
    /// Task 5.5 removes it.
    var objectiveID: String = ""
    // HPA-468 Task 5.5: rename `appliedCityDamage` to `appliedDamage`.
    let appliedCityDamage: Int
}

struct SoldierLossEvent: Equatable {
    let soldierID: BattleCombatState.SoldierID
    let type: SoldierType
    let source: SoldierSpawnSource
    let lane: BattleLane
}

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

    /// Ephemeral per-tick siege input (HPA-468): the authored layout plus
    /// each objective's current remaining HP, projected by `KingdomGameState`.
    /// `tick` may mutate a local copy to prevent same-tick overkill; the
    /// persisted damage stays in `KingdomGameState`.
    struct SiegeSnapshot: Equatable {
        let layout: CitySiegeLayout
        let objectiveRemainingPower: [String: Int]
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
        var didReachConquest = false
        var soldierAttacks: [SoldierAttackEvent] = []
        var towerShots: [TowerShot] = []
        var damagedSoldierIDs: [SoldierID] = []
        var soldierLosses: [SoldierLossEvent] = []
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

    var livingSoldierCount: Int {
        soldiers.filter(\.isAlive).count
    }

    func livingSoldierCount(source: SoldierSpawnSource) -> Int {
        soldiers.filter { $0.isAlive && $0.source == source }.count
    }

    /// Every spawn carries an explicit lane (HPA-468 §3.4): production and
    /// tests pass `siegeProgress.selectedLane`. There is no random-lane
    /// fallback; RNG is reserved for true randoms such as choosing among
    /// multiple occupied defensive-fire lanes.
    @discardableResult
    mutating func spawnSoldier(
        type: SoldierType,
        source: SoldierSpawnSource,
        level: Int,
        attackPower: Int,
        lane: BattleLane
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
                lane: lane,
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

    /// Advances one combat tick against the ephemeral siege snapshot.
    /// Soldiers target the first living objective along their own route,
    /// stop at `target.visualProgress - attackRange`, and mutate a local
    /// copy of the objective HP so same-tick attacks can never overkill one
    /// objective. `didReachConquest` means the local Keep reached zero; the
    /// persisted damage is applied by `KingdomGameState` from the returned
    /// events.
    @discardableResult
    mutating func tick(deltaTime rawDeltaTime: Double, siege snapshot: SiegeSnapshot) -> TickResult {
        let deltaTime = clampedDeltaTime(rawDeltaTime)
        let keepID = snapshot.layout.keepObjective.id
        guard deltaTime > 0, snapshot.objectiveRemainingPower[keepID, default: 0] > 0 else {
            return TickResult()
        }

        var result = TickResult()
        var objectiveRemaining = snapshot.objectiveRemainingPower

        towerCooldownRemaining = max(0, towerCooldownRemaining - deltaTime)
        if towerCooldownRemaining <= 0,
           let targetIndex = defensiveFireTargetIndex(snapshot: snapshot, objectiveRemaining: objectiveRemaining) {
            let damage = damageAgainstSoldier(soldiers[targetIndex])
            soldiers[targetIndex].currentHP = max(0, soldiers[targetIndex].currentHP - damage)
            let soldierID = soldiers[targetIndex].id
            result.towerShots.append(TowerShot(soldierID: soldierID, damage: damage))
            result.damagedSoldierIDs.append(soldierID)

            if !soldiers[targetIndex].isAlive {
                let soldier = soldiers[targetIndex]
                result.soldierLosses.append(
                    SoldierLossEvent(
                        soldierID: soldier.id,
                        type: soldier.type,
                        source: soldier.source,
                        lane: soldier.lane
                    )
                )
            }

            towerCooldownRemaining = towerAttackInterval()
        }

        for index in soldiers.indices where soldiers[index].isAlive {
            let targetID = snapshot.layout.routes[soldiers[index].lane]?
                .first { objectiveRemaining[$0, default: 0] > 0 }
            let targetProgress = targetID.flatMap { snapshot.layout.objective(id: $0)?.visualProgress }

            advanceMovement(forSoldierAt: index, targetProgress: targetProgress, deltaTime: deltaTime)

            guard let targetID,
                  let targetProgress,
                  isInAttackRange(soldiers[index], objectiveProgress: targetProgress) else {
                continue
            }

            soldiers[index].attackCooldownRemaining -= deltaTime

            if soldiers[index].attackCooldownRemaining <= 0 {
                let appliedDamage = min(soldiers[index].attackPower, objectiveRemaining[targetID, default: 0])
                if appliedDamage > 0 {
                    objectiveRemaining[targetID, default: 0] -= appliedDamage
                    result.soldierAttacks.append(
                        SoldierAttackEvent(
                            soldierID: soldiers[index].id,
                            type: soldiers[index].type,
                            source: soldiers[index].source,
                            lane: soldiers[index].lane,
                            objectiveID: targetID,
                            appliedCityDamage: appliedDamage
                        )
                    )
                    soldiers[index].attackCooldownRemaining += attackInterval(forSoldier: soldiers[index])
                }
            }

            if objectiveRemaining[keepID, default: 0] <= 0 {
                result.didReachConquest = true
                break
            }
        }

        soldiers.removeAll { !$0.isAlive }

        return result
    }

    /// Clamps `rawDeltaTime` to the same bounds `tick` uses internally
    /// (`[0, max(0.01, configuration.maxDeltaTime)]`). Exposed for callers
    /// that need to mirror the combat tick's clamped time progression.
    func clampedDeltaTime(_ rawDeltaTime: Double) -> Double {
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

    private mutating func advanceMovement(forSoldierAt index: Int, targetProgress: Double?, deltaTime: Double) {
        guard let targetProgress else {
            return
        }

        let stopPosition = max(0, targetProgress - soldiers[index].attackRange)
        guard soldiers[index].position < stopPosition else {
            return
        }

        soldiers[index].position = min(
            stopPosition,
            soldiers[index].position + soldiers[index].movementSpeed * deltaTime
        )
    }

    private func isInAttackRange(_ soldier: Soldier, objectiveProgress: Double) -> Bool {
        soldier.position >= max(0, objectiveProgress - soldier.attackRange)
    }

    private func attackInterval(forSoldier soldier: Soldier) -> Double {
        1.0 / max(0.1, soldier.attackSpeed)
    }

    /// Foremost living soldier among the defensive fire's covered, in-range
    /// lanes (HPA-468 §3.3). The source must still be alive; range is
    /// source-relative: `position >= max(0, sourceProgress - towerAttackRange)`.
    /// RNG is consumed only when several occupied lanes force a real choice.
    private mutating func defensiveFireTargetIndex(
        snapshot: SiegeSnapshot,
        objectiveRemaining: [String: Int]
    ) -> Int? {
        let sourceID = snapshot.layout.defensiveFire.sourceObjectiveID
        guard objectiveRemaining[sourceID, default: 0] > 0,
              let source = snapshot.layout.objective(id: sourceID) else {
            return nil
        }

        let coveredLanes = Set(snapshot.layout.defensiveFire.coveredLanes)
        let threshold = max(0, source.visualProgress - configuration.towerAttackRange)
        let inRangeIndices = soldiers.indices.filter {
            soldiers[$0].isAlive
                && coveredLanes.contains(soldiers[$0].lane)
                && soldiers[$0].position >= threshold
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

    private func damageAgainstSoldier(_ soldier: Soldier) -> Int {
        let baseDamage = max(1, max(0, configuration.towerDamage) - soldier.defense)
        let laneMultiplier = max(0, configuration.laneDamageMultipliers[soldier.lane] ?? 1.0)
        return max(1, Int((Double(baseDamage) * laneMultiplier).rounded()))
    }

    private func towerAttackInterval() -> Double {
        1.0 / max(0.1, configuration.towerAttackSpeed)
    }
}
