# HPA-476 Anime Tactical Siege Asset Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the shared HPA-476 anime tactical-siege art pack, wire the already-shipped Guard behavior to its final animation assets, and prove the result in real gameplay without changing combat or campaign semantics.

**Architecture:** Reuse the existing Xcode asset catalog, tactical structure probes, 128×128 soldier/Captain animation convention, storyboard slicer, and DEBUG capture fixtures. Static structures replace procedural fallbacks by name; Captain art drops into an already-existing consumer; Guard gets one local `BattleScene` presentation seam that maps existing model progress/events to resting/walk/attack/hit textures. No runtime manifest, generic actor framework, or new gameplay owner is added.

**Tech Stack:** Swift 5, SpriteKit/UIKit, Xcode asset catalogs, Swift Testing, XCTest UI tests, PNG/RGBA, existing `tools/slice_soldier_animation_strips.py`, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-10-15-tactical-siege-art-pack-design.md`

## Global Constraints

- One HPA-476 PR from planning through final assets/evidence. Do not split structure, Guard, Captain, or QA into separate PRs.
- Baseline: `main` at `294a9645c579391510f246656685690fe1e3c01e`.
- Final starting inventory: **71 new image sets** = 7 structures/flag + 31 Guard + 32 Captain + 1 Rally accent.
- Structure canvases: Gate 512×128; Arrow Tower 320×576; Barracks 320×480; assault flag 128×128.
- Guard/Captain animation frames and static actor assets are 128×128.
- Reuse 10-frame `walk`, `attack`, `hit` actions and the existing storyboard validation/timing convention.
- Reuse `write_contents_json`; do not add an asset manifest/parser/database.
- Reuse existing procedural Barracks spawn, collapse, Guard defeat, Captain retreat, projectile, sound, and haptic treatment.
- `BattleScene.swift` may change only for Guard visual consumption; model/timing/damage decisions remain untouched.
- No gameplay-model, save, economy, reward, report, route, HPA-477 content, CI, Codecov, or `project.pbxproj` change.
- Run tests with `-parallel-testing-enabled NO`.
- Keep the PR Draft until the full pack, visual evidence, and final gates are complete.

## Review Focus

1. **Partial Guard/Captain animation install:** CI must fail if any one of the 30 frames in either actor trio is missing; Task 2/3 add complete-inventory tests.
2. **Guard presentation affecting combat:** Task 2 pins that swapping between resting/walk/attack/hit art leaves model progress, HP, attack/loss events, and Guard counts unchanged.
3. **Structure state ambiguity:** Task 1 pins exact canvases and non-identical intact/ruined pairs; Task 4 visually proves both states with HP/coverage overlays present.
4. **Compact HUD/actor collisions:** Task 4 captures compact phone + portrait iPad with Captain portrait/Rally, Settings/tabs/Deploy, objective HP, and lane marker visible together.
5. **Reduced Motion depending on animation for meaning:** Task 4 captures a reduced-motion/static state and confirms ruined/disabled/selected/protected meanings remain readable from static treatment.

## File Map

### Planning / tracked handoff

- `docs/superpowers/specs/2026-10-15-tactical-siege-art-pack-design.md` — fixed design contract.
- `docs/superpowers/plans/2026-10-15-tactical-siege-art-pack-implementation.md` — this plan.
- `docs/art/tactical-siege/README.md` — prompts, source settings, slicing/regeneration, inventory, final acceptance notes.

### Production assets

- `Pyxis/Assets.xcassets/siege-{gate,gate-ruined,arrow-tower,arrow-tower-ruined,barracks,barracks-ruined,assault-flag}.imageset/`
- `Pyxis/Assets.xcassets/siege-guard-resting.imageset/`
- `Pyxis/Assets.xcassets/siege-guard-{walk,attack,hit}-{01...10}.imageset/`
- `Pyxis/Assets.xcassets/vanguard-captain-{portrait,resting}.imageset/`
- `Pyxis/Assets.xcassets/vanguard-captain-{walk,attack,hit}-{01...10}.imageset/`
- `Pyxis/Assets.xcassets/rally-protection-accent.imageset/`

### Runtime/test support

- `Pyxis/BattleScene.swift` — Guard final-art consumption only.
- `PyxisTests/BattleSceneTests.swift` — installed asset contract + Guard presentation regression coverage.
- Existing `Pyxis/ForgedVisualFixture.swift`, `PyxisTests/ForgedVisualFixtureTests.swift`, `PyxisUITests/PyxisUITests.swift` — modify only if current tactical fixtures cannot reproduce one required capture state.

---

## Task 1: Land the static tactical structure contract first

**Files:**
- Create: seven `Pyxis/Assets.xcassets/siege-*.imageset/` static sets listed in File Map.
- Modify: `PyxisTests/BattleSceneTests.swift`
- Create: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: `BattleScene.SiegeObjectiveAssetContract`, existing `makeSiegeStructure` `-ruined` lookup, `write_contents_json(imageset:filename:)`.
- Produces: final structure/flag images under the already-shipped names; a reusable Swift asset-contract table extended by later tasks.

- [ ] **Step 1: Replace the placeholder-absence test with a failing production asset test.**

Rename the current `siegeObjectiveAssetContractPinsSemanticNames` intent to production ownership and keep the semantic-name assertions. Add exact presence/dimension checks:

```text
siege-gate                  512×128
siege-gate-ruined           512×128
siege-arrow-tower           320×576
siege-arrow-tower-ruined    320×576
siege-barracks              320×480
siege-barracks-ruined       320×480
siege-assault-flag          128×128
```

For each intact/ruined pair assert both images have non-empty alpha bounds and `pngData()` differs. Remove only the old `UIImage(named:) == nil` assertions.

- [ ] **Step 2: Run the focused test and verify RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/siegeObjectiveAssetContractPinsProductionAssets
```

Expected: FAIL because the seven production images are not installed yet.

- [ ] **Step 3: Author one structure family at a time against real runtime scale.**

Start with `siege-arrow-tower` + `-ruined`; composite/capture on Falconridge at 393×852 before generating the Gate/Barracks. Reject the first pair if the tower loses silhouette at runtime, overlaps objective HP, or looks active when ruined. Keep the same camera/light/ground line across each pair.

- [ ] **Step 4: Author Gate, Barracks, and assault flag from the approved style.**

Do not create alternate city skins or extra effects. The flag is selected-lane decoration only.

- [ ] **Step 5: Install the seven image sets with the existing catalog writer.**

Use a short Python snippet importing `write_contents_json` from `tools/slice_soldier_animation_strips.py`; do not hand-maintain a second `Contents.json` shape.

- [ ] **Step 6: Create `docs/art/tactical-siege/README.md`.**

Record the shared style prompt/template, exact static canvases, generation tool/model/seed/reference notes when available, and final file names. Leave actor details as sections to be filled by Tasks 2/3 rather than creating another handoff file.

- [ ] **Step 7: Run focused tests and a simulator build.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: PASS; no shipping Swift change is needed for structures.

- [ ] **Step 8: Commit.**

```bash
git add Pyxis/Assets.xcassets/siege-*.imageset \
  PyxisTests/BattleSceneTests.swift docs/art/tactical-siege/README.md
git commit -m "art: add tactical siege structures"
```

---

## Task 2: Add the Guard trio through one local BattleScene presentation seam

**Files:**
- Create: `Pyxis/Assets.xcassets/siege-guard-resting.imageset/`
- Create: `Pyxis/Assets.xcassets/siege-guard-{walk,attack,hit}-{01...10}.imageset/`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: existing `BattleCombatState.Guard` snapshots/events, `guardNodes`, `GuardAnimationKey`, `soldierAnimationTextures(for:action:)`, existing `SoldierAnimationAction` timing, `slice_soldier_storyboards` helper.
- Produces: final `siege-guard` 30-frame trio + resting asset; Guard nodes that choose presentation from existing progress/attack/hit events without owning gameplay.

- [ ] **Step 1: Write failing Guard asset-completeness tests.**

Add `allGuardAnimationFramesAreInstalled` beside the normal soldier asset test. Assert:

- `siege-guard-resting` resolves at 128×128;
- every `siege-guard-{walk,attack,hit}-{01...10}` resolves at 128×128;
- exactly 30 action frames are expected.

Run only this test and confirm RED on missing assets.

- [ ] **Step 2: Write Guard presentation regression tests before runtime changes.**

Add focused tests using the existing Highcrest fixture seams:

- moving Guard selects/plays walk art when a complete trio is installed;
- a `guardAttacks` event selects attack art;
- a `guardHits` event selects hit art;
- stationary/no-reaction Guard settles to resting art;
- the same tick/state before and after presentation sync has identical Guard HP/progress/count and identical combat events.

Do not test SpriteKit animation timing as combat timing; assert node/texture/action-key presentation only.

- [ ] **Step 3: Run the new presentation tests and verify RED.**

Expected: the procedural Guard has no final-art sprite/trio selection path yet.

- [ ] **Step 4: Author three Guard 5×2 storyboards.**

Create `walk`, `attack`, `hit` in one consistent enemy-facing anime Guard design. Use the default chroma key accepted by the existing slicer. Keep feet/baseline and apparent body scale stable across all three boards.

- [ ] **Step 5: Slice/install the Guard trio with the existing helper, not a new CLI mode.**

Invoke `slice_soldier_storyboards(images, assets_dir, "siege-guard", 128)` from a short Python script. Do not widen the CLI `SOLDIERS` allow-list just for this task. Copy the approved neutral walk pose to `siege-guard-resting` and write its catalog JSON with `write_contents_json`.

- [ ] **Step 6: Add the minimal Guard presentation seam in `BattleScene.swift`.**

Keep the existing `GuardNodeBundle`; extend it only as needed for a sprite body and last synced progress. Reuse the existing animation texture loader/timing with prefix `siege-guard`.

Required mapping:

```text
progress changed -> walk
GuardAttackEvent -> attack
GuardHitEvent -> hit
otherwise -> resting
loss -> existing procedural loss/fade
```

If final art lookup fails, retain the current procedural Guard visual. Do not create a Guard animator type, actor protocol, event bus, or new model field.

- [ ] **Step 7: Run Highcrest/Guard-focused tests.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: asset completeness + presentation tests GREEN; existing Highcrest combat/persistence assertions unchanged.

- [ ] **Step 8: Append Guard prompts/slicing instructions to the tracked handoff and commit.**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift \
  Pyxis/Assets.xcassets/siege-guard-*.imageset docs/art/tactical-siege/README.md
git commit -m "art: add animated siege Guard"
```

---

## Task 3: Add Captain portrait/animation and Rally accent with no new runtime architecture

**Files:**
- Create: `Pyxis/Assets.xcassets/vanguard-captain-portrait.imageset/`
- Create: `Pyxis/Assets.xcassets/vanguard-captain-resting.imageset/`
- Create: `Pyxis/Assets.xcassets/vanguard-captain-{walk,attack,hit}-{01...10}.imageset/`
- Create: `Pyxis/Assets.xcassets/rally-protection-accent.imageset/`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: HPA-475's existing `vanguard-captain` prefix path, `vanguard-captain-portrait` HUD lookup, `rally-protection-accent` lookup, `slice_soldier_storyboards` helper.
- Produces: complete final Captain trio/portrait/resting + Rally accent without changing production Swift behavior.

- [ ] **Step 1: Add failing Captain/Rally inventory tests.**

Assert:

- portrait/resting/Rally resolve at 128×128;
- all 30 `vanguard-captain-{walk,attack,hit}` frames resolve at 128×128;
- Captain trio is complete, never partially installed.

Keep the normal-soldier asset test unchanged.

- [ ] **Step 2: Run the focused inventory test and verify RED.**

Expected: HPA-475 currently falls back because final generated assets are absent.

- [ ] **Step 3: Author one Captain identity source before action boards.**

Lock one original outfit, hair/helmet silhouette, weapon, allied-facing direction, and palette. Produce the 128×128 HUD portrait from the same approved character identity; do not create alternate skins or equipment.

- [ ] **Step 4: Author and slice Captain walk/attack/hit storyboards.**

Use `slice_soldier_storyboards(images, assets_dir, "vanguard-captain", 128)`. Copy the approved neutral walk pose to `vanguard-captain-resting`; do not separately generate a conflicting resting pose.

- [ ] **Step 5: Author `rally-protection-accent`.**

128×128 transparent; lower-body/feet-centered; restrained enough that ordinary soldier body/HP remains legible. Do not bake a timer, number, circular AoE radius, or second HP bar into it.

- [ ] **Step 6: Run Captain/HUD/BattleScene focused tests and build.**

Use existing HPA-475 tests plus `BattleSceneTests`. No production Swift edit should be required unless a fixed HPA-475 asset-name contract is factually wrong; if so, stop and correct the smallest existing consumer with a regression test rather than adding an adapter layer.

- [ ] **Step 7: Append Captain/Rally provenance and commit.**

```bash
git add Pyxis/Assets.xcassets/vanguard-captain-*.imageset \
  Pyxis/Assets.xcassets/rally-protection-accent.imageset \
  PyxisTests/BattleSceneTests.swift docs/art/tactical-siege/README.md
git commit -m "art: add Vanguard Captain and Rally assets"
```

---

## Task 4: Prove the pack in real gameplay and correct only visual mismatches

**Files:**
- Modify only if required: `Pyxis/ForgedVisualFixture.swift`
- Modify only if required: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify only if required: `PyxisUITests/PyxisUITests.swift`
- Modify: `docs/art/tactical-siege/README.md`
- Regenerate assets from Tasks 1–3 only when visual evidence finds a mismatch.

**Interfaces:**
- Consumes: current tactical DEBUG fixtures/DevJump state, all final HPA-476 assets, existing UI capture markers.
- Produces: reproducible reference/compact/iPad visual evidence and final art corrections; no production gameplay changes.

- [ ] **Step 1: Reuse existing fixtures and capture the reference 393×852 states.**

Required visual checkpoints:

1. Falconridge Gate intact + ruined;
2. Falconridge Tower intact + ruined;
3. Highcrest Barracks spawning + shut down;
4. Guard walk/attack/hit among allied troops;
5. Captain deployed with Captain HUD portrait visible;
6. Rally accent active on ordinary soldiers;
7. conquest/report state with tactical art still unobtrusive.

- [ ] **Step 2: Add DEBUG-only fixture support only if a required state cannot be held deterministically.**

Prefer lowering a capture-only Captain level or staging objective HP inside the existing fixture model over changing production balance. Pin any new launch marker/parser state with `ForgedVisualFixtureTests` + UI semantic smoke.

- [ ] **Step 3: Repeat the representative combined states on one compact supported phone and portrait iPad.**

Acceptance checks: Settings/tabs/Deploy/Rally hit regions remain unobstructed; objective HP and tower coverage remain readable; actors do not collide with HUD; flag still identifies selected lane.

- [ ] **Step 4: Capture a reduced-motion/static state.**

Confirm meaning survives without animation: ruined structure still looks ruined, disabled Barracks still looks disabled, Guard remains enemy-readable, Captain remains distinct, selected lane remains marked, Rally accent does not become required for understanding combat state.

- [ ] **Step 5: Correct art, not game rules.**

If a mismatch is scale, baseline, silhouette, opacity, or overlap, regenerate/recompose the affected image and rerun the asset tests. Do not retune HP, lanes, Guard rules, Captain rules, UI geometry, or combat timing to make the art fit.

- [ ] **Step 6: Record final visual acceptance notes in `docs/art/tactical-siege/README.md` and commit.**

Commit only actual fixture changes and corrected production assets; large screenshots/contact sheets stay outside tracked git history.

---

## Task 5: Run full gates and prove scope integrity

**Files:**
- No new feature files expected.
- Modify only fixes required by failing tests/visual acceptance within the allowed scope.

**Interfaces:**
- Consumes: completed HPA-476 branch.
- Produces: merge-ready evidence and a clean handoff for HPA-477.

- [ ] **Step 1: Run the complete unit suite serially.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: PASS with no weakened assertions.

- [ ] **Step 2: Run UI tests serially.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: PASS.

- [ ] **Step 3: Run lint + Debug/Release builds.**

```bash
swiftlint lint
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -configuration Release \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Expected: no new lint errors; both builds succeed.

- [ ] **Step 4: Verify asset inventory and diff scope.**

Mechanically count:

- 7 structure/flag sets;
- 31 Guard sets;
- 32 Captain sets;
- 1 Rally set.

Then inspect:

```bash
git diff --check
git diff --name-only main...HEAD
```

Expected tracked runtime change outside assets/docs/tests: only the narrow Guard presentation change in `Pyxis/BattleScene.swift`, plus DEBUG fixture files only if Task 4 required them.

- [ ] **Step 5: Verify prohibited files/areas are untouched.**

No changes to:

```text
Pyxis/KingdomGameState.swift
Pyxis/BattleCombatState.swift
Pyxis/Country1CityCatalog.swift
Pyxis/KingdomGameStore.swift
Pyxis.xcodeproj/project.pbxproj
.github/**
codecov.yml
```

If any appear, remove or explicitly justify a real defect fix against the HPA-476 scope before review.

- [ ] **Step 6: Finalize the PR evidence and Linear handoff.**

PR body should record final asset count, Guard presentation-only code shape, focused/full gates, reference/compact/iPad/reduced-motion evidence, and confirm that HPA-477 can reuse the pack unchanged.

- [ ] **Step 7: Commit any final documentation-only evidence update.**

```bash
git add docs/art/tactical-siege/README.md
git commit -m "docs: finalize tactical siege art handoff"
```

## Self-review result

- **Spec coverage:** every required structure, Guard, Captain, Rally, provenance, real-game comparison, reduced-motion check, and single-PR scope guard maps to a task above.
- **YAGNI:** no new manifest, animation framework, VFX engine, per-city art, extra SFX, or extra PR is planned.
- **Guard gap:** the only production-code addition is explicitly bounded to consuming art from existing Guard state/events.
- **Art separation:** HPA-477 remains data/content rollout only and receives no image-generation work.
- **Backward compatibility:** no migration/compatibility work is planned; none is required for asset-only changes.