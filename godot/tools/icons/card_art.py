#!/usr/bin/env python3
"""S38b: the art inside the card template (owner's option B of
card_template_options.py; the frame, the ribbon and the name are drawn by
src/ui/card_face.gd). Writes, into assets/ui/cards/:
  family/<family>.webp the family's white pictogram (160 px), for the art
                       window of the cards without a piece and the medallion;
  coach/<card>.webp    a coach card's bare 3D piece (its icon without the
                       plate; a mark is its emblem on skin), 160 px;
  fighter/<card>.webp  the same for the fighter equipment cards.
Run from godot/ after equip_icons.tscn (both tables) and garment_icons.tscn:
    python3 tools/icons/card_art.py
"""
import json
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, "tools/icons")
import badge_icon_options as opt   # noqa: E402  the Pen and the glyphs
import card_template_options as tpl   # noqa: E402  the family pictograms
import equip_icons                     # noqa: E402  the bare pieces

PX = 160
OUT = "assets/ui/cards"
FAMILIES = ["coach", "consumable", "combat", "cosmetic", "fusion", "dofus", "arena", "other", "fighter"]


def pictogram(fam):
    n = PX * opt.S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    box = (n * .14, n * .14, n * .72)
    if fam == "other":        # a ticket
        p = opt.Pen(d, box, opt.WHITE, opt.S * 4)
        p.poly((.08, .26), (.92, .26), (.92, .42), (.84, .5), (.92, .58), (.92, .74), (.08, .74),
               (.08, .58), (.16, .5), (.08, .42))
    elif fam == "fighter":    # crossed swords
        opt.glyph(opt.Pen(d, box, opt.WHITE, opt.S * 5), 1, (0, 0, 0))
    else:
        tpl.pictogram(d, fam, box, opt.WHITE)
    return img.resize((PX, PX), Image.LANCZOS)


def fitted(p):
    f = PX * 0.94 / max(p.size)
    p = p.resize((max(1, int(p.width * f)), max(1, int(p.height * f))), Image.LANCZOS)
    out = Image.new("RGBA", (PX, PX), (0, 0, 0, 0))
    out.alpha_composite(p, ((PX - p.width) // 2, (PX - p.height) // 2))
    return out


def main():
    os.makedirs(f"{OUT}/family", exist_ok=True)
    for fam in FAMILIES:
        pictogram(fam).save(f"{OUT}/family/{fam}.webp", quality=90, method=6)
    pieces = json.load(open("art/equipment/pieces.json"))
    made = {}
    for table, src_dir in [("coach", "art/ui/out/equip_coach"), ("fighter", "art/ui/out/equip")]:
        os.makedirs(f"{OUT}/{table}", exist_ok=True)
        gj = os.path.join(src_dir, "garments.json")
        garments = set(json.load(open(gj))) if os.path.exists(gj) else set()
        n = 0
        for cid, piece in pieces[table].items():
            src = os.path.join(src_dir, f"{cid}.png")
            if not os.path.exists(src):
                continue
            if str(piece).startswith("mark_"):
                p = equip_icons.mark(str(piece)[5:])
            else:
                p = equip_icons.piece(src, cid in garments)
            if p is None:
                continue
            fitted(p).save(f"{OUT}/{table}/{cid}.webp", quality=88, method=6)
            n += 1
        made[table] = n
    print(f"{len(FAMILIES)} pictograms, {made['coach']} coach and {made['fighter']} fighter pieces in {OUT}")


if __name__ == "__main__":
    main()
