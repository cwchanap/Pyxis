# Soldier Action Animation Redesign Implementation Plan

> **Superseded timing contract:** The attack and hit durations in Global
> Constraints (infantry/archer/cavalry/mage/siege attack and the 0.80 s hit)
> were revised by `docs/superpowers/specs/2026-07-12-soldier-full-animation-redesign-design.md`.
> The final, authoritative values live in `Pyxis/SoldierAnimationTiming.swift`
> (attack: infantry/cavalry 1.2 s, archer/mage 1.4 s, siege 1.6 s; hit 0.9 s;
> walk 1.0 s) and its tests. Treat any remaining timing text below as
> historical, not a directive to restore the older values.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every soldier attack and hit animation with identity-consistent, naturally posed 10-frame art that cannot bleed across frame boundaries, then play those full-canvas frames without procedural pose overlays.

**Architecture:** A storyboard-aware Python pipeline splits a fixed central 5-by-2 square-cell grid, validates gutters and sequence geometry, and writes complete 128-by-128 RGBA image sets atomically. A small CoreGraphics-only `SoldierAnimationGeometry` value type preserves the current visible body height while SpriteKit displays the complete frame canvas. Assets are generated and reviewed per soldier while runtime still uses the stable fallback; `BattleScene` switches to action-specific textures only after all ten transient sets pass validation.

**Tech Stack:** Swift 5, SpriteKit, Swift Testing, Python 3, Pillow, built-in image generation, ffmpeg, XcodeBuildMCP, SwiftLint

## Global Constraints

- Run every shell command through the repository-required `rtk` prefix.
- Keep all 150 final walk, attack, and hit frames at exactly 128 by 128 pixels.
- Replace attack and hit only: 5 soldier types times 2 actions times 10 frames equals 100 regenerated frames.
- Preserve current walk artwork as the identity, costume, palette, equipment, body-scale, and baseline reference.
- Use one centered 5-column by 2-row grid of square cells; frame order is row-major.
- Reserve the outer 8 percent of every cell for key color and reject artwork that enters it.
- Use `#ff00ff` for archer source boards and `#00ff00` for infantry, cavalry, mage, and siege.
- Generate one action board per built-in image-generation call; do not use CLI image generation without new user authorization.
- Keep source boards and QA previews under `/private/tmp` or ignored `build/`; commit only final frame assets.
- Do not change combat formulas, attack speed, targeting, range, HP, movement, spawning, or battle layout.
- Remove procedural limbs, weapons, facial marks, posture strokes, slash arcs, and exaggerated root movement after authored assets are installed.
- Attack durations are infantry 0.90 s, archer 0.90 s, cavalry 0.80 s, mage 1.00 s, and siege 1.40 s; hit duration is 0.80 s for every type.
- Disable parallel Xcode testing with `-parallel-testing-enabled NO`.
- Do not edit `project.pbxproj`; synchronized root groups discover new Swift files automatically.

## File Map

| File | Responsibility |
| --- | --- |
| `tools/slice_soldier_animation_strips.py` | Preserve legacy strip slicing; add fixed-grid storyboard extraction, chroma removal, validation, selection flags, and atomic writes. |
| `tools/tests/test_slice_soldier_animation_strips.py` | Pin cell boundaries, gutter rejection, scale/density/baseline checks, and all-or-nothing output. |
| `Pyxis/SoldierAnimationGeometry.swift` | Pure normalized full-canvas body geometry and sizing for each soldier type. |
| `PyxisTests/SoldierAnimationGeometryTests.swift` | Verify current visible body size and baseline remain stable on a full canvas. |
| `Pyxis/BattleScene.swift` | Resolve action-specific textures, size complete canvases, position HP bars from logical bodies, use per-type timings, and remove procedural pose overlays. |
| `PyxisTests/BattleSceneTests.swift` | Replace workaround assertions with full-canvas, distinct-action, timing, interruption, fallback, and no-overlay regressions. |
| `Pyxis/Assets.xcassets/{infantry,archer,cavalry,mage,siege}-attack-*.imageset/*.png` | Ten regenerated attack frames for each soldier type. |
| `Pyxis/Assets.xcassets/{infantry,archer,cavalry,mage,siege}-hit-*.imageset/*.png` | Ten regenerated hit frames for each soldier type. |
| `CLAUDE.md` | Record the canonical 5-by-2 storyboard and fixed-cell slicing contract. |

---

### Task 1: Fixed Storyboard Cell Extraction

**Files:**
- Modify: `tools/slice_soldier_animation_strips.py:1-175`
- Create: `tools/tests/test_slice_soldier_animation_strips.py`

**Interfaces:**
- Consumes: Pillow `Image.Image`; key colors as `(red, green, blue, alpha)` tuples.
- Produces: `storyboard_cells(image: Image.Image, key: RGBAColor) -> list[Image.Image]`, returning ten complete square cells in row-major order without content-based cropping.

- [ ] **Step 1: Write the failing fixed-cell tests**

Create `tools/tests/test_slice_soldier_animation_strips.py` with import setup and these tests:

```python
from __future__ import annotations

import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import slice_soldier_animation_strips as pipeline


KEY = (0, 255, 0, 255)


def make_board(cell_size: int = 40) -> tuple[Image.Image, list[tuple[int, int, int, int]]]:
    width = cell_size * 5 - 1  # Force the production right-padding path.
    height = cell_size * 4
    board = Image.new("RGBA", (width, height), KEY)
    normalized_width = width + 1
    top = (height - cell_size * 2) // 2
    colors = [
        (20 + index * 20, 40 + index * 7, 220 - index * 15, 255)
        for index in range(10)
    ]
    draw = ImageDraw.Draw(board)
    for index, color in enumerate(colors):
        column = index % 5
        row = index // 5
        left = column * (normalized_width // 5)
        upper = top + row * cell_size
        draw.rectangle((left + 8, upper + 8, left + 31, upper + 31), fill=color)
    return board, colors


def make_metric_board(boxes: list[tuple[int, int, int, int]]) -> Image.Image:
    cell_size = 64
    width = cell_size * 5
    height = cell_size * 4
    top = cell_size
    board = Image.new("RGBA", (width, height), KEY)
    draw = ImageDraw.Draw(board)
    for index, box in enumerate(boxes):
        column = index % 5
        row = index // 5
        left = column * cell_size
        upper = top + row * cell_size
        translated = (
            left + box[0], upper + box[1], left + box[2], upper + box[3]
        )
        draw.rectangle(translated, fill=(30, 80, 220, 255))
    return board


class StoryboardCellTests(unittest.TestCase):
    def test_extracts_ten_square_cells_in_row_major_order(self) -> None:
        board, colors = make_board()

        cells = pipeline.storyboard_cells(board, KEY)

        self.assertEqual(len(cells), 10)
        self.assertTrue(all(cell.size == (40, 40) for cell in cells))
        for index, cell in enumerate(cells):
            self.assertEqual(cell.getpixel((20, 20)), colors[index])

    def test_neighbor_colors_never_enter_another_cell(self) -> None:
        board, colors = make_board()

        cells = pipeline.storyboard_cells(board, KEY)

        for index, cell in enumerate(cells):
            present = set(cell.getdata())
            self.assertIn(colors[index], present)
            for other_index, color in enumerate(colors):
                if other_index != index:
                    self.assertNotIn(color, present)

    def test_rejects_canvas_too_short_for_two_square_rows(self) -> None:
        board = Image.new("RGBA", (500, 199), KEY)

        with self.assertRaisesRegex(ValueError, "two square rows"):
            pipeline.storyboard_cells(board, KEY)
```

- [ ] **Step 2: Run the tests and verify RED**

Run:

```bash
rtk python3 -m unittest discover -s tools/tests -p 'test_slice_soldier_animation_strips.py' -v
```

Expected: FAIL because `storyboard_cells` does not exist.

- [ ] **Step 3: Implement deterministic grid extraction**

Add these definitions to `tools/slice_soldier_animation_strips.py` without changing legacy `slice_strip` behavior:

```python
from typing import TypeAlias

RGBAColor: TypeAlias = tuple[int, int, int, int]
STORYBOARD_COLUMNS = 5
STORYBOARD_ROWS = 2


def _normalized_storyboard(image: Image.Image, key: RGBAColor) -> Image.Image:
    rgba = image.convert("RGBA")
    remainder = rgba.width % STORYBOARD_COLUMNS
    if remainder == 0:
        return rgba

    padding = STORYBOARD_COLUMNS - remainder
    normalized = Image.new("RGBA", (rgba.width + padding, rgba.height), key)
    normalized.alpha_composite(rgba, (0, 0))
    return normalized


def storyboard_cells(image: Image.Image, key: RGBAColor) -> list[Image.Image]:
    normalized = _normalized_storyboard(image, key)
    cell_size = normalized.width // STORYBOARD_COLUMNS
    grid_height = cell_size * STORYBOARD_ROWS
    if normalized.height < grid_height:
        raise ValueError(
            f"storyboard height {normalized.height} cannot contain two square rows "
            f"of {cell_size}px cells"
        )

    top = (normalized.height - grid_height) // 2
    cells: list[Image.Image] = []
    for row in range(STORYBOARD_ROWS):
        for column in range(STORYBOARD_COLUMNS):
            left = column * cell_size
            upper = top + row * cell_size
            cells.append(normalized.crop((left, upper, left + cell_size, upper + cell_size)))
    return cells
```

- [ ] **Step 4: Run the fixed-cell tests and verify GREEN**

Run the same unittest discovery command. Expected: 3 tests PASS.

- [ ] **Step 5: Commit the extraction contract**

```bash
rtk git add tools/slice_soldier_animation_strips.py tools/tests/test_slice_soldier_animation_strips.py
rtk git commit -m "test: prevent soldier storyboard frame bleed"
```

---

### Task 2: Storyboard Validation And Atomic Output

**Files:**
- Modify: `tools/slice_soldier_animation_strips.py`
- Modify: `tools/tests/test_slice_soldier_animation_strips.py`

**Interfaces:**
- Consumes: `storyboard_cells`, `SOLDIERS`, `ACTIONS`, source files named `<soldier>-<action>.png`.
- Produces: `prepare_storyboard_frames(image, soldier) -> list[Image.Image]`; CLI options `--storyboards-dir`, `--soldiers`, `--actions`; complete `.imageset` replacement only after all ten frames validate.

- [ ] **Step 1: Add failing validator tests**

Append tests that exercise the exact design thresholds:

```python
class StoryboardValidationTests(unittest.TestCase):
    def test_rejects_art_inside_reserved_cell_border(self) -> None:
        board, _ = make_board()
        normalized = pipeline._normalized_storyboard(board, KEY)
        cell_size = normalized.width // 5
        top = (normalized.height - cell_size * 2) // 2
        ImageDraw.Draw(normalized).point((1, top + cell_size // 2), fill=(255, 0, 0, 255))

        with self.assertRaisesRegex(ValueError, "reserved gutter"):
            pipeline.prepare_storyboard_frames(normalized, soldier="infantry")

    def test_prepared_frames_keep_transparent_border_and_fixed_size(self) -> None:
        board, _ = make_board()

        frames = pipeline.prepare_storyboard_frames(board, soldier="infantry")

        self.assertEqual(len(frames), 10)
        for frame in frames:
            self.assertEqual(frame.mode, "RGBA")
            self.assertEqual(frame.size, (128, 128))
            for x in range(128):
                self.assertEqual(frame.getpixel((x, 0))[3], 0)
                self.assertEqual(frame.getpixel((x, 127))[3], 0)

    def test_invalid_sequence_does_not_replace_existing_assets(self) -> None:
        from tempfile import TemporaryDirectory

        board, _ = make_board()
        normalized = pipeline._normalized_storyboard(board, KEY)
        cell_size = normalized.width // 5
        top = (normalized.height - cell_size * 2) // 2
        ImageDraw.Draw(normalized).rectangle((0, top, 7, top + 7), fill=(255, 0, 0, 255))

        with TemporaryDirectory() as directory:
            output = Path(directory)
            sentinel = output / "infantry-attack-01.imageset" / "sentinel.txt"
            sentinel.parent.mkdir(parents=True)
            sentinel.write_text("keep", encoding="utf-8")

            with self.assertRaises(ValueError):
                pipeline.slice_storyboard(normalized, output, "infantry", "attack", 128)

            self.assertEqual(sentinel.read_text(encoding="utf-8"), "keep")

    def test_rejects_low_density_outlier(self) -> None:
        boxes = [(16, 16, 47, 47)] * 10
        boxes[4] = (28, 28, 35, 35)
        with self.assertRaisesRegex(ValueError, "opaque pixel count"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")

    def test_rejects_high_density_outlier(self) -> None:
        boxes = [(20, 16, 43, 47)] * 10
        boxes[4] = (6, 6, 57, 57)
        with self.assertRaisesRegex(ValueError, "opaque pixel count"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")

    def test_rejects_height_outlier_even_when_density_is_normal(self) -> None:
        boxes = [(20, 16, 43, 47)] * 10
        boxes[4] = (6, 24, 57, 39)
        with self.assertRaisesRegex(ValueError, "bounding-box height"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")

    def test_rejects_baseline_drift_greater_than_six_output_pixels(self) -> None:
        boxes = [(16, 16, 47, 47)] * 10
        boxes[4] = (16, 8, 47, 39)
        with self.assertRaisesRegex(ValueError, "baseline"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")
```

- [ ] **Step 2: Run validator tests and verify RED**

Run unittest discovery. Expected: FAIL because `prepare_storyboard_frames` and `slice_storyboard` do not exist.

- [ ] **Step 3: Implement key selection, gutters, chroma removal, and metrics**

Add exact constants and route every frame through one validation path:

```python
STORYBOARD_BORDER_FRACTION = 0.08
KEY_CHANNEL_TOLERANCE = 12
TRANSPARENT_THRESHOLD = 12
OPAQUE_THRESHOLD = 220
MIN_DENSITY_RATIO = 0.60
MAX_DENSITY_RATIO = 1.50
MIN_HEIGHT_RATIO = 0.70
MAX_HEIGHT_RATIO = 1.30
MAX_BASELINE_DELTA = 6

SOLDIER_KEYS: dict[str, RGBAColor] = {
    "infantry": (0, 255, 0, 255),
    "archer": (255, 0, 255, 255),
    "cavalry": (0, 255, 0, 255),
    "mage": (0, 255, 0, 255),
    "siege": (0, 255, 0, 255),
}


def _channel_distance(pixel: tuple[int, int, int, int], key: RGBAColor) -> int:
    return max(abs(pixel[index] - key[index]) for index in range(3))


def _remove_key(cell: Image.Image, key: RGBAColor) -> Image.Image:
    output = cell.convert("RGBA")
    pixels = output.load()
    for y in range(output.height):
        for x in range(output.width):
            red, green, blue, alpha = pixels[x, y]
            distance = _channel_distance((red, green, blue, alpha), key)
            if distance <= TRANSPARENT_THRESHOLD:
                pixels[x, y] = (red, green, blue, 0)
                continue
            if distance >= OPAQUE_THRESHOLD:
                continue
            matte = int(255 * (distance - TRANSPARENT_THRESHOLD) / (OPAQUE_THRESHOLD - TRANSPARENT_THRESHOLD))
            if key[1] > key[0] and key[1] > key[2]:
                green = min(green, max(red, blue) + 28)
            elif key[0] > key[1] and key[2] > key[1]:
                excess = max(0, min(red, blue) - green - 28)
                red = max(0, red - excess)
                blue = max(0, blue - excess)
            pixels[x, y] = (red, green, blue, min(alpha, matte))
    return output


def _storyboard_geometry(
    image: Image.Image, key: RGBAColor
) -> tuple[Image.Image, int, int]:
    normalized = _normalized_storyboard(image, key)
    cell_size = normalized.width // STORYBOARD_COLUMNS
    grid_height = cell_size * STORYBOARD_ROWS
    if normalized.height < grid_height:
        raise ValueError(
            f"storyboard height {normalized.height} cannot contain two square rows "
            f"of {cell_size}px cells"
        )
    return normalized, cell_size, (normalized.height - grid_height) // 2


def _assert_key_region(
    image: Image.Image, box: tuple[int, int, int, int], key: RGBAColor, label: str
) -> None:
    left, top, right, bottom = box
    pixels = image.load()
    for y in range(top, bottom):
        for x in range(left, right):
            if _channel_distance(pixels[x, y], key) > KEY_CHANNEL_TOLERANCE:
                raise ValueError(f"{label}: non-key artwork entered reserved gutter at ({x}, {y})")


def _validate_source_gutters(
    image: Image.Image, cell_size: int, grid_top: int, key: RGBAColor
) -> None:
    _assert_key_region(image, (0, 0, image.width, grid_top), key, "outer canvas")
    grid_bottom = grid_top + cell_size * STORYBOARD_ROWS
    _assert_key_region(image, (0, grid_bottom, image.width, image.height), key, "outer canvas")

    border = max(1, int(round(cell_size * STORYBOARD_BORDER_FRACTION)))
    for index in range(10):
        column = index % STORYBOARD_COLUMNS
        row = index // STORYBOARD_COLUMNS
        left = column * cell_size
        top = grid_top + row * cell_size
        right = left + cell_size
        bottom = top + cell_size
        label = f"frame {index + 1} reserved gutter"
        _assert_key_region(image, (left, top, right, top + border), key, label)
        _assert_key_region(image, (left, bottom - border, right, bottom), key, label)
        _assert_key_region(image, (left, top + border, left + border, bottom - border), key, label)
        _assert_key_region(image, (right - border, top + border, right, bottom - border), key, label)


def _opaque_metrics(image: Image.Image) -> tuple[int, tuple[int, int, int, int]]:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("empty frame")
    count = sum(1 for value in alpha.getdata() if value > 0)
    return count, bounds


def _validate_sequence_metrics(frames: list[Image.Image]) -> None:
    from statistics import median

    metrics = [_opaque_metrics(frame) for frame in frames]
    counts = [metric[0] for metric in metrics]
    heights = [metric[1][3] - metric[1][1] for metric in metrics]
    baselines = [metric[1][3] for metric in metrics]
    median_count = median(counts)
    median_height = median(heights)

    for index, count in enumerate(counts, start=1):
        ratio = count / median_count
        if ratio < MIN_DENSITY_RATIO or ratio > MAX_DENSITY_RATIO:
            raise ValueError(f"frame {index}: opaque pixel count ratio {ratio:.2f}")
    for index, height in enumerate(heights, start=1):
        ratio = height / median_height
        if ratio < MIN_HEIGHT_RATIO or ratio > MAX_HEIGHT_RATIO:
            raise ValueError(f"frame {index}: bounding-box height ratio {ratio:.2f}")
    if max(baselines) - min(baselines) > MAX_BASELINE_DELTA:
        raise ValueError(
            f"baseline delta {max(baselines) - min(baselines)} exceeds {MAX_BASELINE_DELTA}"
        )
    for index, (first, second) in enumerate(zip(frames, frames[1:]), start=1):
        if first.tobytes() == second.tobytes():
            raise ValueError(f"frames {index} and {index + 1} are pixel-identical")


def _validate_transparent_border(frame: Image.Image) -> None:
    alpha = frame.getchannel("A")
    width, height = frame.size
    for inset in range(4):
        if alpha.crop((0, inset, width, inset + 1)).getbbox() is not None:
            raise ValueError("output top border is not transparent")
        if alpha.crop((0, height - inset - 1, width, height - inset)).getbbox() is not None:
            raise ValueError("output bottom border is not transparent")
        if alpha.crop((inset, 0, inset + 1, height)).getbbox() is not None:
            raise ValueError("output left border is not transparent")
        if alpha.crop((width - inset - 1, 0, width - inset, height)).getbbox() is not None:
            raise ValueError("output right border is not transparent")


def prepare_storyboard_frames(
    image: Image.Image, soldier: str, frame_size: int = 128
) -> list[Image.Image]:
    key = SOLDIER_KEYS[soldier]
    normalized, cell_size, grid_top = _storyboard_geometry(image, key)
    _validate_source_gutters(normalized, cell_size, grid_top, key)
    frames = [
        _remove_key(cell, key).resize((frame_size, frame_size), Image.Resampling.LANCZOS)
        for cell in storyboard_cells(normalized, key)
    ]
    for frame in frames:
        _validate_transparent_border(frame)
    _validate_sequence_metrics(frames)
    return frames
```

- [ ] **Step 4: Implement selected CLI input and staged writes**

Use a mutually exclusive input group and explicit choices:

```python
inputs = parser.add_mutually_exclusive_group(required=True)
inputs.add_argument("--strips-dir")
inputs.add_argument("--storyboards-dir")
parser.add_argument("--assets-dir", default="Pyxis/Assets.xcassets")
parser.add_argument("--frame-size", type=int, default=128)
parser.add_argument("--soldiers", nargs="+", choices=SOLDIERS, default=list(SOLDIERS))
parser.add_argument("--actions", nargs="+", choices=ACTIONS, default=list(ACTIONS))
```

Add the complete staged writer and storyboard entry point:

```python
import shutil
from tempfile import TemporaryDirectory


def _write_staged_imagesets(
    frames: list[Image.Image], stage_root: Path, soldier: str, action: str
) -> None:
    for index, frame in enumerate(frames, start=1):
        asset_name = f"{soldier}-{action}-{index:02d}"
        imageset = stage_root / f"{asset_name}.imageset"
        imageset.mkdir(parents=True)
        filename = f"{asset_name}.png"
        frame.save(imageset / filename)
        write_contents_json(imageset, filename)


def _install_staged_imagesets_atomic(
    stage_root: Path, output: Path, soldier: str, action: str
) -> None:
    backup_root = stage_root.parent / "backup"
    backup_root.mkdir()
    records: list[dict[str, object]] = []
    try:
        for index in range(1, FRAME_COUNT + 1):
            asset_name = f"{soldier}-{action}-{index:02d}.imageset"
            staged = stage_root / asset_name
            destination = output / asset_name
            backup = backup_root / asset_name
            record: dict[str, object] = {
                "destination": destination,
                "backup": backup,
                "had_existing": destination.exists(),
                "installed": False,
            }
            if destination.exists():
                destination.rename(backup)
            records.append(record)
            staged.rename(destination)
            record["installed"] = True
    except Exception:
        for record in reversed(records):
            destination = record["destination"]
            backup = record["backup"]
            if record["installed"] and isinstance(destination, Path) and destination.exists():
                shutil.rmtree(destination)
            if record["had_existing"] and isinstance(backup, Path) and backup.exists():
                backup.rename(destination)
        raise


def slice_storyboard(
    image: Image.Image,
    output: Path,
    soldier: str,
    action: str,
    frame_size: int,
) -> None:
    frames = prepare_storyboard_frames(image, soldier, frame_size)
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix=".soldier-animation-", dir=output) as directory:
        temp_root = Path(directory)
        stage_root = temp_root / "new"
        stage_root.mkdir()
        _write_staged_imagesets(frames, stage_root, soldier, action)
        _install_staged_imagesets_atomic(stage_root, output, soldier, action)
```

Route the selected CLI values explicitly:

```python
if args.storyboards_dir is not None:
    source_root = Path(args.storyboards_dir)
    for soldier in args.soldiers:
        for action in args.actions:
            source = source_root / f"{soldier}-{action}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            slice_storyboard(
                Image.open(source), assets_dir, soldier, action, args.frame_size
            )
else:
    source_root = Path(args.strips_dir)
    for soldier in args.soldiers:
        for action in args.actions:
            source = source_root / f"{soldier}-{action}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            slice_strip(source, assets_dir, soldier, action, args.frame_size)
```

Call `prepare_storyboard_frames` before creating any destination. Preserve the existing legacy strip call path exactly outside the new selection loop.

- [ ] **Step 5: Run the complete Python suite and a CLI smoke test**

```bash
rtk python3 -m unittest discover -s tools/tests -p 'test_*.py' -v
rtk python3 tools/slice_soldier_animation_strips.py --help
```

Expected: all tests PASS; help lists both input modes plus soldier/action selectors.

- [ ] **Step 6: Commit the validated pipeline**

```bash
rtk git add tools/slice_soldier_animation_strips.py tools/tests/test_slice_soldier_animation_strips.py
rtk git commit -m "feat: validate soldier animation storyboards"
```

---

### Task 3: Full-Canvas Soldier Geometry

**Files:**
- Create: `Pyxis/SoldierAnimationGeometry.swift`
- Create: `PyxisTests/SoldierAnimationGeometryTests.swift`

**Interfaces:**
- Consumes: `SoldierType`, a logical visible body height, and the existing normalized walk-body regions.
- Produces: `SoldierAnimationGeometry.init(type:)`, `frameSize(forBodyHeight:)`, and `logicalBodyFrame(frameSize:)` for `BattleScene` Task 10.

- [ ] **Step 1: Write failing pure geometry tests**

```swift
import CoreGraphics
import Testing
@testable import Pyxis

struct SoldierAnimationGeometryTests {
    @Test func fullCanvasKeepsRequestedLogicalBodyHeightForEveryType() {
        for type in SoldierType.allCases {
            let geometry = SoldierAnimationGeometry(type: type)
            let frameSize = geometry.frameSize(forBodyHeight: 70)
            let bodyFrame = geometry.logicalBodyFrame(frameSize: frameSize)

            #expect(frameSize.width == frameSize.height)
            #expect(abs(bodyFrame.height - 70) < 0.001)
            #expect(abs(bodyFrame.minY) < 0.001)
        }
    }

    @Test func fullCanvasLeavesHorizontalRoomForWeapons() {
        let geometry = SoldierAnimationGeometry(type: .archer)
        let frameSize = geometry.frameSize(forBodyHeight: 70)
        let bodyFrame = geometry.logicalBodyFrame(frameSize: frameSize)

        #expect(frameSize.width > bodyFrame.width)
        #expect(bodyFrame.midX == 0)
    }
}
```

- [ ] **Step 2: Run focused tests and verify RED**

Use XcodeBuildMCP `test_sim` with:

```text
-parallel-testing-enabled NO
-only-testing:PyxisTests/SoldierAnimationGeometryTests
```

Expected: build FAIL because `SoldierAnimationGeometry` does not exist. Confirm the test count is nonzero after implementation; do not trust a successful zero-test selector.

- [ ] **Step 3: Implement the pure value type**

```swift
import CoreGraphics

struct SoldierAnimationGeometry: Equatable {
    static let canvasSize = CGSize(width: 128, height: 128)

    let bodyRegion: CGRect

    init(type: SoldierType) {
        switch type {
        case .infantry:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.57)
        case .archer:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.59)
        case .cavalry:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.53)
        case .mage:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.58)
        case .siege:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.44)
        }
    }

    func frameSize(forBodyHeight bodyHeight: CGFloat) -> CGSize {
        let side = bodyHeight / bodyRegion.height
        return CGSize(width: side, height: side)
    }

    func logicalBodyFrame(frameSize: CGSize) -> CGRect {
        CGRect(
            x: -frameSize.width / 2 + bodyRegion.minX * frameSize.width,
            y: bodyRegion.minY * frameSize.height,
            width: bodyRegion.width * frameSize.width,
            height: bodyRegion.height * frameSize.height
        )
    }
}
```

- [ ] **Step 4: Run geometry tests and broader layout tests**

Run `SoldierAnimationGeometryTests`, then `-only-testing:PyxisTests/BattlefieldLayoutTests` with parallel testing disabled. Expected: PASS.

- [ ] **Step 5: Commit the geometry unit**

```bash
rtk git add Pyxis/SoldierAnimationGeometry.swift PyxisTests/SoldierAnimationGeometryTests.swift
rtk git commit -m "feat: add full-canvas soldier animation geometry"
```

---

### Task 4: Archer Attack Pilot And User Quality Gate

**Files:**
- Replace after approval: `Pyxis/Assets.xcassets/archer-attack-01.imageset/archer-attack-01.png` through `archer-attack-10.imageset/archer-attack-10.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/archer-attack.png`
- Temporary: `build/animation-preview/`

**Interfaces:**
- Consumes: `archer-walk-01.png` and `archer-walk-06.png` as identity/equipment references; Task 2 storyboard CLI.
- Produces: ten validated archer attack frames, a contact sheet, an animated preview, and explicit user approval before installation.

- [ ] **Step 1: Inspect identity reference images**

Use `view_image` on:

```text
Pyxis/Assets.xcassets/archer-walk-01.imageset/archer-walk-01.png
Pyxis/Assets.xcassets/archer-walk-06.imageset/archer-walk-06.png
```

Confirm the hood, leather layers, face, quiver, wooden bow limbs, dark grip, string, arrow, body scale, facing direction, and baseline that must remain invariant.

- [ ] **Step 2: Generate one archer attack storyboard with the built-in image tool**

Call the built-in image-generation tool once with both reference image paths and this exact prompt:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game character attack animation storyboard
Input images: Image 1 and Image 2 are strict identity, costume, scale, rendering, and equipment references for the same archer
Primary request: create one natural bow-shot animation of exactly ten sequential poses for this exact archer
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background, including every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: one centered 5-column by 2-row grid of ten equal square cells in row-major order; the grid occupies the central horizontal band; generous key-color-only canvas above and below; no panel borders or labels
Motion: frame 1 neutral; frame 2 shoulder settles; frame 3 bow arm extends and drawing elbow starts rising; frame 4 drawing hand moves toward cheek; frame 5 reaches full draw with visible bow bend; frame 6 releases; frame 7 shows small natural bow-arm and drawing-arm recoil; frame 8 controlled recovery; frame 9 near-neutral settle; frame 10 neutral
Fine details: preserve the exact green hood, leather layers, face, quiver, arrow treatment, wooden bow color and limb shape, dark grip, string, and body proportions; hand placement, elbow position, shoulder rotation, string tension, and bow bend must change continuously and anatomically across adjacent frames
Constraints: the same character and same bow in every cell; body scale and ground baseline fixed; full body and complete bow visible; keep all artwork inside the inner 84 percent of each cell; no detached flying arrow inside the storyboard; no shadows, scenery, text, watermark, panel lines, glow, trail, slash arc, aura, explosion, or oversized effect
Avoid: duplicate poses, skipped motion phases, costume changes, face changes, bow redesign, body shrink, neighboring-cell overlap, or artwork crossing a cell boundary
```

The image tool's returned local path becomes the source for `/private/tmp/pyxis-action-storyboards/archer-attack.png`. End the image-generation response without extra prose, then continue from the returned local path in the next execution turn.

- [ ] **Step 3: Slice into ignored preview assets**

```bash
rtk mkdir -p /private/tmp/pyxis-action-storyboards
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers archer --actions attack
```

Expected: ten validated 128-by-128 RGBA imagesets; no gutter, density, height, or baseline failure.

- [ ] **Step 4: Build visual QA artifacts**

```bash
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/archer-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/archer-attack-contact.png
rtk ffmpeg -y -loglevel error -framerate 11 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/archer-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/archer-attack.gif
```

Inspect both files with `view_image`. Reject if the elbow does not rise, the hand misses the cheek, the bow design changes, the body scale moves, a neighboring pose appears, or effects carry the action.

- [ ] **Step 5: Present the pilot for user approval**

Show the contact sheet and GIF. Do not install or generate the remaining storyboards until the user confirms that identity, bow styling, natural motion, detail level, and effect restraint are correct.

- [ ] **Step 6: Install the approved pilot and commit**

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers archer --actions attack
rtk git add Pyxis/Assets.xcassets/archer-attack-*.imageset
rtk git commit -m "feat: replace archer attack animation frames"
```

---

### Task 5: Archer Hit Animation

**Files:**
- Replace: `Pyxis/Assets.xcassets/archer-hit-01.imageset/archer-hit-01.png` through `archer-hit-10.imageset/archer-hit-10.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/archer-hit.png`

**Interfaces:**
- Consumes: `archer-walk-01.png`, `archer-walk-06.png`, and the validated storyboard pipeline.
- Produces: a stable-scale hit reaction that preserves the bow and communicates posture/facial change without effects.

- [ ] **Step 1: Generate the archer hit board**

Use one built-in image-generation call with both archer reference paths and this prompt:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game character hit-reaction storyboard
Input images: Image 1 and Image 2 are strict identity, costume, scale, rendering, and equipment references for the same archer
Primary request: create one restrained being-hit and recovery animation of exactly ten sequential poses for this exact archer
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background, including every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: one centered 5-column by 2-row grid of ten equal square cells in row-major order; central horizontal band; generous key-color-only canvas above and below; no panel borders or labels
Motion: frame 1 neutral; frame 2 notices and braces; frame 3 shoulder and torso begin recoiling; frame 4 peak controlled stagger with tightened eyes and grimace; frame 5 holds the readable compressed posture; frame 6 begins rebound; frame 7 restores the bow arm; frame 8 straightens torso; frame 9 near-neutral settle; frame 10 neutral
Fine details: preserve the exact green hood, leather layers, face, quiver, arrow treatment, wooden bow design, grip, string, and proportions; the archer keeps hold of the bow throughout
Constraints: same character and same bow in every cell; fixed body scale and ground baseline; all artwork inside each cell's inner 84 percent; expression and posture carry the reaction; no stars, impact burst, glow, trail, slash, aura, explosion, shadow, scenery, text, watermark, panel line, or neighboring-cell overlap
Avoid: costume changes, face replacement, dropped or redesigned bow, full-body launch, dramatic translation, duplicate poses, body shrink, or artwork crossing cell boundaries
```

Copy the returned local file to
`/private/tmp/pyxis-action-storyboards/archer-hit.png`.

- [ ] **Step 2: Slice, generate QA artifacts, and inspect**

```bash
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers archer --actions hit
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/archer-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/archer-hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/archer-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/archer-hit.gif
```

Inspect both QA files. Verify the face/posture change reads without stars or impact art.

- [ ] **Step 3: Install and commit**

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers archer --actions hit
rtk git add Pyxis/Assets.xcassets/archer-hit-*.imageset
rtk git commit -m "feat: replace archer hit animation frames"
```

---

### Task 6: Infantry Attack And Hit Assets

**Files:**
- Replace: `Pyxis/Assets.xcassets/infantry-attack-*.imageset/*.png`
- Replace: `Pyxis/Assets.xcassets/infantry-hit-*.imageset/*.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/infantry-{attack,hit}.png`

**Interfaces:**
- Consumes: `infantry-walk-01.png`, `infantry-walk-06.png`, Task 2 CLI.
- Produces: twenty validated infantry action frames.

- [ ] **Step 1: Generate attack and hit in separate built-in calls**

Start both built-in image-generation calls with this exact common block, using
`infantry-walk-01.png` and `infantry-walk-06.png` as referenced image paths, then
append the action-specific motion block below:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game infantry action storyboard
Input images: Image 1 and Image 2 are strict identity, armor, sword, shield, scale, rendering, and palette references for the same infantry soldier
Primary request: generate exactly ten sequential poses for this exact infantry soldier using the appended attack or hit motion
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: exactly ten sequential poses in one centered 5-column by 2-row grid of equal square cells, row-major order, central horizontal band, key-color-only canvas above and below, no borders or labels
Constraints: same soldier and equipment in every cell; fixed body scale and ground baseline; complete body, sword, and shield visible; all artwork inside each cell's inner 84 percent; no shadow, scenery, text, watermark, panel line, neighboring-cell overlap, or detached combat effect
Avoid: duplicate poses, skipped phases, face or costume changes, equipment redesign, body shrink, large translation, or artwork crossing cell boundaries
```

Attack motion text, included verbatim in the attack call:

```text
Frames: 1 neutral guard; 2 planted anticipation; 3 compact sword wind-up behind the shoulder; 4 front-foot weight transfer; 5 committed diagonal strike; 6 wrist and shoulder follow-through; 7 sword decelerates while shield stays protective; 8 controlled return; 9 near-neutral guard; 10 neutral. Preserve the exact sword, small blue shield, helmet, armor, face, plume, palette, and proportions. No slash arc, spark, trail, lunge, jump, or detached effect.
```

Hit motion text, included verbatim in the hit call:

```text
Frames: 1 neutral guard; 2 turns shield toward impact; 3 compresses knees and torso; 4 peak guarded recoil with tightened eyes and grimace; 5 holds readable reaction; 6 begins rebound; 7 restores sword arm; 8 straightens stance; 9 near-neutral guard; 10 neutral. Preserve the exact sword, small blue shield, helmet, armor, face, plume, palette, and proportions. No stars, burst, slash, glow, full-body launch, or detached effect.
```

Copy the returned local files to
`/private/tmp/pyxis-action-storyboards/infantry-attack.png` and
`/private/tmp/pyxis-action-storyboards/infantry-hit.png` respectively.

- [ ] **Step 2: Preview, validate, and inspect both actions**

```bash
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers infantry --actions attack hit
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/infantry-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/infantry-attack-contact.png
rtk ffmpeg -y -loglevel error -framerate 11.111 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/infantry-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/infantry-attack.gif
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/infantry-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/infantry-hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/infantry-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/infantry-hit.gif
```

Inspect all four QA files. Reject scale movement, shield/sword redesign, large displacement, neighboring pixels, or effect-led motion.

- [ ] **Step 3: Install and commit twenty frames**

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers infantry --actions attack hit
rtk git add Pyxis/Assets.xcassets/infantry-attack-*.imageset Pyxis/Assets.xcassets/infantry-hit-*.imageset
rtk git commit -m "feat: replace infantry action animation frames"
```

---

### Task 7: Cavalry Attack And Hit Assets

**Files:**
- Replace: `Pyxis/Assets.xcassets/cavalry-attack-*.imageset/*.png`
- Replace: `Pyxis/Assets.xcassets/cavalry-hit-*.imageset/*.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/cavalry-{attack,hit}.png`

**Interfaces:**
- Consumes: `cavalry-walk-01.png`, `cavalry-walk-06.png`, Task 2 CLI.
- Produces: twenty validated mounted action frames.

- [ ] **Step 1: Generate separate attack and hit boards**

Start both built-in image-generation calls with this exact common block, using
`cavalry-walk-01.png` and `cavalry-walk-06.png` as referenced image paths, then
append the action-specific motion block:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game mounted cavalry action storyboard
Input images: Image 1 and Image 2 are strict identity, rider, horse, tack, lance, scale, rendering, and palette references for the same cavalry unit
Primary request: generate exactly ten sequential poses for this exact cavalry unit using the appended attack or hit motion
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: exactly ten sequential poses in one centered 5-column by 2-row grid of equal square cells, row-major order, central horizontal band, key-color-only canvas above and below, no borders or labels
Constraints: same rider, horse, tack, and lance in every cell; fixed unit scale and hoof baseline; complete unit and lance visible; all artwork inside each cell's inner 84 percent; no shadow, scenery, text, watermark, panel line, neighboring-cell overlap, or detached effect
Avoid: duplicate poses, skipped phases, rider/horse redesign, equipment changes, body shrink, leap, large translation, or artwork crossing cell boundaries
```

Attack motion:

```text
Frames: 1 neutral mounted stance; 2 rider gathers reins and horse braces; 3 rider lowers lance and hips settle; 4 horse takes one controlled forward step; 5 lance drives forward with aligned hands, shoulders, and seat; 6 peak follow-through without a leap; 7 horse checks momentum; 8 rider raises lance slightly; 9 mount and rider settle; 10 neutral. Preserve the exact rider, armor, orange accents, horse, tack, lance design, palette, and proportions. No jump, gallop, giant lunge, trail, spark, or impact effect.
```

Hit motion:

```text
Frames: 1 neutral mounted stance; 2 horse checks step and rider braces; 3 rider absorbs impact through seat and reins; 4 peak controlled recoil with readable facial tension; 5 mount remains grounded; 6 rebound begins; 7 reins and shoulders recover; 8 horse settles; 9 near-neutral; 10 neutral. Preserve the exact rider, horse, tack, lance, palette, and proportions. No launch, rearing leap, stars, burst, glow, or detached effect.
```

Copy the returned local files to
`/private/tmp/pyxis-action-storyboards/cavalry-attack.png` and
`/private/tmp/pyxis-action-storyboards/cavalry-hit.png` respectively.

- [ ] **Step 2: Validate motion and install**

```bash
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers cavalry --actions attack hit
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/cavalry-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/cavalry-attack-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/cavalry-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/cavalry-attack.gif
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/cavalry-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/cavalry-hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/cavalry-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/cavalry-hit.gif
```

Inspect both GIFs and the ten source cells. Confirm hooves remain grounded, rider and mount remain one consistent unit, and the lance never enters a neighboring cell. Then install:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers cavalry --actions attack hit
```

- [ ] **Step 3: Commit cavalry assets**

```bash
rtk git add Pyxis/Assets.xcassets/cavalry-attack-*.imageset Pyxis/Assets.xcassets/cavalry-hit-*.imageset
rtk git commit -m "feat: replace cavalry action animation frames"
```

---

### Task 8: Mage Attack And Hit Assets

**Files:**
- Replace: `Pyxis/Assets.xcassets/mage-attack-*.imageset/*.png`
- Replace: `Pyxis/Assets.xcassets/mage-hit-*.imageset/*.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/mage-{attack,hit}.png`

**Interfaces:**
- Consumes: `mage-walk-01.png`, `mage-walk-06.png`, Task 2 CLI.
- Produces: twenty validated mage action frames with restrained magic detail.

- [ ] **Step 1: Generate separate attack and hit boards**

Start both built-in image-generation calls with this exact common block, using
`mage-walk-01.png` and `mage-walk-06.png` as referenced image paths, then append
the action-specific motion block:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game mage action storyboard
Input images: Image 1 and Image 2 are strict identity, face, robe, staff, scale, rendering, and palette references for the same mage
Primary request: generate exactly ten sequential poses for this exact mage using the appended attack or hit motion
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: exactly ten sequential poses in one centered 5-column by 2-row grid of equal square cells, row-major order, central horizontal band, key-color-only canvas above and below, no borders or labels
Constraints: same mage, robe, staff, and crystal in every cell; fixed body scale and foot baseline; complete body and staff visible; all artwork inside each cell's inner 84 percent; no shadow, scenery, text, watermark, panel line, neighboring-cell overlap, or detached projectile
Avoid: duplicate poses, skipped phases, face/costume/staff redesign, body shrink, large translation, large aura, or artwork crossing cell boundaries
```

Attack motion:

```text
Frames: 1 neutral staff stance; 2 shoulders settle and free hand opens; 3 staff plants while robe follows; 4 free hand gathers controlled energy; 5 staff and hand align toward target; 6 release with only a small staff-tip glow; 7 hands and robe show subtle recoil; 8 staff returns; 9 near-neutral settle; 10 neutral. Preserve the exact face, violet hood and robe, staff shaft and crystal, palette, outline, and proportions. No large aura, orb, projectile, beam, trail, explosion, or scenery.
```

Hit motion:

```text
Frames: 1 neutral staff stance; 2 casting posture is interrupted; 3 free arm folds inward and shoulder recoils; 4 peak stagger with tightened eyes and grimace; 5 readable compressed posture while staff remains held; 6 rebound; 7 free arm restores; 8 robe and staff settle; 9 near-neutral; 10 neutral. Preserve the exact face, violet hood and robe, staff and crystal, palette, outline, and proportions. No stars, burst, aura, glow cloud, launch, or detached effect.
```

Copy the returned local files to
`/private/tmp/pyxis-action-storyboards/mage-attack.png` and
`/private/tmp/pyxis-action-storyboards/mage-hit.png` respectively.

- [ ] **Step 2: Validate motion and install**

```bash
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers mage --actions attack hit
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/mage-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/mage-attack-contact.png
rtk ffmpeg -y -loglevel error -framerate 10 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/mage-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/mage-attack.gif
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/mage-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/mage-hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/mage-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/mage-hit.gif
```

Inspect both GIFs and confirm staff/hand mechanics carry the cast and the only allowed effect is a small attached tip glow. Then install:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers mage --actions attack hit
```

- [ ] **Step 3: Commit mage assets**

```bash
rtk git add Pyxis/Assets.xcassets/mage-attack-*.imageset Pyxis/Assets.xcassets/mage-hit-*.imageset
rtk git commit -m "feat: replace mage action animation frames"
```

---

### Task 9: Siege Attack And Hit Assets

**Files:**
- Replace: `Pyxis/Assets.xcassets/siege-attack-*.imageset/*.png`
- Replace: `Pyxis/Assets.xcassets/siege-hit-*.imageset/*.png`
- Temporary: `/private/tmp/pyxis-action-storyboards/siege-{attack,hit}.png`

**Interfaces:**
- Consumes: `siege-walk-01.png`, `siege-walk-06.png`, Task 2 CLI.
- Produces: twenty validated grounded mechanical action frames.

- [ ] **Step 1: Generate separate attack and hit boards**

Start both built-in image-generation calls with this exact common block, using
`siege-walk-01.png` and `siege-walk-06.png` as referenced image paths, then append
the action-specific motion block:

```text
Use case: stylized-concept
Asset type: 10-frame chibi fantasy mobile-game siege-unit action storyboard
Input images: Image 1 and Image 2 are strict identity, operator, chassis, wheel, mechanism, scale, rendering, and palette references for the same siege unit
Primary request: generate exactly ten sequential poses for this exact siege unit using the appended attack or hit motion
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background in every gap and all unused canvas
Style/medium: match the reference sprite's painted chibi rendering, outline weight, lighting, fine material detail, and facial proportions exactly
Composition/framing: exactly ten sequential poses in one centered 5-column by 2-row grid of equal square cells, row-major order, central horizontal band, key-color-only canvas above and below, no borders or labels
Constraints: same operator, chassis, wheels, and mechanism in every cell; fixed unit scale and wheel baseline; complete unit visible; all artwork inside each cell's inner 84 percent; no shadow, scenery, text, watermark, panel line, neighboring-cell overlap, projectile, smoke, or explosion
Avoid: duplicate poses, skipped phases, operator/mechanism redesign, broken parts, body shrink, jump, whole-unit translation, or artwork crossing cell boundaries
```

Attack motion:

```text
Frames: 1 neutral mechanism; 2 operator braces and reaches control; 3 mechanism draws or loads; 4 operator commits force; 5 firing or ram contact at peak mechanism extension; 6 grounded mechanical recoil; 7 recoil decelerates; 8 mechanism resets; 9 operator and chassis settle; 10 neutral. Preserve the exact operator, helmet, chassis, wheels, metal and wood construction, mechanism, palette, outline, and proportions. No projectile in the board, smoke, explosion, spark cloud, jump, or whole-unit lunge.
```

Hit motion:

```text
Frames: 1 neutral mechanism; 2 operator braces; 3 short chassis jolt begins; 4 peak grounded jolt with operator grimace; 5 wheels remain planted; 6 mechanical rebound; 7 operator restores grip; 8 moving parts settle; 9 near-neutral; 10 neutral. Preserve the exact operator, helmet, chassis, wheels, construction, mechanism, palette, outline, and proportions. No launch, broken parts, stars, explosion, smoke, glow, or detached effect.
```

Copy the returned local files to
`/private/tmp/pyxis-action-storyboards/siege-attack.png` and
`/private/tmp/pyxis-action-storyboards/siege-hit.png` respectively.

- [ ] **Step 2: Validate motion and install**

```bash
rtk mkdir -p build/animation-preview/qa
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/animation-preview/Assets.xcassets --soldiers siege --actions attack hit
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/siege-attack-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/siege-attack-contact.png
rtk ffmpeg -y -loglevel error -framerate 7.143 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/siege-attack-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/siege-attack.gif
rtk ffmpeg -y -loglevel error -pattern_type glob -framerate 1 -i 'build/animation-preview/Assets.xcassets/siege-hit-*.imageset/*.png' -vf 'tile=5x2:padding=8:margin=8:color=black' -frames:v 1 build/animation-preview/qa/siege-hit-contact.png
rtk ffmpeg -y -loglevel error -framerate 12.5 -pattern_type glob -i 'build/animation-preview/Assets.xcassets/siege-hit-*.imageset/*.png' -vf 'scale=512:512:flags=neighbor' -loop 0 build/animation-preview/qa/siege-hit.gif
```

Inspect both GIFs and confirm wheels stay grounded and only the intended mechanism moves. Then install:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir Pyxis/Assets.xcassets --soldiers siege --actions attack hit
```

- [ ] **Step 3: Commit siege assets**

```bash
rtk git add Pyxis/Assets.xcassets/siege-attack-*.imageset Pyxis/Assets.xcassets/siege-hit-*.imageset
rtk git commit -m "feat: replace siege action animation frames"
```

---

### Task 10: Cut BattleScene Over To Authored Full-Canvas Actions

**Files:**
- Modify: `Pyxis/BattleScene.swift:35-145, 1740-2860, 3310-3635`
- Modify: `PyxisTests/BattleSceneTests.swift:95-490, 790-815, 1715-1745`

**Interfaces:**
- Consumes: all ten validated attack/hit sets and `SoldierAnimationGeometry`.
- Produces: full-canvas action-specific playback; per-type timing; logical HP/body layout; `playSoldierAnimation(...) -> Bool`; no procedural pose nodes.

- [ ] **Step 1: Replace workaround tests with failing authored-action tests**

Delete tests that require `soldierAttackPose`, `soldierAttackPart`, `soldierHitExpression`, `soldierHitPosture`, large stable-body offsets, shared walk textures, or center-crop containment. Add:

```swift
@Test func transientAnimationsUseDistinctFullCanvasTexturesForEveryType() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
    let scene = makeScene(store: store)

    for type in SoldierType.allCases {
        let walk = scene.cachedSoldierAnimationTexturesForTesting(soldierType: type, action: "walk")
        let attack = scene.cachedSoldierAnimationTexturesForTesting(soldierType: type, action: "attack")
        let hit = scene.cachedSoldierAnimationTexturesForTesting(soldierType: type, action: "hit")

        #expect(walk.count == 10)
        #expect(attack.count == 10)
        #expect(hit.count == 10)
        #expect(attack[0] !== walk[0])
        #expect(hit[0] !== walk[0])
        #expect(walk.allSatisfy { $0.size() == CGSize(width: 128, height: 128) })
        #expect(attack.allSatisfy { $0.size() == CGSize(width: 128, height: 128) })
        #expect(hit.allSatisfy { $0.size() == CGSize(width: 128, height: 128) })
    }
}

@Test func authoredAttackAndHitDoNotCreateProceduralPoseNodes() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
    let scene = makeScene(store: store, combatSeed: 1)
    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3.0)

    #expect(scene.recentSoldierAttackAnimationCountForTesting > 0)
    #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPart") == 0)
    #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
    #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
}

@Test func transientTimingMatchesSoldierCadence() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
    let scene = makeScene(store: store)
    let expectedAttack: [SoldierType: TimeInterval] = [
        .infantry: 0.90, .archer: 0.90, .cavalry: 0.80, .mage: 1.00, .siege: 1.40
    ]

    for type in SoldierType.allCases {
        #expect(scene.soldierAnimationDurationForTesting(soldierType: type, action: "attack") == expectedAttack[type])
        #expect(scene.soldierAnimationDurationForTesting(soldierType: type, action: "hit") == 0.80)
    }
}
```

Update body-size and HP tests to compare `firstLiveSoldierLogicalBodyFrameForTesting` with `firstLiveSoldierHPBarFrameForTesting`, while `firstLiveSoldierCanvasFrameForTesting` is expected to be larger than the logical body frame.

- [ ] **Step 2: Run BattleScene tests and verify RED**

Use XcodeBuildMCP `test_sim` with `-parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests`. Expected: failures show action textures still alias walk, textures are cropped, old overlay nodes exist, and timing lacks soldier type.

- [ ] **Step 3: Restore action-specific full-canvas texture resolution**

Remove the `.attack`/`.hit` early return to walk. Replace cropped texture creation with:

```swift
private func soldierAnimationTexture(named frameName: String) -> SKTexture {
    SKTexture(imageNamed: frameName)
}
```

Cache complete action sets independently. Incomplete attack or hit sets return `[]`; do not silently cache or return walk from the resolver.

- [ ] **Step 4: Apply full-canvas geometry and logical HP layout**

Replace the soldier-specific `fitBattleNode` call and HP frame lookup with these helpers:

```swift
private func sizeSoldierBody(_ bundle: SoldierNodeBundle) {
    if let sprite = bundle.body as? SKSpriteNode {
        sprite.setScale(1)
        sprite.size = SoldierAnimationGeometry(type: bundle.type)
            .frameSize(forBodyHeight: soldierTargetHeight())
    } else {
        fitBattleNode(bundle.body, targetHeight: soldierTargetHeight())
    }
}

private func logicalSoldierBodyFrame(for bundle: SoldierNodeBundle) -> CGRect {
    guard let sprite = bundle.body as? SKSpriteNode else {
        return bundle.body.calculateAccumulatedFrame()
    }
    return SoldierAnimationGeometry(type: bundle.type)
        .logicalBodyFrame(frameSize: sprite.size)
        .offsetBy(dx: sprite.position.x, dy: sprite.position.y)
}

private func layoutSoldierHPBar(
    _ bundle: SoldierNodeBundle,
    soldier: BattleCombatState.Soldier
) {
    let bodyFrame = logicalSoldierBodyFrame(for: bundle)
    let width = max(36, min(56, bodyFrame.width * 0.72))
    let height: CGFloat = 5
    let y = bodyFrame.maxY + 1.5
    // Keep the existing background/fill path construction and HP percentage.
}
```

Call `sizeSoldierBody(bundle)` from `syncSoldierNodes`. Preserve shape/static fallback sizing through `fitBattleNode`; do not use the full transparent sprite frame to position the HP bar.

Add DEBUG accessors:

```swift
var firstLiveSoldierCanvasFrameForTesting: CGRect? {
    guard let soldierID = firstLiveSoldierIDForTesting,
          let bundle = soldierNodes[soldierID] else {
        return nil
    }
    return sceneFrame(for: bundle.body)
}

var firstLiveSoldierLogicalBodyFrameForTesting: CGRect? {
    guard let soldierID = firstLiveSoldierIDForTesting,
          let bundle = soldierNodes[soldierID],
          let sprite = bundle.body as? SKSpriteNode else {
        return nil
    }
    let localFrame = SoldierAnimationGeometry(type: bundle.type)
        .logicalBodyFrame(frameSize: sprite.size)
    return sceneFrame(for: localFrame, in: bundle.motionRoot)
}

private func sceneFrame(for rect: CGRect, in node: SKNode) -> CGRect? {
    let points = [
        CGPoint(x: rect.minX, y: rect.minY),
        CGPoint(x: rect.maxX, y: rect.minY),
        CGPoint(x: rect.minX, y: rect.maxY),
        CGPoint(x: rect.maxX, y: rect.maxY)
    ].map { node.convert($0, to: self) }

    guard let minX = points.map(\.x).min(),
          let maxX = points.map(\.x).max(),
          let minY = points.map(\.y).min(),
          let maxY = points.map(\.y).max() else {
        return nil
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}
```

- [ ] **Step 5: Implement per-type timing and interruption**

```swift
private func soldierAnimationTimePerFrame(
    for type: SoldierType,
    action: SoldierAnimationAction
) -> TimeInterval {
    switch action {
    case .walk:
        return 0.08
    case .hit:
        return 0.08
    case .attack:
        switch type {
        case .infantry, .archer: return 0.09
        case .cavalry: return 0.08
        case .mage: return 0.10
        case .siege: return 0.14
        }
    }
}
```

Make `playSoldierAnimation` return `true` only when it installs a complete authored animation. It removes walk, attack, and hit keys before installing the new transient; because `applyCombatResult` processes attacks before damaged IDs, a same-tick hit removes and replaces attack, preserving hit priority. Delayed death removal remains 0.80 seconds.

- [ ] **Step 6: Remove procedural action presentation**

Delete `AttackPartMotion`, `StableSoldierBodyFeedback`, procedural effect names and keys, the attack cue path, `playStableSoldierAttackCue`, `playStableSoldierAttackMotion`, every `make/add/runAttackPose...` helper, `playStableSoldierHitMotion`, and every hit expression/posture helper. Keep tower projectile, city hit feedback, and a hit color flash no longer than 0.12 seconds.

When `playSoldierAnimation` returns `false`, apply only a two-point root nudge and return, so missing art remains safe without recreating a procedural pose.

- [ ] **Step 7: Run focused tests until GREEN**

Run `BattleSceneTests`, `SoldierAnimationGeometryTests`, and then all `PyxisTests`, always with parallel testing disabled. Expected: every command executes nonzero tests and PASS.

- [ ] **Step 8: Commit runtime cutover**

```bash
rtk git add Pyxis/BattleScene.swift Pyxis/SoldierAnimationGeometry.swift PyxisTests/BattleSceneTests.swift PyxisTests/SoldierAnimationGeometryTests.swift
rtk git commit -m "feat: play authored soldier action animations"
```

---

### Task 11: Documentation And End-To-End Verification

**Files:**
- Modify: `CLAUDE.md`
- Verify: all files changed by Tasks 1-10

**Interfaces:**
- Consumes: completed pipeline, all 100 regenerated frames, runtime cutover.
- Produces: canonical repository guidance plus complete automated and simulator evidence.

- [ ] **Step 1: Document the canonical source layout**

Add to the soldier animation convention in `CLAUDE.md`:

```markdown
- New attack/hit source art uses a centered 5-by-2 grid of square cells with an 8% key-color border inside every cell. The slicer uses fixed cell coordinates and resizes the complete cell; never crop or auto-fit from per-frame opaque bounds, because that causes neighboring-frame bleed and character scale pumping.
- Use magenta `#ff00ff` source backgrounds for the green archer and green `#00ff00` for the other soldier types. Keep source storyboards temporary; commit only validated 128x128 RGBA frame imagesets.
```

- [ ] **Step 2: Run Python and asset validation**

```bash
rtk python3 -m unittest discover -s tools/tests -p 'test_*.py' -v
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-action-storyboards --assets-dir build/final-animation-audit/Assets.xcassets --soldiers infantry archer cavalry mage siege --actions attack hit
```

Expected: all pipeline tests PASS and all ten boards produce 100 validated frames without warnings or partial output.

- [ ] **Step 3: Run full Xcode verification**

First call XcodeBuildMCP `session_show_defaults`. Set project `/Users/chanwaichan/workspace/Pyxis/Pyxis.xcodeproj`, scheme `Pyxis`, a booted iPhone simulator, bundle ID `cwchanap.Pyxis`, and derived data `/private/tmp/pyxis-action-animation-derived-data` when missing.

Run `test_sim` twice:

```text
-parallel-testing-enabled NO -only-testing:PyxisTests
-parallel-testing-enabled NO -only-testing:PyxisUITests
```

Expected: all unit and UI tests PASS with nonzero execution counts.

- [ ] **Step 4: Run lint and repository hygiene checks**

```bash
rtk swiftlint lint --cache-path /private/tmp/pyxis-action-animation-swiftlint-cache
rtk git diff --check
rtk git status --short
```

Expected: SwiftLint exits 0 with no new warnings in changed Swift files; diff check is clean; status contains only intended changes.

- [ ] **Step 5: Build, launch, and visually verify every soldier**

Use XcodeBuildMCP `build_run_sim`, then verify launch with `screenshot`. In the simulator, manually select and spawn infantry, archer, cavalry, mage, and siege soldiers. Record enough combat to see at least one complete attack and one complete tower-hit reaction for each type.

Verify at battlefield scale:

- No adjacent pose appears inside any frame.
- Body scale, costume, face, and weapon remain stable across action changes.
- Archer elbow rises, drawing hand reaches cheek, matching bow bends, string releases, and body recovers without relying on an arrow effect.
- Infantry sword weight transfer, cavalry rider/mount mechanics, mage hand/staff cast, and siege mechanism recoil are clear and restrained.
- Hit reactions use face/posture changes without stars or large effects.
- Every action completes smoothly and resumes walk; same-tick hit visually overrides attack.
- HP bars stay above the logical body rather than above transparent canvas.

- [ ] **Step 6: Commit documentation and any verification-only adjustments**

```bash
rtk git add CLAUDE.md
rtk git commit -m "docs: record soldier storyboard animation pipeline"
```

Do not commit generated files under `build/` or `/private/tmp`.
