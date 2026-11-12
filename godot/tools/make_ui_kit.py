#!/usr/bin/env python3
"""The S45 interface kit: the pieces ui_style.gd v2 slices into StyleBoxTextures
(9-slice), drawn here so nothing is painted by hand. Ink border of 3 px and a
hard shadow (a "lip") under everything that can be pressed, after the
owner-reviewed mockup (sprints/S45). Our own art. Writes assets/ui/kit/*.png
and the night backdrop assets/ui/ui_bg.png.
Run from godot/: python3 tools/make_ui_kit.py

The 9-slice margins ui_style.gd uses for each piece are in MARGINS below and
must stay in step with it (kit_margins() there).
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

S = 4                          # supersample factor
OUT = 'assets/ui/kit'

INK = (11, 13, 28)             # #0B0D1C
NIGHT = (18, 21, 42)           # #12152A
CREAM = (255, 246, 230)        # #FFF6E6

# body gradients, top -> middle -> bottom (the mockup's .pop/.navy/.green)
FILLS = {
    'pop': [(0, (255, 154, 99)), (0.55, (255, 107, 61)), (1, (232, 80, 31))],
    'navy': [(0, (74, 84, 153)), (0.6, (43, 50, 104)), (1, (32, 38, 79))],
    'green': [(0, (127, 240, 184)), (0.55, (54, 201, 138)), (1, (30, 158, 102))],
    'sun': [(0, (255, 226, 140)), (0.55, (255, 194, 71)), (1, (214, 148, 24))],
    'off': [(0, (78, 82, 112)), (1, (52, 56, 84))],
}


def vgrad(size, stops):
    w, h = size
    col = Image.new('RGB', (1, h))
    px = col.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t0 <= t <= t1:
                k = (t - t0) / max(1e-6, t1 - t0)
                px[0, y] = tuple(round(a + (b - a) * k) for a, b in zip(c0, c1))
                break
    return col.resize((w, h))


def lighten(stops, k):
    return [(t, tuple(min(255, round(c + (255 - c) * k)) for c in col)) for t, col in stops]


def darken(stops, k):
    return [(t, tuple(round(c * (1 - k)) for c in col)) for t, col in stops]


def rrect_mask(size, box, r):
    m = Image.new('L', size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, r, fill=255)
    return m


def down(img):
    return img.resize((img.width // S, img.height // S), Image.LANCZOS)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.png')
    img.save(path)
    print(path)


def relief(w, h, stops, r=14, lip=5, sink=0, shine=0.45):
    """A raised button: ink border, a light line on top, a dark band at the
    bottom of the face and a hard ink lip under it. `sink` pushes the face
    down into the lip (pressed). Returns the supersampled RGBA image."""
    W, H = w * S, (h + lip) * S
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    b = 3 * S
    top = sink * S
    face_h = h * S
    # the lip: the whole shape in ink, lip px lower
    lip_m = rrect_mask((W, H), [0, top + (lip - sink) * S, W - 1, top + face_h - 1 + (lip - sink) * S], r * S)
    img.paste(INK + (255,), (0, 0), lip_m)
    outer = rrect_mask((W, H), [0, top, W - 1, top + face_h - 1], r * S)
    img.paste(INK + (255,), (0, 0), outer)
    inner_box = [b, top + b, W - 1 - b, top + face_h - 1 - b]
    inner = rrect_mask((W, H), inner_box, (r - 3) * S)
    face = vgrad((W, H), [(t, c) for t, c in stops]).convert('RGBA')
    # the dark band at the bottom of the face (inset 0 -6px rgba(0,0,0,.22))
    band = Image.new('L', (W, H), 0)
    ImageDraw.Draw(band).rectangle([0, inner_box[3] - 6 * S, W, H], fill=56)
    face.paste((0, 0, 0), (0, 0), ImageChops.multiply(band, inner))
    # the shine on top (inset 0 3px rgba(255,255,255,.45))
    if shine > 0:
        hi = Image.new('L', (W, H), 0)
        ImageDraw.Draw(hi).rectangle([0, inner_box[1], W, inner_box[1] + 3 * S], fill=round(255 * shine))
        face.paste((255, 255, 255), (0, 0), ImageChops.multiply(hi, inner))
    img.paste(face, (0, 0), inner)
    return img


def skew(img, deg=8):
    """The main action leans forward (the mockup's skewX(-8deg))."""
    k = math.tan(math.radians(deg))
    pad = round(img.height * k / 2) + S
    wide = Image.new('RGBA', (img.width + 2 * pad, img.height), (0, 0, 0, 0))
    wide.paste(img, (pad, 0))
    cy = img.height / 2
    return wide.transform(wide.size, Image.AFFINE, (1, k, -k * cy, 0, 1, 0), Image.BICUBIC)


def buttons():
    for name, stops in FILLS.items():
        if name == 'off':
            continue
        save(down(relief(48, 48, stops)), f'btn_{name}')
        save(down(relief(48, 48, lighten(stops, 0.12))), f'btn_{name}_hover')
        save(down(relief(48, 48, darken(stops, 0.08), sink=4, shine=0.2)), f'btn_{name}_pressed')
    save(down(relief(48, 48, FILLS['off'], lip=3, shine=0.12)), 'btn_off')
    # the leaning main action
    p = FILLS['pop']
    save(down(skew(relief(64, 60, p))), 'btn_main')
    save(down(skew(relief(64, 60, lighten(p, 0.12)))), 'btn_main_hover')
    save(down(skew(relief(64, 60, darken(p, 0.08), sink=4, shine=0.2))), 'btn_main_pressed')
    save(down(skew(relief(64, 60, FILLS['off'], lip=3, shine=0.12))), 'btn_main_off')


def field(fill, rim, name, inset=(0, 0, 0, 70)):
    """A text slot: sunk, a shadow along its top edge."""
    W, H = 40 * S, 40 * S
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    img.paste(rim + (255,), (0, 0), rrect_mask((W, H), [0, 0, W - 1, H - 1], 10 * S))
    b = 3 * S
    inner = rrect_mask((W, H), [b, b, W - 1 - b, H - 1 - b], 7 * S)
    face = Image.new('RGBA', (W, H), fill + (255,))
    sh = Image.new('L', (W, H), 0)
    ImageDraw.Draw(sh).rectangle([0, b, W, b + 3 * S], fill=inset[3])
    face.paste(inset[:3], (0, 0), sh)
    img.paste(face, (0, 0), inner)
    save(down(img), name)


def plate(name, stops, r=18, lip=6, stitch=None, lines=None, w=72, h=72):
    """A window or a sheet: ink border, an optional pespunte (dashed stitch)
    and paper lines, and a hard shadow under it."""
    W, H = w * S, (h + lip) * S
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    img.paste(INK + (255,), (0, 0), rrect_mask((W, H), [0, lip * S, W - 1, H - 1], r * S))
    img.paste(INK + (255,), (0, 0), rrect_mask((W, H), [0, 0, W - 1, h * S - 1], r * S))
    b = 3 * S
    inner = rrect_mask((W, H), [b, b, W - 1 - b, h * S - 1 - b], (r - 3) * S)
    face = vgrad((W, H), stops).convert('RGBA')
    over = Image.new('RGBA', (W, H), (0, 0, 0, 0))   # translucent marks, blended
    d = ImageDraw.Draw(over)
    if lines:   # paper grain: a faint rule every 6 px
        for y in range(0, H, 6 * S):
            d.rectangle([0, y, W, y + 2 * S - 1], fill=lines)
    if stitch:   # the dashed stitch 10 px in (dashes of 6 on 4)
        col, off = stitch
        o = off * S
        x0, y0, x1, y1 = o, o, W - 1 - o, h * S - 1 - o
        for x in range(x0 + 6 * S, x1 - 6 * S, 10 * S):
            d.rectangle([x, y0, x + 6 * S, y0 + 2 * S - 1], fill=col)
            d.rectangle([x, y1 - 2 * S + 1, x + 6 * S, y1], fill=col)
        for y in range(y0 + 6 * S, y1 - 6 * S, 10 * S):
            d.rectangle([x0, y, x0 + 2 * S - 1, y + 6 * S], fill=col)
            d.rectangle([x1 - 2 * S + 1, y, x1, y + 6 * S], fill=col)
    face.alpha_composite(over)
    hi = Image.new('L', (W, H), 0)
    ImageDraw.Draw(hi).rectangle([0, b, W, b + 2 * S], fill=30)
    face.paste((255, 255, 255), (0, 0), ImageChops.multiply(hi, inner))
    img.paste(face, (0, 0), inner)
    save(down(img), name)


def ribbon(name, stops, w=96, h=48, notch=12):
    """A title ribbon: notched ends, ink only top and bottom."""
    W, H = w * S, h * S
    n = notch * S
    poly = [(0, 0), (W, 0), (W - n, H / 2), (W, H), (0, H), (n, H / 2)]
    m = Image.new('L', (W, H), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    face = vgrad((W, H), stops).convert('RGBA')
    d = ImageDraw.Draw(face)
    d.rectangle([0, 0, W, 3 * S - 1], fill=INK)
    d.rectangle([0, H - 3 * S, W, H], fill=INK)
    d.rectangle([0, H - 8 * S, W, H - 3 * S - 1], fill=tuple(round(c * 0.8) for c in stops[-1][1]))
    img.paste(face, (0, 0), m)
    save(down(img), name)


def medal(name, ring=(233, 169, 58), d=64, lip=4):
    """A round medallion: ink rim, gold ring inside, navy face lit from above."""
    D = d * S
    img = Image.new('RGBA', (D, D + lip * S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    dr.ellipse([0, lip * S, D - 1, D - 1 + lip * S], fill=INK)
    dr.ellipse([0, 0, D - 1, D - 1], fill=INK)
    face = Image.new('RGBA', (D, D), (0, 0, 0, 0))
    px = face.load()
    cx, cy, R = D / 2, D * 0.35, D * 0.7
    for y in range(D):
        for x in range(D):
            t = min(1, math.hypot(x - cx, y - cy) / R)
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip((60, 69, 136), (32, 38, 79))) + (255,)
    b = 3 * S
    m = Image.new('L', (D, D), 0)
    ImageDraw.Draw(m).ellipse([b, b, D - 1 - b, D - 1 - b], fill=255)
    img.paste(face, (0, 0), m)
    ImageDraw.Draw(img).ellipse([b, b, D - 1 - b, D - 1 - b], outline=ring, width=3 * S)
    save(down(img), name)


def capsule(name, w=64, h=36):
    """The coin pill (coins with their "+")."""
    W, H = w * S, h * S
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, W - 1, H - 1], H // 2, fill=INK)
    ImageDraw.Draw(img).rounded_rectangle([3 * S, 3 * S, W - 1 - 3 * S, H - 1 - 3 * S], H // 2 - 3 * S,
                                          fill=(12, 14, 30))
    save(down(img), name)


def backdrop():
    """The night backdrop behind every full screen until the arena art takes
    over (phase 2): #12152A, a faint 135° weave, a dark vignette."""
    W, H = 1280 * 2, 720 * 2
    img = Image.new('RGB', (W, H), NIGHT)
    weave = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(weave)
    for x in range(-H, W, 24):
        d.polygon([(x, 0), (x + 12, 0), (x + 12 + H, H), (x + H, H)], fill=8)
    img.paste((255, 255, 255), (0, 0), weave)
    vig = Image.new('L', (W, H), 0)
    ImageDraw.Draw(vig).ellipse([-W * 0.15, -H * 0.3, W * 1.15, H * 1.3], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(H // 5))
    dark = Image.new('RGB', (W, H), (8, 9, 20))
    img = Image.composite(img, dark, vig)
    img.resize((1280, 720), Image.LANCZOS).save('assets/ui/ui_bg.png')
    print('assets/ui/ui_bg.png')


def main():
    buttons()
    field((12, 14, 30), INK, 'field')
    field((12, 14, 30), (255, 194, 71), 'field_focus')
    field((243, 221, 178), (59, 42, 26), 'slot_paper', inset=(0, 0, 0, 30))
    plate('window', [(0, (40, 47, 98)), (1, (26, 31, 70))])
    plate('card', [(0, (32, 37, 76)), (1, (22, 26, 54))], r=12, lip=4, w=48, h=48)
    plate('paper', [(0, (255, 241, 214)), (1, (255, 236, 200))], r=12,
          stitch=((110, 70, 30, 90), 10), lines=(120, 80, 30, 13))
    ribbon('ribbon', [(0, (255, 138, 85)), (1, (232, 80, 31))])
    ribbon('ribbon_sun', [(0, (255, 226, 140)), (1, (214, 148, 24))])
    medal('medal')
    capsule('capsule')
    backdrop()


if __name__ == '__main__':
    main()
