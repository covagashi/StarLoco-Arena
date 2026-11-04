#!/usr/bin/env python3
"""Shape reference for the owner's Google Flow → Meshy pipeline (S35).

Retail sprites are SHAPE reference only (no-retail rule): the owner redraws
each figure in Flow (A-pose, several angles) and feeds that to Meshy; the
rig is done afterwards on the Meshy mesh.

    python3 -I godot/tools/art/flow_refs.py <out_dir>

One screen-sized page per figure, idle in every direction the retail has
(nearest-neighbour, flat background), from the git-ignored retail export
under godot/assets:
  clase-NN-m.png / clase-NN-f.png   the 24 fighters (5 views)
  coach-7000.png / coach-7001.png   the 2 coaches (5 views)
  invocacion-NNNN.png               the 9 summons (4 diagonal views)
and, as ideas for the owner (15 illustrations per page):
  accesorios/<slot>-N.png   fighter equipment by slot (weapon, pet, cloak,
                            hat, dofus)
  ropa-coach/NN-<slot>-N.png  the coach paper-doll clothes by slot
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ASSETS = Path(__file__).resolve().parents[2] / "assets"
ANIMS = ASSETS / "anims"
EQUIP = ASSETS / "gui/images/equipments"
PAGE = (1920, 1080)
BG = (240, 238, 232)
INK = (40, 36, 30)
FONT = "/usr/share/fonts/adwaita-sans-fonts/AdwaitaSans-Regular.ttf"
# retail direction prefix → what the view shows; 3, 4 and 7 are mirrors
VIEWS = [(2, "frente"), (1, "3/4 frente"), (0, "perfil"),
         (5, "3/4 espalda"), (6, "espalda")]
# summons only face the diagonals
SUMMON_VIEWS = [(1, "3/4 frente"), (3, "3/4 frente (izq.)"),
                (5, "3/4 espalda"), (7, "3/4 espalda (der.)")]
SUMMONS = [8001, 8002, 8003, 8004, 8005, 8006, 8007, 8009, 8010]
# fighter equipment slot (fightercards.json type)
SLOTS = {1: "armas", 2: "mascotas", 3: "capas", 4: "sombreros", 5: "dofus"}
# coach paper-doll slot (cards.json type)
COACH_SLOTS = {2: "faldas", 3: "peinados", 4: "marcas", 5: "brazaletes",
               6: "botas", 7: "hombreras", 8: "capas", 9: "pantalones",
               10: "torsos", 11: "cascos", 12: "armas"}


def font(size):
    return ImageFont.truetype(FONT, size)


def idle(set_dir, dr):
    """First idle frame of a direction, cropped to its alpha. Fighters use
    AnimStatique, most summons AnimStatique-02."""
    for action in ("%d_AnimStatique" % dr, "%d_AnimStatique-02" % dr):
        if (set_dir / action).is_dir():
            meta = json.loads((set_dir / action / "meta.json").read_text())
            x, y, w, h = meta["frames"][0]["r"]
            img = Image.open(set_dir / action / meta.get("atlas", "atlas.png"))
            img = img.convert("RGBA").crop((x, y, x + w, y + h))
            return img.crop(img.getbbox())
    raise FileNotFoundError("%s: no idle for direction %d" % (set_dir, dr))


def page(path, title, set_dir, views):
    sprites = [idle(set_dir, dr) for dr, _ in views]
    cw = (PAGE[0] - 80) // len(views)
    scale = min(min((PAGE[1] - 200) // s.height, (cw - 20) // s.width)
                for s in sprites)
    img = Image.new("RGB", PAGE, BG)
    d = ImageDraw.Draw(img)
    d.text((40, 24), title, fill=INK, font=font(40))
    for c, (spr, (_, caption)) in enumerate(zip(sprites, views)):
        big = spr.resize((spr.width * scale, spr.height * scale), Image.NEAREST)
        cx = 40 + c * cw + cw // 2
        img.paste(big, (cx - big.width // 2, PAGE[1] - 70 - big.height), big)
        d.text((cx, PAGE[1] - 55), caption, fill=INK, font=font(24), anchor="mt")
    img.save(path)


def grid_pages(dest, title, items):
    """items: [(illustration path, caption)], 15 per screen-sized page."""
    cw, ch, cols = 372, 300, 5
    for p in range(0, len(items), 15):
        img = Image.new("RGB", PAGE, BG)
        d = ImageDraw.Draw(img)
        d.text((40, 24), title, fill=INK, font=font(40))
        for i, (path, cap) in enumerate(items[p:p + 15]):
            x, y = 40 + (i % cols) * cw, 100 + (i // cols) * ch
            ill = Image.open(path).convert("RGBA")
            k = min(1.5, 328 / ill.width, 225 / ill.height)
            ill = ill.resize((int(ill.width * k), int(ill.height * k)), Image.LANCZOS)
            img.paste(ill, (x + (cw - ill.width) // 2, y), ill)
            d.text((x + cw // 2, y + ill.height + 8), cap, fill=INK,
                   font=font(20), anchor="mt")
        img.save("%s-%d.png" % (dest, p // 15 + 1))


def accessory_pages(out, content):
    """Fighter equipment; names are content table 1 (fightercards.gd)."""
    (out / "accesorios").mkdir(exist_ok=True)
    cards = json.loads((ASSETS / "gamedata/fightercards.json").read_text())
    for slot, name in SLOTS.items():
        ids = sorted(int(k) for k, c in cards.items() if c["type"] == slot)
        items = [(EQUIP / ("fighters/illustrations/%d.png" % cid), "%d · %s"
                  % (cid, content.get("content.1.%d" % cid, ""))) for cid in ids]
        grid_pages(out / "accesorios" / name, "Accesorios de luchador · %s (%d) — retail, solo idea"
                   % (name, len(items)), items)


def coach_clothes_pages(out, content):
    """Coach clothes; names are content table 23."""
    (out / "ropa-coach").mkdir(exist_ok=True)
    cards = json.loads((ASSETS / "gamedata/cards.json").read_text())
    for slot, name in COACH_SLOTS.items():
        items = []
        for cid in sorted(int(k) for k, c in cards.items() if c["type"] == slot):
            path = EQUIP / ("coachs/illustrations/%d.png" % cid)
            if path.exists():
                items.append((path, "%d · %s" % (cid, content.get(
                    "content.23.%d" % cid, cards[str(cid)].get("name", "")))))
        grid_pages(out / "ropa-coach" / ("%02d-%s" % (slot, name)),
                   "Ropa del coach · %s (%d) — retail, solo idea" % (name, len(items)), items)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    ui = json.loads((ASSETS / "i18n/ui_es.json").read_text())
    for cls in range(1, 13):
        for sex, tag, label in [(0, "m", "masculino"), (1, "f", "femenino")]:
            page(out / ("clase-%02d-%s.png" % (cls, tag)),
                 "Clase %d · %s · %s (retail, solo forma)"
                 % (cls, ui.get("breed.%d" % cls, "?"), label),
                 ANIMS / ("fighter_-1%d%d" % (cls, sex)), VIEWS)
    for c in (7000, 7001):
        page(out / ("coach-%d.png" % c), "Coach %d (retail, solo forma)" % c,
             ANIMS / ("coach_%d" % c), VIEWS)
    for sid in SUMMONS:
        page(out / ("invocacion-%d.png" % sid),
             "Invocación %d (retail, solo forma)" % sid,
             ANIMS / ("npc_%d" % sid), SUMMON_VIEWS)
    content = json.loads((ASSETS / "gui/i18n_es.json").read_text())
    accessory_pages(out, content)
    coach_clothes_pages(out, content)


if __name__ == "__main__":
    main()
