# Living Kingdom Anime Asset Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the HPA-479 Living Kingdom anime-fantasy fortress, battlefield-treatment, shared-FX, living-map, and corrected-reference asset pack without changing gameplay or runtime code.

**Architecture:** Keep art as a static, human-readable contract: four reusable fortress families share one canvas/anchor, three transparent landmark treatments reuse the current battlefield backdrop, two shared one-shot FX sequences cover live transitions, and four map overlays register to existing Country 1 coordinates. `docs/visual-parity/living-kingdom/README.md` is the handoff; there is no runtime manifest, generator framework, or Swift change in this PR.

**Tech Stack:** Xcode asset catalogs, PNG with alpha, existing SpriteKit layout conventions, image-generation/animation tooling, macOS `sips`/`shasum`, Xcode/iOS Simulator for build and visual checks.

**Spec:** `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md`

## Global Constraints

- This is **one asset-only PR for HPA-479**. Every task below is a commit/review checkpoint in the same branch and PR.
- Keep the PR Draft until all production assets, references, provenance, and final validation are complete.
- The visual style is anime-inspired painted fantasy environment art, compatible with the existing Forged UI; do not redesign characters/troops.
- Use the original `Pyxis_Living_Kingdom_Concept_References.zip` boards only as mood/composition references; the written game contract overrides invented mechanics shown there.
- Do not begin bulk generation until the exact four concept boards are available to the image/animation agent.
- Do not change Swift, gameplay rules, save data, routing, project files, fonts, current production assets, or `codecov.yml`.
- Do not edit `project.pbxproj`; synchronized groups discover asset-catalog additions.
- New runtime art lives only in uniquely named `lk-*` image sets under `Pyxis/Assets.xcassets/`.
- Fortress sprites are transparent 768×512 PNGs, bottom-center anchored by the runtime, with a shared ground baseline and horizontal gate center.
- The regular Forged phone renders the enemy city at 132 pt high; all fortress art must remain clean up to roughly 150 pt displayed height.
- Landmark battlefield treatments match the current `battlefield-backdrop.png` pixel canvas exactly and remain transparent overlays.
- Country 1 map registration uses the existing canonical 1024×1536 coordinate system; the repair patch is the City 6 → City 7 segment centered at `(393.6768, 580.3776)`.
- Corrected visual-reference composition is logical 393×852 and retains real Forged chrome and truthful game values.
- Offline return creates no second art set; it reuses the static damage/conquered assets plus existing UI.
- HPA-478 owns runtime selection/playback after this PR merges.

## File Map

### Create during this PR

- `docs/visual-parity/living-kingdom/README.md` — single human-readable art → code contract and provenance index.
- `docs/visual-parity/living-kingdom/source/` — normalized copies of the four approved concept boards.
- `docs/visual-parity/living-kingdom/references/` — corrected 393×852 game-composition keyframes.
- `docs/visual-parity/living-kingdom/contact-sheets/` — destruction, landmark, map, offline, and FX review sheets.
- `docs/visual-parity/living-kingdom/previews/` — lightweight breach/collapse animation previews.
- `Pyxis/Assets.xcassets/lk-city-*.imageset/` — 16 fortress image sets.
- `Pyxis/Assets.xcassets/lk-battlefield-*.imageset/` — 3 transparent battlefield treatment image sets.
- `Pyxis/Assets.xcassets/lk-fx-*.imageset/` — 12 one-shot animation frames plus 3 ambient textures.
- `Pyxis/Assets.xcassets/lk-map-*.imageset/` — 4 map overlay image sets.

### Must remain untouched by HPA-479

- `Pyxis/*.swift`
- `PyxisTests/`
- `PyxisUITests/`
- `Pyxis.xcodeproj/project.pbxproj`
- existing non-`lk-*` image sets
- `.github/` and `codecov.yml`

---

## Task 1: Finalize the source-reference and handoff contract

**Files:**
- Modify: `docs/visual-parity/living-kingdom/README.md`
- Create: `docs/visual-parity/living-kingdom/source/concept-siege-destruction.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-landmark-cities.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-living-map.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-offline-return.png`

**Produces:** The fixed source/reference inventory, exact current backdrop dimensions, naming/timing/anchor table, and route-6→7 registration that every later task consumes.

- [ ] **Step 1: Recover the exact concept package from the planning conversation.** Extract `Pyxis_Living_Kingdom_Concept_References.zip`; map its four boards by visual subject to the normalized repository names above without resampling or recompressing them.

- [ ] **Step 2: Record source hashes before editing anything.** Run:

```bash
shasum -a 256 \
  docs/visual-parity/living-kingdom/source/concept-siege-destruction.png \
  docs/visual-parity/living-kingdom/source/concept-landmark-cities.png \
  docs/visual-parity/living-kingdom/source/concept-living-map.png \
  docs/visual-parity/living-kingdom/source/concept-offline-return.png
```

Copy the four SHA-256 values into the README source-provenance section so reviewers can distinguish the untouched concept boards from corrected production references.

- [ ] **Step 3: Read the current runtime canvases locally.** Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pyxis/Assets.xcassets/battlefield-backdrop.imageset/battlefield-backdrop.png \
  Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png \
  Pyxis/Assets.xcassets/country-map-backdrop.imageset/country-map-backdrop.png
```

Record the exact `battlefield-backdrop` pixel width/height in the README and require all three `lk-battlefield-*` overlays to match it exactly. Keep the design's 768×512 fortress canvas and canonical 1024×1536 map contract unchanged.

- [ ] **Step 4: Review the four boards against the written exclusions.** Mark the concept boards as mood-only and explicitly reject any visible wood/stone/gems, invented city/level, claim button, giant stock counter, fortification-management objective, or >8-hour idle credit from becoming a production requirement.

- [ ] **Step 5: Lock the anime-fantasy prompt direction in the README.** The reusable prompt brief is: clean anime-fantasy environment painting, readable mobile silhouette, restrained detail, fixed camera, no characters/UI/text, same structure baseline/gate/canvas between damage stages, and colors subordinate to the Forged HUD.

- [ ] **Step 6: Verify the initial contract diff.** Run:

```bash
git diff --check
git diff --name-only main...HEAD
```

At this checkpoint every changed path must be under `docs/`; no asset generation or runtime file is required yet.

- [ ] **Step 7: Commit the finalized handoff inputs.** Run:

```bash
git add docs/visual-parity/living-kingdom
git commit -m "docs: finalize Living Kingdom art handoff"
```

**Checkpoint A:** Review the four source boards, anime direction, current backdrop dimensions, fixed names, timings, and map registration before bulk art production. Do not create another PR.

---

## Task 2: Author the frontier fortress vertical slice first

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-frontier-{intact,damaged,breached,conquered}.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/battle-frontier-{intact,damaged,breached,conquered}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/destruction-frontier.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Produces:** The approved canvas, scale, silhouette, baseline, gate, damage language, and export convention reused by every other fortress family.

- [ ] **Step 1: Generate only `lk-city-frontier-intact` first.** Use the locked anime-fantasy prompt and a 768×512 transparent canvas. Keep the gate centered, the visual ground touching the bottom baseline, and enough transparent side/top margin that a 132 pt tall render does not crowd the HP bar or lanes.

- [ ] **Step 2: Composite the intact export into the 393×852 Forged Battle composition.** Judge silhouette, city readability, center-gate alignment, lane clearance, and HUD clearance at logical phone scale. Reject and regenerate the intact export if any of these fail; do not compensate with runtime geometry.

- [ ] **Step 3: Derive damaged, breached, and conquered from the approved intact composition.** Preserve camera, canvas, baseline, gate center, lighting direction, major tower positions, and overall footprint. Damage changes are cumulative but each frame must also read correctly when shown directly after a skipped threshold.

- [ ] **Step 4: Create the four Xcode image sets using the repository's universal-1x convention.** Each `Contents.json` contains the source PNG in the universal `1x` entry and empty `2x`/`3x` entries, matching existing asset-catalog structure.

- [ ] **Step 5: Verify canvas and alpha mechanically.** Run:

```bash
for file in Pyxis/Assets.xcassets/lk-city-frontier-*.imageset/*.png; do
  echo "$file"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
done
```

Every file must report 768×512 and alpha.

- [ ] **Step 6: Measure final nontransparent bounds and record them.** Use the image tool/exporter used for authoring to read the final alpha bounding box of each PNG. Put the measured `(minX, minY, maxX, maxY)` values in the README. The four bounds may differ because of rubble, but the baseline and horizontal gate center must not.

- [ ] **Step 7: Build the asset catalog.** Run on an available simulator destination with parallel testing disabled if tests are invoked:

```bash
xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: BUILD SUCCEEDED with no asset-catalog warning for the new image sets.

- [ ] **Step 8: Commit the frontier vertical slice.** Run:

```bash
git add Pyxis/Assets.xcassets/lk-city-frontier-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom frontier destruction set"
```

**Checkpoint B:** Treat frontier as the quality gate. Do not scale generation to the other three families until this complete four-stage slice passes phone-scale visual review.

---

## Task 3: Add Emberford, Runewatch, and Crownspire family identity

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-ember-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-city-arcane-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-city-royal-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-battlefield-{ember,arcane,royal}.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/battle-emberford.png`
- Create: `docs/visual-parity/living-kingdom/references/battle-runewatch.png`
- Create: `docs/visual-parity/living-kingdom/references/battle-crownspire.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/landmarks.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** The Task 2 fortress canvas/baseline/gate convention and Task 1's measured `battlefield-backdrop` canvas.

**Produces:** All 16 fortress stages and the three fixed landmark environment treatments consumed by HPA-478's static city-theme mapping.

- [ ] **Step 1: Author the Ember family from the approved frontier envelope.** Preserve 768×512, bottom-center gate/baseline, and stage alignment. Add bridge/gate cues, oil braziers, warm ember light, and restrained fire language suitable for City 7 Emberford and City 12 Ashbridge.

- [ ] **Step 2: Author the Arcane family from the same envelope.** Preserve geometry; use cool cyan/blue ward motifs and magical light without drawing a shield meter, barrier UI, or second HP concept.

- [ ] **Step 3: Author the Royal family from the same envelope.** Make Crownspire Keep grander through tower/banners/material quality while remaining inside 768×512 and the same 132–150 pt runtime height budget.

- [ ] **Step 4: Author the three transparent battlefield treatment overlays.** Each overlay has the exact pixel dimensions measured from `battlefield-backdrop.png`, paints no second fortress, leaves the three lane corridors readable, and keeps primary visual accents inside the reference-phone visible crop.

- [ ] **Step 5: Create all 15 new image sets with universal-1x `Contents.json` files.** This task adds 12 fortress image sets and 3 treatment image sets; do not add a runtime catalog or metadata JSON.

- [ ] **Step 6: Compose the three landmark references using real city identity.** Use City 7 **Emberford**, City 9 **Runewatch**, and City 15 **Crownspire Keep**. Keep Forged chrome and real lane/UI geometry; do not add invented objectives or resources.

- [ ] **Step 7: Run dimension/alpha checks.** Run:

```bash
for file in \
  Pyxis/Assets.xcassets/lk-city-ember-*.imageset/*.png \
  Pyxis/Assets.xcassets/lk-city-arcane-*.imageset/*.png \
  Pyxis/Assets.xcassets/lk-city-royal-*.imageset/*.png \
  Pyxis/Assets.xcassets/lk-battlefield-*.imageset/*.png; do
  echo "$file"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
done
```

Every fortress is 768×512 with alpha. Every treatment has alpha and exactly matches the measured frontier backdrop canvas.

- [ ] **Step 8: Update measured bounds/provenance and build.** Record every family's actual alpha bounds and generator/prompt/manual-edit provenance in the README, then run the same `xcodebuild ... build` command from Task 2.

- [ ] **Step 9: Commit the landmark families.** Run:

```bash
git add Pyxis/Assets.xcassets/lk-city-ember-*.imageset \
  Pyxis/Assets.xcassets/lk-city-arcane-*.imageset \
  Pyxis/Assets.xcassets/lk-city-royal-*.imageset \
  Pyxis/Assets.xcassets/lk-battlefield-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom landmark city families"
```

**Checkpoint C:** At phone scale, Emberford, Runewatch, and Crownspire must read as distinct identities without obscuring lanes or implying new mechanics.

---

## Task 4: Add the two shared transition effects and ambient textures

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-fx-breach-{01...06}.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-fx-collapse-{01...06}.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-fx-{smoke-soft,ember-specks,ward-glow}.imageset/`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/fx-breach.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/fx-collapse.png`
- Create: `docs/visual-parity/living-kingdom/previews/breach.gif`
- Create: `docs/visual-parity/living-kingdom/previews/collapse.gif`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Produces:** Small shared effects that HPA-478 can play only for newly observed live transitions; static city sprites remain authoritative on reconstruction.

- [ ] **Step 1: Author the six-frame breach sequence.** Use a fixed 512×512 transparent canvas and one shared bottom-center impact convention. The sequence is dust/chips/debris only, lasts 0.30 s at 0.05 s/frame, and fades away rather than leaving persistent ruin pixels.

- [ ] **Step 2: Author the six-frame collapse sequence.** Use the same 512×512 registration, last 0.42 s at 0.07 s/frame, and fade away. Do not animate an alternate fortress silhouette that would conflict with the static conquered asset.

- [ ] **Step 3: Author the three ambient textures.** Keep smoke and ember-specks at 256×256 transparent; keep ward-glow at 512×512 transparent. They must work through simple SpriteKit drift/fade/pulse rather than requiring an authored video or shader framework.

- [ ] **Step 4: Create one universal-1x image set per frame/texture.** Preserve zero-padded frame names exactly as declared by the spec.

- [ ] **Step 5: Make contact sheets and lightweight GIF previews from the exact production frames.** The preview order and timing must match the README; do not create a second set of preview-only animation frames.

- [ ] **Step 6: Verify all effect dimensions and alpha.** Run:

```bash
for file in Pyxis/Assets.xcassets/lk-fx-*.imageset/*.png; do
  echo "$file"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
done
```

Breach/collapse frames must be 512×512 with alpha; ambient dimensions must match the spec.

- [ ] **Step 7: Record timing, registration, bounds, and provenance in the README; then build.** Run the same asset-catalog build command from Task 2.

- [ ] **Step 8: Commit the shared effects.** Run:

```bash
git add Pyxis/Assets.xcassets/lk-fx-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom shared transition effects"
```

---

## Task 5: Add the living-map overlays on the existing route

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-map-secured-city.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-map-caravan.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-map-route-6-7-worn.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-map-route-6-7-repaired.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/map-early.png`
- Create: `docs/visual-parity/living-kingdom/references/map-partial.png`
- Create: `docs/visual-parity/living-kingdom/references/map-complete.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/map-progression.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** Canonical 1024×1536 map coordinates and the fixed route-6→7 registration from Task 1.

**Produces:** Noninteractive state-derived decoration only; no new route, city anchor, economy, rebuild timer, or inspection surface.

- [ ] **Step 1: Author `lk-map-secured-city`.** Use a 96×96 transparent canvas centered on an existing city anchor. Combine warm light and a small secured banner into one treatment so HPA-478 needs one decoration node per completed city rather than separate light/banner systems.

- [ ] **Step 2: Author `lk-map-caravan`.** Use a 128×64 transparent canvas, center anchor, facing +X. Keep it readable around 20 pt high and visually quiet enough that it cannot be confused with a city or touch target.

- [ ] **Step 3: Author worn/repaired variants for the 6→7 crossing.** Both use the exact same 192×192 transparent canvas, are pre-composed to the canonical segment orientation, and register their center to `(393.6768, 580.3776)`. The repaired version changes only the bridge/road condition; it does not paint a new route or settlement.

- [ ] **Step 4: Create the four universal-1x image sets and record exact bounds/registration/provenance.** HPA-478 should need only static asset names plus the existing map transform.

- [ ] **Step 5: Compose early, partial, and complete 393×852 references.** Early shows little/no secured decoration; partial shows completed-city treatments and the repaired 6→7 crossing only when both endpoints are complete; complete shows a fully secured route without turning the map into a management dashboard.

- [ ] **Step 6: Check city-target and Scout-card clearance visually.** Decorations may overlap scenery but must not cover city labels/targets or the Scout/Attack information surface in the reference phone composition.

- [ ] **Step 7: Verify dimensions/alpha and build.** Run:

```bash
for file in Pyxis/Assets.xcassets/lk-map-*.imageset/*.png; do
  echo "$file"
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
done

xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

- [ ] **Step 8: Commit the living-map pack.** Run:

```bash
git add Pyxis/Assets.xcassets/lk-map-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom map overlays"
```

**Checkpoint D:** Review the map at early/partial/complete progress and confirm every decoration is presentation-only and aligned to existing geometry.

---

## Task 6: Complete offline-return references and final asset acceptance

**Files:**
- Create: `docs/visual-parity/living-kingdom/references/offline-damage.png`
- Create: `docs/visual-parity/living-kingdom/references/offline-conquest.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/offline-return.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** All production assets from Tasks 2–5 and the existing Forged feedback/conquest presentation.

**Produces:** The complete fixed art contract ready for HPA-478 runtime integration.

- [ ] **Step 1: Compose the positive-damage/no-conquest reference.** Show the fortress at the truthful resulting intact/damaged/breached stage and a compact existing-style transient summary using actual damage and credited elapsed time. Do not show a claim action or gold if the model does not award gold.

- [ ] **Step 2: Compose the offline-conquest reference.** Show the conquered fortress aftermath behind the existing pending Conquest report with exactly one Continue action. Do not add a second reward burst, settlement button, or invented replay timeline.

- [ ] **Step 3: Build the final four concept contact sheets.** Present destruction progression, three landmarks, map progression, and offline return using the exact production assets and normalized source boards for side-by-side human review.

- [ ] **Step 4: Complete README inventory/provenance.** Every runtime asset name must have dimensions, alpha treatment, measured bounds, anchor/registration, timing when applicable, intended display use, generator/tool, prompt revision, concept-board source, and manual-edit note. Remove no source references and add no runtime parser.

- [ ] **Step 5: Verify the asset inventory is complete.** Run:

```bash
find Pyxis/Assets.xcassets -maxdepth 1 -type d -name 'lk-*.imageset' -print | sort
```

Expected inventory:

- 16 `lk-city-*` image sets;
- 3 `lk-battlefield-*` image sets;
- 15 `lk-fx-*` image sets (12 animation frames + 3 ambient textures);
- 4 `lk-map-*` image sets;
- **38 `lk-*` image sets total**.

- [ ] **Step 6: Verify the PR stayed asset/documentation-only.** Run:

```bash
git diff --name-only main...HEAD
```

Every path must be under either `Pyxis/Assets.xcassets/lk-*.imageset/`, `docs/visual-parity/living-kingdom/`, `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md`, or `docs/superpowers/plans/2026-09-07-living-kingdom-art-pack-implementation.md`. Any Swift, test, project, CI, or existing asset change fails this gate.

- [ ] **Step 7: Run final build and repository hygiene checks.** Run:

```bash
git diff --check

xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: no diff errors and BUILD SUCCEEDED. Existing CI/Codecov configuration remains unchanged.

- [ ] **Step 8: Final human visual review at logical 393×852.** Confirm: all four destruction stages read immediately; Emberford/Runewatch/Crownspire are distinct; lanes/HUD/Scout/targets remain clear; early/partial/complete map progression is coherent; offline damage and conquest are truthful; and the anime-fantasy direction is consistent across the pack.

- [ ] **Step 9: Commit final reference/provenance updates.** Run:

```bash
git add docs/visual-parity/living-kingdom
git commit -m "docs: finalize Living Kingdom visual handoff"
```

- [ ] **Step 10: Mark the existing HPA-479 PR ready only after this gate passes.** Do not open another PR. HPA-478 begins runtime consumption from the merged fixed contract.
