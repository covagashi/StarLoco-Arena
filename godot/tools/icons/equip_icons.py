#!/usr/bin/env python3
"""S38: the equipment icons. Takes the bare renders of our 3D pieces
(tools/icons/equip_icons.tscn → art/ui/out/equip/<card>.png) and sets each
on the style B plate the spells use (slanted, an ink rule on top): a pale
tint of its slot (weapon, pet, cape, hat, dofus) so the piece's own colours
read, the piece fitted to the plate — long weapons laid on the diagonal.
Writes the finished icon (96 px) to assets/ui/equip/. --coach does the
coach cards into assets/ui/equip_coach/: its garments (garment_icons.tscn)
are cut against the bare coach, and its marks are their emblem on skin.
Run from godot/ after the .tscn: python3 tools/icons/equip_icons.py [--coach] [--sheet out.png]
The coach's three: equip_icons.tscn -- --coach, garment_icons.tscn, this --coach.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

PX = 96
S = 4
N = PX * S
INK = (28, 32, 48)
# fightercards.json type → plate tint (style B, pale so the piece reads)
TYPE = {1: (214, 220, 232), 2: (214, 238, 226), 3: (240, 222, 226), 4: (240, 230, 208), 5: (226, 220, 244)}
COACH = (232, 234, 240)
SKIN, SKIN_RIM = (242, 208, 170), (196, 150, 112)
MARKS = 'art/equipment/out/marks'   # tools/art/mark_emblems.py


def mark(emblem):
    """A mark (a tattoo, often on the back or the arm's far side, a few
    pixels on the coach): its emblem on a patch of skin."""
    src = os.path.join(MARKS, emblem + '.png')
    if not os.path.exists(src):
        return None
    n = 256
    patch = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(patch)
    d.ellipse((6, 10, n - 6, n - 4), fill=SKIN_RIM + (255,))
    d.ellipse((12, 12, n - 12, n - 12), fill=SKIN + (255,))
    d.ellipse((40, 26, n - 70, 96), fill=tuple(min(255, c + 14) for c in SKIN) + (255,))
    e = Image.open(src).convert('RGBA')
    e = e.crop(e.getbbox())
    f = n * 0.62 / max(e.size)
    e = e.resize((int(e.width * f), int(e.height * f)), Image.LANCZOS)
    patch.alpha_composite(e, ((n - e.width) // 2, (n - e.height) // 2))
    return patch


def garment(src, bare):
    """A garment worn on the coach: the pixels that differ from the bare
    render are the garment; the cut is its outline's square, and the body
    around it is dimmed so the garment (a mark on the skin too) reads."""
    im = Image.open(src).convert('RGBA')
    fig = bare.getbbox()   # the filters only over the figure, not the frame
    fig = (fig[0] - 40, fig[1] - 40, fig[2] + 40, fig[3] + 40)
    im, bare = im.crop(fig), bare.crop(fig)
    a, b = np.asarray(im).astype(np.int16), np.asarray(bare).astype(np.int16)
    mask = (np.abs(a - b).sum(axis=2) > 60).astype(np.uint8) * 255
    m = Image.fromarray(mask, 'L').filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(5))
    box = m.getbbox()
    if box is None:
        return None
    x0, y0, x1, y1 = box
    side = int(max(x1 - x0, y1 - y0) * 1.12)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    cut = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    body = im.crop(cut)
    r, g, bl, al = body.split()
    grey = Image.merge('RGB', (r, g, bl)).convert('L').point(lambda v: 150 + v * 0.35)
    # the floor shadow (half alpha) is not body: left out of the ghost
    ghost = Image.merge('RGBA', (grey, grey, grey, al.point(lambda v: v * 0.45 if v > 190 else 0)))
    keep = m.filter(ImageFilter.GaussianBlur(1.5)).crop(cut)
    ghost.paste(body, (0, 0), keep)
    return ghost


def piece(src, keep=False):
    if keep:   # a garment on the body
        return garment(src, Image.open(os.path.join(os.path.dirname(src), '_bare.png')).convert('RGBA'))
    im = Image.open(src).convert('RGBA')
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


def icon(src, tint, keep=False, emblem=None):
    p = mark(emblem) if emblem else piece(src, keep)
    plate = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(plate)
    k = int(N * 0.12)
    d.polygon([(k, 0), (N, 0), (N - k, N), (0, N)], fill=tint + (255,))
    d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 5)
    if p is not None:
        room = N * (0.92 if keep and not emblem else 0.78)
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
    worn = json.load(open('art/equipment/pieces.json'))['coach'] if coach else {}
    done = []
    for f in sorted(os.listdir(src_dir)):
        if not f.endswith('.png') or f.startswith('_'):
            continue
        cid = f[:-4]
        tint = COACH if coach else TYPE.get(int(cards.get(cid, {}).get('type', 1)), TYPE[1])
        piece_name = str(worn.get(cid, ''))
        emblem = piece_name[5:] if piece_name.startswith('mark_') else None
        icon(os.path.join(src_dir, f), tint, cid in garments, emblem).save(os.path.join(out, f))
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
