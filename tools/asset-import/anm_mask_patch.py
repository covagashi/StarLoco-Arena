#!/usr/bin/env python3
"""anm_mask_patch.py — write fNNN_m.png channel-coverage masks into already-
exported anim set dirs WITHOUT re-rasterizing color frames.

Replays each action's draw_action walk (channels tagged by ju_2.CZ&0x3F),
fills each quad's parallelogram coverage into a mask canvas (R=ch1 skin,
G=ch2 hair, B=ch8 pupil — costume channels stay authored), writes masks
matching the existing color frames' bounds, and flags meta["mask"]=true.

Coverage-only masks are exact where it matters: the runtime multiplies
rgb by the channel tint, and transparent base pixels stay invisible under
any tint — overshoot beyond the authored edge is harmless.

Usage: anm_mask_patch.py <animations.jar> <anims_root> [<set_dir> ...]
"""

import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anm_dump import parse_anm
from anm_render import CompositeRenderer, FrameRenderer, PQ_IDENTITY, \
    write_png

PLAYERS = "animations/Players/"
NPCS = "animations/NPCs/"


def set_entries(set_name):
    """Exported set dir -> (drive_anm, host_anm|None) composite spec.

    fighter_<-file>: direct body actions live under drive -<file>; every
    gesture bank (Anim*/AnimSort_*) composites over that body — the meta's
    own `anm` field tells which bank authored each action.
    """
    if set_name.startswith("fighter_"):
        return f"{PLAYERS}{set_name[8:]}.anm"
    if set_name.startswith("coach_700"):
        return f"{PLAYERS}{set_name[6:]}.anm"
    if set_name.startswith("npc_"):
        return f"{NPCS}{set_name[4:]}.anm"
    return None


class _MaskWalk(CompositeRenderer):
    """CompositeRenderer without texture decode — the mask pass only needs
    anm structures (labels/crcs/regions), never samples a tgam."""

    def __init__(self, z, *entries):
        self.hosts = [FrameRenderer(parse_anm(z.read(e)), [])
                      for e in entries]
        self.tints = {}
        self.son_hits = {}
        self.scr_hits = {}


def mask_canvas(quads):
    """Coverage raster for channel-tagged quads — same padded bounds math
    as rasterize_quads so the mask lands over the color frame."""
    if not quads:
        return None
    if not any(q.get("ch", 0) > 0 for q in quads):
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
    W = max(1, int(max(c[0] for c in corners)) + 5 - x0)
    H = max(1, int(max(c[1] for c in corners)) + 5 - y0)
    mask = bytearray(W * H * 4)
    for q in quads:
        ch = q.get("ch", 0)
        if ch == 0:
            continue
        mc = ((255, 0, 0) if ch == 1 else
              (0, 255, 0) if ch == 2 else
              (0, 0, 255) if ch == 8 else (0, 0, 0))
        a = max(0, min(255, int(q["cm"][3] * 255)))
        if a == 0:
            continue
        px_, py_ = q["p"]
        ex, ey = q["ex"], q["ey"]
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
                di = (dy * W + dx) * 4
                inv = 255 - a
                for c in range(3):
                    mask[di + c] = max(0, min(255,
                        mc[c] * a // 255 + mask[di + c] * inv // 255))
                mask[di + 3] = max(0, min(255, a +
                                   mask[di + 3] * inv // 255))
    return W, H, bytes(mask), (x0, y0)


def patch_set(z, set_dir, drive_cache):
    """One exported set dir -> masks written. drive_cache reuses parsed
    anms across banks (the body parse dominates)."""
    meta_root = set_dir
    if not os.path.isdir(meta_root):
        return (0, 0)
    written = skipped = 0
    walkers = {}
    for act_name in sorted(os.listdir(meta_root)):
        meta_path = os.path.join(meta_root, act_name, "meta.json")
        if not os.path.isfile(meta_path):
            continue
        meta = json.load(open(meta_path))
        drive = meta.get("anm", "")
        if drive not in walkers:
            host = set_entries(os.path.basename(meta_root))
            if host is None:
                walkers[drive] = None
                continue
            try:
                if drive in drive_cache:
                    r = drive_cache[drive]
                else:
                    r = _MaskWalk(z, drive, host)
                    drive_cache[drive] = r
                walkers[drive] = r
            except Exception:
                walkers[drive] = None
        r = walkers[drive]
        if r is None:
            continue
        act = next((a for a in r.hosts[0].anm["actions"]
                    if a.get("name") == meta.get("action")), None)
        if act is None:
            continue
        for fr in meta.get("frames", []):
            # fNNN.png embeds the logical frame index (export writes
            # f"{i:03d}.png") — draw exactly that frame.
            try:
                logical = int(fr["png"][1:4])
            except (KeyError, ValueError, IndexError):
                continue
            r.clear()
            r.draw_action(act, logical, PQ_IDENTITY)
            qs = []
            for h in r.hosts:
                qs += h.quads
            target = mask_canvas(qs)
            if target is None:
                skipped += 1
                continue
            W, H, mpx, _off = target
            mname = fr["png"][:-4] + "_m.png"
            write_png(os.path.join(meta_root, act_name, mname),
                      W, H, mpx)
            fr["mask"] = mname
            written += 1
        if written:
            meta["mask"] = True
            with open(meta_path, "w") as f:
                json.dump(meta, f, indent=1)
        written = skipped = 0
    return (written, skipped)


def main():
    jar, root = sys.argv[1], sys.argv[2]
    only = sys.argv[3:] if len(sys.argv) > 3 else None
    z = zipfile.ZipFile(jar)
    sets = [d for d in sorted(os.listdir(root))
            if os.path.isdir(os.path.join(root, d))]
    if only:
        sets = [d for d in sets if d in only]
    cache = {}
    for s in sets:
        w, k = patch_set(z, os.path.join(root, s), cache)
        if w or k:
            print(f"{s}: +{w} mask(s), {k} untinted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
