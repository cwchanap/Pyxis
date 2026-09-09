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

For every final asset batch, record here:

- exact names;
- dimensions;
- measured alpha bounds where relevant;
- anchor/registration;
- timing/display-size rule where relevant;
- generator/tool + prompt revision;
- source-board usage if available;
- manual edit/compositing notes.

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