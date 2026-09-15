# HPA-468 Tactical Siege Pilot Design

**Status:** Approved planning direction for implementation on the same PR  
**Linear:** HPA-468 — Tactical siege pilot: destructible objectives and assault lanes  
**Baseline:** `main` at `957a4ae8ddb7de50b3c03858eeaeaef35f8a2260`

## Goal

Make City 3, Falconridge, the smallest playable proof that a siege is about choosing an approach and dismantling defenses instead of reducing one global HP bar.

The player selects one of the existing three lanes. New manual and building-produced soldiers use that lane, automatically advance through that lane's authored objectives, and continue when an objective falls. Falconridge has a Keep, one Arrow Tower, and one shared Ridge Gate. Destroying the Tower permanently stops its fire. Destroying the Keep ends the siege even if an optional defense remains.

This is one implementation PR. The design and plan land first on the same branch; runtime code, tests, and gameplay evidence follow on that PR.

## Review-locked rules

The implementation must keep these boundaries explicit:

1. **Keep HP is the only conquest/liveness/tick-stop authority.** Aggregate remaining durability is never a win predicate and is not a player-facing HP bar.
2. **Every Country 1 city uses selected-lane spawning after this PR.** There is no production RNG lane-assignment path to preserve beside the new control.
3. **`CitySiegeLayout` fails closed at construction.** Persisted progress may discard unknown IDs; authored catalog data may not silently tolerate a broken route.
4. **Defensive fire range is source-relative.** A soldier is in range when its normalized position reaches `max(0, sourceProgress - towerAttackRange)`.
5. **`CityDefenseTrait` is city-wide and independent of objective liveness.** Destroying Falconridge's Arrow Tower stops `DefensiveFire`; it does not remove the city's `.arrowTower` soldier damage multipliers.
6. **Scout tactical copy must pass the existing fail-closed fit contract.** It is not accepted as an unchecked string substitution.
7. **No compatibility aggregate or second spawn path is added just to reduce migration work.** Development-only saves/tests may break and should be updated directly.

## Product shape

### Falconridge uses three structures, not four

Use the lower end of HPA-468's allowed envelope:

| Objective | Stable ID | Weight | Visual anchor | Purpose |
| --- | --- | ---: | --- | --- |
| Keep | `falconridge.keep` | 4 | center / `1.0` | Conquest target |
| Arrow Tower | `falconridge.arrow-tower` | 2 | left / `0.68` | Optional defensive-fire source |
| Ridge Gate | `falconridge.ridge-gate` | 2 | center / `0.58` | Shared blocker for center + right |

City 3's existing durability budget is 92. The 4:2:2 weights resolve exactly to:

- Keep: 46 HP
- Arrow Tower: 23 HP
- Ridge Gate: 23 HP

No extra city HP is created. The objective max-HP resolver always distributes the existing `cityMaxPower` budget exactly; any integer remainder for future layouts goes to the Keep.

### The three authored routes

Falconridge keeps its existing lane profile: left is exposed, center is standard, right is fortified. The default selected lane is center.

- **Left — tower-first:** `Arrow Tower @ 0.68 → Keep @ 1.0`
- **Center — gate-first:** `Ridge Gate @ 0.58 → Keep @ 1.0`
- **Right — gate-first / dangerous:** `Ridge Gate @ 0.58 → Keep @ 1.0`

The Arrow Tower covers all three lanes while alive. Existing lane defense multipliers still modify its damage. Tower range originates at the Tower's authored progress `0.68`, not at the Keep: with the current `towerAttackRange == 0.55`, its fire threshold is `0.13`. This deliberately keeps ranged Tower attackers inside the Tower's threat envelope instead of creating a route-specific dead zone.

The center/right sharing of one Gate proves that an objective can be reachable from more than one approach without a graph or pathfinder.

Gameplay acceptance compares **left (tower-first)** against **center (gate-first)** from the same camp setup. If one is an obvious free choice or Tower destruction produces no noticeable survival difference, tune only Falconridge's objective weights / existing defensive-fire numbers in this PR. Do not add another mechanic.

## Authored siege layout

Add one pure authored value to `CityDefinition`, implemented as a compact `CitySiegeLayout` with nested value types rather than a subsystem:

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

Use `[BattleLane]` for authored defensive coverage; do not change `BattleLane` only to introduce another collection type.

### Construction invariants

`CitySiegeLayout.init` uses preconditions in the same spirit as `LaneDefenseProfile` so broken catalog content fails immediately:

- objective IDs are unique and non-empty;
- exactly one objective is `.keep`;
- every durability weight is positive;
- every objective `visualProgress` and every route-step `progress` is within `0...1`;
- every route is non-empty, references only existing objective IDs, and ends at the one Keep;
- `defaultLane` has a route;
- `defensiveFire.sourceObjectiveID` exists;
- `coveredLanes` contains no duplicates;
- `singleKeep(defaultLane:)` constructs the only non-Falconridge shape and cannot emit an invalid layout.

Persisted `SiegeProgress` remains forgiving: unknown saved objective IDs are discarded during normalization. Authored layout data is not forgiving.

`Country1CityCatalog` owns all layout data. Falconridge gets the custom layout above. Every other Country 1 city gets `singleKeep(defaultLane: laneDefenseProfile.standardLane)`:

- one Keep carrying 100% of the existing durability budget;
- all three routes target that Keep at progress `1.0`;
- default lane = `laneDefenseProfile.standardLane`;
- defensive fire source = the Keep, covering all three lanes.

## Persisted siege progress

Persist only current-siege player choice and objective damage:

```swift
struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
}
```

`KingdomGameState` owns one `siegeProgress` for the current/pending city. `KingdomGameStore` continues to JSON-code the whole state; there is no second repository.

Rules:

- Fresh active city: selected lane = authored default, objective damage = empty/zero.
- Damage is clamped to authored objective max HP; unknown IDs are ignored when persisted state is normalized.
- Keep final objective damage through `cityConqueredPendingMap` / final-country pending report so restored Battle presentation can show support structures honestly.
- Starting the next city replaces it with that city's fresh progress.
- Do not retain completed-city objective history after the pending report flow no longer needs it.
- `siegeProgress` is an explicit `KingdomGameState.CodingKeys` member and is normalized on init/decode.
- Old development saves may reset. Do not add migration/version/converter/dual-schema logic.

### Remove scalar city HP ownership

Do not keep `cityRemainingPower` as a production compatibility authority.

The production model exposes:

- `currentKeepRemainingPower` — remaining HP of the one Keep;
- `currentKeepMaxPower` — max HP allocated to the Keep;
- existing `cityMaxPower` — total authored durability budget used for allocation/balance, not the conquest predicate.

A total-objective remaining projection may exist only for pure model tests/debugging if it genuinely simplifies verification. It must not drive conquest, combat tick continuation, idle loop continuation, Living Kingdom, HUD progress, Keep sprite HP, or the city tooltip.

All player-facing battle HP becomes **Keep HP**:

- Battle HUD progress bar = Keep remaining / Keep max;
- Keep sprite HP bar = Keep remaining / Keep max;
- city tooltip explicitly reports Keep HP;
- Gate/Tower show their own identity + HP.

For Falconridge, a fresh fortress is therefore `46/46`, not `46/92`. Living Kingdom thresholds use Keep max 46. Non-pilot cities remain visually equivalent because their Keep owns the entire durability budget.

## One targeting rule for live and idle combat

Use one small pure route helper next to the siege value types. It is not a service or engine.

It needs only two operations:

1. resolve the first living route step for a lane from authored routes + objective damage;
2. spend a positive damage budget on that route, carrying unused damage to the next step when an objective falls.

This rule is shared by:

- live combat target selection;
- idle/Camp/Map abstract building damage.

No pathfinding, target registry, behavior tree, ECS, or generic effect system is introduced.

## Live combat ownership

`BattleCombatState` remains the only live-actor simulator and never owns persisted objective HP.

Per tick, `KingdomGameState` supplies an ephemeral pure current-siege snapshot containing the layout and remaining objective HP. `BattleCombatState` may mutate a local copy during that tick so multiple soldiers cannot over-damage one target, then returns objective-aware events. The local copy is discarded after `KingdomGameState` applies those events.

### Soldier flow

- Production spawn requires an explicit lane from `state.siegeProgress.selectedLane` for both manual and building-produced soldiers.
- Remove the optional/random production lane fallback; deterministic tests pass lanes explicitly too.
- The combat RNG remains only where it is still needed, such as choosing among multiple occupied defensive-fire lanes.
- Already deployed soldiers keep their current `Soldier.lane` when selection changes.
- Each soldier asks for the first living step in its own lane.
- Movement stops at `targetProgress - soldier.attackRange`.
- On attack, emit `SoldierAttackEvent` with `objectiveID` + actual `appliedDamage`.
- If an earlier attack in the same tick destroys a target, following soldiers may resolve/move toward the next step.
- No direct building-target command, retarget UI, arbitrary movement, or deployed-soldier lane switch.

`ActiveSiegeSession` continues to record type/source/lane damage attribution. The conquest report does not gain structure rows in this ticket.

### Defensive fire

Replace the unconditional global tower with the authored `DefensiveFire` source:

- the source objective must be alive;
- target soldier lane must be in `coveredLanes`;
- fire range is **source-relative**: `soldier.position >= max(0, sourceProgress - towerAttackRange)`;
- source progress comes from the source objective's authored visual progress;
- reuse current cooldown, foremost-target selection, occupied-lane RNG selection, damage, and `LaneDefenseProfile` multiplier behavior;
- once Falconridge's Arrow Tower is destroyed, it never fires again;
- for non-pilot cities, the source is the Keep at `1.0`, so the current `1.0 - towerAttackRange` behavior is preserved.

Do not run the old global tower beside this source.

### Trait independence

Falconridge still has `CityDefenseTrait.arrowTower`. That trait is a city-wide soldier→objective damage modifier and does not depend on whether the destructible Arrow Tower is alive.

Destroying the objective:

- **does:** stop defensive fire and remove Tower coverage presentation;
- **does not:** change favorable/disadvantaged soldier multipliers for later Gate/Keep damage.

This is intentional and must be pinned in model/combat tests.

## KingdomGameState mutations and settlement

`KingdomGameState` remains the authority for objective damage, conquest, reward, offline time, and report creation.

### Live damage

`applyLiveSoldierAttacks` becomes objective-aware:

- validate objective ID against the current authored layout;
- clamp against that objective's remaining HP;
- record only actual applied damage into `ActiveSiegeSession`;
- update `SiegeProgress.damageByObjectiveID`;
- after each event, check **Keep remaining HP**, never aggregate remaining durability;
- when Keep reaches zero, finalize exactly one existing reward/result and stop processing attacks;
- do not zero or fabricate damage on surviving support objectives.

### Idle/Camp/Map damage

Keep current building production, 8-hour cap, and 1/10 idle rate. Change only where generated attack power lands.

For each resolved `BuildingSpawn`:

1. calculate existing trait-adjusted attack power;
2. spend it through the selected lane's ordered route;
3. carry remaining budget forward if that spawn destroys an objective;
4. record the spawn's actual applied total in existing idle attribution;
5. stop immediately when **Keep remaining HP** reaches zero, even if another support objective is still alive.

A surviving Gate prevents idle damage from reaching the Keep. A route that bypasses the Tower may conquer while the Tower survives. No frame-by-frame offline combat or fabricated losses are added.

### Lane changes settle the old lane first

Expose one `KingdomGameState.selectAssaultLane` mutation rather than assigning persisted selection from `BattleScene`.

If an inactive interval is armed, resolve it **before** writing the new lane. That settlement therefore uses the old stored lane. If it conquers the Keep, do not change the lane afterward.

Ordinary in-Battle lane taps with no armed interval do not synthesize production.

## Country-wide lane control

The assault selector is a Country 1 control, not Falconridge-only chrome.

- Every fresh city defaults to `laneDefenseProfile.standardLane`.
- Every subsequent manual/building production spawn uses the currently selected lane.
- Selecting the exposed lane changes incoming defensive-fire pressure through the existing `0.80×` lane multiplier.
- Selecting the fortified lane uses the existing `1.25×` multiplier.
- Already-deployed soldiers stay where they were spawned.

Non-pilot acceptance explicitly pins City 1: default spawns use its standard lane; selecting its exposed lane changes only new spawns and applies exposed-lane defensive-fire damage. There is no hidden RNG spawn behavior retained for “legacy pressure.”

## Battle UI and input

Reuse the existing Forged `BattleHUDNode` lane chips and keep `BattleChromeLayout` as the sole geometry authority.

The current chip visuals are 26pt high. Add `laneChipHitFrames`, derived from those visual frames and expanded/clamped to at least 44×44 inside the battlefield, mirroring the existing medallion visual/hit-frame pattern.

Changes:

- `BattleHUDContent` carries `keepRemainingPower`, `keepMaxPower`, and selected assault lane; remove aggregate `cityRemainingPower` / `cityMaxPower` HP presentation fields.
- `BattleHUDNode.Action` adds `.selectLane(BattleLane)`.
- all three lane hit regions are active, including the standard lane;
- preserve OPEN / HELD role treatment for exposed/fortified lanes;
- exactly the selected lane shows one small procedural assault flag + `ASSAULT` treatment;
- `BattleHUDNode.action(at:)` resolves lane selection from `laneChipHitFrames`;
- `BattleScene` routes the action through the model mutation and persists it;
- Deploy, unit medallions, Settings, tabs, info tooltips, and conquest Continue must not fall through into lane selection.

No second lane picker or command strip.

## Objective presentation

Keep semantic `enemy-city` as the Keep. Add only local `BattleScene` nodes for Falconridge Gate/Tower and their HP treatment.

- Keep HP bar and Living Kingdom use actual Keep health.
- Gate/Tower show readable identity + HP.
- Destroyed Gate/Tower switch to clearly ruined procedural placeholders.
- Tower coverage treatment disappears when the Tower dies.
- Objective nodes rebuild from persisted state, so tab changes/relaunch do not resurrect defenses.
- city tooltip uses `Keep HP current/max`; it never reports total remaining structure HP as if it were the win target.

Do not add a reusable scene-object framework.

## Scout hint

Keep the existing Scout card and action. Add one optional tactical footer string projected from Falconridge's authored layout, using concise copy such as:

`L Tower · C/R Gate`

For non-pilot cities the current `Open: <lane>` footer remains unchanged.

This is a fit contract, not only content:

- `CountryMapScoutCardNode.prepareScout` measures the chosen footer against the existing `exposedLaneFrame`;
- Falconridge tactical copy uses `SingleLineTextFitter` (or the same existing text-fit primitive) down to a small explicit minimum, rather than assuming the normal footer font fits;
- supported compact-phone tests must prove the tactical footer fits and the card still presents;
- if the approved concise copy cannot fit even at the minimum, adjust the footer layout within `CountryMapScoutCardLayout`; do not let the Scout card silently disappear.

Do not add a new inspector or tactical detail screen.

## HPA-476 placeholder / art handoff

HPA-468 creates **procedural placeholders only**. Reserve these future contracts:

| Runtime asset contract | Source canvas | Anchor | States |
| --- | --- | --- | --- |
| `siege-gate` | 256×160 | bottom-center `(0.5, 0)` | `intact`, `ruined` |
| `siege-arrow-tower` | 256×320 | bottom-center `(0.5, 0)` | `intact`, `ruined` |
| `siege-assault-flag` | 128×160 | bottom-center `(0.5, 0)` | selected only |

Runtime sizing stays relative to `BattlefieldLayout.structureHeight`; source pixels do not dictate scene points. HPA-476 owns generation/polish/final replacement art. HPA-468 must not add generated images or animation frames.

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
- compatibility aggregate HP path;
- production RNG lane-spawn path;
- generic combat engine, target registry, VFX manager, ECS, or cross-tab combat runtime;
- final image/animation production.

## Acceptance

HPA-468 is done when:

- Falconridge supports selecting a lane and visibly dismantling its authored objectives.
- Keep remaining HP is the only conquest/liveness/tick-stop authority.
- HUD, Keep sprite bar, tooltip, and Living Kingdom all use Keep current/max HP.
- New manual + building soldiers in every Country 1 city use the selected lane; existing soldiers do not move lanes.
- City 1 proves default-standard, exposed-lane `0.80×`, and no movement of an already-deployed soldier.
- Tower source-relative range is deterministic and Falconridge ranged Tower attackers are covered by the authored Tower.
- Tower destruction visibly and mechanically stops fire but does not remove Falconridge's city-wide `.arrowTower` damage multipliers.
- Gate blocking applies identically to live and abstract idle damage.
- Keep destruction ends the siege while a support objective may survive.
- `CitySiegeLayout` rejects invalid authored routes at construction.
- objective damage and selected lane survive save/load, tab changes, background/foreground, and relaunch.
- Living Kingdom thresholds use Keep max 46 for Falconridge and remain unchanged for one-Keep cities.
- Falconridge Scout tactical footer fits on supported compact phone geometry without disabling the card.
- pending-first report and deliberate Camp conquest routing remain unchanged.
- the left tower-first vs center gate-first runs from the same camp setup produce a meaningful, non-free trade-off.
- no final art is generated in this PR.
