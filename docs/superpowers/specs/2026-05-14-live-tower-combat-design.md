# Live Tower Combat Design

## Context

Pyxis currently has a campaign battle loop built around a player-controlled `Spawn Soldier` button. A spawned soldier is visible in `BattleScene`, walks from the player castle to the enemy city, and applies one abstract `KingdomGameState.spawnSoldierAttack()` when it reaches impact. City conquest awards gold, pauses progression, opens the conquest popup, and requires the player to enter the next city from `CountryMapScene`.

This design keeps that identity but makes the battle less idle. Spawned soldiers become live combat units with HP, defense, attack power, attack speed, attack range, and movement speed. Each city gains one defensive tower that attacks soldiers.

## Goal

Add a first real-time combat layer to city battles:

- each spawned soldier has HP, defense, attack power, attack speed, attack range, and movement speed
- soldiers move toward the city, stop when in attack range, and attack repeatedly
- soldiers remain on the battlefield until they die or the city is conquered
- each city has one tower that attacks living soldiers
- tower damage can kill soldiers before they reach or destroy the city
- the existing spawn-button control, attack-power upgrade, conquest popup, country map gate, and idle-catch-up rules remain intact

## Non-Goals

- Multiple soldier types.
- Multiple towers per city.
- Destructible towers.
- Tower placement.
- Tower upgrades.
- Manual soldier targeting.
- Manual tower targeting.
- Stored army counts.
- Persisting live soldiers through app backgrounding or scene rebuilds.
- Multiple lanes.
- Changing the current Country 1 map progression model.
- Expanding upgrades beyond attack power in this slice.

## Architecture

Keep the current separation between durable progression, live combat rules, and SpriteKit presentation.

### `KingdomGameState`

`KingdomGameState` remains the persisted source of truth for:

- country and city progress
- stage status
- city remaining HP
- city max HP
- gold
- normal soldier attack-power upgrade level
- upgrade cost
- idle catch-up
- conquest rewards
- map gating

It remains SpriteKit-free. It does not own walking soldiers, tower targeting, projectile timing, or animation nodes.

### `BattleCombatState`

Add a new pure Swift model for active live combat. A likely name is `BattleCombatState`.

This model owns temporary battle entities and combat rules:

- live soldier instances
- soldier positions along the lane
- soldier HP and death
- soldier attack cooldowns
- tower cooldowns
- tower targeting
- per-tick movement and attack resolution
- emitted city damage events
- emitted soldier damage/death events

The live combat model is recreated when `BattleScene` opens. It receives durable inputs from `KingdomGameState`, such as current city HP and normal soldier attack power, but it does not persist itself.

### `BattleScene`

`BattleScene` becomes the renderer/controller for live combat.

Responsibilities:

- convert button taps into live combat spawns
- call the combat model from `update(_:)`
- render soldier sprites, HP bars, tower shots, hit flashes, deaths, and city attacks
- apply emitted city damage to `KingdomGameState`
- save `KingdomGameState` after city damage, conquest, background, and foreground transitions
- clear live soldiers after conquest or idle conquest
- preserve the existing conquest popup and country-map routing

## Combat Model

The first live-combat slice has one normal soldier type and one defensive tower per city.

### Normal Soldier

A spawned soldier has:

- `id`
- `maxHP`
- `currentHP`
- `defense`
- `attackPower`
- `attackSpeed`
- `attackRange`
- `movementSpeed`
- `position`
- attack cooldown state
- alive/dead state

`attackPower` is derived from the existing `normalSoldierAttackPower`. The existing upgrade button continues to improve only attack power.

The other stats use fixed formulas for this slice. They can later become additional upgrade axes if the combat loop needs deeper progression.

### City Tower

Each active city has one tower with:

- `damage`
- `attackSpeed`
- `attackRange`
- targeting cooldown state

Tower stats scale by city level so later cities defend themselves more strongly.

### Damage Formula

Tower damage against a soldier uses a simple defense formula:

```swift
damageTaken = max(1, towerDamage - soldierDefense)
```

A soldier dies only when `currentHP <= 0`.

Soldier attacks use the existing attack-power formula. City damage is capped at the city remaining HP before conquest is reported, preserving the current foreground rule that overkill damage does not carry into the next city.

### Movement And Attacks

Combat advances in ticks.

Soldiers move toward the city while they are alive and outside attack range. Once a soldier is within attack range, it stops moving and attacks repeatedly when its attack cooldown resolves.

The tower targets the living soldier closest to the city within tower range. If no living soldier is in range, the tower waits. If a target dies before a shot resolves, the shot is ignored.

## Progression, Persistence, And Idle

Live soldier instances are temporary and are not saved. If the app backgrounds or the battle scene is rebuilt, active soldiers are discarded.

Durable city HP still lives in `KingdomGameState`. When live combat emits city damage, `BattleScene` applies it to `KingdomGameState` and saves.

When city HP reaches 0:

1. city damage is capped to the remaining HP
2. gold is awarded through the existing progression rules
3. the city is marked completed
4. combat pauses
5. live soldiers are cleared
6. the conquest popup opens
7. the next city must be entered from the country map

Offline progress keeps the existing abstract idle rule. On resume, up to 8 hours of progress can damage only the active city, can conquer at most that city, and cannot carry over into the next city. Idle catch-up does not simulate individual soldier HP, tower shots, or live combat instances.

If idle progress conquers the city, `BattleScene` clears any live soldiers before showing the conquest popup.

## Battle Presentation

The battlefield remains familiar:

- player castle on the left
- enemy city on the right
- spawn and upgrade controls at the bottom
- gold, city title, attack power, city HP, and HP bar in the status area

Live combat adds:

- persistent soldier sprites after they reach attack range
- small HP bars above living soldiers
- repeated soldier attack motions while in range
- a simple tower projectile or flash from the enemy city toward the targeted soldier
- death feedback when a soldier reaches 0 HP
- immediate removal of dead soldiers
- clearing all remaining soldiers when the city is conquered

The city tower can be represented by the enemy city area and a projectile/flash effect in this slice. A separate tower asset is not required until the mechanic proves worth further art investment.

The status UI should stay compact. Add at most one live-combat status line, such as `Soldiers: 3`, rather than exposing every stat on the main screen.

## Error Handling And Bounds

- Spawning is blocked while `stageStatus` is not `battleActive`.
- Spawning is blocked while the conquest popup is visible.
- Combat ticks clamp unusually large `deltaTime` values so resume or frame stalls do not instantly wipe the battlefield.
- Dead soldiers do not move, attack, receive new targeting, or apply city damage.
- If the tower has no living soldier in range, it waits.
- If a tower target dies before damage resolves, the shot is ignored.
- If the city is already conquered, live soldiers stop applying damage.
- City damage is capped to the remaining city HP before conquest is reported.
- All live soldiers are cleared after conquest or idle conquest.
- Corrupted persisted values continue to normalize through `KingdomGameState`.

## Testing

Use pure Swift tests for the new combat rules and keep SpriteKit tests focused on scene integration.

### `BattleCombatStateTests`

Cover:

- spawning creates a soldier with full HP and fixed stats
- soldiers move until they enter attack range
- soldiers stop once they are in range
- soldiers attack repeatedly on cooldown
- city damage is emitted only when an attack cooldown resolves
- tower targets a living soldier in range
- tower chooses the living soldier closest to the city
- defense reduces tower damage with a minimum of 1
- soldier death happens only when HP reaches 0
- dead soldiers no longer move, attack, or receive targeting
- conquest is reported when emitted city damage reaches remaining city HP
- large tick deltas are clamped

### `KingdomGameStateTests`

Keep durable-rule coverage for:

- attack-power upgrades affect live soldier attack power through the derived formula
- idle catch-up remains capped at 8 hours
- idle catch-up can damage only the active city
- idle catch-up stops at conquest
- conquest pauses progression and routes through the map gate

### `BattleSceneTests`

Cover:

- tapping spawn creates one live combat soldier
- combat ticks can damage durable city HP and save it
- tower damage can kill and remove a visible soldier
- conquest clears live soldiers and shows the existing popup
- idle conquest clears live soldiers before showing the popup

Manual verification should check the simulator for readable multi-soldier battles, visible soldier HP bars, tower shots, soldier deaths, repeated attacks, city HP changes, and the existing conquest-to-map flow.
