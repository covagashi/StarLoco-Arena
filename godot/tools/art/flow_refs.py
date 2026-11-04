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
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ANIMS = Path(__file__).resolve().parents[2] / "assets/anims"
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


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    ui = json.loads((ANIMS.parent / "i18n/ui_es.json").read_text())
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


if __name__ == "__main__":
    main()
