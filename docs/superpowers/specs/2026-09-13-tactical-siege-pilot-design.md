# HPA-468 Tactical Siege Pilot Design

**Status:** Approved planning direction for implementation on the same PR  
**Linear:** HPA-468 — Tactical siege pilot: destructible objectives and assault lanes  
**Baseline:** `main` at `957a4ae8ddb7de50b3c03858eeaeaef35f8a2260`

## Goal

Make City 3, Falconridge, the smallest playable proof that a siege is about choosing an approach and dismantling defenses instead of reducing one global HP bar.

The player selects one of the existing three lanes. New manual and building-produced soldiers use that lane, automatically advance through that lane's authored objectives, and continue when an objective falls. Falconridge has a Keep, one Arrow Tower, and one shared Ridge Gate. Destroying the Tower permanently stops its fire. Destroying the Keep ends the siege even if an optional defense remains.

This is one implementation PR. The design and plan land first on the same branch; runtime code, tests, and gameplay evidence follow on that PR.

## Product shape

### Falconridge uses three structures, not four

Use the lower end of HPA-468's allowed envelope:

| Objective | Stable ID | Weight | Visual anchor | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `falconridge.keep` | 4 | center / enemy-city anchor | Conquest target |
| Arrow Tower | `falconridge.arrow-tower` | 2 | left / 0.68 route progress | Optional defense; fires while alive |
| Ridge Gate | `falconridge.ridge-gate` | 2 | center / 0.58 route progress | Shared blocker for center + right |

City 3's existing durability budget is 92. The 4:2:2 weights therefore resolve exactly to:

- Keep: 46 HP
- Arrow Tower: 23 HP
- Ridge Gate: 23 HP

No extra city HP is created. The objective max-HP resolver must always distribute the existing `cityMaxPower` budget exactly; any integer remainder for future layouts goes to the Keep.

### The three authored routes

Falconridge keeps its existing lane profile: left is exposed, center is standard, right is fortified. The default selected lane is therefore center.

- **Left — tower-first:** `Arrow Tower @ 0.68 → Keep @ 1.0`
- **Center — gate-first:** `Ridge Gate @ 0.58 → Keep @ 1.0`
- **Right — gate-first / dangerous:** `Ridge Gate @ 0.58 → Keep @ 1.0`

The Arrow Tower covers all three lanes while alive. Existing lane defense multipliers still modify its damage, so the left route spends extra time destroying the Tower but benefits from exposed-lane fire, center reaches the Keep sooner while accepting continued Tower fire, and right is the highest-risk gate route.

The center/right sharing of one Gate deliberately proves that an objective can be reachable from more than one approach without introducing a graph or pathfinder.

Gameplay acceptance compares **left (tower-first)** against **center (gate-first)** from the same camp setup. If one is an obvious free choice or Tower destruction produces no noticeable survival difference, tune only Falconridge's objective weights / Tower firing numbers in this PR. Do not add another mechanic to compensate.

## Authored siege layout

Add one pure authored value to `CityDefinition`, implemented as a compact `CitySiegeLayout` with nested value types rather than a new subsystem:

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

    struct RouteStep: Equatable {
        let objectiveID: String
        let progress: Double
    }

    struct DefensiveFire: Equatable {
        let sourceObjectiveID: String
        let coveredLanes: [BattleLane]
    }

    let objectives: [Objective]
    let routes: [BattleLane: [RouteStep]]
    let defaultLane: BattleLane
    let defensiveFire: DefensiveFire
}
```

Use an authored lane array rather than changing `BattleLane` to `Hashable` only to support a `Set`; tests can pin that coverage contains no duplicates.

The exact implementation may nest helpers differently, but keep these contracts:

- objective IDs are stable authored strings;
- each lane is one ordered list, not a graph;
- route progress is normalized 0...1 and is used by both combat range checks and scene placement;
- every route ends at the same Keep;
- one authored objective can appear in multiple route lists;
- the defensive-fire source is an objective whose liveness gates firing;
- the layout remains framework-free.

`Country1CityCatalog` owns the data. Falconridge gets the custom layout above. Every other Country 1 city gets `singleKeep(...)` through the same model:

- one Keep carrying 100% of the existing durability budget;
- all three routes target that Keep;
- default lane = `laneDefenseProfile.standardLane`;
- defensive fire source = the Keep, covering all three lanes.

That preserves the current basic loop and current tower pressure for non-pilot cities while deleting the need for a legacy city-HP combat branch.

## Persisted siege progress

Persist only current-siege player choice and objective damage:

```swift
struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
}
```

`KingdomGameState` owns one `siegeProgress` for the current/pending city. `KingdomGameStore` continues to serialize the whole state exactly once; there is no second repository or save owner.

Rules:

- Fresh active city: selected lane = authored default, objective damage = empty/zero.
- Damage is clamped to the authored objective's max HP and unknown IDs are ignored when state is normalized.
- Keep the final objective damage through `cityConqueredPendingMap` / final-country report so restored Battle presentation can still show which optional defenses survived.
- Starting the next city replaces it with that city's fresh progress.
- Do not retain completed-city objective history.
- Old development saves may reset. Do not add a migration version, converter, compatibility shim, or dual schema.

### Remove the mutable aggregate HP authority

`cityRemainingPower` must no longer be an independently encoded mutable pool.

Keep read-only projections where they reduce churn:

- `cityRemainingPower`: derived total remaining objective durability while the city is active; 0 after conquest.
- `cityMaxPower`: unchanged existing city durability budget.
- `currentKeepRemainingPower` and `currentKeepMaxPower`: derived from the Keep objective.

Tests/fixtures that need a damaged tactical city should construct objective damage explicitly instead of seeding one ambiguous aggregate HP number.

The Living Kingdom fortress stage must switch from aggregate city HP to **actual Keep HP**. Destroying a Gate or Tower must not visually damage the Keep. Non-pilot cities remain visually identical because their one Keep still owns the full budget.

## One targeting rule for live and idle combat

Use one small pure route helper next to the siege value types. It is not a service or engine.

It needs only two operations:

1. Resolve the first living route step for a lane from authored routes + objective damage.
2. Spend a positive damage budget on that route, carrying unused damage to the next route step when an objective falls.

This is the shared rule used by:

- live combat to know which objective a soldier should approach/attack;
- idle/Camp/Map settlement to spend abstract building-produced damage.

No pathfinding, target registry, behavior tree, ECS, or generic effect system is introduced.

## Live combat ownership

`BattleCombatState` remains the only live-actor simulator. It must **not** become a second persistence owner for objective HP.

Per tick, `KingdomGameState` supplies an ephemeral pure snapshot of the current authored layout and remaining objective HP. `BattleCombatState` may mutate a local copy during that tick so multiple soldiers cannot over-damage a target, but that copy is discarded after the returned events are applied to `KingdomGameState`.

### Soldier flow

- Spawn uses an explicit lane from `state.siegeProgress.selectedLane` for both manual and building-produced soldiers.
- Already deployed soldiers keep their current `Soldier.lane`.
- Each soldier asks for the first living step in its own lane.
- Movement stops at `targetProgress - soldier.attackRange` using the existing normalized movement/range model.
- On attack, emit an objective-aware `SoldierAttackEvent` containing `objectiveID` and `appliedDamage`.
- If an earlier attack in the same tick destroys the target, following soldiers may resolve/move toward the next step.
- No direct building target command, retarget UI, arbitrary movement, or lane switch for deployed soldiers.

Rename the event's current `appliedCityDamage` wording to `appliedDamage`; `ActiveSiegeSession` still records the same type/source/lane damage attribution. The conquest report does not need a new structure-by-structure section in this ticket.

### Defensive fire

Replace the unconditional global tower with the layout's `DefensiveFire` source:

- source objective must still be alive;
- target soldier must be in an authored covered lane;
- target the foremost living soldier in that lane, reusing current range/damage/cooldown behavior;
- existing `LaneDefenseProfile` multipliers remain authoritative for lane-specific damage;
- once Falconridge's Arrow Tower is destroyed, it never fires again;
- for non-pilot cities, the single Keep is the defensive-fire source, preserving current behavior on the unified path.

Do not run the old global tower beside this source.

## KingdomGameState mutations and settlement

`KingdomGameState` remains the authority for objective damage, conquest, reward, offline time, and report creation.

### Live damage

`applyLiveSoldierAttacks` becomes objective-aware:

- clamp each event against current remaining HP for its objective;
- record only actually applied damage into `ActiveSiegeSession`;
- update `SiegeProgress.damageByObjectiveID`;
- conquer immediately when the Keep reaches zero;
- award exactly one existing city reward and finalize the existing pending Battle result;
- do not zero or fabricate damage on surviving support objectives.

### Idle/Camp/Map damage

Keep existing building production, 8-hour cap, and 1/10 idle rate. Change only where generated attack power lands.

For each resolved `BuildingSpawn`:

1. calculate its existing trait-adjusted attack power;
2. treat that number as a damage budget;
3. spend it through the currently selected lane's ordered route;
4. carry remaining budget forward if that spawn destroys an objective;
5. record the actual applied total against that soldier type in existing idle attribution.

This preserves attribution without replaying frame-by-frame combat or fabricating offline soldier losses.

A surviving Gate therefore prevents idle damage from reaching the Keep. A route that bypasses the Arrow Tower may conquer while the Tower survives.

### Lane changes settle the old lane first

Expose one `KingdomGameState` lane-selection mutation rather than assigning `selectedLane` from the scene.

If an inactive interval is armed (`lastBackgroundedAt` / existing offscreen building-progress seam), resolve that interval **before** writing the new lane. The settlement therefore uses the previously stored lane. If settlement conquers the city, do not change the lane afterward.

Ordinary in-Battle lane taps with no armed inactive interval do not synthesize extra production.

## Battle UI and input

Reuse the existing Forged `BattleHUDNode` lane chips and keep `BattleChromeLayout` as the only geometry authority; do not add another command bar.

The current lane-chip visuals are 26pt high, so do not treat those visual rectangles as touch targets. Add `laneChipHitFrames` to `BattleChromeLayout`, derived from each visual `laneChipFrame`, expanded/clamped to at least 44×44 inside the battlefield. This mirrors the existing medallion visual-frame / hit-frame pattern.

Changes:

- `BattleHUDContent` adds selected assault lane.
- `BattleHUDNode.Action` adds `.selectLane(BattleLane)`.
- all three lane-entrance hit regions are active even when the standard lane has no OPEN/HELD role chip.
- retain existing OPEN / HELD treatment for exposed/fortified lanes; do not invent another role taxonomy for the standard lane.
- exactly the selected lane shows the small procedural assault flag and `ASSAULT` treatment, satisfying the single-visible-flag requirement.
- `BattleHUDNode.action(at:)` resolves lane selection from `laneChipHitFrames`.
- `BattleScene.handleBattleHUDTouch` routes selection through the model mutation and persists it.
- lane selection is consumed before scene-level fallback handling, so Deploy, unit medallions, Settings, tabs, income/city tooltips, and conquest UI cannot accidentally change the lane.

No new Settings surface or separate lane picker.

## Objective presentation

Keep the existing semantic `enemy-city` node as the Keep. Add only local `BattleScene` nodes for Falconridge's Gate/Tower and their HP labels.

- Keep HP bar and Living Kingdom treatment read actual Keep health.
- Gate/Tower show readable identity + HP.
- Destroyed Gate/Tower switches to a clearly ruined procedural placeholder and loses its HP fill.
- While the Tower is alive, covered lane paths receive a restrained coverage treatment; the treatment disappears with the Tower.
- Objective nodes are rebuilt from persisted state, so tab changes and relaunches do not resurrect defenses.

Do not create a reusable scene-object framework in this ticket. Small private BattleScene builders are sufficient for three structures.

## Scout hint

Keep the existing Scout card. For Falconridge only, replace the generic secondary route hint with concise tactical copy derived from the authored layout, e.g.:

`Left: silence Tower · Center: break Gate`

Keep the existing defense trait, reward, flavor, and action. Do not add a new inspector or tactical detail screen.

## HPA-476 placeholder / art handoff

HPA-468 creates **procedural placeholders only**. Reserve these future asset contracts so HPA-476 can replace visuals without changing gameplay IDs or layout logic:

| Runtime asset contract | Source canvas | Anchor | States |
| --- | --- | --- | --- |
| `siege-gate` | 256×160 | bottom-center `(0.5, 0)` | `intact`, `ruined` |
| `siege-arrow-tower` | 256×320 | bottom-center `(0.5, 0)` | `intact`, `ruined` |
| `siege-assault-flag` | 128×160 | bottom-center `(0.5, 0)` | selected only |

Runtime sizing stays relative to `BattlefieldLayout.structureHeight`; source pixels do not dictate scene points. HPA-476 owns generation, polish, and final replacement art. HPA-468 must not add generated images or animation frames.

## Deliberate cuts

Not in HPA-468:

- enemy soldiers / Barracks / Guards;
- player hero / Captain / Rally;
- enemy attacks on the player's camp;
- new currencies or per-objective loot;
- wards, depots, more Tower behaviors;
- procedural maps or route editor;
- arbitrary soldier movement or selection;
- campaign-wide siege recipes;
- new report screen or target inspector;
- telemetry;
- save migration/backward compatibility;
- generic combat engine, target registry, VFX manager, ECS, or cross-tab combat runtime;
- final image/animation production.

## Acceptance

HPA-468 is done when:

- Falconridge supports selecting a lane and visibly dismantling its authored objectives.
- New manual + building soldiers use the selected lane; existing soldiers do not move lanes.
- Tower destruction visibly and mechanically stops Tower fire.
- Gate blocking applies identically to live and abstract idle damage.
- Keep destruction ends the siege while a support objective may survive.
- Non-pilot cities still play through the same objective path as one-Keep layouts.
- objective damage and selected lane survive save/load, tab changes, background/foreground, and relaunch.
- Living Kingdom fortress damage follows Keep HP, not Gate/Tower damage.
- pending-first report and deliberate Camp conquest routing remain unchanged.
- the left tower-first vs center gate-first Falconridge runs from the same camp setup produce a meaningful, non-free trade-off.
- no final art is generated in this PR.
