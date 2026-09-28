#!/usr/bin/env python3
"""Render one .anm frame to PNG — first-sprite spike for the Godot client.

Reproduces the client's own render math (decompiled gw_2/pq_0):
  - actions (ju_2) contain frames (xc_2) of element transforms (abd_0)
  - each transform's fL resolves via three tables, in order:
      qE (hn_2 labels → action in ROOT anm by CRC), qB (actions by id),
      qz (ana_1 regions — drawable leaf)
  - transforms accumulate into pq_0: matrix multiply (self*parent),
    translation through parent matrix + parent T, color mul/add chains
  - region quad: corner = (Gv,Gw)·M + T, edges adE/adF along M columns,
    UV pairs in file order [u0,v0,u1,v1] = bsA,bsB,bsD,bsC

usage:
  anm_render.py <animations.jar> <anm-entry> [action-substr] [frame]
  anm_render.py <animations.jar> <anm-entry> --export <out_dir>
"""

import os
import struct
import sys
import zlib
import zipfile

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from anm_dump import Reader, parse_anm  # noqa: E402


# ---------------------------------------------------------------- tgam ----
def next_pow2(n):
    p = 1
    while p < n:
        p <<= 1
    return p


def load_tgam(data: bytes):
    assert data[:4] == b"MAGT", "bad tgam magic"
    w, h = struct.unpack_from("<HH", data, 4)
    pixel_len = struct.unpack_from("<i", data, 8)[0]
    pw = next_pow2(w)
    px = data[16:16 + pixel_len]
    out = bytearray(w * h * 4)
    for y in range(h):
        src = y * pw * 4
        out[y * w * 4:(y + 1) * w * 4] = px[src:src + w * 4]
    return w, h, bytes(out)


# ------------------------------------------------------------ PNG write ----
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


# ------------------------------------------------------------- pq_0 ----
def _s(v):
    """signed byte/fixed helpers"""
    return v - 256 if v > 127 else v


def apply_xf(t, pq):
    """abd_0.a(parent, out) — exact decompiled math per transform type."""
    acx, acy, acz, acA, acB, acC, acD, acE, IQ, IR, IS, IT = pq
    d = t.get("data") or {}
    typ = t["type"]
    o_acx, o_acy, o_acz, o_acA = acx, acy, acz, acA
    o_acB, o_acC = acB, acC
    o_IQ, o_IR, o_IS, o_IT = IQ, IR, IS, IT

    # --- matrix component (types with s4 or compact b4 matrix) ---
    m = None
    if "s4" in d:
        m = [v / 256.0 for v in d["s4"]]
    elif typ in (49, 179) and "b4" in d:
        m = [_s(v) / 127.0 for v in d["b4"]]
    if m is not None:
        if acD:
            o_acx, o_acy, o_acz, o_acA = m
        else:
            o_acx = m[0] * acx + m[1] * acz
            o_acy = m[0] * acy + m[1] * acA
            o_acz = m[2] * acx + m[3] * acz
            o_acA = m[2] * acy + m[3] * acA
        acD = False

    # --- translation component ---
    tr = None
    if "f2" in d:
        tr = list(d["f2"])
    elif typ == 82 and "cJVW" in d:
        tr = [v / 256.0 for v in d["cJVW"]]
    elif typ == 179 and "xPQ" in d:
        tr = [_s(v) * 16.0 / 127.0 for v in d["xPQ"]]
    if tr is not None:
        if acD:
            o_acB = tr[0] + acB
            o_acC = tr[1] + acC
        else:
            o_acB = tr[0] * acx + tr[1] * acz + acB
            o_acC = tr[0] * acy + tr[1] * acA + acC
        acE = False

    # --- color add ---
    if "e4" in d:
        o_IQ += d["e4"][0] / 256.0
        o_IR += d["e4"][1] / 256.0
        o_IS += d["e4"][2] / 256.0
        o_IT += d["e4"][3] / 256.0

    # --- color mul (b4 is color for all types except 49/179 where it's matrix) ---
    if "b4" in d and typ not in (49, 179):
        o_IQ *= _s(d["b4"][0]) / 127.0
        o_IR *= _s(d["b4"][1]) / 127.0
        o_IS *= _s(d["b4"][2]) / 127.0
        o_IT *= _s(d["b4"][3]) / 127.0

    return (o_acx, o_acy, o_acz, o_acA, o_acB, o_acC, acD, acE,
            o_IQ, o_IR, o_IS, o_IT)


PQ_IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0, True, True, 1.0, 1.0, 1.0, 1.0)


# ------------------------------------------------------- scene graph ----
class FrameRenderer:
    def __init__(self, anm, textures):
        self.anm = anm
        self.tex = textures          # list of (w, h, rgba)
        self.regions = {r["id"]: r for r in anm["regions"]}
        self.labels = {l["id"]: l for l in anm.get("labels", [])}
        self.by_id = {a["fL"]: a for a in anm["actions"]}
        self.by_crc = {a["crc"]: a for a in anm["actions"]}
        self.quads = []

    def draw_action(self, action, n2, pq, depth=0):
        if depth > 8 or action is None:
            return
        frames = action["frames"]
        if not frames:
            return
        # logical→physical index: find physical frame covering n2
        idx = n2
        if idx >= action["logical_frames"]:
            idx = (idx % action["logical_frames"] if action["flags"] & 0x80
                   else action["logical_frames"] - 1)
        phys = None
        acc = 0
        for f in frames:
            if acc <= idx < acc + 1 + f["repeat"]:
                phys = f
                break
            acc += 1 + f["repeat"]
        if phys is None:
            return
        for t in phys["transforms"]:
            pq2 = apply_xf(t, pq)
            if pq2[11] <= 0.004:
                continue
            fl = t["fL"]
            lab = self.labels.get(fl)
            if lab is not None:
                sub = self.by_crc.get(lab["crc"])
                if sub is not None:
                    self.draw_action(sub, idx, pq2, depth + 1)
                continue
            sub = self.by_id.get(fl)
            if sub is not None:
                self.draw_action(sub, idx, pq2, depth + 1)
                continue
            rg = self.regions.get(fl)
            if rg is not None:
                self.emit_quad(rg, pq2)

    def emit_quad(self, rg, pq):
        acx, acy, acz, acA, acB, acC, _, _, IQ, IR, IS, IT = pq
        x00 = rg["Gv"] * acx + rg["Gw"] * acz + acB
        y00 = rg["Gv"] * -acy + rg["Gw"] * -acA - acC
        ex = (acx * rg["adE"], -acy * rg["adE"])
        ey = (acz * rg["adF"], -acA * rg["adF"])
        ti = rg["dZA"] & 0xFFFF
        self.quads.append({
            "p": (x00, y00), "ex": ex, "ey": ey,
            "w": rg["adE"], "h": rg["adF"], "uv": rg["uv"],
            "tex": ti, "cm": (IQ, IR, IS, IT),
        })

    def rasterize(self):
        if not self.quads:
            return None
        corners = []
        for q in self.quads:
            x, y = q["p"]
            corners += [(x, y),
                        (x + q["ex"][0], y + q["ex"][1]),
                        (x + q["ey"][0], y + q["ey"][1]),
                        (x + q["ex"][0] + q["ey"][0],
                         y + q["ex"][1] + q["ey"][1])]
        x0 = int(min(c[0] for c in corners)) - 4
        y0 = int(min(c[1] for c in corners)) - 4
        x1 = int(max(c[0] for c in corners)) + 5
        y1 = int(max(c[1] for c in corners)) + 5
        W, H = max(1, x1 - x0), max(1, y1 - y0)
        canvas = bytearray(W * H * 4)

        for q in self.quads:
            tex = self.tex[q["tex"]] if q["tex"] < len(self.tex) else None
            if tex is None:
                continue
            tw, th, tpx = tex
            px_, py_ = q["p"]
            ex, ey = q["ex"], q["ey"]
            w, hh = q["w"], q["h"]
            # uv tuple = (bsA,bsB,bsD,bsC); per gw_2 td order the u axis is B->C, v axis is D->A
            bsA, bsB, bsD, bsC = q["uv"]
            cm = q["cm"]
            # dst→local: solve p = P + s*ex + t*ey  (s,t in 0..w,h)
            det = ex[0] * ey[1] - ey[0] * ex[1]
            if abs(det) < 1e-9:
                continue
            bx0 = max(0, int(min(px_, px_ + ex[0], px_ + ey[0],
                                 px_ + ex[0] + ey[0]) - x0))
            bx1 = min(W, int(max(px_, px_ + ex[0], px_ + ey[0],
                                 px_ + ex[0] + ey[0]) - x0) + 2)
            by0 = max(0, int(min(py_, py_ + ex[1], py_ + ey[1],
                                 py_ + ex[1] + ey[1]) - y0))
            by1 = min(H, int(max(py_, py_ + ex[1], py_ + ey[1],
                                 py_ + ex[1] + ey[1]) - y0) + 2)
            for dy in range(by0, by1):
                for dx in range(bx0, bx1):
                    lx = dx + x0 - px_
                    ly = dy + y0 - py_
                    s = (lx * ey[1] - ly * ey[0]) / det
                    tt = (ex[0] * ly - ex[1] * lx) / det
                    if not (0.0 <= s <= 1.0 and 0.0 <= tt <= 1.0):
                        continue
                    fu = bsB + s * (bsC - bsB)
                    fv = bsD + tt * (bsA - bsD)
                    # bilinear sample over the padded tgam atlas
                    gx = min(tw - 1.001, max(0.0, fu * tw - 0.5))
                    gy = min(th - 1.001, max(0.0, fv * th - 0.5))
                    x_i, y_i = int(gx), int(gy)
                    fx, fy = gx - x_i, gy - y_i
                    px4 = [0.0, 0.0, 0.0, 0.0]
                    for oy in (0, 1):
                        for ox in (0, 1):
                            si = ((y_i + oy) * tw + x_i + ox) * 4
                            wgt = ((1 - fx) if ox == 0 else fx) * \
                                  ((1 - fy) if oy == 0 else fy)
                            for c in range(4):
                                px4[c] += tpx[si + c] * wgt
                    a = min(255, int(px4[3] * cm[3]))
                    if a == 0:
                        continue
                    di = (dy * W + dx) * 4
                    inv = 255 - a
                    for c in range(3):
                        src = int(px4[c] * cm[c]) * a // 255
                        canvas[di + c] = min(255, src +
                                             canvas[di + c] * inv // 255)
                    canvas[di + 3] = min(255, a + canvas[di + 3] * inv // 255)
        return W, H, bytes(canvas), (x0, y0)


def load_anm_and_textures(z, entry):
    """Parse one .anm from the jar and load its referenced .tgam atlases."""
    anm = parse_anm(z.read(entry))
    sub = entry.rsplit("/", 1)[0]
    atlas_dir = "Atlas" if anm["header"]["flags"] & 1 else "Textures"
    textures = []
    for t in anm["textures"]:
        tex_entry = f"{sub}/{atlas_dir}/{t['name']}.tgam"
        try:
            textures.append(load_tgam(z.read(tex_entry)))
        except KeyError:
            textures.append((1, 1, b"\x00" * 4))
    return anm, textures


def export_action(z, entry, action, out_dir):
    """Render every logical frame of one action to PNG + write meta.json.

    Output layout (mirrors Godot AnimatedSprite/SpriteFrames import):
      <out_dir>/<action_name>/f<NNN>.png
      <out_dir>/<action_name>/meta.json   -- fps + per-frame size/origin
    The per-frame offset (ox, oy) preserves the pivot so frames of differing
    bounds stay registered when drawn at the same anchor point.
    """
    import json
    anm, textures = load_anm_and_textures(z, entry)
    name = action.get("name") or str(action["fL"])
    safe = name.replace("/", "_").replace(" ", "_")
    dst = os.path.join(out_dir, safe)
    os.makedirs(dst, exist_ok=True)
    fr = FrameRenderer(anm, textures)
    meta = {"anm": entry, "action": name, "fps": anm["header"]["fps"],
            "frames": []}
    for i in range(action["logical_frames"]):
        fr.quads = []
        fr.draw_action(action, i, PQ_IDENTITY)
        out = fr.rasterize()
        if out is None:
            continue
        W, H, rgba, off = out
        fname = f"f{i:03d}.png"
        write_png(os.path.join(dst, fname), W, H, rgba)
        meta["frames"].append({"png": fname, "w": W, "h": H,
                               "ox": off[0], "oy": off[1]})
    with open(os.path.join(dst, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return len(meta["frames"])


def main():
    jar, entry = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3 and sys.argv[3] == "--export":
        out_dir = sys.argv[4] if len(sys.argv) > 4 else "out"
        z = zipfile.ZipFile(jar)
        anm, _ = load_anm_and_textures(z, entry)
        total = 0
        for a in anm["actions"]:
            if not a.get("name"):
                continue
            n = export_action(z, entry, a, out_dir)
            total += n
            print(f"[export] {a['name']}: {n} frame(s)")
        print(f"[export] done — {total} frame(s) -> {out_dir}")
        return 0
    want = sys.argv[3] if len(sys.argv) > 3 else ""
    fidx = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    z = zipfile.ZipFile(jar)
    anm, textures = load_anm_and_textures(z, entry)
    act = None
    for a in anm["actions"]:
        if want and want in a.get("name", ""):
            act = a
            break
    if act is None:
        act = max(anm["actions"], key=lambda a: a["logical_frames"])
    print(f"[act] {act['fL']} '{act.get('name','')}' frame {fidx}")
    fr = FrameRenderer(anm, textures)
    fr.draw_action(act, fidx, PQ_IDENTITY)
    print(f"[quads] {len(fr.quads)}")
    out = fr.rasterize()
    if out is None:
        print("no drawable elements")
        return 1
    W, H, rgba, off = out
    name = entry.replace("/", "_").rsplit(".", 1)[0] + f"_f{fidx}.png"
    write_png("/tmp/" + name, W, H, rgba)
    print(f"[png] /tmp/{name} {W}x{H} offset={off}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
