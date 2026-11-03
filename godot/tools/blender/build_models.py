#!/usr/bin/env python3
"""Replace kiln pieces with their Blender models (godot/art/blender.json).

Pipeline, from a kit's folder outwards:
    kiln build kit.kx.js   ->  art/<kit>/out/models/*.glb
    python3 godot/tools/blender/build_models.py   (this: Blender models)
    python3 godot/tools/blender/bake_kits.py      (AO, art/ao.json)

Each listed piece is rebuilt for every loom (x, x_b, x_c): the script reads
the kiln GLB for its materials and height and writes its own mesh over it.
A stamp (out/models/.blender.json) keeps the size and mtime of what it
wrote, so a rerun skips pieces already replaced and redoes the ones kiln
rebuilt. A piece already replaced but whose script changed is redone from
kiln only after a kiln rebuild: run kiln first, then this.

    python3 godot/tools/blender/build_models.py [--kit arena5] [--check] [--force]
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "..", "art"))
LOOMS = ("", "_b", "_c")
STAMP = ".blender.json"


def sig(path):
    st = os.stat(path)
    return [st.st_size, st.st_mtime_ns]


def digest(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()[:16]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kit")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true", help="redo the script on a GLB it already replaced (needs kiln's GLB: rebuild with kiln first)")
    a = ap.parse_args()
    with open(os.path.join(ART, "blender.json")) as f:
        cfg = json.load(f)
    blender = os.environ.get("BLENDER") or shutil.which("blender")
    pending = stale = failed = done = 0
    for kit, pieces in cfg["pieces"].items():
        if a.kit and kit != a.kit:
            continue
        models = os.path.join(ART, kit, "out", "models")
        try:
            with open(os.path.join(models, STAMP)) as f:
                stamp = json.load(f)
        except (OSError, ValueError):
            stamp = {}
        for piece, script in pieces.items():
            script = os.path.join(HERE, script)
            sh = digest(script)
            for loom in LOOMS:
                name = f"{piece}{loom}.glb"
                path = os.path.join(models, name)
                if not os.path.exists(path):
                    if loom == "":
                        print(f"warning: {kit}/{name} missing (kiln build first?)", file=sys.stderr)
                    continue
                rec = stamp.get(name)
                ours = rec and rec["sig"] == sig(path)
                if ours and rec["script"] == sh:
                    done += 1
                    continue
                if ours and not a.force:
                    stale += 1
                    print(f"stale: {kit}/{name}: its script changed; rebuild the piece with kiln, then run again")
                    continue
                pending += 1
                if a.check:
                    print(f"pending: {kit}/{name}")
                    continue
                if not blender:
                    sys.exit("blender not found: put it on PATH or set BLENDER")
                with tempfile.TemporaryDirectory() as tmp:
                    dst = os.path.join(tmp, name)
                    r = subprocess.run([blender, "-b", "-P", script, "--", path, dst], capture_output=True, text=True)
                    if r.returncode != 0 or not os.path.exists(dst):
                        failed += 1
                        print(f"FAILED {kit}/{name}\n{(r.stdout + r.stderr)[-2000:]}", file=sys.stderr)
                        continue
                    shutil.move(dst, path)
                stamp[name] = {"sig": sig(path), "script": sh}
                with open(os.path.join(models, STAMP), "w") as f:
                    json.dump(stamp, f, indent=1, sort_keys=True)
                print(f"modelled {kit}/{name}")
    print(f"{done} done, {pending} {'pending' if a.check else 'built now'}, {stale} stale, {failed} failed")
    return 1 if (a.check and pending) or stale or failed else 0


if __name__ == "__main__":
    sys.exit(main())
