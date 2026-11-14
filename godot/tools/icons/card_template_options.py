"""S38b: the card template by family and rarity — an option sheet.
Families (lobby_panels.gd INV_KINDS, plus the arenas) get a colour and a
pictogram; the rarity is the card's rank (cards.json "rank", 0..10) in the
four tiers the game tells the player about (black, copper, silver, gold:
0-2, 3-5, 6-8, 9-10). Coach gear shows its own 3D icon
(assets/ui/equip_coach), the rest the family's pictogram. Three treatments,
at the inventory tile's size (150 x 180) and the detail's.
Run from godot/: python3 tools/icons/card_template_options.py out.png
"""
import json
import math
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "tools/icons")
import badge_icon_options as opt   # noqa: E402  the Pen and the pictograms
import equip_icons                  # noqa: E402  the bare 3D pieces, unplated

S = 4
INK = (28, 32, 48)
WHITE = (255, 255, 255)
PAPER = (243, 244, 248)
FONT = "assets/ui/fonts/SairaCondensed-ExtraBold.ttf"
BODY = "assets/ui/fonts/Nunito-Variable.ttf"
# family → (label, colour)
FAMILY = {"coach": ("Equipo del coach", (47, 116, 240)), "consumable": ("Consumible", (48, 168, 118)),
          "combat": ("Regla de combate", (255, 77, 109)), "cosmetic": ("Cosmético", (176, 127, 208)),
          "fusion": ("Fusión", (34, 181, 201)), "dofus": ("Objeto DOFUS", (217, 154, 43)),
          "arena": ("Arena", (106, 168, 79))}
# tier → (label, base, light, dark)
TIER = [("Negra", (52, 56, 70), (120, 126, 146), (22, 24, 32)),
        ("Cobre", (184, 115, 58), (232, 170, 110), (110, 62, 26)),
        ("Plata", (160, 170, 188), (232, 238, 248), (98, 108, 126)),
        ("Oro", (226, 172, 46), (255, 230, 140), (150, 102, 12))]


def tier(rank):
    return 0 if rank <= 2 else 1 if rank <= 5 else 2 if rank <= 8 else 3


def _sparkle(p, cx, cy, r, waist):
    """A four-point sparkle with pinched sides."""
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else waist
        a = math.radians(i * 45 - 90)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    p.poly(*pts)


def pictogram(d, family, box, col, back=(0, 0, 0, 0)):
    """The family's pictogram in box (x, y, side): a white silhouette with
    its details carved out in `back` (transparent for the card assets, the
    colour under it when drawn straight onto a plate). One stroke logic for
    the set: a solid shape that still reads at 18 px, carved lines of the
    same weight that show from 60 px up."""
    p = opt.Pen(d, box, col, S * 4)       # the white
    q = opt.Pen(d, box, back, S * 4)      # the carving
    if family == "coach":           # a jersey: round neck, short sleeves
        p.poly((.3, .1), (.4, .1), (.5, .2), (.6, .1), (.7, .1), (.94, .28), (.84, .46), (.74, .4),
               (.74, .9), (.26, .9), (.26, .4), (.16, .46), (.06, .28))
        q.d.ellipse([q.P(.38, .0), q.P(.62, .17)], fill=back)
        q.line((.26, .4), (.26, .52), k=1.0)
        q.line((.74, .4), (.74, .52), k=1.0)
    elif family == "consumable":    # a round potion flask with a cork
        p.rect(.5, .1, .18, .1, 0)
        p.rect(.5, .17, .3, .07, 0)
        p.rect(.5, .3, .2, .22, 0)
        p.disc(.5, .64, .31)
        q.disc(.6, .55, .05)
        q.disc(.67, .68, .035)
    elif family == "combat":        # a rule scroll, rolled at top and bottom
        p.rect(.5, .5, .6, .64, 0)
        for y in (.17, .83):
            p.rect(.5, y, .8, .17, 0)
            p.disc(.1, y, .085)
            p.disc(.9, y, .085)
            q.disc(.1, y, .035)
            q.disc(.9, y, .035)
        for y, x1 in ((.4, .66), (.5, .66), (.6, .56)):
            q.line((.34, y), (x1, y), k=1.0)
    elif family == "cosmetic":      # sparkles
        _sparkle(p, .42, .56, .44, .11)
        _sparkle(p, .8, .2, .17, .045)
    elif family == "fusion":        # a cut gem: table, crown, pavilion
        p.poly((.24, .22), (.76, .22), (.95, .44), (.5, .92), (.05, .44))
        q.line((.05, .44), (.95, .44), k=1.0)
        q.line((.24, .22), (.35, .44), (.5, .92), k=1.0)
        q.line((.76, .22), (.65, .44), (.5, .92), k=1.0)
    elif family == "dofus":         # a dragon egg: a girdle band, a shine
        pts = []
        for i in range(72):
            t = math.radians(i * 5)
            pts.append((.5 + (.3 + .06 * math.sin(t)) * math.cos(t), .53 + .4 * math.sin(t)))
        p.poly(*pts)
        q.d.arc([q.P(.14, .4), q.P(.86, .74)], 0, 180, fill=back, width=int(q.w * 1.0))
        q.d.arc([q.P(.2, .48), q.P(.8, .8)], 0, 180, fill=back, width=int(q.w * 1.0))
        q.d.arc([q.P(.27, .22), q.P(.6, .6)], 200, 260, fill=back, width=int(q.w * 1.1))
    elif family == "arena":         # a floating isometric field with a pennant
        L, T, R, B = (.06, .62), (.5, .42), (.94, .62), (.5, .82)
        p.poly(L, T, R, B)
        p.poly((.14, .66), (.86, .66), (.72, .84), (.6, .88), (.5, 1.0), (.4, .88), (.28, .84))
        q.line(L, B, R, k=.9)
        e1, e2 = (T[0] - L[0], T[1] - L[1]), (B[0] - L[0], B[1] - L[1])
        for a in (1 / 3, 2 / 3):
            q.line((L[0] + a * e1[0], L[1] + a * e1[1]), (L[0] + a * e1[0] + e2[0], L[1] + a * e1[1] + e2[1]), k=.8)
            q.line((L[0] + a * e2[0], L[1] + a * e2[1]), (L[0] + a * e2[0] + e1[0], L[1] + a * e2[1] + e1[1]), k=.8)
        p.line((.5, .44), (.5, .08), k=1.1)
        p.poly((.5, .06), (.8, .16), (.5, .26))
    elif family == "other":         # a ticket: side notches, a perforation
        d.rounded_rectangle([p.P(.06, .3), p.P(.94, .7)], radius=int(p.s * .06), fill=col)
        q.disc(.5, .3, .07)
        q.disc(.5, .7, .07)
        for y in (.44, .54):
            q.line((.5, y), (.5, y + .05), k=.9)
        q.line((.18, .44), (.38, .44), k=.9)
        q.line((.18, .56), (.32, .56), k=.9)
    elif family == "fighter":       # crossed swords
        opt.glyph(opt.Pen(d, box, col, S * 5), 1, back)
    elif family == "hair":          # a haircut: a bob with a fringe over the face
        p.disc(.5, .46, .36)
        p.rect(.2, .66, .12, .42, 0)
        p.rect(.8, .66, .12, .42, 0)
        p.disc(.2, .87, .06)
        p.disc(.8, .87, .06)
        q.d.ellipse([q.P(.28, .36), q.P(.72, .9)], fill=back)
        p.poly((.26, .3), (.74, .3), (.74, .46), (.67, .58), (.59, .45), (.51, .6), (.43, .46), (.35, .58),
               (.26, .46))
        q.d.arc([q.P(.2, .16), q.P(.6, .56)], 200, 255, fill=back, width=int(q.w * 1.0))


def art(card_id, family, size, colour):
    """What sits in the art window: the coach card's bare 3D piece (the
    renders equip_icons.py plates, without the plate), or the pictogram."""
    img = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    if family == "coach":
        src = f"art/ui/out/equip_coach/{card_id}.png"
        garments = set(json.load(open("art/ui/out/equip_coach/garments.json")))
        p = equip_icons.piece(src, card_id in garments)
        f = size * 0.92 / max(p.size)
        p = p.resize((max(1, int(p.width * f)), max(1, int(p.height * f))), Image.LANCZOS)
        out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        out.alpha_composite(p, ((size - p.width) // 2, (size - p.height) // 2))
        return out
    pictogram(ImageDraw.Draw(img), family, (size * S * .14, size * S * .14, size * S * .72), WHITE)
    return img.resize((size, size), Image.LANCZOS)


def fit(d, text, font_path, size, width):
    """The largest font (down to 60 %) that fits the text on one line."""
    for k in range(size, int(size * 0.6), -1):
        f = ImageFont.truetype(font_path, k * S)
        if d.textlength(text, font=f) <= width:
            return f
    return ImageFont.truetype(font_path, int(size * 0.6) * S)


def metal(d, xy, t, width):
    """A frame in the tier's metal: dark rim, base, a lit top-left edge."""
    name, base, light, dark = TIER[t]
    x0, y0, x1, y1 = xy
    d.rounded_rectangle(xy, radius=S * 5, fill=dark)
    d.rounded_rectangle((x0 + S, y0 + S, x1 - S, y1 - S), radius=S * 4, fill=base)
    d.line([(x0 + S * 3, y1 - S * 6), (x0 + S * 3, y0 + S * 3), (x1 - S * 6, y0 + S * 3)], fill=light, width=S * 2)


def card(c, style, W=150, H=180):
    w, h = W * S, H * S
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fam, colour = c["family"], FAMILY[c["family"]][1]
    t = tier(c["rank"])
    name_font = ImageFont.truetype(FONT, 15 * S)
    small = ImageFont.truetype(BODY, 11 * S)
    if style == "A":    # the pale plate we have, a family tag and a rarity rule
        d.rectangle((0, 0, w, h), fill=PAPER, outline=(INK + (50,)), width=S)
        d.rectangle((0, 0, w, S * 4), fill=TIER[t][1])
        k = S * 8
        d.polygon([(S * 6 + k, S * 10), (S * 46, S * 10), (S * 46 - k, S * 34), (S * 6, S * 34)], fill=colour)
        pictogram(d, fam, (S * 18, S * 11, S * 22), WHITE, colour)
        a = art(c["id"], fam, 96, colour)
        bg = Image.new("RGBA", (96 * S, 96 * S), (0, 0, 0, 0))
        ImageDraw.Draw(bg).polygon([(S * 12, 0), (96 * S, 0), (84 * S, 96 * S), (0, 96 * S)],
                                   fill=(opt.lighter(colour, .7) if fam == "coach" else colour) + (255,))
        img.alpha_composite(bg, ((w - 96 * S) // 2, S * 26))
        img.alpha_composite(a.resize((96 * S, 96 * S)), ((w - 96 * S) // 2, S * 26))
        d.text((w // 2, h - S * 34), c["name"], font=fit(d, c["name"], FONT, 15, w - S * 14), fill=INK, anchor="mm")
        d.text((w // 2, h - S * 14), TIER[t][0].upper(), font=small, fill=TIER[t][3], anchor="mm")
    elif style == "B":  # a gacha card: the tier's metal frame, the family inside
        metal(d, (0, 0, w, h), t, S * 6)
        inner = (S * 7, S * 7, w - S * 7, h - S * 7)
        d.rounded_rectangle(inner, radius=S * 3, fill=opt.lighter(colour, .55))
        d.rounded_rectangle((inner[0], inner[1], inner[2], inner[1] + S * 104), radius=S * 3, fill=colour)
        # a soft light behind the art
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse((w / 2 - S * 50, S * 14, w / 2 + S * 50, S * 106), fill=opt.lighter(colour, .35) + (255,))
        img.alpha_composite(glow)
        img.alpha_composite(art(c["id"], fam, 92, colour).resize((92 * S, 92 * S)), ((w - 92 * S) // 2, S * 12))
        # the name on an ink ribbon across the bottom
        d.polygon([(S * 4, S * 116), (w - S * 4, S * 116), (w - S * 10, S * 146), (S * 10, S * 146)], fill=INK)
        d.text((w // 2, S * 131), c["name"].upper(), font=fit(d, c["name"].upper(), FONT, 13, w - S * 26), fill=WHITE, anchor="mm")
        # the family medallion, top left, and the tier's diamonds at the foot
        d.ellipse((S * 2, S * 2, S * 32, S * 32), fill=INK)
        d.ellipse((S * 4, S * 4, S * 30, S * 30), fill=colour)
        pictogram(d, fam, (S * 8, S * 8, S * 18), WHITE, colour)
        for i in range(t + 1):
            cx = w / 2 + (i - t / 2) * S * 13
            d.polygon([(cx, S * 153), (cx + S * 5, S * 159), (cx, S * 165), (cx - S * 5, S * 159)], fill=TIER[t][2], outline=TIER[t][3])
    else:               # a trading card: white, a family header, a rarity foot
        d.rounded_rectangle((0, 0, w, h), radius=S * 4, fill=WHITE, outline=INK, width=S * 2)
        d.rectangle((S * 2, S * 2, w - S * 2, S * 26), fill=colour)
        pictogram(d, fam, (S * 6, S * 5, S * 18), WHITE, colour)
        d.text((S * 30, S * 14), FAMILY[fam][0].upper(), font=ImageFont.truetype(FONT, 11 * S), fill=WHITE, anchor="lm")
        d.rectangle((S * 10, S * 32, w - S * 10, S * 120), fill=opt.lighter(colour, .82), outline=opt.lighter(colour, .4), width=S)
        img.alpha_composite(art(c["id"], fam, 84, colour if fam != "coach" else colour).resize((84 * S, 84 * S)), ((w - 84 * S) // 2, S * 34))
        if fam != "coach":   # the pictogram in the family colour on the pale window
            win = Image.new("RGBA", (84 * S, 84 * S), (0, 0, 0, 0))
            pictogram(ImageDraw.Draw(win), fam, (84 * S * .14, 84 * S * .14, 84 * S * .72), colour, opt.lighter(colour, .82))
            img.alpha_composite(win, ((w - 84 * S) // 2, S * 34))
        d.text((w // 2, S * 136), c["name"], font=fit(d, c["name"], FONT, 15, w - S * 14), fill=INK, anchor="mm")
        metal(d, (S * 2, h - S * 26, w - S * 2, h - S * 2), t, S * 3)
        d.text((w // 2, h - S * 14), TIER[t][0].upper(), font=small, fill=WHITE if t in (0, 1) else INK, anchor="mm")
    return img.resize((W, H), Image.LANCZOS)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "card_options.png"
    cards = json.load(open("assets/gamedata/cards.json"))
    picks = [("185", "coach"), ("111", "coach"), ("305", "consumable"), ("1008", "combat"),
             ("202", "arena"), ("943", "fusion"), ("1000", "dofus")]
    sample = [{"id": i, "family": f, "rank": int(cards[i].get("rank", 0)), "name": cards[i]["name"]} for i, f in picks]
    W, H = 1280, 720
    sheet = Image.new("RGBA", (W, H), (233, 236, 241, 255))
    d = ImageDraw.Draw(sheet)
    d.text((24, 14), "S38b · PLANTILLA DE CARTA POR FAMILIA Y RAREZA — OPCIONES", font=ImageFont.truetype(FONT, 26), fill=INK)
    labels = {"A": "A · la placa clara de hoy, etiqueta de familia y regla de rareza",
              "B": "B · carta gacha: marco del metal de la rareza, la familia dentro",
              "C": "C · carta coleccionable: cabecera de familia, pie de rareza"}
    small = ImageFont.truetype(BODY, 12)
    for r, st in enumerate("ABC"):
        y = 54 + r * 220
        d.text((24, y), labels[st], font=ImageFont.truetype(FONT, 18), fill=INK)
        for i, c in enumerate(sample):
            x = 24 + i * 176
            sheet.alpha_composite(card(c, st), (x, y + 28))
        d.text((24 + 7 * 176 - 30, y + 60), "", font=small, fill=INK)
    sheet.convert("RGB").save(out)
    print(out, [(c["name"], TIER[tier(c["rank"])][0]) for c in sample])


if __name__ == "__main__":
    main()
