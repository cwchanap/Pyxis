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

### Guard — original walk identity board

```text
Use case: stylized-concept.
Asset type: Pyxis enemy Guard WALK animation SOURCE STORYBOARD, not a finished UI image.
Create exactly TEN full-body poses of ONE consistent original chibi anime enemy shield Guard, in a precise 5-column by 2-row grid of square cells, read left-to-right top row then bottom row. Wide canvas aspect 5:2, ideally 2560x1024 with ten 512x512 cells. No cell lines, labels, numbers, words or borders. The ENTIRE background is flat pure chroma green RGB(0,255,0), hex #00FF00, with no gradients, shadows, glow or texture.
Character identity in every cell: broad closed charcoal-steel helmet with a low crimson crest stripe (no tall plume or horns), narrow dark visor and small amber eye slit; warm grey plated armor; crimson shoulder cloth; a broad angular dark-red kite shield with one simple gold chevron; short steel sword held low; dark brown boots. Strong heavy enemy silhouette, shield leading toward lower-left/viewer's side. Front three-quarter view facing lower-left toward the player's castle, same fixed camera in all frames. Painted anime game-sprite treatment, dark crisp outline, warm upper-left lighting, readable like a small blue-plumed chibi allied infantry sprite but clearly a different enemy design. No green on the character.
Each cell has exactly one Guard, same scale, same head/helmet/outfit/weapon. Body and equipment fit an approximately 300px-wide by 360px-tall silhouette centered at x=256; feet on y=472 in each 512px cell. Leave every outer 8% of each cell pure green with NOTHING touching those reserved gutters. Keep the entire sword, shield and crest inside the same compact bounds. These poses will reduce to 128x128 and must read at 54–70pt body height.
Motion: a complete smooth ten-pose walk cycle. Pose 1 is a neutral ready stance; poses 2–9 alternate small forward/back foot steps with subtle torso and shield sway, no camera travel or size change; pose 10 returns to the same neutral ready stance. Feet always stay on the same baseline; no floating, jumping, motion smear, trails, hit effects, duplicate adjacent poses, scenery or props. Keep both neutral bookends at identical body height and scale.
```

### Guard — selected walk blade correction

```text
Use case: precise-object-edit. Make ONE SMALL correction to this original Pyxis Guard ten-pose WALK storyboard.
Keep the helmet, head, torso, boots, crimson cloth, and especially the ORIGINAL broad red kite shield EXACTLY the same size, angle and position in every corresponding pose. Do NOT turn the shield edge-on, narrow the shield, move the shield inward, change the body width, or tuck the sword elbow inward.
Change ONLY the short sword blade's angle at the existing grip: point it more down than out, approximately 65 degrees below horizontal, so its tip ends near the outside of the right boot instead of far to the right. Keep the sword's length, thickness and handle size. This should make the total silhouette moderately narrower, about 80–85% of helmet-to-boot height, while retaining the original heavy shield silhouette. Do not squash or stretch any art.
Preserve the ten distinct walk poses, 5-column by 2-row square-cell grid, wide 5:2 canvas, fixed camera and warm upper-left light. Use a uniform pure #00FF00 chroma-green background with no shadows, gradients, labels, numbers, cell lines or effects. Keep matching neutral bookends in cells 1 and 10.
```

### Guard — attack board

```text
Use case: precise-object-edit. Edit target: the provided ten-pose Pyxis enemy Guard storyboard. Preserve the exact character identity, charcoal helmet with crimson stripe, dark steel armor, crimson cloth, red kite shield with gold chevron, short sword, camera, light direction, scale and 5-column by 2-row square-cell layout. Keep a flat pure #00FF00 RGB(0,255,0) chroma-green background everywhere outside the character, with no gradients, shadow, cell lines, text or effects. Give every cell a clean empty 8% gutter on every edge. Keep feet on one common baseline and keep the entire shield/sword silhouette compact inside its cell. Poses 1 and 10 must be the same neutral ready stance as pose 1 in the reference. Do not enlarge the head or change equipment between cells. Change only the motion to a ten-pose short-sword ATTACK sequence facing lower-left toward the player's castle. Poses 2–3 wind up the sword beside the waist while the shield stays forward; poses 4–6 execute a strong low forward thrust/slash, never raising the blade above the helmet; poses 7–9 recover. Show ten distinct adjacent poses and a clear strike in the middle. No blood, blade trails, sparks or impact graphics. The whole character stays the same body scale with only small foot/torso articulation.
```

### Guard — hit board

```text
Use case: precise-object-edit. Edit target: the provided ten-pose Pyxis enemy Guard storyboard. Preserve the exact character identity, charcoal helmet with crimson stripe, dark steel armor, crimson cloth, red kite shield with gold chevron, short sword, camera, light direction, scale and 5-column by 2-row square-cell layout. Keep a flat pure #00FF00 RGB(0,255,0) chroma-green background everywhere outside the character, with no gradients, shadow, cell lines, text or effects. Give every cell a clean empty 8% gutter on every edge. Keep feet on one common baseline and keep the entire shield/sword silhouette compact inside its cell. Poses 1 and 10 must be the same neutral ready stance as pose 1 in the reference. Do not enlarge the head or change equipment between cells. Change only the motion to a ten-pose HIT REACTION sequence. Poses 2–3 brace behind the shield; poses 4–6 recoil slightly back with bent knees and shield jolting toward the torso; poses 7–9 recover; pose 10 returns to neutral. Preserve planted foot baseline and consistent helmet/body size; a readable restrained flinch rather than a fall or death. Show distinct adjacent poses. No attacker, blood, damage numbers, flashes, stars, sparks or impact graphics.
```

### Static preparation

Tower sources: `exec-d6a7f3bd-3cf1-412c-982b-3f0f41052820.png` (intact) and `exec-9a686ec6-2f41-433f-a1cf-4bdefd8e2fa1.png` (ruined), generated by the built-in tool. Both source canvases are 935×1683. Trim transparent bounds, apply one shared LANCZOS scale of `min(304 / maxPairOpaqueWidth, 560 / maxPairOpaqueHeight)`, center each variant horizontally on 320×576, and place its visible base at y=568 (8 px bottom margin). The shared scale preserves masonry size between variants; the ruined art is never enlarged to fill the intact height. Preserve alpha and write the imageset metadata with `write_contents_json`.

Gate sources: `exec-bcb0b68b-ed1f-4ec0-8958-0f8d33365652.png` (intact) and `exec-d4c01bca-b46a-4086-8ad8-3c8fc6bb3f12.png` (ruined), both 1774×887. Use the same paired-bound workflow with width limit 248 and height limit 120; trim any empty alpha left after downsampling before bottom-aligning at y=120 on 256×128. Final alpha bounds are `(5, 7, 251, 120)` and `(4, 8, 252, 120)`, preserving the shared ground line and at least 96% visible lane-width coverage.

Barracks sources: `exec-b9ca356e-dc64-418f-93d1-00eaeb99c956.png` (intact) and `exec-a03decaf-6909-42e8-9a17-9b1eebb3a190.png` (ruined), both 1024×1536. Use the same paired-bound workflow with width limit 304 and height limit 464, trim empty alpha after downsampling, and place both bases at y=472 on 320×480. No background color or shadow is added; RGB values under zero alpha remain invisible.

Accepted source copies are kept locally under ignored `docs/visual-parity/hpa-476/sources/<asset>-source.png`; native evidence is under its `captures/` sibling. Generator originals are left in the tool's default output directory.

### Guard storyboard preparation

Selected raw sources: walk `exec-48a2f265-672b-4609-b87c-4ebf85f49112.png`, attack `exec-07a9448c-1af2-4552-ba01-b7ef3f2f090e.png`, hit `exec-bafe8b71-347b-4bab-9d51-7831b5841a9a.png`. Attack/hit and the selected walk correction reference the original identity board `exec-d02dff7d-736c-46a6-adfd-5d122e86d683.png`. The broad shield stays unchanged; the selected walk edit only brings the sword closer to the boot.

Manual source composition, before running the unchanged slicer:

1. Pad the 1983×793 raw sheets to 1985×794 with the default green key so the existing `storyboard_cells` helper extracts ten square cells.
2. Correct uneven generated background green: pixels with `g > 140`, `g > r + 60`, and `g > b + 60` are background. Guard materials intentionally contain no green. Crop each resulting alpha silhouette, preserving its colors and pose.
3. Apply one uniform scale per action, `348 / max(croppedPoseHeights)`; do not stretch width independently. Center the lower 5% silhouette bounds at x=256 in a 512×512 cell, clamp the left placement between 42 and `470 - resizedWidth`, and place the visible base at y=471. Recompose on exact RGBA `(0,255,0,255)`; reserved gutters remain empty.
4. Reuse the selected walk's two distinct authored neutral bookends as attack/hit bookends. Keep both walk bookends; they pass the existing neutral core tests and remain distinct across the loop boundary.
5. Assemble approved 2560×1024 sheets and run the existing complete-trio helper atomically. No slicer threshold or CLI allow-list is changed.

Final approved sheets are local `sources/siege-guard-{walk,attack,hit}-storyboard.png` under the ignored visual-parity directory. Walk alpha union is `(25,28,107,120)`: 82×92 px with an 8 px foot margin, within the shared infantry contract's ±2 px tolerance. All 30 output frames are 128×128.

```python
from pathlib import Path
from PIL import Image
from tools.slice_soldier_animation_strips import slice_soldier_storyboards

source = Path("docs/visual-parity/hpa-476/sources")
boards = {
    action: Image.open(source / f"siege-guard-{action}-storyboard.png")
    for action in ("walk", "attack", "hit")
}
slice_soldier_storyboards(boards, Path("Pyxis/Assets.xcassets"), "siege-guard", 128)
```

### Vanguard Captain — identity / walk

```text
Use case: stylized-concept.
Asset type: 5-column by 2-row square-cell ten-pose sprite storyboard for an iOS anime tactical siege game, intended to slice into 128x128 frames.
Create the original allied VANGUARD CAPTAIN identity and WALK cycle. A chibi heroic young adult woman commander with swept silver-white bob hair, a small cobalt-and-gold wing-shaped hair clasp, expressive determined face, polished steel plate armor with restrained gold trim, cobalt blue short cape, ivory cloth skirt panels, brown boots, a compact straight broadsword held close upward at her right shoulder, and a compact blue-and-gold round buckler. No helmet plume; visibly distinct from ordinary blue-plumed infantry and a faceless red enemy Guard.
Style: polished hand-painted anime mobile game sprite, crisp dark outlines, broad readable cel-painted values, slightly isometric front three-quarter view facing upper-right (advancing toward the top-right of screen), soft warm light from upper-left, no cast shadow. Keep sword compact and nearly vertical during walk so complete width including equipment is roughly 85% of full body height.
Layout: exactly 5 columns x 2 rows of equal SQUARE cells, left-to-right top-to-bottom. Entire image ratio 5:2. Each character fits entirely in its own cell with 10% clean empty gutter on ALL edges, same body/head size and same planted foot baseline. Occupy only about 70% of each cell's height. Flat exact opaque pure RGB(0,255,0) #00FF00 chroma green everywhere outside each figure, no gradients, shadows, grid lines, labels or effects. No green on the character.
Walk poses 1 through 10 form a subtle distinct walking cycle: ready neutral, left step start, left stride, passing, right step start, right stride, passing, left recovery, small settling step, a second neutral ready pose with tiny cape/arm difference. Preserve equipment, hair and proportions in all ten poses. The neutral first and last must have the same torso/head height and center. Keep boots grounded; every adjacent pose visibly differs. No text, scenery, magical glow, circle, trail, duplicate figure in a cell or cropped weapons.
```

### Vanguard Captain — attack

```text
Use case: identity-preserve. Edit target: the provided ten-pose Vanguard Captain storyboard. Preserve the exact silver-white bob hair, blue-and-gold wing hair clasp, face, polished steel/gold armor, cobalt cape, ivory cloth, brown boots, straight broadsword and blue/gold round buckler. Keep the same camera, light, crisp anime painting and proportions. Exactly 5 columns by 2 rows of square cells on flat opaque pure RGB(0,255,0) #00FF00 chroma green with no shadow, lines, labels or effects. Entire figure and equipment fit every cell with 10% empty gutters, feet on one common baseline, same body/head size. First and tenth poses are the reference's neutral ready stance; keep torso/head core height and center stable across those bookends. Every adjacent pose differs. Change only motion to a ten-pose sword ATTACK cycle: 1 neutral, 2-3 wind up compactly, 4-6 forward diagonal sword cut, 7-9 recover, 10 neutral. A clear physical strike with shield retained close, no giant reach, no VFX, arc, glow, attacker, damage number, blood or new equipment. No green on the character.
```

### Vanguard Captain — hit

```text
Use case: identity-preserve. Edit target: the provided ten-pose Vanguard Captain storyboard. Preserve the exact silver-white bob hair, blue-and-gold wing hair clasp, face, polished steel/gold armor, cobalt cape, ivory cloth, brown boots, straight broadsword and blue/gold round buckler. Keep the same camera, light, crisp anime painting and proportions. Exactly 5 columns by 2 rows of square cells on flat opaque pure RGB(0,255,0) #00FF00 chroma green with no shadow, lines, labels or effects. Entire figure and equipment fit every cell with 10% empty gutters, feet on one common baseline, same body/head size. First and tenth poses are the reference's neutral ready stance; keep torso/head core height and center stable across those bookends. Every adjacent pose differs. Change only motion to a ten-pose HIT REACTION: 1 neutral, 2-3 brace behind buckler, 4-6 restrained backward flinch with knees bent, 7-9 recover, 10 neutral. Planted boots and consistent body size, no fall, death, attacker, impact VFX, damage number, blood, glow or new equipment. No green on the character.
```

### Vanguard Captain — portrait

```text
Use case: identity-preserve. Input image is the identity reference for the original Vanguard Captain. Create one square HUD PORTRAIT of this exact silver-white bob-haired young woman commander: same blue/gold wing hair clasp, blue eyes, determined friendly face, steel and gold-trim shoulder armor, cobalt cape at the neck. Chest-up three-quarter view, face large and centered, looking toward upper-right. Polished hand-painted anime mobile game style, crisp dark outlines, warm upper-left light. Actual transparent background. Clean cutout silhouette inside all edges with a small margin, no frame, circle, badge, text, weapon covering face, background scene, glow, alternate costume or new character.
```

### Rally protection accent

```text
Use case: stylized-concept. Asset type: one 128x128 transparent sprite accent for the Rally protection buff in a hand-painted anime tactical siege game. Create a restrained cool cyan-blue and pale-gold protective shimmer concentrated at the bottom-center feet of a small allied soldier. Two short curved luminous wisps rising only slightly at the sides, with a tiny simple shield-shaped glint at the center near the ground. Most of the square canvas is empty transparent space above; the effect occupies the bottom 30 percent and middle 70 percent width. Soft feathered translucent edges, gentle glow, crisp small core accents, readable over warm brown battlefield. Truly transparent background. No character, weapon, landscape, cast shadow, full enclosing bubble, full ring or circular AoE radius, timer, number, text, bar, frame, icon button, starburst or bright full-body aura. It should sit beneath an ordinary soldier without hiding body or HP; protection is a subtle supporting accent, not invulnerability.
```

### Captain and Rally preparation

Captain sources: walk/identity `exec-b331fbf0-d1ae-4c79-97ff-f80cfa51b301.png`, attack `exec-ca6ef942-c285-4988-bef3-480aa7e61a51.png`, hit `exec-82a85bff-7fbc-456b-86c8-4ed5dca1bd05.png`, portrait `exec-bb66019f-a2fb-4a34-9a85-4c189905d909.png`. The three edits reference the original walk identity. Use the Guard chroma correction/composition workflow with uniform action height **356 px** before slicing. Retain the largest connected alpha silhouette in each cell to discard isolated fragments from neighboring generated poses. Use the two distinct walk neutral bookends for the other actions. The final walk union is 80×94 px with 8 px foot margin. All three boards pass `prepare_soldier_storyboards` together before atomic installation using prefix `vanguard-captain`.

Portrait: preserve the generated transparent canvas and downsample to 128×128 with LANCZOS. Rally source `exec-0c4ca9b7-f9b8-4fbe-9287-e49c92f35980.png`: preserve its lower-canvas placement and alpha, downsample to 128×128. Both use `write_contents_json`. No background removal, independent width stretching, alternate actor skin or duplicated resting image is installed.

## Reproducing captures

Launch a DEBUG simulator build with `-pyxis-forged-fixture <marker> -pyxis-freeze-combat`:

| Marker | Checkpoint |
| --- | --- |
| `battle` / `battle-falconridge-ruined` | Falconridge Gate/Tower intact and ruined |
| `battle-highcrest-wave` / `battle-highcrest-shutdown` | Barracks count/HP and disabled silhouette |
| `battle-captain-deployed` | Captain body and matching HUD portrait beside enemy Guards |
| `battle-rally-active` | Actual Rally protection on an ordinary soldier; Captain is excluded |
| `battle-guard-animation` | Repeating walk/attack/hit with real action completion and moving/still resumption |
| `conquest-live` / `conquest-idle` | Required report content remains unobstructed |

The three actor fixtures reuse Highcrest and dismiss its decorative arrival card through the existing DEBUG seam. Captain deployment uses the existing persisted restore path. Rally is activated through the existing HUD touch command after a same-lane ordinary soldier is deployed. No transient roster or protection timer is persisted.

The Guard animation fixture freezes continuous combat while real SpriteKit actions run. It stages one ordinary soldier, then alternates existing attack/hit feedback commands and small/zero model ticks to select the latest moving/still pose. This is presentation playback evidence, not a new combat timing mode. The normal combat/persistence suites remain authoritative for damage and events.

Local sources, contact sheets, native captures and video stay under ignored `docs/visual-parity/hpa-476/`. No separate Reduce Motion branch exists for these actors; static captures check meaning without claiming animation is disabled.

## Acceptance

Structure stage: all six image sets are installed. Tower and Gate intact/ruined pairs were reviewed in native 393×852 Falconridge captures; Gate coverage also passes intact/ruined tests across all seven non-empty lane subsets. Barracks intact/shutdown captures use the existing Highcrest fixtures; repeat combined readability review after replacing the procedural Guards and at compact/iPad sizes in Task 4.

Task 1 validation: 277 BattleScene/fixture tests passed serially; the reference UI capture smoke passed all 16 fixture states; the generic simulator build passed; lint passed with existing unrelated warnings and no warnings/errors in changed Swift files. The stale `return-damage` UI expectation was corrected from intact to damaged after pinning its 36 damage and 10/35 remaining Keep HP in the fixture test.

Guard stage: the complete 30-frame trio passes the unchanged slicer and all 262 BattleScene tests, including infantry geometry, walking, transient priority/no-restart, and objective-overlay depth. Existing objective HP/count overlays now draw above actors and below effects so the art cannot hide them. Native 393×852 acceptance uses the Highcrest wave fixture. SwiftLint passed with no new changed-file diagnostics.

Captain stage: all 32 Captain/Rally image sets are installed. The shared actor inventory/bounds checks, Captain runtime integration and HUD suites pass **309/309** serially, including the updated production-art expectation in the former Captain fallback test. No shipping Swift changes were needed for these assets.

Visual acceptance completed on iOS 26.5 Simulator:

| Layout | Evidence | Result |
| --- | --- | --- |
| Reference phone, 393×852 | 21-state XCTest capture matrix; `captures/reference-review.png` | Gate/Tower pairs, Barracks/Guard, Captain portrait, Rally and reports readable |
| Compact phone, 375×667 | `captures/compact-*.png` (750×1334 native) | Same combined states; controls, selected lane and objective overlays unobstructed |
| Portrait iPad, 834×1210 | `captures/ipad-*.png` (1668×2420 native) | Same combined states; structures retain scale/ground line and reports remain clear |
| Guard playback | `captures/guard-playback-393x852.mp4` (19.25 s), sampled contact sheet | Walk/attack/hit play and finish; moving and still resumption both observed |

Static meaning survives in the regular captures: broken masonry and limp pennants distinguish ruins, `SHUT DOWN` remains readable without a Barracks HP bar, the faceless crimson Guard contrasts with allied actors, the silver-haired Captain matches the HUD portrait, and the existing `ASSAULT` marker still identifies the lane. The restrained Rally shimmer sits behind ordinary soldiers and never hides body/HP or becomes the only protection cue. Settings, tabs, Deploy and Rally remain clear. No gameplay or UI geometry was retuned for these captures.

The full reference UI suite passed 5/5 with no skips, including the expanded 21-state semantic smoke. Full unit coverage, final builds, hosted checks and whole-branch review remain pending. Physical-device validation has not been run.
