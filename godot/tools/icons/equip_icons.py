#!/usr/bin/env python3
"""S38: the equipment icons. Takes the bare renders of our 3D pieces
(tools/icons/equip_icons.tscn → art/ui/out/equip/<card>.png) and sets each
on the style B plate the spells use (slanted, an ink rule on top): a pale
tint of its slot (weapon, pet, cape, hat, dofus) so the piece's own colours
read, the piece fitted to the plate — long weapons laid on the diagonal.
Writes the finished icon (96 px) to assets/ui/equip/.
Run from godot/ after the .tscn: python3 tools/icons/equip_icons.py [--coach] [--sheet out.png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

PX = 96
S = 4
N = PX * S
INK = (28, 32, 48)
# fightercards.json type → plate tint (style B, pale so the piece reads)
TYPE = {1: (214, 220, 232), 2: (214, 238, 226), 3: (240, 222, 226), 4: (240, 230, 208), 5: (226, 220, 244)}
COACH = (232, 234, 240)


def piece(src, keep=False):
    im = Image.open(src).convert('RGBA')
    if keep:   # a garment on the body: its square is already the crop
        return im
    # the toon outline leaves a pale fringe on a clear background
    r, g, b, a = im.split()
    a = a.point(lambda v: 0 if v < 170 else 255)
    im.putalpha(a)
    box = im.getbbox()
    if box is None:
        return None
    im = im.crop(box)
    if im.height > im.width * 2.2:   # a long weapon: on the diagonal
        im = im.rotate(-42, resample=Image.BICUBIC, expand=True)
        im = im.crop(im.getbbox())
    return im


def icon(src, tint, keep=False):
    p = piece(src, keep)
    plate = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(plate)
    k = int(N * 0.12)
    d.polygon([(k, 0), (N, 0), (N - k, N), (0, N)], fill=tint + (255,))
    d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 5)
    if p is not None:
        room = N * (0.92 if keep else 0.78)
        f = min(room / p.width, room / p.height)
        p = p.resize((max(1, int(p.width * f)), max(1, int(p.height * f))), Image.LANCZOS)
        plate.alpha_composite(p, ((N - p.width) // 2, (N - p.height) // 2 + S * 2))
    return plate.resize((PX, PX), Image.LANCZOS)


def main():
    coach = '--coach' in sys.argv
    kind = 'equip_coach' if coach else 'equip'
    src_dir, out = f'art/ui/out/{kind}', f'assets/ui/{kind}'
    cards = {} if coach else json.load(open('assets/gamedata/fightercards.json'))
    os.makedirs(out, exist_ok=True)
    gj = os.path.join(src_dir, 'garments.json')
    garments = set(json.load(open(gj))) if os.path.exists(gj) else set()
    done = []
    for f in sorted(os.listdir(src_dir)):
        if not f.endswith('.png'):
            continue
        cid = f[:-4]
        tint = COACH if coach else TYPE.get(int(cards.get(cid, {}).get('type', 1)), TYPE[1])
        icon(os.path.join(src_dir, f), tint, cid in garments).save(os.path.join(out, f))
        done.append(cid)
    print(f'{len(done)} icons in {out}')
    if '--sheet' in sys.argv:
        dst = sys.argv[sys.argv.index('--sheet') + 1]
        W = 15
        rows = (len(done) + W - 1) // W
        sheet = Image.new('RGBA', (W * 100 + 20, rows * 100 + 20), (233, 236, 241, 255))
        for i, cid in enumerate(sorted(done, key=int)):
            sheet.alpha_composite(Image.open(os.path.join(out, cid + '.png')), (10 + (i % W) * 100, 10 + (i // W) * 100))
        sheet.convert('RGB').save(dst)
        print(dst)


if __name__ == '__main__':
    main()
