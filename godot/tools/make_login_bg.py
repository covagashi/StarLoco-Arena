#!/usr/bin/env python3
"""Generate the Pippop Arena login background — rendered at 3x and
downscaled with LANCZOS for clean antialiasing.

Output: godot/assets/ui/login_bg.png  (1280x720 — matches the viewport)

Layout contract (final px) — login_screen.gd overlays controls here:
    name field   (475, 365, 330, 44)
    pass field   (475, 445, 330, 44)
    proxy combo  (475, 525, 330, 44)
    connect btn  (530, 608, 220, 52)
    error label  (440, 662, 400, 20)
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

S = 3                      # supersample factor
W, H = 1280 * S, 720 * S
OUT = "assets/ui/login_bg.png"

F_COPPER = "assets/gui/fonts/COPRGTB.TTF"
F_TAHOMA = "assets/gui/fonts/TAHOMA.TTF"
F_BAY = "/System/Library/Fonts/Supplemental/NotoSansTagalog-Regular.ttf"


def sc(v):
    return int(round(v * S))


def vgrad(size, stops):
    """Vertical gradient image from [(pos0-1, (r,g,b)), ...]."""
    g = Image.new("RGB", (1, size[1]))
    px = g.load()
    n = size[1] - 1
    for y in range(size[1]):
        t = y / n
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                f = 0.0 if p1 == p0 else (t - p0) / (p1 - p0)
                px[0, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3))
                break
    return g.resize(size)


def engraved(draw, pos, text, font, ink, lite, off=2):
    """Carved-in-stone text: light cut below, dark ink on top."""
    x, y = pos
    draw.text((x * S, (y + off) * S), text, font=font, fill=lite)
    draw.text((x * S, y * S), text, font=font, fill=ink)


def bezier(p0, p1, p2, p3, n=80):
    pts = []
    for i in range(n + 1):
        t = i / n
        mt = 1 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def tapered_poly(pts, w0, w1):
    """Thicken a polyline into a tapered polygon (width w0 -> w1)."""
    left, right = [], []
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        if i == 0:
            dx, dy = pts[1][0] - x, pts[1][1] - y
        elif i == n - 1:
            dx, dy = x - pts[i - 1][0], y - pts[i - 1][1]
        else:
            dx, dy = pts[i + 1][0] - pts[i - 1][0], y - pts[i + 1][1]
        ln = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


def letter_tile(ch, font, tile_px):
    """One logo glyph on its own tile: dark outline ring + textured gold fill."""
    t = Image.new("RGBA", (sc(tile_px), sc(tile_px)), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    gx, gy = t.size[0] // 2, int(t.size[1] * 0.75)   # glyph center-x, baseline
    # outline ring
    d.text((gx, gy), ch, font=font, anchor="ms",
           fill=(18, 13, 4), stroke_width=sc(6), stroke_fill=(18, 13, 4))
    # gold interior, masked to the glyph without the stroke
    m = Image.new("L", t.size, 0)
    ImageDraw.Draw(m).text((gx, gy), ch, font=font, anchor="ms", fill=255)
    gold = vgrad(t.size, [(0.0, (252, 231, 148)), (0.45, (236, 190, 74)),
                          (1.0, (148, 100, 24))])
    gn = Image.effect_noise(t.size, 42).convert("L")
    gold = ImageChops.multiply(
        gold, gn.point(lambda v: 225 + v // 8).convert("RGB"))
    t.paste(gold.convert("RGBA"), (0, 0), m)
    return t


def mascot(px=200):
    """Round horned creature face peeking over the title — Dofus-ish blob."""
    t = Image.new("RGBA", (sc(px), sc(px)), (0, 0, 0, 0))
    d = ImageDraw.Draw(t)
    cx, cy = sc(100), sc(118)          # body centre in tile
    rx, ry = sc(60), sc(54)
    # horns first (behind body): tapered bezier, bone colour
    for sgn in (-1, 1):
        pts = bezier((cx + sgn * sc(28), cy - sc(40)),
                     (cx + sgn * sc(80), cy - sc(55)),
                     (cx + sgn * sc(95), cy - sc(95)),
                     (cx + sgn * sc(62), cy - sc(105)))
        poly = tapered_poly(pts, sc(16), sc(3))
        d.polygon(poly, fill=(24, 19, 8))
        inner = tapered_poly([(x, y + sc(2)) for x, y in pts], sc(12), sc(2))
        d.polygon(inner, fill=(214, 202, 165))
    # body: outline + gradient clipped to ellipse + grain
    d.ellipse([cx - rx - sc(4), cy - ry - sc(4), cx + rx + sc(4), cy + ry + sc(4)],
              fill=(20, 16, 7))
    m = Image.new("L", t.size, 0)
    ImageDraw.Draw(m).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    body = vgrad(t.size, [(0.0, (138, 132, 66)), (0.55, (96, 92, 42)),
                          (1.0, (56, 54, 24))])
    bn = Image.effect_noise(t.size, 55).convert("L")
    body = ImageChops.multiply(
        body, bn.point(lambda v: 215 + v // 9).convert("RGB"))
    t.paste(body.convert("RGBA"), (0, 0), m)
    d = ImageDraw.Draw(t)
    # top-left sheen clipped to the silhouette
    sheen = Image.new("RGBA", t.size, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).ellipse(
        [cx - sc(48), cy - sc(48), cx + sc(10), cy - sc(10)],
        fill=(255, 250, 210, 70))
    sheen = sheen.filter(ImageFilter.GaussianBlur(sc(8)))
    t.paste(Image.new("RGBA", t.size, (0, 0, 0, 0)), (0, 0))
    t = Image.alpha_composite(t, Image.composite(sheen,
            Image.new("RGBA", t.size, (0, 0, 0, 0)), m))
    d = ImageDraw.Draw(t)
    # angry eyes
    for sgn in (-1, 1):
        ex, ey = cx + sgn * sc(26), cy - sc(12)
        d.ellipse([ex - sc(21), ey - sc(15), ex + sc(21), ey + sc(15)],
                  fill=(238, 233, 208), outline=(20, 16, 7), width=sc(3))
        px_ = ex - sgn * sc(8)
        d.ellipse([px_ - sc(8), ey - sc(3), px_ + sc(8), ey + sc(11)],
                  fill=(16, 12, 5))
        # slanted brow, dropping toward the centre
        brow = [(ex - sc(26), ey - sc(24) - sgn * sc(8)),
                (ex + sc(26), ey - sc(24) + sgn * sc(8))]
        d.line(brow, fill=(40, 38, 16), width=sc(9))
        # lid: body-colour wedge over the eye's upper half
        lid = [(ex - sc(22), ey - sc(16)),
               (ex + sc(22), ey - sc(16)),
               (ex + sgn * sc(22), ey + sc(0)),
               (ex - sgn * sc(22), ey - sc(8))]
        d.polygon(lid, fill=(88, 84, 38))
    # smirk + fangs
    mouth = bezier((cx - sc(30), cy + sc(28)), (cx - sc(10), cy + sc(42)),
                   (cx + sc(14), cy + sc(40)), (cx + sc(32), cy + sc(24)), 40)
    d.line(mouth, fill=(22, 18, 8), width=sc(4))
    for fx, fy0, fy1 in [(cx - sc(22), cy + sc(34), cy + sc(48)),
                         (cx + sc(20), cy + sc(33), cy + sc(45))]:
        d.polygon([(fx - sc(5), fy0), (fx + sc(5), fy0), (fx, fy1)],
                  fill=(238, 233, 208), outline=(20, 16, 7))
    return t


def word_tiles(img, word, font, tile_px, baseline, angles, yoffs,
               tracking=0.86):
    """Paste a word as individually-rotated letter tiles along an arc."""
    advs = [font.getlength(c) / S * tracking for c in word]
    total = sum(advs)
    x = (1280 - total) / 2
    for i, ch in enumerate(word):
        if ch == " ":
            x += advs[i]
            continue
        tile = letter_tile(ch, font, tile_px)
        if angles[i]:
            tile = tile.rotate(angles[i], resample=Image.BICUBIC)
        ty = baseline + yoffs[i] - tile_px * 0.75
        img.paste(tile, (sc(x + advs[i] / 2 - tile_px / 2), sc(ty)), tile)
        x += advs[i]


def main():
    img = vgrad((W, H), [(0.0, (30, 29, 19)), (0.5, (42, 40, 25)),
                         (1.0, (20, 19, 12))]).convert("RGB")
    dr = ImageDraw.Draw(img, "RGBA")

    # film grain
    noise = Image.effect_noise((W, H), 60).convert("L")
    img = ImageChops.multiply(img, noise.point(lambda v: 215 + v // 8).convert("RGB"))
    dr = ImageDraw.Draw(img, "RGBA")

    # vignette
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([sc(-260), sc(-200), W + sc(260), H + sc(200)], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(sc(120)))
    dark = Image.new("RGB", (W, H), (8, 8, 4))
    img = Image.composite(img, dark, vig)
    dr = ImageDraw.Draw(img, "RGBA")

    # ---- stone frame -----------------------------------------------------
    m, th = 18, 30
    dr.rounded_rectangle([sc(m), sc(m), W - sc(m), H - sc(m)],
                         sc(26), fill=(52, 49, 34))
    # chisel: light top/left, dark bottom/right
    dr.line([sc(m + 4), sc(m + th + 6), sc(m + 4), H - sc(m + th + 6)],
            fill=(96, 90, 66), width=sc(3))
    dr.line([sc(m + 4), sc(m + 4), W - sc(m + 4), sc(m + 4)],
            fill=(96, 90, 66), width=sc(3))
    dr.line([W - sc(m + 5), sc(m + th + 6), W - sc(m + 5), H - sc(m + th)],
            fill=(12, 11, 6), width=sc(3))
    dr.line([sc(m), H - sc(m + 5), W - sc(m + 5), H - sc(m + 5)],
            fill=(12, 11, 6), width=sc(3))
    # inner bevel into the field
    dr.rounded_rectangle([sc(m + th - 6), sc(m + th - 6),
                          W - sc(m + th - 6), H - sc(m + th - 6)],
                         sc(14), outline=(18, 17, 10), width=sc(4))
    dr.rounded_rectangle([sc(m + th - 2), sc(m + th - 2),
                          W - sc(m + th - 2), H - sc(m + th - 2)],
                         sc(14), outline=(74, 70, 50), width=sc(2))
    # rivets
    for cx, cy in [(m + th // 2, m + th // 2), (W / S - m - th // 2, m + th // 2),
                   (m + th // 2, H / S - m - th // 2),
                   (W / S - m - th // 2, H / S - m - th // 2)]:
        dr.ellipse([sc(cx - 7), sc(cy - 7), sc(cx + 7), sc(cy + 7)],
                   fill=(38, 35, 22), outline=(90, 85, 62), width=sc(2))
        dr.ellipse([sc(cx - 2), sc(cy - 3), sc(cx + 3), sc(cy + 2)],
                   fill=(120, 112, 82))

    # ---- baybayin watermark behind the title ------------------------------
    fb = ImageFont.truetype(F_BAY, sc(430))
    wm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wm)
    wd.text((W / 2, sc(60)), "ᜃ", font=fb, anchor="mm",
            fill=(90, 86, 60, 26))
    img = Image.alpha_composite(img.convert("RGBA"), wm).convert("RGB")
    dr = ImageDraw.Draw(img, "RGBA")

    # ---- logo: mascot peeking over rotated letter-tiles -------------------
    masc = mascot(200)
    img = img.convert("RGBA")
    img.alpha_composite(masc, (sc(640 - 100), sc(8)))

    fword = ImageFont.truetype(F_COPPER, sc(140))
    word_tiles(img, "PIPPOP", fword, 210, 228,
               angles=[-8, -3, 4, -5, 0, 7],
               yoffs=[-6, 4, 8, 10, 6, -2])
    fsub2 = ImageFont.truetype(F_COPPER, sc(64))
    word_tiles(img, "ARENA", fsub2, 92, 288,
               angles=[-5, -2, 0, 2, 5],
               yoffs=[2, 6, 8, 6, 2])
    dr = ImageDraw.Draw(img, "RGBA")

    # baybayin subtitle strip  (pi-p-po  a-ri-na)
    fsub = ImageFont.truetype(F_BAY, sc(30))
    sub = "ᜉᜒᜉ᜔ᜉᜓ  ᜀᜇᜒᜈ"
    sb = dr.textbbox((0, 0), sub, font=fsub)
    engraved(dr, ((1280 - (sb[2] - sb[0]) / S) / 2, 300), sub, fsub,
             (60, 56, 38), (104, 98, 70), off=1)

    # ---- recessed form well ----------------------------------------------
    wx0, wy0, wx1, wy1 = 440, 325, 840, 595
    dr.rounded_rectangle([sc(wx0 - 6), sc(wy0 - 6), sc(wx1 + 6), sc(wy1 + 6)],
                         sc(20), outline=(14, 13, 7), width=sc(4))
    dr.rounded_rectangle([sc(wx0 - 3), sc(wy0 - 3), sc(wx1 + 3), sc(wy1 + 3)],
                         sc(18), outline=(88, 83, 60), width=sc(2))
    well = vgrad((sc(wx1 - wx0), sc(wy1 - wy0)),
                 [(0.0, (22, 21, 12)), (1.0, (38, 36, 21))])
    wmask = Image.new("L", well.size, 0)
    ImageDraw.Draw(wmask).rounded_rectangle([0, 0, well.size[0], well.size[1]],
                                            sc(16), fill=255)
    img.convert("RGB").paste(well, (sc(wx0), sc(wy0)), wmask)
    img.paste(well, (sc(wx0), sc(wy0)), wmask)
    dr = ImageDraw.Draw(img, "RGBA")
    # inner shadow line at the top of the well
    dr.line([sc(wx0 + 8), sc(wy0 + 8), sc(wx1 - 8), sc(wy0 + 8)],
            fill=(8, 8, 4, 160), width=sc(3))

    # ---- field slots ------------------------------------------------------
    f_lbl = ImageFont.truetype(F_COPPER, sc(17))
    fields = [("CUENTA", 365), ("CONTRASEÑA", 445), ("SERVIDOR", 525)]
    for label, fy in fields:
        engraved(dr, (475, fy - 24), label, f_lbl, (198, 190, 152),
                 (10, 9, 5), off=1)
        # sunken slot
        dr.rounded_rectangle([sc(475), sc(fy), sc(805), sc(fy + 44)],
                             sc(8), fill=(20, 19, 11))
        dr.line([sc(479), sc(fy + 3), sc(801), sc(fy + 3)],
                fill=(60, 56, 38), width=sc(2))
        dr.line([sc(479), sc(fy + 42), sc(801), sc(fy + 42)],
                fill=(76, 72, 50), width=sc(1))

    # baybayin proverbs flanking the form well
    # L: matira ang matibay · lakas ng loob · karangalan · sipag at tiyaga
    # R: digmaan · paglalakbay · panalo · bayanihan
    fprov = ImageFont.truetype(F_BAY, sc(30))
    prov_l = ["ᜋᜆᜒᜇ ᜀᜅ᜔ ᜋᜆᜒᜊᜌ᜔", "ᜎᜃᜐ᜔ ᜈᜅ᜔ ᜎᜓᜂᜊ᜔",
              "ᜃᜇᜅ᜔ᜄᜎᜈ᜔", "ᜐᜒᜉᜄ᜔ ᜀᜆ᜔ ᜆᜒᜌᜄ"]
    prov_r = ["ᜇᜒᜄ᜔ᜋᜀᜈ᜔", "ᜉᜄ᜔ᜎᜎᜃ᜔ᜊᜌ᜔",
              "ᜉᜈᜎᜓ", "ᜊᜌᜈᜒᜑᜈ᜔"]
    for col, proverbs in ((244, prov_l), (1036, prov_r)):
        for i, t in enumerate(proverbs):
            tb = dr.textbbox((0, 0), t, font=fprov)
            engraved(dr, (col - (tb[2] - tb[0]) / S / 2, 350 + i * 62),
                     t, fprov, (56, 52, 35), (96, 91, 65), off=1)

    # ---- connect button (baked art, transparent Button overlays it) -------
    bx0, by0, bx1, by1 = 530, 608, 750, 660
    btn = vgrad((sc(bx1 - bx0), sc(by1 - by0)),
                [(0.0, (196, 154, 58)), (0.5, (150, 112, 34)),
                 (1.0, (110, 80, 22))])
    bmask = Image.new("L", btn.size, 0)
    ImageDraw.Draw(bmask).rounded_rectangle([0, 0, btn.size[0], btn.size[1]],
                                            sc(10), fill=255)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [sc(bx0), sc(by0 + 5), sc(bx1), sc(by1 + 5)], sc(10),
        fill=(0, 0, 0, 140))
    img = Image.alpha_composite(img,
                                shadow.filter(ImageFilter.GaussianBlur(sc(6))))
    img.paste(btn, (sc(bx0), sc(by0)), bmask)
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rounded_rectangle([sc(bx0), sc(by0), sc(bx1), sc(by1)], sc(10),
                         outline=(24, 18, 6), width=sc(3))
    dr.line([sc(bx0 + 6), sc(by0 + 3), sc(bx1 - 6), sc(by0 + 3)],
            fill=(255, 230, 150, 170), width=sc(2))
    fbtn = ImageFont.truetype(F_COPPER, sc(28))
    bb = dr.textbbox((0, 0), "CONECTAR", font=fbtn)
    engraved(dr, ((1280 - (bb[2] - bb[0]) / S) / 2, by0 + 12), "CONECTAR",
             fbtn, (40, 28, 8), (238, 208, 120), off=1)

    # ---- baybayin footer strip --------------------------------------------
    ffoot = ImageFont.truetype(F_BAY, sc(22))
    foot = "ᜑᜈ᜔ᜇᜒᜃᜓ  ᜐᜄᜒᜆ᜔ᜆᜒᜄ᜔  ᜉᜒᜉ᜔ᜉᜓ"   # han-diko ma-gi-ttig pi-p-po
    fb2 = dr.textbbox((0, 0), foot, font=ffoot)
    engraved(dr, ((1280 - (fb2[2] - fb2[0]) / S) / 2, 686), foot, ffoot,
             (52, 49, 33), (92, 87, 62), off=1)

    # corner glyphs on the side pillars
    for gx, gy in [(34, 380), (1246, 380)]:
        engraved(dr, (gx - 13, gy - 40), "ᜇ",
                 ImageFont.truetype(F_BAY, sc(80)),
                 (56, 52, 35), (90, 85, 60), off=2)

    # ---- downscale --------------------------------------------------------
    img = img.convert("RGB").resize((1280, 720), Image.LANCZOS)
    img.save(OUT)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
