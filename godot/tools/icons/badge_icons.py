#!/usr/bin/env python3
"""S38b: the achievement and coin icons, the owner's option B of
badge_icon_options.py. Achievements: a medallion, its rim the grade's metal
(points / 5, 1..5) and its centre the colour of the category, with the
category's pictogram — one icon per category and grade, and a grey padlock
one while pending (assets/ui/achievements/<cat>_<grade>.png, pending.png;
the categories the data has no pictogram for take a star). Coins: a coin in
three-quarters, its face made wide so the mark still reads beside an amount
(assets/ui/tokens/<type>.png: tokens 1, 2, 3, 5 and the pesetas, 10).
Run from godot/: python3 tools/icons/badge_icons.py
"""
import json
import os

from PIL import Image, ImageDraw

import badge_icon_options as opt

S, N, INK, WHITE = opt.S, opt.N, opt.INK, opt.WHITE
ACH_PX, COIN_PX = 96, 64
STAR_CAT = (150, 156, 176)   # a category without a pictogram of its own


def medal(cat, grade, done):
    if cat in opt.CAT or not done:
        return opt.ach(cat if cat in opt.CAT else 5, grade, done, 'B')
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    metal = opt.GRADE[grade]
    d.ellipse((S * 2, S * 2, N - S * 2, N - S * 2), fill=INK)
    d.ellipse((S * 6, S * 6, N - S * 6, N - S * 6), fill=metal)
    d.arc((S * 9, S * 9, N - S * 9, N - S * 9), 200, 320, fill=opt.lighter(metal, .5), width=S * 3)
    d.ellipse((S * 17, S * 17, N - S * 17, N - S * 17), fill=INK)
    d.ellipse((S * 19, S * 19, N - S * 19, N - S * 19), fill=STAR_CAT)
    opt.glyph(opt.Pen(d, (N * .3, N * .3, N * .4), WHITE, S * 4), 'star', STAR_CAT)
    return img


def coin(t):
    """Option B, with a taller face and a thinner edge than on the sheet."""
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = opt.TOKEN[t][1]
    top, h, edge = N * .1, N * .68, N * .12
    d.ellipse((S * 2, top + edge, N - S * 2, top + h + edge), fill=INK)
    d.rectangle((S * 2, top + h / 2, N - S * 2, top + h / 2 + edge), fill=INK)
    d.ellipse((S * 6, top + edge, N - S * 6, top + h + edge - S * 4), fill=opt.darker(col, .3))
    d.rectangle((S * 6, top + h / 2, N - S * 6, top + h / 2 + edge - S * 2), fill=opt.darker(col, .3))
    d.ellipse((S * 2, top - S * 2, N - S * 2, top + h + S * 2), fill=INK)
    d.ellipse((S * 6, top + S * 2, N - S * 6, top + h - S * 2), fill=col)
    d.arc((S * 14, top + S * 6, N - S * 14, top + h - S * 8), 190, 330, fill=opt.lighter(col, .5), width=S * 3)
    face = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    opt.glyph(opt.Pen(ImageDraw.Draw(face), (N * .27, N * .27, N * .46), WHITE, S * 6),
              'peseta' if t == 10 else 'star', col)
    face = face.resize((N, int(N * .72)), Image.LANCZOS)   # the mark lies on the face
    img.alpha_composite(face, (0, int(top + h / 2 - face.height / 2)))
    return img


def main():
    ach = json.load(open('assets/gamedata/npcdialogs.json'))['achievements']
    cats = sorted({int(a['cat']) for a in ach.values()})
    out = 'assets/ui/achievements'
    os.makedirs(out, exist_ok=True)
    for cat in cats:
        for g in range(1, 6):
            medal(cat, g, True).resize((ACH_PX, ACH_PX), Image.LANCZOS).save(f'{out}/{cat}_{g}.png')
    medal(5, 1, False).resize((ACH_PX, ACH_PX), Image.LANCZOS).save(f'{out}/pending.png')
    print(f'{len(cats) * 5 + 1} achievement icons in {out} (categories {cats})')
    out = 'assets/ui/tokens'
    os.makedirs(out, exist_ok=True)
    for t in opt.TOKEN:
        coin(t).resize((COIN_PX, COIN_PX), Image.LANCZOS).save(f'{out}/{t}.png')
    print(f'{len(opt.TOKEN)} coins in {out}')


if __name__ == '__main__':
    main()
