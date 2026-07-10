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
