#!/usr/bin/env python3
"""S35: frames from anim_sheet.gd → screen-sized pages (one animation per
row, labelled) or one MP4 (every animation in turn, the directions side by
side, titled).

    python3 -I tools/art/anim_sheet.py <frames dir> <out.png | out.mp4> [--rows=5]

Pages are <out>-1.png, <out>-2.png… (owner: no tall strips).
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw


def label(img, text):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 8 * len(text) + 12, 20), fill=(20, 26, 33))
    d.text((6, 4), text, fill=(226, 189, 110))


def sheet(src, out, rows):
    idx = json.load(open(os.path.join(src, "index.json")))
    anims, dirs = idx["anims"], idx["dirs"]
    first = Image.open(os.path.join(src, anims[0], f"{dirs[0]}_00.png"))
    w, h = first.size
    pages = [anims[i:i + rows] for i in range(0, len(anims), rows)]
    base = out[:-4]
    for p, group in enumerate(pages, 1):
        cols = max(idx["index"][a]["frames"] for a in group) * len(dirs)
        page = Image.new("RGB", (w * cols, h * len(group)), (28, 35, 44))
        for r, a in enumerate(group):
            n = idx["index"][a]["frames"]
            for di, d in enumerate(dirs):
                for i in range(n):
                    page.paste(Image.open(os.path.join(src, a, f"{d}_{i:02d}.png")), ((di * n + i) * w, r * h))
            tile = page.crop((0, r * h, w * 3, r * h + 22))
            label(tile, f"{a} · {idx['index'][a]['length']:.2f} s")
            page.paste(tile, (0, r * h))
        name = f"{base}-{p}.png" if len(pages) > 1 else out
        page.save(name)
        print(name)


def video(src, out):
    idx = json.load(open(os.path.join(src, "index.json")))
    anims, dirs = idx["anims"], idx["dirs"]
    with tempfile.TemporaryDirectory() as tmp:
        k = 0
        for a in anims:
            n = idx["index"][a]["frames"]
            loops = 3 if a in ("idle", "walk", "carry") else 2
            for _ in range(loops):
                for i in range(n):
                    tiles = [Image.open(os.path.join(src, a, f"{d}_{i:02d}.png")) for d in dirs]
                    w, h = tiles[0].size
                    fr = Image.new("RGB", (w * len(tiles), h))
                    for j, t in enumerate(tiles):
                        fr.paste(t, (j * w, 0))
                    label(fr, a)
                    fr.save(os.path.join(tmp, f"{k:05d}.png"))
                    k += 1
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "30", "-i", os.path.join(tmp, "%05d.png"),
                        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", out], check=True)
    print(out)


def main():
    a = [x for x in sys.argv[1:] if not x.startswith("--")]
    rows = int(next((x.split("=")[1] for x in sys.argv if x.startswith("--rows=")), 5))
    if a[1].endswith(".mp4"):
        video(a[0], a[1])
    else:
        sheet(a[0], a[1], rows)


main()
