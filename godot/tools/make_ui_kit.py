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
    'pop': [(0, (240, 146, 98)), (0.55, (222, 100, 58)), (1, (180, 68, 32))],
    'navy': [(0, (72, 78, 124)), (0.6, (44, 49, 86)), (1, (31, 35, 64))],
    'green': [(0, (127, 240, 184)), (0.55, (54, 201, 138)), (1, (30, 158, 102))],
    'sun': [(0, (247, 214, 132)), (0.55, (233, 180, 76)), (1, (190, 132, 34))],
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


BROWN_INK = (43, 29, 16)
GOLD = (201, 156, 72)
GOLD_HI = (241, 212, 140)


def corner_scroll(size):
    """The top-left gold filigree: two rules that meet in a scroll (a curl
    turned twice) with a diamond in its eye. Mirrored to the other corners."""
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    u = size / 40.0
    w = max(1, round(2.2 * u))
    # the rules leaving the scroll
    d.line([(14 * u, 6 * u), (40 * u, 6 * u)], fill=GOLD, width=w)
    d.line([(6 * u, 14 * u), (6 * u, 40 * u)], fill=GOLD, width=w)
    # the scroll: arcs of shrinking radius around the eye
    ex, ey = 14 * u, 14 * u
    for rad, a0, a1 in [(8, 180, 450), (5, 270, 540), (2.6, 0, 300)]:
        d.arc([ex - rad * u, ey - rad * u, ex + rad * u, ey + rad * u], a0, a1, fill=GOLD, width=w)
    d.polygon([(ex, ey - 2.4 * u), (ex + 2.4 * u, ey), (ex, ey + 2.4 * u), (ex - 2.4 * u, ey)], fill=GOLD_HI)
    # leaves along the rules
    for (lx, ly, horiz) in [(26 * u, 6 * u, True), (6 * u, 26 * u, False)]:
        if horiz:
            d.polygon([(lx - 5 * u, ly), (lx, ly - 3 * u), (lx + 5 * u, ly), (lx, ly + 3 * u)], fill=GOLD)
        else:
            d.polygon([(lx, ly - 5 * u), (lx + 3 * u, ly), (lx, ly + 5 * u), (lx - 3 * u, ly)], fill=GOLD)
    return c


def parchment(name, w=160, h=160, lip=6, r=14):
    """Aged paper (the references: Hagelberg, Moonlighter): mottled, burnt
    towards the edges, a rough dark-brown edge, a double gold rule inside
    and filigree in the corners (which the 9-slice never stretches)."""
    W, H = w * S, (h + lip) * S
    body_h = h * S
    import random
    rnd = random.Random(45)
    # the rough edge: a rounded rect nibbled by noise
    base = rrect_mask((W, H), [0, 0, W - 1, body_h - 1], r * S)
    nib = Image.effect_noise((W, H), 90).filter(ImageFilter.GaussianBlur(S * 1.2))
    edge = ImageChops.subtract(base, base.filter(ImageFilter.MinFilter(S * 4 + 1)))
    bite = ImageChops.multiply(edge, nib.point(lambda v: 255 if v > 138 else 0))
    mask = ImageChops.subtract(base, bite)
    outline = mask.filter(ImageFilter.MaxFilter(S * 6 + 1))
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    shadow = Image.new('L', (W, H), 0)
    shadow.paste(outline, (0, lip * S))
    img.paste(BROWN_INK + (255,), (0, 0), shadow)
    img.paste(BROWN_INK + (255,), (0, 0), outline)
    # the paper: a warm cream, mottled, darker and browner at the edges
    face = vgrad((W, H), [(0, (246, 232, 198)), (1, (238, 220, 180))]).convert('RGB')
    mott = Image.effect_noise((W // 8, H // 8), 60).resize((W, H), Image.BICUBIC) \
        .filter(ImageFilter.GaussianBlur(S * 3)).point(lambda v: 236 + (v - 128) // 6)
    face = ImageChops.multiply(face, Image.merge('RGB', [mott] * 3))
    grain = Image.effect_noise((W, H), 40).point(lambda v: 240 + v // 16)
    face = ImageChops.multiply(face, Image.merge('RGB', [grain] * 3))
    burn = mask.filter(ImageFilter.MinFilter(S * 6 + 1)).filter(ImageFilter.GaussianBlur(S * 7))
    burn = ImageChops.invert(burn)
    burn = ImageChops.multiply(burn, mask).point(lambda v: min(255, v * 200 // 255))
    face.paste((150, 98, 46), (0, 0), burn)
    img.paste(face, (0, 0), mask)
    # the double gold rule and the corner filigree
    d = ImageDraw.Draw(img)
    o = 4 * S + round(6 * S)    # the scrolls' rules continue as one gold line
    lw = max(1, round(2.2 * S * (40 * S / 40.0) / S))
    d.line([(44 * S, o), (W - 44 * S, o)], fill=GOLD, width=lw)
    d.line([(44 * S, body_h - 1 - o), (W - 44 * S, body_h - 1 - o)], fill=GOLD, width=lw)
    d.line([(o, 44 * S), (o, body_h - 44 * S)], fill=GOLD, width=lw)
    d.line([(W - 1 - o, 44 * S), (W - 1 - o, body_h - 44 * S)], fill=GOLD, width=lw)
    cs = 40 * S
    tl = corner_scroll(cs)
    o = 4 * S
    img.alpha_composite(tl, (o, o))
    img.alpha_composite(tl.transpose(Image.FLIP_LEFT_RIGHT), (W - cs - o, o))
    img.alpha_composite(tl.transpose(Image.FLIP_TOP_BOTTOM), (o, body_h - cs - o))
    img.alpha_composite(tl.transpose(Image.ROTATE_180), (W - cs - o, body_h - cs - o))
    save(down(img), name)


def banner(name, stops, w=128, h=60, notch=12, tail=18):
    """A fabric title ribbon: the band, gold trim along it and folded tails
    behind both ends, a shade lower (the references' cloth banners)."""
    W, H = w * S, h * S
    t = tail * S
    n = notch * S
    top, bot = 4 * S, H - 12 * S
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dark = tuple(round(c * 0.62) for c in stops[-1][1])
    d = ImageDraw.Draw(img)
    for side in (0, 1):
        x0 = 0 if side == 0 else W - t - 6 * S
        pts = [(x0, top + 8 * S), (x0 + t + 6 * S, top + 8 * S), (x0 + t + 6 * S, bot + 8 * S), (x0, bot + 8 * S)]
        if side == 0:
            pts[0] = (x0, top + 8 * S)
            notch_pt = (x0 + n * 0.8, (top + bot) / 2 + 8 * S)
            poly = [pts[0], pts[1], pts[2], pts[3], notch_pt]
        else:
            notch_pt = (W - n * 0.8, (top + bot) / 2 + 8 * S)
            poly = [pts[0], pts[1], notch_pt, pts[2], pts[3]]
        d.polygon(poly, fill=INK + (255,))
        inner = [(px + (3 * S if px < W / 2 else -3 * S), py + (3 * S if py < (top + bot) / 2 + 8 * S else -3 * S)) for px, py in poly]
        d.polygon(inner, fill=dark + (255,))
    # the band itself
    band = Image.new('L', (W, H), 0)
    ImageDraw.Draw(band).rectangle([t - 2 * S, top, W - t + 2 * S, bot], fill=255)
    face = vgrad((W, H), stops).convert('RGBA')
    fd = ImageDraw.Draw(face)
    fd.rectangle([0, top, W, top + 3 * S - 1], fill=INK)
    fd.rectangle([0, bot - 3 * S + 1, W, bot], fill=INK)
    fd.rectangle([0, top + 5 * S, W, top + 6 * S], fill=GOLD_HI + (255,))
    fd.rectangle([0, bot - 6 * S, W, bot - 5 * S], fill=GOLD + (255,))
    fd.rectangle([0, bot - 11 * S, W, bot - 7 * S], fill=tuple(round(c * 0.85) for c in stops[-1][1]) + (255,))
    img.paste(face, (0, 0), band)
    d.line([(t - 2 * S, top), (t - 2 * S, bot)], fill=INK, width=3 * S)
    d.line([(W - t + 2 * S, top), (W - t + 2 * S, bot)], fill=INK, width=3 * S)
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
    field((232, 211, 166), (59, 42, 26), 'slot_paper', inset=(0, 0, 0, 30))
    plate('window', [(0, (40, 47, 98)), (1, (26, 31, 70))])
    plate('card', [(0, (32, 37, 76)), (1, (22, 26, 54))], r=12, lip=4, w=48, h=48)
    parchment('paper')
    banner('ribbon', [(0, (232, 128, 84)), (1, (186, 72, 36))])
    banner('ribbon_sun', [(0, (243, 208, 124)), (1, (186, 130, 36))])
    banner('ribbon_navy', [(0, (72, 78, 124)), (1, (40, 45, 80))])
    medal('medal')
    capsule('capsule')
    backdrop()


if __name__ == '__main__':
    main()
