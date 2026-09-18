//
//  Country1CityCatalog.swift
//  Pyxis
//

enum Country1CityCatalog {
    static let cityRange = 1...15

    /// The authored order is also the lookup index. A duplicated fortified /
    /// exposed lane is a programmer error and fails through
    /// `LaneDefenseProfile`'s invariant precondition during static initialization.
    static let definitions: [CityDefinition] = [
        CityDefinition(
            cityNumber: 1,
            name: "Willowford",
            flavorText: "A quiet crossing where the campaign begins.",
            conquestTitle: "Willowford Secured",
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 2,
            name: "Pinewatch",
            flavorText: "A hill watchtown guarding the old trade road.",
            conquestTitle: "Pinewatch Secured",
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 3,
            name: "Falconridge",
            flavorText: "Arrow towers command the high ridge road.",
            conquestTitle: "Falconridge Silenced",
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    .init(
                        id: "falconridge.keep",
                        kind: .keep,
                        durabilityWeight: 3,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "falconridge.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 4,
                        visualLane: .left,
                        visualProgress: 0.68
                    ),
                    .init(
                        id: "falconridge.ridge-gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.58
                    )
                ],
                routes: [
                    .left: ["falconridge.arrow-tower", "falconridge.keep"],
                    .center: ["falconridge.ridge-gate", "falconridge.keep"],
                    .right: ["falconridge.ridge-gate", "falconridge.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(sourceObjectiveID: "falconridge.arrow-tower", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 4,
            name: "Bramblegate",
            flavorText: "Iron spikes guard a narrow frontier gate.",
            conquestTitle: "Bramblegate Broken",
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 5,
            name: "Highcrest",
            flavorText: "A proud hill fortress crowns the frontier.",
            conquestTitle: "Highcrest Falls",
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    .init(id: "highcrest.keep", kind: .keep, durabilityWeight: 4,
                          visualLane: .center, visualProgress: 1.0),
                    .init(id: "highcrest.barracks", kind: .barracks, durabilityWeight: 1,
                          visualLane: .left, visualProgress: 0.62)
                ],
                routes: [
                    .left: ["highcrest.barracks", "highcrest.keep"],
                    .center: ["highcrest.keep"],
                    .right: ["highcrest.keep"]
                ],
                defaultLane: .right,
                defensiveFire: .init(sourceObjectiveID: "highcrest.keep", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 6,
            name: "Granite Pass",
            flavorText: "Stone walls seal the mountain road ahead.",
            conquestTitle: "Granite Pass Open",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 7,
            name: "Emberford",
            flavorText: "Burning oil guards the bridge inland.",
            conquestTitle: "Emberford Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .ember
        ),
        CityDefinition(
            cityNumber: 8,
            name: "Greywall",
            flavorText: "Layered stone walls protect a busy town.",
            conquestTitle: "Greywall Falls",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 9,
            name: "Runewatch",
            flavorText: "Arcane wards shimmer over the night road.",
            conquestTitle: "Runewatch Unbound",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .arcane
        ),
        CityDefinition(
            cityNumber: 10,
            name: "Ironthorn Gate",
            flavorText: "A hardened gate blocks the inner road.",
            conquestTitle: "Ironthorn Gate Broken",
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 11,
            name: "Kingshield Keep",
            flavorText: "A reinforced fortress guards the royal road.",
            conquestTitle: "Kingshield Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 12,
            name: "Ashbridge",
            flavorText: "Fire cauldrons guard the last crossing.",
            conquestTitle: "Ashbridge Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .ember
        ),
        CityDefinition(
            cityNumber: 13,
            name: "Starveil Citadel",
            flavorText: "Arcane wards protect the capital heights.",
            conquestTitle: "Starveil Citadel Falls",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .arcane
        ),
        CityDefinition(
            cityNumber: 14,
            name: "Stonecrown",
            flavorText: "Massive stone walls ring the royal seat.",
            conquestTitle: "Stonecrown Breached",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier
        ),
        CityDefinition(
            cityNumber: 15,
            name: "Crownspire Keep",
            flavorText: "The final keep rises above the capital.",
            conquestTitle: "Crownspire Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .royal
        )
    ]

    static func definition(for cityNumber: Int) -> CityDefinition {
        let clampedCityNumber = min(max(cityRange.lowerBound, cityNumber), cityRange.upperBound)
        return definitions[clampedCityNumber - cityRange.lowerBound]
    }

    /// Non-clamping display fallback lookup. Returns `nil` for city numbers
    /// outside `cityRange`; gameplay must keep using the clamped
    /// `definition(for:)`.
    static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
        guard cityRange.contains(cityNumber) else { return nil }
        return definitions[cityNumber - cityRange.lowerBound]
    }
}

/// Highcrest-only Guard reinforcement tuning (HPA-469 pilot). These City 5
/// values live beside the Highcrest authoring, not in generic siege state.
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    /// Tuned by the HPA-469 Task 6 balance evidence: at the starting 6.0s the
    /// whole 8-Guard reserve deployed by t=24s — long before the exposed
    /// route could destroy the Barracks (~58s) — so shutdown visibly canceled
    /// nothing. 20.0s spreads the four waves across 20/40/60/80s and leaves
    /// reserve unspent at typical shutdown times.
    static let waveIntervalSeconds = 20.0
    static let totalReserve = 8
    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}

extension GuardReinforcementProgress {
    /// Fresh full-reserve progress for a newly entered Highcrest.
    static func freshHighcrest() -> GuardReinforcementProgress {
        GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: HighcrestGuardRules.totalReserve,
            unresolvedGuards: []
        )
    }

    /// Forgiving normalization for persisted Highcrest Guard state: elapsed
    /// wraps into 0..<`waveIntervalSeconds`, reserve clamps to 0...8 and to
    /// the 8-total budget against retained Guards, Guard HP clamps to
    /// 1...12, and at most the first 8 snapshots are retained in order
    /// (lanes preserved; no IDs or positions are persisted).
    func normalizedForHighcrest() -> GuardReinforcementProgress {
        let elapsed = max(0, waveElapsedSeconds)
            .truncatingRemainder(dividingBy: HighcrestGuardRules.waveIntervalSeconds)
        let guards = unresolvedGuards.prefix(HighcrestGuardRules.totalReserve).map { snapshot in
            GuardSnapshot(
                lane: snapshot.lane,
                remainingHP: min(max(1, snapshot.remainingHP), HighcrestGuardRules.maxHP)
            )
        }
        let reserveCeiling = HighcrestGuardRules.totalReserve - guards.count
        return GuardReinforcementProgress(
            waveElapsedSeconds: elapsed,
            remainingReserve: min(max(0, remainingReserve), reserveCeiling),
            unresolvedGuards: guards
        )
    }
}
