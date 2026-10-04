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
    # MAGT / mAGT both carry raw RGBA rows padded to pow2 (the lowercase-m
    # variant only differs in a flags dword — pixel layout is identical)
    assert data[:4] in (b"MAGT", b"mAGT"), "bad tgam magic"
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


# --------------------------------------------------- tint channels ----
# gw_2.tE — 10 runtime color channels; a ju_2 action's flags&0x3F selects
# the channel it (and its subtree) tints with.  Retail wiring (aez_0/ee_2):
#   ch1 skin  — coaches use apH[], fighters use tn_0[]
#   ch2 hair  — coaches use agl_0[], fighters use tn_0[]
#   ch8 pupil — fighters use tn_0[eye]
#   ch6/7/9 clothing — excluded from the channel swap when the action is
#   entered through a retargeted gesture-library anm (gw_2.a first branch).
# Palettes below are the decompiled enum tables; retail multiplies by 1.25
# when building the float[] (aaV).

SKIN_F = [(1.0, 0.83, 0.49), (1.0, 0.81, 0.55), (1.0, 0.89, 0.75),
          (0.1, 0.1, 0.2), (0.2, 0.1, 0.2), (0.3, 0.3, 0.1),
          (0.43, 0.36, 0.56), (0.5, 0.6, 0.5), (0.8, 0.9, 0.45),
          (0.74, 0.9, 1.0), (0.8, 0.8, 0.8)]                    # apH — coach skin
HAIR_F = [(0.7, 0.34, 0.0), (1.0, 0.47, 0.0), (1.0, 0.7, 0.4),
          (1.0, 0.73, 0.23), (1.0, 0.23, 0.35), (1.0, 0.2, 0.2),
          (0.35, 0.36, 0.0), (0.83, 0.87, 0.1), (0.5, 1.0, 0.5),
          (0.8, 0.8, 1.0), (0.47, 0.56, 1.0), (0.2, 0.2, 0.4),
          (0.29, 0.47, 0.41), (1.0, 1.0, 0.75)]                 # agl_0 — coach hair
NAT_F = [(0.21, 0.12, 0.03), (0.32, 0.8, 0.68), (1.0, 0.88, 0.3),
         (1.0, 0.47, 0.06), (0.83, 0.85, 0.14), (1.0, 0.9, 0.65),
         (0.74, 0.65, 0.51), (0.25, 0.23, 0.2), (1.0, 0.86, 0.78),
         (1.0, 0.8, 0.74), (1.0, 0.94, 0.73), (1.0, 0.87, 0.62),
         (1.0, 0.77, 0.55), (0.91, 0.66, 0.56), (0.91, 0.74, 0.07),
         (0.77, 0.62, 0.39), (0.69, 0.44, 0.28), (0.51, 0.3, 0.16),
         (0.34, 0.16, 0.04), (0.54, 0.52, 0.27), (0.49, 0.43, 0.26),
         (0.37, 0.31, 0.18), (0.27, 0.44, 0.56), (0.12, 0.16, 0.22),
         (0.0, 0.0, 0.0), (0.0, 0.59, 0.84), (0.5, 0.72, 0.78),
         (0.59, 0.84, 0.0), (0.92, 0.82, 0.07), (0.71, 0.51, 0.0),
         (0.39, 0.16, 0.0), (0.25, 0.14, 0.04), (0.69, 0.32, 1.0),
         (0.13, 0.79, 1.0), (0.0, 0.0, 0.0), (0.72, 0.07, 0.02),
         (1.0, 0.32, 0.58), (0.61, 0.94, 0.19), (0.74, 0.47, 0.1),
         (1.0, 1.0, 1.0), (1.0, 0.9, 0.48), (0.0, 0.05, 0.3),
         (1.0, 0.85, 0.88), (0.83, 1.0, 0.97), (0.81, 0.31, 1.0),
         (1.0, 0.75, 0.12), (1.0, 0.06, 0.0)]                  # tn_0 — fighter all


def _chan(sub, cur, retarget=False):
    """Channel index to propagate into a sub-action — ju_2.CZ&0x3F; 0 keeps
    the inherited channel.  Retargeted (cross-anm) entries skip the swap for
    costume channels 6/7/9 (gw_2.a first branch)."""
    ch = sub["flags"] & 0x3F
    if retarget and ch in (6, 7, 9):
        return cur
    return ch if ch else cur


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
        self.tints = {}              # ch -> (r,g,b,a) baked color (CLI opts)
        self.son_hits = {}           # Sons<sid> name -> earliest logical frame
        self.scr_hits = {}           # runScript id -> earliest logical frame

    def draw_action(self, action, n2, pq, depth=0, channel=0):
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
        # runScript frame parts (pb_1): the retail client runs
        # scripts/anm/<id>.lua when the frame is entered — record the script
        # id at this logical index, first appearance only (same rule as
        # Sons*: a held part must not retrigger every frame).
        for p in phys["parts"]:
            if p.get("type") == 3 and p.get("script"):
                self.scr_hits.setdefault(p["script"], idx)
        for t in phys["transforms"]:
            pq2 = apply_xf(t, pq)
            if pq2[11] <= 0.004:
                continue
            fl = t["fL"]
            lab = self.labels.get(fl)
            if lab is not None:
                sub = self.by_crc.get(lab["crc"])
                if sub is not None:
                    if str(sub.get("name") or "").startswith("Sons"):
                        self.son_hits.setdefault(sub["name"], idx)
                    else:
                        self.draw_action(sub, idx, pq2, depth + 1,
                                         _chan(sub, channel))
                continue
            sub = self.by_id.get(fl)
            if sub is not None:
                if str(sub.get("name") or "").startswith("Sons"):
                    self.son_hits.setdefault(sub["name"], idx)
                else:
                    self.draw_action(sub, idx, pq2, depth + 1,
                                     _chan(sub, channel))
                continue
            rg = self.regions.get(fl)
            if rg is not None:
                self.emit_quad(rg, pq2, channel)

    def emit_quad(self, rg, pq, ch=0):
        acx, acy, acz, acA, acB, acC, _, _, IQ, IR, IS, IT = pq
        # Decompiled gw_2 emits vertices with the Y components negated
        # (Gv*-acy, -acC …) because its GL viewport is Y-up and flips at
        # display time.  Our raster output is already a Y-down PNG — the
        # authored parts are positioned head-at-negative-y — so the
        # negation must NOT be replicated here or every figure exports
        # upside-down (verified against fighter -110 / Players 7000).
        x00 = rg["Gv"] * acx + rg["Gw"] * acz + acB
        y00 = rg["Gv"] * acy + rg["Gw"] * acA + acC
        ex = (acx * rg["adE"], acy * rg["adE"])
        ey = (acz * rg["adF"], acA * rg["adF"])
        ti = rg["dZA"] & 0xFFFF
        self.quads.append({
            "p": (x00, y00), "ex": ex, "ey": ey,
            "w": rg["adE"], "h": rg["adF"], "uv": rg["uv"],
            "tex": ti, "cm": (IQ, IR, IS, IT), "ch": ch,
        })

    def rasterize(self):
        quads = []
        for q in self.quads:
            qq = dict(q)
            qq["teximg"] = self.tex[q["tex"]] if q["tex"] < len(self.tex) \
                else None
            quads.append(qq)
        return rasterize_quads(quads, self.tints)


def rasterize_quads(quads, tints=None):
        """Rasterize quads; each must carry a resolved `teximg` (w,h,rgba).

        Returns (W, H, rgba, mask, offset): `mask` is a second RGBA canvas —
        same geometry/coverage — encoding which tint channel authored each
        pixel (R=ch1, G=ch2, B=ch≥3).  Runtime consumers multiply the base
        rgb by the channel's tE color (gw_2's divide/mul semantics — the
        channel color REPLACES, it does not stack).  `mask` is None when no
        quad carried a nonzero channel.  `tints` {ch: (r,g,b,a)} bakes the
        channel color straight into the color canvas (preview/export)."""
        if not quads:
            return None
        corners = []
        for q in quads:
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
        has_ch = any(q.get("ch", 0) > 0 for q in quads)
        mask = bytearray(W * H * 4) if has_ch else None

        for q in quads:
            tex = q.get("teximg")
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
                    tint = None
                    if tints:
                        tint = tints.get(q.get("ch", 0))
                    for c in range(3):
                        mul = cm[c] * (tint[c] if tint else 1.0)
                        src = int(px4[c] * mul) * a // 255
                        canvas[di + c] = max(0, min(255, src +
                                             canvas[di + c] * inv // 255))
                    canvas[di + 3] = max(0, min(255, a +
                                             canvas[di + 3] * inv // 255))
                    if mask is not None and q.get("ch", 0) > 0:
                        # R=ch1 skin, G=ch2 hair, B=ch8 pupil — costume
                        # channels 3-7/9 stay authored (no wire tint).
                        mc = ((255, 0, 0) if q["ch"] == 1 else
                              (0, 255, 0) if q["ch"] == 2 else
                              (0, 0, 255) if q["ch"] == 8 else (0, 0, 0))
                        for c in range(3):
                            mask[di + c] = max(0, min(255,
                                mc[c] * a // 255 +
                                mask[di + c] * inv // 255))
                        mask[di + 3] = max(0, min(255, a +
                                           mask[di + 3] * inv // 255))
        return W, H, bytes(canvas), bytes(mask) if mask is not None else None, (x0, y0)


# ------------------------------------------- cross-anm composition ----
class CompositeRenderer:
    """Draw an action whose transforms retarget parts living in OTHER anms.

    Retail's AnimSort_<breed>/AnimXxx.anm files are pure animation tracks:
    each transform's fL is a label id in the gesture anm whose crc resolves
    into the ACTOR's anm (Players/-<file>.anm) part actions. When the crc
    misses in the driving anm, every extra host is searched — that is how
    the gesture poses the body skeleton while its own fx sprites (regions
    inside the gesture anm) still emit from the right atlas.
    """

    def __init__(self, z, drive_entry, *host_entries):
        self.hosts = []
        for e in (drive_entry,) + host_entries:
            anm, tex = load_anm_and_textures(z, e)
            self.hosts.append(FrameRenderer(anm, tex))
        self.tints = {}              # shared — set on self, not the hosts
        self.son_hits = {}           # Sons<sid> -> earliest logical frame,
                                     # resolved across every host anm
        self.scr_hits = {}           # runScript id -> earliest logical frame

    def clear(self):
        for fr in self.hosts:
            fr.quads = []

    def draw_action(self, action, n2, pq, h=0, depth=0, channel=0):
        fr = self.hosts[h]
        if depth > 8 or action is None:
            return
        frames = action["frames"]
        if not frames:
            return
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
        # runScript frame parts (pb_1) on the visited action's own frames —
        # sub-actions reached via labels run their parts too when their
        # logical frame is entered.
        for p in phys["parts"]:
            if p.get("type") == 3 and p.get("script"):
                self.scr_hits.setdefault(p["script"], idx)
        for t in phys["transforms"]:
            pq2 = apply_xf(t, pq)
            if pq2[11] <= 0.004:
                continue
            fl = t["fL"]
            lab = fr.labels.get(fl)
            if lab is not None:
                for h2, fr2 in enumerate(self.hosts):
                    sub = fr2.by_crc.get(lab["crc"])
                    if sub is not None:
                        if str(sub.get("name") or "").startswith("Sons"):
                            self.son_hits.setdefault(sub["name"], idx)
                        else:
                            self.draw_action(
                                sub, idx, pq2, h2, depth + 1,
                                _chan(sub, channel, retarget=True))
                        break
                continue
            sub = fr.by_id.get(fl)
            if sub is not None:
                if str(sub.get("name") or "").startswith("Sons"):
                    self.son_hits.setdefault(sub["name"], idx)
                else:
                    self.draw_action(sub, idx, pq2, h, depth + 1,
                                     _chan(sub, channel))
                continue
            rg = fr.regions.get(fl)
            if rg is not None:
                fr.emit_quad(rg, pq2, channel)

    def rasterize(self):
        quads = []
        for fr in self.hosts:
            for q in fr.quads:
                qq = dict(q)
                qq["teximg"] = fr.tex[q["tex"]] if q["tex"] < len(fr.tex) \
                    else None
                quads.append(qq)
        return rasterize_quads(quads, self.tints)


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


def meta_sfx(son_hits, frames):
    """son_hits {Sons<sid>: firstFrame} -> meta map {frameIdx: [sid,...]}.

    Retail plays a Sons* part once when the parent action's frame stream
    first references it — first appearance only, or a held part would
    retrigger every frame.  son_hits keys are LOGICAL frame indexes; the
    meta frame list skips frames that rendered nothing, so each logical
    index is remapped onto its written position via the f<NNN>.png name
    (which carries the logical index)."""
    l2w = {}
    for k, fr in enumerate(frames):
        try:
            l2w[int(fr["png"][1:-4])] = k
        except (KeyError, ValueError):
            continue
    sfx = {}
    for nm, i in sorted(son_hits.items(), key=lambda kv: kv[1]):
        sid = nm[4:]
        if sid.isdigit() and i in l2w:
            sfx.setdefault(str(l2w[i]), []).append(int(sid))
    return sfx


def meta_scr(scr_hits, frames):
    """scr_hits {scriptId_str: firstFrame} -> meta map {frameIdx: [id,...]}.

    Same first-appearance/logical→written remap as meta_sfx: retail fires
    the frame's pb_1 hook once when the frame is entered; the hook runs
    scripts/anm/<id>.lua which is where playLocalSound/playBark live.
    """
    l2w = {}
    for k, fr in enumerate(frames):
        try:
            l2w[int(fr["png"][1:-4])] = k
        except (KeyError, ValueError):
            continue
    scr = {}
    for sid, i in sorted(scr_hits.items(), key=lambda kv: kv[1]):
        if sid.isdigit() and i in l2w:
            scr.setdefault(str(l2w[i]), []).append(int(sid))
    return scr


def _cli_tints():
    """Parse --skin N --hair N --eye N --tint ch=r,g,b[,a] from sys.argv.
    Builds the tE-style {channel: (r,g,b,a)} map — palettes ×1.25 like the
    retail aaV construction."""
    tints = {}
    av = sys.argv
    def _val(flag):
        return av[av.index(flag) + 1] if flag in av and \
            av.index(flag) + 1 < len(av) else None
    for flag, table, ch in (("--skin", SKIN_F, 1), ("--hair", HAIR_F, 2),
                            ("--eye", NAT_F, 8), ("--fskin", NAT_F, 1),
                            ("--fhair", NAT_F, 2)):
        v = _val(flag)
        if v is None:
            continue
        i = int(v) % len(table)
        r, g, b = table[i]
        tints[ch] = (r * 1.25, g * 1.25, b * 1.25, 1.0)
    for i, a in enumerate(av):
        if a == "--tint" and i + 1 < len(av):
            ch, rgb = av[i + 1].split("=", 1)
            parts = [float(x) for x in rgb.split(",")]
            parts += [1.0] * (4 - len(parts))
            tints[int(ch)] = tuple(parts[:4])
    return tints


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
    fr.tints = _cli_tints()
    meta = {"anm": entry, "action": name, "fps": anm["header"]["fps"],
            "frames": []}
    for i in range(action["logical_frames"]):
        fr.quads = []
        fr.draw_action(action, i, PQ_IDENTITY)
        out = fr.rasterize()
        if out is None:
            continue
        W, H, rgba, mpx, off = out
        fname = f"f{i:03d}.png"
        write_png(os.path.join(dst, fname), W, H, rgba)
        fr_meta = {"png": fname, "w": W, "h": H, "ox": off[0], "oy": off[1]}
        if mpx is not None:
            mname = f"f{i:03d}_m.png"
            write_png(os.path.join(dst, mname), W, H, mpx)
            fr_meta["mask"] = mname
            meta["mask"] = True
        meta["frames"].append(fr_meta)
    if fr.son_hits:
        meta["sfx"] = meta_sfx(fr.son_hits, meta["frames"])
    if fr.scr_hits:
        meta["scr"] = meta_scr(fr.scr_hits, meta["frames"])
    with open(os.path.join(dst, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return len(meta["frames"])


def export_action_composite(cr, anm, entry, action, out_dir):
    """Composite-export one gesture action against the actor skeleton."""
    import json
    name = action.get("name") or str(action["fL"])
    safe = name.replace("/", "_").replace(" ", "_")
    dst = os.path.join(out_dir, safe)
    os.makedirs(dst, exist_ok=True)
    meta = {"anm": entry, "action": name, "fps": anm["header"]["fps"],
            "frames": []}
    cr.son_hits = {}
    cr.scr_hits = {}
    for i in range(action["logical_frames"]):
        cr.clear()
        cr.draw_action(action, i, PQ_IDENTITY)
        out = cr.rasterize()
        if out is None:
            continue
        W, H, rgba, mpx, off = out
        fname = f"f{i:03d}.png"
        write_png(os.path.join(dst, fname), W, H, rgba)
        fr_meta = {"png": fname, "w": W, "h": H, "ox": off[0], "oy": off[1]}
        if mpx is not None:
            mname = f"f{i:03d}_m.png"
            write_png(os.path.join(dst, mname), W, H, mpx)
            fr_meta["mask"] = mname
            meta["mask"] = True
        meta["frames"].append(fr_meta)
    if cr.son_hits:
        meta["sfx"] = meta_sfx(cr.son_hits, meta["frames"])
    if cr.scr_hits:
        meta["scr"] = meta_scr(cr.scr_hits, meta["frames"])
    with open(os.path.join(dst, "meta.json"), "w") as f:
        json.dump(meta, f, indent=1)
    return len(meta["frames"])


def main():
    jar, entry = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3 and sys.argv[3] == "--composite":
        # anm_render.py jar <gesture.anm> --composite <actor.anm> --export
        # <out_dir> [action-substr] — bake skeletal gesture tracks (AnimSort/
        # AnimXxx.anm) over the actor anm's own part sprites.
        host = sys.argv[4]
        out_dir = sys.argv[6] if len(sys.argv) > 6 else "out"
        only = sys.argv[7] if len(sys.argv) > 7 else None
        z = zipfile.ZipFile(jar)
        cr = CompositeRenderer(z, entry, host)
        cr.tints = _cli_tints()
        drive_anm = cr.hosts[0].anm
        total = 0
        for a in drive_anm["actions"]:
            if not a.get("name"):
                continue
            if only and only not in a["name"]:
                continue
            n = export_action_composite(cr, drive_anm, entry, a, out_dir)
            total += n
            if n:
                print(f"[comp] {a['name']}: {n} frame(s)")
        print(f"[comp] done — {total} frame(s) -> {out_dir}")
        return 0
    if len(sys.argv) > 3 and sys.argv[3] == "--export":
        out_dir = sys.argv[4] if len(sys.argv) > 4 else "out"
        only = sys.argv[5] if len(sys.argv) > 5 else None
        z = zipfile.ZipFile(jar)
        anm, _ = load_anm_and_textures(z, entry)
        total = 0
        for a in anm["actions"]:
            if not a.get("name"):
                continue
            if only and only not in a["name"]:
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
    fr.tints = _cli_tints()
    fr.draw_action(act, fidx, PQ_IDENTITY)
    print(f"[quads] {len(fr.quads)}")
    out = fr.rasterize()
    if out is None:
        print("no drawable elements")
        return 1
    W, H, rgba, mpx, off = out
    name = entry.replace("/", "_").rsplit(".", 1)[0] + f"_f{fidx}.png"
    write_png("/tmp/" + name, W, H, rgba)
    if mpx is not None:
        write_png("/tmp/" + name[:-4] + "_m.png", W, H, mpx)
    print(f"[png] /tmp/{name} {W}x{H} offset={off}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
