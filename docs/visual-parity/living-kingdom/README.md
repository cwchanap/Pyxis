# Living Kingdom art → code handoff

## Purpose and gate

This directory is the single human-readable handoff for **HPA-479** production art and later **HPA-478** runtime integration. It is documentation, not a runtime manifest/parser.

The HPA-479 draft PR starts with this planning contract. **Bulk art generation remains blocked until the exact four `Pyxis_Living_Kingdom_Concept_References.zip` boards are copied unchanged into `source/`, SHA-256 hashed, and reviewed against the written exclusions.** Until that happens, this is a production-ready geometry/naming plan, not an approved source-reference pack.

## Planning baseline

- Repository baseline: `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`
- Existing visual baseline: `docs/visual-parity/forged-ui/`
- Corrected-reference viewport: logical **393×852**
- Country 1 map source space: **1024×1536**
- Shipping `enemy-city.png`: **1223×1286 px**
- Shipping `battlefield-backdrop.png`: **864×1821 px**; Task 1 mechanically confirms this immutable-baseline expectation before production
- Runtime fortress anchor: **bottom center `(0.5, 0)`**
- Regular Forged enemy-city display height: **132 pt**
- Art direction: **anime-inspired painted fantasy environments**, subordinate to Forged HUD/gameplay readability

The four source boards remain mood/composition references only. This written contract wins whenever a board depicts mechanics Pyxis does not have.

## Game contract art must not change

Keep the current fixed-camera layered 2D/SpriteKit presentation, three marching lanes, Battle/Camp/Map tabs, five troop types, gold-only economy, authored city identities, HP/reward/unlock behavior, 8-hour idle cap, and existing report/feedback surfaces.

Do not bake UI, text, counters, resources, objectives, touch targets, phone frames, claim buttons, invented city/level data, or new mechanics into scene textures.

## Fortress asset contract

`BattleScene.fitBattleNode` scales an image-backed fortress from its **full sprite canvas height**. Alpha bounds are not a runtime sizing API.

All 16 city sprites therefore:

- are transparent **512×540 px** PNGs;
- render at about **125 pt wide × 132 pt high** on the regular Forged phone, closely matching the shipping city envelope;
- share bottom-center anchor `(0.5, 0)`, bottom-edge ground baseline, horizontal gate center, camera, and lighting direction;
- keep the main gate centered on the canvas midpoint so the existing center-lane impact still reads as a gate hit;
- do not add transparent padding below the visual ground or use padding to manipulate displayed scale;
- keep the intact structural silhouette occupying most of the canvas height; damage/rubble may change measured alpha bounds but must not require a different runtime size or anchor.

Measured alpha bounds are recorded for art review/provenance only. HPA-478 must not add a fortress body-region geometry type just to compensate for inconsistent exports.

### Stage thresholds

| Remaining HP | Stage |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

### Authoritative city → family mapping

The table is authoritative by **city number**. Never infer it from `CityDefenseTrait`.

| Family | City use | Required names |
| --- | --- | --- |
| Frontier | Cities 1–6, 8, 10, **11**, 14 | `lk-city-frontier-{intact,damaged,breached,conquered}` |
| Ember | 7 Emberford, 12 Ashbridge | `lk-city-ember-{intact,damaged,breached,conquered}` |
| Arcane | 9 Runewatch, 13 Starveil Citadel | `lk-city-arcane-{intact,damaged,breached,conquered}` |
| Royal | 15 Crownspire Keep | `lk-city-royal-{intact,damaged,breached,conquered}` |

City 11 Kingshield Keep intentionally remains Frontier even though it shares `.reinforcedKeep` with City 15.

## Battlefield treatment contract

The frontier environment remains the shipping `battlefield-backdrop`. Add three transparent overlays:

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

Each overlay:

- is **864×1821 px**, transparent;
- uses the same aspect-fill transform as the shipping backdrop;
- is intended for `GameUITheme.Z.background`, **under** `forgedAtmosphereNode` (`background + 1`) and under lane terrain (`z = -1`);
- paints no second fortress;
- leaves all three lane corridors readable;
- keeps important detail in the 393×852 crop;
- uses fire/wards/banners as identity only, not as new attacks/shields/resources.

HPA-479 supplies only the art and this z-order contract. HPA-478 performs the node insertion.

## Shared transition effects

### Gate breach

- names: `lk-fx-breach-01` ... `lk-fx-breach-06`
- canvas: **512×512**, transparent
- SpriteKit anchor: **`(0.5, 0)`**
- impact: **canvas bottom center**
- duration: **0.30 s total**, `0.05 s/frame`
- loop: no
- final frame: **fully transparent**
- terminal appearance: `*-breached` static fortress

### Final collapse

- names: `lk-fx-collapse-01` ... `lk-fx-collapse-06`
- canvas: **512×512**, transparent
- SpriteKit anchor: **`(0.5, 0)`**
- impact: **canvas bottom center**
- duration: **0.42 s total**, `0.07 s/frame`
- loop: no
- final frame: **fully transparent**
- terminal appearance: `*-conquered` static fortress

Both sequences remain positioned at the same impact point throughout playback and animate only dust/debris/atmosphere, not a second fortress silhouette.

### Ambient textures

| Asset | Canvas | Intended use |
| --- | ---: | --- |
| `lk-fx-smoke-soft` | 256×256 transparent | simple drift/fade near damaged/breached city |
| `lk-fx-ember-specks` | 256×256 transparent | subtle Ember atmosphere |
| `lk-fx-ward-glow` | 512×512 transparent | subtle Arcane pulse/fade |

## Living-map registration and scale

Country 1 stays in the shipping **1024×1536 canonical source space**. Overlay canvas sizes below are canonical pixels, **not display points**.

The repair story uses **Granite Pass (6) → Emberford (7)**:

| Registration | Canonical source coordinate |
| --- | ---: |
| City 6 | `(360.2432, 520.0896)` |
| City 7 | `(427.1104, 640.6656)` |
| Segment midpoint | `(393.6768, 580.3776)` |
| Segment length | `137.8760 px` |
| Segment direction | `60.9888°` from +X |

Runtime sizing contract for HPA-478:

```text
mapScale = displayedBackdropFrame.width / 1024
runtimeOverlaySize = canonicalPixelSize × mapScale
```

Do not render a 96 px overlay as 96 pt or a 192 px patch as 192 pt.

Required map assets:

| Asset | Canonical canvas | Contract |
| --- | --- | --- |
| `lk-map-secured-city` | 96×96 transparent, center | low-alpha warm halo + small banner; keep the center number readable and keep the upper-right area clear for the existing conquered marker |
| `lk-map-caravan` | 128×64 transparent, center, faces +X | quiet decorative caravan; HPA-478 rotates/scales it along existing routes |
| `lk-map-route-6-7-worn` | 192×192 transparent, center | pre-composed to the canonical 6→7 orientation at the midpoint above |
| `lk-map-route-6-7-repaired` | 192×192 transparent, center | identical canvas/registration; bridge/road condition only |

Map decorations are noninteractive. They do not move anchors, change route topology, add economy/production, or alter the existing 44×44 hit targets.

## Anime-fantasy generation brief

> Anime-inspired painted fantasy environment art for a mobile strategy game; clean readable silhouette, restrained detail, stylized stone/fire/magical light, fixed camera, strong value separation, no characters, no UI, no text, transparent scene asset where requested. Preserve the exact supplied canvas, common ground baseline, horizontal gate center, camera, scale, and lighting direction across variants. Keep decoration subordinate to the Forged dark-iron/gold HUD and three gameplay lanes.

Family emphasis:

- **Frontier:** practical gray/brown stone and timber, muted banners.
- **Ember:** bridge/gate cues, oil braziers, orange ember light; no gameplay fire system.
- **Arcane:** cool cyan/blue ward motifs; no shield UI/second HP concept.
- **Royal:** refined stone/metal, royal banners, grander but inside the same 512×540 envelope.

## Corrected references use real shipping plates

HPA-479 does not have Living Kingdom Swift integration, so it must not draw replacement Forged chrome. Only the new scene-art pixels are composited onto shipping screenshots.

Baseline plates from `docs/visual-parity/forged-ui/native/`:

- Battle and landmark references: `battle-normal-393x852@3x.png`, downsampled to 393×852 before compositing;
- early map: `map-attackable-locked-393x852@3x.png`;
- complete map: `map-complete-393x852@3x.png`;
- offline conquest: `conquest-idle-393x852@3x.png`.

For `map-partial.png`, first capture an untouched shipping-only plate with **no code changes**: use the existing DEBUG jump-to-city tool to jump to City 8, switch to Map, and take a native 393×852 framebuffer screenshot. Store the untouched source plate and capture provenance under `source/`. This gives a truthful state where Cities 6 and 7 are already complete and the repaired crossing is eligible.

Required final reference files:

### Destruction

- `references/battle-frontier-intact.png`
- `references/battle-frontier-damaged.png`
- `references/battle-frontier-breached.png`
- `references/battle-frontier-conquered.png`

### Landmarks

- `references/battle-emberford.png`
- `references/battle-runewatch.png`
- `references/battle-crownspire.png`

### Map

- `references/map-early.png`
- `references/map-partial.png`
- `references/map-complete.png`

### Offline return

- `references/offline-damage.png`
- `references/offline-conquest.png`

`offline-damage.png` replaces only the fortress/art layer on the real Battle plate. **Do not fabricate an elapsed-time line or redraw the feedback UI.** The shipping transient copy is `Buildings dealt N idle damage.` and HPA-478's native runtime acceptance owns proof of that live text.

`offline-conquest.png` uses the real `conquest-idle` plate and changes only underlying scene-art pixels. Preserve the shipping report/values/one Continue action.

No reference may generate or modify gold totals, troop counts, timers, tabs, buttons, or other HUD copy.

## Asset-catalog convention

New runtime art lives in `Pyxis/Assets.xcassets/` as unique `lk-*` image sets.

- fortress, battlefield, ambient, and map assets: **one universal 1x entry only**;
- breach/collapse frame sets: universal 1x filename plus empty 2x/3x entries, mirroring existing soldier-animation frame sets;
- no multi-resolution generation pipeline;
- no replacement of existing assets;
- no `project.pbxproj` change.

## Production inventory and provenance

Every final export is documented here in the same commit that adds it. Record:

1. exact asset name/frame range;
2. pixel dimensions;
3. alpha/opaque treatment;
4. measured nontransparent bounds;
5. anchor/baseline or canonical-map registration;
6. intended use and map scale rule where relevant;
7. timing/loop behavior where applicable;
8. generator/tool/version when known;
9. prompt revision/reference-board source;
10. manual edit/compositing note.

Alpha bounds are review/provenance metadata; they are not an HPA-478 layout API.

## Repeatable validation

When production assets land, add `tools/tests/test_living_kingdom_asset_pack.py`. It validates the **38** `lk-*` sets, exact dimensions, alpha presence, transparent final FX frames, and image-set entry conventions with Pillow/`unittest`.

Run manually:

```bash
python3 -m unittest discover -s tools/tests
```

The current GitHub Actions workflow does **not** invoke `tools/tests`; HPA-479 does not modify CI merely to add this asset gate.

Also run an Xcode build so the asset catalog accepts every `Contents.json`.

## Acceptance

Before this PR leaves Draft:

- the four exact concept boards are present, hashed, and exclusion-reviewed;
- all **38** `lk-*` image sets exist: 16 fortress + 3 battlefield + 15 FX + 4 map;
- every fortress uses the **512×540** full-canvas scaling contract;
- battlefield overlays are 864×1821 and authored for backdrop-level z-order under the Forged atmosphere;
- FX use `(0.5, 0)`, bottom-center impact, and fully transparent final frames;
- map overlays use canonical-pixel sizing plus `displayedBackdropFrame.width / 1024` runtime scale;
- City 11 remains Frontier via the explicit city-number mapping;
- corrected references/contact sheets/previews use real shipping chrome plates and contain no invented idle elapsed-time copy;
- `python3 -m unittest discover -s tools/tests` passes;
- Xcode builds the asset catalog successfully;
- the PR contains no Swift/runtime, persistence, balance, project-file, CI, or Codecov changes.

HPA-478 then consumes this fixed handoff. Image/animation authoring ends with HPA-479.