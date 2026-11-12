#!/usr/bin/env python3
"""S35c: the emblems of the coach's 13 marks (tattoos, scars), own designs
(the retail card art only as an idea), drawn as 256 px PNGs with alpha.

    python3 tools/art/mark_emblems.py [<out_dir>]   (default art/equipment/out/marks)

coach_garment.py projects each one onto the coach's skin (garments.json,
kind "mark", "emblem": <name>). Run from godot/; build.py runs it before the
garments. Needs Pillow.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

N = 256
SS = 4   # drawn 4× and scaled down: smooth edges, then a hard alpha cut in the game


def canvas():
    im = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def P(x, y):
    """0–1 coordinates → pixels of the big canvas."""
    return (x * N * SS, y * N * SS)


def W(w):
    return int(w * N * SS)


def spiral(d, cx, cy, r, turns, col, w):
    pts = []
    for i in range(80):
        t = i / 79
        a = t * turns * 2 * math.pi
        rr = r * (0.15 + 0.85 * t)
        pts.append(P(cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.line(pts, fill=col, width=W(w), joint="curve")


def keltos(d):
    for cx, cy, r in ((0.32, 0.62, 0.2), (0.68, 0.6, 0.2), (0.5, 0.3, 0.2)):
        spiral(d, cx, cy, r, 1.6, (40, 90, 200, 255), 0.06)
    d.polygon([P(0.47, 0.5), P(0.53, 0.5), P(0.5, 0.42)], fill=(40, 90, 200, 255))


def jalatranki(d):
    # a ram's horn curling inside a ring (wool, the Jalatranki's)
    d.ellipse([P(0.1, 0.1), P(0.9, 0.9)], fill=(150, 30, 20, 255))
    d.ellipse([P(0.18, 0.18), P(0.82, 0.82)], fill=(240, 150, 30, 255))
    spiral(d, 0.52, 0.5, 0.26, 1.4, (150, 30, 20, 255), 0.07)


def skull(d):
    bone, dark = (200, 90, 40, 255), (60, 20, 10, 255)
    d.ellipse([P(0.18, 0.08), P(0.82, 0.7)], fill=bone)
    d.rounded_rectangle([P(0.32, 0.55), P(0.68, 0.9)], radius=W(0.06), fill=bone)
    d.ellipse([P(0.27, 0.32), P(0.46, 0.52)], fill=(250, 240, 220, 255))
    d.ellipse([P(0.54, 0.32), P(0.73, 0.52)], fill=(250, 240, 220, 255))
    d.polygon([P(0.5, 0.56), P(0.45, 0.66), P(0.55, 0.66)], fill=dark)
    for x in (0.4, 0.5, 0.6):
        d.line([P(x, 0.74), P(x, 0.88)], fill=dark, width=W(0.025))


def salteadorillo(d):
    d.ellipse([P(0.1, 0.12), P(0.9, 0.92)], fill=(110, 190, 180, 255))
    d.ellipse([P(0.2, 0.0), P(0.8, 0.6)], fill=(0, 0, 0, 0))
    for i, y in enumerate((0.66, 0.76)):
        d.arc([P(0.22 + i * 0.05, y - 0.1), P(0.5, y + 0.1)], 180, 360, fill=(220, 245, 240, 255), width=W(0.03))
        d.arc([P(0.5, y - 0.1), P(0.78 - i * 0.05, y + 0.1)], 180, 360, fill=(220, 245, 240, 255), width=W(0.03))


def scars(d):
    red = (170, 20, 20, 255)
    for x0, y0, x1, y1, w in ((0.25, 0.85, 0.8, 0.1, 0.07), (0.15, 0.7, 0.55, 0.25, 0.05), (0.45, 0.95, 0.85, 0.5, 0.04)):
        d.line([P(x0, y0), P(x1, y1)], fill=red, width=W(w))
        for k in (0.3, 0.55, 0.8):   # stitches across
            mx, my = x0 + (x1 - x0) * k, y0 + (y1 - y0) * k
            nx, ny = -(y1 - y0), x1 - x0
            ln = math.hypot(nx, ny)
            nx, ny = nx / ln * 0.05, ny / ln * 0.05
            d.line([P(mx - nx, my - ny), P(mx + nx, my + ny)], fill=(90, 10, 10, 255), width=W(0.015))


def kepika(d):
    spiral(d, 0.5, 0.5, 0.42, 1.25, (40, 200, 210, 255), 0.13)


def sedforme(d):
    o = (235, 130, 20, 255)
    d.polygon([P(0.5, 0.05), P(0.62, 0.45), P(0.5, 0.85), P(0.38, 0.45)], fill=o)
    d.polygon([P(0.15, 0.25), P(0.42, 0.5), P(0.4, 0.8), P(0.2, 0.6)], fill=o)
    d.polygon([P(0.85, 0.25), P(0.58, 0.5), P(0.6, 0.8), P(0.8, 0.6)], fill=o)
    d.rectangle([P(0.3, 0.7), P(0.7, 0.76)], fill=(170, 70, 10, 255))


def claws(d):
    for i in range(3):
        x = 0.25 + i * 0.2
        d.line([P(x, 0.9), P(x + 0.25, 0.1)], fill=(170, 40, 20, 255), width=W(0.09))
        d.line([P(x + 0.02, 0.85), P(x + 0.24, 0.16)], fill=(240, 200, 180, 255), width=W(0.025))


def mill(d):
    b = (40, 110, 170, 255)
    d.polygon([P(0.5, 0.95), P(0.15, 0.45), P(0.3, 0.15), P(0.5, 0.3), P(0.7, 0.15), P(0.85, 0.45)], fill=b)
    d.ellipse([P(0.42, 0.05), P(0.58, 0.22)], fill=b)


def paginas(d):
    r = (190, 25, 25, 255)
    d.ellipse([P(0.08, 0.08), P(0.92, 0.92)], outline=r, width=W(0.09))
    d.line([P(0.25, 0.32), P(0.37, 0.7), P(0.5, 0.42), P(0.63, 0.7), P(0.75, 0.32)], fill=r, width=W(0.08), joint="curve")


def wings(d):
    w, edge = (250, 245, 255, 255), (200, 180, 230, 255)
    for s in (-1, 1):
        cx = 0.5 + s * 0.22
        d.ellipse([P(cx - 0.22, 0.15), P(cx + 0.22, 0.6)], fill=w, outline=edge, width=W(0.02))
        d.ellipse([P(cx - 0.16, 0.5), P(cx + 0.16, 0.85)], fill=w, outline=edge, width=W(0.02))
        spiral(d, cx, 0.38, 0.1, 1.2, edge, 0.025)


def feather(d):
    t = (60, 180, 180, 255)
    d.polygon([P(0.3, 0.95), P(0.2, 0.55), P(0.45, 0.2), P(0.85, 0.05), P(0.7, 0.4), P(0.55, 0.75)], fill=t)
    d.line([P(0.3, 0.95), P(0.75, 0.15)], fill=(20, 110, 110, 255), width=W(0.025))


def lolomg(d):
    # three brush strokes in a fan, thick to thin, and a dot
    r = (200, 20, 20, 255)
    for i, (w, ang) in enumerate(((0.11, -60), (0.08, -90), (0.06, -120))):
        a = math.radians(ang)
        pts = [P(0.5 + 0.08 * math.cos(a) * k + 0.03 * math.sin(k * 3.0) * (i - 1), 0.82 + 0.08 * math.sin(a) * k)
               for k in range(9)]
        d.line(pts, fill=r, width=W(w), joint="curve")
    d.ellipse([P(0.44, 0.78), P(0.56, 0.9)], fill=r)


EMBLEMS = {
    "keltos": keltos, "jalatranki": jalatranki, "skull": skull, "salteadorillo": salteadorillo,
    "scars": scars, "kepika": kepika, "sedforme": sedforme, "claws": claws, "mill": mill,
    "paginas": paginas, "wings": wings, "feather": feather, "lolomg": lolomg,
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "art/equipment/out/marks"
    os.makedirs(out, exist_ok=True)
    for name, draw in EMBLEMS.items():
        im, d = canvas()
        draw(d)
        im.resize((N, N), Image.LANCZOS).save(os.path.join(out, name + ".png"))
    print(f"[marks] {len(EMBLEMS)} emblems -> {out}")


if __name__ == "__main__":
    main()
