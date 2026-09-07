# Living Kingdom Anime Asset Pack Design

## Status

Approved planning contract for **HPA-479**. This draft PR is the single asset PR for the ticket: planning and handoff documentation land first, then the image/animation agent adds production assets to the same branch and PR.

Runtime playback and gameplay integration belong to **HPA-478** and its separate single PR. HPA-479 must not add Swift runtime behavior.

## Goal

Make Pyxis's existing Country 1 campaign feel more alive and memorable through presentation only:

1. visible fortress damage during a siege;
2. stronger identity for a few landmark cities;
3. a conquered map that looks secured and inhabited;
4. an offline return that reveals the real resulting battlefield state without inventing rewards or replaying a battle.

The art must fit the shipping Forged UI and current SpriteKit geometry rather than turning the concept boards into a new game design.

## Decision summary

Use a compact reusable art system rather than bespoke content for all 15 cities:

- **4 fortress families** — frontier, ember, arcane, royal;
- **4 static stages per family** — intact, damaged, breached, conquered;
- **3 transparent battlefield treatment overlays** — ember, arcane, royal; the existing battlefield remains the frontier treatment;
- **2 short shared one-shot FX sequences** — breach and final collapse;
- **3 small ambient textures** — smoke, embers, ward glow;
- **4 map overlays** — secured-city treatment, caravan, worn bridge/road patch, repaired patch;
- **no separate offline-return illustration set** — offline presentation reuses the same damage/conquered assets plus the existing report/feedback UI.

This is intentionally smaller than fifteen bespoke city environments and richer than recoloring the current city sprite. It keeps runtime mapping static and cheap while giving Cities 7, 9, and 15 a strong visual identity.

## Alternatives considered

### A. Fifteen bespoke city sets

Highest variety, but it multiplies authoring, review, file size, and future maintenance while providing no new gameplay value. Rejected for HPA-479.

### B. Four reusable families plus three landmark overlays — selected

Enough variety to make the route feel authored, while every city still fits the same battle geometry and the runtime only needs a small static city-to-family mapping. This is the best balance for a hobby project.

### C. Keep one city sprite and add color grading only

Cheapest, but it does not make siege destruction or the three landmark cities visually legible enough. Rejected because it misses the approved visual direction.

## Authoritative inputs

### Shipping game contract

`main` at planning time is `41aeb806f8c4b6cdad6dede5855f90ad5a3614cd`, after the Forged UI work.

The following remain authoritative over any concept art:

- `Country1CityCatalog` for city names and identity;
- `BattlefieldLayout` and `BattleScene` for city/gate/lane geometry;
- `CountryMapLayoutDefinition.country1` and `CountryMapLayout` for map coordinates;
- `KingdomGameState`, `BattleResult`, and `IdleProgressResult` for progression and outcomes;
- `docs/visual-parity/forged-ui/` for the existing 393×852 visual composition and chrome.

No mock value becomes game data.

### Concept references

The original four boards remain mood/composition references:

1. Siege Destruction
2. Landmark Cities
3. Living Kingdom Map
4. Offline Return Reveal

The source package is named `Pyxis_Living_Kingdom_Concept_References.zip` in the planning conversation. The exact source boards must be available to the image/animation agent before bulk production begins; do not substitute unrelated images.

The written game contract in this spec and HPA-479 overrides invented cities, currencies, counters, objectives, or other mechanics shown in those boards.

### Visual direction: anime fantasy

Use an **anime-inspired painted fantasy environment style** rather than photorealism or western dark-fantasy concept art:

- clean, readable silhouettes and deliberate shape language;
- stylized painted stone, fire, magical light, banners, and atmosphere;
- restrained line/detail density at phone scale;
- cinematic color separation without turning the screen into a poster illustration;
- no character redesign, chibi reinterpretation, or new troop art;
- no text, HUD, counters, buttons, phone frames, or interaction hints baked into scene textures.

The art should sit naturally below the existing dark-iron/gold Forged chrome. Foreground lanes, soldiers, HP feedback, Scout content, city targets, and tabs must remain easier to read than the decoration.

## Runtime geometry the art must respect

### Enemy fortress

`BattleScene` anchors image-backed battle structures at **bottom center** (`anchorPoint = (0.5, 0)`) and aspect-fits them by height.

On the regular Forged phone layout, the enemy city is rendered at **132 pt high**. Compact layouts derive the target from `BattlefieldLayout`; its structure cap is 144 pt and the enemy target is `structureHeight × 1.04`, so the art must remain clean at roughly **150 pt maximum displayed height**.

All 16 fortress sprites therefore use one common production envelope:

- canvas: **768×512 px**;
- transparent background;
- bottom-center runtime anchor;
- same ground baseline and city center across every family/stage;
- main gate centered on the horizontal midpoint and visually meeting the bottom baseline so the existing center-lane impact point still reads as the gate impact;
- no family may need a different SpriteKit anchor or a different battlefield layout;
- damage may change internal detail and rubble, but not move the whole silhouette, ground plane, or gate center.

Each exported image set records its measured nontransparent bounds in the handoff README. Bounds are measured from the final PNG rather than guessed in advance.

### Battlefield treatment overlays

The current `battlefield-backdrop` remains the frontier background. Ember, arcane, and royal identity comes from transparent overlays named below, layered over that same background.

Each treatment overlay must:

- use the **exact pixel canvas and aspect ratio of the current `battlefield-backdrop.png`**;
- remain transparent outside its treatment art;
- keep all three lane corridors readable;
- avoid painting a second enemy fortress into the background;
- keep important detail inside the reference phone's visible crop when the source is aspect-filled;
- contain no gameplay-significant objects that could be mistaken for additional towers, shields, attacks, or resources.

Matching the existing backdrop canvas avoids a second camera/transform contract.

### Country map

Country 1 uses a canonical **1024×1536** authored map with 15 city anchors and 14 primary sequential route segments. Living-map art must overlay this coordinate system; it must not repaint or move the route.

The selected repair story is the existing **City 6 Granite Pass → City 7 Emberford** segment because Emberford is already authored as the burning-oil bridge crossing.

Canonical registration:

- City 6: `(360.2432, 520.0896)`
- City 7: `(427.1104, 640.6656)`
- segment midpoint: `(393.6768, 580.3776)`
- segment length: `137.8760 px`
- segment direction: `60.9888°` from +X in the authored map coordinate system

The worn/repaired patch is pre-composed in that orientation on a **192×192 transparent canvas** centered on the segment midpoint. HPA-478 only needs to transform that canonical midpoint with the same map transform used by the route; it does not need a generic overlay manifest or a second route model.

Map decorations are always noninteractive and must not enlarge or cover the existing 44×44 city hit targets.

## Fortress families

### Frontier

Used by every Country 1 city not mapped below. Gray/brown stone, timber, muted flags, practical frontier construction. This is the baseline family and should be authored first.

### Ember

Used by **City 7 Emberford** and **City 12 Ashbridge**. Warm orange light, bridge/gate cues, oil braziers and restrained ember atmosphere. Fire is visual identity only; it must not look like a new damage system.

### Arcane

Used by **City 9 Runewatch** and **City 13 Starveil Citadel**. Cool cyan/blue ward motifs and magical highlights. Wards must read as atmosphere/identity, not as a second HP shield or interactable barrier.

### Royal

Used by **City 15 Crownspire Keep** only. Stronger vertical silhouette, royal banners and refined stone/metal accents. It may feel grander but must still fit the same 768×512 canvas and the same runtime anchor/height budget.

## Destruction stages

The runtime integration ticket uses these exact appearance boundaries:

| Remaining city HP | Static asset stage |
| --- | --- |
| `> 60%` | intact |
| `> 25% ... 60%` | damaged |
| `> 0% ... 25%` | breached |
| `0%` / pending conquest | conquered |

Art semantics:

- **intact:** fully readable family silhouette;
- **damaged:** cracks/chipped masonry/local smoke, without opening the gate;
- **breached:** visibly broken gate and rubble, but still the same fortress footprint;
- **conquered:** a stable ruined/secured aftermath, not an empty battlefield and not a different camera shot.

A large hit may skip stages at runtime, so every static stage must make sense when shown directly with no preceding animation.

## Asset naming contract

### Fortress image sets — 16

`lk-city-{family}-{stage}` where:

- family: `frontier`, `ember`, `arcane`, `royal`
- stage: `intact`, `damaged`, `breached`, `conquered`

Examples:

- `lk-city-frontier-intact`
- `lk-city-ember-breached`
- `lk-city-royal-conquered`

### Battlefield treatment image sets — 3

- `lk-battlefield-ember`
- `lk-battlefield-arcane`
- `lk-battlefield-royal`

### Shared one-shot FX image sets — 12 frames

Breach dust/debris, 6 frames:

- `lk-fx-breach-01` ... `lk-fx-breach-06`
- transparent **512×512 px** frames
- one shot, **0.30 s total** (`0.05 s/frame`)
- final frame fades to transparent; the static breached fortress owns the terminal appearance

Final collapse, 6 frames:

- `lk-fx-collapse-01` ... `lk-fx-collapse-06`
- transparent **512×512 px** frames
- one shot, **0.42 s total** (`0.07 s/frame`)
- final frame fades to transparent; the static conquered fortress owns the terminal appearance

Both sequences share one bottom-center impact convention and must remain usable across all four fortress families.

### Ambient textures — 3

- `lk-fx-smoke-soft` — 256×256 transparent
- `lk-fx-ember-specks` — 256×256 transparent
- `lk-fx-ward-glow` — 512×512 transparent

These are simple reusable fade/drift textures, not authored videos or a VFX framework.

### Living-map image sets — 4

- `lk-map-secured-city` — 96×96 transparent; combined warm-light/banner treatment centered on an existing city anchor
- `lk-map-caravan` — 128×64 transparent; center anchor, visually faces +X so HPA-478 can rotate it along a route
- `lk-map-route-6-7-worn` — 192×192 transparent; pre-registered to the selected canonical segment
- `lk-map-route-6-7-repaired` — 192×192 transparent; same canvas/registration as the worn state

No additional map geography, settlement simulation, production marker, collectable icon, or management affordance is added.

## Asset-catalog convention

New runtime art lives under `Pyxis/Assets.xcassets/` and uses unique new image-set names. Do not replace `enemy-city`, `battlefield-backdrop`, `country-map-backdrop`, `conquered-marker`, soldier art, or any other asset already consumed by `main`.

Follow the repository's existing simple image-set convention: one universal source PNG in the `1x` slot with the `2x`/`3x` entries present but unassigned. SpriteKit controls displayed size explicitly, so no generated multi-resolution pipeline is needed for this ticket.

Do not edit `project.pbxproj`; the project uses synchronized groups.

## Handoff metadata

`docs/visual-parity/living-kingdom/README.md` is the single human-readable art-to-code contract. It is not parsed at runtime.

For each produced family/sequence/overlay, record:

- exact asset name(s);
- pixel dimensions;
- alpha/opaque treatment;
- measured nontransparent bounds;
- common anchor/baseline;
- gate/impact attachment convention where relevant;
- intended displayed size or canonical-map registration;
- sequence timing/loop behavior where relevant;
- source/generation provenance, including generator/tool, prompt revision, concept-reference board(s), and manual edits.

Metadata is written when the corresponding final export is added; no separate JSON manifest is introduced.

## Corrected 393×852 reference set

The asset PR must include game-composition references made from the same production assets, not separate poster art.

Required reference frames:

### Destruction

- frontier intact
- frontier damaged
- frontier breached
- frontier conquered

### Landmarks

- Emberford / City 7
- Runewatch / City 9
- Crownspire Keep / City 15

### Living map

- early campaign
- partially secured campaign, including the repaired 6→7 crossing when eligible
- Country 1 complete

### Offline return

- positive offline damage without conquest
- offline conquest with the existing pending conquest report over the conquered aftermath

All references use logical **393×852** composition and retain the Forged chrome. Runtime-derived values are represented truthfully; no wood, stone, gems, invented troop stock, claim button, fake elapsed time, or reward appears.

Store source frames/contact sheets and lightweight animation previews under `docs/visual-parity/living-kingdom/`. These files are review evidence, not a pixel-diff CI framework.

## Validation strategy

HPA-479 changes assets and documentation only, so validation stays simple:

1. inspect every PNG at actual phone-scale composition for lane/HUD/card clearance;
2. verify alpha, dimensions, stage alignment, shared baseline, and animation-frame registration;
3. verify the map patch against the canonical 1024×1536 map and selected 6→7 segment;
4. build the app so every new `.imageset/Contents.json` is accepted by the asset catalog;
5. confirm existing screens/gameplay remain unchanged because no runtime code references the new assets yet;
6. confirm the PR diff contains no Swift, persistence, balance, routing, project-file, or runtime-manifest changes.

Existing CI/Codecov gates stay intact; there is no reason to lower or exclude anything for an asset-only PR.

## Non-goals

HPA-479 does not include:

- Swift scene playback or stage-selection code;
- HP thresholds in persisted state;
- new city/troop/building mechanics;
- Rally, direct-lane deployment, Chronicle, Country 2, prestige, production chains, rebuild timers, collectibles, or extra currencies;
- 15 unique battle environments;
- soldier re-authoring;
- audio production;
- 3D, skeletal animation, a new renderer, a VFX manager, a runtime asset manifest/parser, or an asset-generation framework;
- a second UI redesign or a custom font.

## Done definition

HPA-479 is ready to merge only when the same draft PR contains the finalized handoff README, all production asset image sets, corrected 393×852 references/contact sheets/previews, and provenance; the app builds; visual review confirms the real game geometry and anime-fantasy direction; and the diff remains asset/documentation-only.

After merge, HPA-478 consumes this fixed naming/anchor/timing contract. Any later runtime mismatch is solved in HPA-478 unless the production asset itself violates this contract.