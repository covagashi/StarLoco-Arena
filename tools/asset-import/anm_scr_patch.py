#!/usr/bin/env python3
"""anm_scr_patch.py — inject runScript (pb_1) audio triggers into already-
exported meta.json files WITHOUT re-rendering frames.

Replays each action's frame traversal (draw_action walk, quads discarded),
collects scr_hits exactly like the exporter, remaps logical→written frame
indices through the existing meta frames, and writes meta["scr"] in place.
New exports get "scr" automatically — this exists to patch sets rendered
before runScript collection landed.

Usage: anm_scr_patch.py <animations.jar> <anims_root> [<set_dir> ...]
"""

import json
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anm_dump import parse_anm
from anm_render import (PQ_IDENTITY, CompositeRenderer, FrameRenderer,
                        meta_scr)


def set_host(set_name):
    """Exported set dir -> actor anm entry (composite host)."""
    if set_name.startswith("fighter_"):
        return f"animations/Players/{set_name[8:]}.anm"
    if set_name.startswith("npc_"):
        return f"animations/NPCs/{set_name[4:]}.anm"
    return None  # animsort_*/coach_*: standalone driver export


class _WalkComposite(CompositeRenderer):
    """CompositeRenderer without texture decode — the walk only touches
    anm structures (labels/crcs/regions ids), never rasterizes."""

    def __init__(self, z, *entries):
        self.hosts = [FrameRenderer(parse_anm(z.read(e)), [])
                      for e in entries]
        self.son_hits = {}
        self.scr_hits = {}


class Walker:
    """scr_hits collector over a driver anm (+ optional host)."""

    def __init__(self, z, driver, host):
        entries = (driver, host) if host else (driver,)
        self.r = _WalkComposite(z, *entries)
        self.anm = self.r.hosts[0].anm

    def scr(self, action_name, meta_frames):
        act = next((a for a in self.anm["actions"]
                    if a.get("name") == action_name), None)
        if act is None:
            return None
        self.r.scr_hits = {}
        clear = self.r.clear if hasattr(self.r, "clear") else None
        for i in range(act["logical_frames"]):
            if clear:
                clear()
            else:
                self.r.quads = []
            self.r.draw_action(act, i, PQ_IDENTITY)
        return meta_scr(self.r.scr_hits, meta_frames)


def main():
    jar, root = sys.argv[1], sys.argv[2]
    only = set(sys.argv[3:])
    z = zipfile.ZipFile(jar)
    walkers = {}   # (driver, host) -> Walker
    patched = skipped = 0
    for s in sorted(os.listdir(root)):
        sp = os.path.join(root, s)
        if not os.path.isdir(sp) or (only and s not in only):
            continue
        host = set_host(s)
        for a in sorted(os.listdir(sp)):
            mp = os.path.join(sp, a, "meta.json")
            if not os.path.exists(mp):
                continue
            meta = json.load(open(mp))
            driver = meta.get("anm")
            action = meta.get("action")
            if not driver or not action:
                continue
            # standalone body/npc actions: driver == host entry -> plain walk
            drv_host = None if driver == host else host
            key = (driver, drv_host)
            if key not in walkers:
                walkers[key] = Walker(z, driver, drv_host)
            scr = walkers[key].scr(action, meta.get("frames", []))
            if scr:
                meta["scr"] = scr
                with open(mp, "w") as f:
                    json.dump(meta, f, separators=(",", ":"))
                patched += 1
                print(f"[scr] {s}/{a}: "
                      f"{sorted(set(i for v in scr.values() for i in v))}")
            else:
                skipped += 1
    print(f"[scr] patched={patched} silent={skipped}")


if __name__ == "__main__":
    main()
