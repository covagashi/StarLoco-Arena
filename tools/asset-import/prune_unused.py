#!/usr/bin/env python3
"""prune_unused.py — drop the generated assets the Godot client never loads.

    prune_unused.py <assets_dir> <data_dist_dir> [--move-to DIR] [--delete] [--report FILE]

With neither --move-to nor --delete it only reports. make_assets.sh runs it as
its last stage (prune) with --delete; by hand, --move-to keeps what it takes
out, in the same layout, so a mistake costs a move back instead of a re-render.

What "used" means is read off the client code as it stands (the audit of
2026-10-25, sprints/S31): change the code that picks an asset and this file
has to follow. Each rule names the code it mirrors.

- anims: the sets and action folders fight_view.gd, lobby_panels.gd,
  lobby_screen.gd, level_up_panel.gd, creation_screen.gd and the FACE_*
  portraits (main.gd) can ask for, probed the way _anim_probe does
  (wire dir, mapped dir, then 1, 5, 3, 7; the 02 variants first for idle and
  walk). Summons: the looks of the type-300 templates the breed spells
  summon (1-9). KEPT ON PURPOSE although nothing plays them today: every
  AnimSort-* action and the animsort_* sets — fighter casts look them up by
  spell name and most names do not match yet (a naming bug, not dead art).
- mapgfx: only the fight view draws a map, and only arenas: the worlds whose
  server/data-dist/maps/fight/<id>.jar holds a non-empty .fmd (the arena
  registry's rule, gamedata.LoadFightMaps). tex/ keeps the atlases those
  worlds name.
- gui: GuiLayer still parses xml/theme/default.xml and misc/appSkin at boot;
  every retail XML dialog is replaced by a native panel. Images: card
  illustrations of cards.json/fightercards.json ids and the folders the
  native panels read.
- fx: the effect docs and textures spell_fx.json reaches (xps_fx.gd).
- sounds: spell_sfx.json, the anims' meta "sfx", and the anm_scripts entries
  the kept anims' meta "scr" name (anm_sprite).
- musics: island and fight (audio.gd).
"""
import json
import os
import shutil
import sys
import zipfile

# ---- anims -------------------------------------------------------------------

MAP = {0: 0, 1: 1, 2: 2, 3: 1, 4: 0, 5: 5, 6: 6, 7: 5}
COACH_SET = "coach_7000"
WEAPONS = ["219", "110", "112", "117", "108", "114", "111"]
EMOTES = ["AnimEmote-Applaudir", "AnimEmote-Lire", "AnimEmote-Declaration",
          "AnimEmote-Colere", "AnimEmote-Guitare", "AnimEmote-Pointer",
          "AnimEmote-Rire", "AnimEmote-Effraye", "AnimEmote-Defaite", "AnimEmote-Non"]
FIGHTER_FILES = ["-110", "-111", "-120", "-121", "-130", "-131", "-140", "-141",
                 "-150", "-151", "-160", "-161", "-170", "-171", "-180", "-181",
                 "-190", "-191", "-1100", "-1101", "-1110", "-1111", "-1120", "-1121"]
# the looks of summon templates 1-9, the only ones a breed spell summons
SUMMON_LOOKS = [8001, 8002, 8003, 8004, 8005, 8006, 8007, 8009, 8010]
PORTRAITS = {"portrait_nilo": ["1_AnimStatique"], "portrait_aldebran": ["1_AnimParle"],
             "portrait_demon1": ["0_AnimStatique"]}
ACC = {"é": "e", "è": "e", "ê": "e", "ë": "e", "à": "a", "â": "a", "î": "i", "ï": "i",
       "ô": "o", "ö": "o", "û": "u", "ù": "u", "ü": "u", "ç": "c", "É": "E", "È": "E",
       "À": "A", "Ç": "C", "Î": "I", "Ô": "O", "Û": "U"}


def slug(name):
    return "".join(ACC[c] if c in ACC else (c if c.isascii() and c.isalnum() else "")
                   for c in name)


def anims_keep(assets):
    root = os.path.join(assets, "anims")
    disk = {s: set(os.listdir(os.path.join(root, s))) for s in sorted(os.listdir(root))
            if os.path.isdir(os.path.join(root, s))}
    used = {}

    def has(s, a):
        return s in disk and a in disk[s] and os.path.exists(os.path.join(root, s, a, "meta.json"))

    def load(s, a):
        if has(s, a):
            used.setdefault(s, set()).add(a)
            return True
        return False

    def probe(s, wd, base, prefer02=False):
        bases = [base + "02", base + "-02", base] if prefer02 else [base, base + "02", base + "-02"]
        for d in (wd, MAP[wd], 1, 5, 3, 7):
            for b in bases:
                if load(s, f"{d}_{b}"):
                    return True
        return False

    def carried(base):
        return {"AnimHit": ["AnimHitPorte", base], "AnimTacle": ["AnimTaclePorte", base],
                "AnimMort": ["AnimPorte-Mort", base]}.get(base, [base])

    def combat_one(own, base, carrier, wd):
        sets = ([own] if own != COACH_SET else []) + [COACH_SET]
        for b in (carried(base) if carrier else [base]):
            for s in sets:
                if probe(s, wd, b):
                    return True
        return False

    def combat(own, base, carrier):
        for wd in range(8):
            combat_one(own, base, carrier, wd)

    def actor(own, breed, sex, carriers, cast_slugs):
        for carrier in carriers:
            for wd in range(8):  # idle (fight_view _load_fighter_anim)
                if carrier and probe(own, wd, "AnimStatiquePorte"):
                    continue
                if not probe(own, wd, "AnimStatique", prefer02=True):
                    load(f"coach_700{sex}", f"{MAP[wd]}_AnimStatique")
            for wd in range(8):  # walk
                if carrier and probe(own, wd, "AnimMarchePorte"):
                    continue
                probe(own, wd, "AnimMarche", prefer02=True)
            for b in ["AnimHit", "AnimTacle", "AnimSaut", "AnimCarte"] + EMOTES:
                combat(own, b, carrier)
            ko = "AnimPorte-KO-" if carrier else "AnimKO-"
            for wd in range(8):  # death, else the KO sequence
                if not combat_one(own, "AnimMort", carrier, wd):
                    if probe(own, wd, ko + "Debut"):
                        probe(own, wd, ko + "Boucle")
        if breed == 12:  # the only carry / throw spells (126, 127, 132)
            for b in ("Anim01Porte", "Anim02Porte", "Anim03Porte"):
                combat(own, b, False)
        for d in (1, 5):  # weapons (no probe)
            for fam in WEAPONS:
                if load(own, f"{d}_AnimStatique03-Debut-{fam}"):
                    load(own, f"{d}_AnimStatique03-{fam}")
                elif not load(own, f"{d}_AnimStatique03-{fam}"):
                    combat(own, "AnimCarte", False)
        sets = [own] + ([f"animsort_{breed * 10}"] if breed >= 1 else [])
        for sl in cast_slugs:  # casts
            for d in (1, 5):
                hit = False
                for s in sets:
                    for base in ([f"AnimSort-{sl}"] if sl else []) + ["AnimSort-Cast", "AnimCast"]:
                        if load(s, f"{d}_{base}"):
                            hit = True
                            break
                    if hit:
                        break
                if not hit:
                    combat(own, "AnimCast", False)

    spells = json.load(open(os.path.join(assets, "gamedata", "spells.json")))
    for i, f in enumerate(FIGHTER_FILES):
        breed, sex = i // 2 + 1, i % 2
        slugs = [slug(s["nfr"]) for s in spells.get(str(breed), [])]
        actor(f"fighter_{f}", breed, sex, [False, True] if breed == 12 else [False], slugs)
        for wd in range(8):  # the lobby's fighter preview
            load(f"fighter_{f}", f"{MAP[wd]}_AnimStatique")
    for look in SUMMON_LOOKS:
        actor(f"npc_{look}", -1, 0, [False], [""])
    for sex in (0, 1):  # coaches: fight actor, lobby, creation, level-up
        for wd in range(8):
            load(f"coach_700{sex}", f"{MAP[wd]}_AnimStatique")
            load(f"coach_700{sex}", f"{wd}_AnimStatique")
        load(f"coach_700{sex}", "1_AnimSaut")
    for s, acts in PORTRAITS.items():
        for a in acts:
            load(s, a)
    # kept on purpose: the cast art (see the module docstring)
    for s, acts in disk.items():
        if s.startswith("animsort_"):
            used.setdefault(s, set()).update(acts)
        elif s in used:
            used[s].update(a for a in acts if "AnimSort" in a and a[:1].isdigit())
    drop = []
    for s, acts in disk.items():
        if s not in used:
            drop.append(f"anims/{s}")
            continue
        drop += [f"anims/{s}/{a}" for a in sorted(acts - used[s])]
    return drop


# ---- mapgfx ------------------------------------------------------------------

def arena_ids(data_dist):
    ids = set()
    d = os.path.join(data_dist, "maps", "fight")
    for n in os.listdir(d):
        if not n.endswith(".jar") or not n[:-4].isdigit():
            continue
        with zipfile.ZipFile(os.path.join(d, n)) as z:
            for f in z.infolist():
                if f.filename.endswith(".fmd") and not f.is_dir():
                    if f.file_size > 0:
                        ids.add(int(n[:-4]))
                    break
    return ids


def mapgfx_drop(assets, data_dist):
    d = os.path.join(assets, "mapgfx")
    keep = arena_ids(data_dist)
    drop, tex = [], set()
    for n in sorted(os.listdir(d)):
        if not n.endswith(".json"):
            continue
        if n[:-5].isdigit() and int(n[:-5]) in keep:
            m = json.load(open(os.path.join(d, n)))
            tex |= {str(k) for k in m.get("tex", {})}
            tex |= {str(s["tex"]) for s in m.get("sprites", [])}
        else:
            drop.append(f"mapgfx/{n}")
    tdir = os.path.join(d, "tex")
    if os.path.isdir(tdir):
        drop += [f"mapgfx/tex/{n}" for n in sorted(os.listdir(tdir))
                 if n.endswith(".png") and n[:-4] not in tex]
    return drop


# ---- gui ---------------------------------------------------------------------

GUI_IMAGE_DIRS_KEPT = [
    "equipments/fighters/icons", "spells/icons", "breeds/fightTimeline",
    "theme/images/breeds", "achievement", "tokens",
]
GUI_IMAGE_FILES_KEPT = ["challenges/illustrations/29.png", "theme/images/closeCombatIcon.png"]
GUI_FONTS_KEPT = {"COPRGTB.TTF", "TAHOMA.TTF"}


def walk_files(base, rel=""):
    out = []
    for dp, _, fs in os.walk(os.path.join(base, rel)):
        for f in fs:
            out.append(os.path.relpath(os.path.join(dp, f), base))
    return out


def gui_drop(assets):
    g = os.path.join(assets, "gui")
    drop = []
    cards = set(json.load(open(os.path.join(assets, "gamedata", "cards.json"))))
    fcards = set(json.load(open(os.path.join(assets, "gamedata", "fightercards.json"))))
    for top in sorted(os.listdir(g)):
        p = os.path.join(g, top)
        if top in ("cursors",) or top == "i18n_de.json" or top == "index.json":
            drop.append(f"gui/{top}")
        elif top == "fonts":
            drop += [f"gui/fonts/{f}" for f in sorted(os.listdir(p)) if f not in GUI_FONTS_KEPT]
        elif top == "misc":
            drop += [f"gui/misc/{f}" for f in sorted(os.listdir(p)) if f != "appSkin"]
        elif top == "xml":
            drop += [f"gui/xml/{f}" for f in sorted(os.listdir(p)) if f != "theme"]
            th = os.path.join(p, "theme")
            if os.path.isdir(th):
                drop += [f"gui/xml/theme/{f}" for f in sorted(os.listdir(th)) if f != "default.xml"]
    imgs = os.path.join(g, "images")
    for rel in sorted(walk_files(imgs)):
        r = rel.replace(os.sep, "/")
        if any(r.startswith(k + "/") for k in GUI_IMAGE_DIRS_KEPT) or r in GUI_IMAGE_FILES_KEPT:
            continue
        stem = os.path.splitext(os.path.basename(r))[0]
        if r.startswith("equipments/coachs/illustrations/") and stem in (cards | fcards):
            continue
        if r.startswith("equipments/fighters/illustrations/") and stem in fcards:
            continue
        drop.append(f"gui/images/{r}")
    return collapse(drop, assets, "gui/images")


def collapse(paths, assets, under):
    """Whole directories instead of every file in them, for a readable list."""
    s = set(paths)
    out = [p for p in paths if not p.startswith(under + "/")]
    files = sorted(p for p in paths if p.startswith(under + "/"))
    dirs = {}
    for p in files:
        dirs.setdefault(os.path.dirname(p), []).append(p)
    taken = set()
    for d in sorted(dirs, key=len):
        if any(d == t or d.startswith(t + "/") for t in taken):
            continue
        allf = [f"{d}/{x}".replace(os.sep, "/") for x in
                (os.path.relpath(f, os.path.join(assets, d)) for f in walk_files(assets, d))]
        if allf and all(f in s for f in allf):
            taken.add(d)
    for p in files:
        if not any(p.startswith(t + "/") for t in taken):
            out.append(p)
    return out + sorted(taken)


# ---- fx, sounds, musics ------------------------------------------------------

def fx_drop(assets):
    gd = os.path.join(assets, "gamedata")
    fx = json.load(open(os.path.join(gd, "spell_fx.json")))
    idx = json.load(open(os.path.join(gd, "xps_index.json")))
    ids = set()

    def add(v):
        if isinstance(v, dict):
            for x in v.values():
                add(x)
        else:
            ids.add(int(v))
    for rows in fx.values():
        for r in rows:
            add(r[1])
    ids.discard(0)
    tex = set()
    for i in ids:
        meta = idx.get(str(i), {})
        p = os.path.join(gd, "xps", f"{i}.json")
        if os.path.exists(p):
            d = json.load(open(p))
            if d:
                meta = d
        t = int(meta.get("textureId", i))
        if t == 0 and meta.get("compactHeader"):
            t = i
        tex.add(t)
    drop = [f"gamedata/xps/{f}" for f in sorted(os.listdir(os.path.join(gd, "xps")))
            if f.endswith(".json") and f[:-5].isdigit() and int(f[:-5]) not in ids]
    drop += [f"fx/{f}" for f in sorted(os.listdir(os.path.join(assets, "fx")))
             if f.endswith(".png") and f[:-4].isdigit() and int(f[:-4]) not in tex]
    return drop, ids


def sounds_drop(assets, dropped):
    gd = os.path.join(assets, "gamedata")
    ids = set()
    for rows in json.load(open(os.path.join(gd, "spell_sfx.json"))).values():
        for r in rows:
            ids.add(int(r[1]))
    scr = json.load(open(os.path.join(gd, "anm_scripts.json")))
    root = os.path.join(assets, "anims")
    for s in os.listdir(root):
        if not os.path.isdir(os.path.join(root, s)):
            continue  # .gdignore
        for a in os.listdir(os.path.join(root, s)):
            rel = f"anims/{s}/{a}"
            if rel in dropped or f"anims/{s}" in dropped:
                continue
            m = os.path.join(root, s, a, "meta.json")
            if not os.path.exists(m):
                continue
            d = json.load(open(m))
            for v in d.get("sfx", {}).values():
                ids.update(int(i) for i in v)
            for v in d.get("scr", {}).values():
                for k in v:
                    for p in scr.get(str(int(k)), {}).get("s", []):
                        ids.add(int(p[0]))
    return [f"sounds/{f}" for f in sorted(os.listdir(os.path.join(assets, "sounds")))
            if f.endswith(".ogg") and f[:-4].isdigit() and int(f[:-4]) not in ids]


def musics_drop(assets):
    keep = {"island.ogg", "fight.ogg"}
    return [f"musics/{f}" for f in sorted(os.listdir(os.path.join(assets, "musics")))
            if f.endswith(".ogg") and f not in keep]


# ---- main --------------------------------------------------------------------

def size_of(p):
    if os.path.isdir(p):
        n = b = 0
        for dp, _, fs in os.walk(p):
            for f in fs:
                n += 1
                b += os.path.getsize(os.path.join(dp, f))
        return n, b
    return 1, os.path.getsize(p)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    assets, data_dist = argv[1], argv[2]
    move_to = argv[argv.index("--move-to") + 1] if "--move-to" in argv else ""
    delete = "--delete" in argv
    report = argv[argv.index("--report") + 1] if "--report" in argv else ""
    groups = {}
    groups["anims"] = anims_keep(assets)
    groups["mapgfx"] = mapgfx_drop(assets, data_dist)
    groups["gui"] = gui_drop(assets)
    groups["fx"], _ = fx_drop(assets)
    groups["sounds"] = sounds_drop(assets, set(groups["anims"]))
    groups["musics"] = musics_drop(assets)
    lines = []
    tot_n = tot_b = 0
    for g, paths in groups.items():
        n = b = 0
        for p in paths:
            pn, pb = size_of(os.path.join(assets, p))
            n += pn
            b += pb
        tot_n += n
        tot_b += b
        print(f"{g:7s} {len(paths):5d} paths  {n:6d} files  {b / 1048576:7.1f} MB")
        lines += paths
    print(f"total   {len(lines):5d} paths  {tot_n:6d} files  {tot_b / 1048576:7.1f} MB")
    if report:
        with open(report, "w") as f:
            f.write("\n".join(lines) + "\n")
    if not (move_to or delete):
        return 0
    for p in lines:
        src = os.path.join(assets, p)
        if not os.path.exists(src):
            continue
        if move_to:
            dst = os.path.join(move_to, p)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(src, dst)
        elif os.path.isdir(src):
            shutil.rmtree(src)
        else:
            os.remove(src)
    # xps_index.json keeps only the effects still on disk
    idx_path = os.path.join(assets, "gamedata", "xps_index.json")
    idx = json.load(open(idx_path))
    _, used_fx = fx_drop(assets)
    trimmed = {k: v for k, v in idx.items() if int(k) in used_fx}
    if len(trimmed) != len(idx):
        if move_to:
            os.makedirs(os.path.join(move_to, "gamedata"), exist_ok=True)
            shutil.copy(idx_path, os.path.join(move_to, "gamedata", "xps_index.json"))
        with open(idx_path, "w") as f:
            json.dump(trimmed, f, separators=(",", ":"))
    print("moved to " + move_to if move_to else "deleted")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
