#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import deque
from math import sqrt
from pathlib import Path
from statistics import median
from typing import Callable

from PIL import Image

import slice_soldier_animation_strips as pipeline

MIN_RESIZED_CANVAS = 112
MAX_RESIZED_CANVAS = 148
MIN_HEAD_COMPONENT_PIXELS = 8
HELMET_SAMPLE_HEIGHT = 24
HELMET_SAMPLE_HALF_WIDTH = 22
MAX_NEUTRAL_HELMET_ERROR = 0.7
MAX_NEUTRAL_BODY_ERROR = 1.2


def _is_helmet_blue(red: int, green: int, blue: int, alpha: int) -> bool:
    return (
        alpha >= 96
        and blue >= 90
        and blue > red * 1.35
        and blue > green * 1.15
    )


def _color_components(
    image: Image.Image,
    predicate: Callable[[int, int, int, int], bool],
) -> list[list[tuple[int, int]]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    mask = {
        (x, y)
        for y in range(rgba.height)
        for x in range(rgba.width)
        if predicate(*pixels[x, y])
    }
    components: list[list[tuple[int, int]]] = []
    while mask:
        start = min(mask, key=lambda point: (point[1], point[0]))
        mask.remove(start)
        pending = deque([start])
        component: list[tuple[int, int]] = []
        while pending:
            x, y = pending.popleft()
            component.append((x, y))
            for neighbor in (
                (x - 1, y - 1),
                (x, y - 1),
                (x + 1, y - 1),
                (x - 1, y),
                (x + 1, y),
                (x - 1, y + 1),
                (x, y + 1),
                (x + 1, y + 1),
            ):
                if neighbor in mask:
                    mask.remove(neighbor)
                    pending.append(neighbor)
        if len(component) >= MIN_HEAD_COMPONENT_PIXELS:
            components.append(component)
    return components


def _helmet_blue_components(image: Image.Image) -> list[list[tuple[int, int]]]:
    return _color_components(image, _is_helmet_blue)


def _helmet_sample_origin(image: Image.Image) -> tuple[int, int]:
    components = _helmet_blue_components(image)
    if not components:
        raise ValueError("frame has no blue helmet component")
    top = min(min(y for _, y in component) for component in components)
    head_components = [
        component
        for component in components
        if min(y for _, y in component) <= top + 15
    ]
    head_xs = [x for component in head_components for x, _ in component]
    center_x = round((min(head_xs) + max(head_xs)) / 2)
    return center_x, top


def helmet_scale_metric(image: Image.Image) -> float:
    center_x, top = _helmet_sample_origin(image)
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    blue_count = sum(
        _is_helmet_blue(*pixels[x, y])
        for y in range(top, min(rgba.height, top + HELMET_SAMPLE_HEIGHT))
        for x in range(
            max(0, center_x - HELMET_SAMPLE_HALF_WIDTH),
            min(rgba.width, center_x + HELMET_SAMPLE_HALF_WIDTH + 1),
        )
    )
    if blue_count == 0:
        raise ValueError("frame has no blue helmet pixels")
    return sqrt(blue_count)


def body_scale_metric(image: Image.Image) -> float:
    center_x, top = _helmet_sample_origin(image)
    baseline = pipeline._opaque_metrics(image)[1][3]
    half_width = round((baseline - top) * 0.34)
    alpha = image.getchannel("A")
    region = alpha.crop(
        (
            max(0, center_x - half_width),
            max(0, top),
            min(image.width, center_x + half_width + 1),
            min(image.height, baseline),
        )
    )
    opaque_count = sum(1 for value in region.getdata() if value >= 96)
    if opaque_count == 0:
        raise ValueError("frame has no opaque body pixels")
    return sqrt(opaque_count)


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


def _neutral_scale_metrics(frame: Image.Image) -> tuple[float, float]:
    return helmet_scale_metric(frame), body_scale_metric(frame)


def action_canvas_sizes(
    frames_by_action: dict[str, list[Image.Image]],
) -> dict[str, int]:
    reference_metrics = _neutral_scale_metrics(frames_by_action["walk"][0])
    canvas_sizes = {"walk": pipeline.STORYBOARD_FRAME_SIZE}
    for action in ("attack", "hit"):
        source_metrics = _neutral_scale_metrics(frames_by_action[action][0])
        if (
            abs(source_metrics[0] - reference_metrics[0])
            <= MAX_NEUTRAL_HELMET_ERROR
            and abs(source_metrics[1] - reference_metrics[1])
            <= MAX_NEUTRAL_BODY_ERROR
        ):
            canvas_sizes[action] = pipeline.STORYBOARD_FRAME_SIZE
            continue
        scale = median(
            reference / source
            for reference, source in zip(reference_metrics, source_metrics)
        )
        canvas_sizes[action] = max(
            MIN_RESIZED_CANVAS,
            min(MAX_RESIZED_CANVAS, round(pipeline.STORYBOARD_FRAME_SIZE * scale)),
        )
    return canvas_sizes


def _validate_uniform_action_scale(
    frames_by_action: dict[str, list[Image.Image]],
) -> None:
    frames = [
        frame
        for action in pipeline.ACTIONS
        for frame in frames_by_action[action]
    ]
    for frame in frames:
        pipeline._validate_transparent_border(frame)

    baselines = [pipeline._opaque_metrics(frame)[1][3] for frame in frames]
    if max(baselines) != min(baselines):
        raise ValueError("uniformly scaled frames must share one baseline")

    for action in pipeline.ACTIONS:
        for index, (first, second) in enumerate(
            zip(frames_by_action[action], frames_by_action[action][1:]),
            start=1,
        ):
            if first.tobytes() == second.tobytes():
                raise ValueError(
                    f"{action} frames {index} and {index + 1} are pixel-identical"
                )
    reference_helmet, reference_body = _neutral_scale_metrics(
        frames_by_action["walk"][0]
    )
    for action in ("attack", "hit"):
        helmet, body = _neutral_scale_metrics(frames_by_action[action][0])
        helmet_error = abs(helmet - reference_helmet)
        body_error = abs(body - reference_body)
        if helmet_error > MAX_NEUTRAL_HELMET_ERROR:
            raise ValueError(
                f"{action} neutral helmet scale error {helmet_error:.2f} "
                f"exceeds {MAX_NEUTRAL_HELMET_ERROR:.2f}"
            )
        if body_error > MAX_NEUTRAL_BODY_ERROR:
            raise ValueError(
                f"{action} neutral body scale error {body_error:.2f} "
                f"exceeds {MAX_NEUTRAL_BODY_ERROR:.2f}"
            )


def _action_profiles_are_stable(
    frames_by_action: dict[str, list[Image.Image]],
) -> bool:
    baselines = [
        pipeline._opaque_metrics(frame)[1][3]
        for action in pipeline.ACTIONS
        for frame in frames_by_action[action]
    ]
    if max(baselines) != min(baselines):
        return False
    return all(
        canvas_size == pipeline.STORYBOARD_FRAME_SIZE
        for canvas_size in action_canvas_sizes(frames_by_action).values()
    )


def stabilize_frame(
    frame: Image.Image,
    resized_canvas: int,
    target_baseline: int,
) -> Image.Image:
    candidate = _aligned_to_baseline(
        _scaled_on_fixed_canvas(frame, resized_canvas), target_baseline
    )
    pipeline._validate_transparent_border(candidate)
    return candidate


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

    canvas_sizes = action_canvas_sizes(frames_by_action)
    if _action_profiles_are_stable(frames_by_action):
        return {
            action: [frame.copy() for frame in frames_by_action[action]]
            for action in pipeline.ACTIONS
        }

    neutral_walk_frames = [
        frames_by_action["walk"][0],
        frames_by_action["walk"][-1],
    ]
    target_baseline = round(
        median(
            pipeline._opaque_metrics(frame)[1][3]
            for frame in neutral_walk_frames
        )
    )
    stabilized = {
        action: [
            stabilize_frame(frame, canvas_sizes[action], target_baseline)
            for frame in frames_by_action[action]
        ]
        for action in pipeline.ACTIONS
    }
    _validate_uniform_action_scale(stabilized)
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
        print(f"{soldier}: wrote 30 frames with one uniform scale per action")


if __name__ == "__main__":
    main()
