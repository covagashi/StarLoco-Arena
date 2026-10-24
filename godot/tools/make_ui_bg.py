#!/usr/bin/env python3
"""Backdrop for the full screens (login, coach creation, lobby): the
stonework of the old baked screens — olive gradient, stone grain, an
engraved outer frame with four rivets — with no slots, so any layout sits
on it. Our own art, not retail. Writes assets/ui/ui_bg.png (1280x720).
Run from godot/: python3 tools/make_ui_bg.py
"""
from PIL import Image, ImageChops, ImageDraw, ImageFilter
from make_login_bg import S, W, H, sc, vgrad


def main():
    img = vgrad((W, H), [(0, (57, 55, 36)), (1, (23, 25, 18))])
    noise = Image.effect_noise((W, H), 35).point(lambda v: 224 + v // 9)
    img = ImageChops.multiply(img, noise.convert('RGB')).convert('RGBA')
    d = ImageDraw.Draw(img)
    # the outer slab, lit from the top
    shadow = Image.new('RGBA', img.size)
    ImageDraw.Draw(shadow).rounded_rectangle([sc(18), sc(23), sc(1262), sc(707)], sc(24),
                                             fill=(0, 0, 0, 145))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(sc(4))))
    fill = (44, 44, 30)
    face = vgrad((sc(1244), sc(684)), [(0, tuple(c + 22 for c in fill)), (0.45, fill),
                                       (1, tuple(c - 17 for c in fill))])
    grain = Image.effect_noise(face.size, 30).point(lambda v: 228 + v // 10)
    face = ImageChops.multiply(face, grain.convert('RGB'))
    mask = Image.new('L', face.size)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sc(1244), sc(684)], sc(24), fill=255)
    img.paste(face, (sc(18), sc(18)), mask)
    d.rounded_rectangle([sc(18), sc(18), sc(1262), sc(702)], sc(24), outline=(16, 16, 9), width=sc(3))
    d.line([sc(30), sc(21), sc(1250), sc(21)], fill=(109, 109, 95), width=sc(2))
    d.rounded_rectangle([sc(29), sc(29), sc(1251), sc(691)], sc(20), outline=(92, 87, 59), width=sc(2))
    d.rounded_rectangle([sc(35), sc(35), sc(1245), sc(685)], sc(17), outline=(19, 20, 13), width=sc(3))
    for x, y in [(30, 30), (1250, 30), (30, 690), (1250, 690)]:
        d.ellipse([sc(x - 7), sc(y - 7), sc(x + 7), sc(y + 7)], fill=(33, 32, 21),
                  outline=(116, 104, 68), width=sc(2))
        d.ellipse([sc(x - 2), sc(y - 3), sc(x + 2), sc(y + 1)], fill=(157, 140, 90))
    img.convert('RGB').resize((W // S, H // S), Image.LANCZOS).save('assets/ui/ui_bg.png')
    print('assets/ui/ui_bg.png')


if __name__ == '__main__':
    main()
