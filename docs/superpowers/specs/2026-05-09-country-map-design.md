# Country Map Design

## Context

Pyxis currently has one playable idle battle loop. `KingdomGameState` owns progression formulas, combat resolution, upgrades, persistence-ready values, and idle catch-up. `GameScene` owns SpriteKit presentation: battlefield art, pending soldiers, HP/status labels, spawn and upgrade buttons, and hit/conquest feedback.

This slice adds a first campaign layer without changing the core combat identity. The player still launches directly into battle on first app start. After conquering a city, the game should pause progression, show congratulations, and send the player to a country map where the next city is chosen explicitly.

## Goal

Build Country 1 as a 15-city chapter:

- each city is one battle stage
- Country 1 contains 15 cities
- first launch starts directly in `Country 1 - City 1` battle
- conquering a city shows a congratulations popup
- closing the popup routes to the country map
- the player explicitly enters the next unlocked city from the country map
- after City 15, the country is complete and no next city is available yet

The country map should use a branching-looking layout, but progression remains linear in this slice.

## Non-Goals

- World map screen.
- Multiple countries.
- Multiple simultaneously available cities.
- Branching stage choice.
- Side routes, bonus cities, or replay rewards.
- New troop types or persistent armies.
- Changing the spawn-button combat loop.
- Full save migration framework.

## Architecture

Use two SpriteKit scenes plus the existing pure state/store boundary.

### `KingdomGameState`

`KingdomGameState` remains the source of truth for campaign and combat rules. It should stay SpriteKit-free and own:

- current country number
- current city number inside the country
- completed city count for the current country
- global combat city level used by balance formulas
- current city remaining HP
- gold
- normal soldier upgrade level
- last background timestamp
- stage gate/status

The stage gate should distinguish at least:

- battle is active
- city conquest is pending map return
- country is complete

When a city is conquered, the model marks the stage complete and pauses combat. It does not automatically advance to the next city.

### `BattleScene`

`BattleScene` owns the current battlefield experience:

- player castle
- enemy city
- soldier animations
- pending soldier attacks
- status labels
- HP bar
- `Spawn Soldier`
- `Upgrade Soldier`
- congratulations popup

It applies combat only when a soldier reaches impact, matching the current battle-animation rule. When conquest occurs, it shows the popup and blocks more spawn input until the popup is closed.

### `CountryMapScene`

`CountryMapScene` owns the Country 1 map:

- 15 city nodes
- branching-looking route layout
- completed, unlocked, and locked visual states
- tap handling for city entry
- feedback for locked city taps

The first implementation should show all 15 cities, but only the next city is enterable.

### `GameViewController`

`GameViewController` becomes the scene router for the shared `SKView`. It presents:

- `BattleScene` for active battle stages
- `CountryMapScene` when the player should choose the next city

This keeps battle and map layout/input separate and leaves room for a future `WorldMapScene` above `CountryMapScene`.

## Progression Flow

First launch:

1. Load state.
2. If no city has been conquered, present `BattleScene` for `Country 1 - City 1`.

Foreground battle:

1. Player taps `Spawn Soldier`.
2. A soldier animation starts.
3. Damage is applied only at impact.
4. If the city survives, state is saved and battle continues.
5. If the city is conquered, gold is awarded, the current city is marked conquered, combat pauses, state is saved, and the congratulations popup opens.

Popup close:

1. If another city remains in Country 1, route to `CountryMapScene`.
2. If City 15 was conquered, route to the completed `CountryMapScene` with no next city unlocked.

Country map:

1. Completed cities are marked complete.
2. Exactly one next city is unlocked while the country is incomplete.
3. Future cities are visible but locked.
4. Tapping the unlocked city starts that city and routes to `BattleScene`.
5. Tapping a locked city gives lightweight feedback and does not mutate state.

Starting the next city:

1. The model validates the requested city is the next unlocked city.
2. The current city number advances.
3. The global combat city level advances according to the same progression sequence.
4. Current city HP is restored to the formula-derived max HP for the new combat level.
5. The stage gate returns to active battle.

## Idle Progress

Entering background only records `lastBackgroundedAt` and saves state. No damage, conquest, gold award, or city progression happens while the app is backgrounded.

When the app resumes, `BattleScene` asks `KingdomGameState.returnFromBackground(at:)` to apply idle progress once.

Idle progress may damage only the active city. If the calculated idle damage is at least the current city's remaining HP:

1. Apply only enough damage to conquer the active city.
2. Award that city's gold at resume time.
3. Mark that city conquered.
4. Pause combat.
5. Clear `lastBackgroundedAt`.
6. Show the congratulations popup in `BattleScene`.

Idle progress must not carry damage into the next city. The next city cannot receive damage until the player closes the popup, returns to `CountryMapScene`, and explicitly enters the unlocked city.

If the saved state is already waiting on a conquered city or completed country, resume should clear stale background timing without awarding extra progress.

## UI And Presentation

### Battle

The battle presentation keeps the current layout:

- friendly castle on the left
- enemy city on the right
- soldiers moving from castle to city
- gold, city label, soldier attack, HP label, and HP bar
- spawn and upgrade controls at the bottom

The city label should use the campaign display name, such as `Country 1 - City 3`.

### Congratulations Popup

On conquest, `BattleScene` shows a modal-style overlay above the battlefield. It should include:

- conquered label, such as `Country 1 - City 3 Conquered`
- gold earned
- one clear close/continue action

Spawn and upgrade input should be blocked while the popup is open.

For City 15, the popup should communicate that Country 1 was conquered before routing to the completed map.

### Country Map

The selected map style is a branching-looking Country 1 route. It should visually hint at future branching content, while this slice keeps linear unlocking.

The map should show:

- `Country 1` title/status
- 15 city nodes
- completed city state
- current unlocked city state
- locked future city state
- simple locked-city tap feedback

No World Map appears in this slice.

## Persistence

Continue using `KingdomGameStore` to JSON-code one `KingdomGameState` object into `UserDefaults`.

Persist only values needed to resume:

- country number
- current city number in country
- completed city count for Country 1
- global combat city level
- current city remaining HP
- gold
- normal soldier upgrade level
- last background timestamp
- stage gate/status

Derived values should continue to be computed:

- city max HP
- gold reward
- soldier attack
- upgrade cost
- whether each map city is completed, unlocked, or locked

Decode should clamp invalid persisted values instead of failing:

- country number clamps to at least `1`
- Country 1 city number clamps within `1...15`
- completed count clamps within `0...15`
- global combat level clamps to at least `1`
- city HP clamps to at least `1` while battle is active
- invalid gate/status falls back to a battle-ready state

Older prototype saves can be interpreted simply. If a save only has the old `cityLevel`, treat it as the global combat level and infer a Country 1 city from that progression, capped at City 15. No broad migration framework is required for this prototype phase.

## Error Handling And Bounds

- Combat actions should be rejected while the stage is not battle-active.
- Starting a locked or future city should fail without mutating state.
- Starting a conquered city should fail unless replay is explicitly added in a future design.
- City 15 conquest should mark the country complete and expose no next city.
- Foreground overkill damage does not carry into the next city.
- Idle overkill damage does not carry into the next city.
- Idle progress clears the background timestamp after resume so rewards cannot be claimed twice.
- Pending soldiers that impact after the city has already been conquered should not apply extra damage or rewards.

## Testing

### Unit Tests

Add Swift Testing coverage for the pure model:

- first launch starts battle-ready at `Country 1 - City 1`
- foreground conquest marks the current city conquered and pauses combat
- starting the next unlocked city advances the city and restores full HP
- locked/future city entry is rejected
- City 15 conquest marks Country 1 complete with no next city unlocked
- idle resume damages only the active city
- idle resume can conquer the active city and award gold at resume time
- idle resume cannot continue into the next city
- background timestamp is cleared after resume
- invalid campaign values are clamped on decode

### Scene Tests

Keep scene tests narrow and stable:

- `BattleScene` delays damage until soldier impact
- conquest opens the popup instead of immediately resetting into the next city
- popup close requests a country-map route
- `CountryMapScene` reports enter-city intent only for the unlocked next city

### Manual Smoke

Verify on simulator:

- app launches directly into City 1 battle
- City 1 conquest shows popup, then map
- map shows 15 cities in the branching-looking layout
- only the next city can be entered
- returning from background after enough idle time shows the reward/conquest moment on resume
- after popup close, the player returns to the country map

## Future Expansion

This design intentionally leaves room for:

- a `WorldMapScene` above country maps
- additional countries
- multiple cities per country with branching unlock rules
- replay or farming rules for completed cities
- richer country-map art and generated assets

Those behaviors are not part of the first country-map implementation.

## Open Decisions

None. The approved first slice is a two-scene design with linear Country 1 progression, a branching-looking map layout, launch directly into City 1 battle, and idle progress that pauses at the current city's conquest until the player explicitly enters the next city from the country map.
