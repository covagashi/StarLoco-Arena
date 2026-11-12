#!/usr/bin/env python3
"""S37: movie-maker frames of vfx_sheet.gd → one screen-sized page per
shape, <out>-<shape>.png: a row per element, a column per moment of the
effect (the first replay, which starts at 0.3 s).

    python3 -I tools/fx/vfx_pages.py <frames dir> <out prefix>

The grid geometry mirrors vfx_sheet.gd (TILE, HEAD, the default order).
"""
import os
import sys

from PIL import Image, ImageDraw

SHAPES = ["bolt", "hit", "area", "aura", "curse", "heal", "summon", "trap", "tp"]
ELEMS = ["neutral", "fire", "earth", "water", "air"]
TILE = (200, 170)
HEAD = (70, 26)
FPS = 30
START = 0.3
MOMENTS = [0.05, 0.2, 0.35, 0.5, 0.75, 1.05, 1.4]
GOLD = (226, 189, 110)
BG = (20, 26, 33)


def main(src, out):
    frames = sorted(f for f in os.listdir(src) if f.endswith(".png"))
    if not frames:
        sys.exit("no frames in " + src)

    def frame(t):
        i = min(int(round((START + t) * FPS)), len(frames) - 1)
        return Image.open(os.path.join(src, frames[i])).convert("RGB")

    shots = [frame(t) for t in MOMENTS]
    for si, shape in enumerate(SHAPES):
        w = HEAD[0] + TILE[0] * len(MOMENTS)
        h = HEAD[1] + TILE[1] * len(ELEMS) + 30
        page = Image.new("RGB", (w, h), BG)
        d = ImageDraw.Draw(page)
        d.text((8, 6), f"S37 · {shape}", fill=GOLD)
        for mi, t in enumerate(MOMENTS):
            d.text((HEAD[0] + mi * TILE[0] + 80, h - 22), f"{t:.2f} s", fill=GOLD)
        for ei, elem in enumerate(ELEMS):
            y = HEAD[1] + ei * TILE[1]
            d.text((8, y + TILE[1] // 2 - 6), elem, fill=GOLD)
            x0 = HEAD[0] + si * TILE[0]
            for mi, shot in enumerate(shots):
                tile = shot.crop((x0, y, x0 + TILE[0], y + TILE[1]))
                page.paste(tile, (HEAD[0] + mi * TILE[0], y))
        page.save(f"{out}-{si + 1}-{shape}.png")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
