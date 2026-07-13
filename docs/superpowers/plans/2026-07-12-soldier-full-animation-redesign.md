# Soldier Full Animation Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all 150 soldier walk, attack, and hit frames with five identity-consistent animation trios and play them with readable action-specific timing.

**Architecture:** Extend the existing storyboard pipeline so all three actions for one soldier validate and install as one atomic 30-frame unit. Move frame timing and approval metadata into small framework-free Swift types, then let `BattleScene` build weighted per-frame SpriteKit actions from that data. Generate and approve one canonical identity plus three storyboards per soldier, cutting over one complete soldier at a time before deleting the legacy procedural fallback.

**Tech Stack:** Swift 5, SpriteKit, Swift Testing, Python 3, Pillow, built-in image generation, ffmpeg, XcodeBuildMCP, SwiftLint

## Global Constraints

- Run every shell command through the repository-required `rtk` prefix.
- Keep all 150 final frames at exactly 128 by 128 pixels with RGBA output.
- Process soldiers in this order: archer, infantry, cavalry, mage, siege.
- Generate one canonical identity first, then walk, attack, and hit from that same identity.
- Use one centered 5-column by 2-row storyboard; frame order is row-major.
- Reserve the outer eight percent of every source cell for flat key color only.
- Use `#ff00ff` for archer and `#00ff00` for infantry, cavalry, mage, and siege.
- Never weaken gutter, alpha, density, height, baseline, or frame-count validation to accept broken art.
- Do not use per-frame content scaling or cropping. Rigid translation may correct source-cell placement while preserving scale and pixels.
- Do not include slash arcs, impact stars, speed lines, detached projectiles, auras, explosions, text, shadows, or scenery in body frames.
- Walk is a uniform 1.0-second loop. Hit totals 0.9 seconds. Attack totals are infantry 1.2, archer 1.4, cavalry 1.2, mage 1.4, and siege 1.6 seconds.
- Keep combat rules, targeting, movement, spawning, lanes, and battle layout unchanged.
- Use the built-in image generation tool. Do not switch to CLI image generation without new user approval.
- Keep canonical references and source storyboards under `/private/tmp/pyxis-full-animation`; keep QA outputs under ignored `build/animation-preview/`.
- Do not edit `project.pbxproj`; synchronized root groups discover new Swift files.
- Disable parallel Xcode testing with `-parallel-testing-enabled NO`.
- Preserve unrelated worktree changes, including the user's `.gitignore` edit.

## Shared Image Prompt Contract

Every canonical and storyboard prompt must include these invariants verbatim:

```text
Match the supplied canonical character exactly: same face, hair, head/body
proportions, costume pieces, colors, weapon or mechanism construction, outline
weight, lighting direction, and chibi fantasy mobile-game rendering quality.
Keep the character facing right. Keep apparent body scale constant. No text,
labels, borders, dividers, shadows, floor, scenery, watermark, extra character,
detached projectile, slash arc, impact star, speed line, aura, explosion, or
decorative effect. Preserve the complete character and all equipment.
```

Every storyboard prompt must additionally include:

```text
Create exactly ten sequential animation poses arranged in a strict 5-column by
2-row grid of equal square cells, frames 1-5 on the first row and 6-10 on the
second. Leave generous flat chroma-key padding around every pose. No artwork may
touch or cross a cell boundary. Frames 1 and 10 are compatible neutral poses.
Keep feet, hooves, or wheels on one baseline and do not translate, bounce,
shrink, or enlarge the whole character between cells.
```

If image generation preserves the correct art but shifts whole poses within the
grid, use a deterministic ffmpeg composition to translate complete separated
poses onto fixed square cells. Preserve every source pixel and the generated
scale. Do not repair overlap, cropping, missing equipment, or style drift with
post-processing; regenerate those defects with a targeted image edit.

## File Map

| File | Responsibility |
| --- | --- |
| `tools/slice_soldier_animation_strips.py` | Prepare, cross-validate, stage, and atomically install one soldier's three storyboard actions. |
| `tools/tests/test_slice_soldier_animation_strips.py` | Pin 30-frame geometry validation and rollback behavior. |
| `Pyxis/SoldierAnimationTiming.swift` | Framework-free action enum, total durations, timing weights, and per-frame durations. |
| `Pyxis/SoldierAnimationManifest.swift` | Explicit per-type authored-action and full-canvas approval state during staged rollout. |
| `PyxisTests/SoldierAnimationTimingTests.swift` | Verify frame counts, totals, and non-uniform timing shape. |
| `PyxisTests/SoldierAnimationManifestTests.swift` | Verify each staged soldier cutover. |
| `Pyxis/BattleScene.swift` | Resolve manifest-approved textures, build weighted SpriteKit actions, interrupt transients, and schedule removal. |
| `PyxisTests/BattleSceneTests.swift` | Verify distinct action textures, full-canvas sizing, timing integration, interruption, fallback, and no overlays. |
| `Pyxis/Assets.xcassets/{archer,infantry,cavalry,mage,siege}-{walk,attack,hit}-*.imageset/*.png` | Final 150 animation frames. |
| `CLAUDE.md` | Record the complete animation-trio and weighted-playback contract. |

---

### Task 1: Validate And Install Complete Soldier Trios Atomically

**Files:**
- Modify: `tools/slice_soldier_animation_strips.py:159-475`
- Modify: `tools/tests/test_slice_soldier_animation_strips.py:86-160`

**Interfaces:**
- Consumes: three storyboard `Image.Image` values keyed by `walk`, `attack`, and `hit`.
- Produces: `prepare_soldier_storyboards(images: dict[str, Image.Image], soldier: str, frame_size: int = 128) -> dict[str, list[Image.Image]]` and `slice_soldier_storyboards(images: dict[str, Image.Image], output: Path, soldier: str, frame_size: int = 128) -> None`.

- [ ] **Step 1: Add failing cross-action geometry tests**

Add helpers and tests:

```python
def make_action_boards() -> dict[str, Image.Image]:
    return {action: make_metric_board([(16, 16, 47, 47)] * 10) for action in pipeline.ACTIONS}


class SoldierTrioValidationTests(unittest.TestCase):
    def test_prepares_all_thirty_frames(self) -> None:
        prepared = pipeline.prepare_soldier_storyboards(
            make_action_boards(), soldier="infantry"
        )

        self.assertEqual(set(prepared), set(pipeline.ACTIONS))
        self.assertTrue(all(len(frames) == 10 for frames in prepared.values()))

    def test_rejects_cross_action_baseline_drift(self) -> None:
        boards = make_action_boards()
        boards["hit"] = make_metric_board([(16, 8, 47, 39)] * 10)

        with self.assertRaisesRegex(ValueError, "trio baseline"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

    def test_requires_exactly_walk_attack_and_hit(self) -> None:
        boards = make_action_boards()
        del boards["hit"]

        with self.assertRaisesRegex(ValueError, "walk, attack, and hit"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")
```

- [ ] **Step 2: Run the pipeline tests and verify RED**

Run:

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
```

Expected: FAIL because `prepare_soldier_storyboards` does not exist.

- [ ] **Step 3: Implement trio preparation and cross-action metrics**

Add:

```python
def _validate_trio_metrics(prepared: dict[str, list[Image.Image]]) -> None:
    from statistics import median

    metrics = [
        _opaque_metrics(frame)
        for action in ACTIONS
        for frame in prepared[action]
    ]
    counts = [count for count, _ in metrics]
    heights = [bounds[3] - bounds[1] for _, bounds in metrics]
    baselines = [bounds[3] for _, bounds in metrics]
    median_count = median(counts)
    median_height = median(heights)

    for count in counts:
        ratio = count / median_count
        if ratio < MIN_DENSITY_RATIO or ratio > MAX_DENSITY_RATIO:
            raise ValueError(f"trio opaque pixel count ratio {ratio:.2f}")
    for height in heights:
        ratio = height / median_height
        if ratio < MIN_HEIGHT_RATIO or ratio > MAX_HEIGHT_RATIO:
            raise ValueError(f"trio bounding-box height ratio {ratio:.2f}")
    if max(baselines) - min(baselines) > MAX_BASELINE_DELTA:
        raise ValueError(
            f"trio baseline delta {max(baselines) - min(baselines)} "
            f"exceeds {MAX_BASELINE_DELTA}"
        )


def prepare_soldier_storyboards(
    images: dict[str, Image.Image], soldier: str, frame_size: int = 128
) -> dict[str, list[Image.Image]]:
    if set(images) != set(ACTIONS):
        raise ValueError("soldier trio requires walk, attack, and hit storyboards")
    prepared = {
        action: prepare_storyboard_frames(images[action], soldier, frame_size)
        for action in ACTIONS
    }
    _validate_trio_metrics(prepared)
    return prepared
```

- [ ] **Step 4: Add a failing 30-frame rollback test**

```python
def test_invalid_hit_does_not_replace_walk_or_attack(self) -> None:
    from tempfile import TemporaryDirectory

    boards = make_action_boards()
    invalid = boards["hit"].copy()
    ImageDraw.Draw(invalid).point((1, 80), fill=(255, 0, 0, 255))
    boards["hit"] = invalid

    with TemporaryDirectory() as directory:
        output = Path(directory)
        sentinels = []
        for action in pipeline.ACTIONS:
            sentinel = output / f"infantry-{action}-01.imageset" / "sentinel.txt"
            sentinel.parent.mkdir(parents=True)
            sentinel.write_text(action, encoding="utf-8")
            sentinels.append((sentinel, action))

        with self.assertRaises(ValueError):
            pipeline.slice_soldier_storyboards(boards, output, "infantry", 128)

        for sentinel, action in sentinels:
            self.assertEqual(sentinel.read_text(encoding="utf-8"), action)
```

- [ ] **Step 5: Run the rollback test and verify RED**

Run the unittest command from Step 2.

Expected: FAIL because `slice_soldier_storyboards` does not exist.

- [ ] **Step 6: Implement one staged install for all thirty imagesets**

Generalize `_install_staged_imagesets_atomic` to accept `actions: tuple[str, ...]`,
iterate each action and frame, and roll back every installed destination if any
rename fails. Update the existing `slice_storyboard` caller to pass `(action,)`.
Then add:

```python
def slice_soldier_storyboards(
    images: dict[str, Image.Image],
    output: Path,
    soldier: str,
    frame_size: int,
) -> None:
    prepared = prepare_soldier_storyboards(images, soldier, frame_size)
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix=".soldier-animation-", dir=output) as directory:
        temp_root = Path(directory)
        stage_root = temp_root / "new"
        stage_root.mkdir()
        for action in ACTIONS:
            _write_staged_imagesets(prepared[action], stage_root, soldier, action)
        _install_staged_imagesets_atomic(
            stage_root, output, soldier, tuple(ACTIONS)
        )
```

In `main`, when `--storyboards-dir` is used with all three actions, load all
three images for one soldier and call `slice_soldier_storyboards`. Preserve
single-action `slice_storyboard` only for ignored preview work.

- [ ] **Step 7: Run tests and commit**

Run:

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk git diff --check
rtk git add tools/slice_soldier_animation_strips.py tools/tests/test_slice_soldier_animation_strips.py
rtk git commit -m "feat: validate soldier animation trios atomically"
```

Expected: all pipeline tests PASS and the diff check is clean.

---

### Task 2: Add Framework-Free Timing And Approval Metadata

**Files:**
- Create: `Pyxis/SoldierAnimationTiming.swift`
- Create: `Pyxis/SoldierAnimationManifest.swift`
- Create: `PyxisTests/SoldierAnimationTimingTests.swift`
- Create: `PyxisTests/SoldierAnimationManifestTests.swift`

**Interfaces:**
- Produces: `SoldierAnimationAction`, `SoldierAnimationTiming.frameDurations(for:type:)`, `SoldierAnimationTiming.totalDuration(for:type:)`, `SoldierAnimationManifest.isAuthored(_:for:)`, and `SoldierAnimationManifest.usesFullCanvas(for:)`.

- [ ] **Step 1: Write failing timing tests**

Create `PyxisTests/SoldierAnimationTimingTests.swift`:

```swift
import Foundation
import Testing
@testable import Pyxis

struct SoldierAnimationTimingTests {
    @Test func everyActionProvidesTenPositiveDurations() {
        for type in SoldierType.allCases {
            for action in SoldierAnimationAction.allCases {
                let durations = SoldierAnimationTiming.frameDurations(for: action, type: type)
                #expect(durations.count == 10)
                #expect(durations.allSatisfy { $0 > 0 })
            }
        }
    }

    @Test func totalsMatchApprovedPlaybackDurations() {
        let attacks: [SoldierType: TimeInterval] = [
            .infantry: 1.2, .archer: 1.4, .cavalry: 1.2, .mage: 1.4, .siege: 1.6
        ]
        for (type, expected) in attacks {
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .attack, type: type) - expected) < 0.000_1)
        }
        for type in SoldierType.allCases {
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .walk, type: type) - 1.0) < 0.000_1)
            #expect(abs(SoldierAnimationTiming.totalDuration(for: .hit, type: type) - 0.9) < 0.000_1)
        }
    }

    @Test func attackMovesFasterThroughContactThanAnticipation() {
        let durations = SoldierAnimationTiming.frameDurations(for: .attack, type: .archer)
        #expect(durations[2] > durations[4])
        #expect(durations[7] > durations[4])
    }

    @Test func hitHoldsPeakReactionLongerThanNeutral() {
        let durations = SoldierAnimationTiming.frameDurations(for: .hit, type: .infantry)
        #expect(durations[3] > durations[0])
        #expect(durations[4] > durations[9])
    }
}
```

- [ ] **Step 2: Run timing tests and verify RED**

Use XcodeBuildMCP `session_show_defaults`, then:

```text
test_sim(extraArgs: [
  "-parallel-testing-enabled", "NO",
  "-only-testing:PyxisTests/SoldierAnimationTimingTests"
])
```

Expected: build failure because the timing types do not exist.

- [ ] **Step 3: Implement the timing model**

Create `Pyxis/SoldierAnimationTiming.swift`:

```swift
import Foundation

enum SoldierAnimationAction: String, CaseIterable, Hashable {
    case walk
    case attack
    case hit
}

struct SoldierAnimationTiming {
    static let frameCount = 10

    private static let attackWeights = [1.10, 1.20, 1.30, 0.75, 0.70, 0.85, 1.00, 1.15, 1.10, 0.85]
    private static let hitWeights = [0.90, 1.00, 1.10, 1.20, 1.20, 1.00, 0.95, 0.90, 0.90, 0.85]

    static func totalDuration(
        for action: SoldierAnimationAction,
        type: SoldierType
    ) -> TimeInterval {
        switch action {
        case .walk:
            1.0
        case .hit:
            0.9
        case .attack:
            switch type {
            case .infantry, .cavalry: 1.2
            case .archer, .mage: 1.4
            case .siege: 1.6
            }
        }
    }

    static func frameDurations(
        for action: SoldierAnimationAction,
        type: SoldierType
    ) -> [TimeInterval] {
        let weights: [Double]
        switch action {
        case .walk: weights = Array(repeating: 1, count: frameCount)
        case .attack: weights = attackWeights
        case .hit: weights = hitWeights
        }
        let unit = totalDuration(for: action, type: type) / weights.reduce(0, +)
        return weights.map { $0 * unit }
    }
}
```

- [ ] **Step 4: Write failing manifest tests for the current staged state**

Create `PyxisTests/SoldierAnimationManifestTests.swift`:

```swift
import Testing
@testable import Pyxis

struct SoldierAnimationManifestTests {
    @Test func currentApprovedActionsMatchInstalledArcherPilot() {
        #expect(SoldierAnimationManifest.isAuthored(.attack, for: .archer))
        #expect(SoldierAnimationManifest.isAuthored(.hit, for: .archer))
        #expect(!SoldierAnimationManifest.isAuthored(.walk, for: .archer))
        #expect(SoldierAnimationManifest.usesFullCanvas(for: .archer))

        for type in SoldierType.allCases where type != .archer {
            #expect(!SoldierAnimationManifest.usesFullCanvas(for: type))
            for action in SoldierAnimationAction.allCases {
                #expect(!SoldierAnimationManifest.isAuthored(action, for: type))
            }
        }
    }
}
```

- [ ] **Step 5: Run manifest tests and verify RED**

Use XcodeBuildMCP:

```text
test_sim(extraArgs: [
  "-parallel-testing-enabled", "NO",
  "-only-testing:PyxisTests/SoldierAnimationManifestTests"
])
```

Expected: build failure because `SoldierAnimationManifest` does not exist.

- [ ] **Step 6: Implement staged approval metadata**

Create `Pyxis/SoldierAnimationManifest.swift`:

```swift
struct SoldierAnimationManifest {
    private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
        .archer: [.attack, .hit]
    ]
    private static let fullCanvasTypes: Set<SoldierType> = [.archer]

    static func isAuthored(_ action: SoldierAnimationAction, for type: SoldierType) -> Bool {
        authoredActions[type]?.contains(action) == true
    }

    static func usesFullCanvas(for type: SoldierType) -> Bool {
        fullCanvasTypes.contains(type)
    }
}
```

- [ ] **Step 7: Run focused tests and commit**

Run both new test suites, then:

```bash
rtk git add Pyxis/SoldierAnimationTiming.swift Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationTimingTests.swift PyxisTests/SoldierAnimationManifestTests.swift
rtk git commit -m "feat: add soldier animation timing metadata"
```

Expected: both suites PASS.

---

### Task 3: Integrate Weighted Playback Into BattleScene

**Files:**
- Modify: `Pyxis/BattleScene.swift:75-110, 1964-2030, 2170-2180, 2631-2650, 2790-2940, 3430-3460`
- Modify: `PyxisTests/BattleSceneTests.swift:340-530`

**Interfaces:**
- Consumes: `SoldierAnimationTiming` and `SoldierAnimationManifest` from Task 2.
- Produces: weighted `SKAction` playback and type-specific delayed-removal durations.

- [ ] **Step 1: Replace old timing expectations with failing weighted expectations**

Update the timing test to assert:

```swift
for type in SoldierType.allCases {
    #expect(scene.soldierAnimationFrameDurationsForTesting(action: "walk", soldierType: type).count == 10)
    #expect(abs(scene.soldierAnimationDurationForTesting(action: "walk", soldierType: type) - 1.0) < 0.001)
    #expect(abs(scene.soldierAnimationDurationForTesting(action: "hit", soldierType: type) - 0.9) < 0.001)
}
#expect(abs(scene.soldierAnimationDurationForTesting(action: "attack", soldierType: .infantry) - 1.2) < 0.001)
#expect(abs(scene.soldierAnimationDurationForTesting(action: "attack", soldierType: .archer) - 1.4) < 0.001)
#expect(abs(scene.soldierAnimationDurationForTesting(action: "attack", soldierType: .cavalry) - 1.2) < 0.001)
#expect(abs(scene.soldierAnimationDurationForTesting(action: "attack", soldierType: .mage) - 1.4) < 0.001)
#expect(abs(scene.soldierAnimationDurationForTesting(action: "attack", soldierType: .siege) - 1.6) < 0.001)
```

Add a delayed-removal assertion:

```swift
for type in SoldierType.allCases {
    #expect(abs(scene.soldierDelayedRemovalWaitDurationForTesting(soldierType: type) - 0.9) < 0.001)
}
```

Add an interruption regression:

```swift
scene.spawnSoldierForTesting()
scene.triggerFirstLiveSoldierAnimationForTesting("attack")
#expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))

scene.triggerFirstLiveSoldierAnimationForTesting("hit")
#expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
#expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
```

- [ ] **Step 2: Run `BattleSceneTests` and verify RED**

Use XcodeBuildMCP:

```text
test_sim(extraArgs: [
  "-parallel-testing-enabled", "NO",
  "-only-testing:PyxisTests/BattleSceneTests"
])
```

Expected: compile failures for the new test helpers and old 0.8/1.0 timing behavior.

- [ ] **Step 3: Use manifest lookups and remove the nested action enum**

Delete the private `SoldierAnimationAction` declaration from `BattleScene`.
Replace the two approval helpers with:

```swift
private func usesAuthoredSoldierAnimation(
    for type: SoldierType,
    action: SoldierAnimationAction
) -> Bool {
    SoldierAnimationManifest.isAuthored(action, for: type)
}

private func usesFullCanvasSoldierTextures(for type: SoldierType) -> Bool {
    SoldierAnimationManifest.usesFullCanvas(for: type)
}
```

Delete the old uniform timing constants and `soldierAnimationTimePerFrame`.

- [ ] **Step 4: Build weighted texture actions**

Add:

```swift
private func soldierTextureAction(
    textures: [SKTexture],
    action: SoldierAnimationAction,
    type: SoldierType
) -> SKAction {
    let durations = SoldierAnimationTiming.frameDurations(for: action, type: type)
    let steps = zip(textures, durations).flatMap { texture, duration in
        [SKAction.setTexture(texture, resize: false), SKAction.wait(forDuration: duration)]
    }
    return SKAction.sequence(steps)
}
```

Use `SKAction.repeatForever(soldierTextureAction(... .walk ...))` for walk. Use
the same builder before the existing resume-walk closure for attack and hit.
Continue removing walk, attack, and hit keys before starting a transient.

- [ ] **Step 5: Use type-specific hit duration for killed soldiers**

In `scheduleDelayedSoldierRemoval`, replace the static wait with:

```swift
let duration = SoldierAnimationTiming.totalDuration(for: .hit, type: bundle.type)
let wait = SKAction.wait(forDuration: duration)
```

Replace the old test accessors with:

```swift
func soldierAnimationFrameDurationsForTesting(
    action: String,
    soldierType: SoldierType = .infantry
) -> [TimeInterval] {
    guard let action = SoldierAnimationAction(rawValue: action) else { return [] }
    return SoldierAnimationTiming.frameDurations(for: action, type: soldierType)
}

func soldierAnimationDurationForTesting(
    action: String,
    soldierType: SoldierType = .infantry
) -> TimeInterval {
    guard let action = SoldierAnimationAction(rawValue: action) else { return 0 }
    return SoldierAnimationTiming.totalDuration(for: action, type: soldierType)
}

func soldierDelayedRemovalWaitDurationForTesting(
    soldierType: SoldierType
) -> TimeInterval {
    SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
}

func triggerFirstLiveSoldierAnimationForTesting(_ rawAction: String) {
    guard let soldierID = firstLiveSoldierIDForTesting,
          let action = SoldierAnimationAction(rawValue: rawAction) else {
        return
    }
    playSoldierAnimation(action, for: soldierID, resumesWalk: true)
}
```

- [ ] **Step 6: Run focused and full tests, then commit**

Run `BattleSceneTests`, then all `PyxisTests` with parallel testing disabled.
Run:

```bash
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
rtk git commit -m "feat: use weighted soldier sprite playback"
```

Expected: focused and full tests PASS; SwiftLint exits zero with only existing warnings.

---

### Task 4: Regenerate And Cut Over The Archer Trio

**Files:**
- Modify: `Pyxis/SoldierAnimationManifest.swift`
- Modify: `PyxisTests/SoldierAnimationManifestTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Replace: `Pyxis/Assets.xcassets/archer-{walk,attack,hit}-*.imageset/*.png`

**Interfaces:**
- Consumes: approved archer attack/hit frames as identity references and the trio pipeline from Task 1.
- Produces: thirty approved archer frames and full authored manifest approval.

- [ ] **Step 1: Write the failing archer-trio approval test**

Change the archer manifest expectation to:

```swift
#expect(SoldierAnimationAction.allCases.allSatisfy {
    SoldierAnimationManifest.isAuthored($0, for: .archer)
})
#expect(SoldierAnimationManifest.usesFullCanvas(for: .archer))
```

In `BattleSceneTests`, require archer walk, attack, and hit texture arrays to be
pairwise distinct and require no procedural attack/hit feedback.

- [ ] **Step 2: Run manifest and battle tests and verify RED**

Expected: archer walk is not yet manifest-approved.

- [ ] **Step 3: Generate and review the canonical archer identity**

Inspect `archer-attack-01.png`, `archer-attack-10.png`, `archer-hit-01.png`, and
`archer-hit-10.png` with `view_image`. Call built-in image generation using those
files as references plus the Shared Image Prompt Contract and:

```text
Create one complete neutral archer reference on a perfectly flat solid #ff00ff
background. Preserve the approved green hood, brown hair and face, leather
layers, cape, quiver, arrows, and exact wooden bow design. Use a relaxed planted
stance suitable for the first and last frame of walk, attack, and hit. Center the
complete figure with generous padding and no cast shadow.
```

Copy the selected output to
`/private/tmp/pyxis-full-animation/archer-canonical.png`, inspect it, present it
to the user, and wait for approval before generating action boards.

- [ ] **Step 4: Generate all three archer storyboards**

Use the canonical image as the reference for three built-in image generation
calls. Each call includes both shared prompt contracts.

Walk addendum:

```text
Animate a smooth in-place walk: alternating planted steps, visible knee and arm
movement, restrained cape and quiver follow-through, and a stable torso and bow.
Frames 1-5 are the first half-cycle; frames 6-10 mirror the leg rhythm and return
to neutral. No vertical body bounce and no loose arrows.
```

Attack addendum:

```text
Animate a complete bow shot: neutral, shoulder settle, bow arm extension,
drawing elbow rise, hand to cheek at full draw, release, small arm/bow recoil,
follow-through, recovery, neutral. The body stays planted and the exact bow is
complete in every frame. Do not draw a detached fired arrow or trail.
```

Hit addendum:

```text
Animate a controlled hit reaction: recognition, shoulder collapse, torso
compression, tightened eyes and grimace, held peak posture, rebound, recovery,
neutral. Both feet remain planted and the archer retains the complete bow.
```

Save as `/private/tmp/pyxis-full-animation/archer-{walk,attack,hit}.png`.

- [ ] **Step 5: Slice to preview, validate, and obtain visual approval**

Run:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers archer --actions walk attack hit
```

Create contact sheets and 5-fps slowed GIFs for all three actions with ffmpeg,
save them under `build/animation-preview/qa/archer/`, inspect them, present them
together, and wait for user approval. Reject any identity change, body bounce,
equipment crop, frame bleed, or effect-heavy frame.

```bash
rtk mkdir -p build/animation-preview/qa/archer
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/archer-walk-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/archer/walk-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/archer-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/archer/attack-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/archer-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/archer/hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/archer-walk-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/archer/walk.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/archer-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/archer/attack.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/archer-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/archer/hit.gif
```

- [ ] **Step 6: Install the approved trio and update the manifest**

Run:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers archer --actions walk attack hit
```

Change:

```swift
.archer: Set(SoldierAnimationAction.allCases)
```

in `SoldierAnimationManifest.authoredActions`.

- [ ] **Step 7: Verify and commit**

Run pipeline tests, `SoldierAnimationManifestTests`, `BattleSceneTests`, all
`PyxisTests`, SwiftLint, and `git diff --check`. Build and launch with
XcodeBuildMCP against Xcode's configured DerivedData. Record simulator playback
showing archer walk, attack, and hit.

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationManifestTests.swift PyxisTests/BattleSceneTests.swift Pyxis/Assets.xcassets/archer-*.imageset/*.png
rtk git commit -m "feat: install approved archer animation trio"
```

Use XcodeBuildMCP `test_sim` first for `PyxisTests/SoldierAnimationManifestTests`,
then `PyxisTests/BattleSceneTests`, then all `PyxisTests`, always with
`["-parallel-testing-enabled", "NO"]`. Use `build_run_sim` after tests pass.

---

### Task 5: Regenerate And Cut Over The Infantry Trio

**Files:**
- Modify: `Pyxis/SoldierAnimationManifest.swift`
- Modify: `PyxisTests/SoldierAnimationManifestTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Replace: `Pyxis/Assets.xcassets/infantry-{walk,attack,hit}-*.imageset/*.png`

**Interfaces:**
- Consumes: infantry walk frame 1 for equipment semantics and the approved archer canonical for render quality.
- Produces: thirty approved infantry frames and infantry manifest approval.

- [ ] **Step 1: Write and run the failing infantry approval tests**

Require all three infantry actions to be authored, full-canvas rendering to be
enabled, all three texture arrays to be distinct, and procedural attack/hit
feedback to be absent for infantry. Run manifest and battle suites.

```swift
for action in SoldierAnimationAction.allCases {
    #expect(SoldierAnimationManifest.isAuthored(action, for: .infantry))
}
#expect(SoldierAnimationManifest.usesFullCanvas(for: .infantry))
```

Expected: FAIL because infantry is still unapproved and aliases transient
textures to walk.

- [ ] **Step 2: Generate and approve the canonical infantry identity**

Inspect `infantry-walk-01.png` and the approved archer canonical. Call built-in
image generation with those references, the Shared Image Prompt Contract, and:

```text
Create one complete neutral infantry reference on a perfectly flat solid
#00ff00 background. Preserve the recognizable blue-plumed helmet, silver armor,
blue-and-gold shield, short silver sword, brown hair, and open chibi face from
the infantry concept. Render it with the approved archer's detail, outline,
materials, lighting, and proportions without borrowing the archer's clothing or
green palette. Use a planted guarded stance with complete sword and shield.
```

Save to `/private/tmp/pyxis-full-animation/infantry-canonical.png`, inspect it,
present it, and wait for approval.

- [ ] **Step 3: Generate the infantry walk, attack, and hit storyboards**

Use the canonical reference and shared contracts.

Walk:

```text
Animate a smooth armored in-place walk with alternating planted steps, restrained
opposite arm movement, small attached plume follow-through, and stable sword and
shield. Keep torso height level and return to the same guard stance.
```

Attack:

```text
Animate neutral guard, compact sword wind-up, planted front foot, visible weight
transfer, diagonal sword strike, wrist and shoulder follow-through, rebound,
return behind the shield, and neutral. No slash effect.
```

Hit:

```text
Animate recognition, shield turn toward impact, compressed knees and torso,
brief facial grimace, held guarded recoil, rebound, regain guard, and neutral.
Keep both feet planted and retain the exact sword and shield.
```

Save to `/private/tmp/pyxis-full-animation/infantry-{walk,attack,hit}.png`.

- [ ] **Step 4: Preview, validate, review, and install the complete trio**

Run the trio slicer to `build/animation-preview/Assets.xcassets`, create three
contact sheets and three 5-fps GIFs under `build/animation-preview/qa/infantry/`,
present them together, and wait for approval. Then rerun the atomic slicer to
`Pyxis/Assets.xcassets` and add infantry with all actions to both manifest sets.

Update the manifest collections to:

```swift
private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
    .archer: Set(SoldierAnimationAction.allCases),
    .infantry: Set(SoldierAnimationAction.allCases)
]
private static let fullCanvasTypes: Set<SoldierType> = [.archer, .infantry]
```

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers infantry --actions walk attack hit
rtk mkdir -p build/animation-preview/qa/infantry
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/infantry-walk-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/infantry/walk-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/infantry-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/infantry/attack-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/infantry-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/infantry/hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/infantry-walk-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/infantry/walk.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/infantry-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/infantry/attack.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/infantry-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/infantry/hit.gif
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers infantry --actions walk attack hit
```

- [ ] **Step 5: Verify and commit**

Run pipeline tests, focused manifest tests, focused battle tests, all
`PyxisTests`, SwiftLint, and `git diff --check`. Then use XcodeBuildMCP
`build_run_sim` and record infantry walk, attack, and hit in the simulator.

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationManifestTests.swift PyxisTests/BattleSceneTests.swift Pyxis/Assets.xcassets/infantry-*.imageset/*.png
rtk git commit -m "feat: install approved infantry animation trio"
```

Use XcodeBuildMCP `test_sim` for `PyxisTests/SoldierAnimationManifestTests`,
`PyxisTests/BattleSceneTests`, and all `PyxisTests`, each with parallel testing
disabled.

---

### Task 6: Regenerate And Cut Over The Cavalry Trio

**Files:**
- Modify: `Pyxis/SoldierAnimationManifest.swift`
- Modify: `PyxisTests/SoldierAnimationManifestTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Replace: `Pyxis/Assets.xcassets/cavalry-{walk,attack,hit}-*.imageset/*.png`

**Interfaces:**
- Consumes: cavalry walk frame 1 for equipment semantics and the approved archer canonical for render quality.
- Produces: thirty approved cavalry frames and cavalry manifest approval.

- [ ] **Step 1: Write and run failing cavalry approval tests**

Require all cavalry actions authored, full canvas, distinct textures, and no
procedural attack/hit feedback. Run manifest and battle suites.

```swift
for action in SoldierAnimationAction.allCases {
    #expect(SoldierAnimationManifest.isAuthored(action, for: .cavalry))
}
#expect(SoldierAnimationManifest.usesFullCanvas(for: .cavalry))
```

Expected: FAIL because cavalry remains on walk fallback.

- [ ] **Step 2: Generate and approve the canonical cavalry identity**

Inspect `cavalry-walk-01.png` and the approved archer canonical. Generate with
the Shared Image Prompt Contract plus:

```text
Create one complete neutral cavalry reference on a perfectly flat solid #00ff00
background. Preserve the small white horse, silver-armored rider, orange plume,
orange-and-gold tack, reins, and complete lance from the cavalry concept. Match
the approved archer rendering quality without changing role colors or equipment.
The horse stands square and grounded; rider, mount, reins, and lance form one
coherent unit with generous padding.
```

Save as `/private/tmp/pyxis-full-animation/cavalry-canonical.png`, inspect,
present, and wait for approval.

- [ ] **Step 3: Generate the cavalry action boards**

Walk:

```text
Animate a controlled in-place horse walk with alternating hoof steps, subtle leg
articulation, rider hips following the saddle, and restrained rein and plume
motion. Keep the mount's body level; no hop or whole-unit bob.
```

Attack:

```text
Animate neutral riding stance, rider grip and shoulder preparation, lance lower,
horse brace, one controlled forward step, lance drive, held commitment, rebound,
lance recovery, and neutral. No full-sprite leap or speed effect.
```

Hit:

```text
Animate recognition, horse checking its step, rider absorbing impact through
seat and reins, brief rider grimace, held recoil, controlled rebound, restored
reins and lance, and neutral. Keep hooves grounded.
```

Save as `/private/tmp/pyxis-full-animation/cavalry-{walk,attack,hit}.png`.

- [ ] **Step 4: Preview, validate, review, and install**

Run the atomic preview pipeline, create and inspect the three cavalry contact
sheets and slowed GIFs, present them together, and wait for approval. Install to
the runtime catalog only afterward; approve all cavalry actions and full canvas
in the manifest.

Update the manifest collections to:

```swift
private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
    .archer: Set(SoldierAnimationAction.allCases),
    .infantry: Set(SoldierAnimationAction.allCases),
    .cavalry: Set(SoldierAnimationAction.allCases)
]
private static let fullCanvasTypes: Set<SoldierType> = [.archer, .infantry, .cavalry]
```

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers cavalry --actions walk attack hit
rtk mkdir -p build/animation-preview/qa/cavalry
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/cavalry-walk-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/cavalry/walk-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/cavalry-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/cavalry/attack-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/cavalry-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/cavalry/hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/cavalry-walk-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/cavalry/walk.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/cavalry-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/cavalry/attack.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/cavalry-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/cavalry/hit.gif
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers cavalry --actions walk attack hit
```

- [ ] **Step 5: Verify and commit**

Run pipeline tests, `SoldierAnimationManifestTests`, `BattleSceneTests`, all
`PyxisTests`, SwiftLint, and `git diff --check`. Use XcodeBuildMCP with parallel
testing disabled, then build, launch, and record cavalry walk, attack, and hit.

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationManifestTests.swift PyxisTests/BattleSceneTests.swift Pyxis/Assets.xcassets/cavalry-*.imageset/*.png
rtk git commit -m "feat: install approved cavalry animation trio"
```

---

### Task 7: Regenerate And Cut Over The Mage Trio

**Files:**
- Modify: `Pyxis/SoldierAnimationManifest.swift`
- Modify: `PyxisTests/SoldierAnimationManifestTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Replace: `Pyxis/Assets.xcassets/mage-{walk,attack,hit}-*.imageset/*.png`

**Interfaces:**
- Consumes: mage walk frame 1 for equipment semantics and the approved archer canonical for render quality.
- Produces: thirty approved mage frames and mage manifest approval.

- [ ] **Step 1: Write and run failing mage approval tests**

Require all mage actions authored, full canvas, distinct textures, and no
procedural attack/hit feedback. Run manifest and battle suites.

```swift
for action in SoldierAnimationAction.allCases {
    #expect(SoldierAnimationManifest.isAuthored(action, for: .mage))
}
#expect(SoldierAnimationManifest.usesFullCanvas(for: .mage))
```

Expected: FAIL because mage remains on walk fallback.

- [ ] **Step 2: Generate and approve the canonical mage identity**

Inspect `mage-walk-01.png` and the approved archer canonical. Generate with the
Shared Image Prompt Contract plus:

```text
Create one complete neutral mage reference on a perfectly flat solid #00ff00
background. Preserve the purple hood and robe, gold trim, brown hair, open chibi
face, and complete staff with purple crystal from the mage concept. Match the
approved archer's detail, outline, materials, lighting, and proportions without
changing the mage palette. Use a planted staff-bearing stance.
```

Save as `/private/tmp/pyxis-full-animation/mage-canonical.png`, inspect, present,
and wait for approval.

- [ ] **Step 3: Generate the mage action boards**

Walk:

```text
Animate a smooth small-step in-place walk with alternating feet, natural free-arm
movement, restrained robe and hood follow-through, and stable staff control.
Keep head and torso level and return to neutral.
```

Attack:

```text
Animate neutral, plant the staff, gather with the free hand, raise and direct the
staff, peak cast posture, controlled staff recoil, follow-through, lower the free
hand, settle, and neutral. A tiny staff-tip glow is allowed only at peak; no aura
or projectile.
```

Hit:

```text
Animate recognition, interrupted casting posture, face tightening into a
grimace, free arm folding inward, shoulders compressing, held recoil, rebound,
restore staff stance, settle, and neutral. Both feet stay planted.
```

Save as `/private/tmp/pyxis-full-animation/mage-{walk,attack,hit}.png`.

- [ ] **Step 4: Preview, validate, review, and install**

Run the atomic preview pipeline, create all mage contact sheets and slowed GIFs,
present them together, and wait for approval. Install only the approved trio;
then approve all mage actions and full canvas in the manifest.

Update the manifest collections to:

```swift
private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
    .archer: Set(SoldierAnimationAction.allCases),
    .infantry: Set(SoldierAnimationAction.allCases),
    .cavalry: Set(SoldierAnimationAction.allCases),
    .mage: Set(SoldierAnimationAction.allCases)
]
private static let fullCanvasTypes: Set<SoldierType> = [.archer, .infantry, .cavalry, .mage]
```

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers mage --actions walk attack hit
rtk mkdir -p build/animation-preview/qa/mage
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/mage-walk-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/mage/walk-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/mage-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/mage/attack-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/mage-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/mage/hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/mage-walk-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/mage/walk.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/mage-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/mage/attack.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/mage-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/mage/hit.gif
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers mage --actions walk attack hit
```

- [ ] **Step 5: Verify and commit**

Run pipeline tests, `SoldierAnimationManifestTests`, `BattleSceneTests`, all
`PyxisTests`, SwiftLint, and `git diff --check`. Use XcodeBuildMCP with parallel
testing disabled, then build, launch, and record mage walk, attack, and hit.

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationManifestTests.swift PyxisTests/BattleSceneTests.swift Pyxis/Assets.xcassets/mage-*.imageset/*.png
rtk git commit -m "feat: install approved mage animation trio"
```

---

### Task 8: Regenerate And Cut Over The Siege Trio

**Files:**
- Modify: `Pyxis/SoldierAnimationManifest.swift`
- Modify: `PyxisTests/SoldierAnimationManifestTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Replace: `Pyxis/Assets.xcassets/siege-{walk,attack,hit}-*.imageset/*.png`

**Interfaces:**
- Consumes: siege walk frame 1 for equipment semantics and the approved archer canonical for render quality.
- Produces: thirty approved siege frames and final all-type manifest approval.

- [ ] **Step 1: Write and run failing siege approval tests**

Require all siege actions authored, full canvas, distinct textures, and no
procedural attack/hit feedback. Add a manifest assertion that every type and
action is approved. Run manifest and battle suites.

```swift
for type in SoldierType.allCases {
    for action in SoldierAnimationAction.allCases {
        #expect(SoldierAnimationManifest.isAuthored(action, for: type))
    }
    #expect(SoldierAnimationManifest.usesFullCanvas(for: type))
}
```

Expected: FAIL because siege remains on walk fallback.

- [ ] **Step 2: Generate and approve the canonical siege identity**

Inspect `siege-walk-01.png` and the approved archer canonical. Generate with the
Shared Image Prompt Contract plus:

```text
Create one complete neutral siege reference on a perfectly flat solid #00ff00
background. Preserve the compact gray cannon, wooden-and-metal wheels, chassis,
helmeted operator, blue clothing accents, and hand controls from the siege
concept. Match the approved archer's detail, outline, materials, lighting, and
proportions while keeping the mechanism readable. Wheels share one baseline and
the complete unit has generous padding.
```

Save as `/private/tmp/pyxis-full-animation/siege-canonical.png`, inspect,
present, and wait for approval.

- [ ] **Step 3: Generate the siege action boards**

Walk:

```text
Animate grounded in-place travel: wheels rotate in a readable alternating cycle,
operator legs and hands follow the mechanism, and attached equipment shifts
slightly. Keep the chassis level with no whole-unit bounce.
```

Attack:

```text
Animate neutral, operator brace, grip mechanism, operate cannon controls, peak
mechanical release, short grounded chassis recoil, operator absorbs recoil,
mechanism reset, settle, and neutral. No muzzle flash, smoke, or explosion.
```

Hit:

```text
Animate recognition, operator brace and grimace, short chassis jolt, compressed
operator posture, held peak recoil, mechanical rebound, wheel and control
settling, restored stance, and neutral. Keep wheels grounded and retain every
mechanism part.
```

Save as `/private/tmp/pyxis-full-animation/siege-{walk,attack,hit}.png`.

- [ ] **Step 4: Preview, validate, review, and install**

Run the atomic preview pipeline, create all siege contact sheets and slowed GIFs,
present them together, and wait for approval. Install only after approval; then
approve all siege actions and full canvas in the manifest.

Update the manifest collections to:

```swift
private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
    .archer: Set(SoldierAnimationAction.allCases),
    .infantry: Set(SoldierAnimationAction.allCases),
    .cavalry: Set(SoldierAnimationAction.allCases),
    .mage: Set(SoldierAnimationAction.allCases),
    .siege: Set(SoldierAnimationAction.allCases)
]
private static let fullCanvasTypes: Set<SoldierType> = Set(SoldierType.allCases)
```

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers siege --actions walk attack hit
rtk mkdir -p build/animation-preview/qa/siege
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/siege-walk-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/siege/walk-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/siege-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/siege/attack-contact.png
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/siege-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/siege/hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/siege-walk-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/siege/walk.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/siege-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/siege/attack.gif
rtk ffmpeg -y -loglevel error -framerate 5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/siege-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/siege/hit.gif
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers siege --actions walk attack hit
```

- [ ] **Step 5: Verify and commit**

Run pipeline tests, `SoldierAnimationManifestTests`, `BattleSceneTests`, all
`PyxisTests`, SwiftLint, and `git diff --check`. Use XcodeBuildMCP with parallel
testing disabled, then build, launch, and record siege walk, attack, and hit.

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
rtk git diff --check
rtk git add Pyxis/SoldierAnimationManifest.swift PyxisTests/SoldierAnimationManifestTests.swift PyxisTests/BattleSceneTests.swift Pyxis/Assets.xcassets/siege-*.imageset/*.png
rtk git commit -m "feat: install approved siege animation trio"
```

---

### Task 9: Remove Legacy Procedural Animation And Run Final Verification

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-07-12-soldier-full-animation-redesign-design.md`

**Interfaces:**
- Consumes: manifest state where every soldier and action is approved.
- Produces: authored-only runtime with no legacy pose/effect fallback.

- [ ] **Step 1: Confirm the full authored test suite is green before refactoring**

Run `SoldierAnimationManifestTests`, `SoldierAnimationTimingTests`, and
`BattleSceneTests`. Confirm all five types use distinct action textures, full
canvas, weighted timing, and no procedural overlay.

- [ ] **Step 2: Remove unreachable legacy presentation code**

Delete procedural attack cue, attack pose/part builders, stable attack root
motion, hit expression/posture builders, stable hit root motion, their effect
names, their action keys, and their test-only geometry accessors. Simplify
`playSoldierAttackFeedback` and `playSoldierHitFeedback` to authored playback plus
removal scheduling. Keep city impact feedback and tower projectile rendering.

Delete fallback branches in `soldierAnimationTextures`; incomplete installed
sets should return an empty array and fail tests rather than silently aliasing to
walk after all assets are approved.

- [ ] **Step 3: Update tests after the green refactor**

Remove tests that assert legacy motion magnitude or overlay node presence. Keep
and broaden tests that assert:

```swift
for type in SoldierType.allCases {
    for action in SoldierAnimationAction.allCases {
        #expect(scene.cachedSoldierAnimationTexturesForTesting(
            soldierType: type,
            action: action.rawValue
        ).count == 10)
    }
    #expect(scene.animationFrameCropForTesting(
        soldierType: type,
        action: SoldierAnimationAction.walk.rawValue
    ) == CGRect(x: 0, y: 0, width: 1, height: 1))
}
```

- [ ] **Step 4: Document the final contract**

Update `CLAUDE.md` to state that all walk, attack, and hit frames use the
validated 5-by-2 storyboard, 128-pixel output, complete-trio atomic install, and
weighted playback model. Change the new design spec status from `Approved` to
`Implemented` only after every final gate passes.

- [ ] **Step 5: Run the complete verification stack**

1. `rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips`
2. XcodeBuildMCP `test_sim` for all `PyxisTests`, parallel disabled.
3. XcodeBuildMCP `test_sim` for all `PyxisUITests`, parallel disabled.
4. `rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache`
5. `rtk git diff --check`
6. XcodeBuildMCP `build_run_sim` using the configured Xcode DerivedData.
7. Record and inspect one simulator video that shows all five types walking,
   attacking, and being hit without body bounce, style changes, clipping, or
   stale assets.

- [ ] **Step 6: Commit final cleanup**

```bash
rtk git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift CLAUDE.md docs/superpowers/specs/2026-07-12-soldier-full-animation-redesign-design.md
rtk git commit -m "refactor: remove legacy soldier animation effects"
```

Expected final state: 150 approved 128-by-128 frames, all tests green, changed
Swift files lint-clean, simulator playback matches QA previews, and no unrelated
worktree changes staged.
