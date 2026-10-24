#!/usr/bin/env python3
"""sounds.py — copy every combat sfx the Godot client can ask for out of
sounds.jar into assets/sounds/<id>.ogg.

Three things name a sound id, and each one is already in the assets tree:

  gamedata/spell_sfx.json    Sound.playSound ids in the spell scripts
  gamedata/anm_scripts.json  playLocalSound / playLocalRandomSound ids in
                             the anm runScript scripts (both written by
                             spell_sounds.py)
  anims/*/*/meta.json "sfx"  Sons<id> parts on anm frames (anm_render.py)

so this runs after the gamedata and anims stages of tools/make_assets.sh.
Without an anims tree it falls back to the Sons<id> action names of every
NPCs/ and Players/ anm, a few more ids than the exported sets play.
Ids that sounds.jar does not have are reported and skipped.

Usage:
  python3 tools/asset-import/sounds.py <sounds.jar> <assets_dir> \
      [animations.jar]
"""
import glob
import json
import os
import re
import sys
import zipfile


def from_gamedata(assets: str) -> set[int]:
    ids: set[int] = set()
    p = os.path.join(assets, "gamedata", "spell_sfx.json")
    if os.path.exists(p):
        for rows in json.load(open(p)).values():
            ids.update(int(i) for _, i in rows)
    p = os.path.join(assets, "gamedata", "anm_scripts.json")
    if os.path.exists(p):
        for v in json.load(open(p)).values():
            ids.update(int(s[0]) for s in v["s"])
    return ids


def from_anims(assets: str) -> tuple[set[int], int]:
    ids: set[int] = set()
    metas = glob.glob(os.path.join(assets, "anims", "*", "*", "meta.json"))
    for m in metas:
        for v in json.load(open(m)).get("sfx", {}).values():
            ids.update(int(x) for x in v)
    return ids, len(metas)


def from_anm_names(anim_jar: str) -> set[int]:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from anm_dump import parse_anm
    ids: set[int] = set()
    with zipfile.ZipFile(anim_jar) as z:
        for n in z.namelist():
            if not n.endswith(".anm") or not n.startswith(
                    ("animations/NPCs/", "animations/Players/")):
                continue
            try:
                anm = parse_anm(z.read(n))
            except Exception:
                continue
            for a in anm["actions"]:
                m = re.match(r"Sons(\d+)$", str(a.get("name") or ""))
                if m:
                    ids.add(int(m.group(1)))
    return ids


def main() -> None:
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    jar, assets = sys.argv[1], sys.argv[2]
    ids = from_gamedata(assets)
    anim_ids, metas = from_anims(assets)
    if metas:
        ids |= anim_ids
    elif len(sys.argv) == 4:
        print("no anims/ meta.json yet: using the Sons<id> anm names")
        ids |= from_anm_names(sys.argv[3])
    out = os.path.join(assets, "sounds")
    os.makedirs(out, exist_ok=True)
    copied, missing = 0, []
    with zipfile.ZipFile(jar) as z:
        have = set(z.namelist())
        for sid in sorted(ids):
            name = f"sounds/{sid}.ogg"
            if name not in have:
                missing.append(sid)
                continue
            with open(os.path.join(out, f"{sid}.ogg"), "wb") as f:
                f.write(z.read(name))
            copied += 1
    print(f"sounds: {len(ids)} ids, {copied} oggs, "
          f"{len(missing)} not in sounds.jar -> {out}")


if __name__ == "__main__":
    main()
