#!/usr/bin/env python3
"""The app mark, kept as a grid of characters rather than as a binary.

A PNG in a diff says only that some bytes changed. This says what changed, and
anyone can move a pixel without a drawing program:

    python3 assets/logo.py

The mark is the deck fanning out -- four tabs stepping toward the screen edge,
each in one of the note colours. That movement is the app; a yellow square
with a folded corner is every notes app since 1998.
"""
import subprocess
import os

PALETTE = {
    ".": None,                  # transparent
    "Y": "#FBDC6E", "B": "#A9CDFA", "G": "#A9E9C6", "P": "#D9C9F7",
}

# No outline. A rim reads at 256px and eats the mark at 18: the coloured tabs
# fall to a pixel each and the whole thing greys out. Colour is what survives
# the small sizes, so colour is all there is.
FAN = """
................
..........YYYYYY
..........YYYYYY
..........YYYYYY
................
........BBBBBBBB
........BBBBBBBB
........BBBBBBBB
................
......GGGGGGGGGG
......GGGGGGGGGG
......GGGGGGGGGG
................
....PPPPPPPPPPPP
....PPPPPPPPPPPP
....PPPPPPPPPPPP
"""

SIZES = (16, 32, 64, 256)


def render(grid, path, size):
    rows = [row for row in grid.strip("\n").split("\n")]
    width, height = len(rows[0]), len(rows)
    for row in rows:
        assert len(row) == width, "ragged row: " + row

    args = ["magick", "-size", f"{width}x{height}", "xc:none"]
    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            colour = PALETTE[char]
            if colour is not None:
                args += ["-fill", colour, "-draw", f"point {x},{y}"]
    # Nearest neighbour, so a pixel stays a pixel at every size.
    args += ["-filter", "point", "-resize", f"{size}x{size}", path]
    subprocess.run(args, check=True)


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for size in SIZES:
        path = os.path.join(here, f"logo-{size}.png")
        render(FAN, path, size)
        print("wrote", os.path.basename(path))
