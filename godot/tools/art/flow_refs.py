#!/usr/bin/env python3
"""Reference pack for the owner's Google Flow → Meshy pipeline (S35).

Retail sprites are SHAPE reference only (no-retail rule): the owner redraws
each class in Flow (A-pose, several angles) and feeds that to Meshy.

    python3 -I godot/tools/art/flow_refs.py <out_dir>

Writes, from the git-ignored retail export under godot/assets:
  clases/clase-NN.png      one screen-sized page per class: male above,
                           female below, idle in 5 directions (×4, nearest)
  vistas/clase-NN-<m|f>/   each direction alone (×6, flat background), to
                           upload to Flow as an image reference
  accesorios/<slot>-N.png  fighter equipment illustrations by slot, 15 per
                           page (weapon, pet, cloak, hat, dofus)
  accesorios/armas-en-mano.png  class 1 in each armed stance (the retail
                           draws the weapon as a separate sprite: pose only)
  ropa-coach/<slot>-N.png  the coach paper-doll clothes by slot
  otros/                   the 2 coaches and the 9 summons, same layout
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GODOT = Path(__file__).resolve().parents[2]
ASSETS = GODOT / "assets"
ANIMS = ASSETS / "anims"
EQUIP = ASSETS / "gui/images/equipments/fighters/illustrations"
COACH_EQUIP = ASSETS / "gui/images/equipments/coachs/illustrations"
PAGE = (1920, 1080)
BG = (240, 238, 232)
INK = (40, 36, 30)
FONT = "/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf"
# retail direction prefix → what the view shows; 3, 4 and 7 are mirrors
VIEWS = [(2, "frente"), (1, "3/4 frente"), (0, "perfil"),
         (5, "3/4 espalda"), (6, "espalda")]
SEXES = [(0, "m", "masculino"), (1, "f", "femenino")]
# summons only face the diagonals
SUMMON_VIEWS = [(1, "3/4 frente"), (3, "3/4 frente (izq.)"),
                (5, "3/4 espalda"), (7, "3/4 espalda (der.)")]
SUMMONS = [8001, 8002, 8003, 8004, 8005, 8006, 8007, 8009, 8010]
# armed-stance family (fight_view WEAPON_FAMILY) → weapon kind and its cards'
# use script; 219 is bare fists
STANCES = [(110, "espada", 8001), (112, "dagas", 8002), (117, "arco", 8003),
           (108, "bastón", 8004), (114, "martillo", 8006),
           (111, "pala / hacha", 8007), (219, "puños", None)]
SLOTS = {1: "armas", 2: "mascotas", 3: "capas", 4: "sombreros", 5: "dofus"}
# coach paper-doll slots (cards.json type)
COACH_SLOTS = {2: "faldas", 3: "peinados", 4: "marcas", 5: "brazaletes",
               6: "botas", 7: "hombreras", 8: "capas", 9: "pantalones",
               10: "torsos", 11: "cascos", 12: "armas"}


def font(size):
    return ImageFont.truetype(FONT, size)


def idle_action(set_dir, dr):
    """The idle action of a direction: fighters use AnimStatique, most
    summons AnimStatique-02."""
    for name in ("%d_AnimStatique" % dr, "%d_AnimStatique-02" % dr):
        if (set_dir / name).is_dir():
            return name
    return None


def frame0(set_dir, action):
    """First frame of an action, cropped to its alpha."""
    meta = json.loads((set_dir / action / "meta.json").read_text())
    x, y, w, h = meta["frames"][0]["r"]
    img = Image.open(set_dir / action / meta.get("atlas", "atlas.png"))
    img = img.convert("RGBA").crop((x, y, x + w, y + h))
    return img.crop(img.getbbox())


def flat(img, scale, pad):
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    out = Image.new("RGB", (big.width + 2 * pad, big.height + 2 * pad), BG)
    out.paste(big, (pad, pad), big)
    return out


def class_pages(out, names):
    for cls in range(1, 13):
        page = Image.new("RGB", PAGE, BG)
        d = ImageDraw.Draw(page)
        d.text((40, 24), "Clase %d · %s (retail, solo forma)"
               % (cls, names.get(cls, "?")), fill=INK, font=font(40))
        for row, (sex, tag, label) in enumerate(SEXES):
            set_dir = ANIMS / ("fighter_-1%d%d" % (cls, sex))
            top = 100 + row * 490
            d.text((40, top), label, fill=INK, font=font(28))
            vdir = out / "vistas" / ("clase-%02d-%s" % (cls, tag))
            vdir.mkdir(parents=True, exist_ok=True)
            for col, (dr, view) in enumerate(VIEWS):
                spr = frame0(set_dir, "%d_AnimStatique" % dr)
                big = spr.resize((spr.width * 4, spr.height * 4), Image.NEAREST)
                cx = 40 + col * 372 + 186
                page.paste(big, (cx - big.width // 2, top + 440 - big.height), big)
                d.text((cx, top + 450), view, fill=INK, font=font(22), anchor="mt")
                flat(spr, 6, 60).save(vdir / ("%d-%s.png"
                                       % (col + 1, view.replace("/", "").replace(" ", "-"))))
        page.save(out / "clases" / ("clase-%02d.png" % cls))


def row_page(path, title, rows, scale=4):
    """rows: [(label, set_dir, [(action, caption)])], one row per figure."""
    page = Image.new("RGB", PAGE, BG)
    d = ImageDraw.Draw(page)
    d.text((40, 24), title, fill=INK, font=font(40))
    rh = (PAGE[1] - 100) // len(rows)
    for r, (label, set_dir, views) in enumerate(rows):
        top = 100 + r * rh
        d.text((40, top), label, fill=INK, font=font(28))
        cw = (PAGE[0] - 80) // len(views)
        for c, (action, caption) in enumerate(views):
            if action is None:
                continue
            spr = frame0(set_dir, action)
            s_ = min(scale, (rh - 130) // spr.height, (cw - 20) // spr.width)
            big = spr.resize((spr.width * s_, spr.height * s_), Image.NEAREST)
            cx = 40 + c * cw + cw // 2
            page.paste(big, (cx - big.width // 2, top + rh - 90 - big.height), big)
            d.multiline_text((cx, top + rh - 80), caption, fill=INK, font=font(22),
                             anchor="ma", align="center")
    page.save(path)


def other_pages(out):
    (out / "otros").mkdir(parents=True, exist_ok=True)
    rows = [("coach %d" % c, ANIMS / ("coach_%d" % c),
             [("%d_AnimStatique" % dr, v) for dr, v in VIEWS]) for c in (7000, 7001)]
    row_page(out / "otros" / "coaches.png", "Coaches (retail, solo forma)", rows)
    for p in range(0, len(SUMMONS), 3):
        rows = []
        for sid in SUMMONS[p:p + 3]:
            sd = ANIMS / ("npc_%d" % sid)
            rows.append(("invocación %d" % sid, sd,
                         [(idle_action(sd, dr), v) for dr, v in SUMMON_VIEWS]))
        row_page(out / "otros" / ("invocaciones-%d.png" % (p // 3 + 1)),
                 "Invocaciones (retail, solo forma)", rows)


def stance_page(out, cards):
    by_script = {}
    for cid, c in cards.items():
        if c["type"] == 1:
            by_script.setdefault(c.get("script"), []).append(int(cid))
    rows = []
    for sex, _, label in SEXES:
        sd = ANIMS / ("fighter_-11%d" % sex)
        views = []
        for fam, kind, script in STANCES:
            ids = sorted(by_script.get(script, []))
            cap = kind + ("\n" + ", ".join(map(str, ids)) if ids else "")
            views.append(("1_AnimStatique03-%d" % fam, cap))
        rows.append(("clase 1, " + label, sd, views))
    row_page(out / "accesorios" / "armas-en-mano.png",
             "Postura con arma (retail; el arma va en otro sprite) · debajo, sus cartas", rows)


def grid_pages(dest, title, items):
    """items: [(illustration path, caption)], 15 per screen-sized page."""
    cw, ch, cols = 372, 300, 5
    for p in range(0, len(items), 15):
        page = Image.new("RGB", PAGE, BG)
        d = ImageDraw.Draw(page)
        d.text((40, 24), title, fill=INK, font=font(40))
        for i, (path, cap) in enumerate(items[p:p + 15]):
            x, y = 40 + (i % cols) * cw, 100 + (i // cols) * ch
            img = Image.open(path).convert("RGBA")
            k = min(1.5, 328 / img.width, 225 / img.height)
            img = img.resize((int(img.width * k), int(img.height * k)), Image.LANCZOS)
            page.paste(img, (x + (cw - img.width) // 2, y), img)
            d.text((x + cw // 2, y + img.height + 8), cap, fill=INK,
                   font=font(20), anchor="mt")
        page.save("%s-%d.png" % (dest, p // 15 + 1))


def accessory_pages(out, content):
    cards = json.loads((ASSETS / "gamedata/fightercards.json").read_text())
    by_slot = {}
    for cid, c in cards.items():
        by_slot.setdefault(c["type"], []).append(int(cid))
    for slot, ids in sorted(by_slot.items()):
        name = SLOTS.get(slot, str(slot))
        items = [(EQUIP / ("%d.png" % cid), "%d · %s"
                  % (cid, content.get("content.1.%d" % cid, ""))) for cid in sorted(ids)]
        grid_pages(out / "accesorios" / name, "Accesorios de luchador · %s (%d) — retail, solo idea"
                   % (name, len(ids)), items)


def coach_clothes_pages(out, content):
    cards = json.loads((ASSETS / "gamedata/cards.json").read_text())
    (out / "ropa-coach").mkdir(parents=True, exist_ok=True)
    for slot, name in COACH_SLOTS.items():
        items = []
        for cid in sorted(int(k) for k, c in cards.items() if c["type"] == slot):
            path = COACH_EQUIP / ("%d.png" % cid)
            if path.exists():
                items.append((path, "%d · %s" % (cid, content.get(
                    "content.23.%d" % cid, cards[str(cid)].get("name", "")))))
        grid_pages(out / "ropa-coach" / ("%02d-%s" % (slot, name)),
                   "Ropa del coach · %s (%d) — retail, solo idea" % (name, len(items)), items)


def main():
    out = Path(sys.argv[1])
    for sub in ("clases", "vistas", "accesorios"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    ui = json.loads((ASSETS / "i18n/ui_es.json").read_text())
    names = {i: ui.get("breed.%d" % i, "?") for i in range(1, 13)}
    content = json.loads((ASSETS / "gui/i18n_es.json").read_text())
    class_pages(out, names)
    accessory_pages(out, content)
    coach_clothes_pages(out, content)
    stance_page(out, json.loads((ASSETS / "gamedata/fightercards.json").read_text()))
    other_pages(out)


if __name__ == "__main__":
    main()
