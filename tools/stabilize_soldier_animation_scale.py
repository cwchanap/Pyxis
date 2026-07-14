#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from statistics import median

from PIL import Image

import slice_soldier_animation_strips as pipeline

MIN_RESIZED_CANVAS = 112
MAX_RESIZED_CANVAS = 144


def _frame_path(
    assets_dir: Path, soldier: str, action: str, frame_number: int
) -> Path:
    name = f"{soldier}-{action}-{frame_number:02d}"
    return assets_dir / f"{name}.imageset" / f"{name}.png"


def _load_frame(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return image.convert("RGBA")


def _scaled_on_fixed_canvas(frame: Image.Image, resized_canvas: int) -> Image.Image:
    frame = frame.convert("RGBA")
    resized = frame.resize(
        (resized_canvas, resized_canvas), Image.Resampling.LANCZOS
    )
    output = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    offset = (frame.width - resized_canvas) // 2
    output.alpha_composite(resized, (offset, offset))
    return output


def _aligned_to_baseline(frame: Image.Image, target_baseline: int) -> Image.Image:
    bounds = frame.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("cannot stabilize an empty animation frame")

    output = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    output.alpha_composite(frame, (0, target_baseline - bounds[3]))
    return output


def stabilize_frame(
    frame: Image.Image,
    target_core_height: int,
    target_core_centroid: float,
    target_baseline: int,
) -> Image.Image:
    candidates: list[tuple[int, float, int, Image.Image]] = []
    for resized_canvas in range(MIN_RESIZED_CANVAS, MAX_RESIZED_CANVAS + 1):
        candidate = _aligned_to_baseline(
            _scaled_on_fixed_canvas(frame, resized_canvas), target_baseline
        )
        try:
            pipeline._validate_transparent_border(candidate)
        except ValueError:
            continue
        core_height, core_centroid = pipeline._vertical_core_metrics(candidate)
        candidates.append(
            (
                abs(core_height - target_core_height),
                abs(core_centroid - target_core_centroid),
                abs(resized_canvas - frame.width),
                candidate,
            )
        )

    if not candidates:
        raise ValueError("no uniform scale preserves the transparent frame border")
    minimum_core_error = min(candidate[0] for candidate in candidates)
    eligible = [
        candidate
        for candidate in candidates
        if candidate[0] <= minimum_core_error + 1
    ]
    return min(
        eligible,
        key=lambda candidate: (candidate[1], candidate[0], candidate[2]),
    )[3]


def stabilize_trio(
    frames_by_action: dict[str, list[Image.Image]],
) -> dict[str, list[Image.Image]]:
    if set(frames_by_action) != set(pipeline.ACTIONS):
        raise ValueError("soldier trio requires walk, attack, and hit frames")
    if any(
        len(frames_by_action[action]) != pipeline.FRAME_COUNT
        for action in pipeline.ACTIONS
    ):
        raise ValueError("each soldier action requires exactly ten frames")

    try:
        for frames in frames_by_action.values():
            pipeline._validate_sequence_metrics(frames)
        pipeline._validate_trio_metrics(frames_by_action)
    except ValueError:
        pass
    else:
        return {
            action: [frame.copy() for frame in frames_by_action[action]]
            for action in pipeline.ACTIONS
        }

    neutral_walk_frames = [
        frames_by_action["walk"][0],
        frames_by_action["walk"][-1],
    ]
    target_core_height = round(
        median(
            pipeline._vertical_core_metrics(frame)[0]
            for frame in neutral_walk_frames
        )
    )
    target_core_centroid = median(
        pipeline._vertical_core_metrics(frame)[1]
        for frame in neutral_walk_frames
    )
    target_baseline = round(
        median(
            pipeline._opaque_metrics(frame)[1][3]
            for frame in neutral_walk_frames
        )
    )

    stabilized = {
        action: [
            stabilize_frame(
                frame,
                target_core_height,
                target_core_centroid,
                target_baseline,
            )
            for frame in frames_by_action[action]
        ]
        for action in pipeline.ACTIONS
    }
    for frames in stabilized.values():
        pipeline._validate_sequence_metrics(frames)
    pipeline._validate_trio_metrics(stabilized)
    return stabilized


def load_trio(assets_dir: Path, soldier: str) -> dict[str, list[Image.Image]]:
    return {
        action: [
            _load_frame(_frame_path(assets_dir, soldier, action, frame_number))
            for frame_number in range(1, pipeline.FRAME_COUNT + 1)
        ]
        for action in pipeline.ACTIONS
    }


def write_trio(
    assets_dir: Path, soldier: str, frames_by_action: dict[str, list[Image.Image]]
) -> None:
    for action in pipeline.ACTIONS:
        for frame_number, frame in enumerate(frames_by_action[action], start=1):
            destination = _frame_path(assets_dir, soldier, action, frame_number)
            destination.parent.mkdir(parents=True, exist_ok=True)
            frame.save(destination)
            pipeline.write_contents_json(destination.parent, destination.name)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Uniformly stabilize authored soldier body scale on 128px frames."
    )
    parser.add_argument("--assets-dir", required=True, type=pipeline.resolve_within_repo)
    parser.add_argument(
        "--output-assets-dir", required=True, type=pipeline.resolve_within_repo
    )
    parser.add_argument(
        "--soldiers", nargs="+", required=True, choices=pipeline.SOLDIERS
    )
    args = parser.parse_args()

    stabilized_by_soldier = {
        soldier: stabilize_trio(load_trio(args.assets_dir, soldier))
        for soldier in args.soldiers
    }
    for soldier, frames_by_action in stabilized_by_soldier.items():
        write_trio(args.output_assets_dir, soldier, frames_by_action)
        heights = [
            pipeline._vertical_core_metrics(frame)[0]
            for action in pipeline.ACTIONS
            for frame in frames_by_action[action]
        ]
        print(
            f"{soldier}: wrote 30 frames; vertical core "
            f"{min(heights)}-{max(heights)}px"
        )


if __name__ == "__main__":
    main()
