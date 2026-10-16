#!/usr/bin/env python3
"""Convert the painted map art to 1 bit, one texture at a time (sprints/S04).

The 1-bit look works when every asset is already black-and-white at its own
pixel grid, and only the darkness/light layer is dithered on screen (the
Glagstone layering: WORLD, DARKNESS, LIGHTS). Converting per texture, instead
of filtering the finished frame, keeps each tile crisp and makes the pattern
travel with the sprite when the camera moves, instead of swimming under it.

Per texture:
  1. luminance (Rec. 709) of the RGB;
  2. local contrast: tone = mean + (lum - mean) * detail, where mean is an
     alpha-weighted Gaussian blur of radius --radius, so transparent pixels
     of the atlas do not drag the edges of a sprite toward black. The retail
     art keeps greens and browns in one mid-grey band; this is what brings
     back cracks, slab edges and symbols;
  3. levels (--black / --white) and --gamma;
  4. dither to ink/paper: Atkinson error diffusion (default; crisp, high
     contrast, no repeating pattern, so seams between tiles do not show) or
     an 8x8 Bayer matrix anchored at the texture origin;
  5. alpha thresholded at --alpha, so edges stay hard.

Usage:
  onebit.py <src mapgfx dir> <out dir> [--worlds=10,11] [--detail=4]
            [--radius=2] [--black=0] [--white=0.75] [--gamma=0.75]
            [--dither=atkinson|bayer] [--alpha=0.5]

<src>/<world>.json files are copied as is; <src>/tex/<gfx>.png are converted
into <out>/tex/. With --worlds, only the textures those worlds use. Exits 0 on
success, 1 if any texture failed, 2 on bad usage.
"""

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

BAYER8 = np.array(
    [
        [0, 32, 8, 40, 2, 34, 10, 42],
        [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44, 4, 36, 14, 46, 6, 38],
        [60, 28, 52, 20, 62, 30, 54, 22],
        [3, 35, 11, 43, 1, 33, 9, 41],
        [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47, 7, 39, 13, 45, 5, 37],
        [63, 31, 55, 23, 61, 29, 53, 21],
    ],
    dtype=np.float32,
)


def blur(a: np.ndarray, radius: float) -> np.ndarray:
    """Separable Gaussian (sigma = radius), zero outside the texture. numpy
    rather than PIL: Pillow 9 will not blur float ("F") images."""
    r = max(1, int(radius * 3))
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / radius) ** 2).astype(np.float32)
    k /= k.sum()
    def along(v: np.ndarray) -> np.ndarray:
        # pad + "valid" keeps the length even when the kernel outgrows the
        # texture ("same" would return the kernel's length instead)
        return np.convolve(np.pad(v, r), k, mode="valid")

    a = np.apply_along_axis(along, 0, a)
    return np.apply_along_axis(along, 1, a)


def tone_map(rgba: np.ndarray, o: dict) -> tuple[np.ndarray, np.ndarray]:
    rgb = rgba[..., :3].astype(np.float32) / 255.0
    alpha = rgba[..., 3].astype(np.float32) / 255.0
    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    if o["detail"] != 1.0 and o["radius"] > 0:
        w = blur(alpha, o["radius"])
        mean = blur(lum * alpha, o["radius"]) / np.maximum(w, 1e-4)
        lum = mean + (lum - mean) * o["detail"]
    span = max(o["white"] - o["black"], 1e-3)
    lum = np.clip((lum - o["black"]) / span, 0.0, 1.0) ** o["gamma"]
    return lum, alpha


def atkinson(t: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Atkinson diffusion: spreads 6/8 of the error, which keeps highlights
    and shadows clean. Only opaque pixels take part."""
    t = t.copy()
    h, w = t.shape
    out = np.zeros((h, w), dtype=bool)
    taps = ((0, 1), (0, 2), (1, -1), (1, 0), (1, 1), (2, 0))
    for y in range(h):
        row = t[y]
        for x in range(w):
            if not mask[y, x]:
                continue
            v = row[x]
            on = v >= 0.5
            out[y, x] = on
            err = (v - (1.0 if on else 0.0)) / 8.0
            for dy, dx in taps:
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx]:
                    t[yy, xx] += err
    return out


def bayer(t: np.ndarray) -> np.ndarray:
    h, w = t.shape
    thr = (np.tile(BAYER8, (h // 8 + 1, w // 8 + 1))[:h, :w] + 0.5) / 64.0
    return t > thr


def convert(src: Path, dst: Path, o: dict) -> None:
    rgba = np.asarray(Image.open(src).convert("RGBA"))
    tone, alpha = tone_map(rgba, o)
    mask = alpha >= o["alpha"]
    on = atkinson(tone, mask) if o["dither"] == "atkinson" else bayer(tone)
    out = np.zeros(rgba.shape, dtype=np.uint8)
    out[..., :3] = np.where(on[..., None], 255, 0).astype(np.uint8)
    out[..., 3] = np.where(mask, 255, 0).astype(np.uint8)
    Image.fromarray(out, mode="RGBA").save(dst)


def parse(argv: list[str]) -> dict | None:
    # Defaults from the first art pass on map 10 (sprints/S04): light ground
    # with a dot texture, cracks drawn, foliage like an engraving.
    o = {"detail": 4.0, "radius": 2.0, "black": 0.0, "white": 0.75, "gamma": 0.75,
         "dither": "atkinson", "alpha": 0.5, "worlds": None}
    pos = []
    for a in argv:
        if not a.startswith("--"):
            pos.append(a)
            continue
        k, _, v = a[2:].partition("=")
        if k == "worlds":
            o["worlds"] = [int(x) for x in v.split(",") if x]
        elif k == "dither":
            if v not in ("atkinson", "bayer"):
                print(f"--dither is atkinson or bayer, got {v!r}", file=sys.stderr)
                return None
            o["dither"] = v
        elif k in o:
            o[k] = float(v)
        else:
            print(f"unknown option --{k}", file=sys.stderr)
            return None
    if len(pos) != 2:
        print(__doc__, file=sys.stderr)
        return None
    o["src"], o["out"] = Path(pos[0]), Path(pos[1])
    return o


def main(argv: list[str]) -> int:
    o = parse(argv)
    if o is None:
        return 2
    src, out = o["src"], o["out"]
    (out / "tex").mkdir(parents=True, exist_ok=True)
    metas = sorted(src.glob("*.json"))
    if o["worlds"] is not None:
        metas = [m for m in metas if m.stem.isdigit() and int(m.stem) in o["worlds"]]
    texs: set[str] = set()
    for m in metas:
        shutil.copyfile(m, out / m.name)
        texs.update(json.loads(m.read_text()).get("tex", {}).keys())
    if o["worlds"] is None:
        texs = {p.stem for p in (src / "tex").glob("*.png")}
    failed = 0
    for i, t in enumerate(sorted(texs, key=lambda s: int(s) if s.isdigit() else s)):
        p = src / "tex" / f"{t}.png"
        if not p.exists():
            continue
        try:
            convert(p, out / "tex" / p.name, o)
        except Exception as e:  # keep going; report at the end
            failed += 1
            print(f"FAIL {p}: {e}", file=sys.stderr)
        if (i + 1) % 200 == 0:
            print(f"[onebit] {i + 1}/{len(texs)}")
    print(f"[onebit] {len(metas)} maps, {len(texs) - failed} textures -> {out}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
