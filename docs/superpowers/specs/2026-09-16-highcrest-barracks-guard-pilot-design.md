# HPA-469 Highcrest Barracks + Guard Pilot Design

**Status:** Reviewed planning direction for implementation on the same PR  
**Linear:** HPA-469 — Highcrest Barracks + Guard pilot  
**Baseline:** `main` at `76f5e6b836acab5e48f6c27ab107049e1811ba18` (merged HPA-468)

## Goal

Prove one enemy-reinforcement mechanic in City 5, Highcrest, without creating a second combat engine, generic wave system, or enemy-AI framework.

Highcrest gets exactly one destructible Barracks and one enemy Guard type. While the Barracks lives, it periodically sends a finite reserve of Guards into the currently selected assault lane. Guards approach from the enemy fortress, block allied soldiers, fight automatically, and remain after the Barracks is destroyed. Destroying the Barracks prevents future Guard spawns; destroying the Keep still wins immediately.

This remains one implementation PR. Design, pure models, persistence, live combat, idle/Camp settlement, scene integration, tests, tuning, and gameplay evidence land together. HPA-476 remains the only final image/animation-production task.

## Review-locked constraints

1. Extend the HPA-468 seams: `CitySiegeLayout`, `SiegeProgress`, `BattleCombatState`, `KingdomGameState`, and `BattleScene`. Do not add a wave service, target registry, behavior tree, ECS, pathfinder, physics combat, or second simulator.
2. Keep HP remains the only conquest/liveness authority.
3. Barracks destruction only stops future reinforcement spawns. Existing Guards survive until defeated or Keep conquest.
4. Guard production is finite: **2 Guards / 6 seconds, 8 total reserve across the siege**. There is no separate active-Guard cap. If this ramp is too steep, tune reserve or interval rather than adding cap semantics.
5. Reserve is consumed only by Guards actually spawned and never replenishes during the siege.
6. New Guards use the assault lane selected when they spawn. Existing Guards never change lane after a later lane selection.
7. New and restored Guards start at the Keep's authored `visualProgress` on their lane, not at the Barracks structure position, so direct-route armies cannot permanently walk past future waves.
8. Guards never advance below the Barracks line. The Barracks objective's `visualProgress` is the lower movement bound, so Guards defend the fortress side instead of camping the player spawn.
9. Opposing actors cannot pass through each other. Guards never attack the player's castle/camp, repair structures, steal resources, or reclaim cities.
10. Each actor keeps its own attack-range rule. Soldiers may begin attacking a Guard at their per-type range; the Guard continues closing until its own range is satisfied or the Barracks-line floor stops it. Ranged troops therefore keep their earlier first-strike window without making Guards unable to retaliate.
11. Idle/Camp/Map catch-up remains deliberately approximate. Reuse the existing 8-hour cap, 1/10 player building-production rate, no-buildings/no-progress rule, at-most-one-city conquest, and exactly-once report/reward routing.
12. Reuse `applyAbstractBuildingSpawnDamage` as the one shared abstract-damage seam already used by background idle and Camp/build-upgrade settlement. Do not add a second chronological production walker.
13. Guard-only combat changes must persist even when no `SoldierAttackEvent` hits a structure. Reuse the existing BattleScene save cadence rather than saving every frame.
14. Development save breaks are acceptable. Do not add a migration or save-version layer.
15. No generated art in HPA-469. Only procedural placeholders and stable runtime asset/action contracts are allowed.

## Highcrest authored layout

Use the smallest readable shape: **Keep + Barracks only**. Do not add another Gate or Arrow Tower merely to justify the encounter.

Highcrest's existing lane profile is:

- left = exposed;
- center = fortified;
- right = standard.

Use right as the default lane, preserving today's standard-lane default.

| Objective | Stable ID | Weight | Visual position | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `highcrest.keep` | 4 | center / `1.0` | conquest target and Guard actor spawn/restore progress |
| Barracks | `highcrest.barracks` | 1 | left / `0.62` | optional reinforcement shutdown target and Guard movement floor |

Routes:

- **Left / exposed:** `highcrest.barracks -> highcrest.keep`
- **Center / fortified:** `highcrest.keep`
- **Right / standard:** `highcrest.keep`

Highcrest's current City 5 durability budget is 427. The 4:1 starting weights allocate **342 Keep / 85 Barracks** while preserving the total exactly. The Barracks-first route therefore pays the full 427 structure damage but can shut off future Guard pressure; direct routes pay 342 structure damage and leave the Barracks active until conquest.

Keep the existing `.arrowTower` city defense trait. `defensiveFire.sourceObjectiveID` remains `highcrest.keep`, matching today's single-Keep defensive-fire origin without inventing another structure.

The two direct routes intentionally are not equal difficulty: center is the existing fortified lane (`1.25x` incoming tower damage) while right is standard (`1.0x`). The pilot's balance comparison is therefore **right direct vs left Barracks-first**. Center remains the deliberate hard direct lane, not a third parity target.

## Highcrest-local reinforcement tuning

These are authored City 5 values, so keep them beside Highcrest in `Country1CityCatalog.swift`, not in generic `SiegeState.swift`:

```swift
enum HighcrestGuardRules {
    static let guardsPerWave = 2
    static let waveIntervalSeconds = 20.0
    static let totalReserve = 8

    static let maxHP = 12
    static let attackPower = 3
    static let attackSpeed = 1.0
    static let attackRange = 0.10
    static let movementSpeed = 0.30
}
```

The four waves deploy at t = 20/40/60/80s. **Shipped value (HPA-469 Task 6 balance evidence):** the starting 6.0s interval deployed the entire reserve by t = 24s — long before the exposed route could destroy the Barracks (~50s with the representative camp) — so Barracks shutdown visibly canceled nothing. 20.0s leaves reserve unspent at typical shutdown times, making shutdown a real choice, and later waves land into a standing army (the Task 6 harness proved a wave-2 Guard engaging an army whose foremost soldier had already passed the Barracks floor). No active cap, queue, or extra mechanic was added.

## Authored siege model and Scout copy

Extend `CitySiegeLayout.ObjectiveKind` with only:

```swift
case barracks
```

Keep stable objective IDs as persistence identity. Add an optional Barracks lookup; do not add a generalized structure registry.

Construction remains fail-closed:

- all HPA-468 layout invariants remain;
- an authored layout may contain at most one `.barracks` objective for this pilot;
- non-pilot cities remain valid with no Barracks;
- `CityDefinition` documentation must no longer claim Falconridge is the only custom-layout city.

The existing Scout tactical footer derives from every non-Keep objective. Add the exhaustive enum case so Highcrest renders:

```text
L Barracks
```

Keep route membership as the source of `L`; do not hard-code Highcrest copy in the view. The existing measured/fail-closed compact Scout path must prove the footer presents.

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

`KingdomGameState.normalizedSiegeProgress` remains the single forgiving normalization seam. For Highcrest it:

- clamps reserve to `0...8`;
- normalizes elapsed into `0..<6`;
- clamps Guard HP to `1...12`;
- retains at most eight unresolved Guards total, preserving order and lanes;
- clamps remaining reserve so `unresolvedGuards.count + remainingReserve <= 8`;
- leaves Barracks-destroyed survivors intact;
- creates fresh reinforcement progress on a fresh Highcrest siege;
- forces non-Highcrest `guardReinforcements` to `nil`;
- never fabricates waves in pending-result state.

Persisted Guard IDs, positions, animation state, and projectiles are deliberately omitted. On scene reconstruction, each unresolved Guard receives a fresh transient ID and starts at Keep progress on its persisted lane.

### Why Guard position is not persisted

Scene replacement currently rebuilds the entire transient `BattleCombatState`; allied soldiers are not spatially persisted either. HPA-469 persists Guard lane + HP specifically to prevent healing/reserve resets, not to introduce partial spatial continuity for only one side. Persisting enemy position alone would make reconstruction asymmetric and expand save semantics beyond this pilot.

This means a Battle -> Camp/Map -> Battle transition reconstructs living Guards at Keep progress. That reset is accepted for this pilot and should be covered by reconstruction tests. A future shared cross-tab combat runtime, if ever justified, should solve actor spatial continuity for both sides together rather than adding Guard-only coordinates now.

## Live wave scheduling

`KingdomGameState` owns the durable wave clock and reserve because scene replacement/relaunch must not grant free reserve or clock resets.

Add one focused mutation:

```swift
mutating func advanceActiveGuardReinforcements(deltaTime: Double) -> [GuardSnapshot]
```

For an active Highcrest siege with a living Keep and Barracks:

```swift
let totalElapsed = progress.waveElapsedSeconds + max(0, deltaTime)
let dueOpportunities = Int(totalElapsed / HighcrestGuardRules.waveIntervalSeconds)
progress.waveElapsedSeconds = totalElapsed.truncatingRemainder(
    dividingBy: HighcrestGuardRules.waveIntervalSeconds
)
let spawnCount = min(
    progress.remainingReserve,
    dueOpportunities * HighcrestGuardRules.guardsPerWave
)
```

Append exactly `spawnCount` full-HP snapshots on `siegeProgress.selectedLane`, subtract exactly that reserve, and return the new snapshots. If Keep/Barracks is dead or reserve is zero, spawn none. There is no active-cap branch, blocked-wave queue, or lane-switch cap rule.

### Live-frame ownership and persistence

`BattleScene.advanceCombat(deltaTime:)` owns integration order:

```text
player building spawns
-> BattleCombatState.tick (tower fire remains first inside tick)
-> feedback.emitAutomaticCombat(result)
-> apply structure/soldier/Guard result to KingdomGameState
-> synchronize combat.guardSnapshots into SiegeProgress
-> advance Guard waves with combat.clampedDeltaTime(deltaTime)
-> restore newly spawned Guards into BattleCombatState
-> persist durable progress and sync nodes/HUD
```

Guard snapshot synchronization and wave advancement must live outside `applyCombatResult`'s existing `soldierAttacks.isEmpty` early return. A tick where allies only damage Guards still persists Guard HP.

Do not save every frame. Broaden the existing two-second BattleScene progress-save throttle so Guard wave elapsed state is covered even when there are no player buildings. Guard HP changes, Guard deaths, structure hits, and actual Guard spawns save immediately.

Barracks destruction during a tick is applied before wave advancement, so it cannot emit a same-frame late wave.

## Guard combat in `BattleCombatState`

Keep `BattleCombatState` as the only live actor simulator. Add one `Guard` array and transient `GuardID`; do not build an enemy hierarchy.

A Guard stores only ID, lane, HP, position, and attack cooldown. Its combat numbers come from `HighcrestGuardRules`.

### Spawn / restore and movement floor

- Barracks renders at `highcrest.barracks.visualProgress == 0.62`;
- new/restored Guards start at `snapshot.layout.keepObjective.visualProgress`;
- Guard movement downward clamps at `snapshot.layout.barracksObjective?.visualProgress ?? 0`;
- a Guard with no allied target holds position and never marches toward the player castle;
- direct-route soldiers already beyond `0.62` still meet later waves because Guards enter from Keep progress.

Derive the floor from authored Barracks geometry rather than duplicating `0.62` in Guard rules.

### Independent attack ranges

There is no single shared contact distance.

For a soldier/Guard pair on the same lane:

1. the soldier stops advancing once it is within **its own** per-type attack range and may attack;
2. the Guard continues closing while outside **its own** `0.10` attack range, subject to the Barracks movement floor and no-pass-through clamp;
3. therefore Archer/Mage/Siege can land earlier attacks while the Guard closes;
4. if the Guard survives and can close far enough, it may retaliate from its own range;
5. Infantry/Cavalry naturally begin much closer to the Guard.

This preserves existing ranged identity without making a melee Guard permanently unable to reach ranged troops.

### Tick ordering

Preserve HPA-468's existing tower-first behavior. Do not rewrite the tick as a new phase engine.

Within `tick(deltaTime:siege:)`:

1. resolve the existing defensive tower shot/cooldown in its current position;
2. resolve lane-local soldier/Guard movement using each actor's own range and the Guard floor;
3. resolve living Guard attacks;
4. resolve still-living allied attacks against a blocking Guard first, otherwise the first live structure on the route;
5. prune dead Guards/soldiers and emit events;
6. Keep death remains immediate conquest and stops later work.

With `guards.isEmpty`, current HPA-468 behavior must remain unchanged.

### Small event surface

Reuse existing `damagedSoldierIDs` and `soldierLosses` for Guard-caused allied hit/loss presentation. Add only what Guard rendering/attack feedback needs:

```swift
struct GuardAttackEvent: Equatable {
    let guardID: BattleCombatState.GuardID
    let soldierID: BattleCombatState.SoldierID
    let appliedDamage: Int
}

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
```

`TickResult` adds `guardAttacks`, `guardHits`, and `guardLosses`. Structure-hit `SoldierAttackEvent` remains structure-only; Guard damage does not become city damage or battle-report damage.

Automatic sound mapping remains small:

- `guardAttacks` may contribute existing `.attackMelee`;
- `guardHits` routes `type` through existing `attackSound(for:)` so Infantry/Cavalry use melee, Archer/Mage use ranged, and Siege uses siege;
- Guard-caused soldier hit/death already flows through existing `damagedSoldierIDs` / `soldierLosses` and needs no extra hit/death mapping.

No new sound ID, category, queue, or replay behavior is added.

## Idle / Camp / Map approximation

Do not frame-simulate Guards offline and do not add a chronological production event walker.

Both existing settlement callers already converge on `applyAbstractBuildingSpawnDamage`. Extend that existing seam instead:

```swift
private mutating func applyAbstractBuildingSpawnDamage(
    _ spawns: [BuildingSpawn],
    elapsedSeconds: Double,
    conquestMode: BattleConquestMode
) -> (applied: Int, conquered: Bool, goldEarned: Int)
```

Rules:

1. callers keep the existing 8-hour cap and 1/10 building-production calculation;
2. if the current city has no player buildings, preserve no-buildings/no-progress and do not advance Guard waves;
3. when buildings exist, call `advanceActiveGuardReinforcements(deltaTime: elapsedSeconds)` once before applying the resolved building spawns;
4. for each `BuildingSpawn`, spend its trait-adjusted damage against the oldest unresolved Guard on `siegeProgress.selectedLane` first, continuing through same-lane Guards until the budget is exhausted;
5. only leftover damage continues through `CitySiegeLayout.spendDamageBudget` on the selected lane;
6. only the structure-applied portion is recorded as idle city damage / battle-report attribution;
7. Guard damage grants no reward and is not city damage;
8. stop immediately when Keep reaches zero and reuse existing exactly-once conquest/reward/report behavior.

### Accepted approximation

All Guards due within the settlement window are materialized before that window's abstract player damage is applied. Compared with a chronological interleave, this can make Guards absorb damage slightly earlier and can allow Guards that a mid-window Barracks kill would have prevented.

The error is bounded: at the starting values only eight Guards exist and their total maximum HP is **96**. The approximation is therefore conservative/player-unfavorable by at most that finite defender pool, while avoiding a second copy of building spawn timing. Running balance evidence can tune reserve/interval if this pressure is too high.

Both background idle and Camp/build-upgrade settlement use this same shared damage seam; there is no second Guard ruleset to drift.

### Prevent live-time double counting

Leaving active Battle already calls `markCurrentCityBuildingProgressInactive(at:)`, which re-arms settlement timing for cities with player buildings. Add a focused lifecycle test proving live Guard wave time already advanced in Battle is not advanced again by the next Camp/Map settlement window. When there are no player buildings, settlement remains no-progress and therefore cannot double-count Guard time.

## Presentation

### Barracks

Reuse the existing local siege-structure helpers rather than creating a structure renderer. Add Barracks handling with:

- authored objective position;
- objective HP bar;
- intact state while spawning is possible;
- obvious ruined/disabled state after destruction;
- compact attached `GUARDS N` while reserve remains and `SHUT DOWN` after destruction.

No separate wave HUD or inspector is added.

### Guards

Use a procedural enemy silhouette structurally distinct from allied troops: helmet/head + shield/body composition, enemy-facing orientation, and separate node structure. Team recognition must not rely only on tint.

Guard nodes observe model state only. Animation never controls attack timing or damage. Reduced-motion/static presentation remains understandable.

### Runtime art handoff to HPA-476

Extend existing `SiegeObjectiveAssetContract` rather than inventing a manifest:

```text
siege-barracks — bottom-center — intact, ruined/disabled
siege-guard    — feet/bottom-center — resting, walk, attack, hit
```

Defeat may use a procedural fade and Barracks spawn cue may remain procedural. HPA-476 chooses final source dimensions, generated art, frames, prompts, and polish.

Existing City 5 Forged/Camp fixtures must be re-smoked because Highcrest changes from single-Keep to authored Barracks state.

## Testing and evidence

### Baseline first

Before Task 1 implementation, capture the current `main` Highcrest baseline with the representative deterministic camp/loadout. Record elapsed time and allied losses. Do not wait until final tuning to discover the pre-pilot reference.

### Authored model / Scout

Cover:

- Highcrest IDs, routes, 4:1 allocation, right default, one-Barracks invariant/lookup;
- `HighcrestGuardRules` authored beside Highcrest;
- `L Barracks` through compact measured/fail-closed Scout presentation;
- `SiegeObjectiveAssetContract.barracks == "siege-barracks"`;
- non-Highcrest `guardReinforcements == nil`;
- normalization preserves/clamps Highcrest reinforcement progress instead of dropping it.

### Wave / persistence

Cover:

- `5.9s -> 0`, `+0.1s -> 2`, another `6s -> 4`, `12s -> remaining reserve consumed` according to aligned opportunities;
- lane changes affect only newly spawned Guards;
- Barracks shutdown stops future spawns while living Guards remain;
- save/load preserves elapsed phase, reserve, lanes, and HP;
- reconstruction starts persisted Guards at Keep progress without healing them;
- position reset on reconstruction is explicit and accepted; no Guard-only position persistence is added.

### Combat

Cover:

- a direct-route soldier already past Barracks progress still intercepts a Keep-spawned Guard;
- Guard never moves below Barracks progress;
- opposing actors never pass through each other;
- per-type range tests prove Archer/Mage/Siege can attack earlier while Guard continues closing to its own range;
- Guard attacks only its own lane and never the player castle;
- blocker death resumes structure movement;
- tower shot order remains unchanged;
- `guards.isEmpty` retains HPA-468 behavior;
- Keep victory does not require Guard cleanup.

### Idle / lifecycle

Cover:

- both background idle and Camp/build-upgrade use the same `applyAbstractBuildingSpawnDamage` Guard absorption seam;
- all due window Guards are spawned once before abstract damage, matching the documented approximation;
- same-lane Guards absorb production damage before structures;
- no buildings means no Guard-wave advancement;
- Barracks shutdown prevents later windows from spawning Guards;
- live Battle wave time is not re-applied by the next settlement window;
- tab/relaunch reconstruction does not heal Guards, refill reserve, or restart wave phase;
- exactly-once reward/report and at-most-one-city conquest remain unchanged.

### BattleScene / feedback

Cover:

- Guard-only ticks synchronize HP even when `soldierAttacks` is empty;
- Guard wave elapsed is covered by the existing two-second save throttle even with no player buildings;
- `guardAttacks` yields existing melee attack feedback;
- `guardHits` uses its `SoldierType` and the existing attack-sound mapping;
- Guard-caused allied hit/death needs no duplicate scheduler mapping;
- Barracks destroyed during a combat tick cannot spawn a same-frame wave;
- procedural Barracks/Guard nodes reconstruct correctly;
- existing City 5 Forged/Camp fixtures still hold.

### Running evidence

Use one identical deterministic camp/loadout for:

1. **right / standard direct push**;
2. **left / exposed Barracks-first**.

Record elapsed time, allied losses, Guards spawned/defeated, and Barracks shutdown time. Capture a later direct-route wave intercepting an army that has passed `0.62`.

Center is the deliberate fortified hard lane and is not a balance-parity target; one smoke is sufficient to prove the lane still functions.

Capture real gameplay at the existing 393x852 reference, one compact supported phone, and portrait iPad. Show active Guard pressure, Barracks shutdown, surviving Guard after shutdown, final Keep conquest, and one non-pilot city.

Retune only Highcrest objective weights, `totalReserve`, `waveIntervalSeconds`, or the existing local Guard combat stats if one route is an obvious free choice, both routes stall, or Barracks shutdown has no visible consequence. Do not add an active cap or another mechanic as the first balance response.

## Risks resolved by this design

### Spawn-behind

Guard actors spawn/restore at Keep progress while Barracks geometry stays left/0.62.

### Spawn-point camping

Guard movement is clamped at the authored Barracks progress; they defend the fortress half and never push to the player spawn.

### Ranged identity ambiguity

Soldiers and Guards use their own ranges independently. Ranged troops gain earlier attack opportunities while a surviving Guard continues closing to its own range.

### Duplicate settlement machinery

Both settlement callers retain current production resolution and share the existing `applyAbstractBuildingSpawnDamage` extension. No production-timing walker is added.

### Guard-only state loss

Guard snapshot synchronization stays in `advanceCombat`, outside the structure-attack early return, and the existing save cadence is broadened to include wave elapsed progress.

### Deliberate position reset

Guard position remains transient for the same scene-lifecycle reason as allied soldier position. The pilot persists only the state needed to prevent healing/reserve resets.

## Deliberate cuts

No active-Guard cap, cap queue semantics, additional enemy classes, multiple Barracks, Guard position persistence, enemy rewards, Guard loot/gold, formations, threat tables, pathfinding, physics, Guard attacks on the player castle, repairs, regeneration, resource theft, city reclamation, boss phases, generic wave configuration, chronological idle combat simulation, runtime asset manifest, telemetry, save migration, per-city generated art, or HPA-475 hero/Rally work.
