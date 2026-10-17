#!/usr/bin/env python3
"""1-bit backdrops of our own for the S18 screens (login, creation, lobby).

    python3 tools/make_onebit_bg.py [OUT_DIR] [--only=tablero,rayos,cartas]

Run from godot/. Writes OUT_DIR/onebit_bg_<name>.png (default assets/ui), at
1280x720, pure black and white. Own art, not derived from the retail client,
so it can be committed (the retail-art arena backdrop cannot). Every
pattern stays quiet in the middle, where the windows sit, and does its
decorating towards the edges. Ordered 4x4 Bayer, like the S04 maps.
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 1280, 720
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9],
                   [15, 7, 13, 5]]) + 0.5) / 16.0


def dither(level: np.ndarray, cell: int = 2) -> np.ndarray:
    """level in 0..1 per pixel -> bool white mask, Bayer cells of `cell` px."""
    yy, xx = np.mgrid[0:H, 0:W]
    t = BAYER[(yy // cell) % 4, (xx // cell) % 4]
    return level > t


def calm_centre(power: float = 1.0) -> np.ndarray:
    """0 in the middle of the screen, rising to 1 at the edges."""
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    return np.clip((d - 0.35) / 0.75, 0, 1) ** power


def to_img(mask: np.ndarray) -> Image.Image:
    return Image.fromarray((mask * 255).astype(np.uint8)).convert("RGB")


# --- tablero: the arena floor as an isometric grid --------------------------
def tablero() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    cw, ch = 172.0, 86.0          # two fight cells' 2:1 diamond
    u = (xx / cw + yy / ch)
    v = (xx / cw - yy / ch)
    fu, fv = u - np.floor(u), v - np.floor(v)
    line = (np.minimum(fu, 1 - fu) < 0.012) | (np.minimum(fv, 1 - fv) < 0.012)
    edge = calm_centre(0.8)
    # lines fade in with the edges; a dotted fade rather than grey
    lines = line & dither(0.9 * edge ** 1.5, cell=1)
    # some cells lit like spawn cells: a sparse, seeded choice
    rng = np.random.default_rng(10)
    cu, cv = np.floor(u).astype(int), np.floor(v).astype(int)
    key = (cu * 7919 + cv * 104729) % 1000
    lit = (rng.permutation(1000)[key] < 70) & (edge > 0.45)
    fill = lit & dither(np.full((H, W), 0.16))
    return to_img(lines | fill)


# --- rayos: halftone sunburst behind the title --------------------------------
def rayos() -> Image.Image:
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    cx, cy = W / 2, 140.0
    ang = np.arctan2(yy - cy, xx - cx)
    r = np.hypot(xx - cx, yy - cy)
    wedge = (np.floor((ang + math.pi) / (2 * math.pi / 36)) % 2) == 0
    # faint by the title, strongest mid-way, fading again at the far edges
    ramp = np.clip((r - 170) / 260, 0, 1) * np.clip(1.3 - r / 1100, 0, 1)
    level = np.where(wedge, 0.22 * ramp, 0.0) * calm_centre(0.7)
    # halftone: round dots on a 10 px grid, sized by the level
    g = 7.0
    dx = (xx % g) - g / 2
    dy = (yy % g) - g / 2
    dots = np.hypot(dx, dy) < (g / 2) * np.sqrt(level) * 1.25
    return to_img(dots)


# --- cartas: a scatter of card outlines ---------------------------------------
def cartas() -> Image.Image:
    S = 2
    im = Image.new("L", (W * S, H * S), 0)
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(4)
    placed = []
    tries = 0
    while len(placed) < 26 and tries < 4000:
        tries += 1
        x, y = rng.uniform(-40, W + 40), rng.uniform(-60, H + 60)
        # keep the middle (the windows) free
        if abs(x - W / 2) < 380 and abs(y - H / 2) < 250:
            continue
        if any(math.hypot(x - px, y - py) < 150 for px, py in placed):
            continue
        placed.append((x, y))
        a = math.radians(rng.uniform(-32, 32))
        cw, chh = 92, 128

        def pts(w, h):
            out = []
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                px, py = sx * w / 2, sy * h / 2
                out.append(((x + px * math.cos(a) - py * math.sin(a)) * S,
                            (y + px * math.sin(a) + py * math.cos(a)) * S))
            return out
        d.polygon(pts(cw, chh), fill=0, outline=255, width=3 * S)
        d.polygon(pts(cw - 16, chh - 16), outline=255, width=1 * S)
        kind = len(placed) % 3
        r = 14 * S
        cx, cy = x * S, y * S
        if kind == 0:      # spiral-ish rings
            for k in (1.0, 0.6):
                d.ellipse([cx - r * k, cy - r * k, cx + r * k, cy + r * k], outline=255, width=2 * S)
        elif kind == 1:    # diamond
            d.polygon([(cx, cy - r * 1.3), (cx + r, cy), (cx, cy + r * 1.3), (cx - r, cy)],
                      outline=255, width=2 * S)
        else:              # star
            p = []
            for i in range(10):
                rr = r * (1.3 if i % 2 == 0 else 0.55)
                t = a + i * math.pi / 5 - math.pi / 2
                p.append((cx + rr * math.cos(t), cy + rr * math.sin(t)))
            d.polygon(p, outline=255, width=2 * S)
    im = im.resize((W, H), Image.LANCZOS)
    m = np.asarray(im) > 110
    # a sparse dot field fills the black around the cards, denser at edges
    m |= dither(0.035 * calm_centre(1.5), cell=2)
    return to_img(m)


PATTERNS = {"tablero": tablero, "rayos": rayos, "cartas": cartas}


def main(argv):
    out = "assets/ui"
    only = list(PATTERNS)
    for a in argv:
        if a.startswith("--only="):
            only = a.split("=", 1)[1].split(",")
        else:
            out = a
    os.makedirs(out, exist_ok=True)
    for name in only:
        p = os.path.join(out, "onebit_bg_%s.png" % name)
        PATTERNS[name]().convert("1").save(p, optimize=True)
        print("wrote", p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
