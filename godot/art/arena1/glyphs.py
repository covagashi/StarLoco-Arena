#!/usr/bin/env python3
"""Baybayin glyphs for the arena 1 slabs and floor runes, "like a trap"
(owner's idea), drawn with Noto Sans Tagalog (art/fonts, OFL). Each PNG is a
512 px mask, white glyph on black, centred on the texture CORNER: kiln
projects UVs from the model origin (the cell centre), so the corner lands in
the middle of the piece. loom reads them with image(...).luma().

    python3 glyphs.py        (writes out/glyphs/<name>.png)
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT = HERE.parent / "fonts" / "NotoSansTagalog-Regular.ttf"
# slab: ha, ba, ka; rune: la, ta, sa
GLYPHS = {"slab_a": "ᜑ", "slab_b": "ᜊ", "slab_c": "ᜃ",
          "rune_a": "ᜎ", "rune_b": "ᜆ", "rune_c": "ᜐ"}
SIZE = 512


def glyph(ch: str, scale: float) -> Image.Image:
    f = ImageFont.truetype(str(FONT), int(SIZE * scale))
    im = Image.new("L", (SIZE, SIZE), 0)
    d = ImageDraw.Draw(im)
    l, t, r, b = d.textbbox((0, 0), ch, font=f)
    d.text(((SIZE - (r - l)) / 2 - l, (SIZE - (b - t)) / 2 - t), ch, font=f, fill=255)
    # move the centre to the corner (the image wraps)
    h = SIZE // 2
    out = Image.new("L", (SIZE, SIZE))
    for (sx, sy), (dx, dy) in {((0, 0), (h, h)), ((h, 0), (0, h)), ((0, h), (h, 0)), ((h, h), (0, 0))}:
        out.paste(im.crop((sx, sy, sx + h, sy + h)), (dx, dy))
    return out


if __name__ == "__main__":
    out = HERE / "out" / "glyphs"
    out.mkdir(parents=True, exist_ok=True)
    for name, ch in GLYPHS.items():
        glyph(ch, 0.62 if name.startswith("slab") else 0.36).save(out / f"{name}.png")
    print(len(GLYPHS), "glyphs ->", out)
