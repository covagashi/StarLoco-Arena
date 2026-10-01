#!/usr/bin/env python3
"""spell_sounds.py — retail SFX maps for the Godot fight view.

The retail client runs a Lua script per spell cast (data.jar scripts/<id>.lua).
Those scripts fire `Sound.playSound(<id>, stopOnChange)` at script scope
(cast whoosh) and inside `invoke(<ms>, 1, "fn")` callbacks (impact booms).
This extracts, per spell, the timed sound ids — [[t_ms, soundId], ...] —
and copies the referenced oggs out of sounds.jar.

It also handles the anm-frame channel: `pb_1` runScript parts on .anm frames
execute `scripts/anm/<id>.lua`, which are boilerplate locals feeding
`playLocalSound(preset, stop, soundFileId, gain)` / `playLocalRandomSound`
/ `playBark`. Those map into `anm_scripts.json`:
  {scriptId: {"s": [[soundId, gain], ...], "stop": bool}} — multi-entry "s"
  is a uniform-random set (playLocalRandomSound); Godot picks one per play.

Usage:
  go run ./server/cmd/dumpspells server/data-dist /tmp/spells_raw.json
  python3 tools/asset-import/spell_sounds.py /tmp/spells_raw.json \
      client/compiled/game/contents/data.jar \
      client/compiled/game/contents/sounds.jar \
      godot/assets/gamedata/spell_sfx.json godot/assets/sounds \
      godot/assets/gamedata/anm_scripts.json
"""

import json
import re
import sys
import zipfile

PLAY = re.compile(r"Sound\.playSound\(\s*(\d+)")
PART = re.compile(
    r"Particle\.add(?:Tween)?ParticleSystem\(\s*(\d+)\s*,\s*(\w+)")
# weighted variant: playLocalRandomSound(rollOff, stop, id1, w1, id2, w2, ...)
RAND = re.compile(r"Sound\.playLocalRandomSound\(([^)]*)\)")
INVOKE = re.compile(r'invoke\(\s*(\d+)\s*,\s*\d+\s*,\s*"(\w+)"')
FUNC = re.compile(r"^function\s+(\w+)\s*\(")
END = re.compile(r"^end\b")


def script_fx(src: str) -> list:
    """[[t_ms, xpsId, anchor], ...] — anchor is caster|target|cell."""
    lines = src.split("\n")
    funcs = {}
    top = []
    cur = None
    for ln in lines:
        m = FUNC.match(ln)
        if m:
            cur = m.group(1)
            funcs.setdefault(cur, [])
            continue
        if cur is not None and END.match(ln):
            cur = None
            continue
        (funcs[cur] if cur is not None else top).append(ln)

    out = []
    seen = set()

    def anchor(var: str) -> str:
        if var.startswith("dest"):
            return "target"
        if var.startswith("start"):
            return "caster"
        return "caster"

    def scan(body, base_t):
        for ln in body:
            for m in PART.finditer(ln):
                out.append((base_t, int(m.group(1)), anchor(m.group(2))))
            for m in INVOKE.finditer(ln):
                t, fn = int(m.group(1)), m.group(2)
                if fn in funcs and fn not in seen:
                    seen.add(fn)
                    scan(funcs[fn], base_t + t)

    scan(top, 0)
    return out


def script_sounds(src: str) -> list:
    """[[t_ms, sid], ...] — top-level calls at t=0; invoke()-deferred calls
    at the invoke delay (recursive, invokes inside functions accumulate)."""
    lines = src.split("\n")
    funcs = {}          # name -> [lines]
    top = []            # top-level lines
    cur = None
    for ln in lines:
        m = FUNC.match(ln)
        if m:
            cur = m.group(1)
            funcs.setdefault(cur, [])
            continue
        if cur is not None and END.match(ln):
            cur = None
            continue
        (funcs[cur] if cur is not None else top).append(ln)

    out = []
    seen = set()

    def scan(body, base_t):
        for ln in body:
            for m in PLAY.finditer(ln):
                out.append((base_t, int(m.group(1))))
            for m in RAND.finditer(ln):
                ids = [int(x) for x in
                       re.findall(r"\d+", m.group(1))][2::2]  # id,weight…
                for sid in ids:
                    out.append((base_t, sid))
            for m in INVOKE.finditer(ln):
                t, fn = int(m.group(1)), m.group(2)
                if fn in funcs and fn not in seen:
                    seen.add(fn)
                    scan(funcs[fn], base_t + t)

    scan(top, 0)
    return out


def anm_script_sounds(src: str):
    """Parse one scripts/anm/<id>.lua boilerplate.

    -> {"s": [[soundId, gain], ...], "stop": bool} or None.
    playLocalSound feeds soundFileId/gain/stopOnAnimationChange locals;
    playLocalRandomSound takes literal (id, gain) pairs picked UNIFORMLY
    (agO.java: ej_0.n — the second number is gain, not a weight).
    playBark/playGroundSound resolve through tables we don't ship -> None.
    """
    stop = re.search(r"stopOnAnimationChange\s*=\s*(\w+)", src)
    stop = stop.group(1) == "true" if stop else False
    sid = re.search(r"soundFileId\s*=\s*(\d+)", src)
    if sid:
        g = re.search(r"gain\s*=\s*([\d.]+)", src)
        return {"s": [[int(sid.group(1)),
                       float(g.group(1)) if g else 100.0]],
                "stop": stop}
    m = RAND.search(src)
    if m:
        nums = [int(x) for x in re.findall(r"\d+", m.group(1))]
        # var-name args carry no digits, so nums is exactly id,gain,id,gain…
        return {"s": [[nums[i], float(nums[i + 1])]
                      for i in range(0, len(nums) - 1, 2)],
                "stop": stop}
    return None  # playBark (npc voice table we don't ship) / silence


def main() -> None:
    spells_path, data_jar, sounds_jar, out_json, out_sounds = sys.argv[1:6]
    anm_json = sys.argv[6] if len(sys.argv) > 6 else None
    fx_json = sys.argv[7] if len(sys.argv) > 7 else None
    spells = json.load(open(spells_path))

    # spell -> scriptId (dedup across breeds)
    script_of = {}
    for lst in spells.values():
        for s in lst:
            if s.get("script"):
                script_of[s["id"]] = s["script"]

    result = {}
    fx_result = {}
    wanted = set()
    anm_result = {}
    barks = 0
    with zipfile.ZipFile(data_jar) as z:
        for sid, script in sorted(script_of.items()):
            try:
                src = z.read(f"scripts/{script}.lua").decode("latin-1")
            except KeyError:
                continue
            hits = script_sounds(src)
            if hits:
                result[str(sid)] = [[t, i] for t, i in sorted(set(hits))]
                wanted.update(i for _, i in hits)
            if fx_json:
                fx = script_fx(src)
                if fx:
                    fx_result[str(sid)] = [
                        [t, i, a] for t, i, a in sorted(set(fx))]
        if anm_json:
            for nm in z.namelist():
                m = re.match(r"scripts/anm/(\d+)\.lua$", nm)
                if not m:
                    continue
                parsed = anm_script_sounds(
                    z.read(nm).decode("latin-1"))
                if parsed is None:
                    barks += 1
                    continue
                anm_result[m.group(1)] = parsed
                wanted.update(p[0] for p in parsed["s"])

    copied = 0
    with zipfile.ZipFile(sounds_jar) as z:
        for sid in sorted(wanted):
            try:
                data = z.read(f"sounds/{sid}.ogg")
            except KeyError:
                continue
            with open(f"{out_sounds}/{sid}.ogg", "wb") as f:
                f.write(data)
            copied += 1

    json.dump(result, open(out_json, "w"), separators=(",", ":"))
    print(f"spell sfx: {len(result)} spells, {len(wanted)} ids, "
          f"{copied} oggs -> {out_sounds}")
    if anm_json:
        json.dump(anm_result, open(anm_json, "w"), separators=(",", ":"))
        print(f"anm script sfx: {len(anm_result)} scripts, {barks} skipped "
              f"(bark/none) -> {anm_json}")
    if fx_json:
        json.dump(fx_result, open(fx_json, "w"), separators=(",", ":"))
        print(f"spell fx: {len(fx_result)} spells -> {fx_json}")


if __name__ == "__main__":
    main()
