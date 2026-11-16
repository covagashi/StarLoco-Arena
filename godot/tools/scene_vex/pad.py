"""Crop each vex figure to the menus' layout convention: exactly 32 px of
transparent padding on every side of the figure (so figure height = image
height - 64, feet at the bottom edge of the content box), a soft contact
shadow inside the bottom padding, and a palette PNG when the file is heavy.
  python3 pad.py out/sprites <dest>
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

src, dst = sys.argv[1:3]
PAD = 32
NAMES = ["fighter_a", "fighter_b", "coach", "story_a", "story_b", "tour", "coach_ghost"]
for n in NAMES:
    im = Image.open(os.path.join(src, n + ".png")).convert("RGBA")
    a = im.getchannel("A")
    if n == "coach_ghost":
        # the blur has a long faint tail: cut it where it stops being visible
        a = a.point(lambda v: 255 if v > 24 else 0)
    box = a.getbbox()
    fig = im.crop(box)
    W, H = fig.width + 2 * PAD, fig.height + 2 * PAD
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if n != "coach_ghost":
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cx, cy = W / 2, H - PAD + 9
        rx = fig.width * 0.34
        ImageDraw.Draw(sh).ellipse((cx - rx, cy - 8, cx + rx, cy + 8), fill=(28, 32, 48, 70))
        sh = sh.filter(ImageFilter.GaussianBlur(3))
        # keep it inside the bottom padding, under the feet
        mask = Image.new("L", (W, H), 0)
        ImageDraw.Draw(mask).rectangle((0, H - PAD - 2, W, H), fill=255)
        out = Image.composite(sh, out, mask)
    out.alpha_composite(fig, (PAD, PAD))
    path = os.path.join(dst, n + ".png")
    out.save(path, optimize=True)
    if os.path.getsize(path) > 250 * 1024:
        q = out.quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
        q.save(path, optimize=True)
    print(f"{n}: {W}x{H} figure {fig.width}x{fig.height} {os.path.getsize(path) // 1024} KB")
