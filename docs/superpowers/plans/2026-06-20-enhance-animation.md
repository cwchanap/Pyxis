# Enhance Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add compact battle lane spacing and generated 10-frame walk, attack, and hit animations for all five soldier types.

**Architecture:** Keep combat logic pure and unchanged. `BattlefieldLayout` owns lane density, a small asset pipeline slices generated strips into asset catalog frames, and `BattleScene` maps `SoldierType` plus animation action to SpriteKit texture animations with static fallbacks.

**Tech Stack:** Swift 5, SpriteKit, Swift Testing, Xcode asset catalogs, generated PNG sprite strips, local image post-processing.

**Spec:** `docs/superpowers/specs/2026-06-20-enhance-animation-design.md`

**Primary verification command:**
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:PyxisTests
```

---

## File Structure

| File | Responsibility |
| --- | --- |
| `tools/slice_soldier_animation_strips.py` | Slice 10-frame strip PNGs into `.imageset` frame assets and write `Contents.json`. |
| `Pyxis/Assets.xcassets/<soldier>-<action>-<frame>.imageset/` | Generated transparent animation frames. |
| `Pyxis/BattlefieldLayout.swift` | Compute compact symmetric lane centers. |
| `Pyxis/BattleScene.swift` | Resolve animation frames, start walk loops, play attack and hit animations, preserve fallbacks. |
| `PyxisTests/BattlefieldLayoutTests.swift` | Pin compact lane spacing. |
| `PyxisTests/BattleSceneTests.swift` | Pin animation frame resolution and action-key behavior. |

## Task 1: Compact Lane Geometry

**Files:**
- Modify: `Pyxis/BattlefieldLayout.swift`
- Modify: `PyxisTests/BattlefieldLayoutTests.swift`

- [x] **Step 1: Write failing tests**

Add tests proving lanes remain symmetric but use a compact spread:

```swift
@Test func lanesUseCompactCenterSpread() {
    let layout = BattlefieldLayout.compute(constraints: makeConstraints())
    let xs = BattleLane.allCases.map { layout.castleGatePoints[$0]!.x }
    let leftGap = xs[1] - xs[0]
    let rightGap = xs[2] - xs[1]

    #expect(abs(leftGap - rightGap) < 0.01)
    #expect(leftGap < layout.frame.width * 0.20)
    #expect(rightGap < layout.frame.width * 0.20)
}

@Test func fallbackLanesUseCompactCenterSpread() {
    let layout = BattlefieldLayout.compute(constraints: makeConstraints(
        sceneWidth: 200,
        sceneHeight: 100,
        safeTopY: 80,
        safeBottomY: 70
    ))
    let xs = BattleLane.allCases.map { layout.castleGatePoints[$0]!.x }
    #expect(xs[1] == 100)
    #expect(xs[1] - xs[0] < 40)
    #expect(xs[2] - xs[1] < 40)
}
```

- [x] **Step 2: Verify red**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:PyxisTests/BattlefieldLayoutTests
```

Expected: the new compact-spread tests fail because current lanes are at 25%, 50%, and 75%.

- [x] **Step 3: Implement compact lane centers**

Add a helper that returns `0.38`, `0.50`, and `0.62` across the active layout width:

```swift
private static func laneCenterX(in frame: CGRect, lane: BattleLane) -> CGFloat {
    let compactOffsets: [BattleLane: CGFloat] = [
        .left: -0.12,
        .center: 0,
        .right: 0.12
    ]
    return frame.midX + frame.width * (compactOffsets[lane] ?? 0)
}
```

Use this helper for both visible and fallback gate points.

- [x] **Step 4: Verify green**

Run the same `BattlefieldLayoutTests` command and confirm the suite passes.

## Task 2: Animation Asset Pipeline

**Files:**
- Create: `tools/slice_soldier_animation_strips.py`
- Create: `Pyxis/Assets.xcassets/<soldier>-<action>-<frame>.imageset/`

- [x] **Step 1: Generate source strips**

Use the built-in image generation tool to create 15 horizontal sprite strips: 5 soldier types × 3 actions. Each strip must contain 10 equal-width frames on a flat chroma-key background.

- [x] **Step 2: Add slicing script**

Create `tools/slice_soldier_animation_strips.py`. The canonical implementation is version-controlled at that path; key behaviors:

- Slices each `<soldier>-<action>.png` strip into 10 frames (`FRAME_COUNT = 10`).
- Chroma-keys the green background and applies a light edge despill (`strip_chroma_key`).
- Center-bottom-aligns each frame on a square `--frame-size` canvas (default 128) via `centered_square_frame`.
- Writes one `<soldier>-<action>-NN.imageset/` bundle per frame (PNG + `Contents.json`).
- `--assets-dir` (output) is resolved and clamped to the repo root (`resolve_within_repo`) so a faulty argument can't write outside the project tree. `--strips-dir` (read-only input) is intentionally **not** clamped, so source strips may live outside the repo (e.g. `/tmp`).

- [x] **Step 3: Slice strips**

Run:
```bash
python3 tools/slice_soldier_animation_strips.py --strips-dir /private/tmp/pyxis-hpa83-strips --assets-dir Pyxis/Assets.xcassets
```

Expected: 150 `.imageset` directories are created.

- [x] **Step 4: Inspect image dimensions**

Run:
```bash
sips -g pixelWidth -g pixelHeight Pyxis/Assets.xcassets/infantry-walk-01.imageset/infantry-walk-01.png
```

Expected: a 128×128 square PNG frame (soldiers render at ~28-42 pt, so 128 px is ample for 3× devices without oversampling). Not a whole strip, and not 512 px (which would waste ~150 MB of GPU memory across the full animation set).

## Task 3: BattleScene Animation Resolution

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [x] **Step 1: Write failing tests**

Add tests that verify frame names are generated for every soldier type and action:

```swift
@Test func allSoldierTypesExposeTenAnimationFramesForEachAction() throws {
    let scene = makeScene()

    for soldierType in SoldierType.allCases {
        for action in ["walk", "attack", "hit"] {
            let names = scene.animationFrameNamesForTesting(soldierType: soldierType, action: action)
            #expect(names.count == 10)
            #expect(names.first == "\(soldierType.rawValue)-\(action)-01")
            #expect(names.last == "\(soldierType.rawValue)-\(action)-10")
        }
    }
}
```

- [x] **Step 2: Verify red**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: build fails because `animationFrameNamesForTesting` does not exist.

- [x] **Step 3: Implement frame naming**

Add a private animation action enum and frame-name builder in `BattleScene`, plus a debug test accessor:

```swift
private enum SoldierAnimationAction: String, CaseIterable {
    case walk
    case attack
    case hit
}

private static let soldierAnimationFrameCount = 10

private func soldierAnimationFrameNames(for type: SoldierType, action: SoldierAnimationAction) -> [String] {
    (1...Self.soldierAnimationFrameCount).map {
        "\(type.rawValue)-\(action.rawValue)-\(String(format: "%02d", $0))"
    }
}
```

- [x] **Step 4: Verify green**

Run the same `BattleSceneTests` command and confirm the new frame naming test passes.

## Task 4: Runtime Animation Playback

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [x] **Step 1: Write failing tests**

Add tests that spawn a soldier and verify walking animation starts, then advance combat enough to trigger attack or tower-hit feedback and verify action keys are installed:

```swift
@Test func spawnedSoldierStartsWalkingAnimation() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()

    #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
}

@Test func towerDamageStartsHitAnimation() throws {
    let store = try makeStore(initialState: stateWithBarracks(
        cityRemainingPower: 100,
        cityNumberInCountry: 9,
        completedCityCount: 8
    ))
    let scene = makeScene(store: store, combatSeed: 1)

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 1.2)

    #expect(scene.recentSoldierHitAnimationCountForTesting > 0)
}
```

- [x] **Step 2: Verify red**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: build fails because the animation hooks do not exist.

- [x] **Step 3: Implement playback**

In `createSoldierNode`, create sprite-backed bodies when animation frames exist. In `syncSoldierNodes`, start a repeat-forever walk animation under `soldierWalkAnimation`. In `applyCombatResult`, play attack and hit animations with keys `soldierAttackAnimation` and `soldierHitAnimation`.

- [x] **Step 4: Verify green**

Run the same `BattleSceneTests` command and confirm the suite passes.

## Task 5: Full Verification

**Files:**
- Modify as needed from prior tasks.

- [x] **Step 1: Run unit tests**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:PyxisTests
```

- [x] **Step 2: Run build if unit tests pass**

Run:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- [x] **Step 3: Inspect final diff**

Run:
```bash
git status --short
git diff --stat
```

Confirm the diff contains only docs, slicing tooling, generated animation assets, layout tests, and battle animation code.
