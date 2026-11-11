#!/usr/bin/env python3
"""S34: the art, from its sources to what the game reads, in one command.

    python3 tools/art/build.py                 build what is stale, then check
    python3 tools/art/build.py arena5 feca_f   only these kits / figures
    python3 tools/art/build.py equipment       only the equipment pieces
    python3 tools/art/build.py --dry-run       list what is stale, build nothing
    python3 tools/art/build.py --force         rebuild everything selected
    python3 tools/art/build.py --pack <dist>   then pack it beside an export
    python3 tools/art/build.py --show 5:1      then a fight on arena 5 with
                                               breed 1 (Feca) to a PNG

Run from godot/. The steps, in order (each skips what is up to date):
1. pre:      per-kit generators the looms read (arena1/glyphs.py).
2. textures: loom build of every *.tx.js of a kit (out/<name>/).
3. kiln:     kiln build of the kit's kit.kx.js (out/models/*.glb).
4. blender:  tools/blender/build_models.py (art/blender.json), then
             tools/blender/bake_kits.py (art/ao.json), on what kiln rebuilt.
4b. equipment: kiln build of art/equipment/kit.kx.js (the pieces a figure
             wears, S35c; no Blender step).
5. figures:  every 3D figure of art/characters/figures.json in Blender
             (meshy_fighter.py / meshy_summon.py / crystal_8010.py), then
             the coaches' skin and hair masks (coach_masks.py).
6. checks:   tools/art/check.py on everything (names, scale, pivots,
             budgets, weight, credits). A failed check fails the build.

Up to date means the same content: each step keeps a stamp (out/.build.json)
with a hash of everything it read (the source, its include()s, the loom
textures it uses, the Blender scripts), so a git checkout, a reverted edit
or a one-piece rebuild with --only never leaves an output stale.

Tools (PATH or env): node + KILN / LOOM (default ~/.claude/skills/kiln and
~/.claude/skills/loom, MIT), BLENDER, GODOT, PIPPOP_MESHY (the owner's Meshy
originals, default ~/codigo/capturas/s35/meshy; outside git, see
art/CREDITS.md). A figure whose original is missing is skipped with a
warning; the build still fails if its GLB is missing too.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ART = os.path.join(GODOT, "art")
BLENDER_TOOLS = os.path.join(GODOT, "tools", "blender")
CHAR_TOOLS = os.path.join(BLENDER_TOOLS, "characters")
STAMP = ".build.json"
HOME = os.path.expanduser("~")
# Generators a kit's looms read, run before them (inputs, command).
PRE = {"arena1": [(["glyphs.py", "../fonts/NotoSansTagalog-Regular.ttf"], ["python3", "glyphs.py"])]}
# What the figure scripts import: a change in any of them rebuilds the figures.
FIGURE_LIBS = ["rig_anims.py", "meshy_fighter.py", "creature_anims.py", "fighter1.py"]


def log(msg):
    print(msg, flush=True)


def digest(*paths, extra=""):
    h = hashlib.sha256(extra.encode())
    for p in paths:
        h.update(p.encode())
        with open(p, "rb") as f:
            h.update(f.read())
    return h.hexdigest()[:20]


def tool(env, default_js):
    """The command that runs kiln or loom: $ENV (a binary or a .js) or the skill."""
    path = os.environ.get(env) or os.path.join(HOME, ".claude", "skills", default_js, "bin", default_js + ".js")
    if path.endswith(".js"):
        node = shutil.which("node")
        if not node or not os.path.exists(path):
            sys.exit(f"{default_js} not found: install the {default_js} skill or set {env}")
        return [node, path]
    return [path]


class Stamp:
    """out/.build.json of one folder: {key: hash}."""

    def __init__(self, folder):
        self.path = os.path.join(folder, "out", STAMP)
        try:
            with open(self.path) as f:
                self.data = json.load(f)
        except (OSError, ValueError):
            self.data = {}

    def fresh(self, key, h):
        return self.data.get(key) == h

    def set(self, key, h):
        self.data[key] = h
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path, "w") as f:
            json.dump(self.data, f, indent=1, sort_keys=True)


def kits():
    """Every kit the game uses: art/arena<N>/ with a kit.json."""
    out = []
    for d in sorted(os.listdir(ART), key=lambda d: (len(d), d)):
        if re.fullmatch(r"arena\d+", d) and os.path.exists(os.path.join(ART, d, "kit.json")):
            out.append(d)
    return out


def includes(path, seen=None):
    """A kiln/loom source and every file it include()s, recursively."""
    seen = seen if seen is not None else []
    if path in seen or not os.path.exists(path):
        return seen
    seen.append(path)
    with open(path) as f:
        text = f.read()
    for inc in re.findall(r'include\(\s*["\']([^"\']+)["\']', text):
        includes(os.path.normpath(os.path.join(os.path.dirname(path), inc)), seen)
    return seen


def texture_kits(kit):
    """The kits whose loom textures a kit's models read (itself, ../arenaN/out)."""
    found = {kit}
    for src in includes(os.path.join(ART, kit, "kit.kx.js")):
        with open(src) as f:
            found.update(re.findall(r"\.\./(arena\d+)/out", f.read()))
    return sorted(found)


def run(cmd, cwd, label):
    t = time.time()
    r = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if r.returncode != 0:
        log(r.stdout[-3000:])
        sys.exit(f"[build] {label} failed")
    log(f"[build] {label} ({time.time() - t:.0f} s)")
    return r.stdout


# ------------------------------------------------------------ the kit steps

def build_textures(kit, a, loom):
    """True if any of the kit's textures was (or, dry run, would be) rebuilt."""
    d = os.path.join(ART, kit)
    st = Stamp(d)
    changed = False
    pre_h = ""
    for inputs, cmd in PRE.get(kit, []):
        paths = [os.path.normpath(os.path.join(d, p)) for p in inputs]
        h = digest(*paths)
        key = "pre:" + inputs[0]
        if a.force or not st.fresh(key, h):
            changed = True
            if a.dry_run:
                log(f"stale: {kit} {inputs[0]}")
            else:
                run(cmd, d, f"{kit} {inputs[0]}")
                st.set(key, h)
        pre_h += h
    for tx in sorted(f for f in os.listdir(d) if f.endswith(".tx.js")):
        src = includes(os.path.join(d, tx))
        h = digest(*src, extra=pre_h)
        key = "loom:" + tx
        names = st.data.get("names:" + tx, [])
        missing = not names or any(not os.path.isdir(os.path.join(d, "out", n)) for n in names)
        if not a.force and st.fresh(key, h) and not missing:
            continue
        changed = True
        if a.dry_run:
            log(f"stale: {kit} {tx}")
            continue
        run(loom + ["build", tx, "--no-preview"], d, f"{kit} loom {tx}")
        listed = subprocess.run(loom + ["list", tx], cwd=d, stdout=subprocess.PIPE, text=True).stdout
        st.set("names:" + tx, re.findall(r"^material (\S+)", listed, re.M))
        st.set(key, h)
    return changed


def textures_hash(kit):
    """What a kit's models read from loom: the loom stamps of every texture kit."""
    parts = []
    for k in texture_kits(kit):
        st = Stamp(os.path.join(ART, k))
        parts += [f"{key}={v}" for key, v in sorted(st.data.items()) if key.startswith(("loom:", "pre:"))]
    return "|".join(parts)


def blender_hash(kit):
    """The Blender scripts and settings applied to a kit after kiln."""
    with open(os.path.join(ART, "blender.json")) as f:
        models = json.load(f)["pieces"].get(kit, {})
    with open(os.path.join(ART, "ao.json")) as f:
        ao = json.load(f)
    ao = [ao.get("strength"), ao["pieces"].get(kit, [])]
    scripts = sorted({os.path.join(BLENDER_TOOLS, s) for s in models.values()})
    libs = [os.path.join(BLENDER_TOOLS, f) for f in ("build_models.py", "bake_kits.py", "bake_ao.py")]
    return digest(*scripts, *libs, extra=json.dumps([models, ao], sort_keys=True))


def build_kiln(kit, a, kiln, tex_changed=False):
    d = os.path.join(ART, kit)
    st = Stamp(d)
    src = includes(os.path.join(d, "kit.kx.js"))
    h = digest(*src, os.path.join(d, "kit.json"), extra=textures_hash(kit) + blender_hash(kit))
    models = os.path.join(d, "out", "models")
    if not a.force and st.fresh("kiln", h) and os.path.isdir(models) and not (a.dry_run and tex_changed):
        return False
    if a.dry_run:
        log(f"stale: {kit} kit.kx.js")
        return False
    run(kiln + ["build", "kit.kx.js", "--no-preview"], d, f"{kit} kiln")
    # build_models/bake_kits redo every piece kiln rewrote (their stamps
    # follow the GLB's size and mtime): forget theirs so a piece whose
    # Blender script changed is redone too.
    for s in (".blender.json", ".ao.json"):
        p = os.path.join(models, s)
        if os.path.exists(p):
            os.remove(p)
    st.set("kiln", h)
    return True


def build_blender(kits_built, a):
    if a.dry_run or not kits_built:
        return
    blender = os.environ.get("BLENDER") or shutil.which("blender")
    if not blender:
        sys.exit("blender not found: put it on PATH or set BLENDER")
    for k in kits_built:
        run([sys.executable, os.path.join(BLENDER_TOOLS, "build_models.py"), "--kit", k], GODOT, f"{k} blender models")
        run([sys.executable, os.path.join(BLENDER_TOOLS, "bake_kits.py"), "--kit", k, "-j", str(a.jobs)], GODOT, f"{k} ambient occlusion")


# ------------------------------------------------------------ equipment

EQUIPMENT = os.path.join(ART, "equipment")


def equipment_hash():
    return digest(*includes(os.path.join(EQUIPMENT, "kit.kx.js")), os.path.join(EQUIPMENT, "pieces.json"))


def build_equipment(a, kiln):
    """S35c: the rigid pieces the figures wear (Fighter3D.hang)."""
    st = Stamp(EQUIPMENT)
    h = equipment_hash()
    if not a.force and st.fresh("kiln", h) and os.path.isdir(os.path.join(EQUIPMENT, "out", "models")):
        return False
    if a.dry_run:
        log("stale: equipment kit.kx.js")
        return False
    run(kiln + ["build", "kit.kx.js", "--no-preview"], EQUIPMENT, "equipment kiln")
    st.set("kiln", h)
    return True


# ------------------------------------------------------------ figures

def build_figures(names, a):
    d = os.path.join(ART, "characters")
    out = os.path.join(d, "out")
    with open(os.path.join(d, "figures.json")) as f:
        figs = json.load(f)["figures"]
    meshy = os.path.expanduser(os.environ.get("PIPPOP_MESHY", "~/codigo/capturas/s35/meshy"))
    st = Stamp(d)
    libs = [os.path.join(CHAR_TOOLS, f) for f in FIGURE_LIBS if os.path.exists(os.path.join(CHAR_TOOLS, f))]
    blender = os.environ.get("BLENDER") or shutil.which("blender")
    built = []
    for name, fig in figs.items():
        if names and name not in names:
            continue
        script = os.path.join(CHAR_TOOLS, fig["script"])
        cmd = [blender or "blender", "-b", "--python-exit-code", "1", "-P", script, "--"]
        inputs = [script, *libs]
        extra = json.dumps(fig, sort_keys=True)
        if "src" in fig:
            src = os.path.join(meshy, fig["src"], fig["src"] + ".glb")
            if not os.path.exists(src):
                log(f"warning: {name}: no original at {src} (PIPPOP_MESHY), kept as built")
                continue
            # the original is big and never edited: its size stands for it
            extra += f"|{os.path.getsize(src)}"
            cmd.append(src)
        glb = os.path.join(out, name + ".glb")
        cmd.append(glb)
        if fig.get("joints"):
            j = os.path.join(d, "joints", fig["src"] + ".json")
            inputs.append(j)
            cmd.append("--joints=" + j)
        cmd += [f"--{k}={v}" for k, v in fig.get("opts", {}).items()]
        h = digest(*inputs, extra=extra)
        if not a.force and st.fresh("figure:" + name, h) and os.path.exists(glb):
            continue
        if a.dry_run:
            log(f"stale: figure {name}")
            continue
        if not blender:
            sys.exit("blender not found: put it on PATH or set BLENDER")
        os.makedirs(out, exist_ok=True)
        run(cmd, GODOT, f"figure {name}")
        st.set("figure:" + name, h)
        built.append(name)
    coaches = [n for n in figs if n.startswith("coach_") and (not names or n in names)]
    for c in coaches:
        glb = os.path.join(out, c + ".glb")
        if not os.path.exists(glb):
            continue
        h = digest(glb, os.path.join(HERE, "coach_masks.py"))
        if not a.force and st.fresh("mask:" + c, h) and os.path.exists(os.path.join(out, c + "_mask.png")):
            continue
        if a.dry_run:
            log(f"stale: mask {c}")
            continue
        # coach_masks needs numpy from the user's site-packages: no -I
        run(["python3", os.path.join(HERE, "coach_masks.py"), c], GODOT, f"mask {c}")
        st.set("mask:" + c, digest(glb, os.path.join(HERE, "coach_masks.py")))
    return built


# ------------------------------------------------------------ after

def godot_cmd():
    return os.environ.get("GODOT") or shutil.which("godot") or sys.exit("godot not found: put it on PATH or set GODOT")


def show(spec, out):
    """A real fight (test/fight_ui_preview.tscn) on an arena with a class in
    3D, to a PNG: under xvfb so nothing opens on the screen."""
    arena, _, breed = spec.partition(":")
    with open(os.path.join(GODOT, "src", "maps", "arena_layout.gd")) as f:
        worlds = re.search(r"const WORLDS := \[([^\]]*)\]", f.read()).group(1)
    world = [int(w) for w in re.findall(r"\d+", worlds)][int(arena) - 1]
    if not os.path.exists(os.path.join(GODOT, ".godot", "global_script_class_cache.cfg")):
        # a fresh clone: one import pass registers the class_names
        run([godot_cmd(), "--headless", "--path", GODOT, "--import"], GODOT, "godot import (fresh checkout)")
    env = dict(os.environ, FIGHT_UI_MAP=str(world), FIGHT_UI_SHOT=os.path.abspath(out), DISPLAY="")
    if breed:
        env["FIGHT_UI_BREED"] = breed
    cmd = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24", godot_cmd(), "--path", GODOT,
           "--resolution", "1280x720", "test/fight_ui_preview.tscn"]
    if os.path.exists(out):
        os.remove(out)
    try:
        text = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300).stdout
    except subprocess.TimeoutExpired as e:
        text = (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
    if not os.path.exists(out):
        log(text[-2000:])
        sys.exit("[build] show failed: no capture")
    log(f"[build] arena {arena} (world {world}) in a fight -> {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("only", nargs="*", help="kits (arena5, with the kits that read its textures) or figures (feca_f); default everything")
    ap.add_argument("--dry-run", action="store_true", help="list what is stale, build nothing")
    ap.add_argument("--force", action="store_true", help="rebuild everything selected")
    ap.add_argument("-j", "--jobs", type=int, default=3, help="Blender AO bakes at once")
    ap.add_argument("--no-check", action="store_true")
    ap.add_argument("--pack", metavar="DIST", help="then copy the art beside an export (pack_arenas.gd)")
    ap.add_argument("--show", metavar="ARENA[:BREED]", help="then capture a fight on that arena")
    ap.add_argument("--shot", default="art-show.png", help="where --show writes (default art-show.png)")
    a = ap.parse_args()
    t0 = time.time()
    all_kits = kits()
    with open(os.path.join(ART, "characters", "figures.json")) as f:
        all_figs = list(json.load(f)["figures"])
    bad = [o for o in a.only if o not in all_kits and o not in all_figs and o not in ("characters", "equipment")]
    if bad:
        sys.exit(f"unknown: {', '.join(bad)} (kits: {', '.join(all_kits)}; figures: art/characters/figures.json)")
    sel_kits = [k for k in all_kits if not a.only or k in a.only]
    # a kit whose models read a selected kit's textures (arena7 reads
    # ../arena6/out) is rebuilt with it
    sel_kits = [k for k in all_kits if k in sel_kits or set(texture_kits(k)) & set(sel_kits)]
    sel_figs = [f for f in all_figs if not a.only or f in a.only or "characters" in a.only]
    sel_equipment = not a.only or "equipment" in a.only
    loom = tool("LOOM", "loom") if sel_kits else None
    kiln = tool("KILN", "kiln") if sel_kits or sel_equipment else None
    # textures first, of every kit a selected kit reads from
    tex_kits = sorted({t for k in sel_kits for t in texture_kits(k)}, key=all_kits.index)
    changed = {k for k in tex_kits if build_textures(k, a, loom)}
    rebuilt = [k for k in sel_kits if build_kiln(k, a, kiln, bool(changed & set(texture_kits(k))))]
    build_blender(rebuilt, a)
    if sel_equipment:
        build_equipment(a, kiln)
    if sel_figs:
        build_figures(set(sel_figs) if a.only else set(), a)
    if a.dry_run:
        log("[build] dry run: nothing built")
        return
    log(f"[build] done in {time.time() - t0:.0f} s")
    if not a.no_check:
        r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "check.py")], cwd=GODOT)
        if r.returncode != 0:
            sys.exit("[build] checks failed")
    if a.pack:
        run([godot_cmd(), "--headless", "--path", GODOT, "-s", "tools/art/pack_arenas.gd", "--", os.path.abspath(a.pack)],
            GODOT, f"pack -> {a.pack}")
    if a.show:
        show(a.show, a.shot)


if __name__ == "__main__":
    main()
