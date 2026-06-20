# Enhance Animation (HPA-83)

**Date:** 2026-06-20
**Linear issue:** [HPA-83 Enhance animation](https://linear.app/cwchanap/issue/HPA-83/enhance-animation)
**Status:** Approved

## Summary

Improve the battle presentation by making the three lanes visually denser and replacing static soldier visuals with generated frame-based animation. Each soldier type gets distinct art for walking, attacking, and taking tower damage.

## Requirements

1. The three marching lanes should leave minimal space between them while staying readable.
2. Infantry, archer, cavalry, mage, and siege soldiers each get their own generated animation art.
3. Each soldier type has 10 frames for each action:
   - `walk`
   - `attack`
   - `hit`
4. Generated strips are sliced into predictable asset catalog image sets:
   - `<soldier>-walk-01` through `<soldier>-walk-10`
   - `<soldier>-attack-01` through `<soldier>-attack-10`
   - `<soldier>-hit-01` through `<soldier>-hit-10`
5. `BattleScene` plays a looping walk animation for living soldiers.
6. `BattleScene` plays attack frames when a soldier attack lands.
7. `BattleScene` plays hit frames when tower damage lands.
8. Missing generated frames fall back to existing static sprite behavior so the scene remains testable and shippable.

## Art Direction

The five soldier types should look distinct but belong to the same chibi fantasy mobile-game style already used by Pyxis. Frames must be readable at small iPhone battlefield scale, with the character centered and fully visible in every frame.

| Soldier | Visual direction |
| --- | --- |
| Infantry | Sword and small shield, blue-accented friendly armor |
| Archer | Hooded bow user, green accents |
| Cavalry | Mounted knight or rider silhouette, warm orange accents |
| Mage | Robed caster with staff, violet magic accents |
| Siege | Compact siege engineer or small ram/cannon crew, gray metal accents |

Sprite strips are generated on a flat chroma-key background and locally converted to transparent PNG frames. The final asset frames should avoid shadows, UI text, watermarks, and inconsistent scale jumps between frames.

## Architecture

### Asset pipeline

Generate one 10-frame horizontal sprite strip per soldier/action pair:

- 5 soldier types
- 3 actions
- 10 frames per strip

That produces 15 strips and 150 final frame image sets. A local slicing script turns each strip into square PNG frames and creates the `.imageset/Contents.json` files. The source strips can live under `tmp/` during generation; only final frame image sets are app assets.

### Runtime animation

`BattleScene` keeps the combat model untouched. Animation selection is a scene responsibility:

- Soldier type and action map to a list of asset names.
- A soldier body is an `SKSpriteNode` when generated frames or existing static art are available.
- Walk animation runs under a stable action key while the soldier is alive.
- Attack and hit animations temporarily replace the body textures, then resume walk if the soldier is still alive.
- Existing city hit, tower projectile, HP bar, and conquest feedback remain unchanged.

### Lane density

`BattlefieldLayout` owns lane geometry, so lane spacing changes belong there. The new lane centers stay symmetric around the battlefield center but use a smaller horizontal spread than the current 25% / 50% / 75% layout. Fallback layouts remain valid for tiny scenes.

## Fallbacks

- If a generated action frame is missing, `BattleScene` falls back to the static soldier asset for that soldier type.
- If the soldier-specific static asset is missing, the existing colorized fallback remains available.
- Missing animation frames must not crash tests or gameplay.

## Out of Scope

- No changes to combat formulas, tower targeting, spawn rates, or city damage.
- No player lane selection.
- No changes to `CountryMapScene` or `BuildingViewScene`.
- No new UI controls.
- No per-frame hitboxes or physics.

## Testing

Swift Testing coverage should verify stable behavior without depending on exact visual pixels:

- `BattlefieldLayoutTests` pins compact, symmetric lane spacing.
- `BattleSceneTests` verifies each soldier type resolves 10 frame names for each action.
- `BattleSceneTests` verifies spawned soldiers start a walking animation when frames exist.
- `BattleSceneTests` verifies attack and hit action keys can run from combat tick results.
- Existing combat model tests remain the source of truth for damage and tower behavior.

Manual verification should inspect generated assets and run the app or test scene enough to confirm that soldiers animate and lane spacing is denser.
