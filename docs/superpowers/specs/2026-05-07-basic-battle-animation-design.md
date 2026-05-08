# Basic Battle Animation Design

## Context

Pyxis currently has a working idle kingdom MVP. `KingdomGameState` owns the pure combat and progression rules, `KingdomGameStore` persists state in `UserDefaults`, and `GameScene` presents SpriteKit labels, HP bar, feedback text, and spawn/upgrade buttons.

The next slice should replace the mostly text-driven spawn experience with visible battle animation. The player castle should send soldiers toward an enemy city, and city damage should happen when a soldier reaches the city and attacks.

## Goal

Add a basic animated battle presentation to `GameScene`:

- show a player castle on the left side of the battlefield
- show an enemy city/castle on the right side
- keep the existing `Spawn Soldier` button
- spawn a visible soldier when the button is tapped
- allow multiple soldiers to be in flight at once
- apply attack damage only when a soldier reaches the city and performs its attack
- use generated chibi anime fantasy game art for the castle, city, and soldier

## Non-Goals

- Tap-anywhere spawning.
- Physics, collision, pathfinding, or tactical movement.
- Multiple lanes.
- Multiple troop types.
- Stored army counts.
- Texture atlas optimization.
- Reworking the pure combat formulas.
- Brittle UI tests that inspect SpriteKit animation frames.

## Art Direction

Use generated chibi anime fantasy PNG assets with transparent backgrounds. The assets should be readable at iPhone gameplay scale and visually consistent with each other.

Required assets:

- `player-castle.png`: friendly kingdom castle, transparent background
- `enemy-city.png`: enemy fortified city/castle, transparent background
- `normal-soldier.png`: small readable chibi soldier, transparent background

Optional asset:

- `impact-flash.png`: only if the generated art set benefits from a drawn impact effect. A SpriteKit shape flash is acceptable for this slice.

The background can remain code-rendered with simple sky/ground bands or battlefield colors. The important game objects should use generated art, while the environment stays flexible for different screen sizes.

## Scene Layout

`GameScene` should become a battlefield-first scene while keeping the existing progression UI available.

The battlefield layout:

- player castle anchored on the left side
- enemy city anchored on the right side
- a ground lane between them
- soldiers spawn at the player castle gate
- soldiers move toward the enemy city gate

The UI layout:

- gold, city level, soldier attack, city HP, and HP bar stay in a compact status area
- the `Spawn Soldier` and `Upgrade Soldier` controls stay at the bottom
- the feedback label remains available for conquest and upgrade messages, but it should no longer be the primary gameplay feedback

Sprite sizes should be derived from the current scene size. They should not rely on raw image pixel dimensions. Existing orientation handling should continue to call layout code when the scene size changes.

## Spawn And Attack Flow

Tapping `Spawn Soldier` creates a soldier sprite immediately, but it does not mutate `KingdomGameState` immediately.

Each soldier runs independently:

1. Spawn at the player castle gate.
2. Walk toward the enemy city over a short fixed duration.
3. Perform a small attack motion near the enemy city.
4. Apply combat by calling `state.spawnSoldierAttack()` at the impact moment.
5. Save state through `KingdomGameStore`.
6. Redraw labels and HP bar from the updated state.
7. Remove the soldier sprite.

Repeated taps should create repeated soldiers. Multiple soldiers may walk across the battlefield at the same time. Damage lands in impact order.

If one soldier conquers the current city, any later in-flight soldier attacks the newly reset city when it reaches the target. This preserves the existing foreground rule: overkill damage from one foreground soldier does not carry into the next city.

## Animation Details

Soldier animation should be intentionally simple:

- walk from castle gate to city gate using `SKAction.move`
- add a subtle bob, scale pulse, or leg/weapon motion so the soldier does not slide stiffly
- perform a short lunge or weapon swing near the city
- remove the soldier after the attack finishes

Hit feedback:

- flash or briefly shake the enemy city at the impact moment
- update the HP bar and city HP text after applying damage

Conquest feedback:

- if the attack conquers the city, play a slightly stronger pulse or flash on the enemy city
- update gold, city level, and city HP after the model advances to the next city

The first implementation does not need to reposition soldiers already in motion when orientation changes. Static anchors should relayout, and in-flight soldiers can finish the path they started on.

## Asset Loading And Fallbacks

Generated images should be added to the app bundle under `Pyxis/`. The Xcode project uses file-system-synchronized groups, so the project file should not need manual registration changes.

`GameScene` should load images with `SKTexture(imageNamed:)` and build:

- persistent `SKSpriteNode`s for the player castle and enemy city
- a new `SKSpriteNode` for each spawned soldier
- SpriteKit-only fallback hit effects unless an impact asset is added

During development, missing image resources should not crash the scene. If an expected image cannot be used, `GameScene` should build a simple fallback shape node so the scene remains testable while assets are being generated or renamed.

## Architecture

Keep the existing layer split:

- `KingdomGameState` remains SpriteKit-free and unchanged unless tests reveal a model bug.
- `KingdomGameStore` remains responsible only for persistence.
- `GameScene` owns visual nodes, animation timing, impact callbacks, and UI redraws.

The key design boundary is that `GameScene` may queue visual attack animations, but it should still call the same model method when an attack actually lands. The model should not learn about walking soldiers, animation durations, or SpriteKit nodes.

## Testing And Verification

Automated coverage should stay focused on stable behavior:

- keep existing `KingdomGameState` tests as the source of truth for combat math
- add scene-level seams only if they can verify delayed impact behavior without making `GameScene` awkward
- verify that tapping spawn can create multiple pending visual soldiers before attacks land
- verify that each impact applies one model attack, saves state, and redraws UI

Do not add fragile UI tests that depend on exact SpriteKit animation frames or text node discovery.

Manual or smoke verification should include:

- the app launches without missing-resource crashes
- castle, enemy city, and soldier art render at usable sizes
- tapping `Spawn Soldier` starts a soldier from the castle
- HP changes when the soldier reaches the city, not at tap time
- repeated taps show multiple soldiers in flight
- conquest still grants gold and advances city level

## Open Decisions

None for this slice. The approved defaults are:

- keep the spawn button
- apply damage on soldier impact
- allow multiple soldiers in flight
- use generated chibi anime fantasy PNG art
- keep the background simple and code-rendered
