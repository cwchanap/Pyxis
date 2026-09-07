# Living Kingdom Anime Asset Pack Design

## Status

Planning contract for **HPA-479**. The draft PR is the single asset-production PR for this ticket: planning/handoff documentation lands first, then the image/animation agent adds production assets to the same branch and PR.

**Source-reference gate:** the four original concept boards are not yet in the repository. Bulk image generation is blocked until Task 1 recovers the exact `Pyxis_Living_Kingdom_Concept_References.zip` boards, copies them unchanged into the PR, records SHA-256 hashes, and completes the exclusion review. Do not describe the production contract as source-approved before that gate passes.

Runtime playback and gameplay integration belong to **HPA-478** and its separate single PR. HPA-479 must not add Swift runtime behavior.

## Goal

Make Pyxis's existing Country 1 campaign feel more alive and memorable through presentation only:

1. visible fortress damage during a siege;
2. stronger identity for a few landmark cities;
3. a conquered map that looks secured and inhabited;
4. an offline return that reveals the real resulting battlefield state without inventing rewards or replaying a battle.

The art must fit the shipping Forged UI and current SpriteKit geometry rather than turning the concept boards into a new game design.

## Selected shape

Use a compact reusable art pack rather than bespoke content for all 15 cities:

- **4 fortress families** — frontier, ember, arcane, royal;
- **4 static stages per family** — intact, damaged, breached, conquered;
- **3 transparent battlefield treatment overlays** — ember, arcane, royal; the existing battlefield remains the frontier treatment;
- **2 short shared one-shot FX sequences** — breach and final collapse;
- **3 small ambient textures** — smoke, embers, ward glow;
- **4 map overlays** — secured-city treatment, caravan, worn 6→7 crossing, repaired 6→7 crossing;
- **no separate offline-return illustration set** — offline presentation reuses the same damage/conquered assets plus the existing report/feedback UI.

No runtime manifest, VFX manager, generated-asset framework, new renderer, or per-city asset system is needed.

## Authoritative inputs

Planning baseline: `main` at `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`, after the Forged UI work.

The following remain authoritative over any concept art:

- `Country1CityCatalog` for city names and identity;
- `BattlefieldLayout` and `BattleScene` for city/gate/lane geometry;
- `CountryMapLayoutDefinition.country1` and `CountryMapLayout` for map coordinates and scale;
- `KingdomGameState`, `BattleResult`, and `IdleProgressResult` for progression and outcomes;
- `docs/visual-parity/forged-ui/` for the existing 393×852 visual composition and chrome.

No mock value becomes game data.

### Concept references

The original four boards remain mood/composition references only:

1. Siege Destruction
2. Landmark Cities
3. Living Kingdom Map
4. Offline Return Reveal

The exact four files from `Pyxis_Living_Kingdom_Concept_References.zip` must be copied without resampling/recompression into `docs/visual-parity/living-kingdom/source/` and hashed before bulk production. The written game contract overrides invented cities, currencies, counters, objectives, or mechanics shown on those boards.

### Visual direction: anime fantasy

Use **anime-inspired painted fantasy environment art**, not photorealism or western dark-fantasy concept art:

- clean readable silhouettes and deliberate shape language;
- stylized painted stone, fire, magical light, banners, and atmosphere;
- restrained detail at phone scale;
- cinematic color separation without turning the screen into poster art;
- no character redesign, chibi reinterpretation, or new troop art;
- no text, HUD, counters, buttons, phone frames, or interaction hints baked into scene textures.

Foreground lanes, soldiers, HP feedback, Scout content, city targets, and tabs stay more readable than decoration.

## Runtime geometry the art must respect

### Fortress canvas is the scaling contract

`BattleScene.makeBattleSprite` gives image-backed structures `anchorPoint = (0.5, 0)`. `BattleScene.fitBattleNode` then scales an `SKSpriteNode` from its **full sprite canvas height**, including transparent pixels. HPA-478 will keep that existing path; it will not add a second fortress-body geometry type merely to compensate for HPA-479 exports.

At the baseline commit:

- shipping `enemy-city.png` is **1223×1286 px**, width:height ≈ **0.951**;
- the regular Forged enemy city is rendered at **132 pt high**, making the shipping sprite roughly **126 pt wide**;
- compact layouts derive the target height from `BattlefieldLayout`, up to roughly 150 pt.

Therefore all 16 Living Kingdom fortress sprites use one fixed, near-square production canvas:

- canvas: **512×540 px** transparent PNG;
- width:height ≈ **0.948**, so a 132 pt height render is ≈ **125 pt wide**;
- runtime anchor: bottom center `(0.5, 0)`;
- visual ground meets the bottom edge; do not add transparent padding below the baseline;
- main gate is centered on the horizontal midpoint and remains aligned with the center-lane impact;
- same canvas, baseline, horizontal gate center, camera, and lighting direction for every family/stage;
- intact structural silhouette should occupy most of the canvas height, comparable to the shipping city; damage/rubble may change alpha bounds but must not use padding to control runtime scale.

Measured nontransparent bounds remain useful **documentation only**. HPA-478 does not use them to resize or position the fortress. Do not add `FortressAnimationGeometry`/body-region runtime APIs for this ticket.

### Battlefield treatment overlays

The existing frontier `battlefield-backdrop.png` is **864×1821 px**, opaque, and aspect-filled by `BattleScene`. Task 1 mechanically confirms those baseline dimensions before authoring.

Each of `lk-battlefield-{ember,arcane,royal}`:

- is transparent **864×1821 px**;
- uses the same aspect-fill transform as `battlefieldBackdropNode`;
- is intended to sit with the backdrop at `GameUITheme.Z.background`, **below** `forgedAtmosphereNode` (`background + 1`) and below lane terrain (`z = -1`);
- paints no second fortress;
- leaves all three lane corridors readable through contrast/value control;
- keeps important accents inside the reference-phone visible crop;
- contains no gameplay-significant object that looks like another tower, shield, attack, or resource.

This is a handoff z-order contract for HPA-478, not new runtime code in HPA-479.

### Country-map canonical space and display scale

Country 1 stays in the existing **1024×1536** authored source space with 15 city anchors and 14 sequential primary routes.

The repair story uses **City 6 Granite Pass → City 7 Emberford**:

- City 6: `(360.2432, 520.0896)`
- City 7: `(427.1104, 640.6656)`
- segment midpoint: `(393.6768, 580.3776)`
- segment length: `137.8760 px`
- segment direction: `60.9888°` from +X in authored map coordinates

The worn/repaired patch is pre-composed to that orientation on a **192×192 canonical-pixel transparent canvas** centered on the segment midpoint.

Map overlay dimensions are **canonical source pixels, not SpriteKit points**. HPA-478 uses the same backdrop scale already computed by `CountryMapLayout`:

```text
mapScale = displayedBackdropFrame.width / 1024
runtimeOverlaySize = canonicalPixelSize × mapScale
```

On a 393-point-wide phone where width drives the scale, a 96 px secured-city canvas is about 37 pt wide and a 192 px route patch about 74 pt wide. HPA-478 must not display them as 96 pt / 192 pt nodes.

`lk-map-secured-city` shares the completed-city area with the current ~30 pt city circle, centered number label, and the existing conquered marker offset up-right. Author it as a low-alpha warm halo plus a small banner biased away from the upper-right marker; do not place opaque art across the number label or marker.

All map decorations are noninteractive and do not change hit targets, anchors, route topology, or Scout/Attack behavior.

### FX attachment contract

Breach/collapse frames use **512×512 transparent canvases** with one explicit SpriteKit convention:

- `anchorPoint = (0.5, 0)` for every FX frame;
- impact origin = canvas bottom center;
- frame position does not move during playback;
- visual debris/dust expands around that origin; it does not animate/replace the fortress silhouette;
- the **last frame is fully transparent**;
- static `breached` / `conquered` fortress art owns the terminal state.

README alpha bounds are recorded in PNG coordinates; runtime attachment remains the bottom-center SpriteKit anchor so HPA-478 does not need to infer Y-axis orientation from the image.

## Authoritative city → family table

This table is presentation content. It is authoritative by **city number** and must not be inferred from `CityDefenseTrait`:

| Family | Cities |
| --- | --- |
| Frontier | 1–6, 8, 10, **11**, 14 |
| Ember | 7 Emberford, 12 Ashbridge |
| Arcane | 9 Runewatch, 13 Starveil Citadel |
| Royal | 15 Crownspire Keep |

City 11 Kingshield Keep remains **Frontier** even though it shares `.reinforcedKeep` with City 15. HPA-478 may encode this as a small static projection beside `Country1CityCatalog`; it must not create a mapping service or derive family from defense trait.

## Destruction stages

| Remaining city HP | Static asset stage |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

Art semantics:

- **intact:** fully readable family silhouette;
- **damaged:** cracks/chipped masonry/local smoke, gate not yet open;
- **breached:** visibly broken gate and rubble within the same footprint;
- **conquered:** stable ruined/secured aftermath, not an empty battlefield or different camera shot.

Every static stage must read correctly if runtime damage skips directly to it.

## Asset naming contract

### Fortress image sets — 16

`lk-city-{frontier|ember|arcane|royal}-{intact|damaged|breached|conquered}`

### Battlefield treatments — 3

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

### Shared one-shot FX — 12 frames

Breach:

- `lk-fx-breach-01` ... `lk-fx-breach-06`
- 512×512 transparent
- 0.30 s total, 0.05 s/frame
- last frame fully transparent

Collapse:

- `lk-fx-collapse-01` ... `lk-fx-collapse-06`
- 512×512 transparent
- 0.42 s total, 0.07 s/frame
- last frame fully transparent

### Ambient textures — 3

- `lk-fx-smoke-soft` — 256×256 transparent
- `lk-fx-ember-specks` — 256×256 transparent
- `lk-fx-ward-glow` — 512×512 transparent

### Living-map image sets — 4

- `lk-map-secured-city` — 96×96 canonical-pixel transparent canvas
- `lk-map-caravan` — 128×64 canonical-pixel transparent canvas, faces +X
- `lk-map-route-6-7-worn` — 192×192 canonical-pixel transparent canvas
- `lk-map-route-6-7-repaired` — 192×192 canonical-pixel transparent canvas

## Asset-catalog convention

Use new uniquely named image sets under `Pyxis/Assets.xcassets/`; never replace assets consumed by `main`.

Match the repository's actual conventions instead of forcing one shape everywhere:

- fortress, battlefield, ambient, and map image sets: **one universal 1x entry only**, like `enemy-city`;
- breach/collapse animation-frame image sets: universal 1x filename plus empty 2x/3x entries is allowed/preferred to mirror existing soldier-frame sets;
- no generated multi-resolution pipeline;
- no `project.pbxproj` edit.

## Handoff metadata

`docs/visual-parity/living-kingdom/README.md` is the single human-readable art→code contract. It is not parsed at runtime.

For each final asset/family/sequence, record:

- exact asset name(s);
- pixel dimensions;
- alpha/opaque treatment;
- measured nontransparent bounds;
- bottom-center anchor/baseline or canonical-map registration;
- map canonical size and runtime scale rule where relevant;
- sequence timing/loop behavior where relevant;
- source/generation provenance, including tool, prompt revision, source board(s), and manual edits.

## Corrected reference strategy: real plates, art-only compositing

HPA-479 cannot produce a native screenshot of Living Kingdom runtime because HPA-478 owns the Swift integration. Therefore HPA-479 references must **not redraw Forged chrome**. They composite only new scene art onto real shipping screenshots/plates.

Use these baseline plates from `docs/visual-parity/forged-ui/native/`:

- Battle/landmarks: `battle-normal-393x852@3x.png`, downsampled to logical 393×852 before compositing;
- Map early: `map-attackable-locked-393x852@3x.png`;
- Map complete: `map-complete-393x852@3x.png`;
- Offline conquest: `conquest-idle-393x852@3x.png`.

For the repaired 6→7 partial-map showcase, capture one additional **shipping-only pre-art plate** without code changes: use the existing DEBUG jump-to-city tool to jump to City 8, switch to Map, and take a native 393×852 framebuffer screenshot. Store that untouched plate under `docs/visual-parity/living-kingdom/source/` with capture provenance, then composite the HPA-479 map overlays onto it. Do not fabricate map completion chrome.

Required corrected references:

- `battle-frontier-{intact,damaged,breached,conquered}.png`
- `battle-emberford.png`
- `battle-runewatch.png`
- `battle-crownspire.png`
- `map-early.png`
- `map-partial.png` (shipping City-8 pre-art plate; 6→7 repair eligible)
- `map-complete.png`
- `offline-damage.png`
- `offline-conquest.png`

`offline-damage.png` may replace only the fortress/art layer on the Battle plate. **Do not draw new idle chrome or elapsed-time copy.** The shipping transient copy is `Buildings dealt N idle damage.`; HPA-478's native runtime acceptance will prove the real text/feedback surface.

`offline-conquest.png` uses the real `conquest-idle` plate and replaces only the underlying fortress/art pixels; retain the existing report, values, and one Continue action unchanged.

Do not generate gold totals, troop counts, timers, buttons, or other HUD text in HPA-479 reference images.

## Validation strategy

HPA-479 remains runtime-free, but asset validation is repeatable:

1. inspect every PNG at actual phone-scale composition for lane/HUD/card clearance;
2. verify alpha, exact dimensions, fortress/FX registration, stage alignment, and map canonical sizing;
3. add `tools/tests/test_living_kingdom_asset_pack.py` when the production assets land; it validates the 38 image-set inventory, dimensions, alpha, and image-set entry conventions using Pillow/`unittest`;
4. run `python3 -m unittest discover -s tools/tests` as a **manual repository gate** (current GitHub Actions does not invoke this suite); do not modify CI for HPA-479;
5. build the app so every new `Contents.json` is accepted by the asset catalog;
6. confirm the PR diff contains no Swift/runtime, persistence, balance, routing, project-file, CI, or Codecov changes.

## Non-goals

HPA-479 does not include:

- Swift scene playback or stage-selection code;
- HP thresholds persisted in save data;
- new city/troop/building mechanics;
- Rally, direct-lane deployment, Chronicle, Country 2, prestige, production chains, rebuild timers, collectibles, extra currencies;
- 15 unique battle environments;
- soldier re-authoring;
- audio production;
- 3D, skeletal animation, a new renderer, VFX manager, runtime asset manifest/parser, or asset-generation framework;
- a second UI redesign or custom font.

## Done definition

HPA-479 is ready to merge only when this same draft PR contains:

- the four exact source concept boards with hashes and completed exclusion review;
- all **38** `lk-*` runtime image sets;
- corrected references/contact sheets/previews built from production art and real shipping plates;
- complete handoff/provenance metadata;
- passing `python3 -m unittest discover -s tools/tests` asset validation;
- successful Xcode asset-catalog build;
- visual review confirming the 512×540 fortress envelope, backdrop z-order intent, map source-scale contract, and anime-fantasy direction;
- no Swift/runtime, project-file, CI, or Codecov changes.

After merge, HPA-478 consumes the fixed names/anchors/timings/scale rules and implements static city→family selection, HP-stage projection, one-shot live transition effects, and map overlay sizing through the existing layout scale. No second art pass should be required for geometry mistakes already covered by this contract.