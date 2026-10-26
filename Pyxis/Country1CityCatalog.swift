//
//  Country1CityCatalog.swift
//  Pyxis
//

import Foundation

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
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 3:1 Keep:Gate HP (15 + 5 of 20): the Keep is the majority and the
                    // conquest authority; the gate adds unfired HP on the left/center routes.
                    .init(
                        id: "willowford.keep",
                        kind: .keep,
                        durabilityWeight: 3,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "willowford.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.76
                    )
                ],
                routes: [
                    .left: ["willowford.gate", "willowford.keep"],
                    .center: ["willowford.gate", "willowford.keep"],
                    .right: ["willowford.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(sourceObjectiveID: "willowford.keep", coveredLanes: [.right])
            )
        ),
        CityDefinition(
            cityNumber: 2,
            name: "Pinewatch",
            flavorText: "A hill watchtown guarding the old trade road.",
            conquestTitle: "Pinewatch Secured",
            defenseTrait: .standardWatch,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 3:1 Keep:Gate HP (28 + 9 of 37): the Keep is the majority and the
                    // conquest authority. The Gate is shared by the left and right detours,
                    // a tie that breaks to the left lane.
                    .init(
                        id: "pinewatch.keep",
                        kind: .keep,
                        durabilityWeight: 3,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "pinewatch.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.76
                    )
                ],
                routes: [
                    .left: ["pinewatch.gate", "pinewatch.keep"],
                    .center: ["pinewatch.keep"],
                    .right: ["pinewatch.gate", "pinewatch.keep"]
                ],
                defaultLane: .right,
                defensiveFire: .init(sourceObjectiveID: "pinewatch.keep", coveredLanes: [.center])
            )
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
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 3:1:1 Keep:Gate:East Gate HP (77 + 25 + 25 of 127): the Keep is the
                    // majority and the conquest authority. The shared Gate sits on the centre
                    // lane (the left and centre routes both pass it); the East Gate is the
                    // right route's own chokepoint.
                    .init(
                        id: "bramblegate.keep",
                        kind: .keep,
                        durabilityWeight: 3,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "bramblegate.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.76
                    ),
                    .init(
                        id: "bramblegate.east-gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.82
                    )
                ],
                routes: [
                    .left: ["bramblegate.gate", "bramblegate.keep"],
                    .center: ["bramblegate.gate", "bramblegate.keep"],
                    .right: ["bramblegate.east-gate", "bramblegate.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(sourceObjectiveID: "bramblegate.keep", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 5,
            name: "Highcrest",
            flavorText: "A proud hill fortress crowns the frontier.",
            conquestTitle: "Highcrest Falls",
            defenseTrait: .arrowTower,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .right),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // Route-balance pass (round 2): 20:1 weights put the
                    // Barracks at 11 power, so the Barracks-first shutdown
                    // lands well before the first 30s Guard wave and
                    // cancels the whole remaining reserve, while direct
                    // routes face every wave against a 223-power Keep.
                    .init(id: "highcrest.keep", kind: .keep, durabilityWeight: 20,
                          visualLane: .center, visualProgress: 1.0),
                    .init(id: "highcrest.barracks", kind: .barracks, durabilityWeight: 1,
                          visualLane: .left, visualProgress: 0.72)
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
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 6:2:3 Keep:Gate:Tower HP (237 + 78 + 118 of 433): the Keep is the
                    // majority and the conquest authority. The Tower sits between the Gate and
                    // the Keep share and is the only fire source, covering every lane. The
                    // shared Gate sits on the centre lane (left and centre routes).
                    .init(
                        id: "granite-pass.keep",
                        kind: .keep,
                        durabilityWeight: 6,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "granite-pass.gate",
                        kind: .gate,
                        durabilityWeight: 2,
                        visualLane: .center,
                        visualProgress: 0.76
                    ),
                    .init(
                        id: "granite-pass.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 3,
                        visualLane: .right,
                        visualProgress: 0.80
                    )
                ],
                routes: [
                    .left: ["granite-pass.gate", "granite-pass.keep"],
                    .center: ["granite-pass.gate", "granite-pass.keep"],
                    .right: ["granite-pass.arrow-tower", "granite-pass.keep"]
                ],
                defaultLane: .left,
                defensiveFire: .init(sourceObjectiveID: "granite-pass.arrow-tower", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 7,
            name: "Emberford",
            flavorText: "Burning oil guards the bridge inland.",
            conquestTitle: "Emberford Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .ember,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 20:4:1 Keep:Gate:Barracks HP (642 + 128 + 32 of 802): the Keep is 20:1
                    // over the Barracks, the Highcrest ratio. The Barracks sits on the left
                    // route, which the Keep's fire covers, so its chewers stay in reach. The
                    // Gate sits on the centre route, which takes no fire.
                    .init(
                        id: "emberford.keep",
                        kind: .keep,
                        durabilityWeight: 20,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "emberford.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.72
                    ),
                    .init(
                        id: "emberford.gate",
                        kind: .gate,
                        durabilityWeight: 4,
                        visualLane: .center,
                        visualProgress: 0.80
                    )
                ],
                routes: [
                    .left: ["emberford.barracks", "emberford.keep"],
                    .center: ["emberford.gate", "emberford.keep"],
                    .right: ["emberford.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(sourceObjectiveID: "emberford.keep", coveredLanes: [.left, .right])
            )
        ),
        CityDefinition(
            cityNumber: 8,
            name: "Greywall",
            flavorText: "Layered stone walls protect a busy town.",
            conquestTitle: "Greywall Falls",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 6:3:2 Keep:Tower:Gate HP (810 + 404 + 269 of 1483): the Keep is the
                    // majority and the conquest authority. The Tower sits between the Gate and
                    // the Keep share and is the only fire source, covering every lane. The
                    // shared Gate sits on the centre lane (centre and right routes). The default
                    // is the exposed Tower route: at the realistic budget camp both Gate routes
                    // stall, because the Tower's fire kills every soldier before a Gate falls.
                    .init(
                        id: "greywall.keep",
                        kind: .keep,
                        durabilityWeight: 6,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "greywall.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 3,
                        visualLane: .left,
                        visualProgress: 0.80
                    ),
                    .init(
                        id: "greywall.gate",
                        kind: .gate,
                        durabilityWeight: 2,
                        visualLane: .center,
                        visualProgress: 0.77
                    )
                ],
                routes: [
                    .left: ["greywall.arrow-tower", "greywall.keep"],
                    .center: ["greywall.gate", "greywall.keep"],
                    .right: ["greywall.gate", "greywall.keep"]
                ],
                defaultLane: .left,
                defensiveFire: .init(sourceObjectiveID: "greywall.arrow-tower", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 9,
            name: "Runewatch",
            flavorText: "Arcane wards shimmer over the night road.",
            conquestTitle: "Runewatch Unbound",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .arcane,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:1:1 Keep:Barracks:Tower HP (2574 + 85 + 85 of 2744): the Keep is the
                    // conquest authority. The small Barracks lets a Barracks-first attack shut the
                    // Guards down before the first 30 s wave. The Tower is the single fire source,
                    // covering every lane, and the right route's only stop.
                    .init(
                        id: "runewatch.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "runewatch.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.72
                    ),
                    .init(
                        id: "runewatch.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.80
                    )
                ],
                routes: [
                    .left: ["runewatch.barracks", "runewatch.keep"],
                    .center: ["runewatch.keep"],
                    .right: ["runewatch.arrow-tower", "runewatch.keep"]
                ],
                defaultLane: .left,
                defensiveFire: .init(sourceObjectiveID: "runewatch.arrow-tower", coveredLanes: BattleLane.allCases)
            )
        ),
        CityDefinition(
            cityNumber: 10,
            name: "Ironthorn Gate",
            flavorText: "A hardened gate blocks the inner road.",
            conquestTitle: "Ironthorn Gate Broken",
            defenseTrait: .spikedGate,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 10:3:2:2 Keep:Tower:Gate:East Gate HP (2988 + 895 + 597 + 597 of 5077):
                    // the Keep is the conquest authority. The Tower is the single fire source,
                    // covering every lane. The left route runs through the Tower; the centre and
                    // right routes each have their own Gate.
                    .init(
                        id: "ironthorn-gate.keep",
                        kind: .keep,
                        durabilityWeight: 10,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "ironthorn-gate.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 3,
                        visualLane: .left,
                        visualProgress: 0.80
                    ),
                    .init(
                        id: "ironthorn-gate.gate",
                        kind: .gate,
                        durabilityWeight: 2,
                        visualLane: .center,
                        visualProgress: 0.78
                    ),
                    .init(
                        id: "ironthorn-gate.east-gate",
                        kind: .gate,
                        durabilityWeight: 2,
                        visualLane: .right,
                        visualProgress: 0.84
                    )
                ],
                routes: [
                    .left: ["ironthorn-gate.arrow-tower", "ironthorn-gate.keep"],
                    .center: ["ironthorn-gate.gate", "ironthorn-gate.keep"],
                    .right: ["ironthorn-gate.east-gate", "ironthorn-gate.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(
                    sourceObjectiveID: "ironthorn-gate.arrow-tower",
                    coveredLanes: BattleLane.allCases
                )
            )
        ),
        CityDefinition(
            cityNumber: 11,
            name: "Kingshield Keep",
            flavorText: "A reinforced fortress guards the royal road.",
            conquestTitle: "Kingshield Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:3:1:1 Keep:Tower:Gate:Barracks HP (8051 + 805 + 268 + 268 of 9392):
                    // the Keep is the conquest authority. The Tower is the single fire source,
                    // covering every lane, and the left route's only stop. The centre Gate is the
                    // centre route's only stop. The Barracks is the right route's only stop and the
                    // Guard source that the default lane shuts down.
                    .init(
                        id: "kingshield-keep.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "kingshield-keep.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 3,
                        visualLane: .left,
                        visualProgress: 0.80
                    ),
                    .init(
                        id: "kingshield-keep.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.82
                    ),
                    .init(
                        id: "kingshield-keep.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.72
                    )
                ],
                routes: [
                    .left: ["kingshield-keep.arrow-tower", "kingshield-keep.keep"],
                    .center: ["kingshield-keep.gate", "kingshield-keep.keep"],
                    .right: ["kingshield-keep.barracks", "kingshield-keep.keep"]
                ],
                defaultLane: .right,
                defensiveFire: .init(
                    sourceObjectiveID: "kingshield-keep.arrow-tower",
                    coveredLanes: BattleLane.allCases
                )
            )
        ),
        CityDefinition(
            cityNumber: 12,
            name: "Ashbridge",
            flavorText: "Fire cauldrons guard the last crossing.",
            conquestTitle: "Ashbridge Secured",
            defenseTrait: .burningOil,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .ember,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:1:1:1 Keep:Gate:Barracks:Tower HP (15797 + 526 + 526 + 526 of 17375):
                    // the Keep is the conquest authority. The Tower is the single fire source,
                    // covering every lane, and the right route's only stop. The Gate is the left
                    // route's only stop, and the Barracks is the centre route's only stop. The
                    // flame identity stays in the burning-oil defense trait.
                    .init(
                        id: "ashbridge.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "ashbridge.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.80
                    ),
                    .init(
                        id: "ashbridge.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.72
                    ),
                    .init(
                        id: "ashbridge.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.83
                    )
                ],
                routes: [
                    .left: ["ashbridge.gate", "ashbridge.keep"],
                    .center: ["ashbridge.barracks", "ashbridge.keep"],
                    .right: ["ashbridge.arrow-tower", "ashbridge.keep"]
                ],
                defaultLane: .left,
                defensiveFire: .init(
                    sourceObjectiveID: "ashbridge.arrow-tower",
                    coveredLanes: BattleLane.allCases
                )
            )
        ),
        CityDefinition(
            cityNumber: 13,
            name: "Starveil Citadel",
            flavorText: "Arcane wards protect the capital heights.",
            conquestTitle: "Starveil Citadel Falls",
            defenseTrait: .arcaneWard,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .left, exposedLane: .right),
            visualFamily: .arcane,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:1:1:1 Keep:Gate:Barracks:East Gate HP (29221 + 974 + 974 + 974 of 32143):
                    // the Keep is the conquest authority and the only fire source, covering every lane.
                    // The Barracks is the centre (standard) route's only stop; each Gate guards one
                    // flank route. The arcane ward stays in the defense trait.
                    .init(
                        id: "starveil-citadel.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "starveil-citadel.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.80
                    ),
                    .init(
                        id: "starveil-citadel.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.72
                    ),
                    .init(
                        id: "starveil-citadel.east-gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.83
                    )
                ],
                routes: [
                    .left: ["starveil-citadel.gate", "starveil-citadel.keep"],
                    .center: ["starveil-citadel.barracks", "starveil-citadel.keep"],
                    .right: ["starveil-citadel.east-gate", "starveil-citadel.keep"]
                ],
                defaultLane: .center,
                defensiveFire: .init(
                    sourceObjectiveID: "starveil-citadel.keep",
                    coveredLanes: BattleLane.allCases
                )
            )
        ),
        CityDefinition(
            cityNumber: 14,
            name: "Stonecrown",
            flavorText: "Massive stone walls ring the royal seat.",
            conquestTitle: "Stonecrown Breached",
            defenseTrait: .stoneWall,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .center, exposedLane: .left),
            visualFamily: .frontier,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:1:2:1 Keep:Gate:Tower:East Gate HP (52472 + 1748 + 3497 + 1748 of 59465):
                    // the Keep is the conquest authority. The Tower is the single fire source, covering
                    // every lane, and the centre route's only stop. The left and right Gates each guard
                    // one flank route; the right route is the standard lane and never reaches the Tower.
                    .init(
                        id: "stonecrown.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "stonecrown.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .left,
                        visualProgress: 0.77
                    ),
                    .init(
                        id: "stonecrown.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 2,
                        visualLane: .center,
                        visualProgress: 0.82
                    ),
                    .init(
                        id: "stonecrown.east-gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.84
                    )
                ],
                routes: [
                    .left: ["stonecrown.gate", "stonecrown.keep"],
                    .center: ["stonecrown.arrow-tower", "stonecrown.keep"],
                    .right: ["stonecrown.east-gate", "stonecrown.keep"]
                ],
                defaultLane: .right,
                defensiveFire: .init(
                    sourceObjectiveID: "stonecrown.arrow-tower",
                    coveredLanes: BattleLane.allCases
                )
            )
        ),
        CityDefinition(
            cityNumber: 15,
            name: "Crownspire Keep",
            flavorText: "The final keep rises above the capital.",
            conquestTitle: "Crownspire Keep Falls",
            defenseTrait: .reinforcedKeep,
            laneDefenseProfile: LaneDefenseProfile(fortifiedLane: .right, exposedLane: .center),
            visualFamily: .royal,
            siegeLayout: CitySiegeLayout(
                objectives: [
                    // 30:2:1:1:1 Keep:Tower:Barracks:Gate:East Gate HP (94296 + 6286 + 3143 +
                    // 3143 + 3143 of 110011): the Keep is the conquest authority. The Tower is the
                    // single fire source, covering every lane, and the left route's first stop. The
                    // Barracks is the centre route's first stop. The Gate stands before the Keep on
                    // the left and centre routes, and the East Gate is the right route's only stop.
                    .init(
                        id: "crownspire-keep.keep",
                        kind: .keep,
                        durabilityWeight: 30,
                        visualLane: .center,
                        visualProgress: 1.0
                    ),
                    .init(
                        id: "crownspire-keep.arrow-tower",
                        kind: .arrowTower,
                        durabilityWeight: 2,
                        visualLane: .left,
                        visualProgress: 0.78
                    ),
                    .init(
                        id: "crownspire-keep.gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.84
                    ),
                    .init(
                        id: "crownspire-keep.barracks",
                        kind: .barracks,
                        durabilityWeight: 1,
                        visualLane: .center,
                        visualProgress: 0.72
                    ),
                    .init(
                        id: "crownspire-keep.east-gate",
                        kind: .gate,
                        durabilityWeight: 1,
                        visualLane: .right,
                        visualProgress: 0.82
                    )
                ],
                routes: [
                    .left: ["crownspire-keep.arrow-tower", "crownspire-keep.gate", "crownspire-keep.keep"],
                    .center: ["crownspire-keep.barracks", "crownspire-keep.gate", "crownspire-keep.keep"],
                    .right: ["crownspire-keep.east-gate", "crownspire-keep.keep"]
                ],
                defaultLane: .left,
                defensiveFire: .init(
                    sourceObjectiveID: "crownspire-keep.arrow-tower",
                    coveredLanes: BattleLane.allCases
                )
            )
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

/// Country 1 Guard reinforcement rules (HPA-469). One fixed set of values
/// shared by every Country 1 city that authors a Barracks; there is no
/// per-city scaling. The values were first tuned on the City 5 (Highcrest)
/// pilot and are a starting reference, not a guarantee for later cities.
enum Country1GuardRules {
    static let guardsPerWave = 2
    /// City 5 (Highcrest) pilot rationale, a starting reference and not a
    /// late-city guarantee. Tuned by the Highcrest route-balance pass (round 2):
    /// the Barracks objective holds only 11 power (weights 20:1 with the Keep),
    /// so the typical Barracks-first shutdown lands before the first 30s
    /// wave and cancels the whole unspent reserve. Direct-route armies keep the
    /// Barracks alive, so all six waves (12 Guards) deploy against them; that
    /// asymmetry closes the route-dominance gap while honoring the shutdown
    /// consequence.
    static let waveIntervalSeconds = 30.0
    static let totalReserve = 12
    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.28
    static let movementSpeed = 0.30
}

extension GuardReinforcementProgress {
    /// Fresh full-reserve Guard progress for a newly entered Country 1 city with a Barracks.
    static func freshCountry1() -> GuardReinforcementProgress {
        GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: Country1GuardRules.totalReserve,
            unresolvedGuards: []
        )
    }

    /// Forgiving normalization for persisted Country 1 Guard state: elapsed
    /// wraps into 0..<`waveIntervalSeconds`, reserve clamps into
    /// 0...`totalReserve` and to the total budget against retained Guards,
    /// Guard HP clamps to 1...`maxHP`, and at most the first `totalReserve`
    /// snapshots are retained in order (lanes preserved; no IDs or positions
    /// are persisted).
    func normalizedForCountry1() -> GuardReinforcementProgress {
        let elapsed = max(0, waveElapsedSeconds)
            .truncatingRemainder(dividingBy: Country1GuardRules.waveIntervalSeconds)
        let guards = unresolvedGuards.prefix(Country1GuardRules.totalReserve).map { snapshot in
            GuardSnapshot(
                lane: snapshot.lane,
                remainingHP: min(max(1, snapshot.remainingHP), Country1GuardRules.maxHP)
            )
        }
        let reserveCeiling = Country1GuardRules.totalReserve - guards.count
        return GuardReinforcementProgress(
            waveElapsedSeconds: elapsed,
            remainingReserve: min(max(0, remainingReserve), reserveCeiling),
            unresolvedGuards: guards
        )
    }
}

/// Vanguard Captain tuning (HPA-475): one automatic hero deploying from
/// City 3 onward. These Country 1 values live beside the combat authoring,
/// not in generic siege state. Captain attack/HP scale from the camp-derived
/// captain level (HPA-582) — these are starting values, not a new
/// progression axis.
enum VanguardCaptainRules {
    static let unlockCity = 3
    static let recoverySeconds = 12.0
    static let rallyDurationSeconds = 5.0
    static let rallyDamageMultiplier = 0.70

    static func isAvailable(cityNumber: Int) -> Bool {
        cityNumber >= unlockCity
    }

    /// One attack point above the ordinary soldier curve.
    static func attackPower(for upgradeLevel: Int) -> Int {
        KingdomGameState.normalSoldierAttackPower(for: upgradeLevel) + 1
    }

    static func maxHP(for upgradeLevel: Int) -> Int {
        let level = max(1, upgradeLevel)
        return max(1, Int((20 * pow(1.25, Double(level - 1))).rounded()))
    }
}

extension VanguardCaptainProgress {
    /// Fresh full-HP Captain for a newly entered City 3+ siege, seeded on
    /// the entry-selected lane.
    static func freshCaptain(selectedLane: BattleLane, upgradeLevel: Int) -> VanguardCaptainProgress {
        VanguardCaptainProgress(
            lane: selectedLane,
            remainingHP: VanguardCaptainRules.maxHP(for: upgradeLevel),
            recoveryRemainingSeconds: 0,
            rallyConsumed: false
        )
    }

    /// Forgiving normalization for persisted Captain state: keeps the lane
    /// and Rally consumption, clamps HP >= 0 and recovery into
    /// 0...`recoverySeconds`, and forces recovery to 0 while HP > 0 (an
    /// alive captain is not recovering).
    func normalizedForCaptain() -> VanguardCaptainProgress {
        let hp = max(0, remainingHP)
        var recovery = min(
            max(0, recoveryRemainingSeconds),
            VanguardCaptainRules.recoverySeconds
        )
        if hp > 0 {
            recovery = 0
        }
        return VanguardCaptainProgress(
            lane: lane,
            remainingHP: hp,
            recoveryRemainingSeconds: recovery,
            rallyConsumed: rallyConsumed
        )
    }
}
