#!/usr/bin/env python3
"""anm_flip.py — fix the Y-axis convention on already-exported anim sets.

The offline renderer used gw_2's vertex math verbatim (Y negated for the
engine's Y-up GL viewport), which produced every PNG upside-down — the
authored parts are head-at-negative-y and our output is already a Y-down
PNG, so the negation double-applies.  Verified anatomically: fighter
-110 and Players 7000 only stand upright once flipped.

Flipping the exported image is pixel-exact equivalent to fixing the
emitter: the whole frame (geometry + sampled texture) mirrors together.
This pass flips every f*.png (including f*_m.png masks) row-wise and
rewrites each meta.json's per-frame oy:

    old pixel row r sits at scene y = oy + r
    retail wants scene y' = -y  →  row r' = h-1-r at oy' = -(oy + h - 1)

Usage: anm_flip.py <anims_root> [<set_dir> ...]"""

import json
import os
import struct
import sys
import zlib

PNG_SIG = b"\x89PNG\r\n\x1a\n"


def read_png(path):
    d = open(path, "rb").read()
    assert d[:8] == PNG_SIG, path
    pos = 8
    w = h = 0
    idat = b""
    while pos < len(d):
        n, typ = struct.unpack(">I4s", d[pos:pos + 8])
        pos += 8
        if typ == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", d[pos:pos + 10])
            assert bd == 8 and ct == 6, (path, bd, ct)
        elif typ == b"IDAT":
            idat += d[pos:pos + n]
        elif typ == b"IEND":
            break
        pos += n + 4
    raw = zlib.decompress(idat)
    stride = w * 4 + 1
    rows = []
    prev = bytearray(w * 4)
    for y in range(h):
        f = raw[y * stride]
        line = bytearray(raw[y * stride + 1:(y + 1) * stride])
        if f:
            for i in range(len(line)):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                if f == 1:
                    line[i] = (line[i] + a) & 255
                elif f == 2:
                    line[i] = (line[i] + b) & 255
                elif f == 3:
                    line[i] = (line[i] + (a + b) // 2) & 255
                elif f == 4:
                    p = a + b - c
                    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                    line[i] = (line[i] +
                               (a if pa <= pb and pa <= pc
                                else b if pb <= pc else c)) & 255
        rows.append(bytes(line))
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d))
    raw = b"".join(b"\x00" + r for r in rows)
    out = (PNG_SIG
           + chunk(b"IHDR", struct.pack(">IIBB", w, h, 8, 6) + b"\x00\x00\x00")
           + chunk(b"IDAT", zlib.compress(raw, 6))
           + chunk(b"IEND", b""))
    open(path, "wb").write(out)


def flip_set(set_dir):
    flipped = metas = 0
    for act in os.listdir(set_dir):
        ad = os.path.join(set_dir, act)
        mp = os.path.join(ad, "meta.json")
        if not os.path.isfile(mp):
            continue
        meta = json.load(open(mp))
        if meta.get("flipy"):
            continue                       # already corrected
        for fr in meta.get("frames", []):
            png = os.path.join(ad, fr["png"])
            if not os.path.isfile(png):
                continue
            w, h, rows = read_png(png)
            write_png(png, w, h, list(reversed(rows)))
            fr["oy"] = -(fr["oy"] + h - 1)
            flipped += 1
            if fr.get("mask"):
                mk = os.path.join(ad, fr["mask"])
                if os.path.isfile(mk):
                    mw, mh, mrows = read_png(mk)
                    write_png(mk, mw, mh, list(reversed(mrows)))
        meta["flipy"] = True               # idempotent marker
        with open(mp, "w") as f:
            json.dump(meta, f, indent=1)
        metas += 1
    return flipped, metas


def main():
    root = sys.argv[1]
    only = set(sys.argv[2:]) if len(sys.argv) > 2 else None
    total_f = total_m = 0
    for s in sorted(os.listdir(root)):
        if only and s not in only:
            continue
        sd = os.path.join(root, s)
        if not os.path.isdir(sd):
            continue
        f, m = flip_set(sd)
        if m:
            print(f"{s}: {f} frame(s) flipped, {m} meta(s)")
        total_f += f
        total_m += m
    print(f"[flip] done — {total_f} frames, {total_m} metas")
    return 0


if __name__ == "__main__":
    sys.exit(main())
