# Living Kingdom art → code handoff

## Purpose

This directory is the single human-readable handoff for **HPA-479** production art and the later **HPA-478** runtime integration.

The HPA-479 draft PR is opened with this contract before bulk image/animation authoring. Production metadata is added to this same README atomically with the corresponding final exports; there is no runtime JSON manifest or parser.

## Planning baseline

- Repository baseline: `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`
- Existing visual baseline: `docs/visual-parity/forged-ui/`
- Corrected-reference viewport: logical **393×852**
- Country 1 map source space: **1024×1536**
- Runtime fortress anchor: **bottom center**
- Regular Forged enemy-city display height: **132 pt**
- Compact-layout maximum target is approximately **150 pt**
- Art direction: **anime-inspired painted fantasy environments**, subordinate to Forged HUD/gameplay readability

The original mood boards come from `Pyxis_Living_Kingdom_Concept_References.zip` in the planning conversation. The four exact source boards are copied into `source/` and hashed before bulk generation begins. They remain mood/composition references only; this written contract wins when the boards depict mechanics Pyxis does not have.

## Game contract that art must not change

Keep the current fixed-camera layered 2D/SpriteKit presentation, three marching lanes, Battle/Camp/Map tabs, five existing troop types, gold-only economy, authored city identities, current HP/reward/unlock behavior, 8-hour idle cap, and existing report/feedback surfaces.

Do not bake UI, text, counters, resources, objectives, touch targets, phone frames, claim buttons, invented city/level data, or new mechanics into scene textures.

## Fortress asset contract

All 16 city sprites:

- are transparent **768×512 px** PNGs;
- share one bottom-center anchor, ground baseline, horizontal gate center, camera, and lighting direction;
- keep the main gate centered and visually meeting the lower baseline so the existing center-lane impact reads correctly;
- remain clean at 132 pt regular and roughly 150 pt maximum displayed height;
- may change damage detail/rubble between stages but must not require per-stage layout or anchor changes.

Runtime stage thresholds used later by HPA-478:

| Remaining HP | Stage |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

### Required fortress image sets

| Family | City use | Required names |
| --- | --- | --- |
| Frontier | Cities 1–6, 8, 10, 11, 14 | `lk-city-frontier-{intact,damaged,breached,conquered}` |
| Ember | City 7 Emberford, City 12 Ashbridge | `lk-city-ember-{intact,damaged,breached,conquered}` |
| Arcane | City 9 Runewatch, City 13 Starveil Citadel | `lk-city-arcane-{intact,damaged,breached,conquered}` |
| Royal | City 15 Crownspire Keep | `lk-city-royal-{intact,damaged,breached,conquered}` |

For each final PNG, the production commit records its measured alpha bounds `(minX, minY, maxX, maxY)` and generation provenance in the inventory section below. Bounds are measured from the actual export, not guessed in this planning-only draft.

## Battlefield treatment contract

The existing `battlefield-backdrop` remains the frontier environment. Landmark identity layers are transparent overlays:

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

Each overlay uses **exactly the same pixel canvas and aspect ratio as the current `Pyxis/Assets.xcassets/battlefield-backdrop.imageset/battlefield-backdrop.png`**. The image worker records the numeric source dimensions from local `sips` inspection before producing these overlays.

Rules:

- no second fortress painted into the treatment;
- all three lanes remain readable;
- primary accents stay visible in the 393×852 aspect-filled crop;
- ember fire/oil, arcane wards, and royal banners/materials are identity only and must not imply new attacks, shields, or interactable systems.

## Shared transition effects

### Gate breach

- names: `lk-fx-breach-01` ... `lk-fx-breach-06`
- canvas: **512×512**, transparent
- registration: shared bottom-center impact convention
- duration: **0.30 s total**, `0.05 s/frame`
- loop: no
- terminal state: fade to transparent; `*-breached` static city art owns the result

### Final collapse

- names: `lk-fx-collapse-01` ... `lk-fx-collapse-06`
- canvas: **512×512**, transparent
- registration: same shared bottom-center impact convention
- duration: **0.42 s total**, `0.07 s/frame`
- loop: no
- terminal state: fade to transparent; `*-conquered` static city art owns the result

### Ambient textures

| Asset | Canvas | Intended use |
| --- | ---: | --- |
| `lk-fx-smoke-soft` | 256×256 transparent | simple drift/fade near damaged/breached city |
| `lk-fx-ember-specks` | 256×256 transparent | subtle Ember family atmosphere |
| `lk-fx-ward-glow` | 512×512 transparent | subtle Arcane pulse/fade |

These textures are intentionally simple enough for SpriteKit actions; no shader/VFX framework or authored full-screen video is required.

## Living-map registration

The Country 1 authored map stays unchanged at **1024×1536** with its existing 15 anchors and 14 sequential routes.

The repair story uses the existing **Granite Pass (City 6) → Emberford (City 7)** segment:

| Registration | Canonical source coordinate |
| --- | ---: |
| City 6 | `(360.2432, 520.0896)` |
| City 7 | `(427.1104, 640.6656)` |
| Segment midpoint | `(393.6768, 580.3776)` |
| Segment length | `137.8760 px` |
| Segment direction | `60.9888°` from +X |

Required map assets:

| Asset | Canvas / anchor | Contract |
| --- | --- | --- |
| `lk-map-secured-city` | 96×96 transparent, center | combined warm-light + small secured-banner treatment centered on an existing city anchor |
| `lk-map-caravan` | 128×64 transparent, center, faces +X | small decorative caravan; HPA-478 may rotate it along eligible existing routes |
| `lk-map-route-6-7-worn` | 192×192 transparent, center | pre-composed to the canonical 6→7 orientation, registered at the midpoint above |
| `lk-map-route-6-7-repaired` | 192×192 transparent, center | identical canvas/registration; changes bridge/road condition only |

All map decorations are noninteractive. They do not move anchors, alter route topology, add income/production, or cover city targets/Scout/Attack UI.

## Anime-fantasy generation brief

Use this shared direction for production prompts:

> Anime-inspired painted fantasy environment art for a mobile strategy game; clean readable silhouette, controlled shape language, restrained detail, stylized stone/fire/magical light, fixed camera, strong value separation, no characters, no UI, no text, transparent scene asset where requested. Preserve the exact supplied canvas, common ground baseline, horizontal gate center, camera, scale, and lighting direction across variants. Keep decoration subordinate to the existing Forged dark-iron/gold HUD and three gameplay lanes.

Family emphasis:

- **Frontier:** practical gray/brown stone and timber, muted banners.
- **Ember:** bridge/gate cues, oil braziers, orange ember light; no gameplay fire system.
- **Arcane:** cool cyan/blue ward motifs; no shield UI or second HP concept.
- **Royal:** refined stone/metal, royal banners, grander but still bounded silhouette.

## Corrected reference inventory

The final asset PR builds these 393×852 composition references from the production assets themselves:

### Destruction

- `references/battle-frontier-intact.png`
- `references/battle-frontier-damaged.png`
- `references/battle-frontier-breached.png`
- `references/battle-frontier-conquered.png`

### Landmark cities

- `references/battle-emberford.png`
- `references/battle-runewatch.png`
- `references/battle-crownspire.png`

### Living map

- `references/map-early.png`
- `references/map-partial.png`
- `references/map-complete.png`

### Offline return

- `references/offline-damage.png`
- `references/offline-conquest.png`

Reference frames retain real Forged chrome and truthful game state. Offline damage does not fabricate a reward/claim; offline conquest reuses the conquered fortress behind the existing pending conquest report.

## Production inventory and provenance rule

Every final asset export is documented in this README in the same commit that adds it. Each entry records:

1. exact asset name or frame range;
2. pixel dimensions;
3. alpha/opaque treatment;
4. measured nontransparent bounds;
5. anchor/baseline or canonical-map registration;
6. intended displayed size/use;
7. frame timing/loop behavior where applicable;
8. generator/tool and version when known;
9. prompt revision/reference-board source;
10. manual edit/compositing note.

The initial planning commit intentionally contains only the fixed contract above. The inventory grows with real production exports so it never claims measured metadata for files that do not yet exist.

## Asset-catalog convention

New runtime art lives in `Pyxis/Assets.xcassets/` as uniquely named `lk-*` `.imageset` directories. Follow the repository convention of one universal source PNG in the `1x` slot and unassigned `2x`/`3x` entries. SpriteKit sets the displayed size explicitly.

Do not replace any existing asset consumed by `main`, and do not edit `project.pbxproj`.

## Acceptance

Before this asset PR leaves Draft:

- all **38** `lk-*` image sets exist: 16 fortress + 3 battlefield + 15 FX + 4 map;
- all fortress families have four aligned stages;
- all required corrected references/contact sheets/animation previews exist;
- actual dimensions/alpha/bounds/registration/timing/provenance are recorded here;
- Emberford, Runewatch, and Crownspire are visually distinct at phone scale;
- map overlays align to existing anchors/routes and leave interaction surfaces readable;
- references contain no invented game mechanics or false offline rewards;
- Xcode builds the asset catalog successfully;
- the PR contains no Swift/runtime, persistence, balance, project-file, CI, or Codecov changes.

HPA-478 then consumes this fixed handoff. Image/animation authoring ends with HPA-479.