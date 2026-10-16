# Tactical siege art pack — HPA-476

Production work in progress on PR #46. Final acceptance and quality gates are recorded only after they run.

## Contract

68 image sets: six structure variants, 30 Guard frames, Captain portrait plus 30 frames, and one Rally accent. No assault flag or duplicate resting images.

| Family | Final canvas | Consumer |
| --- | --- | --- |
| Gate intact/ruined | 256×128 | one bottom-centered segment per blocked lane |
| Arrow Tower intact/ruined | 320×576 | existing aspect-fit objective renderer |
| Barracks intact/ruined | 320×480 | existing aspect-fit objective renderer |
| Guard/Captain frames | 128×128 | complete 10 walk + 10 attack + 10 hit trios |
| Captain portrait / Rally accent | 128×128 | existing HPA-475 consumers |

Guard and Captain use infantry geometry: walk union width 80 px, body height 94 px, foot margin 8 px. SpriteKit horizontally centers that logical region; opaque image minX need not equal its logical minX. Source motion stays inside the transparent canvas.

## Generation and installation

Use the built-in image-generation tool with genuine transparent alpha for cutouts. The tool does not expose a model identifier or seed here; none is invented. Large originals and review captures stay in ignored local working space rather than the asset catalog. The final PNGs and this handoff are tracked.

Static files use `write_contents_json` from `tools/slice_soldier_animation_strips.py`. Actor boards use that module's `slice_soldier_storyboards` with prefixes `siege-guard` and `vanguard-captain`; the CLI soldier allow-list and validator thresholds remain unchanged.

## Prompts

### Arrow Tower — intact

```text
Use case: stylized-concept.
Asset type: final transparent PNG cutout for Pyxis, a mobile anime tactical-fantasy siege game; intact Arrow Tower.
Create exactly one isolated enemy arrow watchtower. Portrait canvas 320x576, width:height 5:9. Whole tower visible, bottom-center ground anchor. A tall compact ochre-grey stone tower with bold square crenellations, a readable dark archer firing slit, reinforced dark timber details and a small muted crimson pennant. Painted anime fantasy game art, clean strong silhouette, restrained warm highlights, subtle dark outlines, front-facing three-quarter view with a little of the roof visible, light from upper left. Match a charming blue-roof stone-castle world while identifying an enemy structure by its angular crenellations and crimson pennant. The tower will render only about 39x70 points, so favor broad shapes and readable masonry over tiny clutter.
Composition: centered, occupies about 92% of canvas height and 90% of width, base on the same horizontal line 8 px above bottom. Transparent background with genuine alpha; no ground plane, no scenery, no cast shadow extending outside the silhouette. No projectile, characters, smoke, glow, counters, HP bars, labels, text, border, UI or watermark. Intact and battle-ready.
```

### Arrow Tower — ruined

```text
Use case: precise-object-edit. Edit target: the provided Pyxis enemy Arrow Tower cutout. Make the RUINED / disabled version of exactly this same tower.
Keep the same transparent full canvas, camera, lighting direction, original base footprint, bottom-center ground line, masonry scale, palette, and timber/stone materials. Do not crop, zoom, or recenter to the remaining rubble.
Collapse the roof, pennant, and top firing platform into a visibly broken lower tower stump and a compact pile of its own masonry. Torn dark crimson cloth can hang limp low on the stump. Leave most of the upper canvas empty transparent alpha. Broken wall edges, fallen beams, and dark abandoned firing slit must read destroyed and inactive at tiny mobile scale. The remaining stump should be around 45% of the original tower height, with the rubble grounded at precisely the original base line. No fire, smoke, particles, active weapons, glowing effects, living characters, text, HP bars, border, UI, scenery, ground plane, or background. Preserve genuine alpha.
```



### Gate — intact

```text
Use case: stylized-concept.
Asset type: Pyxis tactical siege game, intact Gate segment, final transparent cutout.
Create ONE broad low fortified gate segment with a wide closed dark-oak double door framed by two short ochre-grey stone piers and a low crenellated stone lintel. Strong dark metal braces on the timber. Width is twice total height: target canvas 256x128, 2:1 landscape, with the complete silhouette filling about 96% width and 90% height, a level base 8 pixels above bottom. No towers projecting tall above it, no pennant. This is one repeatable lane-width blocker, not a whole castle or a panoramic city wall.
Painted anime tactical-fantasy game art, bold readable silhouette, warm stone, weathered dark oak, subtle dark outline, front-facing shallow three-quarter view, upper-left warm light, matching an ochre-stone enemy watchtower with dark timber braces and crimson accents in a charming blue-roof castle world. Central closed passage should remain obvious at 108x54 point runtime scale. The two side piers and broad door read solid and intact.
Genuine transparent alpha background. No scenery, ground plane, long cast shadow, people, motion effects, glow, fire, smoke, projectiles, text, HP bar, UI, border or watermark. Keep all art within canvas and maintain a clean ground-contact line.
```

### Gate — ruined

```text
Use case: precise-object-edit. Edit target: the provided Pyxis fortified Gate segment.
Create its RUINED / destroyed version. Preserve the same full canvas, shallow front three-quarter camera, upper-left lighting, stone/oak/iron material scale, original left/right base locations, broad footprint and bottom ground line. Keep genuine transparent alpha and leave the upper part of the canvas empty where the gate collapsed; do not zoom in or enlarge rubble.
The lintel is down, both short piers are fractured to low irregular stumps, crimson banners torn and limp, and the double doors are smashed into low splintered planks and a few fallen iron braces. Show a clear destroyed passage with transparent empty space through the middle, small rubble piles at the two original feet, and no surviving full-height closed door or intact horizontal wall. Read unmistakably inactive at 108x54 points. Keep the same warm painted anime tactical-fantasy style. No people, active machinery, fire, smoke, glow, particles, text, UI, HP bar, background, scenery, ground plane, shadow slab, border or watermark.
```

### Barracks — intact

```text
Use case: stylized-concept.
Asset type: final transparent cutout for Pyxis tactical siege, enemy Barracks intact.
Create ONE compact enemy reinforcement barracks: an ochre-grey stone guardhouse, dark oak reinforced doorway, a steep muted crimson tiled roof and a small shield-shaped iron emblem above the entry. Squat broad lower walls with two heavy corner buttresses, a short upper loft under the roof, one simple rack with two spear tips attached close to the side, no extra buildings. A wide dark doorway and strong roof silhouette should read reinforcement source at about 45x68 point runtime size.
Target canvas 320x480, 2:3 portrait; whole building bottom-centered, fills 90% width and about 92% height with a clean level ground line near bottom. Painted anime tactical-fantasy game art, warm ochre stone, weathered dark timber, restrained crimson enemy accents, broad readable shapes, subtle dark outline, front-facing shallow three-quarter camera, warm upper-left light. Match a crenellated enemy watchtower and low oak Gate in a blue-roof castle world.
Genuine transparent alpha background. Intact, orderly and battle-ready, with no people, spawning bodies, fire, smoke, glow, particles, long shadows, ground slab, scenery, text, UI, HP bars, border or watermark.
```

### Barracks — ruined

```text
Use case: precise-object-edit. Edit target: the provided Pyxis crimson-roof enemy Barracks cutout.
Create the RUINED / shut-down version of exactly this building. Preserve the same full canvas, camera, upper-left lighting, stone/oak/iron scale, base footprint and ground-contact line. Do not crop or zoom. Keep the two lower stone buttresses recognizable, but fracture them; collapse the upper loft and crimson roof into a low heap of cracked red tiles, fallen timbers and rubble. The entrance is visibly blocked by debris, the shield emblem is split/fallen, and the spear rack is broken and tipped down. Leave empty transparent space above the remaining lower ruin; no intact roof or active entrance.
Maintain the warm painted anime tactical-fantasy style, and make disabled reinforcement production obvious at about 45x68 points without using text. Genuine transparent alpha around the ruin and through empty areas; absolutely no background haze, scenery, ground plane, shadow slab, fire, smoke, particles, glow, living characters, UI, HP bars, border or watermark.
```

### Static preparation

Tower sources: `exec-d6a7f3bd-3cf1-412c-982b-3f0f41052820.png` (intact) and `exec-9a686ec6-2f41-433f-a1cf-4bdefd8e2fa1.png` (ruined), generated by the built-in tool. Both source canvases are 935×1683. Trim transparent bounds, apply one shared LANCZOS scale of `min(304 / maxPairOpaqueWidth, 560 / maxPairOpaqueHeight)`, center each variant horizontally on 320×576, and place its visible base at y=568 (8 px bottom margin). The shared scale preserves masonry size between variants; the ruined art is never enlarged to fill the intact height. Preserve alpha and write the imageset metadata with `write_contents_json`.

Gate sources: `exec-bcb0b68b-ed1f-4ec0-8958-0f8d33365652.png` (intact) and `exec-d4c01bca-b46a-4086-8ad8-3c8fc6bb3f12.png` (ruined), both 1774×887. Use the same paired-bound workflow with width limit 248 and height limit 120; trim any empty alpha left after downsampling before bottom-aligning at y=120 on 256×128. Final alpha bounds are `(5, 7, 251, 120)` and `(4, 8, 252, 120)`, preserving the shared ground line and at least 96% visible lane-width coverage.

Barracks sources: `exec-b9ca356e-dc64-418f-93d1-00eaeb99c956.png` (intact) and `exec-a03decaf-6909-42e8-9a17-9b1eebb3a190.png` (ruined), both 1024×1536. Use the same paired-bound workflow with width limit 304 and height limit 464, trim empty alpha after downsampling, and place both bases at y=472 on 320×480. No background color or shadow is added; RGB values under zero alpha remain invisible.

Accepted source copies are kept locally under ignored `docs/visual-parity/hpa-476/sources/<asset>-source.png`; native evidence is under its `captures/` sibling. Generator originals are left in the tool's default output directory.

## Acceptance

Structure stage: all six image sets are installed. Tower and Gate intact/ruined pairs were reviewed in native 393×852 Falconridge captures; Gate coverage also passes intact/ruined tests across all seven non-empty lane subsets. Barracks intact/shutdown captures use the existing Highcrest fixtures; repeat combined readability review after replacing the procedural Guards and at compact/iPad sizes in Task 4.

Task 1 validation: 277 BattleScene/fixture tests passed serially; the reference UI capture smoke passed all 16 fixture states; the generic simulator build passed; lint passed with existing unrelated warnings and no warnings/errors in changed Swift files. The stale `return-damage` UI expectation was corrected from intact to damaged after pinning its 36 damage and 10/35 remaining Keep HP in the fixture test.

Guard/Captain production, final combined captures, full unit/UI suites, Release build, and coverage remain pending.
