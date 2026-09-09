# Living Kingdom art → code handoff

## Purpose

This directory is the human-readable handoff from **HPA-479** art production to **HPA-478** runtime integration. It is not a runtime manifest.

Planning baseline: `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`.

The final pack contains **35** runtime image sets:

- 16 fortress stages;
- 3 battlefield treatments;
- 12 transition-animation frames;
- 4 map overlays.

There are **no ambient smoke/ember/ward textures** in this ticket. Add them later only if HPA-478 proves a real consumer.

## Measured shipping baseline

Verified 2026-09-08 against this branch's assets (`sips` dimensions + Pillow alpha scan):

| Asset | Canvas (px) | `hasAlpha` | Alpha bbox `(L, T, R, B)` |
| --- | --- | --- | --- |
| `enemy-city` | 1223×1286 | yes | `(155, 23, 1070, 1258)` |
| `battlefield-backdrop` | 864×1821 | no | — (opaque) |
| `country-map-backdrop` | 1024×1536 | no | — (opaque) |

The measured enemy-city silhouette maps to opaque width **0.748** of canvas width (915/1223), opaque height **0.960** of canvas height (1235/1286), and a transparent gap below the opaque box of **0.022** of canvas height (28/1286); opaque-box center drift is ≈0.4 px at 512-scale. All four values sit inside the alpha-envelope bands in the Fortress contract below — the bands are confirmed, no spec change required.

## Concept references

The original four boards from `Pyxis_Living_Kingdom_Concept_References.zip` are mood/composition references only and are **not a production blocker**.

**Status: recovered.** Copied **unchanged** into `source/` (byte-identical to the archive contents, confirmed by SHA-256):

| File | SHA-256 |
| --- | --- |
| `source/concept-01-siege-destruction.png` | `43b6f241212e33ddbf318e5a5cc8904ba522303509b0db3fcb1fac8e69e86520` |
| `source/concept-02-landmark-cities.png` | `f9f9b5cf3b503005bb1edb5b136aea3c883c14dd0037bec24c76e80bcc7891cd` |
| `source/concept-03-living-kingdom-map.png` | `12bc622b1d2b83b601d888b8ed2d1ee4efe0da4fd20158e913e99a9afdeb4336` |
| `source/concept-04-offline-return-reveal.png` | `65694bf7644d77cdedab9c4ef02cb24af76272a53d77a0843c2b4ec2b2750cac` |

Mechanics visible in the boards that are **excluded** from this ticket: extra resources, invented names/levels, huge troop stocks, claim buttons, and fortification-management objectives. Production scope follows this written brief plus the Forged native plates, not the boards.

## Visual direction

Anime-inspired painted fantasy environments:

- clear mobile silhouettes;
- restrained stone/fire/magical-light detail;
- fixed camera and stable lighting direction;
- no new troop/character art;
- no UI/text/counters/buttons baked into textures;
- lane, soldier, city-label, Scout, and Forged-HUD readability wins over decoration.

## Fortress contract

Runtime facts:

- `BattleScene.makeBattleSprite` uses `anchorPoint = (0.5, 0)`;
- `BattleScene.fitBattleNode` scales from the full sprite canvas height;
- regular enemy-city canvas height is 132 pt;
- compact target tops out around 150 pt;
- alpha bounds are **not** a runtime sizing API.

All 16 fortress PNGs:

- canvas: **512×540 px**, RGBA;
- bottom-center runtime anchor `(0.5, 0)`;
- gate centered horizontally;
- same structural center, camera, and lighting across family stages.

### Alpha-envelope acceptance

Every fortress stage must satisfy:

| Metric | Allowed band |
| --- | ---: |
| opaque width / 512 | `0.72...0.80` |
| opaque height / 540 | `0.94...0.98` |
| transparent gap below opaque box / 540 | `0.015...0.030` |
| opaque-box center drift from canvas center | `≤ 0.02 × 512` |

Intact stages should normally stay in the tighter **0.72...0.78** width band. Damage/rubble may use the 0.80 ceiling but must not become a different apparent footprint.

At a 132 pt canvas-height render this produces roughly **90–100 pt visible width**, close to the shipping enemy-city silhouette instead of filling the ~125 pt full canvas width.

These bounds are enforced by the CI-run Swift asset test; HPA-478 does not introduce a fortress body-region geometry type.

### Stage thresholds

| Remaining HP | Stage |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

### Family mapping

Never infer family from `CityDefenseTrait`.

| Family | Cities | Names |
| --- | --- | --- |
| Frontier | 1–6, 8, 10, **11**, 14 | `lk-city-frontier-{intact,damaged,breached,conquered}` |
| Ember | 7 Emberford, 12 Ashbridge | `lk-city-ember-{intact,damaged,breached,conquered}` |
| Arcane | 9 Runewatch, 13 Starveil Citadel | `lk-city-arcane-{intact,damaged,breached,conquered}` |
| Royal | 15 Crownspire Keep | `lk-city-royal-{intact,damaged,breached,conquered}` |

City 11 remains Frontier even though it shares `.reinforcedKeep` with City 15.

## Battlefield treatments

Assets:

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

Each is transparent **864×1821 px**, matching the shipping `battlefield-backdrop` canvas and aspect-fill.

HPA-478 layering:

```text
battlefieldBackdropNode     = GameUITheme.Z.background
Living Kingdom treatment   = GameUITheme.Z.background + 0.5
forgedAtmosphereNode       = GameUITheme.Z.background + 1
lane terrain               = -1
```

This guarantees the treatment paints over the opaque backdrop but remains under the Forged grade and lane terrain.

Do not paint a second fortress or anything that reads as a new tower, shield, attack, or resource.

## Transition effects

### Breach

- `lk-fx-breach-01...06`
- 512×512 RGBA
- 0.05 s/frame, 0.30 s total

### Collapse

- `lk-fx-collapse-01...06`
- 512×512 RGBA
- 0.07 s/frame, 0.42 s total

Shared contract:

- SpriteKit anchor `(0.5, 0)`;
- impact origin = canvas bottom center;
- node position does not move during playback;
- dust/debris/atmosphere only, not a second fortress silhouette;
- frame 06 is **fully transparent**;
- static breached/conquered fortress owns the terminal appearance.

### FX display size

Use the same pixel scale as the fortress canvas:

```text
fortressScale = enemyCityDisplayHeight / 540
fxDisplayHeight = 512 × fortressScale
```

At the regular 132 pt fortress height, FX display at about **125 pt high**. Never render a 512 px FX frame as a 512 pt node.

## Living map

Country 1 canonical source space: **1024×1536**.

Selected segment: **Granite Pass (6) → Emberford (7)**.

| Registration | Canonical coordinate |
| --- | ---: |
| City 6 | `(360.2432, 520.0896)` |
| City 7 | `(427.1104, 640.6656)` |
| Midpoint | `(393.6768, 580.3776)` |
| Length | `137.8760 px` |
| Direction | `60.9888°` from +X in authored y-up coordinates |

In the PNG as viewed, the crossing runs **lower-left to upper-right**.

Runtime scale:

```text
mapScale = displayedBackdropFrame.width / 1024
runtimeOverlaySize = canonicalPixelSize × mapScale
```

Assets:

| Asset | Canonical canvas | Contract |
| --- | ---: | --- |
| `lk-map-secured-city` | 96×96 | centered low-alpha secured treatment; keep number + upper-right conquered marker readable |
| `lk-map-caravan` | 128×64 | centered, faces +X; HPA-478 rotates/scales along an existing eligible route |
| `lk-map-route-6-7-worn` | 192×192 | before state, pre-oriented/registered to 6→7 |
| `lk-map-route-6-7-repaired` | 192×192 | after state, same canvas/registration |

All map assets are decorative/noninteractive. The worn asset stays because the ticket explicitly requires a before/after repair treatment.

## Asset catalog

All 35 image sets use one Contents.json shape generated by the existing helper:

`tools/slice_soldier_animation_strips.py::write_contents_json(imageset, filename)`

It emits one universal 1x filename plus empty 2x/3x entries. Use it for fortress, battlefield, FX, and map sets alike. Do not hand-author two catalog shapes, replace existing assets, edit `project.pbxproj`, or create a new asset-manifest system.

## Corrected reference plates

Only replace new scene-art pixels on real shipping plates; do not redraw Forged chrome.

Existing plates under `docs/visual-parity/forged-ui/native/`:

- Battle / landmarks: `battle-normal-393x852@3x.png`;
- early map: `map-attackable-locked-393x852@3x.png`;
- complete map: `map-complete-393x852@3x.png`;
- offline conquest: `conquest-idle-393x852@3x.png`.

### Partial map

Extend the existing DEBUG `ForgedVisualFixture` with `map-partial`:

- base: `DevJumpState.make(city: 8)` → 7 completed cities;
- set stage to `.cityConqueredPendingMap` so the Map is the truthful mounted surface;
- capture through the same 393×852 UI-fixture flow used by existing Forged native plates.

Store the untouched native plate under `source/` before compositing map art.

### Required corrected references

- `references/battle-frontier-{intact,damaged,breached,conquered}.png`
- `references/battle-emberford.png`
- `references/battle-runewatch.png`
- `references/battle-crownspire.png`
- `references/map-early.png`
- `references/map-partial.png`
- `references/map-complete.png`
- `references/offline-damage.png`
- `references/offline-conquest.png`

`offline-damage.png` changes only scene art; do not synthesize an elapsed-time line or redraw feedback chrome. Shipping positive-damage copy is formatted through `CompactNumberFormatter`, e.g. **`Buildings dealt 1.2K idle damage.`**

`offline-conquest.png` preserves the existing pending report and its single Continue action.

## Continuous asset validation

Use the existing CI-run Swift test seam rather than a manual Python gate.

`PyxisTests/BattleSceneTests.swift` already loads authored assets synchronously. HPA-479 extends that file so each landed batch checks:

1. expected `lk-*` names resolve through `UIImage(named:)`;
2. `cgImage` dimensions match this contract;
3. fortress opaque bounds stay inside the alpha envelope;
4. `lk-fx-breach-06` and `lk-fx-collapse-06` are fully transparent once those sequences land.

Extend the existing `PixelBounds` helper to include Y bounds. Grow the expected asset table in the **same commit** that adds each asset batch so every checkpoint is verifiable and CI remains green.

No separate `tools/tests/test_living_kingdom_asset_pack.py` and no CI workflow change.

## Production metadata

### Frontier destruction set (Task 2, HPA-479)

Landed 2026-09-08. Four image sets, all **512×540 RGBA**, bottom-center anchor
`(0.5, 0)`, gate centered, derived from one approved intact source (same
camera, center, baseline gap, tower positions, and footprint across stages).

Generator/tool chain: `codex exec` → built-in `image_generation`
(gpt-image; ~1024×1536 / 1221×1289 portrait rasters), flat `#00ff00` chroma-key
background, keyed with
`~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`
(`--key-color #00ff00 --tolerance 60 --auto-key border --soft-matte
--spill-cleanup --despill`), then a deterministic PIL envelope repack
(trim to alpha bbox → uniform LANCZOS scale → paste centered on a 512×540
canvas with a fixed 12 px bottom gap).

Prompt notes: intact was authored first (composition: centered banded timber
gate, two flanking round towers with blue-gray conical roofs + red pennants,
central keep with red banner, warm upper-left daylight, anime-painted fantasy
style matching `concept-01-siege-destruction.png` mood). damaged/breached/
conquered were generated from the intact green-plate reference with
stage-delta prompts; conquered v2 tightened the footprint rule after v1's
rubble flared past the width cap (v1 discarded).

The `agy` CLI (Gemini) path was attempted first per plan but its upstream
image endpoint returned consistent internal errors during this session
("remote service remains unavailable"), so the skill's `codex exec` path B
produced all four rasters.

Measured alpha bounds (Pillow scan of the shipped PNGs; acceptance evidence,
not HPA-478 layout input):

| Stage | bbox (L, T, R, B) | width / 512 | height / 540 | bottom gap / 540 | center x |
| --- | --- | ---: | ---: | ---: | ---: |
| `lk-city-frontier-intact` | (69, 10, 443, 528) | 0.7305 | 0.9593 | 0.0222 | 256.0 |
| `lk-city-frontier-damaged` | (64, 10, 449, 528) | 0.7520 | 0.9593 | 0.0222 | 256.5 |
| `lk-city-frontier-breached` | (60, 10, 453, 528) | 0.7676 | 0.9593 | 0.0222 | 256.5 |
| `lk-city-frontier-conquered` | (64, 10, 448, 528) | 0.7500 | 0.9593 | 0.0222 | 256.0 |

All four sit inside the contract bands (intact also ≤ 0.78 width). CI test (grown to all
16 fortresses in Task 3):
`PyxisTests/BattleSceneTests.livingKingdomFortressAssetsMatchContract`.

Manual edit/compositing notes: the intact stage was rejected once for a too-
narrow silhouette (visible aspect 0.672 → regenerated at 0.723); conquered was
regenerated once for a too-wide rubble footprint (0.889 → 0.741). A small
residual chroma-green tinge inside the breached smoke plume was inspected at
pixel level and is below visibility at asset scale.

Reference plates (`references/battle-frontier-*.png`): the shipping enemy-city
pixels on `docs/visual-parity/forged-ui/native/battle-normal-393x852@3x.png`
were removed by lerping clean sky sampled on both sides of the city rect
(438, 648)–(748, 1064) @3x, then each 512×540 stage was composited over the
gate at the shipping transform — enemy-city canvas height 132 pt → 396 px at
3x, scale = 396/540, canvas pasted at (406, 671) so visible bottoms align with
the removed city. Forged chrome untouched.

For every final asset batch beyond Task 2, record here:

- exact names;
- dimensions;
- measured alpha bounds where relevant;
- anchor/registration;
- timing/display-size rule where relevant;
- generator/tool + prompt revision;
- source-board usage if available;
- manual edit/compositing notes.

### Ember / Arcane / Royal landmark families + battlefield treatments (Task 3, HPA-479)

Landed 2026-09-08. Fifteen image sets: 12 fortress stages (3 families × intact/damaged/
breached/conquered, all **512×540 RGBA**, bottom-center anchor `(0.5, 0)`, gate centered,
stage-stable camera/footprint per family) plus 3 battlefield treatments (**864×1821 RGBA**,
transparent, authored for z = `GameUITheme.Z.background + 0.5`).

Family identities (authored from `concept-02-landmark-cities.png` mood, not Frontier
recolors): **Ember** — charcoal-basalt stone, fire-lit windows, flanking bronze oil
braziers, narrow stone bridge apron, ember-orange flame banner (cities 7 Emberford,
12 Ashbridge; decorative braziers only, no gameplay fire mechanic). **Arcane** — pale
blue-white stone, cyan rune etchings + crystal finials, deep-blue star banner; runes are
etched wall marks only, no dome/barrier/shield reading (cities 9 Runewatch, 13 Starveil
Citadel). **Royal** — white marble + gold trim, crown crest, sun banner, fleur-de-lis
tower banners, marble stair (city 15 Crownspire Keep).

Generator/tool chain: `codex exec` → built-in `image_generation` (gpt-image; 1024×1536
portrait rasters; battlefields came back at exactly 864×1821 / 864×1820). The `agy`
(Gemini) path was attempted first again this session and its upstream endpoint still
returned internal errors, so all rasters are gpt-image. Each family's intact stage was
authored first on a flat `#00ff00` chroma plate; damaged/breached/conquered were produced
as reference-image edits of that intact plate (composition/footprint locked by prompt),
keyed with `~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`
(`--key-color #00ff00 --tolerance 60 --auto-key border --soft-matte --spill-cleanup
--despill`), then a deterministic PIL repack: trim to alpha bbox → LANCZOS scale →
paste centered on 512×540 with the fixed 12 px bottom gap. Per-asset opaque height
`H = round(512 × 0.75 / aspect)` clamped to `[512, 528]` (Task 2 used a fixed 518; the
per-asset clamp keeps every stage mid-band — the Ember breached smoke plume and wider
families needed the slack). Intact stages additionally clamp under the 0.78 width cap.

Prompt revisions: Ember intact took three attempts (v1/v2 silhouettes measured 0.79–0.80
wide at the fixed height — the bridge apron kept reading wide; v3 narrowed the apron to
gate width and landed 0.78 raw). Ember breached v2 overcorrected to a 0.884 wide plume
and was discarded; v1 was kept.

Measured alpha bounds (Pillow scan of the shipped PNGs; acceptance evidence):

| Stage | bbox (L, T, R, B) | width / 512 | height / 540 | bottom gap / 540 | center x |
| --- | --- | ---: | ---: | ---: | ---: |
| `lk-city-ember-intact` | (56, 16, 455, 528) | 0.7793 | 0.9481 | 0.0222 | 255.5 |
| `lk-city-ember-damaged` | (64, 14, 448, 528) | 0.7500 | 0.9519 | 0.0222 | 256.0 |
| `lk-city-ember-breached` | (70, 0, 441, 528) | 0.7246 | 0.9778 | 0.0222 | 255.5 |
| `lk-city-ember-conquered` | (54, 16, 457, 528) | 0.7871 | 0.9481 | 0.0222 | 255.5 |
| `lk-city-arcane-intact` | (64, 16, 448, 528) | 0.7500 | 0.9481 | 0.0222 | 256.0 |
| `lk-city-arcane-damaged` | (64, 10, 448, 528) | 0.7500 | 0.9593 | 0.0222 | 256.0 |
| `lk-city-arcane-breached` | (68, 0, 444, 528) | 0.7344 | 0.9778 | 0.0222 | 256.0 |
| `lk-city-arcane-conquered` | (55, 16, 456, 528) | 0.7832 | 0.9481 | 0.0222 | 255.5 |
| `lk-city-royal-intact` | (64, 5, 448, 528) | 0.7500 | 0.9685 | 0.0222 | 256.0 |
| `lk-city-royal-damaged` | (64, 3, 448, 528) | 0.7500 | 0.9722 | 0.0222 | 256.0 |
| `lk-city-royal-breached` | (64, 5, 448, 528) | 0.7500 | 0.9685 | 0.0222 | 256.0 |
| `lk-city-royal-conquered` | (64, 8, 448, 528) | 0.7500 | 0.9630 | 0.0222 | 256.0 |

All twelve sit inside the contract bands; intact stages ≤ 0.78 width. A pixel scan found
zero chroma-green residue (opaque samples where G > R×1.35 and G > B×1.35) on all twelve.

Battlefield treatments (`lk-battlefield-{ember,arcane,royal}`): atmosphere-only particle
layers authored on pure-black plates — ember sparks + heat wisps, arcane motes + star
sparkles, royal gold light shafts + dust — density concentrated in the top quarter,
sparse center column, near-empty lower half; no architecture/shield/text. Conversion:
luminance→alpha (`alpha = max(R,G,B)`, values ≤ 10 → 0) with color unpremultiplied so the
layer composites like additive light; royal resized 1820→1821 (uniform LANCZOS, ≤0.1%).
Transparency stats (864×1821 canvas): fully-transparent pixels **78.1% / 82.8% / 76.3%**
(ember/arcane/royal), mean alpha **9.5 / 8.3 / 15.0**, bottom edge alpha **0.0**, lower
corners fully transparent; top corners carry the intentional glow (ember 40/106, arcane
37/85, royal 209/253 mean alpha in the 40 px corner patches).

Reference plates (`references/battle-{emberford,runewatch,crownspire}.png`): same method
as Task 2 — shipping enemy-city pixels on `battle-normal-393x852@3x.png` removed by
per-row horizontal sky lerp sampled at `x ∈ [426,438)` and `[748,760)` across the city
rect `(438, 648)–(748, 1064) @3x`, then each family's intact 512×540 stage composited at
scale `396/540`, pasted at `(406, 671)` so visible bottoms align. Forged chrome untouched.
Contact sheet: `contact-sheets/landmark-families.png` (3 families × 4 stages).

### Transition effects (Task 4, HPA-479)

Landed 2026-09-08. Twelve image sets: `lk-fx-breach-01...06` and
`lk-fx-collapse-01...06`, all **512×512 RGBA**, dust/debris/atmosphere only
(no fortress silhouette), SpriteKit anchor `(0.5, 0)`, impact origin = canvas
bottom center.

Registration: every frame is derived from one of two chroma-keyed key plates per
sequence (burst + dissipate) by deterministic PIL repack — trim to alpha bbox →
LANCZOS scale (breach peak opaque width 430 px, collapse 460 px) → bottom-center
paste at `(256, 512)` → alpha-multiply → integer shift pinning each frame's
alpha-weighted centroid x to 256. The node position never moves during playback;
the effect only expands (frames 01–03, scale 0.60/0.85/1.00 breach,
0.62/0.88/1.00 collapse) and dissolves (frames 04–05 from the dissipate plate,
opacity 0.45/0.18 breach, 0.50/0.22 collapse). **Frame 06 is a fully transparent
512×512 RGBA canvas** (alpha all zero — `opaquePixelBounds == nil`), so the
static breached/conquered fortress owns the terminal appearance.

Timing: breach 0.05 s/frame (0.30 s total), collapse 0.07 s/frame (0.42 s total).
Display: `fxDisplayHeight = 512 × (132/540) ≈ 125 pt`; both sequences were
reviewed as 125 px filmstrips and read at that size (previews/fx-*-filmstrip.png).

Measured per-frame alpha bbox + centroid x (Pillow scan of the shipped PNGs;
registration evidence):

| Frame | bbox (L, T, R, B) | centroid x |
| --- | --- | ---: |
| `lk-fx-breach-01` | (128, 361, 386, 512) | 256.29 |
| `lk-fx-breach-02` | (74, 298, 440, 512) | 256.20 |
| `lk-fx-breach-03` | (42, 260, 472, 512) | 256.16 |
| `lk-fx-breach-04` | (62, 293, 476, 512) | 256.29 |
| `lk-fx-breach-05` | (63, 306, 468, 512) | 256.03 |
| `lk-fx-breach-06` | fully transparent | — |
| `lk-fx-collapse-01` | (117, 359, 402, 512) | 255.92 |
| `lk-fx-collapse-02` | (58, 295, 463, 512) | 255.65 |
| `lk-fx-collapse-03` | (31, 266, 491, 512) | 255.56 |
| `lk-fx-collapse-04` | (42, 294, 488, 512) | 256.33 |
| `lk-fx-collapse-05` | (46, 313, 483, 511) | 256.47 |
| `lk-fx-collapse-06` | fully transparent | — |

Generator/tool chain: `codex exec` → built-in `image_generation` (gpt-image;
1536×1024 rasters) on flat `#00ff00` chroma plates, keyed with
`~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`
(`--key-color #00ff00 --tolerance 60 --auto-key border --soft-matte
--spill-cleanup --despill`). The `agy` (Gemini) path was probed first and its
upstream endpoint still returned 500s, as in Tasks 2–3. Prompt notes: breach
burst = sharp tan-brown dust/debris blast erupting from one bottom-center point;
collapse burst = heavier gray-brown masonry chunks + churning dust (denser,
blockier read); one matching wispy dissipate plate per sequence. All four plates
share the same composition rules (bottom-center origin, empty upper third, no
architecture/ground line/text). A post-key clamp (`G → max(R,B)` on opaque
pixels where `G > R×1.35 and G > B×1.35`) removed the residual chroma
signature; the final scan counts **0** such pixels across all ten art frames.
Previews: `previews/fx-{breach,collapse}-filmstrip.png` (125 px = display size)
and `contact-sheets/fx-transition-sequences.png` (160 px), all built from the
installed production frames.

CI seam: `PyxisTests/BattleSceneTests.livingKingdomTransitionEffectsMatchContract`
(all 12 names resolve at 512×512; both terminal frames fully transparent).
### Living map overlays + partial-map fixture (Task 5, HPA-479)

Landed 2026-09-09. Four image sets plus the DEBUG `map-partial` fixture and
`ForgedVisualFixture.mapPartial` (`DevJumpState.make(city: 8)` → 7 completed
cities, `stageStatus = .cityConqueredPendingMap`).

| Asset | Canvas | Measured alpha |
| --- | ---: | --- |
| `lk-map-secured-city` | 96×96 RGBA | bbox (2, 3, 93, 92), centroid (47.6, 47.6), max alpha 183 (intentional low-alpha treatment — number plate + upper-right conquered badge stay readable), 29.6% transparent |
| `lk-map-caravan` | 128×64 RGBA | bbox (2, 6, 125, 57), centroid (59.0, 33.2), faces +X, 48.3% transparent |
| `lk-map-route-6-7-worn` | 192×192 RGBA | bbox (43, 43, 148, 148), road length 148.5 canonical px, 90.9% transparent |
| `lk-map-route-6-7-repaired` | 192×192 RGBA | bbox (43, 43, 148, 148), road length 148.5 canonical px, 90.9% transparent |

Registration: both route stages share one identical registration — the road is
centered on the canvas center and runs lower-left→upper-right as the
square-canvas diagonal (measured principal axis ≈45.5° from +X on the
192×192 canvas). The authored map-space 6→7 route is a different angle,
≈61° from +X in authored y-up coordinates (60.99°): runtime placement
(HPA-478) rotates/positions the tile onto that route. The 150 canonical px
length matches the 137.88 px city-6→city-7 span so the art connects the two
city nodes without overrunning them when placed at the crossing midpoint
`(393.6768, 580.3776)` at `runtimeOverlaySize = 192 × mapScale`. No text baked
into any asset.

Generator/tool chain: `codex exec` → built-in `image_generation` (gpt-image;
1254×1254 secured-city/routes, 1536×1024 caravan rasters) on flat `#00ff00`
chroma plates, soft-matte keyed with
`~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py` (same flags as
Tasks 2–4), then a deterministic PIL repack to the canonical canvases. The
`agy` (Gemini) path was not retried this session; its upstream endpoint had
returned 500s in Tasks 2–4, so generation ran via the established `codex
exec` path. The route pair was re-registered in a final repack pass: trim at
the 99% opaque bbox (+14 px soft-edge pad) → LANCZOS scale to a 150 canonical
px road length → alpha ≤ 10 zeroed → centered paste on 192×192 (the first cut
spanned the full canvas diagonal and overran both city nodes). A Pillow scan
counts **0** chroma-signature opaque pixels (`G > R×1.35 and G > B×1.35`,
alpha > 128) on all four.

Prompt notes: secured-city = circular ring of pale weathered stones around
trampled grass, upper-right kept empty so the runtime conquered marker stays
readable; caravan = covered wagon with beige tilt pulled by two horses facing
the right edge, tiny walking guard; worn = muddy battle-scarred dirt track
with craters; repaired = clean fitted pale-gray cobblestone with grass tufts.
Both routes authored from one composition rule (corner-to-corner diagonal,
≈45° principal axis on the canvas) so they register identically.

Fixture semantics: `makeState()` pins the pre-mount state
(`completedCityCount == 7`, unit-tested). The pending-map init normalization
(`completedCityCount = max(completedCityCount, cityNumberInCountry)`) bumps it
to **8** on the fixture-install save/load path, so the mounted map's shipping
semantic string is `Map;stage=cityConqueredPendingMap;completed=8;`
`attackableCity=none;laterLockedCity=10` — the UI smoke asserts that value
from the device. (The plan's guessed `completed=7;attackableCity=8;laterLockedCity=9`
was wrong on all three counts; the shipping value is authoritative.)

Native partial plate capture: `xcrun simctl install` + `launch cwchanap.Pyxis
-pyxis-forged-fixture map-partial -pyxis-freeze-combat` + `xcrun simctl io
screenshot`. Device: **iPhone 16 simulator, iOS 26.5** (logical 393×852,
@3x → 1179×2556 px). This machine's "iPhone 17" simulator is the 2025 device
type (402×874), so the 393×852 parity flow runs on the iPhone-16-class
device; the UI smoke skips itself on any other logical size.

Reference plates (`references/map-{early,partial,complete}.png`): composed
only on real shipping plates with PIL `alpha_composite` at `mapScale =
plateWidth / 1024` (1179/1024 = 1.15137 at 3x). Scene geometry replicated
from `CountryMapLayout` for 393×852 with safe-area insets (62, 34): scale
393/1024, backdrop 393×589.5 pt, `verticalOrigin = 206.7442 pt`, verified
against plate-measured city-node centers (±14 px). secured-city overlays are
centered on completed city nodes; nodes whose center falls below 1520 plate
px sit behind the information card and receive no overlay (never paint over
chrome). Worn 6→7 on `map-early` (before state), repaired 6→7 on
`map-partial` (7 completed ⇒ repair eligible) and `map-complete`; caravan
unrotated in contract +X facing on secured-route 2→3 (early) and 7→8
(partial/complete). The 6→7 road renders **beneath the native node
markers**: after the road paste the composer restores each route-end node's
badge disc (55 plate-px circle sampled from the pre-road state, incl. any
secured ring) so the node 6/7 numerals stay fully legible while the road
still visibly connects the two nodes. Contact sheet:
`contact-sheets/map-references.png`.

Fix round 1 (review): the first composite pass pasted the road over node
6/7's badges, burying node 6's numeral; all three references were
recomposited with the badge-disc restore above (no other pixels changed),
and the registration prose was corrected to distinguish the asset's ≈45°
canvas diagonal from the ≈61° map-space 6→7 route angle.

### Offline return references (Task 6, HPA-479)

Landed 2026-09-09. Three files, all composed **only** on real shipping
plates; Forged chrome is never redrawn and no elapsed-time UI is
synthesized.

| File | Canvas | Base plate |
| --- | ---: | --- |
| `references/offline-damage.png` | 1179×2556 (@3x of 393×852) | `native/battle-live-damage-393x852@3x.png` |
| `references/offline-conquest.png` | 1179×2556 (@3x of 393×852) | `native/conquest-idle-393x852@3x.png` |
| `contact-sheets/offline-return.png` | 1156×1266 | the two references above |

`offline-damage.png` (positive idle damage, city survived): the shipping
enemy-city pixels on the live-damage plate were removed with the Task 2/3
per-row horizontal sky lerp across the city rect (438, 648)–(748, 1064) @3x
sampled at x ∈ [426,438) and [748,760), then
`lk-city-frontier-damaged` (city 3 Falconridge, Frontier family) was
composited at the shipping transform — scale `396/540`, canvas pasted at
(406, 671). Every pixel outside the swap region is byte-identical to the
base plate (programmatic assert). The plate's captured damage-feedback
chrome (the live-combat `−3` float and its mini HP bar) is preserved as
captured, never rewritten. Caveat recorded for reviewers: the captured
HP chrome reflects the fixture's live state, while the fortress shows the
damaged stage to illustrate the post-idle-damage presentation; at runtime
the stage always follows remaining HP. Shipping offline-return feedback is
a gold tooltip rendered at HUD z, and positive-damage copy is formatted
through `CompactNumberFormatter` — e.g.
**`Buildings dealt 1.2K idle damage.`** — never a raw integer; the tooltip
itself is not baked into the reference.

`offline-conquest.png` (idle conquest while backgrounded): the underlying
scene was reconstructed from the aligned `battle-normal` plate (same
backdrop; verified per-pixel, flanking-sky mean diff ≈ 4/255), city
removed by the same sky lerp, and `lk-city-frontier-conquered` composited
at the identical shipping transform. The report panel's show-through was
then calibrated against the capture as `P ≈ k·S + c(y)` per channel
(fitted k = (0.0225, 0.0279, 0.0335); c(820) = (59.0, 44.1, 28.2) —
matching the authored panel-gradient top color (59, 44, 28) — trending to
c(1119) = (50.2, 36.8, 22.0) toward the darker bottom stop). Only the
faint fortress ghost region (396, 813)–(794, 1080) was recomputed with
the new conquered stage behind the panel; chrome pixels inside the region
(TAKEN badge arc, CITY 3 / Falconridge labels, gold coin and +17, stat
tiles, MARCH ON) are residual-masked and kept from the capture, and
everything outside the region is byte-identical to `conquest-idle`. The
report values (`+17`, `100% MVP`, `1` idle damage, `0/0 SENT/LOST`) and
its single Continue action are preserved untouched.

Generator/tool chain: deterministic PIL/numpy compositing only — no
generative step in Task 6; all art comes from the landed production image
sets and the untouched native plates.

### Final handoff inventory (Task 6, HPA-479)

Normalized complete inventory for HPA-478. Per-batch provenance detail
(tool chain, prompt revisions, manual edits, per-asset measurements) lives
in the Task 2–5 sections above; this table is the single checklist of
every delivered file.

**Runtime image sets — 35** (all installed in `Pyxis/Assets.xcassets`, one
universal 1x PNG per set via
`tools/slice_soldier_animation_strips.py::write_contents_json`):

| Batch | Sets | Canvas | Anchor / registration | Display / timing rule |
| --- | --- | ---: | --- | --- |
| Fortress (T2) | `lk-city-frontier-{intact,damaged,breached,conquered}` | 512×540 RGBA | SpriteKit `(0.5, 0)`, gate centered, stage-stable camera | 132 pt canvas height (compact ≈150 pt cap); stage by remaining HP (>60 intact, >25 damaged, >0 breached, 0 conquered) |
| Fortress (T3) | `lk-city-{ember,arcane,royal}-{intact,damaged,breached,conquered}` | 512×540 RGBA | same | same |
| Battlefield (T3) | `lk-battlefield-{ember,arcane,royal}` | 864×1821 RGBA | aspect-fill; z = `GameUITheme.Z.background + 0.5` (over opaque backdrop, under Forged grade + lane terrain) | atmosphere-only; no architecture/shield/text |
| FX (T4) | `lk-fx-breach-01…06`, `lk-fx-collapse-01…06` | 512×512 RGBA | anchor `(0.5, 0)`, impact origin = canvas bottom center, node static | breach 0.05 s/frame (0.30 s), collapse 0.07 s/frame (0.42 s); height `512 × (132/540) ≈ 125 pt`; frame 06 fully transparent |
| Map (T5) | `lk-map-secured-city`, `lk-map-caravan`, `lk-map-route-6-7-worn`, `lk-map-route-6-7-repaired` | 96×96 / 128×64 / 192×192 / 192×192 RGBA | canonical 1024×1536 map space; caravan faces +X; route tiles pre-drawn at ≈45° canvas diagonal for runtime rotation onto the ≈61° 6→7 route at midpoint (393.6768, 580.3776) | `runtimeOverlaySize = canonicalPixelSize × (displayedBackdropFrame.width / 1024)`; decorative/noninteractive |

Measured alpha bounds per asset: Task 2/3 tables above (fortresses) and
Task 4/5 tables above (FX registration, map overlays). CI seam:
`PyxisTests/BattleSceneTests.livingKingdomFortressAssetsMatchContract` +
`.livingKingdomTransitionEffectsMatchContract` (+ name/dimension checks
for battlefield and map sets).

**Reference plates — 12** (under `references/`, all 1179×2556 @3x of
393×852, composed only on real shipping plates):

| File | Base plate | Swap |
| --- | --- | --- |
| `battle-frontier-{intact,damaged,breached,conquered}` | `battle-normal` | per-stage frontier fortress at the gate |
| `battle-emberford`, `battle-runewatch`, `battle-crownspire` | `battle-normal` | Ember/Arcane/Royal intact stages |
| `map-early`, `map-partial`, `map-complete` | `map-attackable-locked` / `map-partial` native fixture / `map-complete` | worn/repaired 6→7, secured rings, caravan |
| `offline-damage` | `battle-live-damage` | frontier-damaged at the gate; feedback chrome preserved |
| `offline-conquest` | `conquest-idle` | conquered ghost behind the preserved report |

**Support files**: contact sheets `contact-sheets/{destruction-frontier,
landmark-families,fx-transition-sequences,map-references,offline-return}.png`
and display-size previews `previews/fx-{breach,collapse}-filmstrip.png`;
source boards + the native `map-partial` capture under `source/`.

### Final visual review (Task 6, HPA-479)

Reviewed 2026-09-09 at logical 393×852 (native @3x plates read at 1:1 and
downscaled):

- **Apparent fortress width** — intact/damaged frontier at the gate read
  ≈90–100 pt against the removed shipping silhouette; gate-centered,
  bottoms aligned. ✓
- **Stage continuity** — `destruction-frontier` sheet and the offline
  composite: same camera, center, tower positions, and footprint across
  intact/damaged/breached/conquered. ✓
- **Landmark identity** — Ember (charcoal + fire-lit braziers), Arcane
  (pale blue-white + cyan runes, no shield reading), Royal (marble + gold
  crown/sun banners) are distinct authored families, not recolors. ✓
- **Treatment grade/z intent** — battlefield layers are top-weighted
  atmosphere only (sparks/motes/light shafts), near-empty lower half,
  authored for z = background + 0.5 under the Forged grade. ✓
- **FX scale/origin** — 125 px filmstrips read at display size; bottom-
  center origin; static node; frame 06 empty hands off to the static
  breached/conquered fortress. ✓
- **Map scale/labels** — `map-partial`: repaired 6→7 connects the nodes
  beneath legible badge numerals; caravan on 7→8; secured rings never
  cover numbers or conquered markers; no baked text. ✓
- **Truthful offline compositions** — damage reference swaps only fortress
  pixels on the real damage-return plate (no elapsed-time UI; formatted
  shipping copy documented above); conquest reference preserves the
  shipping report values and its single Continue action. ✓
- Review limitation: `lk-city-royal-breached` could not be opened in a
  viewer during this pass (content gateway rejects the file); its
  correctness is covered programmatically — alpha-envelope bounds in the
  Task 3 table and the CI contract test — and by the Task 3 pixel review.

## Acceptance

Before PR #41 leaves Draft:

- **35** `lk-*` image sets exist;
- all 16 fortress stages pass 512×540 + alpha-envelope CI checks;
- all 3 battlefield treatments are 864×1821 and authored for z = background + 0.5;
- all 12 FX frames obey anchor/timing/display-size rules and terminal transparency;
- all 4 map assets obey canonical sizing/registration;
- the DEBUG `map-partial` fixture and its unit/UI tests are green;
- corrected references use real shipping plates and truthful formatted copy;
- Xcode build and existing unit/UI CI gates pass;
- no non-DEBUG shipping gameplay/runtime behavior, persistence, balance, routing, CI, Codecov, existing asset, or project-file change is present.

HPA-478 owns shipping playback/state integration after this PR merges.