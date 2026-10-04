#!/usr/bin/env python3
"""Generate the Pippop Arena login background — rendered at 3x and
downscaled with LANCZOS for clean antialiasing.

Output: godot/assets/gui/login_bg.png  (1280x800)

Layout contract (final px) — login_screen.gd overlays controls here:
    name field   (475, 390, 330, 46)
    pass field   (475, 470, 330, 46)
    proxy combo  (475, 550, 330, 46)
    connect btn  (530, 660, 220, 54)
    error label  (440, 722, 400, 24)
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

S = 3                      # supersample factor
W, H = 1280 * S, 800 * S
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
            dx, dy = pts[i + 1][0] - pts[i - 1][0], pts[i + 1][1] - pts[i - 1][1]
        ln = max((dx * dx + dy * dy) ** 0.5, 1e-6)
        nx, ny = -dy / ln, dx / ln
        w = (w0 + (w1 - w0) * i / (n - 1)) / 2
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    return left + right[::-1]


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

    # ---- horns flanking the title ---------------------------------------
    for sign in (-1, 1):
        cxm = W / S / 2
        base = (cxm + sign * 245, 190)
        pts = bezier(base,
                     (cxm + sign * 320, 120),
                     (cxm + sign * 300, 40),
                     (cxm + sign * 205, 34))
        poly = tapered_poly([(x * S, y * S) for x, y in pts], sc(30), sc(4))
        dr.polygon(poly, fill=(34, 29, 16))
        # rim light on the outer edge
        edge = poly[:len(pts)]
        for i in range(len(edge) - 1):
            dr.line([edge[i], edge[i + 1]], fill=(120, 106, 66, 160),
                    width=sc(2))

    # ---- baybayin watermark behind the title ------------------------------
    fb = ImageFont.truetype(F_BAY, sc(430))
    wm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wd = ImageDraw.Draw(wm)
    wd.text((W / 2, sc(60)), "ᜃ", font=fb, anchor="mm",
            fill=(90, 86, 60, 26))
    img = Image.alpha_composite(img.convert("RGBA"), wm).convert("RGB")
    dr = ImageDraw.Draw(img, "RGBA")

    # ---- title "PIPPOP ARENA" --------------------------------------------
    ft = ImageFont.truetype(F_COPPER, sc(120))
    title = "PIPPOP ARENA"
    tb = dr.textbbox((0, 0), title, font=ft)
    tw = (tb[2] - tb[0]) / S
    tx = (1280 - tw) / 2
    ty = 66
    # warm glow
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.text((sc(tx), sc(ty)), title, font=ft, fill=(210, 120, 30, 120))
    gl = gl.filter(ImageFilter.GaussianBlur(sc(14)))
    img = Image.alpha_composite(img.convert("RGBA"), gl).convert("RGB")
    dr = ImageDraw.Draw(img, "RGBA")
    # carved shadow
    dr.text((sc(tx), sc(ty + 4)), title, font=ft, fill=(16, 12, 4))
    # gold gradient fill through a text mask
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text((sc(tx), sc(ty)), title, font=ft, fill=255)
    gold = vgrad((W, H), [(0.0, (250, 226, 140)), (0.55, (232, 185, 69)),
                         (1.0, (154, 106, 28))]).convert("RGBA")
    img.paste(gold, (0, 0), mask)
    dr = ImageDraw.Draw(img, "RGBA")

    # baybayin subtitle strip  (pi-p-po  a-ri-na)
    fsub = ImageFont.truetype(F_BAY, sc(34))
    sub = "ᜉᜒᜉ᜔ᜉᜓ  ᜀᜇᜒᜈ"
    sb = dr.textbbox((0, 0), sub, font=fsub)
    engraved(dr, ((1280 - (sb[2] - sb[0]) / S) / 2, 208), sub, fsub,
             (60, 56, 38), (104, 98, 70), off=1)

    # ---- recessed form well ----------------------------------------------
    wx0, wy0, wx1, wy1 = 440, 300, 840, 612
    dr.rounded_rectangle([sc(wx0 - 6), sc(wy0 - 6), sc(wx1 + 6), sc(wy1 + 6)],
                         sc(20), outline=(14, 13, 7), width=sc(4))
    dr.rounded_rectangle([sc(wx0 - 3), sc(wy0 - 3), sc(wx1 + 3), sc(wy1 + 3)],
                         sc(18), outline=(88, 83, 60), width=sc(2))
    well = vgrad((sc(wx1 - wx0), sc(wy1 - wy0)),
                 [(0.0, (22, 21, 12)), (1.0, (38, 36, 21))])
    wmask = Image.new("L", well.size, 0)
    ImageDraw.Draw(wmask).rounded_rectangle([0, 0, well.size[0], well.size[1]],
                                            sc(16), fill=255)
    img.paste(well, (sc(wx0), sc(wy0)), wmask)
    dr = ImageDraw.Draw(img, "RGBA")
    # inner shadow line at the top of the well
    dr.line([sc(wx0 + 8), sc(wy0 + 8), sc(wx1 - 8), sc(wy0 + 8)],
            fill=(8, 8, 4, 160), width=sc(3))

    # ---- field slots ------------------------------------------------------
    f_lbl = ImageFont.truetype(F_COPPER, sc(17))
    fields = [("CUENTA", 390), ("CONTRASEÑA", 470), ("SERVIDOR", 550)]
    for label, fy in fields:
        engraved(dr, (475, fy - 24), label, f_lbl, (198, 190, 152),
                 (10, 9, 5), off=1)
        # sunken slot
        dr.rounded_rectangle([sc(475), sc(fy), sc(805), sc(fy + 46)],
                             sc(8), fill=(20, 19, 11))
        dr.line([sc(479), sc(fy + 3), sc(801), sc(fy + 3)],
                fill=(60, 56, 38), width=sc(2))
        dr.line([sc(479), sc(fy + 44), sc(801), sc(fy + 44)],
                fill=(76, 72, 50), width=sc(1))

    # ---- connect button (baked art, transparent Button overlays it) -------
    bx0, by0, bx1, by1 = 530, 648, 750, 706
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
    img = Image.alpha_composite(img.convert("RGBA"),
                                shadow.filter(ImageFilter.GaussianBlur(sc(6))))
    img = img.convert("RGB")
    img.paste(btn, (sc(bx0), sc(by0)), bmask)
    dr = ImageDraw.Draw(img, "RGBA")
    dr.rounded_rectangle([sc(bx0), sc(by0), sc(bx1), sc(by1)], sc(10),
                         outline=(24, 18, 6), width=sc(3))
    dr.line([sc(bx0 + 6), sc(by0 + 3), sc(bx1 - 6), sc(by0 + 3)],
            fill=(255, 230, 150, 170), width=sc(2))
    fbtn = ImageFont.truetype(F_COPPER, sc(30))
    bb = dr.textbbox((0, 0), "CONECTAR", font=fbtn)
    engraved(dr, ((1280 - (bb[2] - bb[0]) / S) / 2, by0 + 12), "CONECTAR",
             fbtn, (40, 28, 8), (238, 208, 120), off=1)

    # ---- baybayin footer strip --------------------------------------------
    ffoot = ImageFont.truetype(F_BAY, sc(26))
    foot = "ᜑᜈ᜔ᜇᜒᜃᜓ  ᜐᜄᜒᜆ᜔ᜆᜒᜄ᜔  ᜉᜒᜉ᜔ᜉᜓ"   # han-diko ma-gi-ttig pi-p-po
    fb2 = dr.textbbox((0, 0), foot, font=ffoot)
    engraved(dr, ((1280 - (fb2[2] - fb2[0]) / S) / 2, 742), foot, ffoot,
             (52, 49, 33), (92, 87, 62), off=1)

    # corner glyphs on the side pillars
    for gx, gy in [(34, 400), (1246, 400)]:
        engraved(dr, (gx - 13, gy - 40), "ᜇ",
                 ImageFont.truetype(F_BAY, sc(80)),
                 (56, 52, 35), (90, 85, 60), off=2)

    # ---- downscale --------------------------------------------------------
    img = img.resize((1280, 800), Image.LANCZOS)
    img.save(OUT)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
