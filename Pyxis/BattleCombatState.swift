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
    /// The authored objective this attack landed on (HPA-468).
    var objectiveID: String
    let appliedDamage: Int
}

struct SoldierLossEvent: Equatable {
    let soldierID: BattleCombatState.SoldierID
    let type: SoldierType
    let source: SoldierSpawnSource
    let lane: BattleLane
}

struct BattleCombatState: Equatable {
    typealias SoldierID = Int
    typealias GuardID = Int

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

    /// Transient lane-local enemy Guard (HPA-469 pilot). Only lane + HP are
    /// persisted (via `GuardSnapshot`); IDs and positions are rebuilt.
    struct Guard: Equatable, Identifiable {
        let id: GuardID
        let lane: BattleLane
        let maxHP: Int
        var currentHP: Int
        var position: Double
        var attackCooldownRemaining: Double

        var isAlive: Bool {
            currentHP > 0
        }
    }

    /// A living Guard attacked an allied soldier (HPA-469).
    struct GuardAttackEvent: Equatable {
        let guardID: BattleCombatState.GuardID
        let soldierID: BattleCombatState.SoldierID
        let appliedDamage: Int
    }

    /// A soldier hit a Guard. `type` is the attacking soldier's type; this
    /// event is intentionally distinct from `SoldierAttackEvent` so Guard
    /// damage never becomes battle-report city damage.
    struct GuardHitEvent: Equatable {
        let guardID: BattleCombatState.GuardID
        let soldierID: BattleCombatState.SoldierID
        let type: SoldierType
        let appliedDamage: Int
    }

    struct GuardLossEvent: Equatable {
        let guardID: BattleCombatState.GuardID
        let lane: BattleLane
    }

    struct TickResult: Equatable {
        var didReachConquest = false
        var soldierAttacks: [SoldierAttackEvent] = []
        var towerShots: [TowerShot] = []
        var damagedSoldierIDs: [SoldierID] = []
        var soldierLosses: [SoldierLossEvent] = []
        var guardAttacks: [GuardAttackEvent] = []
        var guardHits: [GuardHitEvent] = []
        var guardLosses: [GuardLossEvent] = []
    }

    let configuration: Configuration
    private(set) var soldiers: [Soldier]
    private(set) var guards: [Guard]
    private var nextSoldierID: SoldierID
    private var nextGuardID: GuardID
    private var towerCooldownRemaining: Double
    private var rng: SplitMix64

    init(configuration: Configuration, seed: UInt64) {
        self.configuration = configuration
        self.soldiers = []
        self.guards = []
        self.nextSoldierID = 1
        self.nextGuardID = 1
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

    /// Restores (or freshly spawns) one transient Guard at Keep progress on
    /// the snapshot's lane. Combat numbers come from `HighcrestGuardRules`;
    /// only lane + HP survive a scene replacement, so IDs and positions are
    /// always rebuilt here.
    @discardableResult
    mutating func restoreGuard(_ snapshot: GuardSnapshot, siege: SiegeSnapshot) -> GuardID {
        let id = nextGuardID
        nextGuardID += 1

        guards.append(
            Guard(
                id: id,
                lane: snapshot.lane,
                maxHP: HighcrestGuardRules.maxHP,
                currentHP: min(max(1, snapshot.remainingHP), HighcrestGuardRules.maxHP),
                position: siege.layout.keepObjective.visualProgress,
                attackCooldownRemaining: 0
            )
        )

        return id
    }

    /// Living Guards' persisted lane + clamped HP only; positions stay
    /// transient. Dead Guards are pruned at the end of every tick, so this
    /// never emits a 0-HP snapshot (persistence would clamp that back up to
    /// 1 and resurrect the Guard).
    var guardSnapshots: [GuardSnapshot] {
        guards.filter(\.isAlive).map { guardActor in
            GuardSnapshot(lane: guardActor.lane, remainingHP: guardActor.currentHP)
        }
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

        // HPA-469 lane-local Guards: movement and attacks resolve after the
        // tower block, before the soldier loop, so a soldier killed by a
        // Guard this tick never attacks back.
        advanceGuards(deltaTime: deltaTime, snapshot: snapshot)
        resolveLivingGuardAttacks(deltaTime: deltaTime, into: &result)

        for index in soldiers.indices where soldiers[index].isAlive {
            let blockerIndex = nearestGuardBlockerIndex(forLane: soldiers[index].lane)
            let targetID = snapshot.layout.routes[soldiers[index].lane]?
                .first { objectiveRemaining[$0, default: 0] > 0 }
            let targetProgress = targetID.flatMap { snapshot.layout.objective(id: $0)?.visualProgress }

            let movementTarget = movementTarget(
                forSoldierAt: index,
                blockerIndex: blockerIndex,
                targetProgress: targetProgress
            )
            advanceMovement(forSoldierAt: index, targetProgress: movementTarget, deltaTime: deltaTime)

            guard let targetID,
                  let targetProgress else {
                continue
            }

            // A blocking Guard is attacked before any structure, but only
            // once the soldier's own per-type range is satisfied.
            if attackGuardBlockerIfInRange(
                at: index,
                blockerIndex: blockerIndex,
                deltaTime: deltaTime,
                into: &result
            ) {
                continue
            }

            guard isInAttackRange(soldiers[index], objectiveProgress: targetProgress) else {
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
                            appliedDamage: appliedDamage
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

        pruneDeadActors(into: &result)

        return result
    }

    /// Removes soldiers and Guards that died this tick, emitting one loss
    /// event per dead Guard exactly once, before the removal.
    private mutating func pruneDeadActors(into result: inout TickResult) {
        for guardActor in guards where !guardActor.isAlive {
            result.guardLosses.append(GuardLossEvent(guardID: guardActor.id, lane: guardActor.lane))
        }
        guards.removeAll { !$0.isAlive }
        soldiers.removeAll { !$0.isAlive }
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

    // MARK: Lane-local Guard combat (HPA-469)

    /// The position a soldier marches toward this tick: its first live
    /// structure, or its lane's blocking Guard when that is closer, so
    /// opposing actors never cross (HPA-469).
    private func movementTarget(
        forSoldierAt index: Int,
        blockerIndex: Int?,
        targetProgress: Double?
    ) -> Double? {
        guard let blockerIndex, let targetProgress else {
            return targetProgress
        }
        return min(targetProgress, guards[blockerIndex].position)
    }

    /// Guards close downward on the foremost soldier of their own lane while
    /// outside their own `HighcrestGuardRules.attackRange`, clamped at the
    /// authored Barracks progress (or 0 without one) and never crossing the
    /// target. A Guard with no allied target holds position.
    private mutating func advanceGuards(deltaTime: Double, snapshot: SiegeSnapshot) {
        let floor = snapshot.layout.barracksObjective?.visualProgress ?? 0
        for index in guards.indices where guards[index].isAlive {
            guard let target = foremostSoldier(in: guards[index].lane) else {
                continue
            }
            let stopPosition = max(floor, target.position + HighcrestGuardRules.attackRange)
            guard guards[index].position > stopPosition else {
                continue
            }
            guards[index].position = max(
                stopPosition,
                guards[index].position - HighcrestGuardRules.movementSpeed * deltaTime
            )
        }
    }

    /// Each living Guard attacks the foremost living soldier of its own lane
    /// once inside its own range. Guard damage/death flows through the
    /// existing `damagedSoldierIDs` / `soldierLosses` channels (same as the
    /// tower); it never becomes `SoldierAttackEvent` or city damage.
    private mutating func resolveLivingGuardAttacks(deltaTime: Double, into result: inout TickResult) {
        for index in guards.indices where guards[index].isAlive {
            guard let targetIndex = foremostSoldierIndex(in: guards[index].lane) else {
                continue
            }
            let distance = guards[index].position - soldiers[targetIndex].position
            guard distance <= HighcrestGuardRules.attackRange else {
                continue
            }

            guards[index].attackCooldownRemaining -= deltaTime
            guard guards[index].attackCooldownRemaining <= 0 else {
                continue
            }

            let appliedDamage = min(HighcrestGuardRules.attackPower, soldiers[targetIndex].currentHP)
            guard appliedDamage > 0 else {
                continue
            }

            soldiers[targetIndex].currentHP -= appliedDamage
            result.guardAttacks.append(
                GuardAttackEvent(
                    guardID: guards[index].id,
                    soldierID: soldiers[targetIndex].id,
                    appliedDamage: appliedDamage
                )
            )
            result.damagedSoldierIDs.append(soldiers[targetIndex].id)

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

            guards[index].attackCooldownRemaining += 1.0 / max(0.1, HighcrestGuardRules.attackSpeed)
        }
    }

    /// Attacks the lane's blocking Guard when the soldier's own per-type
    /// range is satisfied. Returns whether the attack happened, in which case
    /// structure attacks are skipped for that soldier this tick.
    private mutating func attackGuardBlockerIfInRange(
        at soldierIndex: Int,
        blockerIndex: Int?,
        deltaTime: Double,
        into result: inout TickResult
    ) -> Bool {
        guard let blockerIndex,
              isInAttackRange(soldiers[soldierIndex], objectiveProgress: guards[blockerIndex].position) else {
            return false
        }
        resolveSoldierAttackOnGuard(
            at: soldierIndex,
            guardIndex: blockerIndex,
            deltaTime: deltaTime,
            into: &result
        )
        return true
    }

    private mutating func resolveSoldierAttackOnGuard(
        at soldierIndex: Int,
        guardIndex: Int,
        deltaTime: Double,
        into result: inout TickResult
    ) {
        soldiers[soldierIndex].attackCooldownRemaining -= deltaTime
        guard soldiers[soldierIndex].attackCooldownRemaining <= 0 else {
            return
        }

        let appliedDamage = min(soldiers[soldierIndex].attackPower, guards[guardIndex].currentHP)
        guard appliedDamage > 0 else {
            return
        }

        guards[guardIndex].currentHP -= appliedDamage
        result.guardHits.append(
            GuardHitEvent(
                guardID: guards[guardIndex].id,
                soldierID: soldiers[soldierIndex].id,
                type: soldiers[soldierIndex].type,
                appliedDamage: appliedDamage
            )
        )
        soldiers[soldierIndex].attackCooldownRemaining += attackInterval(forSoldier: soldiers[soldierIndex])
    }

    /// The first Guard a soldier meets on its route: the lowest-position
    /// living Guard in the soldier's lane. Guards never move below the
    /// Barracks floor, so this is always the nearest opposing actor ahead.
    private func nearestGuardBlockerIndex(forLane lane: BattleLane) -> Int? {
        guards.indices
            .filter { guards[$0].isAlive && guards[$0].lane == lane }
            .min { guards[$0].position < guards[$1].position }
    }

    private func foremostSoldierIndex(in lane: BattleLane) -> Int? {
        soldiers.indices
            .filter { soldiers[$0].isAlive && soldiers[$0].lane == lane }
            .max { soldiers[$0].position < soldiers[$1].position }
    }

    private func foremostSoldier(in lane: BattleLane) -> Soldier? {
        foremostSoldierIndex(in: lane).map { soldiers[$0] }
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
