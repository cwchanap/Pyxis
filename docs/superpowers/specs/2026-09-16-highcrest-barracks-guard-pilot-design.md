# HPA-469 Highcrest Barracks + Guard Pilot Design

**Status:** Reviewed planning direction for implementation on the same PR  
**Linear:** HPA-469 — Highcrest Barracks + Guard pilot  
**Baseline:** `main` at `76f5e6b836acab5e48f6c27ab107049e1811ba18` (merged HPA-468)

## Goal

Prove one enemy-reinforcement mechanic in City 5, Highcrest, without creating a second combat engine, generic wave system, or enemy-AI framework.

Highcrest gets exactly one destructible Barracks and one enemy Guard type. While the Barracks lives, it periodically adds Guards to the currently selected assault lane. Guards approach from the enemy fortress, block allied soldiers, fight automatically, and remain after the Barracks is destroyed. Destroying the Barracks prevents all future Guard spawns; destroying the Keep still wins immediately.

This remains one implementation PR. Design, pure models, persistence, live combat, shared idle/Camp settlement, scene integration, tests, tuning, and gameplay evidence land together. HPA-476 remains the only final image/animation-production task.

## Review-locked constraints

1. Extend the HPA-468 seams: `CitySiegeLayout`, `SiegeProgress`, `BattleCombatState`, `KingdomGameState`, and `BattleScene`. Do not add a wave service, target registry, behavior tree, ECS, pathfinder, physics combat, or second simulator.
2. Keep HP remains the only conquest/liveness authority.
3. Barracks destruction only stops future reinforcement spawns. Existing Guards survive until defeated or Keep conquest.
4. Guard production is finite: **2 Guards / 6 seconds, max 4 living Guards on the lane being reinforced, 8 total reserve across the siege**. Reserve is consumed only by Guards actually spawned.
5. A lane-cap-blocked wave consumes no reserve and does not queue an extra burst. The six-second phase continues; the next attempt is the next aligned wave opportunity after capacity exists.
6. New Guards use the assault lane selected when they spawn. Existing Guards never change lane after a later lane selection. Other-lane Guards do not consume the selected lane's four-Guard cap.
7. New and restored Guards start at the Keep's authored `visualProgress` on their lane, not at the Barracks structure position. The Barracks stays the left-side shutdown objective; reinforcement actors come from the fortress so direct-route armies cannot walk past their spawn point.
8. Opposing actors cannot pass through each other. Guards never attack the player's castle/camp, repair structures, steal resources, or reclaim cities.
9. Idle/Camp/Map catch-up stays bounded and approximate. Reuse the existing 8-hour cap, 1/10 building-production rate, no-buildings/no-progress rule, at-most-one-city conquest, and exactly-once report/reward routing.
10. Both background idle resolution and in-Camp/build-upgrade settlement use one shared private chronological settlement helper. Do not implement two Guard walkers.
11. Guard-only combat changes must persist even when no `SoldierAttackEvent` hits a structure. Reuse existing save cadence rather than saving every frame.
12. Development save breaks are acceptable. Do not add a migration or save-version layer.
13. No generated art in HPA-469. Only procedural placeholders and stable runtime asset/action contracts are allowed.

## Highcrest authored layout

Use the smallest shape that makes the Barracks decision readable: **Keep + Barracks only**. Do not add another Gate or Arrow Tower merely to justify the encounter.

Highcrest already has the lane profile:

- left = exposed;
- center = fortified;
- right = standard.

Use right as the default lane, preserving the existing standard-lane default.

| Objective | Stable ID | Weight | Visual position | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `highcrest.keep` | 4 | center / `1.0` | conquest target and Guard actor spawn/restore progress |
| Barracks | `highcrest.barracks` | 1 | left / `0.62` | optional reinforcement shutdown target |

Routes:

- **Left / exposed:** `highcrest.barracks -> highcrest.keep`
- **Center / fortified:** `highcrest.keep`
- **Right / standard:** `highcrest.keep`

Highcrest's current City 5 durability budget is 427. The 4:1 starting weights allocate **342 Keep / 85 Barracks** while preserving the existing total budget exactly. The Barracks-first route therefore pays the full 427 damage but can permanently shut off Guard pressure; the direct routes pay 342 structure damage but leave the Barracks active until conquest.

Keep the existing `.arrowTower` city defense trait. For this pilot, `defensiveFire.sourceObjectiveID` remains `highcrest.keep`, which matches today's single-Keep behavior and avoids adding another structure.

## Highcrest-local reinforcement tuning

Keep the mechanic local and explicit rather than data-driving a generic wave system.

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 6.0
    static let maxActiveGuardsPerLane = 4
    static let totalReserve = 8

    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}
```

These are starting values. The implementation PR may retune only these local Guard numbers and Highcrest's 4:1 durability weights if the required same-camp comparison shows an obvious stall or an irrelevant Barracks. Do not add another mechanic to solve balance.

## Authored siege model and Scout copy

Extend `CitySiegeLayout.ObjectiveKind` with only:

```swift
case barracks
```

Keep stable objective IDs as persistence identity. Add only a convenience lookup for the optional Barracks; do not add a generalized structure registry.

Construction stays fail-closed:

- all HPA-468 layout invariants remain;
- a pilot layout may contain **at most one** `.barracks` objective;
- the Barracks lookup is optional so non-pilot cities remain valid;
- `CityDefinition` documentation must no longer claim Falconridge is the only custom-layout city.

The existing Scout tactical footer derives from every non-Keep objective, so Highcrest must explicitly support the new closed enum case:

```text
L Barracks
```

`CountryMapScoutCardContent.ObjectiveKind.tacticalName` adds `Barracks`, and the existing measured/fail-closed Scout acceptance path must prove the Highcrest footer presents at compact-phone geometry. Do not add another tutorial surface.

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

`KingdomGameState.normalizedSiegeProgress` remains the single forgiving normalization seam and must materialize the correct shape instead of accidentally dropping reinforcement progress when it reconstructs `SiegeProgress`.

Normalization rules:

- reserve clamps to `0...8`;
- wave elapsed normalizes into `0..<6`;
- Guard HP clamps to `1...12`;
- keep at most four persisted Guards per lane and at most eight unresolved Guards total, preserving order;
- every Guard keeps its persisted lane;
- Barracks destruction does not erase unresolved Guards or refill reserve;
- entering the next city creates fresh siege/reinforcement progress;
- non-Highcrest cities normalize `guardReinforcements` to `nil`;
- pending-result state does not fabricate new waves.

Persisted Guard IDs, positions, animation state, and projectiles are deliberately omitted. On scene reconstruction, each unresolved Guard receives a fresh transient ID and starts at `layout.keepObjective.visualProgress` on its persisted lane.

## Live wave scheduling

`KingdomGameState` owns the durable wave clock and reserve because scene replacement/relaunch must not grant free resets.

Add one focused mutation:

```swift
mutating func advanceActiveGuardReinforcements(deltaTime: Double) -> [GuardSnapshot]
```

It is available only for active Highcrest sieges with a living Keep and living Barracks. For each due six-second opportunity it:

1. counts living unresolved Guards only on `siegeProgress.selectedLane`;
2. computes available slots against `maxActiveGuardsPerLane`;
3. appends `min(2, availableSlots, remainingReserve)` full-HP snapshots on the selected lane;
4. consumes reserve only for appended Guards;
5. advances the six-second phase even when the lane cap blocks a wave, so blocked waves do not queue;
6. returns only newly appended snapshots so `BattleScene` can mirror them into transient combat.

The reserve remains global. Therefore a lane switch can leave four Guards on the old lane while later waves reinforce the new lane, but at most eight Guards can ever spawn across the entire siege.

### Live-frame ownership and persistence

`BattleScene.advanceCombat(deltaTime:)` owns the integration order. Keep the existing player-building production behavior, then:

```text
player building spawns
-> BattleCombatState.tick (tower fire still resolves first inside tick)
-> feedback.emitAutomaticCombat(result)
-> apply structure/soldier/Guard result to KingdomGameState
-> synchronize combat.guardSnapshots into SiegeProgress
-> advance Guard waves with combat.clampedDeltaTime(deltaTime)
-> spawn returned Guards into BattleCombatState
-> persist durable progress and sync nodes/HUD
```

Guard snapshot synchronization and wave advancement must live outside `applyCombatResult`'s existing `soldierAttacks.isEmpty` early return. A tick where allies only damage Guards still needs Guard HP persisted.

Do not save every frame. Broaden the existing two-second BattleScene progress-save throttle so Guard wave elapsed state is covered even when there are no player buildings, while Guard HP changes, Guard deaths, structure hits, and actual Guard spawns save immediately through the existing mutation/persistence path.

Barracks destruction during a tick is applied before wave advancement, so it cannot produce a same-frame late wave.

## Guard combat in `BattleCombatState`

Keep `BattleCombatState` as the only live actor simulator. Add one `Guard` actor array and transient `GuardID`; do not build an enemy hierarchy.

A Guard stores only ID, lane, HP, position, and attack cooldown. Its combat numbers come from `HighcrestGuardRules`.

### Spawn / restore progress

Actors and structure geometry have separate jobs:

- Barracks renders at `highcrest.barracks.visualProgress == 0.62`;
- newly spawned Guards start at `snapshot.layout.keepObjective.visualProgress` on the selected lane;
- restored Guards also start at Keep progress because positions are intentionally not persisted;
- a right/center army already past `0.62` must still meet later reinforcement waves near the Keep.

Do not reuse the Barracks structure position as an actor spawn position.

### Lane-local contact rule

For each lane:

- a soldier considers only living Guards in its lane;
- if a Guard lies between that soldier and its next structure objective, that Guard blocks the soldier;
- the soldier stops at Guard range and attacks the Guard before the structure;
- Guards move downward toward the foremost living allied soldier in their lane and stop in Guard attack range;
- neither movement step may cross the opposing actor;
- after the blocking Guard dies, surviving soldiers resume normal HPA-468 structure targeting;
- Guards never acquire a target from another lane and never continue toward the player castle when their lane has no allied soldier.

Same-team spacing/formations remain out of scope.

### Tick ordering

Preserve HPA-468's existing tower-first behavior. Do not rewrite the tick as a new phase engine.

Within `tick(deltaTime:siege:)`:

1. resolve the existing defensive tower shot/cooldown exactly where it runs today;
2. resolve lane-local soldier/Guard blocker movement;
3. resolve living Guard attacks;
4. resolve still-living allied attacks against a Guard blocker first, otherwise the first live structure on the route;
5. prune dead Guards/soldiers and emit events;
6. Keep death remains immediate conquest and stops later work.

An actor killed earlier in the actor phase does not act later in the same tick. With `guards.isEmpty`, existing HPA-468 movement/attack behavior must remain unchanged.

### Small event surface

Reuse existing `damagedSoldierIDs` and `soldierLosses` for allied hit/loss presentation. Add only what Guard rendering needs:

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

`TickResult` adds `guardAttacks`, `guardHits`, and `guardLosses`. Structure-hit `SoldierAttackEvent` remains structure-only; Guard damage does not become city damage or battle-report damage.

`AutomaticCombatFeedbackScheduler` treats Guard attack/hit activity as candidates for the existing melee/hit sound IDs. Do not add a new feedback category or sound asset.

## Shared idle / Camp / Map settlement

Do not frame-simulate Guards offline and do not implement separate idle and Camp walkers.

Both `settleCurrentCityBuildingProgress(at:)` and `resolveCurrentCityBuildingIdleProgress(at:)` call one private chronological helper, for example:

```swift
private mutating func resolveCurrentCityBuildingSettlement(
    elapsedSeconds: Double,
    cityState: inout CityBattleState,
    conquestMode: ConquestMode
) -> (applied: Int, conquered: Bool, goldEarned: Int)
```

The helper reuses `resolveBuildingSpawns(in:effectiveActiveSeconds:)` as the production primitive and advances events in time order.

### Event walk

Relevant events are:

- the next player building-production event;
- the next **spawnable** Guard wave opportunity while Keep/Barracks live, reserve remains, and the selected lane has a free Guard slot;
- Keep destruction;
- the capped settlement end.

Rules:

1. retain the existing 8-hour real-time cap and 1/10 player building-production scaling;
2. when time advances, keep the persisted Guard wave phase aligned to six-second opportunities;
3. if the selected lane is at its Guard cap, arithmetically skip repeated blocked wave boundaries until the next player-production event or settlement end rather than iterating thousands of empty six-second slices;
4. when a player `BuildingSpawn` resolves, spend its trait-adjusted damage against unresolved Guards on `siegeProgress.selectedLane`, oldest snapshot first;
5. only after no same-lane Guard blocker remains may leftover damage continue through `CitySiegeLayout.spendDamageBudget` on the selected lane;
6. at a spawnable wave opportunity, call the same `advanceActiveGuardReinforcements` rules used by live combat; do not copy cap/reserve logic into the settlement helper;
7. if Barracks dies, resolve remaining production with no future Guard-wave events;
8. stop immediately when Keep HP reaches zero and reuse the existing exactly-once conquest/reward/report path.

The finite reserve bounds **successful Guard spawns to eight**, not the number of potential six-second boundaries. Do not claim “at most four checkpoints.”

Preserve the existing no-buildings/no-progress rule: if there is no player building production to resolve, offline/Camp settlement does not advance Guard waves in isolation.

Lane-selection settlement still happens before changing `selectedLane`, so the shared helper resolves the old lane first; later live waves use the newly selected lane.

## Presentation

### Barracks

Add one local `BattleScene` procedural Barracks builder using the authored objective position. It has:

- its own objective HP bar;
- intact state while spawning is possible;
- obvious ruined/disabled state after destruction;
- one compact attached reserve label while alive (`GUARDS 8` -> `GUARDS 0`) and `SHUT DOWN` after destruction.

No separate enemy-wave HUD or inspector is added.

### Guards

Use a procedural enemy silhouette structurally distinct from allied troops: helmet/head + shield/body composition, enemy-facing orientation, and separate node structure. Team recognition must not rely on tint alone.

Guard nodes observe model state only. Animation never controls attack timing or damage. Reduced-motion/static presentation remains understandable.

### Runtime art handoff to HPA-476

Extend the existing `SiegeObjectiveAssetContract` rather than inventing an asset manifest:

```text
siege-barracks — bottom-center — intact, ruined/disabled
siege-guard    — feet/bottom-center — resting, walk, attack, hit
```

Defeat may use a procedural fade and the Barracks spawn cue may remain procedural. HPA-476 chooses final source dimensions, generated art, frames, prompts, and polish under these names/contracts.

Existing City 5 Forged/Camp fixtures must be re-smoked because Highcrest now has authored Barracks state. Do not let the new layout silently change unrelated fixture assumptions.

## Testing and evidence

### Authored model / Scout tests

Cover:

- Highcrest layout IDs, routes, 4:1 allocation, standard default lane, one-Barracks invariant, and Barracks lookup;
- `L Barracks` Scout copy through the existing compact measured/fail-closed path;
- `SiegeObjectiveAssetContract.barracks == "siege-barracks"`;
- non-Highcrest `guardReinforcements == nil`;
- `normalizedSiegeProgress` preserves/clamps Highcrest reinforcement progress instead of dropping it.

### Wave / persistence tests

Cover:

- wave timing, finite reserve, per-selected-lane active cap, and selected-lane assignment;
- **four left Guards + switch right + six seconds -> two right Guards, reserve decreases by two**;
- cap-blocked wave consumes no reserve and does not queue a burst;
- Barracks shutdown stops future waves while old Guards remain;
- save/load round-trip preserves elapsed phase, reserve, lanes, and HP;
- reconstruction starts persisted Guards at Keep progress without healing them.

### Combat tests

Cover:

- right-lane army already past Barracks progress still intercepts a new Guard spawned at Keep progress;
- opposing contact/range, no pass-through, automatic Guard/allied attacks, blocker death, and resume toward structures;
- Guard cannot cross lanes or attack the player castle;
- tower shot order remains unchanged;
- `guards.isEmpty` retains current HPA-468 behavior;
- immediate Keep victory does not require Guard cleanup.

### Idle/lifecycle tests

Cover:

- both background idle and Camp/build-upgrade settlement use the shared helper;
- unresolved same-lane Guards absorb production damage before structures;
- cap-blocked intervals collapse rather than iterating every six-second boundary;
- Barracks destruction stops later offline waves;
- no buildings means no offline progress or Guard-wave advancement;
- tab/relaunch reconstruction does not heal Guards, refill reserve, or restart wave phase;
- exactly-once reward/report and at-most-one-city conquest remain unchanged.

### BattleScene / feedback tests

Cover:

- Guard-only ticks synchronize HP to `SiegeProgress` even when `soldierAttacks` is empty;
- Guard wave elapsed is covered by the existing two-second save throttle with no player building present;
- Guard attacks/hits map to existing automatic melee/hit sounds;
- Barracks destroyed in a combat tick cannot spawn a same-frame wave;
- `siege-barracks` intact/shutdown placeholder states and Guard placeholders reconstruct correctly;
- existing City 5 Forged/Camp fixtures still hold.

### Running evidence

Capture Highcrest on the existing 393x852 reference, a compact supported phone, and portrait iPad. Show:

1. direct-route reinforcements meeting an army that has passed Barracks progress;
2. pressure while the Barracks survives;
3. Barracks-first destruction and `SHUT DOWN` state;
4. no subsequent spawn after at least one full six-second interval;
5. surviving Guards still fighting after shutdown;
6. one lane switch demonstrating old-lane Guards do not suppress new-lane reinforcement;
7. final Keep advance/conquest;
8. one non-pilot city retaining HPA-468 behavior.

Use one identical deterministic camp/loadout for a **right direct push** versus **left Barracks-first** comparison. Record elapsed time, allied losses, Guards spawned/defeated, and Barracks shutdown time. Retune only Highcrest weights or `HighcrestGuardRules` if one route is an obvious free choice, both routes stall, or Barracks destruction has no visible consequence.

## Risks resolved by this design

### Spawn-behind on direct routes

Barracks structure geometry is left/0.62, but Guard actors spawn/restore from Keep progress. Direct-route columns therefore cannot permanently outrun reinforcement waves.

### Lane-switch cap stranding

The four-Guard cap is per reinforced lane, while reserve is global. Old-lane Guards remain honest obstacles if the player returns, but they cannot disable reinforcement on a newly selected lane.

### Guard-only state loss

Guard snapshot synchronization sits in `advanceCombat`, outside the structure-attack early return, and the existing save cadence is broadened to include wave elapsed progress.

### Divergent idle vs Camp semantics

Both settlement callers use one private chronological helper and the same wave mutation. There is no second Guard ruleset to drift.

## Deliberate cuts

No additional enemy classes, multiple Barracks, enemy rewards, Guard loot/gold, formations, threat tables, pathfinding, physics, Guard attacks on the player castle, repairs, regeneration, resource theft, city reclamation, boss phases, generic wave configuration, runtime asset manifest, telemetry, save migration, per-city generated art, or HPA-475 hero/Rally work.
