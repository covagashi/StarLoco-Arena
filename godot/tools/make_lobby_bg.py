#!/usr/bin/env python3
"""Lobby stonework. Contract: coach (40,150,320,350), actions
(400,210,824,270), chat (40,516,650,150), menus (720,526,510,140).
Run from godot/: python3 tools/make_lobby_bg.py.
"""
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter
from make_login_bg import S, W, H, sc, vgrad, word_tiles, engraved, F_COPPER, F_BAY


def main():
    img = vgrad((W, H), [(0, (57, 55, 36)), (1, (23, 25, 18))])
    noise = Image.effect_noise((W, H), 35).point(lambda v: 224 + v // 9)
    img = ImageChops.multiply(img, noise.convert('RGB')).convert('RGBA')
    d = ImageDraw.Draw(img)
    def slab(rect, fill, rim=(106, 98, 65), radius=14):
        x, y, w, h = rect
        shadow = Image.new('RGBA', img.size)
        ImageDraw.Draw(shadow).rounded_rectangle([sc(x),sc(y+5),sc(x+w),sc(y+h+5)],sc(radius),fill=(0,0,0,145))
        img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(sc(4))))
        top = tuple(min(255, c+22) for c in fill)
        bottom = tuple(max(0, c-17) for c in fill)
        face = vgrad((sc(w),sc(h)), [(0,top),(0.45,fill),(1,bottom)])
        mask = Image.new('L', face.size)
        ImageDraw.Draw(mask).rounded_rectangle([0,0,sc(w),sc(h)],sc(radius),fill=255)
        img.paste(face,(sc(x),sc(y)),mask)
        d.rounded_rectangle([sc(x),sc(y),sc(x+w),sc(y+h)],sc(radius),outline=(16,16,9),width=sc(3))
        d.line([sc(x+12),sc(y+3),sc(x+w-12),sc(y+3)],fill=tuple(min(255,c+65) for c in fill),width=sc(2))
        d.line([sc(x+3),sc(y+14),sc(x+3),sc(y+h-14)],fill=rim,width=sc(1))
    slab((18, 18, 1244, 684), (44, 44, 30), radius=24)
    d.rounded_rectangle([sc(29),sc(29),sc(1251),sc(691)],sc(20),outline=(92,87,59),width=sc(2))
    d.rounded_rectangle([sc(35),sc(35),sc(1245),sc(685)],sc(17),outline=(19,20,13),width=sc(3))
    for x,y in [(30,30),(1250,30),(30,690),(1250,690)]:
        d.ellipse([sc(x-7),sc(y-7),sc(x+7),sc(y+7)],fill=(33,32,21),outline=(116,104,68),width=sc(2))
        d.ellipse([sc(x-2),sc(y-3),sc(x+2),sc(y+1)],fill=(157,140,90))
    slab((40, 150, 320, 350), (24, 29, 23), radius=100)
    # Coach pedestal: a deliberately quiet stage for the animated paper doll.
    d.ellipse([sc(90), sc(424), sc(310), sc(470)], fill=(13, 17, 13), outline=(99, 92, 60), width=sc(2))
    d.ellipse([sc(105), sc(428), sc(295), sc(451)], fill=(64, 64, 42))
    for x in (65, 326):
        for i, ch in enumerate('ᜃᜄᜅᜆᜇ'):
            engraved(d, (x-9, 225+i*36), ch, ImageFont.truetype(F_BAY, sc(22)), (67, 72, 47), (16, 19, 12), off=1)
    slab((40, 516, 650, 150), (20, 25, 21))
    slab((720, 516, 510, 150), (32, 34, 24))
    for x, y, w, h, color in [(400,210,264,126,(63,79,42)), (680,210,264,126,(149,111,39)), (960,210,264,126,(63,65,44)), (400,352,264,92,(62,57,43)), (680,352,264,92,(62,57,43)), (960,352,264,92,(62,57,43))]:
        slab((x,y,w,h),color)
    word_tiles(img, 'ARENA', ImageFont.truetype(F_COPPER, sc(72)), 104, 120,
               angles=[-5,3,-2,4,-3], yoffs=[0,3,0,4,0])
    # Nine small carved-line menu symbols, in retail menu order.
    icons = Image.new('RGBA', (32 * 9 * S, 32 * S))
    paths = [
        [[(6,8),(26,8)],[(6,16),(26,16)],[(6,24),(26,24)]],
        [[(5,25),(5,20),(13,16),(21,20),(21,25)],[(22,10),(27,15),(27,25)]],
        [[(6,26),(6,17)],[(15,26),(15,10)],[(24,26),(24,5)]],
        [[(5,10),(27,10),(27,26),(5,26),(5,10)],[(11,10),(11,5),(21,5),(21,10)]],
        [[(6,6),(26,6),(23,18),(16,22),(9,18),(6,6)],[(16,22),(16,27)],[(10,27),(22,27)]],
        [[(5,8),(27,8),(27,27),(5,27),(5,8)],[(5,14),(27,14)],[(10,4),(10,10)],[(22,4),(22,10)]],
        [[(16,4),(20,11),(28,12),(22,18),(24,27),(16,23),(8,27),(10,18),(4,12),(12,11),(16,4)]],
        [[(5,6),(27,6),(27,22),(15,22),(8,28),(8,22),(5,22),(5,6)]],
        [[(10,10),(11,6),(20,5),(24,9),(23,14),(16,19),(16,22)],[(16,26),(16,28)]],
    ]
    di = ImageDraw.Draw(icons)
    for i, strokes in enumerate(paths):
        for stroke in strokes:
            di.line([(sc(i*32+x),sc(y)) for x,y in stroke], fill=(229,217,174), width=sc(2), joint='curve')
    di.ellipse([sc(9+32),sc(4),sc(17+32),sc(12)], outline=(229,217,174), width=sc(2))
    icons.resize((32*9,32), Image.Resampling.LANCZOS).save('assets/ui/lobby_icons.png')
    img.convert('RGB').resize((1280,720), Image.Resampling.LANCZOS).save('assets/ui/lobby_bg.png')


if __name__ == '__main__':
    main()
