#!/usr/bin/env python3
"""Coach creation background — same carved-stone family as the login.
Output: godot/assets/ui/creation_bg.png  (1280x720)

Layout contract (final px) — creation_screen.gd overlays controls here:
    name field   (260, 204, 340, 44)
    sex buttons  (260,286,165,40) (435,286,165,40)  — drawn recesses
    hair grid    cells 34px gap 8 at y=362 and y=404, x=262+i*42
    skin grid    cells 34px gap 8 at y=474 and y=516, x=262+i*42
    doll niche   arch (700,160)..(1050,580); doll feet ~y=545 centre 875
    dir arrows   (665,330,48,38) prev  (1055,330,48,38) next
    random btn   (430,620,200,52)
    validate btn (650,620,200,52)
    quit btn     (1205,28,44,44)
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_login_bg import (S, W, H, sc, vgrad, engraved, bezier,
                           tapered_poly, letter_tile, word_tiles,
                           F_COPPER, F_TAHOMA, F_BAY)
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

OUT = "assets/ui/creation_bg.png"


def main():
    img = vgrad((W, H), [(0.0, (30, 29, 19)), (0.5, (42, 40, 25)),
                         (1.0, (20, 19, 12))]).convert("RGB")
    dr = ImageDraw.Draw(img, "RGBA")

    noise = Image.effect_noise((W, H), 60).convert("L")
    img = ImageChops.multiply(
        img, noise.point(lambda v: 215 + v // 8).convert("RGB"))
    dr = ImageDraw.Draw(img, "RGBA")

    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([sc(-260), sc(-200), W + sc(260), H + sc(200)], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(sc(120)))
    img = Image.composite(img, Image.new("RGB", (W, H), (8, 8, 4)), vig)
    dr = ImageDraw.Draw(img, "RGBA")

    # ---- stone frame (same as login) -------------------------------------
    m, th = 18, 30
    dr.rounded_rectangle([sc(m), sc(m), W - sc(m), H - sc(m)],
                         sc(26), fill=(52, 49, 34))
    dr.line([sc(m + 4), sc(m + th + 6), sc(m + 4), H - sc(m + th + 6)],
            fill=(96, 90, 66), width=sc(3))
    dr.line([sc(m + 4), sc(m + 4), W - sc(m + 4), sc(m + 4)],
            fill=(96, 90, 66), width=sc(3))
    dr.line([W - sc(m + 5), sc(m + th + 6), W - sc(m + 5), H - sc(m + th)],
            fill=(12, 11, 6), width=sc(3))
    dr.line([sc(m), H - sc(m + 5), W - sc(m + 5), H - sc(m + 5)],
            fill=(12, 11, 6), width=sc(3))
    dr.rounded_rectangle([sc(m + th - 6), sc(m + th - 6),
                          W - sc(m + th - 6), H - sc(m + th - 6)],
                         sc(14), outline=(18, 17, 10), width=sc(4))
    dr.rounded_rectangle([sc(m + th - 2), sc(m + th - 2),
                          W - sc(m + th - 2), H - sc(m + th - 2)],
                         sc(14), outline=(74, 70, 50), width=sc(2))
    for cx, cy in [(m + th // 2, m + th // 2), (W / S - m - th // 2, m + th // 2),
                   (m + th // 2, H / S - m - th // 2),
                   (W / S - m - th // 2, H / S - m - th // 2)]:
        dr.ellipse([sc(cx - 7), sc(cy - 7), sc(cx + 7), sc(cy + 7)],
                   fill=(38, 35, 22), outline=(90, 85, 62), width=sc(2))
        dr.ellipse([sc(cx - 2), sc(cy - 3), sc(cx + 3), sc(cy + 2)],
                   fill=(120, 112, 82))

    # ---- title: letter tiles + baybayin subtitle --------------------------
    fword = ImageFont.truetype(F_COPPER, sc(92))
    img = img.convert("RGBA")
    word_tiles(img, "CREA TU JEFE", fword, 138, 128,
               angles=[-6, 2, -4, 5, 0, -3, 4, 0, -5, 3, -2, 6],
               yoffs=[0, 4, 6, 4, 0, 3, 5, 0, 2, 5, 4, 0])
    dr = ImageDraw.Draw(img, "RGBA")
    fsub = ImageFont.truetype(F_BAY, sc(26))
    sub = "ᜃᜇᜓᜅ᜔ ᜈᜅ᜔ ᜑᜒᜋᜉ᜔"
    sb = dr.textbbox((0, 0), sub, font=fsub)
    engraved(dr, ((1280 - (sb[2] - sb[0]) / S) / 2, 138), sub, fsub,
             (58, 54, 36), (98, 93, 66), off=1)

    # ---- left form well ----------------------------------------------------
    wx0, wy0, wx1, wy1 = 230, 160, 640, 580
    dr.rounded_rectangle([sc(wx0 - 6), sc(wy0 - 6), sc(wx1 + 6), sc(wy1 + 6)],
                         sc(20), outline=(14, 13, 7), width=sc(4))
    dr.rounded_rectangle([sc(wx0 - 3), sc(wy0 - 3), sc(wx1 + 3), sc(wy1 + 3)],
                         sc(18), outline=(88, 83, 60), width=sc(2))
    well = vgrad((sc(wx1 - wx0), sc(wy1 - wy0)),
                 [(0.0, (22, 21, 12)), (1.0, (38, 36, 21))])
    wmask = Image.new("L", well.size, 0)
    ImageDraw.Draw(wmask).rounded_rectangle(
        [0, 0, well.size[0], well.size[1]], sc(16), fill=255)
    img.convert("RGB").paste(well, (sc(wx0), sc(wy0)), wmask)
    img.paste(well, (sc(wx0), sc(wy0)), wmask)
    dr = ImageDraw.Draw(img, "RGBA")
    dr.line([sc(wx0 + 8), sc(wy0 + 8), sc(wx1 - 8), sc(wy0 + 8)],
            fill=(8, 8, 4, 160), width=sc(3))

    f_lbl = ImageFont.truetype(F_COPPER, sc(17))

    # name
    engraved(dr, (260, 180), "NOMBRE DEL JEFE", f_lbl,
             (198, 190, 152), (10, 9, 5), off=1)
    dr.rounded_rectangle([sc(260), sc(204), sc(600), sc(248)],
                         sc(8), fill=(20, 19, 11))
    dr.line([sc(264), sc(207), sc(596), sc(207)], fill=(60, 56, 38), width=sc(2))
    dr.line([sc(264), sc(246), sc(596), sc(246)], fill=(76, 72, 50), width=sc(1))

    # sex toggle recesses
    engraved(dr, (260, 262), "SEXO", f_lbl,
             (198, 190, 152), (10, 9, 5), off=1)
    for bx in (260, 435):
        dr.rounded_rectangle([sc(bx), sc(286), sc(bx + 165), sc(326)],
                             sc(8), fill=(20, 19, 11))
        dr.line([sc(bx + 4), sc(289), sc(bx + 161), sc(289)],
                fill=(60, 56, 38), width=sc(2))
        dr.line([sc(bx + 4), sc(324), sc(bx + 161), sc(324)],
                fill=(76, 72, 50), width=sc(1))

    # swatch grid recesses (hair then skin)
    for lbl, gy in [("COLOR DE PELO", 362), ("COLOR DE PIEL", 474)]:
        engraved(dr, (260, gy - 22), lbl, f_lbl,
                 (198, 190, 152), (10, 9, 5), off=1)
        for row in (gy, gy + 42):
            for i in range(8):
                cx0 = 262 + i * 42
                dr.rounded_rectangle([sc(cx0), sc(row), sc(cx0 + 34),
                                      sc(row + 34)], sc(6), fill=(20, 19, 11))
                dr.line([sc(cx0 + 3), sc(row + 2), sc(cx0 + 31), sc(row + 2)],
                        fill=(58, 54, 36), width=sc(1))

    # ---- doll alcove (right) ----------------------------------------------
    ax0, ay0, ax1, ay1 = 700, 160, 1050, 580
    # carved arch: rectangle + semicircular top, dark interior
    arch_w = ax1 - ax0
    arch = Image.new("L", (sc(arch_w + 40), sc(ay1 - ay0 + 30)), 0)
    ad = ImageDraw.Draw(arch)
    ad.rectangle([sc(20), sc(110), sc(arch_w + 20), sc(ay1 - ay0 + 20)],
                 fill=255)
    ad.ellipse([sc(20), sc(10), sc(arch_w + 20), sc(210)], fill=255)
    arch = arch.filter(ImageFilter.GaussianBlur(sc(2)))
    # stone rim: draw the arch enlarged in rim colour, then inner arch dark
    rim = Image.new("RGBA", arch.size, (0, 0, 0, 0))
    rim.paste((96, 90, 66), (0, 0), arch)
    inner_m = arch.transform(arch.size, Image.AFFINE,
                             (1.06, 0, -sc(10), 0, 1.06, sc(-6)))
    inner_m = inner_m.filter(ImageFilter.GaussianBlur(sc(1)))
    darkfill = Image.new("RGBA", arch.size, (0, 0, 0, 0))
    darkfill.paste((10, 9, 5), (0, 0), inner_m)
    img.alpha_composite(rim, (sc(ax0 - 20), sc(ay0 - 15)))
    img.alpha_composite(darkfill, (sc(ax0 - 20), sc(ay0 - 15)))
    # interior gradient through the inner arch mask
    inner = vgrad((sc(arch_w), sc(ay1 - ay0)),
                  [(0.0, (14, 13, 7)), (0.6, (34, 32, 18)),
                   (1.0, (48, 44, 26))])
    imask = Image.new("L", (sc(arch_w), sc(ay1 - ay0)), 0)
    imd = ImageDraw.Draw(imask)
    imd.rectangle([0, sc(95), sc(arch_w), sc(ay1 - ay0)], fill=255)
    imd.ellipse([0, 0, sc(arch_w), sc(190)], fill=255)
    img.convert("RGB").paste(inner, (sc(ax0), sc(ay0 + 10)), imask)
    img.paste(inner, (sc(ax0), sc(ay0 + 10)), imask)
    dr = ImageDraw.Draw(img, "RGBA")
    # floor shadow inside the niche
    fl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(fl).ellipse([sc(ax0 + 60), sc(525), sc(ax1 - 60), sc(565)],
                               fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img,
                                fl.filter(ImageFilter.GaussianBlur(sc(8))))
    dr = ImageDraw.Draw(img, "RGBA")

    # arrow sockets flanking the niche
    for sx, flip in ((665, False), (1055, True)):
        dr.rounded_rectangle([sc(sx), sc(330), sc(sx + 48), sc(368)],
                             sc(19), fill=(20, 19, 11))
        dr.line([sc(sx + 4), sc(333), sc(sx + 44), sc(333)],
                fill=(60, 56, 38), width=sc(2))
        # engraved arrowhead inside the socket
        cxm, cym = sx + 24, 349
        tri = [(cxm - 9 if not flip else cxm + 9, cym - 12),
               (cxm + 9 if not flip else cxm - 9, cym),
               (cxm - 9 if not flip else cxm + 9, cym + 12)]
        dr.polygon([(sc(px), sc(py + 1)) for px, py in tri],
                   fill=(92, 87, 62))
        dr.polygon([(sc(px), sc(py)) for px, py in tri],
                   fill=(198, 190, 152))

    # ---- bottom buttons ----------------------------------------------------
    for bx0, label, gold in [(430, "ALEATORIO", False),
                             (650, "VALIDAR", True)]:
        bx1, by0, by1 = bx0 + 200, 620, 672
        if gold:
            fill = vgrad((sc(200), sc(52)),
                         [(0.0, (196, 154, 58)), (0.5, (150, 112, 34)),
                          (1.0, (110, 80, 22))])
        else:
            fill = vgrad((sc(200), sc(52)),
                         [(0.0, (74, 70, 50)), (0.5, (58, 55, 38)),
                          (1.0, (40, 38, 24))])
        bm = Image.new("L", fill.size, 0)
        ImageDraw.Draw(bm).rounded_rectangle([0, 0, sc(200), sc(52)],
                                             sc(10), fill=255)
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            [sc(bx0), sc(by0 + 5), sc(bx1), sc(by1 + 5)], sc(10),
            fill=(0, 0, 0, 140))
        img = Image.alpha_composite(
            img, shadow.filter(ImageFilter.GaussianBlur(sc(6))))
        img.paste(fill, (sc(bx0), sc(by0)), bm)
        dr = ImageDraw.Draw(img, "RGBA")
        dr.rounded_rectangle([sc(bx0), sc(by0), sc(bx1), sc(by1)], sc(10),
                             outline=(24, 18, 6), width=sc(3))
        dr.line([sc(bx0 + 6), sc(by0 + 3), sc(bx1 - 6), sc(by0 + 3)],
                fill=(255, 230, 150, 150) if gold else (150, 145, 110, 120),
                width=sc(2))
        fbtn = ImageFont.truetype(F_COPPER, sc(26))
        bb = dr.textbbox((0, 0), label, font=fbtn)
        engraved(dr, ((bx0 + bx1) / 2 - (bb[2] - bb[0]) / S / 2, by0 + 12),
                 label, fbtn,
                 (40, 28, 8) if gold else (16, 14, 8),
                 (238, 208, 120) if gold else (140, 134, 100), off=1)

    # quit socket top-right
    dr.ellipse([sc(1205), sc(28), sc(1249), sc(72)], fill=(20, 19, 11))
    dr.ellipse([sc(1205), sc(28), sc(1249), sc(72)],
               outline=(90, 85, 62), width=sc(2))
    fq = ImageFont.truetype(F_COPPER, sc(22))
    engraved(dr, (1217, 38), "X", fq, (198, 190, 152), (10, 9, 5), off=1)

    # baybayin columns flanking the form well
    fcol = ImageFont.truetype(F_BAY, sc(40))
    for gx in (185, 665):
        for i, gch in enumerate("ᜃᜄᜅᜆᜇᜈᜑ"):
            engraved(dr, (gx - 20, 190 + i * 50), gch, fcol,
                     (50, 47, 30), (84, 79, 54), off=1)

    img = img.convert("RGB").resize((1280, 720), Image.LANCZOS)
    img.save(OUT)
    print("wrote", OUT, img.size)


if __name__ == "__main__":
    main()
