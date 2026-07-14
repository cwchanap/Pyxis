from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import patch

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


def make_action_boards() -> dict[str, Image.Image]:
    boxes = [
        (16 + index % 2, 16, 47 + index % 2, 47)
        for index in range(10)
    ]
    return {action: make_metric_board(boxes) for action in pipeline.ACTIONS}


def make_antialiased_chroma_edge_board() -> Image.Image:
    cell_size = 355
    board = Image.new(
        "RGBA", (cell_size * 5, cell_size * 2 + 177), pipeline.SOLDIER_KEYS["archer"]
    )
    top = 88
    for index in range(pipeline.FRAME_COUNT):
        column = index % 5
        row = index // 5
        left = column * cell_size
        upper = top + row * cell_size
        antialiased_cell = Image.new(
            "RGBA", (cell_size * 4, cell_size * 4), pipeline.SOLDIER_KEYS["archer"]
        )
        ImageDraw.Draw(antialiased_cell).ellipse(
            (61 * 4, 50 * 4, 280 * 4, 287 * 4), fill=(20 + index, 0, 0, 255)
        )
        board.alpha_composite(
            antialiased_cell.resize((cell_size, cell_size), Image.Resampling.LANCZOS),
            (left, upper),
        )
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


class StoryboardValidationTests(unittest.TestCase):
    def test_rejects_non_128_storyboard_frame_size(self) -> None:
        board, _ = make_board()

        with self.assertRaisesRegex(ValueError, "128x128"):
            pipeline.prepare_storyboard_frames(board, soldier="infantry", frame_size=64)

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

    def test_prepared_archer_frames_remove_resampling_key_color_fringe(self) -> None:
        frames = pipeline.prepare_storyboard_frames(
            make_antialiased_chroma_edge_board(), soldier="archer"
        )

        key_red, key_green, key_blue, _ = pipeline.SOLDIER_KEYS["archer"]
        for frame in frames:
            for red, green, blue, alpha in frame.getdata():
                if alpha == 0:
                    continue
                self.assertNotEqual((red, green, blue), (key_red, key_green, key_blue))
                self.assertFalse(red == blue and red >= 128 and green < red)

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

    def test_rejects_mid_action_vertical_core_compression(self) -> None:
        boxes = [
            (19 + index % 2, 19, 44 + index % 2, 44)
            if 3 <= index <= 6
            else (16 + index % 2, 16, 47 + index % 2, 47)
            for index in range(10)
        ]

        with self.assertRaisesRegex(ValueError, "vertical core height delta"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")

    def test_rejects_mid_action_vertical_core_centroid_drift(self) -> None:
        boxes = [
            (16 + index % 2, 19, 47 + index % 2, 50)
            if 3 <= index <= 6
            else (16 + index % 2, 16, 47 + index % 2, 47)
            for index in range(10)
        ]

        with self.assertRaisesRegex(ValueError, "vertical core centroid delta"):
            pipeline.prepare_storyboard_frames(make_metric_board(boxes), "infantry")


class SoldierTrioValidationTests(unittest.TestCase):
    def assert_action_boards_are_individually_valid(
        self, boards: dict[str, Image.Image]
    ) -> None:
        for action in pipeline.ACTIONS:
            frames = pipeline.prepare_storyboard_frames(boards[action], "infantry")
            self.assertEqual(len(frames), pipeline.FRAME_COUNT)

    def test_prepares_all_thirty_frames(self) -> None:
        prepared = pipeline.prepare_soldier_storyboards(
            make_action_boards(), soldier="infantry"
        )

        self.assertEqual(set(prepared), set(pipeline.ACTIONS))
        self.assertTrue(all(len(frames) == 10 for frames in prepared.values()))

    def test_rejects_cross_action_baseline_drift(self) -> None:
        boards = make_action_boards()
        shifted = [
            (16 + index % 2, 8, 47 + index % 2, 39)
            for index in range(10)
        ]
        boards["hit"] = make_metric_board(shifted)

        with self.assertRaisesRegex(ValueError, "trio baseline"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

    def test_rejects_cross_action_density_drift(self) -> None:
        boards = make_action_boards()
        boards["hit"] = make_metric_board(
            [(24 + index % 2, 24, 39 + index % 2, 39) for index in range(10)]
        )

        self.assert_action_boards_are_individually_valid(boards)

        with self.assertRaisesRegex(ValueError, "trio opaque pixel count"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

    def test_rejects_cross_action_height_drift(self) -> None:
        boards = make_action_boards()
        boards["hit"] = make_metric_board(
            [(24 + index % 2, 8, 39 + index % 2, 55) for index in range(10)]
        )

        self.assert_action_boards_are_individually_valid(boards)

        with self.assertRaisesRegex(ValueError, "trio bounding-box height"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

    def test_rejects_cross_action_neutral_frame_height_drift(self) -> None:
        boards = make_action_boards()
        boards["attack"] = make_metric_board(
            [(18 + index % 2, 18, 45 + index % 2, 45) for index in range(10)]
        )

        self.assert_action_boards_are_individually_valid(boards)

        with self.assertRaisesRegex(ValueError, "trio neutral-frame height"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

    def test_allows_mid_action_posture_change_when_neutral_scale_matches(self) -> None:
        boards = make_action_boards()
        hit_boxes = [
            (17 + index % 2, 17, 46 + index % 2, 46)
            if 3 <= index <= 6
            else (16 + index % 2, 16, 47 + index % 2, 47)
            for index in range(10)
        ]
        boards["hit"] = make_metric_board(hit_boxes)

        prepared = pipeline.prepare_soldier_storyboards(
            boards, soldier="infantry"
        )

        self.assertEqual(set(prepared), set(pipeline.ACTIONS))

    def test_requires_exactly_walk_attack_and_hit(self) -> None:
        boards = make_action_boards()
        del boards["hit"]

        with self.assertRaisesRegex(ValueError, "walk, attack, and hit"):
            pipeline.prepare_soldier_storyboards(boards, soldier="infantry")

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

    def test_rename_failure_restores_every_preexisting_imageset(self) -> None:
        from tempfile import TemporaryDirectory

        with TemporaryDirectory() as directory:
            output = Path(directory)
            sentinels: dict[Path, str] = {}
            for action in pipeline.ACTIONS:
                for index in range(1, pipeline.FRAME_COUNT + 1):
                    imageset = output / f"infantry-{action}-{index:02d}.imageset"
                    sentinel = imageset / "sentinel.txt"
                    sentinel.parent.mkdir(parents=True)
                    sentinel_value = f"{action}-{index:02d}"
                    sentinel.write_text(sentinel_value, encoding="utf-8")
                    sentinels[sentinel] = sentinel_value

            completed_walk_installs: list[str] = []
            original_rename = Path.rename

            def fail_staged_attack_install(path: Path, target: Path) -> Path:
                if path.parent.name == "new" and path.name.startswith("infantry-walk-"):
                    completed_walk_installs.append(path.name)
                if (
                    path.parent.name == "new"
                    and path.name == "infantry-attack-01.imageset"
                ):
                    raise OSError("injected staged attack install failure")
                return original_rename(path, target)

            with patch.object(
                Path, "rename", autospec=True, side_effect=fail_staged_attack_install
            ):
                with self.assertRaisesRegex(OSError, "injected staged attack"):
                    pipeline.slice_soldier_storyboards(
                        make_action_boards(), output, "infantry", 128
                    )

            self.assertEqual(len(completed_walk_installs), pipeline.FRAME_COUNT)
            for sentinel, sentinel_value in sentinels.items():
                self.assertEqual(sentinel.read_text(encoding="utf-8"), sentinel_value)
