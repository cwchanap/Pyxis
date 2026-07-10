#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import TypeAlias

from PIL import Image

SOLDIERS = ("infantry", "archer", "cavalry", "mage", "siege")
ACTIONS = ("walk", "attack", "hit")
FRAME_COUNT = 10
RGBAColor: TypeAlias = tuple[int, int, int, int]
STORYBOARD_COLUMNS = 5
STORYBOARD_ROWS = 2

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


def strip_chroma_key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()

    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            is_key = green > 150 and red < 95 and blue < 95 and green > red * 1.6 and green > blue * 1.6
            if is_key:
                pixels[x, y] = (red, green, blue, 0)
            elif alpha > 0 and green > red * 1.25 and green > blue * 1.25:
                # Light despill on antialiased edges without touching darker green costumes.
                pixels[x, y] = (red, min(green, max(red, blue) + 28), blue, alpha)

    return rgba


def centered_square_frame(frame: Image.Image, frame_size: int) -> Image.Image:
    transparent = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    bbox = frame.getbbox()
    if bbox is None:
        return transparent

    content = frame.crop(bbox)
    content.thumbnail((frame_size, frame_size), Image.Resampling.LANCZOS)
    transparent.alpha_composite(
        content,
        ((frame_size - content.width) // 2, frame_size - content.height),
    )
    return transparent


def _opaque_pixel_count(image: Image.Image) -> int:
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    pixels = image.load()
    return sum(1 for y in range(image.height) for x in range(image.width) if pixels[x, y][3] > 0)


def _validate_content_density(
    canvases: list[Image.Image],
    soldier: str,
    action: str,
    threshold: float = 0.40,
) -> None:
    """Reject strips where any frame has dramatically less content than its siblings.

    A frame whose opaque-pixel count is below ``threshold * median`` typically
    indicates a source-art defect (missing drawing, or chroma-key eating the
    character) — the kind of frame that compresses to a tiny PNG and visibly
    flickers every animation cycle. Failing here is far cheaper than shipping
    the artifact. A strip whose median is 0 (entirely empty) is a different
    failure mode and is allowed through this check.
    """
    counts = [_opaque_pixel_count(c) for c in canvases]
    sorted_counts = sorted(counts)
    median = sorted_counts[len(sorted_counts) // 2]
    if median == 0:
        return
    offenders = [
        (index + 1, count)
        for index, count in enumerate(counts)
        if count < threshold * median
    ]
    if offenders:
        rendered = ", ".join(
            f"frame {n}={c}px ({100 * c / median:.0f}% of median)" for n, c in offenders
        )
        raise ValueError(
            f"{soldier}-{action}: content density check failed ({rendered}; "
            f"median={median}px, threshold={int(threshold * 100)}% of median). "
            "Inspect the source strip — likely a missing drawing or chroma-key over-removal."
        )


def slice_strip(strip: Path, output: Path, soldier: str, action: str, frame_size: int) -> None:
    image = strip_chroma_key(Image.open(strip))
    output_resolved = output.resolve()

    # Slice every frame first, then run the content-density guard before writing
    # any files. This keeps a defective strip from leaving behind a partial
    # asset tree that masks the original problem on re-runs.
    canvases: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        left = round(image.width * index / FRAME_COUNT)
        right = round(image.width * (index + 1) / FRAME_COUNT)
        raw_frame = image.crop((left, 0, right, image.height))
        canvases.append(centered_square_frame(raw_frame, frame_size))

    _validate_content_density(canvases, soldier=soldier, action=action)

    for index, canvas in enumerate(canvases, start=1):
        asset_name = f"{soldier}-{action}-{index:02d}"
        imageset = output_resolved / f"{asset_name}.imageset"
        # Validate the constructed path stays under the declared output root
        # before touching the filesystem (defends against faulty CLI arguments).
        imageset.relative_to(output_resolved)
        imageset.mkdir(parents=True, exist_ok=True)

        filename = f"{asset_name}.png"
        canvas.save(imageset / filename)
        write_contents_json(imageset, filename)


def main() -> None:
    parser = argparse.ArgumentParser()
    # ``--assets-dir`` is the OUTPUT root and is resolved/clamped to the repo
    # below so a faulty argument cannot write assets outside the project tree.
    # ``--strips-dir`` is a read-only INPUT, so it is intentionally NOT clamped
    # — source strips legitimately live outside the repo (e.g. /tmp). The
    # default for ``--assets-dir`` is resolved below because argparse does not
    # run ``type`` on defaults.
    parser.add_argument("--strips-dir", required=True)
    parser.add_argument("--assets-dir", default="Pyxis/Assets.xcassets")
    # Soldiers render at ~28-42 pt on screen, so 128 px is ample for 3x
    # devices without oversampling. 512 px wastes ~150 MB of GPU memory when
    # all five soldier types' animation sets are cached. See CLAUDE.md.
    parser.add_argument("--frame-size", type=int, default=128)
    args = parser.parse_args()

    strips_dir = Path(args.strips_dir)
    try:
        assets_dir = resolve_within_repo(args.assets_dir)
    except argparse.ArgumentTypeError as exc:
        parser.error(str(exc))

    for soldier in SOLDIERS:
        for action in ACTIONS:
            strip = strips_dir / f"{soldier}-{action}.png"
            if not strip.exists():
                raise FileNotFoundError(strip)
            slice_strip(strip, assets_dir, soldier, action, args.frame_size)


if __name__ == "__main__":
    main()
