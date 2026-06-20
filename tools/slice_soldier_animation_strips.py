#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

SOLDIERS = ("infantry", "archer", "cavalry", "mage", "siege")
ACTIONS = ("walk", "attack", "hit")
FRAME_COUNT = 10

# Assets are always written under the repo root (the current working directory
# when the script is invoked). Paths supplied via CLI are resolved and clamped
# to this root so a faulty --assets-dir cannot escape the project tree.
REPO_ROOT = Path.cwd().resolve()


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


def slice_strip(strip: Path, output: Path, soldier: str, action: str, frame_size: int) -> None:
    image = strip_chroma_key(Image.open(strip))
    output_resolved = output.resolve()

    for index in range(FRAME_COUNT):
        left = round(image.width * index / FRAME_COUNT)
        right = round(image.width * (index + 1) / FRAME_COUNT)
        raw_frame = image.crop((left, 0, right, image.height))
        canvas = centered_square_frame(raw_frame, frame_size)

        asset_name = f"{soldier}-{action}-{index + 1:02d}"
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
    # ``type=resolve_within_repo`` validates each user-supplied path during
    # parsing so a faulty argument is rejected with a clean usage error before
    # any filesystem access happens. The default for ``--assets-dir`` is
    # resolved below because argparse does not run ``type`` on defaults.
    parser.add_argument("--strips-dir", required=True, type=resolve_within_repo)
    parser.add_argument("--assets-dir", default="Pyxis/Assets.xcassets")
    parser.add_argument("--frame-size", type=int, default=512)
    args = parser.parse_args()

    strips_dir = args.strips_dir
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
