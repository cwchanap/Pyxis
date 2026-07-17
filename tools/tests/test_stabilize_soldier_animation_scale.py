from __future__ import annotations

import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import slice_soldier_animation_strips as pipeline
import stabilize_soldier_animation_scale as stabilizer


def make_frame(
    index: int,
    height: int,
    baseline: int = 116,
    width: int = 44,
) -> Image.Image:
    frame = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    left = 38 + index % 2
    ImageDraw.Draw(frame).rectangle(
        (left, baseline - height, left + width - 1, baseline - 1),
        fill=(30 + index, 80, 220, 255),
    )
    return frame


def make_soldier_pose_frame(
    index: int,
    scale: float,
    weapon_length: int,
) -> Image.Image:
    frame = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    center_x = 62 + index % 2
    baseline = 116

    head_width = round(22 * scale)
    head_height = round(24 * scale)
    torso_width = round(30 * scale)
    torso_height = round(40 * scale)
    head_top = baseline - round(82 * scale)
    torso_top = head_top + head_height - 2

    draw.rectangle(
        (
            center_x - head_width // 2,
            head_top,
            center_x + head_width // 2,
            head_top + head_height,
        ),
        fill=(20, 75, 215, 255),
    )
    draw.rectangle(
        (
            center_x + 1,
            head_top + round(head_height * 0.45),
            center_x + head_width // 2 + 3,
            head_top + head_height - 2,
        ),
        fill=(220, 145, 95, 255),
    )
    draw.rectangle(
        (
            center_x - torso_width // 2,
            torso_top,
            center_x + torso_width // 2,
            torso_top + torso_height,
        ),
        fill=(90, 105, 120, 255),
    )
    draw.rectangle(
        (center_x - 12, torso_top + torso_height, center_x - 3, baseline - 1),
        fill=(80, 55, 40, 255),
    )
    draw.rectangle(
        (center_x + 3, torso_top + torso_height, center_x + 12, baseline - 1),
        fill=(80, 55, 40, 255),
    )
    draw.rectangle(
        (
            center_x + torso_width // 2,
            torso_top + 8,
            center_x + torso_width // 2 + weapon_length,
            torso_top + 13,
        ),
        fill=(205, 210, 220, 255),
    )
    return frame


class SoldierAnimationScaleStabilizerTests(unittest.TestCase):
    def test_derives_one_canvas_scale_for_each_complete_action(self) -> None:
        frames = {
            "walk": [
                make_soldier_pose_frame(index, 1.0, 18)
                for index in range(10)
            ],
            "attack": [
                make_soldier_pose_frame(index, 0.88, 34)
                for index in range(10)
            ],
            "hit": [
                make_soldier_pose_frame(index, 1.10, 18)
                for index in range(10)
            ],
        }

        canvas_sizes = stabilizer.action_canvas_sizes(frames)

        self.assertEqual(canvas_sizes["walk"], 128)
        self.assertGreater(canvas_sizes["attack"], 128)
        self.assertLess(canvas_sizes["hit"], 128)

    def test_normalizes_action_neutral_scale_without_flattening_weapon_motion(self) -> None:
        scales = [0.92, 0.96, 1.00, 1.04, 1.08, 1.04, 1.00, 0.96, 0.92, 1.00]
        weapon_lengths = [12, 16, 22, 30, 40, 34, 28, 22, 16, 12]
        frames = {
            action: [
                make_soldier_pose_frame(index, scales[index], weapon_lengths[index])
                for index in range(10)
            ]
            for action in pipeline.ACTIONS
        }

        stabilized = stabilizer.stabilize_trio(frames)

        helmet_scales = [
            stabilizer.helmet_scale_metric(stabilized[action][0])
            for action in pipeline.ACTIONS
        ]
        weapon_extents = [
            pipeline._opaque_metrics(frame)[1][2]
            for frame in stabilized["attack"]
        ]
        self.assertLessEqual(max(helmet_scales) - min(helmet_scales), 0.8)
        self.assertGreater(max(weapon_extents) - min(weapon_extents), 12)

    def test_uniformly_stabilizes_complete_trio_to_walk_neutral_scale(self) -> None:
        frames = {
            "walk": [make_frame(index, 72 + index % 3) for index in range(10)],
            "attack": [make_frame(index, 68 + index % 4) for index in range(10)],
            "hit": [make_frame(index, 70 + index % 3) for index in range(10)],
        }

        stabilized = stabilizer.stabilize_trio(frames)

        helmet_scales = [
            stabilizer.helmet_scale_metric(frame)
            for action in pipeline.ACTIONS
            for frame in stabilized[action]
        ]
        baselines = [
            pipeline._opaque_metrics(frame)[1][3]
            for action in pipeline.ACTIONS
            for frame in stabilized[action]
        ]
        self.assertLessEqual(max(helmet_scales) - min(helmet_scales), 0.8)
        self.assertEqual(len(set(baselines)), 1)
        self.assertTrue(
            all(
                frame.size == (128, 128)
                for frames in stabilized.values()
                for frame in frames
            )
        )

    def test_does_not_choose_a_different_scale_for_individual_action_frames(self) -> None:
        walk_scales = [1.0] * 10
        attack_scales = [1.0, 1.0, 1.0, 1.0, 1.12, 1.0, 1.0, 1.0, 1.0, 1.0]
        hit_scales = [1.0, 1.0, 0.92, 0.92, 0.92, 0.92, 1.0, 1.0, 1.0, 1.0]
        frames = {
            "walk": [
                make_soldier_pose_frame(index, scale, 18)
                for index, scale in enumerate(walk_scales)
            ],
            "attack": [
                make_soldier_pose_frame(index, scale, 18)
                for index, scale in enumerate(attack_scales)
            ],
            "hit": [
                make_soldier_pose_frame(index, scale, 18)
                for index, scale in enumerate(hit_scales)
            ],
        }

        canvas_sizes = stabilizer.action_canvas_sizes(frames)

        self.assertEqual(canvas_sizes["walk"], 128)
        self.assertEqual(canvas_sizes["attack"], 128)
        self.assertEqual(canvas_sizes["hit"], 128)

    def test_requires_all_ten_frames_for_every_action(self) -> None:
        frames = {
            action: [make_frame(index, 72) for index in range(10)]
            for action in pipeline.ACTIONS
        }
        frames["hit"].pop()

        with self.assertRaisesRegex(ValueError, "exactly ten"):
            stabilizer.stabilize_trio(frames)

    def test_is_idempotent_after_trio_passes_strict_validation(self) -> None:
        frames = {
            "walk": [make_frame(index, 72 + index % 3) for index in range(10)],
            "attack": [make_frame(index, 68 + index % 4) for index in range(10)],
            "hit": [make_frame(index, 70 + index % 3) for index in range(10)],
        }

        stabilized = stabilizer.stabilize_trio(frames)
        stabilized_again = stabilizer.stabilize_trio(stabilized)

        self.assertTrue(
            all(
                first.tobytes() == second.tobytes()
                for action in pipeline.ACTIONS
                for first, second in zip(
                    stabilized[action], stabilized_again[action]
                )
            )
        )


if __name__ == "__main__":
    unittest.main()
