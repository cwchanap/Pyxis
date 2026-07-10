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
