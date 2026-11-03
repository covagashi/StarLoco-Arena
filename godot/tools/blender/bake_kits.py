#!/usr/bin/env python3
"""Bake ambient occlusion into the kit pieces listed in godot/art/ao.json.

Run after `kiln build` (the GLBs in art/<kit>/out/models/ are git-ignored
build outputs). Each piece is baked in place by bake_ao.py in Blender
headless. A stamp (out/models/.ao.json) keeps the size and mtime of every
baked file, so running it again skips what is already baked and only bakes
what kiln rebuilt.

    python3 godot/tools/blender/bake_kits.py [--kit arena1] [--check] [-j 4]

--check: bake nothing; list what is pending and exit 1 if anything is.
BLENDER overrides the binary (default: blender on PATH).
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art"))
LOOMS = ("", "_b", "_c")
STAMP = ".ao.json"


def load_stamp(models):
    try:
        with open(os.path.join(models, STAMP)) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_stamp(models, stamp):
    with open(os.path.join(models, STAMP), "w") as f:
        json.dump(stamp, f, indent=1, sort_keys=True)


def sig(path):
    st = os.stat(path)
    return [st.st_size, st.st_mtime_ns]


def plan(cfg, only):
    """(kit, file name) pairs to bake, and the ones already baked."""
    todo, done, stale = [], [], []
    for kit, pieces in cfg["pieces"].items():
        if only and kit != only:
            continue
        models = os.path.join(ART, kit, "out", "models")
        stamp = load_stamp(models)
        for piece in pieces:
            found = False
            for loom in LOOMS:
                name = f"{piece}{loom}.glb"
                path = os.path.join(models, name)
                if not os.path.exists(path):
                    continue
                found = True
                rec = stamp.get(name)
                if rec and rec["sig"] == sig(path):
                    if rec["strength"] == cfg["strength"]:
                        done.append((kit, name))
                    else:  # baked at another strength: needs kiln's original
                        stale.append((kit, name))
                else:
                    todo.append((kit, name))
            if not found:
                print(f"warning: {kit}/{piece}: no GLB in out/models (kiln build first?)", file=sys.stderr)
    return todo, done, stale


def bake(blender, kit, name, strength):
    models = os.path.join(ART, kit, "out", "models")
    src = os.path.join(models, name)
    with tempfile.TemporaryDirectory() as tmp:
        dst = os.path.join(tmp, name)
        r = subprocess.run([blender, "-b", "-P", os.path.join(HERE, "bake_ao.py"), "--", src, dst, str(strength)],
                           capture_output=True, text=True)
        if r.returncode != 0 or not os.path.exists(dst):
            return kit, name, (r.stdout + r.stderr)[-2000:]
        shutil.move(dst, src)
    return kit, name, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("-j", type=int, default=4)
    a = ap.parse_args()
    with open(os.path.join(ART, "ao.json")) as f:
        cfg = json.load(f)
    todo, done, stale = plan(cfg, a.kit)
    for kit, name in stale:
        print(f"stale: {kit}/{name} was baked at another strength; rebuild it with kiln, then run again")
    if a.check:
        for kit, name in todo:
            print(f"pending: {kit}/{name}")
        print(f"{len(done)} baked, {len(todo)} pending, {len(stale)} stale")
        return 1 if todo or stale else 0
    blender = os.environ.get("BLENDER") or shutil.which("blender")
    if not blender:
        sys.exit("blender not found: put it on PATH or set BLENDER")
    failed = 0
    with ThreadPoolExecutor(a.j) as ex:
        for kit, name, err in ex.map(lambda t: bake(blender, t[0], t[1], cfg["strength"]), todo):
            models = os.path.join(ART, kit, "out", "models")
            if err:
                failed += 1
                print(f"FAILED {kit}/{name}\n{err}", file=sys.stderr)
                continue
            stamp = load_stamp(models)
            stamp[name] = {"sig": sig(os.path.join(models, name)), "strength": cfg["strength"]}
            save_stamp(models, stamp)
            print(f"baked {kit}/{name}")
    print(f"{len(todo) - failed} baked now, {len(done)} already baked, {failed} failed, {len(stale)} stale")
    return 1 if failed or stale else 0


if __name__ == "__main__":
    sys.exit(main())
