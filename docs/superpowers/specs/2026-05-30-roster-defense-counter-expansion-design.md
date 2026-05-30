# Roster And Defense Counter Expansion Design

## Context

Pyxis currently has a 15-city Country 1 campaign, a per-city 25-slot Building View, two soldier types, building-produced live soldiers, building-based idle damage, and a live battle model where player soldiers attack a city defended by one tower.

The current architecture is worth preserving:

- `KingdomGameState` owns durable campaign, city, gold, building, idle, conquest, and save-normalization rules.
- `CityBuildingState` owns per-city building-grid value types.
- `SoldierType` owns soldier identity.
- `BattleCombatState` owns transient live soldiers, tower targeting, movement, attacks, damage, and deaths.
- SpriteKit scenes render and route the state without owning durable game rules.

This design deepens the game by adding a classic kingdom roster and authored city defense traits. The goal is to create strategic build choices without rewriting combat into defender-unit battles or adding a magic command system yet.

## Goals

- Expand the player roster to five soldier types: Infantry, Archer, Cavalry, Mage, and Siege.
- Add one matching building for each soldier type.
- Unlock new unit buildings progressively across the 15-city country.
- Remove the global battle troop-upgrade button.
- Make building upgrades the main unit-scaling path.
- Require a matching current-city building before a soldier type can be manually spawned.
- Add authored city defense traits that are visible on the country map and battle HUD.
- Apply light counter modifiers to live city damage and idle building damage.
- Preserve city-scoped building state, city conquest cleanup, existing map gating, and abstract idle resolution.

## Non-Goals

- Enemy defender units that move and fight on the battlefield.
- Multiple enemy towers per city.
- Player tower placement.
- Active magic buttons or spell casting.
- Hard counters that make a city impossible without one unit type.
- Persistent live soldiers after backgrounding or scene rebuilds.
- Stored armies or queued troops.
- Replayable conquered-city building state.
- A new country or branching map.
- New art generation as part of the mechanics spec.

## Core Loop

Each city becomes a small scouting and building puzzle:

1. The country map shows the next city's defense trait before entry.
2. The player enters the city, then builds or upgrades current-city unit buildings.
3. A built unit building unlocks manual spawning for its soldier type.
4. Buildings also auto-spawn their matching soldier type during active battle.
5. Soldier city damage is modified by the current city's defense trait.
6. Idle building damage uses the same soldier type, level, and defense-trait modifier.
7. Conquest awards gold, pauses progression, clears that city's buildings, and returns the player to the map flow.

The player should be able to win with imperfect counters, but planning should be materially faster and safer.

## Player Roster

The expanded soldier roster is:

- Infantry: baseline durable melee.
- Archer: ranged, lower HP, safer against melee-punishing defenses.
- Cavalry: fast melee, strong against fragile or long-range defenses.
- Mage: ranged magic attacker, strong against armored or shielded defenses.
- Siege: slow, high city damage, strong against fortified cities.

`SoldierType` expands from two cases to five cases:

- `infantry`
- `archer`
- `cavalry`
- `mage`
- `siege`

The existing Infantry and Archer behavior should remain recognizable. New types add stat variety through the same live-combat fields that already exist: HP, defense, attack power, attack speed, attack range, and movement speed.

## Unit Buildings

Each soldier type has one matching building:

- Barracks -> Infantry
- Archery Range -> Archer
- Stable -> Cavalry
- Mage Tower -> Mage
- Siege Workshop -> Siege

`BuildingType` expands to include:

- `barracks`
- `archeryRange`
- `stable`
- `mageTower`
- `siegeWorkshop`

The current per-city building constraints stay in place:

- 25 slots per city.
- One building per slot.
- Max 5 buildings per type per city.
- Buildings are temporary siege infrastructure for the current city.
- The conquered city's building state is removed or reset after conquest.

## Progressive Unlocks

Country 1 introduces the roster gradually:

| City | Newly Available Building | Soldier Type |
| --- | --- | --- |
| 1 | Barracks | Infantry |
| 2 | Archery Range | Archer |
| 5 | Stable | Cavalry |
| 8 | Mage Tower | Mage |
| 11 | Siege Workshop | Siege |

Unlocked means the building type can be constructed in the current city's Building View. It does not mean the unit is manually spawnable by itself. Manual spawning still requires at least one matching building to exist in the current city.

Cities before an unlock should show the locked building type as disabled with clear feedback. The first implementation can use simple text feedback such as `Unlocks at City 5`.

## Upgrade Model

The existing global battle `Upgrade` button is removed. Building upgrades become the main scaling path.

Rules:

- Building-spawned soldiers use the level of the building that spawned them.
- Manual soldiers use the highest level among matching buildings in the current city.
- If the current city has no matching building, that soldier type cannot be selected or spawned manually.
- Upgrading a building improves future auto-spawned soldiers from that building.
- Upgrading any building of a type can improve manual spawning if it becomes the highest-level building of that type.

This keeps scaling local to the city plan and makes the Building View the main strategic surface.

## Enemy Defense Traits

Each city has one authored defense trait. Traits are city/tower archetypes only. They do not spawn enemy defender units.

Initial trait set:

- Standard Watch: no damage modifier; baseline introduction.
- Arrow Tower: stronger against low-HP ranged units; Infantry and Cavalry are safer.
- Spiked Gate: punishes melee attackers; Archer and Mage perform better.
- Stone Wall: resists light attacks; Siege and Mage perform better.
- Arcane Ward: resists magic; Infantry, Cavalry, and Siege perform better.
- Burning Oil: punishes slow close-range units; Archer, Mage, and Cavalry perform better.
- Reinforced Keep: high city pressure and fortification; Siege performs best.

Traits should be visible:

- on the country map for visible cities, especially the next unlocked city
- in the battle HUD for the current city

This gives players enough information to build counters before committing gold.

## Counter Modifiers

Counters are light, not hard locks.

Recommended modifier shape:

- favorable unit: about `+25%` city damage
- unfavorable unit: about `-20%` city damage
- neutral unit: normal city damage

These modifiers apply only to soldier damage against the city. Tower damage, targeting, and movement can remain mostly unchanged in the first implementation. A trait may later adjust tower behavior if the mechanic needs more flavor, but city-damage modifiers are the first slice.

Counter examples:

| Trait | Favorable Units | Unfavorable Units |
| --- | --- | --- |
| Standard Watch | none | none |
| Arrow Tower | Infantry, Cavalry | Archer, Mage |
| Spiked Gate | Archer, Mage | Infantry, Cavalry |
| Stone Wall | Mage, Siege | Archer |
| Arcane Ward | Infantry, Cavalry, Siege | Mage |
| Burning Oil | Archer, Mage, Cavalry | Infantry, Siege |
| Reinforced Keep | Siege | Archer, Infantry |

Damage should still clamp to at least 1 when a soldier attack would otherwise deal positive base damage. Overkill should not carry into the next city.

## Authored Country 1 Defense Progression

The 15-city sequence should teach traits gradually and revisit them after the relevant counters unlock.

Proposed progression:

| City | Defense Trait | Purpose |
| --- | --- | --- |
| 1 | Standard Watch | baseline Infantry |
| 2 | Standard Watch | introduces Archer without pressure |
| 3 | Arrow Tower | teaches durable melee/faster units matter |
| 4 | Spiked Gate | teaches ranged units matter |
| 5 | Arrow Tower | introduces Cavalry as a strong answer |
| 6 | Stone Wall | previews the need for heavier damage |
| 7 | Burning Oil | asks for ranged or fast planning |
| 8 | Stone Wall | introduces Mage as an answer |
| 9 | Arcane Ward | prevents Mage from becoming universal |
| 10 | Spiked Gate | reinforces ranged planning |
| 11 | Reinforced Keep | introduces Siege as an answer |
| 12 | Burning Oil | tests avoiding slow close-range units |
| 13 | Arcane Ward | tests non-magic answers |
| 14 | Stone Wall | tests Mage/Siege composition |
| 15 | Reinforced Keep | final Country 1 fortification |

The exact numbers can be tuned during implementation, but the authored sequence should stay stable so tests can assert city trait expectations.

## Data Model

Add a pure Swift `CityDefenseTrait` enum:

- `standardWatch`
- `arrowTower`
- `spikedGate`
- `stoneWall`
- `arcaneWard`
- `burningOil`
- `reinforcedKeep`

It should provide:

- display name
- short description
- counter modifier for a `SoldierType`
- optional UI hint text

`KingdomGameState` should expose:

- `defenseTrait(for cityNumber: Int) -> CityDefenseTrait`
- `currentCityDefenseTrait`
- `unlockedBuildingTypes(for cityNumber: Int) -> [BuildingType]`
- `isBuildingTypeUnlocked(_:for:)`
- `manualSoldierLevel(for:) -> Int?`
- trait-adjusted soldier city damage helpers for live and idle paths

`BattleCombatState` should not know about the whole campaign. It can receive either:

- already-adjusted attack power when a soldier is spawned, or
- a compact combat configuration that includes the current trait's damage modifier table.

The preferred first implementation is to pass already-adjusted city attack power into spawned live soldiers. That keeps `BattleCombatState` simple and avoids campaign concepts leaking into the live simulator.

## Scene Responsibilities

### `CountryMapScene`

Show the defense trait for visible cities. The next unlocked city should make its trait easy to read so the player can plan buildings before entering.

Completed and unlocked city states should show their authored defense trait. Locked future cities keep their locked behavior and do not need to reveal future traits in this slice.

### `BuildingViewScene`

Use city unlock rules to render build actions:

- available building types can be built if slot, cap, and gold rules pass
- locked building types are shown disabled with unlock feedback
- building upgrade remains the main unit-scaling action

The 5x5 city-grid model stays unchanged.

### `BattleScene`

Battle scene changes:

- remove the global `Upgrade` action from the battle controls
- show the current city's defense trait in the HUD
- restrict the manual spawn selector to currently build-unlocked and current-city-built soldier types
- use the highest current-city matching building level for manual spawns
- use source building level for building spawns
- apply counter-adjusted city damage through the same conquest flow as today

If no manual soldier type is currently spawnable, the spawn control should give clear feedback such as `Build a unit building first`.

## Idle Damage

Idle/offline building damage uses the same strategic rules as live city damage:

1. Resolve building spawn cycles as the current system does.
2. For each abstract spawn, get its soldier type and building level.
3. Compute base soldier attack power from type and level.
4. Apply the current city's defense-trait modifier.
5. Sum adjusted damage.
6. Apply capped city damage and conquest rules.

Idle still does not simulate:

- soldier movement
- tower shots
- deaths
- live entity persistence
- overflow into the next city

No buildings still means no idle damage.

## Save Compatibility And Normalization

Changes should be additive and defensive:

- Existing saves with Barracks and Archery Range continue decoding.
- New building enum cases decode normally once introduced.
- Unsupported or corrupt building types are dropped through the existing lossy decode behavior.
- Invalid slots are dropped.
- Building levels clamp to at least 1.
- Per-type caps still clamp by sorted slot order.
- Completed-city building state is still discarded.
- Missing trait data is not persisted; traits come from authored lookup by city number.

Because city defense traits are authored by city number, they do not need to be stored in each save file for this slice.

## Error Handling And Bounds

- Locked building type: build action is blocked with clear feedback.
- Missing matching building: manual spawn is blocked.
- No manual unit selected after unlock changes: selector falls back to the first spawnable type or shows build-first feedback.
- Invalid slot: existing invalid-slot handling remains.
- Slot occupied: existing slot-occupied handling remains.
- Type cap reached: cap remains 5 per type per city.
- Insufficient gold: existing cost feedback remains.
- Stage unavailable: building and spawning remain unavailable outside active battle state.
- Conquest: live combat stops, current city buildings clear, and map routing remains stage-driven.
- Poor counters: battle is slower, not impossible.
- Counter-adjusted positive damage: clamps to at least 1.

## Testing

Use pure Swift tests for most rules and focused SpriteKit tests for scene integration.

### Model Tests

Add or update tests for:

- all five `SoldierType` display names
- all five `BuildingType` display names and soldier mappings
- progressive building unlocks for Cities 1, 2, 5, 8, and 11
- locked building types being rejected cleanly
- manual spawn availability requiring a matching current-city building
- manual soldier level using the highest matching building level
- building-spawned soldier level using source building level
- defense trait lookup for all 15 Country 1 cities
- favorable, neutral, and unfavorable counter modifiers
- live city damage using counter-adjusted attack power
- idle building damage using counter-adjusted attack power
- save decode preserving valid old building data
- save decode dropping unsupported or corrupt building data

### Scene Tests

Add or update tests for:

- `BattleScene` no longer exposing the global upgrade action
- `BattleScene` showing the current defense trait text
- manual selector listing only built and unlocked unit types
- spawn feedback when no matching unit building exists
- building-spawned units still enter live combat
- `CountryMapScene` showing defense trait text for the next unlocked city
- `BuildingViewScene` showing locked building types as disabled
- conquest still clearing live soldiers and current-city buildings

### Manual Verification

Run simulator checks through at least:

- early game: Cities 1-3, Infantry and Archer flow
- mid unlock: City 5 Cavalry unlock
- magic unlock: City 8 Mage unlock
- late unlock: City 11 Siege unlock
- final pressure: City 15 Reinforced Keep

Manual verification should confirm map trait visibility, build unlocks, manual selector behavior, auto-spawns, counter impact, idle damage, conquest cleanup, and routing back to the country map.
