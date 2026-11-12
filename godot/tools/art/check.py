#!/usr/bin/env python3
"""S34: the asset checks, run by build.py after every build (and on their
own). Exit 1 if any check fails; warnings only print.

    python3 -I tools/art/check.py [--quiet]

What is checked (budgets below, from S33/S35b and the web demo, S44):
- every kit (art/arena<N>/kit.json): names, every piece in its three looms
  (and the column under a block) built, a block's walk surface (top) inside
  its model and the block centred on its cell, per-piece budget
  (triangles, texture size, GLB weight), and up to date with its sources
  (build.py's stamps);
- every layout (art/layouts): every placed piece is in its kit;
- every figure (art/characters/figures.json): built, names, 1.45 high with
  the feet on the floor and near the centre, the 10 animations, the
  triangle / bone / texture / weight budget; every figure Fighter3D draws
  has a recipe; the coaches have their masks;
- the equipment (art/equipment/pieces.json): every piece a card names is
  built, within its budget, and up to date with kit.kx.js;
- art/CREDITS.md names every source folder of art/ and every font;
- the weight each prototype arena ships (pack_arenas.gd), against S44.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb import Glb  # noqa: E402
import build  # noqa: E402

ART = build.ART
GODOT = build.GODOT
NAME = re.compile(r"^[a-z][a-z0-9_]*$")
LOOMS = ("", "_b", "_c")
# A kit piece: kiln + Blender, seen at 86-px cells.
PIECE_TRIS = 25000
PIECE_TEX = 1024
PIECE_KB = 4096
# A figure (S35b recipe: 5,000 triangles, 20 bones, 1024² texture).
FIG_TRIS = 5000
FIG_BONES = 20
FIG_TEX = 1024
FIG_KB = 1200
FIG_HEIGHT = 1.45
# An equipment piece (S35c): small, flat-coloured kiln, no texture.
EQUIP_TRIS = 1500
EQUIP_KB = 256
# A coach garment (coach_garment.py): the body's own faces, thickened.
GARMENT_TRIS = 3500
GARMENT_KB = 256
ANIMS = ["idle_loop", "walk_loop", "cast", "melee", "hit", "die", "jump", "celebrate", "carry_loop", "throw"]
# One arena's models as shipped (S44: ≤ 50 MB first load for the whole demo;
# arenas load on demand, so this is per arena).
ARENA_MB = 40


class Report:
    def __init__(self, quiet):
        self.fails = []
        self.warns = []
        self.quiet = quiet

    def fail(self, msg):
        self.fails.append(msg)

    def warn(self, msg):
        self.warns.append(msg)

    def note(self, msg):
        if not self.quiet:
            print(msg)


def check_kits(r):
    total = 0
    for kit in build.kits():
        d = os.path.join(ART, kit)
        models = os.path.join(d, "out", "models")
        with open(os.path.join(d, "kit.json")) as f:
            pieces = json.load(f)["pieces"]
        n = size = 0
        for p in pieces:
            name = p["name"]
            if not NAME.match(name):
                r.fail(f"{kit}/{name}: name is not lower_snake_case")
            for loom in LOOMS:
                for piece in [name] + ([p["col"]] if p.get("kind") == "tile" and p.get("col") else []):
                    path = os.path.join(models, piece + loom + ".glb")
                    if not os.path.exists(path):
                        r.fail(f"{kit}/{piece}{loom}: not built")
                        continue
                    g = Glb(path)
                    n += 1
                    size += g.size
                    if g.tris > PIECE_TRIS:
                        r.fail(f"{kit}/{piece}{loom}: {g.tris} triangles > {PIECE_TRIS}")
                    for im in g.images:
                        if max(im["w"], im["h"]) > PIECE_TEX:
                            r.fail(f"{kit}/{piece}{loom}: texture {im['w']}×{im['h']} > {PIECE_TEX}")
                    if g.size > PIECE_KB * 1024:
                        r.fail(f"{kit}/{piece}{loom}: {g.size // 1024} KB > {PIECE_KB} KB")
                    if piece == name and loom == "" and p.get("kind") == "tile":
                        lo, hi = g.bounds()
                        top = p.get("top")
                        if top is None or not lo[1] - 0.01 <= top <= hi[1] + 0.01:
                            r.fail(f"{kit}/{name}: walk surface top={top} outside the model ({lo[1]:.2f}..{hi[1]:.2f})")
                        if abs(lo[0] + hi[0]) / 2 > 0.2 or abs(lo[2] + hi[2]) / 2 > 0.2:
                            r.fail(f"{kit}/{name}: block not centred on its cell")
        stale = stale_kit(kit)
        if stale:
            r.fail(f"{kit}: out of date with its sources ({stale}): python3 tools/art/build.py {kit}")
        total += size
        r.note(f"  {kit:8} {len(pieces):3} pieces, {n:3} GLB, {size / 1048576:5.1f} MB")
    return total


def stale_kit(kit):
    """What of a kit is older than its sources, by build.py's stamps; ""."""
    d = os.path.join(ART, kit)
    st = build.Stamp(d)
    for tx in sorted(f for f in os.listdir(d) if f.endswith(".tx.js")):
        pre = "".join(build.digest(*[os.path.normpath(os.path.join(d, p)) for p in inputs])
                      for inputs, _ in build.PRE.get(kit, []))
        if not st.fresh("loom:" + tx, build.digest(*build.includes(os.path.join(d, tx)), extra=pre)):
            return tx
    src = build.includes(os.path.join(d, "kit.kx.js"))
    h = build.digest(*src, os.path.join(d, "kit.json"), extra=build.textures_hash(kit) + build.blender_hash(kit))
    return "" if st.fresh("kiln", h) else "kit.kx.js"


def check_layouts(r):
    kits = {}
    for kit in build.kits():
        with open(os.path.join(ART, kit, "kit.json")) as f:
            kits[kit] = {p["name"]: p for p in json.load(f)["pieces"]}
    release = int(re.search(r"const RELEASE := (\d+)", open(os.path.join(GODOT, "src", "maps", "arena_layout.gd")).read()).group(1))
    for name in sorted(os.listdir(os.path.join(ART, "layouts"))):
        if not re.fullmatch(r"arena-\d+\.json", name):
            continue   # e.g. the ._* files macOS leaves over Samba
        arena = int(re.search(r"\d+", name).group())
        with open(os.path.join(ART, "layouts", name)) as f:
            cells = json.load(f)["cells"]
        files = set()
        for items in cells.values():
            for it in items:
                pc = kits.get(it["kit"], {}).get(it["piece"])
                if pc is None:
                    r.fail(f"{name}: {it['kit']}/{it['piece']} is in no kit.json")
                    continue
                loom = {"a": "", "b": "_b", "c": "_c"}[it.get("loom", "a")]
                files.add(os.path.join(ART, it["kit"], "out", "models", it["piece"] + loom + ".glb"))
                if pc.get("kind") == "tile" and pc.get("col"):
                    files.add(os.path.join(ART, it["kit"], "out", "models", pc["col"] + loom + ".glb"))
        mb = sum(os.path.getsize(f) for f in files if os.path.exists(f)) / 1048576
        if arena <= release:
            r.note(f"  arena {arena:2} ships {len(files):3} models, {mb:5.1f} MB")
            if mb > ARENA_MB:
                r.warn(f"arena {arena}: {mb:.1f} MB of models > {ARENA_MB} MB (S44 web demo)")


def check_figures(r):
    d = os.path.join(ART, "characters")
    with open(os.path.join(d, "figures.json")) as f:
        figs = json.load(f)["figures"]
    size = 0
    for name, fig in figs.items():
        if not NAME.match(name):
            r.fail(f"figure {name}: name is not lower_snake_case")
        if fig.get("joints") and not os.path.exists(os.path.join(d, "joints", fig["src"] + ".json")):
            r.fail(f"figure {name}: joints/{fig['src']}.json missing")
        path = os.path.join(d, "out", name + ".glb")
        if not os.path.exists(path):
            r.fail(f"figure {name}: not built")
            continue
        g = Glb(path)
        size += g.size
        lo, hi = g.bounds()
        if g.tris > FIG_TRIS:
            r.fail(f"figure {name}: {g.tris} triangles > {FIG_TRIS}")
        if g.bones > FIG_BONES:
            r.fail(f"figure {name}: {g.bones} bones > {FIG_BONES}")
        missing = [a for a in ANIMS if a not in g.anims]
        if missing:
            r.fail(f"figure {name}: animations missing: {', '.join(missing)}")
        for im in g.images:
            if max(im["w"], im["h"]) > FIG_TEX:
                r.fail(f"figure {name}: texture {im['w']}×{im['h']} > {FIG_TEX}")
        if g.size > FIG_KB * 1024:
            r.fail(f"figure {name}: {g.size // 1024} KB > {FIG_KB} KB")
        if "src" in fig:   # the modelled crystal hovers at its own height
            if abs(hi[1] - lo[1] - FIG_HEIGHT) > 0.01:
                r.fail(f"figure {name}: {hi[1] - lo[1]:.3f} high, not {FIG_HEIGHT}")
            if abs(lo[1]) > 0.005:
                r.fail(f"figure {name}: feet at {lo[1]:.3f}, not on the floor")
            if abs(lo[0] + hi[0]) / 2 > 0.1 or abs(lo[2] + hi[2]) / 2 > 0.2:
                r.fail(f"figure {name}: off centre ({(lo[0] + hi[0]) / 2:.2f}, {(lo[2] + hi[2]) / 2:.2f})")
        if name.startswith("coach_") and not os.path.exists(os.path.join(d, "out", name + "_mask.png")):
            r.fail(f"figure {name}: no skin/hair mask (coach_masks.py)")
        if stale_figure(name, fig):
            r.fail(f"figure {name}: out of date with its recipe: python3 tools/art/build.py {name}")
    src = open(os.path.join(GODOT, "src", "anims", "fighter3d.gd")).read()
    drawn = set()
    for const in ("MODELS", "SUMMONS", "COACHES"):
        block = re.search(r"const %s := \{(.*?)\n\S" % const, src, re.S).group(1)
        drawn.update(re.findall(r'"([a-z][a-z0-9_]*)"', block))
    for name in sorted(drawn - set(figs)):
        r.fail(f"figure {name}: Fighter3D draws it but figures.json has no recipe")
    r.note(f"  figures  {len(figs):3} GLB, {size / 1048576:5.1f} MB")
    return size


def stale_figure(name, fig):
    """True if build.py would rebuild the figure (its original present)."""
    d = os.path.join(ART, "characters")
    meshy = os.path.expanduser(os.environ.get("PIPPOP_MESHY", "~/codigo/capturas/s35/meshy"))
    extra = json.dumps(fig, sort_keys=True)
    if "src" in fig:
        src = os.path.join(meshy, fig["src"], fig["src"] + ".glb")
        if not os.path.exists(src):
            return False   # can't tell without the original: kept as built
        extra += f"|{os.path.getsize(src)}"
    libs = [os.path.join(build.CHAR_TOOLS, f) for f in build.FIGURE_LIBS if os.path.exists(os.path.join(build.CHAR_TOOLS, f))]
    inputs = [os.path.join(build.CHAR_TOOLS, fig["script"]), *libs]
    if fig.get("joints"):
        inputs.append(os.path.join(d, "joints", fig["src"] + ".json"))
    return not build.Stamp(d).fresh("figure:" + name, build.digest(*inputs, extra=extra))


def check_equipment(r):
    d = build.EQUIPMENT
    with open(os.path.join(d, "pieces.json")) as f:
        tables = json.load(f)
    size = 0
    with open(os.path.join(d, "garments.json")) as f:
        garments = {k for k in json.load(f) if not k.startswith("_")}
    pieces = sorted({p for t in ("fighter", "coach") for p in tables.get(t, {}).values()})
    for name in pieces:
        if not NAME.match(name):
            r.fail(f"equipment {name}: name is not lower_snake_case")
        if name in garments:
            continue
        path = os.path.join(d, "out", "models", name + ".glb")
        if not os.path.exists(path):
            r.fail(f"equipment {name}: not built (python3 tools/art/build.py equipment)")
            continue
        g = Glb(path)
        size += g.size
        if g.tris > EQUIP_TRIS:
            r.fail(f"equipment {name}: {g.tris} triangles > {EQUIP_TRIS}")
        if g.size > EQUIP_KB * 1024:
            r.fail(f"equipment {name}: {g.size // 1024} KB > {EQUIP_KB} KB")
    if not build.Stamp(d).fresh("kiln", build.equipment_hash()):
        r.fail("equipment: out of date with kit.kx.js: python3 tools/art/build.py equipment")
    r.note(f"  equipment {len(pieces):3} GLB, {size / 1048576:5.1f} MB")
    gsize = 0
    for fig in build.GARMENT_FIGS:
        for name in sorted(garments):
            if not NAME.match(name):
                r.fail(f"garment {name}: name is not lower_snake_case")
            path = os.path.join(d, "out", "garments", fig, name + ".glb")
            if not os.path.exists(path):
                r.fail(f"garment {name} ({fig}): not built (python3 tools/art/build.py equipment)")
                continue
            g = Glb(path)
            gsize += g.size
            if g.tris > GARMENT_TRIS:
                r.fail(f"garment {name} ({fig}): {g.tris} triangles > {GARMENT_TRIS}")
            if g.size > GARMENT_KB * 1024:
                r.fail(f"garment {name} ({fig}): {g.size // 1024} KB > {GARMENT_KB} KB")
        if not build.Stamp(d).fresh("garments:" + fig, build.garments_hash(fig)):
            r.fail(f"garments of {fig}: out of date: python3 tools/art/build.py equipment")
    r.note(f"  garments {len(garments) * len(build.GARMENT_FIGS):3} GLB, {gsize / 1048576:5.1f} MB")
    return size + gsize


def check_credits(r):
    path = os.path.join(ART, "CREDITS.md")
    if not os.path.exists(path):
        r.fail("art/CREDITS.md missing")
        return
    text = open(path).read()
    for d in sorted(os.listdir(ART)):
        if os.path.isdir(os.path.join(ART, d)) and not d.startswith(".") and d in tracked_dirs():
            if f"`{d}/" not in text:
                r.fail(f"art/CREDITS.md does not say where art/{d}/ comes from")
    for f in os.listdir(os.path.join(ART, "fonts")):
        if f.endswith((".ttf", ".otf")) and f not in text:
            r.fail(f"art/CREDITS.md does not credit the font {f}")


def tracked_dirs():
    """The art/ folders git tracks (a scratch folder isn't credited)."""
    import subprocess
    out = subprocess.run(["git", "ls-files", "art"], cwd=GODOT, stdout=subprocess.PIPE, text=True).stdout
    return {p.split("/")[1] for p in out.splitlines() if p.count("/") >= 2}


def main():
    r = Report("--quiet" in sys.argv)
    r.note("[check] kits")
    kits_size = check_kits(r)
    r.note("[check] layouts")
    check_layouts(r)
    r.note("[check] figures")
    figs_size = check_figures(r)
    r.note("[check] equipment")
    figs_size += check_equipment(r)
    check_credits(r)
    for w in r.warns:
        print("warning:", w)
    for f in r.fails:
        print("FAIL:", f)
    total = (kits_size + figs_size) / 1048576
    print(f"[check] {len(r.fails)} failed, {len(r.warns)} warnings; built art {total:.0f} MB")
    sys.exit(1 if r.fails else 0)


if __name__ == "__main__":
    main()
