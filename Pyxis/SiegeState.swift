//
//  SiegeState.swift
//  Pyxis
//

/// Authored, fail-closed siege layout for one city (HPA-468 tactical siege
/// pilot). Framework-free value type.
///
/// Authored catalog data fails closed: `init` preconditions every invariant
/// in the same spirit as `LaneDefenseProfile`, so a catalog authoring error
/// crashes at static initialization instead of silently normalizing.
/// Persisted progress (`SiegeProgress`) is the forgiving half and is
/// normalized by its owner.
struct CitySiegeLayout: Equatable {
    enum ObjectiveKind: Equatable, Hashable {
        case keep
        case gate
        case arrowTower
        case barracks
    }

    struct Objective: Equatable {
        let id: String
        let kind: ObjectiveKind
        let durabilityWeight: Int
        let visualLane: BattleLane
        let visualProgress: Double
    }

    struct DefensiveFire: Equatable {
        let sourceObjectiveID: String
        let coveredLanes: [BattleLane]
    }

    /// Ordered stable objective IDs only; geometry resolves from each
    /// referenced objective's `visualProgress`.
    let objectives: [Objective]
    let routes: [BattleLane: [String]]
    let defaultLane: BattleLane
    let defensiveFire: DefensiveFire

    /// The single `.keep` objective. Safe because `init` enforces exactly one.
    var keepObjective: Objective {
        objectives.first { $0.kind == .keep }!
    }

    /// The optional single `.barracks` objective (HPA-469 Highcrest Guard
    /// pilot), or nil for layouts without one. `init` enforces at-most-one.
    var barracksObjective: Objective? {
        objectives.first { $0.kind == .barracks }
    }

    init(
        objectives: [Objective],
        routes: [BattleLane: [String]],
        defaultLane: BattleLane,
        defensiveFire: DefensiveFire
    ) {
        let keeps = objectives.filter { $0.kind == .keep }
        precondition(keeps.count == 1, "CitySiegeLayout must contain exactly one keep objective")
        let keepID = keeps[0].id
        precondition(
            objectives.filter { $0.kind == .barracks }.count <= 1,
            "CitySiegeLayout must contain at most one barracks objective"
        )
        precondition(
            objectives.allSatisfy { !$0.id.isEmpty },
            "CitySiegeLayout objective IDs must be non-empty"
        )
        precondition(
            Set(objectives.map(\.id)).count == objectives.count,
            "CitySiegeLayout objective IDs must be unique"
        )
        precondition(
            objectives.allSatisfy { $0.durabilityWeight > 0 },
            "CitySiegeLayout durability weights must be positive"
        )
        precondition(
            objectives.allSatisfy { (0.0...1.0).contains($0.visualProgress) },
            "CitySiegeLayout visualProgress must lie within 0...1"
        )

        let progressByID = Dictionary(uniqueKeysWithValues: objectives.map { ($0.id, $0.visualProgress) })
        precondition(
            Set(routes.keys) == Set(BattleLane.allCases),
            "CitySiegeLayout routes must contain exactly all three lanes"
        )
        for lane in BattleLane.allCases {
            let route = routes[lane, default: []]
            precondition(!route.isEmpty, "CitySiegeLayout route for \(lane) must be non-empty")
            precondition(
                route.allSatisfy { progressByID[$0] != nil },
                "CitySiegeLayout route for \(lane) references an unknown objective ID"
            )
            // Duplicate IDs would let one objective appear twice in a route,
            // and a once-snapshotted damage budget would then let the repeat
            // re-absorb its full HP past the authored maximum.
            precondition(
                Set(route).count == route.count,
                "CitySiegeLayout route for \(lane) must not repeat an objective ID"
            )
            precondition(route.last == keepID, "CitySiegeLayout route for \(lane) must end at the keep")
            let routeProgress = route.map { progressByID[$0]! }
            precondition(
                zip(routeProgress, routeProgress.dropFirst()).allSatisfy { $0 <= $1 },
                "CitySiegeLayout route for \(lane) must be non-decreasing by objective progress"
            )
        }

        precondition(
            progressByID[defensiveFire.sourceObjectiveID] != nil,
            "CitySiegeLayout defensive-fire source must reference an existing objective"
        )
        precondition(!defensiveFire.coveredLanes.isEmpty, "CitySiegeLayout defensive-fire coverage must be non-empty")
        precondition(
            Set(defensiveFire.coveredLanes).count == defensiveFire.coveredLanes.count,
            "CitySiegeLayout defensive-fire coverage must not repeat lanes"
        )

        self.objectives = objectives
        self.routes = routes
        self.defaultLane = defaultLane
        self.defensiveFire = defensiveFire
    }

    /// The only non-pilot shape: one Keep at progress 1.0 that every lane
    /// attacks directly and that sources defensive fire over all lanes.
    static func singleKeep(defaultLane: BattleLane) -> CitySiegeLayout {
        CitySiegeLayout(
            objectives: [
                Objective(id: "keep", kind: .keep, durabilityWeight: 1, visualLane: .center, visualProgress: 1.0)
            ],
            routes: Dictionary(uniqueKeysWithValues: BattleLane.allCases.map { ($0, ["keep"]) }),
            defaultLane: defaultLane,
            defensiveFire: DefensiveFire(sourceObjectiveID: "keep", coveredLanes: BattleLane.allCases)
        )
    }

    // MARK: Objective lookup

    func objective(id: String) -> Objective? {
        objectives.first { $0.id == id }
    }

    // MARK: Pure HP math

    /// Splits `totalBudget` across objectives proportional to
    /// `durabilityWeight`, floors each share, and gives any integer remainder
    /// to the Keep. The result always sums exactly to `totalBudget`.
    func maxPowerAllocation(totalBudget: Int) -> [String: Int] {
        let totalWeight = objectives.reduce(0) { $0 + $1.durabilityWeight }
        var allocation: [String: Int] = [:]
        var assigned = 0
        for objective in objectives {
            let share = totalBudget * objective.durabilityWeight / totalWeight
            allocation[objective.id] = share
            assigned += share
        }
        allocation[keepObjective.id, default: 0] += totalBudget - assigned
        return allocation
    }

    /// Per-objective remaining HP, clamped at zero.
    func remainingPower(maxPowers: [String: Int], damageByObjectiveID: [String: Int]) -> [String: Int] {
        var remaining: [String: Int] = [:]
        for objective in objectives {
            let damage = damageByObjectiveID[objective.id] ?? 0
            remaining[objective.id] = max(0, (maxPowers[objective.id] ?? 0) - damage)
        }
        return remaining
    }

    /// Keep HP is the only conquest/liveness authority.
    func keepRemainingPower(maxPowers: [String: Int], damageByObjectiveID: [String: Int]) -> Int {
        remainingPower(maxPowers: maxPowers, damageByObjectiveID: damageByObjectiveID)[keepObjective.id] ?? 0
    }

    /// The first still-living objective along `lane`'s route, in route order.
    func firstLiveObjectiveID(
        for lane: BattleLane,
        maxPowers: [String: Int],
        damageByObjectiveID: [String: Int]
    ) -> String? {
        let remaining = remainingPower(maxPowers: maxPowers, damageByObjectiveID: damageByObjectiveID)
        return routes[lane]?.first { remaining[$0, default: 0] > 0 }
    }

    /// Spends a positive damage budget down `lane`'s ordered route: each
    /// objective absorbs up to its remaining HP, and the remainder spills to
    /// the next objective only after the current one dies. Anything left
    /// once the route (ending at the Keep) is exhausted is dropped. Routes
    /// are duplicate-free by construction, so no objective can absorb from
    /// a single budget twice. Returns the updated damage map plus the
    /// per-objective damage actually applied.
    func spendDamageBudget(
        _ budget: Int,
        along lane: BattleLane,
        maxPowers: [String: Int],
        damageByObjectiveID: [String: Int]
    ) -> (damageByObjectiveID: [String: Int], appliedByObjectiveID: [String: Int]) {
        var damage = damageByObjectiveID
        var applied: [String: Int] = [:]
        guard budget > 0, let route = routes[lane] else { return (damage, applied) }

        let remaining = remainingPower(maxPowers: maxPowers, damageByObjectiveID: damageByObjectiveID)
        var remainingBudget = budget
        for objectiveID in route {
            guard remainingBudget > 0 else { break }
            let absorbed = min(remaining[objectiveID, default: 0], remainingBudget)
            guard absorbed > 0 else { continue }
            damage[objectiveID, default: 0] += absorbed
            applied[objectiveID, default: 0] += absorbed
            remainingBudget -= absorbed
        }
        return (damage, applied)
    }
}

/// Persisted per-city siege progress (HPA-468). The forgiving half of the
/// siege model: owners clamp damage to authored maxima and discard unknown
/// objective IDs; the authored layout is the fail-closed half.
struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
    /// Highcrest Guard reinforcement state (HPA-469); nil for every
    /// non-pilot city. Normalized by the owning game state.
    var guardReinforcements: GuardReinforcementProgress?

    init(
        selectedLane: BattleLane,
        damageByObjectiveID: [String: Int],
        guardReinforcements: GuardReinforcementProgress? = nil
    ) {
        self.selectedLane = selectedLane
        self.damageByObjectiveID = damageByObjectiveID
        self.guardReinforcements = guardReinforcements
    }

    private enum CodingKeys: String, CodingKey {
        case selectedLane
        case damageByObjectiveID
        case guardReinforcements
    }

    /// Forgiving decode: a malformed present `guardReinforcements` payload
    /// drops to nil (the owner's normalization re-seeds it) instead of
    /// throwing away the sibling lane/damage progress with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedLane = try container.decode(BattleLane.self, forKey: .selectedLane)
        damageByObjectiveID = try container.decode([String: Int].self, forKey: .damageByObjectiveID)
        guardReinforcements = (try? container.decodeIfPresent(
            GuardReinforcementProgress.self,
            forKey: .guardReinforcements
        )) ?? nil
    }
}

/// One unresolved Guard snapshot in persisted siege progress (HPA-469).
/// Deliberately minimal — lane and remaining HP only; no IDs or positions.
struct GuardSnapshot: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
}

/// Persisted Highcrest Guard reinforcement state (HPA-469). The forgiving
/// half: the owning game state clamps values back into the authored tuning
/// ranges (see `normalizedForHighcrest` beside the Highcrest authoring).
struct GuardReinforcementProgress: Codable, Equatable {
    var waveElapsedSeconds: Double
    var remainingReserve: Int
    var unresolvedGuards: [GuardSnapshot]
}
