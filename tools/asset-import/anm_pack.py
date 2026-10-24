#!/usr/bin/env python3
"""anm_pack.py — pack exported animation frames into one atlas per action.

`anm_render.py --export` writes one PNG per frame (and one f*_m.png channel
mask per frame when the action has tint channels): ~318 000 files, 1.7 GB,
slow to copy and to install (S15). This rewrites each action folder in place
into `atlas.png` (+ `atlas_m.png`), and each frame in meta.json gets an `r`
rect [x, y, w, h] into it instead of its `png`/`mask` file. AnmSprite
(godot/src/anims/anm_sprite.gd) reads both layouts, so packing is optional
and can run on any already-exported tree.

Usage:
  anm_pack.py <anims_root> [set_dir …] [--check]

  --check   after packing each action, cut every frame back out of the atlas
            and compare it byte for byte with the original before deleting
            the loose files (slow; for verification runs).

Stdlib only, like the rest of asset-import: a minimal PNG reader for the
8-bit RGBA PNGs our own exporter writes (all five filter types handled), and
the exporter's writer.
"""

import json
import os
import struct
import sys
import zlib

ATLAS_W = 2048   # widest atlas row; a wider frame widens the atlas


def read_png(path):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"not a PNG: {path}"
    pos, w, h, idat = 8, 0, 0, []
    while pos < len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if tag == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and ctype == 6 and inter == 0, f"unsupported PNG layout: {path}"
        elif tag == b"IDAT":
            idat.append(body)
        pos += 12 + ln
    raw = zlib.decompress(b"".join(idat))
    stride = w * 4
    out = bytearray(stride * h)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return w, h, bytes(out)


def write_png(path, w, h, rgba):
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)


def shelf_pack(sizes):
    """[(w, h)] → (atlas_w, atlas_h, [(x, y)]): rows filled tallest first."""
    width = max([ATLAS_W] + [w for w, _ in sizes])
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][1])
    pos = [None] * len(sizes)
    x = y = row_h = 0
    for i in order:
        w, h = sizes[i]
        if x + w > width:
            x, y, row_h = 0, y + row_h, 0
        pos[i] = (x, y)
        x += w
        row_h = max(row_h, h)
    return width, y + row_h, pos


def blit(dst, dw, src, sw, sh, ox, oy):
    for row in range(sh):
        d = ((oy + row) * dw + ox) * 4
        dst[d:d + sw * 4] = src[row * sw * 4:(row + 1) * sw * 4]


def cut(src, sw, x, y, w, h):
    return b"".join(src[((y + r) * sw + x) * 4:((y + r) * sw + x + w) * 4] for r in range(h))


def pack_action(adir, check=False):
    meta_path = os.path.join(adir, "meta.json")
    meta = json.load(open(meta_path))
    frames = meta.get("frames", [])
    if meta.get("atlas") or not frames:
        return 0
    imgs, masks = [], []
    for fr in frames:
        w, h, px = read_png(os.path.join(adir, fr["png"]))
        assert (w, h) == (fr["w"], fr["h"]), f"{adir}/{fr['png']}: meta says {fr['w']}x{fr['h']}"
        imgs.append(px)
        masks.append(read_png(os.path.join(adir, fr["mask"]))[2] if fr.get("mask") else None)
    aw, ah, pos = shelf_pack([(fr["w"], fr["h"]) for fr in frames])
    atlas = bytearray(aw * ah * 4)
    matlas = bytearray(aw * ah * 4) if any(m is not None for m in masks) else None
    for i, fr in enumerate(frames):
        x, y = pos[i]
        blit(atlas, aw, imgs[i], fr["w"], fr["h"], x, y)
        if matlas is not None and masks[i] is not None:
            blit(matlas, aw, masks[i], fr["w"], fr["h"], x, y)
    write_png(os.path.join(adir, "atlas.png"), aw, ah, bytes(atlas))
    if matlas is not None:
        write_png(os.path.join(adir, "atlas_m.png"), aw, ah, bytes(matlas))
    if check:
        _, _, back = read_png(os.path.join(adir, "atlas.png"))
        for i, fr in enumerate(frames):
            x, y = pos[i]
            assert cut(back, aw, x, y, fr["w"], fr["h"]) == imgs[i], f"{adir}: frame {i} differs after packing"
    old = []
    for i, fr in enumerate(frames):
        old.append(fr.pop("png"))
        if fr.get("mask"):
            old.append(fr.pop("mask"))
            fr["masked"] = True
        fr["r"] = [pos[i][0], pos[i][1], fr["w"], fr["h"]]
    meta["atlas"] = "atlas.png"
    if matlas is not None:
        meta["mask_atlas"] = "atlas_m.png"
    tmp = meta_path + ".tmp"
    json.dump(meta, open(tmp, "w"), indent=1)
    os.replace(tmp, meta_path)   # the meta flips to the atlas only once it is written
    for f in old:
        try:
            os.remove(os.path.join(adir, f))
        except FileNotFoundError:
            pass
    return len(frames)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    check = "--check" in sys.argv
    if not args:
        sys.exit(__doc__)
    root, sets = args[0], args[1:]
    sets = sets or sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
    total = 0
    for s in sets:
        sdir = os.path.join(root, s)
        n = 0
        for a in sorted(os.listdir(sdir)):
            adir = os.path.join(sdir, a)
            if os.path.isfile(os.path.join(adir, "meta.json")):
                n += pack_action(adir, check)
        total += n
        print(f"[pack] {s}: {n} frames", flush=True)
    print(f"[pack] done — {total} frames packed")


if __name__ == "__main__":
    main()
