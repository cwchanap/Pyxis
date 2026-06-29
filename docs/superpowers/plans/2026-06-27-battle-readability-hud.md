# Battle Readability HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Pyxis battle screen read as a wide, tall battlefield with subtle terrain cues, 2x soldiers, a mixed icon/text HUD, and stable soldier identity during transient feedback.

**Architecture:** Keep lane math in `Pyxis/BattlefieldLayout.swift` and SpriteKit presentation in `Pyxis/BattleScene.swift`. Do not touch combat model behavior. Tests live in `PyxisTests/BattlefieldLayoutTests.swift` and `PyxisTests/BattleSceneTests.swift`.

**Tech Stack:** Swift 5, SpriteKit, Swift Testing, Xcode/iOS Simulator.

---

## File Structure

- Modify `Pyxis/BattlefieldLayout.swift`: lane thirds, wider lane path widths, optional feedback clearance.
- Modify `Pyxis/BattleScene.swift`: wider battlefield frame, low-alpha terrain lane rendering, mixed persistent text/icon nodes, transient tooltips, 2x soldiers, close HP bars, stable transient playback textures, and visible attack cues.
- Modify `PyxisTests/BattlefieldLayoutTests.swift`: pure geometry tests.
- Modify `PyxisTests/BattleSceneTests.swift`: SpriteKit layout and HUD rendering tests.

### Task 1: Battlefield Geometry

**Files:**
- Modify: `PyxisTests/BattlefieldLayoutTests.swift`
- Modify: `Pyxis/BattlefieldLayout.swift`

- [ ] **Step 1: Write failing tests**

Add tests that assert lane centers sit at equal thirds of the frame, lane paths are wide enough to read as bands, and zero feedback font size does not reserve tooltip clearance.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattlefieldLayoutTests
```

Expected: failure on the new lane spread/path width/feedback clearance expectations.

- [ ] **Step 3: Implement geometry**

Change `BattlefieldLayout.compute` so `lanePathWidth` is based on the computed battlefield frame width, lane centers use `1/6`, `3/6`, and `5/6` of that frame, and feedback clearance is only reserved when `feedbackFontSize > 0`. Note: the sole caller (`BattleScene.layoutBattlefield`) currently always passes `feedbackFontSize: 0`, so no clearance is reserved in practice; the conditional path is retained for future tooltip sizing but is not exercised today.

- [ ] **Step 4: Run tests to verify pass**

Run the same `BattlefieldLayoutTests` command. Expected: PASS.

### Task 2: Terrain Lane Rendering

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `Pyxis/BattleScene.swift`

- [ ] **Step 1: Write failing tests**

Add tests that assert each lane renders terrain nodes with decorative marks, blends into the backdrop at low alpha, and preserves lane placement/no-overlap guarantees.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests
```

Expected: failure because the current lane visuals are flat/opaque path rectangles without terrain detail.

- [ ] **Step 3: Implement terrain lanes**

Render each lane as a terrain cue in `BattleScene.drawLanePaths()`: low-alpha dirt/grass tint, subtle border, and deterministic small decorative marks. Keep the lane node names stable for tests.

- [ ] **Step 4: Run tests to verify pass**

Run the same `BattleSceneTests` command. Expected: PASS or isolated failures from the following HUD task.

### Task 3: Mixed Icon/Text HUD And Tooltip Text

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `Pyxis/BattleScene.swift`

- [ ] **Step 1: Write failing tests**

Add tests that assert the initial battle scene shows essential text (`Spawn`, selected unit, gold, soldier count, city title/HP), keeps large icon-backed controls, and uses compact near-square buttons for common Build/World actions.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests
```

Expected: failure because the current branch hides all persistent HUD labels and uses wide common-action buttons.

- [ ] **Step 3: Implement HUD icons, text, and tooltip behavior**

Keep short persistent text on Spawn, the unit selector, gold, soldier count, city title, and HP. Keep longer context in tooltips. Resize World and Build into compact icon buttons, lay out Spawn as a larger pill with icon plus text, and size all button icons large enough to read.

- [ ] **Step 4: Run tests to verify pass**

Run the same `BattleSceneTests` command. Expected: PASS or isolated failures that point to tests still expecting text labels.

### Task 4: Larger Soldiers And Taller Battlefield

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `Pyxis/BattleScene.swift`

- [ ] **Step 1: Write failing tests**

Add tests that assert the battlefield frame occupies most of a tall phone viewport, the first live soldier body height is at least 54 pt and at most 70 pt (half scale — see the spec's Design section for why the original 108-140 pt target was reduced), and its HP bar sits close to the body.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests
```

Expected: failure because the current feedback reservation shortens the battlefield and soldiers render below the requested 2x size.

- [ ] **Step 3: Implement presentation sizing**

Reduce HUD height to an icon strip, pass the wider battlefield width into `BattlefieldLayout`, stop reserving tooltip space while hidden, set soldier target height to the half-scale 54-70 pt band (matching the spec's Design rationale), and keep the HP bar near the body.

- [ ] **Step 4: Run tests to verify pass**

Run the same `BattleSceneTests` command. Expected: PASS.

### Task 5: Stable Soldier Transient Playback

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `Pyxis/BattleScene.swift`

- [ ] **Step 1: Write failing tests**

Add regression tests that assert attack and hit playback use the same `SKTexture` instances as the stable walk-frame set for each `SoldierType`, and that city damage creates a visible stable-art attack cue.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests
```

Expected: failure because generated attack/hit textures are currently loaded directly and can visually swap the actor to mismatched art.

- [ ] **Step 3: Route transient playback to stable frames**

Keep existing transient timing and resolve `.attack` and `.hit` animation textures through the walk-frame set until consistent generated transient frames are available. Add a stable slash cue plus stronger lunge so attack feedback remains readable without swapping actor art.

- [ ] **Step 4: Run tests to verify pass**

Run the same `BattleSceneTests` command. Expected: PASS.

### Task 6: Full Verification

**Files:**
- No additional files expected.

- [ ] **Step 1: Run focused tests**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests/BattlefieldLayoutTests -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 2: Run broader unit/UI verification when simulator capacity permits**

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO
```

Expected: PASS.

- [ ] **Step 3: Lint with writable cache**

Run:

```bash
swiftlint lint --cache-path /private/tmp/pyxis-battle-readability-swiftlint-cache
```

Expected: no new lint violations.
