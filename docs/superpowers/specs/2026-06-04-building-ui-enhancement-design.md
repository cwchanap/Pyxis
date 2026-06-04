# Building UI Enhancement Design

## Context

Pyxis already has a per-city Building View backed by `KingdomGameState` and `CityBattleState`. The durable model stores 25 city-specific building slots, unlock rules, costs, per-type caps, and idle building production. `BuildingViewScene` currently presents that model as a simple 5x5 grid of colored shape nodes with text labels and bottom action buttons.

This design upgrades the Building View presentation so it feels like a small countryside city-builder scene. The underlying slot IDs, build rules, upgrade rules, persistence, idle production, and unlock gates stay intact.

## Goals

- Replace the visible uniform 5x5 board with a scenic city-builder layout.
- Keep the existing 25-slot city model and slot numbering.
- Add a generated countryside settlement background image.
- Add final generated image assets for each building type.
- Show empty lots as construction pads placed around paths and terrain.
- Show occupied lots as building sprites with level badges.
- Keep every building type visible in the build palette.
- Dim locked future building icons and show their unlock city.
- Preserve current touch routing, feedback, building, upgrade, and battle-return behavior.

## Non-Goals

- Changing building costs, unlock cities, caps, idle damage, or spawn rules.
- Adding new building types.
- Adding timed construction or construction animations.
- Adding draggable buildings.
- Adding rotatable buildings.
- Adding placement adjacency bonuses.
- Making buildings persist after city conquest.
- Reworking Battle View or Country Map UI.
- Introducing UIKit overlays for this scene.

## Visual Direction

The Building View should read as a settlement management surface, not a spreadsheet-like board.

The main scene uses a generated countryside backdrop with grass, dirt roads, trees, and clearings. It should not include the five building types already placed, because occupied slots must be driven by game state. Empty slots render as build pads over the background.

The 25 slots remain fixed and selectable, but their visible positions are authored coordinates instead of grid cells. The coordinates should form a readable settlement layout: clusters along roads, a few lots around open clearings, and enough spacing for building art and level badges. Slot identity remains stable so existing saves and tests still map to slots 1 through 25.

The top panel remains a compact status surface for city title, gold, and feedback. The bottom panel becomes a build palette plus upgrade and battle controls.

## Asset Set

Add generated final art to `Pyxis/Assets.xcassets`:

- `building-view-countryside-backdrop`
- `building-pad-empty`
- `building-barracks`
- `building-archery-range`
- `building-stable`
- `building-mage-tower`
- `building-siege-workshop`
- `building-locked-overlay`, only if dimming and a vector/shape lock badge are not enough

Building assets should use transparent backgrounds, consistent lighting, and a three-quarter or light isometric view. They should be readable at SpriteKit slot sizes and must not contain baked-in text. The backdrop should be a full-scene bitmap with no critical content at the extreme edges, so it can be cropped or scaled across phone aspect ratios.

## Slot States

Each slot has one visible container node named with the existing `buildingSlot-<slot>` pattern so touch handling remains stable.

Empty slots show `building-pad-empty` at normal opacity. A selected empty slot gets a stronger outline or glow. If no slot is selected, pads remain visible but subdued enough for the settlement background to carry the scene.

Occupied slots show the matching building sprite:

- Barracks uses `building-barracks`.
- Archery Range uses `building-archery-range`.
- Stable uses `building-stable`.
- Mage Tower uses `building-mage-tower`.
- Siege Workshop uses `building-siege-workshop`.

Occupied slots also show a small level badge, such as `Lv 2`, anchored near the building base. The selected occupied slot gets an outline or glow and enables upgrade affordance when affordable.

## Build Palette States

The palette always shows all five building types as icon buttons. This keeps future progression visible.

Unlocked and affordable building types use normal icon opacity and an enabled button treatment when an empty slot is selected. Unlocked but unaffordable types keep their icon visible but use a subdued button treatment; tapping them should keep the current feedback pattern, such as `Need 18 gold. You have 0.`

Locked future building types use dimmed icons and disabled button treatment. They show the unlock city in compact text, matching the current feedback language such as `Mage City 8`. Tapping a locked type should continue to show explicit feedback such as `Mage Tower unlocks at City 8.`

The palette should retain stable button names like `build-barracks-button` so existing scene input logic and tests remain straightforward.

## Architecture

This is primarily a presentation change.

`KingdomGameState`, `CityBattleState`, build results, upgrade results, unlock rules, persistence, and idle behavior should remain the source of truth. No durable save migration should be needed.

`BuildingType` can gain small presentation helpers if that keeps scene code clearer:

- building sprite asset name
- palette icon asset name, likely the same as building sprite
- empty or locked display strings only if they are already duplicated in the scene

`BuildingViewScene` owns:

- backdrop sprite node
- scenic slot layout coordinates
- empty pad nodes
- building sprite nodes
- level badge nodes
- selected-slot highlight
- icon-based build palette nodes
- locked and unaffordable visual state

The existing `slotNodes` test surface may evolve from shape nodes into slot container nodes, but each container should still expose frame, text, fill/opacity, or asset helpers under `#if DEBUG` as needed for focused tests.

## Layout

The scene should continue to handle portrait, compact portrait, compact landscape, and very short landscape sizes.

The top and bottom panels keep their current safe-area-aware layout. The scenic slot area occupies the space between those panels. Authored slot coordinates should be normalized within that available rectangle rather than hard-coded as absolute screen pixels. This lets the same settlement layout scale across devices while preserving relative placement.

Building sprites should scale from the available scene area with a min/max size to avoid unreadable icons on small devices and oversized buildings on tablets or wide simulators. Level badges and selection outlines must not overlap the top or bottom panels.

## Error Handling

Existing rule failures remain unchanged:

- no selected slot
- occupied slot
- insufficient gold
- locked building
- type cap reached
- missing building for upgrade
- unavailable stage
- city conquered during building-progress settlement

The enhancement only changes how these states are shown. Disabled or dimmed controls should still be tappable enough to provide explanatory feedback where the current scene already does so.

## Testing

Use focused SpriteKit scene tests and avoid expanding pure model tests unless a new pure helper is added.

Cover:

- Building View still exposes 25 selectable slots.
- Slot positions are authored scenic positions, not a uniform 5x5 grid.
- Occupied slots use the expected building asset names.
- Empty slots use the empty pad asset.
- Level badges appear for occupied slots.
- Palette exposes all five building icons.
- Locked future building icons are dimmed and show unlock-city text.
- Unlocked but unaffordable building icons are visible but disabled/subdued.
- Existing build, upgrade, feedback, and battle-route tests continue to pass.
- Compact and landscape layout keeps slots, badges, palette buttons, upgrade, and battle controls from overlapping panels or each other.

## Implementation Notes

Generate the final art during implementation and commit the resulting imagesets. The Xcode project uses synchronized root groups for project files, and asset catalog additions should stay inside `Pyxis/Assets.xcassets`.

Keep the first implementation still and readable. Small polish animations, such as pad pulse or build pop-in, can be added later after the core scenic layout and assets are stable.
