#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
from tempfile import TemporaryDirectory
from pathlib import Path
from typing import TypeAlias

from PIL import Image

SOLDIERS = ("infantry", "archer", "cavalry", "mage", "siege")
ACTIONS = ("walk", "attack", "hit")
FRAME_COUNT = 10
RGBAColor: TypeAlias = tuple[int, int, int, int]
STORYBOARD_COLUMNS = 5
STORYBOARD_ROWS = 2
STORYBOARD_FRAME_SIZE = 128
STORYBOARD_BORDER_FRACTION = 0.08
KEY_CHANNEL_TOLERANCE = 12
TRANSPARENT_THRESHOLD = 12
OPAQUE_THRESHOLD = 220
MIN_DENSITY_RATIO = 0.60
MAX_DENSITY_RATIO = 1.50
MIN_HEIGHT_RATIO = 0.70
MAX_HEIGHT_RATIO = 1.30
MAX_BASELINE_DELTA = 6
MAX_NEUTRAL_HEIGHT_SCALE_DELTA = 0.05
VERTICAL_CORE_LOW_QUANTILE = 0.05
VERTICAL_CORE_HIGH_QUANTILE = 0.95
MAX_VERTICAL_CORE_HEIGHT_DELTA = 2
MAX_VERTICAL_CORE_CENTROID_DELTA = 4.0

SOLDIER_KEYS: dict[str, RGBAColor] = {
    "infantry": (0, 255, 0, 255),
    "archer": (255, 0, 255, 255),
    "cavalry": (0, 255, 0, 255),
    "mage": (0, 255, 0, 255),
    "siege": (0, 255, 0, 255),
}

# Assets are always written under the repo root (the current working directory
# when the script is invoked). Paths supplied via CLI are resolved and clamped
# to this root so a faulty --assets-dir cannot escape the project tree.
REPO_ROOT = Path.cwd().resolve()


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


def _channel_distance(pixel: RGBAColor, key: RGBAColor) -> int:
    return max(abs(pixel[index] - key[index]) for index in range(3))


def _remove_key(cell: Image.Image, key: RGBAColor) -> Image.Image:
    output = cell
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
            matte = int(
                255
                * (distance - TRANSPARENT_THRESHOLD)
                / (OPAQUE_THRESHOLD - TRANSPARENT_THRESHOLD)
            )
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
    image: Image.Image,
    box: tuple[int, int, int, int],
    key: RGBAColor,
    label: str,
) -> None:
    left, top, right, bottom = box
    pixels = image.load()
    for y in range(top, bottom):
        for x in range(left, right):
            if _channel_distance(pixels[x, y], key) > KEY_CHANNEL_TOLERANCE:
                raise ValueError(
                    f"{label}: non-key artwork entered reserved gutter at ({x}, {y})"
                )


def _validate_source_gutters(
    image: Image.Image, cell_size: int, grid_top: int, key: RGBAColor
) -> None:
    _assert_key_region(image, (0, 0, image.width, grid_top), key, "outer canvas")
    grid_bottom = grid_top + cell_size * STORYBOARD_ROWS
    _assert_key_region(image, (0, grid_bottom, image.width, image.height), key, "outer canvas")

    border = max(1, int(round(cell_size * STORYBOARD_BORDER_FRACTION)))
    for index in range(FRAME_COUNT):
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


def _vertical_core_metrics(image: Image.Image) -> tuple[int, float]:
    alpha = image.getchannel("A")
    row_counts = [
        sum(1 for value in alpha.crop((0, y, image.width, y + 1)).getdata() if value > 0)
        for y in range(image.height)
    ]
    total = sum(row_counts)
    if total == 0:
        raise ValueError("empty frame")

    lower_target = total * VERTICAL_CORE_LOW_QUANTILE
    upper_target = total * VERTICAL_CORE_HIGH_QUANTILE
    cumulative = 0
    lower_y = 0
    upper_y = image.height - 1
    found_lower = False
    for y, count in enumerate(row_counts):
        cumulative += count
        if not found_lower and cumulative >= lower_target:
            lower_y = y
            found_lower = True
        if cumulative >= upper_target:
            upper_y = y
            break

    centroid = sum(y * count for y, count in enumerate(row_counts)) / total
    return upper_y - lower_y + 1, centroid


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
    # Scale drift is judged only from neutral bookends. Mid-action articulation
    # (raised arms, sword arcs, hit lean) legitimately changes vertical core
    # height; density and baseline above still catch transient-frame problems.
    neutral_frames = (frames[0], frames[-1])
    core_metrics = [_vertical_core_metrics(frame) for frame in neutral_frames]
    core_heights = [height for height, _ in core_metrics]
    core_height_delta = max(core_heights) - min(core_heights)
    if core_height_delta > MAX_VERTICAL_CORE_HEIGHT_DELTA:
        raise ValueError(
            f"vertical core height delta {core_height_delta} "
            f"exceeds {MAX_VERTICAL_CORE_HEIGHT_DELTA}"
        )
    core_centroids = [centroid for _, centroid in core_metrics]
    core_centroid_delta = max(core_centroids) - min(core_centroids)
    if core_centroid_delta > MAX_VERTICAL_CORE_CENTROID_DELTA:
        raise ValueError(
            f"vertical core centroid delta {core_centroid_delta:.2f} "
            f"exceeds {MAX_VERTICAL_CORE_CENTROID_DELTA:.2f}"
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


def _validate_storyboard_frame_size(frame_size: int) -> None:
    if frame_size != STORYBOARD_FRAME_SIZE:
        raise ValueError(
            "storyboard frames must be 128x128 "
            f"(got {frame_size}x{frame_size})"
        )


def prepare_storyboard_frames(
    image: Image.Image, soldier: str, frame_size: int = 128
) -> list[Image.Image]:
    _validate_storyboard_frame_size(frame_size)
    key = SOLDIER_KEYS[soldier]
    normalized, cell_size, grid_top = _storyboard_geometry(image, key)
    _validate_source_gutters(normalized, cell_size, grid_top, key)
    frames = [
        _remove_key(
            _remove_key(cell, key).resize(
                (frame_size, frame_size), Image.Resampling.LANCZOS
            ),
            key,
        )
        for cell in storyboard_cells(normalized, key)
    ]
    for frame in frames:
        _validate_transparent_border(frame)
    _validate_sequence_metrics(frames)
    return frames


def _validate_trio_metrics(prepared: dict[str, list[Image.Image]]) -> None:
    from statistics import median

    metrics_by_action = {
        action: [_opaque_metrics(frame) for frame in prepared[action]]
        for action in ACTIONS
    }
    metrics = [
        metric
        for action in ACTIONS
        for metric in metrics_by_action[action]
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

    # Cross-action scale uses neutral bookends only; mid-action core height
    # variation is articulation, not scale drift.
    core_metrics = [
        _vertical_core_metrics(prepared[action][index])
        for action in ACTIONS
        for index in (0, -1)
    ]
    core_heights = [height for height, _ in core_metrics]
    core_height_delta = max(core_heights) - min(core_heights)
    if core_height_delta > MAX_VERTICAL_CORE_HEIGHT_DELTA:
        raise ValueError(
            f"trio vertical core height delta {core_height_delta} "
            f"exceeds {MAX_VERTICAL_CORE_HEIGHT_DELTA}"
        )
    neutral_heights = {
        action: median(
            metrics_by_action[action][index][1][3]
            - metrics_by_action[action][index][1][1]
            for index in (0, -1)
        )
        for action in ACTIONS
    }
    walk_height = neutral_heights["walk"]
    for action in ACTIONS:
        ratio = neutral_heights[action] / walk_height
        if abs(1.0 - ratio) > MAX_NEUTRAL_HEIGHT_SCALE_DELTA:
            raise ValueError(
                f"trio neutral-frame height ratio for {action} is {ratio:.2f}"
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


def resolve_within_repo(target: str) -> Path:
    """Resolve ``target`` and ensure it stays inside the repo root.

    Accepts absolute or relative paths, but the resolved location must be the
    repo root itself or a descendant of it. Raises ``argparse.ArgumentTypeError``
    so argparse surfaces the problem as a usage error.
    """
    resolved = Path(target).expanduser().resolve()
    try:
        resolved.relative_to(REPO_ROOT)
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"{target!r} resolves to {resolved}, which is outside the repo root {REPO_ROOT}"
        )
    return resolved


def write_contents_json(imageset: Path, filename: str) -> None:
    payload = {
        "images": [
            {"idiom": "universal", "filename": filename, "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    imageset.joinpath("Contents.json").write_text(json.dumps(payload, indent=2) + "\n")


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
    stage_root: Path, output: Path, soldier: str, actions: tuple[str, ...]
) -> None:
    backup_root = stage_root.parent / "backup"
    backup_root.mkdir()
    records: list[dict[str, object]] = []
    try:
        for action in actions:
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
    _validate_storyboard_frame_size(frame_size)
    frames = prepare_storyboard_frames(image, soldier, frame_size)
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(prefix=".soldier-animation-", dir=output) as directory:
        temp_root = Path(directory)
        stage_root = temp_root / "new"
        stage_root.mkdir()
        _write_staged_imagesets(frames, stage_root, soldier, action)
        _install_staged_imagesets_atomic(stage_root, output, soldier, (action,))


def slice_soldier_storyboards(
    images: dict[str, Image.Image],
    output: Path,
    soldier: str,
    frame_size: int = 128,
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


def main() -> None:
    parser = argparse.ArgumentParser()
    # ``--assets-dir`` is the OUTPUT root and is resolved/clamped to the repo
    # below so a faulty argument cannot write assets outside the project tree.
    # ``--storyboards-dir`` is a read-only INPUT, so it is intentionally NOT
    # clamped — source storyboards legitimately live outside the repo (e.g.
    # /tmp). The default for ``--assets-dir`` is resolved below because argparse
    # does not run ``type`` on defaults.
    parser.add_argument("--storyboards-dir", required=True)
    parser.add_argument("--assets-dir", default="Pyxis/Assets.xcassets")
    # Soldiers render at ~28-42 pt on screen, so 128 px is ample for 3x
    # devices without oversampling. 512 px wastes ~150 MB of GPU memory when
    # all five soldier types' animation sets are cached. See CLAUDE.md.
    parser.add_argument("--frame-size", type=int, default=128)
    parser.add_argument("--soldiers", nargs="+", choices=SOLDIERS, default=list(SOLDIERS))
    parser.add_argument("--actions", nargs="+", choices=ACTIONS, default=list(ACTIONS))
    args = parser.parse_args()

    try:
        assets_dir = resolve_within_repo(args.assets_dir)
    except argparse.ArgumentTypeError as exc:
        parser.error(str(exc))

    # Storyboard assets must be installed as complete walk/attack/hit trios
    # so every frame set passes cross-action validation
    # (`prepare_soldier_storyboards` -> `_validate_trio_metrics`). A partial
    # `--actions` selection would route through `slice_storyboard`, which
    # validates a single action only and could install scale-inconsistent
    # frames. `slice_storyboard` remains available for direct/test use.
    if set(args.actions) != set(ACTIONS):
        parser.error(
            "--storyboards-dir requires all three actions "
            f"({', '.join(ACTIONS)}); partial selections would bypass "
            "cross-action trio validation."
        )
    source_root = Path(args.storyboards_dir)
    for soldier in args.soldiers:
        images = {}
        for action in ACTIONS:
            source = source_root / f"{soldier}-{action}.png"
            if not source.exists():
                raise FileNotFoundError(source)
            images[action] = Image.open(source)
        slice_soldier_storyboards(
            images, assets_dir, soldier, args.frame_size
        )


if __name__ == "__main__":
    main()
