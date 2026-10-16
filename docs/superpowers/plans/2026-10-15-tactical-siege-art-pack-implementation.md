# HPA-476 Anime Tactical Siege Asset Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the shared HPA-476 anime tactical-siege art pack, wire the already-shipped Guard behavior to its final animation assets, and prove the result in real gameplay without changing combat or campaign semantics.

**Architecture:** Reuse the existing Xcode asset catalog, tactical structure probes, 128×128 soldier/Captain animation convention, storyboard slicer, and DEBUG capture fixtures. Static structures replace procedural fallbacks by name; Captain art drops into an already-existing consumer; Guard gets one local `BattleScene` presentation seam that maps existing model progress/events to walk-01/walk/attack/hit textures. Gate repeats the same segment on each blocked lane inside its existing objective container. No runtime manifest, generic actor framework, or new gameplay owner is added.

**Tech Stack:** Swift 5, SpriteKit/UIKit, Xcode asset catalogs, Swift Testing, XCTest UI tests, PNG/RGBA, existing `tools/slice_soldier_animation_strips.py`, iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-10-15-tactical-siege-art-pack-design.md`

## Global Constraints

- One HPA-476 PR from planning through final assets/evidence. Do not split structure, Guard, Captain, or QA into separate PRs.
- Baseline: `main` at `294a9645c579391510f246656685690fe1e3c01e`.
- Final starting inventory: **68 new image sets** = 6 structures + 30 Guard + 31 Captain + 1 Rally accent; no assault flag or duplicate resting assets.
- Structure canvases: Gate segment 256×128; Arrow Tower 320×576; Barracks 320×480.
- Guard/Captain frames, Captain portrait, and Rally accent are 128×128. Both actor trios use infantry `bodyRegion` `(0.1875, 0.0625, 0.625, 0.734375)` (80×94 px body, 8 px foot margin); visible body height is 54–70 pt, or 38–50 pt below 500 pt screen height.
- Reuse 10-frame `walk`, `attack`, `hit` actions and the existing storyboard validation/timing convention.
- Reuse `write_contents_json`; do not add an asset manifest/parser/database.
- Reuse existing procedural Barracks spawn, collapse, Guard defeat, Captain retreat, projectile, sound, and haptic treatment.
- Production `BattleScene.swift` edits are limited to Guard art consumption and per-lane Gate segments; model/timing/damage decisions remain untouched. Minimal DEBUG capture hooks are allowed in existing scene/controller fixture handling.
- No gameplay-model, save, economy, reward, report, route, HPA-477 content, CI, Codecov, or `project.pbxproj` change.
- Run tests with `-parallel-testing-enabled NO`.
- Keep the PR Draft until the full pack, visual evidence, and final gates are complete.

## Review Focus

1. **Partial actor installation/geometry drift:** Tasks 2/3 extend the existing trio test across all seven prefixes and add one walk-bounds table; missing frames, wrong canvas/body height, or foot margins fail before capture.
2. **Guard poses repeatedly interrupted:** Task 2 tests no attack/hit restart, hit preempting attack, attack preserving hit, and sync preserving the active transient. Combat ticks remain independent of actions.
3. **Gate art misses blocked approaches:** Task 1 tests intact/ruined per-lane and outer-span coverage (±5%) across every non-empty lane subset, including non-adjacent left/right routes.
4. **Compact HUD/actor collisions:** Task 4 captures compact phone + portrait iPad with Captain portrait/Rally, Settings/tabs/Deploy, objective HP, and the existing selected-lane HUD visible together.
5. **Missing capture states or unclear static meaning:** Task 4 adds tested Falconridge and Captain/Rally DEBUG staging before capture; every capture checks static ruined/disabled/enemy/selected/protected meaning.

## File Map

### Planning / tracked handoff

- `docs/superpowers/specs/2026-10-15-tactical-siege-art-pack-design.md` — fixed design contract.
- `docs/superpowers/plans/2026-10-15-tactical-siege-art-pack-implementation.md` — this plan.
- `docs/art/tactical-siege/README.md` — prompts, source settings, slicing/regeneration, inventory, final acceptance notes.

### Production assets

- `Pyxis/Assets.xcassets/siege-{gate,gate-ruined,arrow-tower,arrow-tower-ruined,barracks,barracks-ruined}.imageset/`
- `Pyxis/Assets.xcassets/siege-guard-{walk,attack,hit}-{01...10}.imageset/`
- `Pyxis/Assets.xcassets/vanguard-captain-portrait.imageset/`
- `Pyxis/Assets.xcassets/vanguard-captain-{walk,attack,hit}-{01...10}.imageset/`
- `Pyxis/Assets.xcassets/rally-protection-accent.imageset/`

### Runtime/test support

- `Pyxis/BattleScene.swift` — Guard art consumption, per-lane Gate segments, minimal DEBUG capture hooks.
- `PyxisTests/BattleSceneTests.swift` — shared asset/bounds contract, Gate coverage, Guard presentation regression coverage.
- `Pyxis/ForgedVisualFixture.swift`, `PyxisTests/ForgedVisualFixtureTests.swift`, `PyxisUITests/PyxisUITests.swift` — expected Falconridge and Captain/Rally capture staging/tests.
- `Pyxis/GameViewController.swift` — only DEBUG fixture bootstrap where existing scene commands need launch staging.

---

## Task 1: Land the static tactical structure contract first

**Files:**
- Create: six `Pyxis/Assets.xcassets/siege-*.imageset/` static sets listed in File Map.
- Modify: `Pyxis/BattleScene.swift` — per-lane Gate segments only.
- Modify: `PyxisTests/BattleSceneTests.swift`
- Create: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: `BattleScene.SiegeObjectiveAssetContract`, `makeGateObjective(_:layout:remainingPower:maxPower:) -> SKNode`, existing `makeSiegeStructure` aspect-fit/`-ruined` lookup, `write_contents_json`.
- Produces: six final structure images, per-lane Gate presentation with one HP/ruin owner, and a reusable Swift asset-contract table extended by later tasks.

- [ ] **Step 1: Replace the placeholder-absence test with a failing production asset test.**

Rename the current `siegeObjectiveAssetContractPinsSemanticNames` intent to production ownership and keep the semantic-name assertions. Add exact presence/dimension checks:

```text
siege-gate                  256×128
siege-gate-ruined           256×128
siege-arrow-tower           320×576
siege-arrow-tower-ruined    320×576
siege-barracks              320×480
siege-barracks-ruined       320×480
```

For each intact/ruined pair assert both images have non-empty alpha bounds and `pngData()` differs. Remove the old absence assertions. The unused assault-flag constant may remain unshipped; do not add a consumer.

Add `gateSegmentsCoverBlockedLanes` with synthetic layouts for all seven non-empty lane subsets, intact and ruined: each segment covers its blocked lane width within ±5%, the union outer bounds match the authored span within ±5%, and HP/ruin ownership stays singular. Left/right-only routes get two segments at those lane centers, never a segment on the unblocked center lane.

- [ ] **Step 2: Run the focused test and verify RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/siegeObjectiveAssetContractPinsProductionAssets
```

Expected: asset test FAIL because the six production images are absent. Run `gateSegmentsCoverBlockedLanes` before the Gate seam and confirm RED on segment count/coverage; the current whole-span placeholder is not sufficient evidence.

- [ ] **Step 3: Author one structure family at a time against real runtime scale.**

Start with `siege-arrow-tower` + `-ruined`; composite/capture on Falconridge at 393×852 before generating the Gate. Next approve the Gate segment pair at one- and three-lane spans before generating Barracks; a synthetic scene layout is sufficient for the extra Gate spans. Reject the first pair if the tower loses silhouette at runtime, overlaps objective HP, or looks active when ruined. Keep the same camera/light/ground line across each pair.

- [ ] **Step 4: Install the approved Gate segment pair and repeat it per blocked lane.**

In `makeGateObjective`, reuse the existing container/span/`xs`: one `makeSiegeStructure` call per spanned lane at `x = laneX - container.position.x`, with target width `battlefieldLayout.lanePathWidth`, existing height `max(10, lanePathWidth * 0.5)`, and the existing bottom-center vertical placement. Keep one HP bar/ruin marker on the container. Do not divide the entire span into equal tiles or stretch the texture across an unblocked lane. Author Barracks from the accepted structure style; no alternate city skins or extra effects.

- [ ] **Step 5: Install the six image sets with the existing catalog writer.**

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

Expected: production asset and Gate coverage tests PASS; only the local Gate rendering loop changes shipping Swift for structures.

- [ ] **Step 8: Commit.**

```bash
git add Pyxis/Assets.xcassets/siege-*.imageset \
  Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift docs/art/tactical-siege/README.md
git commit -m "art: add tactical siege structures"
```

---

## Task 2: Add the Guard trio through one local BattleScene presentation seam

**Files:**
- Create: `Pyxis/Assets.xcassets/siege-guard-{walk,attack,hit}-{01...10}.imageset/`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: existing Guard snapshots/events, `guardNodes`, `GuardAnimationKey`, `firstAvailableSoldierAnimationFrameName(for:)`, `soldierAnimationTextures(for:action:)`, `soldierTextureAction(textures:action:type:sprite:)`, infantry `SoldierAnimationGeometry`/`SoldierAnimationTiming`, and `slice_soldier_storyboards`.
- Produces: final `siege-guard` 30-frame trio, `SiegeObjectiveAssetContract.guardAssetPrefix = "siege-guard"`, and Guard nodes using existing progress/events; Task 3 reuses the shared prefix/geometry test table.

- [ ] **Step 1: Extend existing actor inventory coverage and add the walk-bounds contract.**

Extend `allSoldierAnimationFramesAreInstalled` with the Guard prefix, keeping all existing five soldier prefixes; assert 30 frames per prefix and 128×128 for every frame. Add one shared `actorWalkBoundsMatchBodyGeometry` table with `(assetPrefix, SoldierType)` rows, using `.infantry` for Guard (and Captain in Task 3).

For each row, union alpha > 0 bounds over ten walk frames. Compare width, height, and bottom foot margin to `bodyRegion × 128`, within ±2 px. Convert top-left image coordinates to bottom-left geometry. Do not compare raw opaque minX: runtime centers the region, and the existing archer union is asymmetric. Guard's targets are 80 px width, 94 px height, 8 px foot margin.

Run the existing trio test plus the bounds test; verify RED on missing Guard frames, with the five existing soldier rows passing. Do not add a parallel `allGuardAnimationFramesAreInstalled` test.

- [ ] **Step 2: Write Guard presentation regression tests before runtime changes.**

Use existing Highcrest fixture seams; add focused tests for:

- moving Guard selects walk art when a complete trio is installed;
- initial stationary Guard uses walk-01;
- frame size equals infantry `frameSize(forBodyHeight:)`, stays square, and uses its foot-margin offset;
- attack selects attack art and does not restart an active attack;
- hit preempts attack, does not restart an active hit under several hit events, and is not interrupted by an attack;
- progress sync leaves an active attack/hit action in place.

Assert texture/action-key selection and no-restart identity or existing DEBUG trigger-count conventions. SKActions never finish without a render loop: do not advance combat and assert a transient completed, or add animation clocks to the model. Live capture in Task 4 verifies completion resumes the latest walk/still pose. Keep existing combat regression assertions; omit a redundant read-only presentation/model-equality test.

- [ ] **Step 3: Run the new presentation tests and verify RED.**

Expected: the procedural Guard has no final-art sprite/trio selection path yet.

- [ ] **Step 4: Author three Guard 5×2 storyboards.**

Create `walk`, `attack`, `hit` in one consistent enemy-facing anime Guard design. Use the default chroma key accepted by the existing slicer. Keep feet/baseline and apparent body scale stable across all three boards, matching infantry body geometry before slicing. Keep the first complete trio ready for real-game acceptance after installation and the presentation seam.

- [ ] **Step 5: Slice/install the Guard trio with the existing helper, not a new CLI mode.**

Invoke `slice_soldier_storyboards(images, assets_dir, "siege-guard", 128)` from a short Python script. Do not widen the CLI `SOLDIERS` allow-list just for this task. Use walk-01 as the stationary pose; do not copy a resting image set.

- [ ] **Step 6: Add the minimal Guard presentation seam in `BattleScene.swift`.**

Keep the existing `GuardNodeBundle`; extend it only as needed for a sprite body and last synced progress. Use `SiegeObjectiveAssetContract.guardAssetPrefix`, complete-trio probing, existing texture loading, `soldierTextureAction(..., type: .infantry, ...)`, and infantry geometry for frame sizing/foot offset. Do not couple the prefix to the node-name constant.

Required mapping:

```text
progress changed -> walk
GuardAttackEvent -> attack
GuardHitEvent -> hit
stationary with no transient -> walk-01
loss -> existing procedural loss/fade
```

Do not restart attack while attack/hit is active; hit preempts attack but does not restart an active hit. Sync preserves transients. On completion, resume the most recently synced moving/still pose; do not blindly start walk for a stationary Guard. If the complete trio probe fails, retain the current procedural Guard visual. Do not create a Guard animator type, actor protocol, event bus, or new model field.

- [ ] **Step 7: Run Highcrest/Guard-focused tests.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: asset completeness + presentation tests GREEN; existing Highcrest combat/persistence assertions unchanged. Approve this first complete actor trio in real 393×852 gameplay before generating the Captain boards in Task 3.

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
- Create: `Pyxis/Assets.xcassets/vanguard-captain-{walk,attack,hit}-{01...10}.imageset/`
- Create: `Pyxis/Assets.xcassets/rally-protection-accent.imageset/`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/art/tactical-siege/README.md`

**Interfaces:**
- Consumes: HPA-475's existing Captain prefix/portrait/Rally consumers, Task 2's shared trio and walk-bounds test tables, infantry geometry, and `slice_soldier_storyboards`.
- Produces: complete final Captain trio/portrait + Rally accent without changing production Swift behavior.

- [ ] **Step 1: Add failing Captain/Rally inventory tests.**

Assert:

- portrait/Rally resolve at 128×128 with non-empty alpha content;
- all 30 `vanguard-captain-{walk,attack,hit}` frames resolve at 128×128;
- Captain trio is complete, never partially installed.

Add the Captain prefix to Task 2's existing trio test and walk-bounds table (mapped to `.infantry`); do not add a parallel Captain trio test or alter the five existing soldier mappings/assertions.

- [ ] **Step 2: Run the focused inventory test and verify RED.**

Expected: HPA-475 currently falls back because final generated assets are absent.

- [ ] **Step 3: Author one Captain identity source before action boards.**

Lock one original outfit, hair/helmet silhouette, weapon, allied-facing direction, and palette. Produce the 128×128 HUD portrait from the same approved character identity; do not create alternate skins or equipment.

- [ ] **Step 4: Author and slice Captain walk/attack/hit storyboards.**

Use `slice_soldier_storyboards(images, assets_dir, "vanguard-captain", 128)`. Match the infantry body-region contract; retain outfit and silhouette consistency with the portrait. Do not install a duplicate resting set.

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
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisUITests/PyxisUITests.swift`
- Modify only if launch staging requires it: DEBUG sections of `Pyxis/GameViewController.swift` / `Pyxis/BattleScene.swift`
- Modify: `docs/art/tactical-siege/README.md`
- Regenerate assets from Tasks 1–3 only when visual evidence finds a mismatch.

**Interfaces:**
- Consumes: existing Highcrest fixtures/DevJump, by-kind objective-damage staging, existing Captain deployment/Rally scene commands, all final HPA-476 assets, and existing UI capture markers.
- Produces: tested DEBUG-only Falconridge/Captain/Rally staging and reproducible reference/compact/iPad evidence; no production gameplay changes.

- [ ] **Step 1: Add failing fixture tests for the missing capture states.**

Write tests for new fixture enum/parser markers covering Falconridge Gate/Tower intact/ruined staging and Captain-deployed/Rally-active states. Assert parsed markers, current city, staged objective damage, battle tab, and Captain/Rally preconditions in `ForgedVisualFixtureTests`; UI semantic smoke must verify the actual deployed Captain/Rally state after bootstrap, since `makeState()` alone cannot own transient combat. Run the new tests and verify RED before fixture changes.

- [ ] **Step 2: Implement DEBUG staging, run fixture/UI smoke, then capture 393×852.**

Use existing `seedSiegeProgress` by-kind damage for Falconridge and existing scene commands for Captain deployment/Rally. If launch handling needs a hook, keep it entirely `#if DEBUG` in the existing controller/scene. Do not persist a transient roster or change production balance. Reuse existing Highcrest states. Run `ForgedVisualFixtureTests` and the new UI smoke serially; expected PASS before capture.

Required visual checkpoints:

1. Falconridge Gate intact + ruined;
2. Falconridge Tower intact + ruined;
3. Highcrest Barracks spawning + shut down;
4. Guard walk/attack/hit among allied troops, including transient completion returning to the current moving/still pose;
5. Captain deployed with Captain HUD portrait visible;
6. Rally accent active on ordinary soldiers;
7. conquest/report state with tactical art still unobtrusive.

- [ ] **Step 3: Repeat the representative combined states on one compact supported phone and portrait iPad.**

Acceptance checks: Settings/tabs/Deploy/Rally hit regions remain unobstructed; objective HP and tower coverage remain readable; actors do not collide with HUD; the existing HUD `ASSAULT` treatment still identifies the selected lane.

- [ ] **Step 4: Check static meaning in every regular capture.**

Confirm meaning survives without animation: ruined structure still looks ruined, disabled Barracks still looks disabled, Guard remains enemy-readable, Captain remains distinct, selected lane remains marked, Rally accent does not become required for understanding combat state. Actor sprites have no Reduce Motion branch; do not claim a separate reduced-motion screenshot proves disabled animation or add new motion behavior for this ticket.

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

- [ ] **Step 1: Run the complete unit suite serially with coverage.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -enableCodeCoverage YES \
  -resultBundlePath /tmp/pyxis-hpa-476-unit.xcresult \
  -only-testing:PyxisTests
```

Use a fresh result-bundle path for each run. Export coverage with the existing CI `xccov` / `tools/xccov-to-lcov.rb` flow. Expected: unit tests PASS with no weakened assertions; preserve the existing Codecov project and patch targets of 90%. Local coverage output does not establish a hosted Codecov pass. CI skips draft PR jobs, so retain local evidence while Draft and verify hosted checks after the completed pack is marked ready for review.

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

- 6 structure sets;
- 30 Guard sets;
- 31 Captain sets;
- 1 Rally set.

Then inspect:

```bash
git diff --check
git diff --name-only main...HEAD
```

Expected tracked runtime change outside assets/docs/tests: only Guard art consumption and per-lane Gate rendering in `Pyxis/BattleScene.swift`, plus the expected DEBUG fixture/test changes and minimal DEBUG controller bootstrap if required.

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

PR body should record final asset count, Guard/Gate presentation-only code shape, focused/full gates, reference/compact/iPad evidence and static-meaning checks, and confirm that HPA-477 can reuse the pack unchanged.

- [ ] **Step 7: Commit any final documentation-only evidence update.**

```bash
git add docs/art/tactical-siege/README.md
git commit -m "docs: finalize tactical siege art handoff"
```

## Self-review result

- **Spec coverage:** every required structure, Guard, Captain, Rally, provenance, real-game comparison, static-meaning check, and single-PR scope guard maps to a task above.
- **YAGNI:** no new manifest, animation framework, VFX engine, per-city art, extra SFX, or extra PR is planned.
- **Presentation gaps:** production edits are bounded to Guard art from existing state/events and one shared Gate segment per blocked lane; fixture launch staging stays DEBUG-only.
- **Art separation:** HPA-477 remains data/content rollout only and receives no image-generation work.
- **Backward compatibility:** no migration/compatibility work is planned; none is required for asset-only changes.
