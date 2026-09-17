# HPA-469 Highcrest Barracks + Guard Pilot Design

**Status:** Planning direction for implementation on the same PR  
**Linear:** HPA-469 — Highcrest Barracks + Guard pilot  
**Baseline:** `main` at `76f5e6b836acab5e48f6c27ab107049e1811ba18` (merged HPA-468)

## Goal

Prove one enemy-reinforcement mechanic in City 5, Highcrest, without creating a second combat engine, generic wave system, or enemy-AI framework.

Highcrest gets exactly one destructible Barracks and one enemy Guard type. While the Barracks lives, it periodically adds Guards to the currently selected assault lane. Guards block allied soldiers, fight automatically, and remain after the Barracks is destroyed. Destroying the Barracks prevents all future Guard spawns; destroying the Keep still wins immediately.

This remains one implementation PR. Design, pure models, persistence, live combat, idle settlement, scene integration, tests, and gameplay evidence land together. HPA-476 remains the only final image/animation-production task.

## Review-locked constraints

1. Extend the HPA-468 seams: `CitySiegeLayout`, `SiegeProgress`, `BattleCombatState`, `KingdomGameState`, and `BattleScene`. Do not add a wave service, target registry, behavior tree, ECS, pathfinder, physics combat, or second simulator.
2. Keep HP remains the only conquest/liveness authority.
3. Barracks destruction only stops future reinforcement spawns. Existing Guards survive until defeated or Keep conquest.
4. Guard waves are finite: **2 Guards / 6 seconds, max 4 active, 8 total reserve**. Reserve is consumed only by Guards actually spawned.
5. A wave blocked by the active cap consumes no blocked reserve; it waits for the next six-second wave opportunity.
6. New Guards use the assault lane selected when they spawn. Existing Guards never change lane after a later lane selection.
7. Opposing actors cannot pass through each other. Guards never attack the player's castle/camp, repair structures, steal resources, or reclaim cities.
8. Idle/Camp/Map catch-up stays bounded and approximate. Reuse the existing 8-hour cap, 1/10 building-production rate, at-most-one-city conquest, and exactly-once report/reward routing.
9. Development save breaks are acceptable. Do not add a migration or save-version layer.
10. No generated art in HPA-469. Only procedural placeholders and stable runtime asset/action contracts are allowed.

## Highcrest authored layout

Use the smallest shape that makes the Barracks decision readable: **Keep + Barracks only**. Do not add another Gate or Arrow Tower unless the final running-game comparison demonstrates that the Barracks choice is unreadable without one.

Highcrest already has the lane profile:

- left = exposed;
- center = fortified;
- right = standard.

Use right as the default lane, preserving the existing standard-lane default.

| Objective | Stable ID | Weight | Visual position | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `highcrest.keep` | 4 | center / `1.0` | conquest target |
| Barracks | `highcrest.barracks` | 1 | left / `0.62` | optional reinforcement shutdown target |

Routes:

- **Left / exposed:** `highcrest.barracks -> highcrest.keep`
- **Center / fortified:** `highcrest.keep`
- **Right / standard:** `highcrest.keep`

Highcrest's current City 5 durability budget is 427. The 4:1 starting weights allocate **342 Keep / 85 Barracks** while preserving the existing total budget exactly. The Barracks-first route therefore pays the full 427 damage but can permanently shut off Guard pressure; the direct routes pay 342 structure damage but leave the Barracks active until conquest.

Keep the existing `.arrowTower` city defense trait. For this pilot, `defensiveFire.sourceObjectiveID` remains `highcrest.keep`, which matches today's single-Keep behavior and avoids adding another structure merely to justify the trait.

## Highcrest-local reinforcement tuning

Keep the mechanic intentionally local and explicit rather than data-driving a generic wave system.

Add a small pure constant namespace beside the siege values:

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 6.0
    static let maxActiveGuards = 4
    static let totalReserve = 8

    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}
```

These are the starting values for the pilot. The implementation PR may retune only these local Guard numbers and Highcrest's 4:1 durability weights if the required same-camp comparison shows an obvious stall or an irrelevant Barracks. Do not introduce a new mechanic to solve balance.

## Authored siege model

Extend `CitySiegeLayout.ObjectiveKind` with only:

```swift
case barracks
```

The layout remains the single source of structure identity and geometry. Add a convenience lookup for the optional Barracks, but do not add a generalized structure registry.

The HPA-468 construction invariants remain in force. For the current pilot, authored layouts may contain at most one Barracks. Non-Highcrest cities remain unchanged.

## Persisted reinforcement progress

Keep reinforcement state inside the current siege progress rather than creating another repository or save object.

```swift
struct GuardSnapshot: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
}

struct GuardReinforcementProgress: Codable, Equatable {
    var waveElapsedSeconds: Double
    var remainingReserve: Int
    var unresolvedGuards: [GuardSnapshot]
}

struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
    var guardReinforcements: GuardReinforcementProgress?
}
```

Fresh Highcrest starts with elapsed `0`, reserve `8`, and no Guards. Other cities use `nil`.

Normalization is intentionally small:

- reserve clamps to `0...8`;
- wave elapsed clamps to `0..<6`;
- Guard HP clamps to `1...12`;
- persisted Guards beyond the four-active cap are dropped from the tail;
- every Guard keeps its persisted lane;
- Barracks destruction does not erase unresolved Guards or refill reserve;
- entering the next city creates fresh siege/reinforcement progress;
- pending-result state may retain the snapshots until the existing result lifecycle is acknowledged.

Persisted Guard IDs and positions are deliberately omitted. On scene reconstruction, each unresolved Guard receives a fresh transient ID and starts at the Barracks' authored `visualProgress` on its persisted lane.

## Live wave scheduling

`KingdomGameState` owns the durable wave clock and reserve because scene replacement/relaunch must not grant free resets.

Add one focused mutation such as:

```swift
mutating func advanceActiveGuardReinforcements(deltaTime: Double) -> [GuardSnapshot]
```

It is available only for active Highcrest sieges with a living Keep and living Barracks. It advances the persisted clock, attempts a wave every six seconds, appends at most the available active slots, subtracts reserve only for appended Guards, and returns only the newly spawned snapshots so `BattleScene` can mirror them into the transient combat state.

### Frame ordering

Order each Battle frame as follows:

1. resolve existing player building spawns;
2. tick `BattleCombatState` using the current structure/Guard snapshot;
3. apply structure attacks and Guard/soldier losses to `KingdomGameState`;
4. synchronize the combat state's living Guard snapshots back into `SiegeProgress`;
5. only then advance the reinforcement clock and create due Guards if the Keep and Barracks still live;
6. mirror new Guards into `BattleCombatState`, save, and refresh presentation.

This ordering guarantees that a Barracks destroyed during the current combat tick cannot emit a same-frame "late" wave.

## Guard combat in `BattleCombatState`

Keep `BattleCombatState` as the only live actor simulator. Add one `Guard` actor array and transient `GuardID`; do not build an enemy hierarchy.

A Guard stores only the fields needed by the pilot: ID, lane, HP, position, attack cooldown. Its combat numbers come from `HighcrestGuardRules`.

### Lane-local contact rule

For each lane:

- the closest living Guard ahead of allied troops is the blocker;
- an allied soldier targets that Guard before any structure on its route;
- allied movement clamps at `guard.position - soldier.attackRange`;
- the Guard moves downward only toward the foremost living allied soldier in its lane and clamps at `soldier.position + guardAttackRange`;
- when in range, the Guard attacks that allied soldier automatically;
- after the blocker dies, surviving allied soldiers resume normal HPA-468 objective targeting on the next tick;
- Guards never acquire a target from another lane and never continue toward the player castle if their lane has no allied soldier.

Same-team formation/spacing is explicitly out of scope. Multiple Guards may visually cluster; the requirement is only that opposing actors do not cross.

Use deterministic tick ordering: movement first, then living Guard attacks, then living allied attacks. An actor killed earlier in that tick does not act later in the tick.

### Small event surface

Reuse existing `damagedSoldierIDs` and `soldierLosses` for allied hit/loss presentation. Add only what Guard rendering needs, for example:

```swift
struct GuardAttackEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

struct GuardHitEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

struct GuardLossEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let lane: BattleLane
}
```

`TickResult` adds arrays for those events. Structure-hit `SoldierAttackEvent` remains structure-only; Guard damage does not become city damage or battle-report damage.

## Idle / Camp / Map settlement

Do not frame-simulate Guards offline. Reuse the existing `CityBattleState` building timers and `resolveBuildingSpawns` helper in bounded chronological segments around reinforcement-wave boundaries.

Algorithm:

1. keep the existing 8-hour cap and convert each real-time segment to `segment / idleBuildingProductionScale` before resolving player building production;
2. spend each returned building spawn's trait-adjusted damage against unresolved Guards in the selected lane first;
3. only after no unresolved blocker remains may the leftover damage continue through `CitySiegeLayout.spendDamageBudget` for the selected lane;
4. at each six-second Guard-wave boundary, if the Barracks still lives, add up to two Guards subject to the four-active cap and remaining reserve;
5. if the Barracks dies, resolve the remaining capped time without future Guard-wave checkpoints;
6. stop immediately when Keep HP reaches zero and reuse the existing exactly-once conquest/reward/report path.

Because the entire siege can consume at most eight Guards, settlement needs at most four wave checkpoints plus one final production segment. This is bounded work regardless of an eight-hour absence.

Preserve the existing no-buildings/no-progress rule: if there is no player building production to resolve, offline settlement returns `.none` and does not advance Guard waves in isolation.

Lane-selection settlement continues to happen before changing `selectedLane`, so old-lane Guards/waves resolve against the old selection and later live waves use the new one.

## Presentation

### Barracks

Add one local `BattleScene` procedural Barracks builder using the authored objective position. It has:

- its own objective HP bar;
- intact state while spawning is possible;
- obvious ruined/disabled state after destruction;
- a compact attached reserve label while alive (`GUARDS 8` -> `GUARDS 0`) and `SHUT DOWN` after destruction.

No separate enemy-wave HUD or inspector is added.

### Guards

Use a procedural enemy silhouette that is structurally distinct from allied troops: helmet/head + shield/body shape, enemy-facing orientation, and a separate node composition. Team recognition must not rely on tint alone.

Guard nodes observe model state only. Animation never controls attack timing or damage. Reduced-motion/static presentation remains understandable.

### Runtime art handoff to HPA-476

HPA-469 defines these stable placeholder contracts only:

| Asset | Anchor | Runtime states/actions |
| --- | --- | --- |
| `siege-barracks` | bottom-center | intact, ruined/disabled |
| `siege-guard` | bottom-center / feet | resting fallback, walk, attack, hit; defeat may use procedural fade |

A Barracks spawn cue may remain procedural. HPA-476 chooses final source dimensions, generated art, frames, prompts, and polish under these names/contracts.

## Testing and evidence

### Pure model tests

Cover:

- Highcrest layout IDs, routes, 4:1 allocation, standard default lane, and Barracks lookup;
- wave timing, partial-cap waves, reserve consumption, finite reserve, selected-lane assignment, shutdown, and old Guards surviving shutdown;
- save/load round-trip for elapsed wave time, reserve, lanes, and HP;
- Guard contact/range, no pass-through, automatic Guard/allied attacks, blocker death, resume toward structures, and immediate Keep victory.

### Idle/lifecycle tests

Cover:

- unresolved Guards absorb idle production before structures;
- wave boundaries can add finite Guards during settlement;
- active cap does not consume blocked reserve;
- Barracks destruction stops later offline waves;
- no buildings means no offline progress;
- tab/relaunch reconstruction does not heal Guards, refill reserve, or reset the wave clock;
- exactly-once reward/report and at-most-one-city conquest remain unchanged.

### Scene tests / running evidence

Capture Highcrest on the existing 393x852 reference, a compact supported phone, and portrait iPad. Show:

1. first Guard wave meeting the army;
2. pressure while the Barracks survives;
3. Barracks-first destruction and `SHUT DOWN` state;
4. no subsequent spawn after at least one full six-second interval;
5. surviving Guards still fighting after shutdown;
6. final Keep advance/conquest;
7. one non-pilot city retaining HPA-468 behavior.

Use one identical deterministic camp/loadout for a **right direct push** versus **left Barracks-first** comparison. Record elapsed time, allied losses, Guards spawned/defeated, and Barracks shutdown time. Retune only Highcrest weights or `HighcrestGuardRules` if one route is an obvious free choice, both routes stall, or Barracks destruction has no visible consequence.

## Deliberate cuts

No additional enemy classes, multiple Barracks, enemy rewards, Guard loot/gold, formations, threat tables, pathfinding, physics, Guard attacks on the player castle, repairs, regeneration, resource theft, city reclamation, boss phases, generic wave configuration, runtime asset manifest, telemetry, save migration, per-city generated art, or HPA-475 hero/Rally work.
