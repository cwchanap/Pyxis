# Idle Kingdom MVP Design

## Context

Pyxis is currently a fresh SpriteKit iOS project with the default `GameScene` sample and no existing game systems. The MVP will replace the starter interaction with a simple idle-conquest loop while keeping the implementation small and testable.

## Goal

Build the basic mechanism for an idle kingdom game:

- The player represents a kingdom attacking one city.
- The player has one troop type: normal soldier.
- In active foreground play, the player taps a spawn button.
- Each spawned soldier immediately attacks once, deals its own attack power to the city, and disappears.
- When the app is idle because it is in the background, soldiers spawn automatically and immediately attack.
- Conquering the city grants gold.
- Gold upgrades normal soldier attack power.
- City HP grows by a stronger-than-2x exponential curve after every conquest.

## Non-Goals

- Multiple cities.
- Multiple troop types.
- Stored soldier army counts.
- Separate attack assignment UI.
- Offline migration or save-version migration.
- Custom art assets beyond simple SpriteKit shapes, labels, and bars.

## Architecture

Use a clean split between game rules and SpriteKit presentation.

### `KingdomGameState`

Owns all core rules and state:

- `gold`
- `cityLevel`
- `cityRemainingPower`
- `cityMaxPower`
- `normalSoldierUpgradeLevel`
- `normalSoldierAttackPower`
- `lastBackgroundedAt`

It exposes intention-revealing methods:

- `spawnSoldierAttack(now:)`
- `upgradeNormalSoldier()`
- `enterBackground(at:)`
- `returnFromBackground(at:)`
- formula helpers for city HP, gold reward, attack power, and upgrade cost

This model must not depend on SpriteKit. Unit tests should be able to cover progression without constructing a scene.

### `GameScene`

Owns rendering and input:

- status labels for gold, city level, soldier attack, and upgrade cost
- a city HP label and HP bar
- a primary `Spawn Soldier` button
- a secondary `Upgrade Soldier` button
- feedback text for damage, conquest, upgrades, and insufficient gold

`GameScene` calls model methods, then redraws labels and bars from the model state.

### App Lifecycle

The app should notify the scene or model when it enters background and foreground. Background entry records a timestamp. Foreground return applies idle progress once and clears the timestamp so progress cannot be double-counted.

## Core Loop

### Foreground Play

The first screen is the game scene. There is no main menu for the MVP.

When the player taps `Spawn Soldier`:

1. The game creates one normal soldier attack event.
2. That event immediately deals `normalSoldierAttackPower` damage to the city.
3. The soldier disappears.
4. The city HP bar and labels update.

There is no persistent soldier count and no separate attack button.

### Conquest

The city has `remainingPower`. If a soldier attack reduces it to `0` or below:

1. Clamp city HP at `0`.
2. Grant gold for the conquered city.
3. Increase `cityLevel` by `1`.
4. Create the next version of the same city with newly calculated max HP.
5. Reset `cityRemainingPower` to the new `cityMaxPower`.
6. Show feedback that the city was conquered and gold was earned.

Damage does not carry over from a foreground tap after conquest. Idle catch-up can continue applying remaining accumulated damage across multiple conquests.

### Upgrades

Gold is only used to upgrade normal soldier attack power.

When the player taps `Upgrade Soldier`:

1. If gold is at least the current upgrade cost, spend the cost.
2. Increase `normalSoldierUpgradeLevel` by `1`.
3. Recalculate `normalSoldierAttackPower`.
4. Update the displayed attack power and next cost.

If the player cannot afford the upgrade, state does not change and the feedback label shows the missing gold condition.

### Idle Background Progress

Idle mode means the app is in the background. No manual toggle is required.

On background return:

1. Calculate elapsed seconds from `lastBackgroundedAt`.
2. Clamp elapsed time to a maximum of 8 hours.
3. Convert elapsed time into automatic soldier attacks at `1 soldier / second`.
4. Each automatic soldier deals current `normalSoldierAttackPower`.
5. Apply total automatic damage against the current city, looping through conquests if enough damage is available.
6. Clear `lastBackgroundedAt`.
7. Show a summary such as `Idle attacks dealt 540 damage and conquered 2 cities`.

No automatic spawning happens while the app is foregrounded.

## Formulas

Use simple, explicit formulas that can be tuned later.

```swift
cityMaxPower = round(20 * pow(2.15, cityLevel - 1))
goldReward = round(8 * pow(1.45, cityLevel - 1))

normalSoldierAttackPower = ceil(pow(1.38, normalSoldierUpgradeLevel - 1))
normalSoldierUpgradeCost = round(10 * pow(1.7, normalSoldierUpgradeLevel - 1))
```

All formula outputs must be clamped to at least `1`.

The balance intent:

- city HP grows fastest, above `2x` per level
- soldier attack power grows exponentially so upgrades stay meaningful
- attack power grows slower than city HP so conquest pressure increases over time
- gold reward grows slower than upgrade cost so later upgrades require repeated conquest
- the first city has `20 HP`, so the first conquest takes 20 taps at attack power 1

Example city HP:

| City Level | HP |
| ---: | ---: |
| 1 | 20 |
| 2 | 43 |
| 3 | 92 |
| 4 | 199 |
| 5 | 427 |
| 6 | 919 |
| 7 | 1,976 |
| 8 | 4,247 |
| 9 | 9,130 |
| 10 | 19,631 |

## Persistence

Use `UserDefaults` for MVP persistence.

Save after:

- each spawn attack
- each conquest
- each successful upgrade
- background entry
- foreground idle catch-up

Persist only the current game state needed to resume:

- gold
- city level
- city remaining power
- normal soldier upgrade level
- last background timestamp, if any

Derived values such as max city power, gold reward, soldier attack power, and upgrade cost should be recalculated from formulas on load.

Because this is prototype-phase work, no save migration system is required.

## Error Handling And Bounds

- Clamp city HP to `0` before conquest reset.
- Clamp all formula outputs to at least `1`.
- Clamp background catch-up to 8 hours.
- Failed upgrades must not mutate gold or upgrade level.
- Foreground soldier spawn always applies exactly one attack event.
- Background catch-up must clear the stored timestamp after applying so the same idle duration cannot be claimed twice.

## Testing

Add Swift unit tests for the pure model:

- spawning one soldier reduces city HP by current soldier attack power
- conquering a city grants gold and advances city level
- a foreground tap does not carry over excess damage after conquest
- a successful upgrade spends gold and increases attack power using the exponential formula
- a failed upgrade leaves gold, upgrade level, and attack power unchanged
- idle catch-up applies automatic soldier damage
- idle catch-up can conquer multiple cities
- idle catch-up clears the background timestamp so it cannot be applied twice

Keep UI tests minimal for this first slice. A launch/smoke test is enough unless stable accessibility identifiers are cheap to expose during implementation.
