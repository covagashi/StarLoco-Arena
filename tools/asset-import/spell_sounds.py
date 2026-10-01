#!/usr/bin/env python3
"""spell_sounds.py — retail spell-cast SFX map for the Godot fight view.

The retail client runs a Lua script per spell cast (data.jar scripts/<id>.lua).
Those scripts fire `Sound.playSound(<id>, stopOnChange)` at script scope
(cast whoosh) and inside `invoke(<ms>, 1, "fn")` callbacks (impact booms).
This extracts, per spell, the timed sound ids — [[t_ms, soundId], ...] —
and copies the referenced oggs out of sounds.jar.

Usage:
  go run ./server/cmd/dumpspells server/data-dist /tmp/spells_raw.json
  python3 tools/asset-import/spell_sounds.py /tmp/spells_raw.json \
      client/compiled/game/contents/data.jar \
      client/compiled/game/contents/sounds.jar \
      godot/assets/gamedata/spell_sfx.json godot/assets/sounds
"""

import json
import re
import sys
import zipfile

PLAY = re.compile(r"Sound\.playSound\(\s*(\d+)")
# weighted variant: playLocalRandomSound(rollOff, stop, id1, w1, id2, w2, ...)
RAND = re.compile(r"Sound\.playLocalRandomSound\(([^)]*)\)")
INVOKE = re.compile(r'invoke\(\s*(\d+)\s*,\s*\d+\s*,\s*"(\w+)"')
FUNC = re.compile(r"^function\s+(\w+)\s*\(")
END = re.compile(r"^end\b")


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


def main() -> None:
    spells_path, data_jar, sounds_jar, out_json, out_sounds = sys.argv[1:6]
    spells = json.load(open(spells_path))

    # spell -> scriptId (dedup across breeds)
    script_of = {}
    for lst in spells.values():
        for s in lst:
            if s.get("script"):
                script_of[s["id"]] = s["script"]

    result = {}
    wanted = set()
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


if __name__ == "__main__":
    main()
