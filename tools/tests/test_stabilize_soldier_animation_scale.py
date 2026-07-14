from __future__ import annotations

import sys
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import slice_soldier_animation_strips as pipeline
import stabilize_soldier_animation_scale as stabilizer


def make_frame(index: int, height: int, baseline: int = 116) -> Image.Image:
    frame = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    left = 38 + index % 2
    ImageDraw.Draw(frame).rectangle(
        (left, baseline - height, left + 43, baseline - 1),
        fill=(30 + index, 80, 220, 255),
    )
    return frame


class SoldierAnimationScaleStabilizerTests(unittest.TestCase):
    def test_uniformly_stabilizes_complete_trio_to_walk_neutral_scale(self) -> None:
        frames = {
            "walk": [make_frame(index, 72 + index % 3) for index in range(10)],
            "attack": [make_frame(index, 68 + index % 4) for index in range(10)],
            "hit": [make_frame(index, 70 + index % 3) for index in range(10)],
        }

        stabilized = stabilizer.stabilize_trio(frames)

        core_heights = [
            pipeline._vertical_core_metrics(frame)[0]
            for action in pipeline.ACTIONS
            for frame in stabilized[action]
        ]
        baselines = [
            pipeline._opaque_metrics(frame)[1][3]
            for action in pipeline.ACTIONS
            for frame in stabilized[action]
        ]
        self.assertLessEqual(
            max(core_heights) - min(core_heights),
            pipeline.MAX_VERTICAL_CORE_HEIGHT_DELTA,
        )
        self.assertEqual(len(set(baselines)), 1)
        self.assertTrue(
            all(
                frame.size == (128, 128)
                for frames in stabilized.values()
                for frame in frames
            )
        )

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
