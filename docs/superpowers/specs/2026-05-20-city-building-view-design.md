# City Building View Design

## Context

Pyxis currently has a one-active-city battle loop. `BattleScene` renders live combat, `CountryMapScene` handles city entry, `BattleCombatState` owns temporary battlefield units, and `KingdomGameState` owns durable campaign progress, gold, city HP, upgrades, persistence, and idle catch-up.

This design adds a city-specific Building View. Buildings are temporary siege infrastructure for a specific city, not kingdom-wide assets. They spawn soldiers during the active battle and produce abstract damage while the city is idle. The data must be isolated by city so a future feature can support multiple simultaneous city attacks without a global building list.

## Goals

- Add a new Building View scene for the current city.
- Give each city its own isolated 25-slot building grid.
- Let players build Barracks and Archery Ranges on any empty slot.
- Cap each building type at 5 per city.
- Use global gold for building construction and upgrades.
- Spawn Infantry and Archer soldiers from buildings during active battle.
- Let manual spawning choose Infantry or Archer through a selector.
- Keep manual-spawned soldiers under one shared live cap, starting at 10.
- Replace the old global idle damage model with building-based idle damage.
- Keep live soldiers transient and SpriteKit-owned while durable city building state stays in pure Swift models.

## Non-Goals

- Multiple simultaneous visible battle scenes.
- Queued soldiers.
- Soldier storage while a battle scene is closed.
- Timed construction.
- Timed upgrades.
- Building adjacency bonuses.
- More than Infantry and Archer.
- Manual soldier cap upgrades.
- Building art generation in this first mechanics slice.
- Tower placement or tower upgrades.
- Reworking the country map progression model beyond routing to the Building View.

## Architecture

Keep the existing separation between durable progression, pure live-combat rules, and SpriteKit presentation.

### Durable City Building State

Add city-keyed building data to `KingdomGameState`, using a stable city identity such as country number plus city number. A likely shape is:

- `CityKey`: country and city number.
- `CityBattleState`: isolated state for one city.
- `BuildingSlot`: one of 25 fixed slot indexes, either empty or occupied.
- `CityBuilding`: building type, level, and active-battle spawn timer progress.
- `BuildingType`: Barracks or Archery Range.
- `SoldierType`: Infantry or Archer.
- `lastBuildingProgressResolvedAt`: timestamp for resolving offscreen building damage independently per city.

The current app uses one active city, but the save shape should be a dictionary keyed by city identity rather than one global building grid. Future simultaneous attacks can then resolve city building data independently.

City building state resets or is discarded when that city is conquered. The completed city does not need replayable building data in this slice.

### `KingdomGameState`

`KingdomGameState` remains SpriteKit-free and owns:

- city-keyed building state
- global gold
- build and upgrade costs
- building type caps
- city HP and conquest
- idle building damage resolution
- save-data normalization for invalid building data

It should expose mutating operations for building interactions, such as:

- build a building in a slot
- upgrade a building in a slot
- resolve active building spawn timers
- resolve idle building damage for a city
- clear building state after conquest

These operations should return explicit result enums for success, insufficient gold, occupied slot, invalid slot, type cap reached, missing building, and unavailable stage.

### `BattleCombatState`

`BattleCombatState` becomes soldier-type aware while remaining a pure Swift model. A live soldier should know:

- soldier type
- spawn source: manual or building
- level
- max HP
- current HP
- defense
- attack power
- attack speed
- attack range
- movement speed
- position and attack cooldown

Infantry and Archer use the same movement and attack loop. Their first-slice differences are:

- Infantry has higher HP and shorter range.
- Archer has lower HP and longer range.
- Attack speed stays the same initially.

Soldier level changes attack power and HP for both types.

### `BuildingViewScene`

Add a new SpriteKit scene for the current city build grid. It should:

- render a 5x5 city grid with 25 slots
- show current city, gold, and building counts
- let the player select an empty slot and build Barracks or Archery Range
- let the player select an occupied slot and upgrade that building
- show unavailable actions through feedback instead of silently doing nothing
- route back to Battle View

The first implementation can use code-owned SpriteKit UI and existing `GameUITheme` primitives rather than introducing UIKit overlays.

### `BattleScene`

`BattleScene` remains the only live war-zone renderer. It should:

- add a route to Building View
- replace the single manual spawn button behavior with a soldier-type selector plus spawn action
- enforce the manual live cap across all manual Infantry and Archer soldiers
- tick building spawn timers while battle is active
- spawn building-produced live soldiers when building timers complete
- keep building-spawned soldiers separate from the manual cap
- apply emitted city damage to `KingdomGameState`
- clear live combat and city building state after conquest

## Building Rules

Each city has 25 visible slots arranged as a 5x5 city grid.

The player can build on any empty slot. Each slot holds one building. Construction is instant and paid with global gold.

First building types:

- Barracks: spawns Infantry.
- Archery Range: spawns Archer.

Each city has a per-type cap:

- max 5 Barracks
- max 5 Archery Ranges

The cap is per city, not global. A future simultaneous city system can have each city enforce its own caps independently.

Building upgrades are instant and paid with global gold. Upgrading a building increases that building's level. Future soldiers spawned by that building use the building's level.

## Manual Spawning

Manual spawning stays in Battle View. The player chooses Infantry or Archer from a selector, then taps spawn.

Manual soldiers use the existing global soldier upgrade level. That preserves the value of the current upgrade loop while adding soldier-type choice.

Manual soldiers share one live cap:

- starting cap: 10
- shared across manual Infantry and manual Archer
- building-spawned soldiers do not count toward this cap

If the cap is reached, spawn input should remain understandable through feedback, such as a short message that the manual squad is full.

## Active Building Spawning

Buildings spawn soldiers only for the current live battle view. Each constructed building has a spawn interval. When the timer completes while `BattleScene` is active, that building creates one live soldier of its soldier type and building level.

The first implementation should use conservative, readable starter values. For example:

- Barracks level 1 spawns an Infantry every 10 seconds.
- Archery Range level 1 spawns an Archer every 12 seconds.
- Higher building levels improve soldier level, not necessarily spawn speed in the first slice.

If balance tuning needs more depth later, spawn interval can become another building stat. It should not be required for the first implementation.

## Idle Building Damage

The old global/manual idle damage is replaced by building-based idle damage.

If a city has no buildings, background or offscreen time deals no idle damage.

When a city is not actively being viewed, its buildings continue producing at a slower idle rate. Each city should track its own last building-progress resolution timestamp so future simultaneous city battles can resolve independently. The first design assumption is:

```text
idle spawn interval = active spawn interval * 10
```

On resume or when returning to the city, completed idle spawn cycles convert directly into abstract city damage. No soldiers are queued, stored, or later released into the battle scene.

Idle damage should use the same soldier type and level formulas as live building-spawned soldiers, but it should resolve as aggregate city damage. It should not simulate tower shots, soldier HP loss, movement, targeting, projectiles, or deaths.

Building idle damage can conquer a city. In the current one-active-city slice, conquest still feeds the existing popup and country-map flow. The city damage is capped to the city remaining HP and does not overflow into another city. The city-keyed data shape should still allow future multi-city idle resolution to resolve each city independently.

## Progression And Persistence

Global gold pays for:

- building construction
- building upgrades
- existing global soldier upgrades

City building data is temporary for that city. Once the city is conquered:

1. city damage is capped to remaining HP
2. gold reward is awarded through existing progression rules
3. the city is marked completed
4. live combat is cleared
5. the conquered city's building state is removed or reset
6. the conquest popup opens
7. the player returns to the country map flow

Save decoding should normalize invalid building data instead of failing. Examples:

- out-of-range slot indexes are dropped
- duplicate occupied slots keep one valid building
- unsupported building types are dropped
- building levels clamp to at least 1
- per-type caps clamp by keeping the earliest valid slots
- building data for completed cities is discarded

## Presentation

The Building View should feel like a city grid, not a list of upgrades.

Layout direction:

- title/status band with current city and gold
- 5x5 grid in the main visual area
- each slot displays empty, Barracks, or Archery Range state
- selected slot shows available actions
- bottom or side action area for Build Barracks, Build Archery Range, Upgrade, and Back to Battle

The first slice can use simple code-owned shapes, labels, and color language:

- Barracks: green/friendly military tone
- Archery Range: blue/ranged unit tone
- Empty lots: subdued construction-lot tone
- Invalid or unaffordable action: short feedback and button flash

The Battle View should add a compact Build control and a soldier-type selector without crowding the existing HUD, spawn, and upgrade controls.

## Error Handling And Bounds

- Building is blocked when the selected slot is occupied.
- Building is blocked for invalid slot indexes.
- Building is blocked when gold is insufficient.
- Building is blocked when that city has already reached 5 buildings of the requested type.
- Upgrade is blocked when the selected slot is empty.
- Upgrade is blocked when gold is insufficient.
- Building operations are unavailable outside an active city.
- Manual spawning is blocked while the conquest popup is visible.
- Manual spawning is blocked when the shared manual live cap is reached.
- Building-spawned soldiers ignore the manual cap.
- Active spawn timers do not create soldiers after the city is conquered.
- Idle damage does nothing when the city has no buildings.
- Idle damage does not overflow into another city.
- Live soldiers are still discarded on scene rebuild or backgrounding.

## Testing

Use pure Swift tests for model behavior and focused SpriteKit tests for scene integration.

### `KingdomGameStateTests`

Cover:

- a new city starts with 25 empty slots
- building in any empty slot succeeds when gold is sufficient
- building consumes gold
- building fails on occupied slots
- building fails for invalid slot indexes
- building fails when the per-city type cap reaches 5
- building caps are isolated per city
- upgrading a building consumes gold and increments its level
- upgrading an empty slot fails
- soldier level from a building follows the building level
- no-building idle time deals no damage
- building idle damage replaces old global idle damage
- building idle damage can conquer the current city
- conquered cities clear or discard building state
- decoding invalid building state normalizes instead of failing

### `BattleCombatStateTests`

Cover:

- Infantry and Archer are created with distinct HP and range
- soldier level increases attack power and HP
- manual soldiers carry manual source
- building-spawned soldiers carry building source
- manual live count includes only manual soldiers
- building-spawned soldiers do not count toward manual cap
- tower targeting and city damage still work for both soldier types

### `BattleSceneTests`

Cover:

- manual selector changes the soldier type used by spawn
- manual spawn cap blocks the 11th manual live soldier
- building-spawned soldiers do not block manual spawning
- active building timer creates live soldiers during battle
- Build control routes to Building View

### `BuildingViewSceneTests`

Cover:

- grid renders 25 selectable slots
- empty slot selection exposes build actions
- occupied slot selection exposes upgrade action
- successful build updates the slot display and gold display
- type-cap and insufficient-gold failures show feedback
- Back to Battle routes through the scene router

## Implementation Notes

This should follow the existing Pyxis workflow:

- design spec in `docs/superpowers/specs/`
- implementation plan in `docs/plans/` or `docs/superpowers/plans/`
- Swift Testing for pure models
- XCTest only for UI test targets
- no `project.pbxproj` edits for new Swift files because synchronized root groups pick them up automatically
- verify with the available simulator destination; this machine has recently used `iPhone 17` with `-parallel-testing-enabled NO`
