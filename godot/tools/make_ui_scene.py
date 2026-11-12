#!/usr/bin/env python3
"""The art behind the S45 screens: the renders of our own game in
art/ui/renders/ (an arena in 3D, the coach and fighters, taken for the
owner-reviewed mockup) turned into what the client draws: the backdrops as
they are, the figures with the mockup's soft drop shadow baked in (CSS
drop-shadow(0 10px 14px rgba(0,0,0,.5))). Writes assets/ui/scene/*.png.
Run from godot/: python3 tools/make_ui_scene.py

The figures keep their pixel size; the shadow adds PAD px on every side
(the screens place them PAD px up and left of the mockup position).
"""
import os

from PIL import Image, ImageFilter

SRC = 'art/ui/renders'
OUT = 'assets/ui/scene'
PAD = 32
BACKDROPS = ['arena_bg', 'stage_bg']
FIGURES = ['coach', 'fighter_a', 'fighter_b', 'story_a', 'story_b', 'tour']


def shadowed(img):
    w, h = img.size
    out = Image.new('RGBA', (w + 2 * PAD, h + 2 * PAD), (0, 0, 0, 0))
    a = img.split()[3].point(lambda v: v * 128 // 255)
    sh = Image.new('RGBA', out.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 255), (PAD, PAD + 10), a)
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(7)))
    out.alpha_composite(img, (PAD, PAD))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for n in BACKDROPS:
        Image.open(f'{SRC}/{n}.webp').convert('RGB').save(f'{OUT}/{n}.png')
        print(f'{OUT}/{n}.png')
    for n in FIGURES:
        shadowed(Image.open(f'{SRC}/{n}.webp').convert('RGBA')).save(f'{OUT}/{n}.png')
        print(f'{OUT}/{n}.png')


if __name__ == '__main__':
    main()
