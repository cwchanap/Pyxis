# HPA-476 Anime Tactical Siege Asset Pack Design

## Status

Planning contract for **HPA-476**. This is the single image/animation-production PR for the tactical-siege initiative. It starts from `main` at `294a9645c579391510f246656685690fe1e3c01e`, where HPA-468, HPA-469, and HPA-475 are already merged. HPA-477 remains blocked until this pack ships.

The PR owns generated art, concise provenance/regeneration notes, asset-contract tests, real-game visual evidence, and the minimum presentation-only Swift needed to consume the Guard animation contract. It must not change combat, balance, save data, routing, economy, reports, or campaign rules.

## Goal

Replace the tactical-siege placeholders with one coherent anime-style pack that stays readable at actual mobile scale:

- Gate, Arrow Tower, and Barracks read clearly intact and ruined;
- the enemy Guard is immediately distinct from allied troops and animates through the already-shipped Guard behavior;
- the Vanguard Captain is visually recognizable in battle and in the compact Captain HUD segment;
- the selected assault lane and Rally protection remain clear without becoming screen-filling VFX;
- the same shared pack can be reused by HPA-477 across all 15 Country 1 layouts.

This is art/presentation work, not another gameplay-system slice.

## Reuse survey and selected shape

Reuse the existing owners instead of adding infrastructure:

1. **Structures:** `BattleScene.SiegeObjectiveAssetContract` already probes `siege-gate`, `siege-arrow-tower`, `siege-barracks`, and `siege-assault-flag`; `makeSiegeStructure` already chooses `-ruined` variants and falls back procedurally.
2. **Captain:** HPA-475 already probes `vanguard-captain-portrait`, `vanguard-captain-resting`, `vanguard-captain-{walk,attack,hit}-01...10`, and `rally-protection-accent`. Its existing all-or-nothing soldier animation path already accepts the `vanguard-captain` prefix.
3. **Animation slicing:** `tools/slice_soldier_animation_strips.py` already validates 5×2 storyboards, 10-frame walk/attack/hit trios, 128×128 output, transparent gutters, stable baseline/scale, and atomic installation. Its helper functions accept an arbitrary prefix even though the CLI intentionally lists only normal soldier types.
4. **Asset catalogs:** reuse `write_contents_json`; do not introduce another manifest, parser, generator format, or project-file edit.
5. **Visual proof:** reuse the existing DEBUG Forged/DevJump fixtures and tactical-siege fixture states before adding any new capture-only state.

The one real integration gap is the Guard: HPA-469 shipped a procedural Guard node and a stable `siege-guard` handoff, but it does not yet consume image animation frames. HPA-476 may add one narrow presentation seam in `BattleScene` so the existing Guard model/events drive static/walk/attack/hit art. Animation stays observational and must never control movement, attacks, damage, targeting, or persistence.

## Deliberate cuts

Do **not** add:

- a runtime asset manifest or registry;
- an actor-animation framework or new animation model;
- a VFX manager;
- per-city tactical art;
- a new Keep asset unless real in-game comparison proves the existing Keep/Living Kingdom art unusable;
- a Barracks spawn animation pack;
- a structure-collapse frame sequence;
- a dedicated Guard defeat sequence;
- alternate Captains, skins, equipment, portraits, or hero variants;
- new sound effects, music, or voice;
- new gameplay rules to justify an asset.

Existing procedural spawn, collapse, hit, retreat, and feedback treatment remains unless the required static/actor assets below make it redundant naturally.

## Final runtime inventory

Ship exactly **71 new image sets** unless the implementation review proves one of the optional static items is already present under the same name:

### Structures and lane marker — 7

- `siege-gate`
- `siege-gate-ruined`
- `siege-arrow-tower`
- `siege-arrow-tower-ruined`
- `siege-barracks`
- `siege-barracks-ruined`
- `siege-assault-flag`

### Enemy Guard — 31

- `siege-guard-resting`
- `siege-guard-walk-01...10`
- `siege-guard-attack-01...10`
- `siege-guard-hit-01...10`

### Vanguard Captain — 32

- `vanguard-captain-portrait`
- `vanguard-captain-resting`
- `vanguard-captain-walk-01...10`
- `vanguard-captain-attack-01...10`
- `vanguard-captain-hit-01...10`

### Rally — 1

- `rally-protection-accent`

No separate Keep cutout, Barracks spawn cue, tower projectile, or collapse animation is included in the starting inventory. Those already have a shipping presentation and are YAGNI for this ticket.

## Visual direction

Use one coherent **anime-inspired painted tactical-fantasy** style compatible with the existing Forged/Living Kingdom presentation:

- strong silhouettes first; small material detail second;
- transparent backgrounds for every asset in this pack;
- stable light direction and restrained warm fantasy palette;
- no text, counters, HP bars, lane labels, buttons, or baked UI;
- structures must remain readable behind existing HP/coverage overlays;
- actors must remain readable among current soldiers at roughly 28–42 pt visible height;
- decorative glow must not obscure objective HP, selected-lane treatment, Settings, tabs, Deploy, Rally, or Continue.

Enemy-versus-player recognition may use color as reinforcement but **must not rely on tint alone**.

## Structure contract

Keep the runtime bottom-center structure anchor. Source canvases match the shipping target aspect closely so `makeSiegeStructure` does not need new layout math:

| Asset family | Source canvas | Runtime meaning |
| --- | ---: | --- |
| Gate | 512×128 | wide blocker spanning its authored lane approaches |
| Arrow Tower | 320×576 | current `height = width × 1.8` target |
| Barracks | 320×480 | current `height = width × 1.5` target |
| Assault flag | 128×128 | selected-lane marker, bottom-center |

Rules:

- intact/ruined variants share an identical canvas and ground-contact line;
- ruined variants remain recognizable as the same structure and do not look active;
- the Gate keeps a clear central passage/blocker read at the rendered lane scale;
- the Tower keeps a readable firing silhouette without painting a projectile path into the texture;
- the Barracks reads as a reinforcement source when intact and disabled when ruined without requiring animated smoke;
- the assault flag stays compact and does not cover objective HP or soldiers.

Asset tests pin exact dimensions and non-empty alpha bounds. Real-game comparison is the authority for apparent scale; do not add runtime geometry types to compensate for poor source composition.

## Guard animation contract

The Guard uses the same compact source convention as soldiers and Captain:

- every frame is **128×128 RGBA**;
- feet/ground contact stays bottom-center within the slicer's transparent gutter;
- 10 walk + 10 attack + 10 hit frames;
- `siege-guard-resting` is the approved neutral walk pose copied from the accepted walk sequence rather than separately generated;
- the Guard faces toward the player's side of the battlefield and keeps its shield/weapon silhouette distinct from allied troops;
- walk/attack/hit use the existing `SoldierAnimationAction` frame-count/timing convention;
- defeat continues to use the existing procedural loss/fade treatment.

### Minimal Guard presentation seam

`BattleScene` may extend the existing Guard node bundle with only the data required to show the art, for example a sprite body plus the previous synced progress needed to choose resting versus walk. Reuse `soldierAnimationTextures(for:action:)` / existing animation timing with the `siege-guard` prefix rather than introducing a second loader.

Presentation mapping:

- Guard progress changed during sync -> walk visual;
- existing `guardAttacks` event -> attack visual;
- existing `guardHits` event -> hit visual;
- stationary and not reacting -> `siege-guard-resting`;
- missing/incomplete art -> existing procedural/static Guard remains understandable.

Model state and existing TickResult events remain authoritative. Sprite actions never gate or schedule combat.

## Captain and Rally contract

HPA-475's names and geometry are already fixed:

| Asset | Contract |
| --- | --- |
| `vanguard-captain-portrait` | 128×128 transparent square; readable in the compact Captain HUD segment |
| `vanguard-captain-resting` | 128×128 actor canvas, feet bottom-center |
| `vanguard-captain-walk-01...10` | 128×128, existing walk timing |
| `vanguard-captain-attack-01...10` | 128×128, existing attack timing |
| `vanguard-captain-hit-01...10` | 128×128, existing hit timing |
| `rally-protection-accent` | 128×128 transparent accent behind protected ordinary soldiers |

The Captain uses the allied battlefield direction and must read as a named companion rather than a recolored infantry unit. Keep one stable outfit/silhouette across portrait and animation.

`vanguard-captain-resting` should be derived from the approved neutral walk pose, not produced as a separate inconsistent generation.

Rally protection is a restrained halo/shield accent around the protected soldier's lower body. It must not look like a second HP bar, invulnerability bubble, area-of-effect radius, or new resource.

## Storyboard and slicing workflow

For Guard and Captain, author three 5×2 source storyboards per actor: `walk`, `attack`, `hit`. Use the existing slicer helper programmatically with actor prefixes `siege-guard` and `vanguard-captain` so its current CLI soldier allow-list remains unchanged.

The existing validation remains authoritative:

- 10 square cells per storyboard;
- 128×128 final frames;
- chroma-key gutter remains empty;
- transparent border after slicing;
- stable density, body height, baseline, and neutral-frame scale across the trio;
- no pixel-identical adjacent frames;
- trio installed atomically.

Do not weaken slicer thresholds to make generated art pass. Regenerate/correct the source art instead.

## Asset-catalog and project integration

- every new image is one `.imageset` under `Pyxis/Assets.xcassets`;
- use `write_contents_json` for static image sets and the existing slicer for actor frames;
- no `.atlas`, runtime manifest, asset database, or extra package;
- do not edit `project.pbxproj`; synchronized project groups already pick up source/test changes and asset catalog content is already included;
- existing non-HPA-476 production assets are untouched.

## Continuous validation

Replace the current placeholder-only HPA-476 test that asserts tactical assets are absent with a production contract test beside the existing animation asset tests.

The final CI contract must verify:

1. all 71 names resolve through `UIImage(named:)`;
2. structure/flag/portrait/resting/Rally dimensions match this spec;
3. all Guard/Captain animation frames are exactly 128×128;
4. Guard and Captain have complete 30-frame trios, never a partial installed action set;
5. structure intact/ruined pairs are non-empty and not pixel-identical;
6. static actor/resting and Rally assets have non-empty alpha content;
7. current normal-soldier animation tests remain unchanged and green.

Do not add a second Python validator or CI workflow. Swift asset tests plus the existing slicer are sufficient.

## Provenance and regeneration handoff

Add one tracked text handoff at:

`docs/art/tactical-siege/README.md`

Record only durable information:

- approved visual brief;
- final asset inventory and source canvases;
- exact prompt text/template per family/actor;
- image-generation tool/model name when known;
- seed/reference-image notes when the tool exposes them;
- storyboard chroma-key choice;
- slicer command/Python snippet;
- any manual crop/composite steps;
- final acceptance notes and known visual limitations.

Large storyboards/contact sheets/reference screenshots stay local or in ignored visual-parity space; do not bloat git history merely to preserve review boards.

## Real-game evidence

Approve the pack in the shipping UI, not on isolated transparent PNGs.

Reuse existing DEBUG fixtures first and capture at:

- the 393×852 reference class;
- one compact supported phone;
- portrait iPad.

Required states:

1. Falconridge Gate intact and ruined;
2. Falconridge Arrow Tower intact and ruined;
3. Highcrest Barracks spawning and shut down;
4. Guard moving/attacking/being hit beside allied soldiers;
5. Vanguard Captain deployed with portrait/HUD visible;
6. Rally active on ordinary soldiers;
7. final Keep conquest with tactical art still legible around the existing report/chrome;
8. reduced-motion/static state where animation cannot be relied on for meaning.

If an existing fixture cannot hold a state long enough to capture it, add the smallest DEBUG-only fixture adjustment on this same PR. Do not change production balance merely for screenshots.

## Allowed source changes

Expected tracked changes are limited to:

- `Pyxis/Assets.xcassets/siege-*.imageset/`;
- `Pyxis/Assets.xcassets/vanguard-captain-*.imageset/`;
- `Pyxis/Assets.xcassets/rally-protection-accent.imageset/`;
- `Pyxis/BattleScene.swift` — Guard art consumption only;
- `PyxisTests/BattleSceneTests.swift` — asset and Guard presentation contract;
- existing DEBUG fixture/test files only if required for reproducible capture;
- `docs/art/tactical-siege/README.md`;
- this spec and its implementation plan.

No gameplay-model, catalog tuning, persistence, route, reward, report, feedback-policy, CI, Codecov, or project-file change belongs here.

## Risks

1. **Art looks good in isolation but fails at 30–40 pt.** Mitigation: approve the first structure and first actor trio on real 393×852 gameplay before bulk generation.
2. **Guard integration grows into an animation subsystem.** Mitigation: reuse existing textures/timing and existing Guard events; one local BattleScene seam only.
3. **Generated actor frames drift in scale/baseline.** Mitigation: the existing trio slicer rejects density, baseline, gutter, and neutral-scale drift; do not weaken it.
4. **Structure art fights existing overlays.** Mitigation: keep transparent canvases and validate with objective HP, tower coverage, flags, Guards, and chrome present.
5. **Asset volume increases memory unnecessarily.** Mitigation: actors stay 128×128; structures use only the three fixed canvases above; no speculative FX sequences.

## Done definition

HPA-476 is ready only when:

- all 71 image sets are installed under the fixed names;
- Guard and Captain complete trios pass existing slicing/CI validation;
- the narrow Guard presentation seam uses art without changing model behavior;
- intact/ruined structures, flag, portrait, actors, and Rally accent are visually accepted in real gameplay at reference/compact/iPad sizes;
- reduced-motion/static presentation remains understandable;
- provenance/regeneration notes are complete;
- full unit/UI/build/lint/coverage gates pass without weakening them;
- the diff contains no gameplay, economy, save, routing, report, or HPA-477 per-city art scope;
- HPA-477 can reuse the exact shared pack without requesting new city-specific assets.