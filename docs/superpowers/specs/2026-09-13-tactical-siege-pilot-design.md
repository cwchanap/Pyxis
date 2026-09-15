# HPA-468 Tactical Siege Pilot Design

**Status:** Approved planning direction for implementation on the same PR  
**Linear:** HPA-468 — Tactical siege pilot: destructible objectives and assault lanes  
**Baseline:** `main` at `957a4ae8ddb7de50b3c03858eeaeaef35f8a2260`

## Goal

Make City 3, Falconridge, the smallest playable proof that a siege is about choosing an approach and dismantling defenses instead of reducing one global HP bar.

The player selects one of the existing three lanes. New manual and building-produced soldiers use that lane, automatically advance through that lane's authored objectives, and continue when an objective falls. Falconridge has a Keep, one Arrow Tower, and one shared Ridge Gate. Destroying the Tower permanently stops its fire. Destroying the Keep ends the siege even if an optional defense remains.

This remains one implementation PR. Design, implementation, tests, and gameplay evidence all land on the same branch.

## Review-locked rules

1. **Keep HP is the only conquest/liveness/tick-stop authority.** Aggregate durability is only an allocation budget.
2. **Every Country 1 production spawn uses the selected lane.** There is no production RNG lane-spawn fallback.
3. **`CitySiegeLayout` fails closed at construction.** Authored catalog errors do not silently normalize.
4. **All three Battle lanes have a non-empty route.** The selector cannot choose a lane with no target.
5. **Objective geometry has one authority.** Movement, defensive-fire origin, and rendering all read `Objective.visualProgress`; routes contain objective IDs only.
6. **Stable objective IDs remain the persistence identity.** `ObjectiveKind` describes behavior/rendering, not identity; later layouts may legitimately contain multiple Gates/Towers.
7. **Defensive fire range is source-relative.** `inRange = soldier.position >= max(0, sourceProgress - towerAttackRange)`.
8. **`CityDefenseTrait` is city-wide and independent of objective liveness.** Destroying the Arrow Tower stops defensive fire only.
9. **Scout tactical copy is a measured fit contract.** It must pass the existing fail-closed Scout path.
10. **No final compatibility HP API remains.** The implementation plan may keep the old scalar temporarily during intermediate commits solely to keep each checkpoint compilable, then deletes it before completion.

## Falconridge product shape

Use the lower end of HPA-468's allowed structure envelope:

| Objective | Stable ID | Weight | Visual position | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `falconridge.keep` | 4 | center / `1.0` | conquest target |
| Arrow Tower | `falconridge.arrow-tower` | 2 | left / `0.68` | destructible defensive-fire source |
| Ridge Gate | `falconridge.ridge-gate` | 2 | spans center + right / `0.58` | shared blocker |

City 3's existing durability budget is 92. The required ticket contract is to redistribute that budget, not give each structure a full city's HP. The 4:2:2 allocation therefore remains:

- Keep: 46 HP
- Arrow Tower: 23 HP
- Ridge Gate: 23 HP

Any integer allocation remainder for future layouts goes to the Keep.

### Per-route cost is intentionally lower than today's scalar city

The new player-facing route cost is not the sum of every structure in the city. Each Falconridge route requires one blocker plus the Keep:

- left: Tower 23 + Keep 46 = **69 damage**;
- center: Gate 23 + Keep 46 = **69 damage**;
- right: Gate 23 + Keep 46 = **69 damage**.

Today's City 3 scalar requires 92 damage, so the initial authored route cost is about **25% lower**. That is an intentional pilot starting point under HPA-468's fixed 92 total-durability contract, not an invisible claim of balance parity.

At the same time, source-relative Tower range increases exposure: the Tower is at `0.68`, so with current `towerAttackRange == 0.55` defensive fire begins at normalized progress `0.13`; the old Keep-relative source began at `0.45`. The pilot can therefore be cheaper in raw objective damage while exposing troops to defensive fire for longer.

Task 6 records a current-`main` City 3 baseline from the same camp/loadout before implementation, then compares left and center. If either new route is an obvious free choice versus baseline, or one new route Pareto-dominates the other, retune only Falconridge objective weights / existing defensive-fire values while keeping the **total authored durability budget at 92**. Do not add another mechanic or inflate every structure to full-city HP.

### Authored routes

Falconridge keeps the existing lane profile: left exposed, center standard, right fortified. Default selection is center.

- **Left — tower-first:** `falconridge.arrow-tower → falconridge.keep`
- **Center — gate-first:** `falconridge.ridge-gate → falconridge.keep`
- **Right — gate-first / fortified:** `falconridge.ridge-gate → falconridge.keep`

The shared Gate is not rendered as a center-lane-only object. `BattleScene` derives every lane whose route contains `falconridge.ridge-gate` and renders one barrier spanning the center/right approaches, including its ruined state. This keeps the right-lane blocker visually honest without adding duplicate Gate state.

## Authored siege model

Add one framework-free value beside `CityDefinition`:

```swift
struct CitySiegeLayout: Equatable {
    enum ObjectiveKind: Equatable {
        case keep
        case gate
        case arrowTower
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

    let objectives: [Objective]
    let routes: [BattleLane: [String]]
    let defaultLane: BattleLane
    let defensiveFire: DefensiveFire
}
```

A route stores only ordered objective IDs. There is no `RouteStep.progress`; movement, scene placement, and defensive-fire origin all resolve the referenced objective and use its `visualProgress`.

### Construction invariants

`CitySiegeLayout.init` preconditions authored data in the same spirit as `LaneDefenseProfile`:

- objective IDs are unique and non-empty;
- exactly one objective is `.keep`;
- every durability weight is positive;
- every objective `visualProgress` is within `0...1`;
- `routes` contains **exactly** `BattleLane.allCases`;
- every route is non-empty, references only existing objective IDs, and ends at the one Keep;
- route objective progress is non-decreasing so soldiers never target backward along a lane;
- `defaultLane` is one of those routes;
- `defensiveFire.sourceObjectiveID` exists;
- defensive-fire coverage is non-empty and contains no duplicate lane;
- `.singleKeep(defaultLane:)` creates the only non-Falconridge shape and cannot emit invalid data.

Persisted progress is forgiving; authored catalog data is not.

### Stable ID vs `ObjectiveKind`

Keep `damageByObjectiveID: [String: Int]`. Do **not** key persistence by `ObjectiveKind`.

Reasons:

- HPA-468 explicitly requires stable authored objective IDs;
- the ticket permits one or two Gates, and HPA-477 may author repeated kinds later;
- `.gate` / `.arrowTower` are categories, not unique identities;
- stable IDs let one route share one exact object and let future layouts distinguish `gate-west` from `gate-east` without another persistence rewrite.

Tests should use layout lookup/test support rather than scattering literal IDs through unrelated suites. Unknown persisted IDs are discarded during normalization.

`Country1CityCatalog` remains the only authoring site. Other Country 1 cities use `.singleKeep(defaultLane: laneDefenseProfile.standardLane)` with all three routes targeting the same Keep at `1.0` and the Keep as the defensive-fire source.

## Persisted siege progress

```swift
struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
}
```

`KingdomGameState` owns one current/pending `siegeProgress`; `KingdomGameStore` stays generic JSON plumbing.

Rules:

- fresh city = authored default lane + zero damage;
- damage clamps to authored objective max;
- unknown objective IDs are discarded on normalization;
- pending-result state retains progress long enough to restore truthful Battle presentation;
- entering the next city creates fresh progress for its layout;
- no completed-city objective history is retained afterward;
- `siegeProgress` is explicitly encoded/decoded by `KingdomGameState`;
- old development saves may reset; no migration/converter/versioning layer.

## HP authority

Final production code exposes:

- `currentKeepRemainingPower`;
- `currentKeepMaxPower`;
- existing `cityMaxPower` only as the authored **allocation budget**.

Do not retain a total-objective remaining production API. If aggregate sums help tests, compute them in `PyxisTests/SiegeTestSupport.swift`.

All player-facing battle HP uses Keep current/max:

- Forged Battle progress;
- Keep sprite HP bar;
- city tooltip;
- Living Kingdom fortress stage.

Gate/Tower use their own objective HP treatment. A fresh Falconridge fortress is `46/46`, not `46/92`, and Gate/Tower damage cannot visually damage the Keep.

## Shared route rule

One small pure helper beside the siege values serves both live and idle paths:

1. resolve the first living objective ID for a lane;
2. spend a positive damage budget along that ordered route, carrying remainder only after an objective dies.

No graph, pathfinder, target registry, service, behavior tree, ECS, or second combat engine.

## Live combat

`BattleCombatState` remains the only transient live-actor simulator. `KingdomGameState` supplies an ephemeral snapshot containing the authored layout and current objective HP. The combat state may mutate a local copy during one tick to prevent same-tick overkill, then returns objective-aware events; it never persists objective damage itself.

### Soldier flow

- every spawn requires an explicit lane;
- manual and building-produced production both pass `state.siegeProgress.selectedLane`;
- no optional/random spawn behavior remains;
- already-deployed soldiers keep their lane;
- each soldier targets the first living ID in its own route;
- target position is resolved from that objective's `visualProgress`;
- movement stops at `visualProgress - attackRange`;
- attack events carry `objectiveID` + actual applied damage;
- if an earlier soldier destroys a target, later soldiers in the same tick may resolve the next route objective.

`TickResult.didReachConquest` means the local Keep reached zero. `TickResult.cityDamage` is removed because an objective-aware tick has no single meaningful city-damage field.

### Defensive fire

The authored fire source replaces the unconditional global tower:

- source must still be alive;
- source progress is its `Objective.visualProgress`;
- target lane must be in authored coverage;
- range is `position >= max(0, sourceProgress - towerAttackRange)`;
- reuse current cooldown, foremost-target selection, occupied-lane random choice, base damage, and lane multipliers;
- Falconridge Tower death permanently stops fire;
- non-pilot Keep sources at `1.0` preserve the existing range origin.

The projectile visual starts at the actual defensive-fire source position/node. Falconridge shots visibly leave the Arrow Tower at `0.68`; single-Keep cities still originate at the Keep.

### Trait independence

Falconridge's `.arrowTower` `CityDefenseTrait` remains active after the destructible Tower dies. Tower death disables defensive fire only; favorable/disadvantaged soldier→objective multipliers still apply to later Gate/Keep damage.

## Kingdom state mutations and idle settlement

`applyLiveSoldierAttacks` validates objective IDs, clamps actual objective damage, records existing siege attribution, updates `SiegeProgress`, and completes immediately when **Keep remaining HP** reaches zero. It never waits for optional structures and never fabricates their destruction.

Idle/Camp/Map settlement keeps the 8-hour cap, 1/10 building-production rate, no-buildings/no-progress rule, at-most-one-city conquest, and existing reward/report routing. Each abstract building spawn becomes one trait-adjusted damage budget spent down the selected route. A live blocker prevents Keep damage; spillover happens only when the blocker dies.

### Lane selection result

The model owns settle-before-select and returns an explicit result:

```swift
enum AssaultLaneSelectionResult: Equatable {
    case unavailable
    case unchanged(idleProgress: IdleProgressResult)
    case selected(idleProgress: IdleProgressResult)
    case conqueredDuringSettlement(IdleProgressResult)
}
```

`selectAssaultLane(_:at:)` first settles any armed inactive interval using the **old** lane. If that settlement conquers the Keep, selection does not change and the scene gets `.conqueredDuringSettlement`. Otherwise it reports unchanged/selected explicitly. An ordinary Battle tap with no armed interval produces no synthetic work.

## Country-wide lane control

The selector applies to all Country 1 cities:

- fresh city defaults to `laneDefenseProfile.standardLane`;
- every new manual/building spawn uses the selected lane;
- exposed/fortified lanes retain current `0.80×` / `1.25×` incoming defensive-fire pressure;
- existing soldiers never move when selection changes.

City 1 acceptance pins default standard-lane spawn, selected exposed-lane spawn/damage, and deployed-soldier stability. There is no hidden legacy RNG pressure path.

## Battle UI

Reuse `BattleHUDNode` lane chips and `BattleChromeLayout` as the sole geometry authority.

- keep existing 26pt visual `laneChipFrames`;
- add 44×44+ `laneChipHitFrames`, derived/clamped inside the battlefield like medallion hit frames;
- `BattleHUDContent` carries selected lane + Keep HP current/max;
- all three lanes are selectable;
- exposed/fortified keep OPEN/HELD role treatment;
- exactly one selected lane gets the procedural flag / `ASSAULT` treatment;
- Settings, Deploy, medallions, tabs, info frames, and conquest Continue remain isolated from lane selection.

## Objective presentation

Keep `enemy-city` as the Keep. `BattleScene` adds only local procedural Gate/Tower builders and HP/ruin treatment.

- Arrow Tower is placed from its authored left/`0.68` objective position;
- Ridge Gate derives all routes containing its ID and spans the center/right approaches at `0.58`;
- ruined Gate spans those same lanes;
- Tower coverage disappears when the Tower dies;
- destroyed state rebuilds from persisted progress after tab changes/relaunch;
- Tower projectiles originate at the Tower, not `enemyGatePoints[lane]`.

Do not add a generic scene-object framework.

## Scout hint

Keep the existing Scout card/action. Falconridge uses a concise measured tactical footer such as:

`L Tower · C/R Gate`

Other cities retain `Open: <lane>`.

`CountryMapScoutCardNode` measures/fits the chosen footer against the existing `exposedLaneFrame` using the existing text-fit approach and an explicit minimum size. Compact-phone tests must prove Falconridge still presents. If the copy cannot fit at the floor, adjust that existing footer geometry; do not add another screen.

## HPA-476 art handoff

HPA-468 generates no final image/animation assets. It defines only stable runtime names/state/anchor semantics:

- `siege-gate` — bottom-center anchor, intact/ruined;
- `siege-arrow-tower` — bottom-center anchor, intact/ruined;
- `siege-assault-flag` — bottom-center anchor, selected only.

Do **not** pre-author source pixel canvas dimensions here. HPA-476 chooses the smallest real source size that stays crisp at the actual render height once final art exists.

## Risks and checkpoints

### Incremental compile risk

Deleting `cityRemainingPower` before Battle/HUD/fixture readers move would make Tasks 2–4 unverifiable. The implementation plan therefore introduces the new authority additively, switches readers, then performs one final deletion checkpoint. Every task gate must build the app target.

### Falconridge balance swing

The fixed 92 allocation yields 69 raw route damage while source-relative fire starts much earlier. Capture the current-`main` City 3 baseline before implementation and compare elapsed time/losses from identical camp state after implementation. Retune only Falconridge weights/fire inside the 92 total if the new routes are free/dominant or Tower destruction is unnoticeable.

### Shared-Gate legibility

One state object blocks two routes. Render the Gate spanning the center/right approaches and pin it with scene geometry tests plus compact-phone/iPad smoke. Do not discover this only during final gameplay capture.

### Migration blast radius

Scalar HP and `appliedCityDamage` appear throughout tests. Introduce `SiegeTestSupport` before mechanical rewrites, keep focused suites broad enough to cover affected feedback/lifecycle/controller tests, and finish with a zero-reference cleanup gate.

## Deliberate cuts

Not in HPA-468:

- enemy soldiers/Barracks/Guards;
- player Captain/Rally;
- enemy attacks on the player's camp;
- new currencies/per-objective loot;
- wards, depots, extra Tower behaviors;
- procedural map/editor/pathfinding;
- arbitrary movement/unit selection;
- campaign-wide recipe rollout;
- new report/target inspector;
- telemetry;
- migration/backward compatibility;
- generic combat/effect/VFX framework;
- final generated art.

## Acceptance

HPA-468 is done when:

- Falconridge visibly supports Tower-first and Gate-first routes;
- every selected lane has a valid route and every new production spawn uses it;
- shared Gate is visually legible from both center and right;
- Tower death stops defensive fire and projectile origin is visually correct;
- city-wide `.arrowTower` soldier multipliers remain after Tower death;
- live and idle paths respect the same blockers/spillover;
- Keep death ends the siege while optional structures may survive;
- objective damage + selected lane survive save/load/tab/lifecycle/relaunch;
- player-facing HP/Living Kingdom use Keep only;
- non-pilot cities run through the same one-Keep objective path;
- Falconridge Scout tactical footer fits supported compact geometry;
- current-main baseline plus same-camp left/center comparison demonstrates a meaningful, non-free route tradeoff after any needed Falconridge-only tuning;
- final production contains no `cityRemainingPower`, `appliedCityDamage`, or `TickResult.cityDamage` compatibility residue;
- no final art is generated in this PR.
