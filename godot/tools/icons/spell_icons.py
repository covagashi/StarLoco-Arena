#!/usr/bin/env python3
"""S38: the spell icons, drawn in code (no hand-painted images), in the
owner's pick from the option sheet (2026-11-13: "b"): a white glyph on the
spell's element colour, cut on the slant, an ink rule along the top. One
glyph per spell (not per effect shape: shape + element would give 35 equal
neutral auras), composed from a small vocabulary of pictograms below.
Writes assets/ui/spells/<id>.png (96 px), which the fight's spell bar and
the panels read before the retail art.
Run from godot/: python3 tools/icons/spell_icons.py [--sheet out.png]
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = 'assets/ui/spells'
PX = 96
S = 4
N = PX * S
INK = (28, 32, 48)
EL = {'neutral': (120, 126, 146), 'fire': (232, 84, 52), 'water': (47, 116, 240),
      'air': (54, 180, 140), 'earth': (176, 120, 52)}


class Pen:
    """Draws in unit coordinates (0..1 inside the icon's glyph box)."""

    def __init__(self, d, col):
        self.d, self.c = d, col
        self.w = int(N * 0.068)

    def P(self, x, y):
        m = 0.17 * N
        return (m + x * (N - 2 * m), m + y * (N - 2 * m))

    def ln(self, *pts, k=1.0):
        self.d.line([self.P(*p) for p in pts], fill=self.c, width=int(self.w * k), joint='curve')
        for p in (pts[0], pts[-1]):   # round caps
            x, y = self.P(*p)
            r = self.w * k / 2
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=self.c)

    def poly(self, *pts):
        self.d.polygon([self.P(*p) for p in pts], fill=self.c)

    def outline(self, *pts, k=1.0):
        self.ln(*(pts + (pts[0],)), k=k)

    def disc(self, cx, cy, r):
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        self.d.ellipse([a, b], fill=self.c)

    def ring(self, cx, cy, r, k=1.0):
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        self.d.ellipse([a, b], outline=self.c, width=int(self.w * k))

    def arc(self, cx, cy, r, a0, a1, k=1.0):
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        self.d.arc([a, b], a0, a1, fill=self.c, width=int(self.w * k))

    def hole(self, cx, cy, r, col):
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        self.d.ellipse([a, b], fill=col)

    # ---- pictograms
    def sword(self, x0, y0, x1, y1, k=1.0):
        self.ln((x0, y0), (x1, y1), k=1.4 * k)
        dx, dy = x1 - x0, y1 - y0
        l = math.hypot(dx, dy)
        nx, ny = -dy / l, dx / l
        gx, gy = x0 + dx * 0.22, y0 + dy * 0.22
        self.ln((gx - nx * .2 * k, gy - ny * .2 * k), (gx + nx * .2 * k, gy + ny * .2 * k))

    def arrow(self, x0, y0, x1, y1, head=0.22):
        self.ln((x0, y0), (x1, y1))
        a = math.atan2(y1 - y0, x1 - x0)
        for s in (1, -1):
            self.ln((x1, y1), (x1 - head * math.cos(a + s * 0.55), y1 - head * math.sin(a + s * 0.55)))

    def fletched(self, x0, y0, x1, y1):
        self.arrow(x0, y0, x1, y1, 0.2)
        a = math.atan2(y1 - y0, x1 - x0)
        for t in (0.0, 0.12):
            bx, by = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for s in (1, -1):
                self.ln((bx, by), (bx - .14 * math.cos(a + s * 0.8), by - .14 * math.sin(a + s * 0.8)), k=0.7)

    def star(self, cx, cy, r, n=5, inner=0.45):
        pts = []
        for i in range(n * 2):
            a = -math.pi / 2 + i * math.pi / n
            rr = r if i % 2 == 0 else r * inner
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        self.poly(*pts)

    def heart(self, cx, cy, s):
        self.disc(cx - s * .25, cy - s * .12, s * .28)
        self.disc(cx + s * .25, cy - s * .12, s * .28)
        self.poly((cx - s * .5, cy - s * .05), (cx + s * .5, cy - s * .05), (cx, cy + s * .55))

    def shield(self, cx, cy, s, fill=False):
        pts = ((cx - s * .45, cy - s * .45), (cx + s * .45, cy - s * .45), (cx + s * .45, cy + s * .05),
               (cx, cy + s * .55), (cx - s * .45, cy + s * .05))
        if fill:
            self.poly(*pts)
        else:
            self.outline(*pts)

    def flame(self, cx, cy, s):
        self.poly((cx, cy - s * .55), (cx + s * .32, cy - s * .05), (cx + s * .3, cy + s * .3), (cx, cy + s * .5),
                  (cx - s * .3, cy + s * .3), (cx - s * .32, cy - s * .05), (cx - s * .1, cy - s * .2))

    def drop(self, cx, cy, s):
        self.disc(cx, cy + s * .15, s * .3)
        self.poly((cx, cy - s * .5), (cx + s * .28, cy + s * .08), (cx - s * .28, cy + s * .08))

    def cloud(self, cx, cy, s):
        for dx, dy, r in ((-.25, .05, .22), (0, -.1, .28), (.27, .05, .2)):
            self.disc(cx + dx * s, cy + dy * s, r * s)
        self.poly((cx - .45 * s, cy + .05 * s), (cx + .45 * s, cy + .05 * s), (cx + .45 * s, cy + .25 * s),
                  (cx - .45 * s, cy + .25 * s))

    def wind(self, cx, cy, s):
        for i, y in enumerate((-.25, 0, .25)):
            w = (.5, .65, .4)[i]
            self.ln((cx - w * s, cy + y * s), (cx + w * s * .6, cy + y * s), k=0.8)
            self.arc(cx + w * s * .6, cy + y * s - .1 * s, .1 * s, 270, 450, k=0.8)

    def bolt(self, cx, cy, s):
        self.poly((cx + .1 * s, cy - .55 * s), (cx - .3 * s, cy + .05 * s), (cx, cy + .05 * s),
                  (cx - .1 * s, cy + .55 * s), (cx + .3 * s, cy - .05 * s), (cx, cy - .05 * s))

    def rock(self, cx, cy, s):
        self.poly((cx - .45 * s, cy + .35 * s), (cx - .35 * s, cy - .15 * s), (cx - .05 * s, cy - .4 * s),
                  (cx + .3 * s, cy - .25 * s), (cx + .45 * s, cy + .35 * s))

    def skull(self, cx, cy, s, bg):
        self.disc(cx, cy - .08 * s, .38 * s)
        self.poly((cx - .22 * s, cy + .15 * s), (cx + .22 * s, cy + .15 * s), (cx + .18 * s, cy + .42 * s),
                  (cx - .18 * s, cy + .42 * s))
        for dx in (-.15, .15):
            self.hole(cx + dx * s, cy - .05 * s, .1 * s, bg)

    def eye(self, cx, cy, s, bg):
        pts = [(cx + .5 * s * math.cos(a), cy + .28 * s * math.sin(a)) for a in [i * math.pi / 12 for i in range(24)]]
        self.poly(*pts)
        self.hole(cx, cy, .19 * s, bg)
        self.disc(cx, cy, .1 * s)

    def paw(self, cx, cy, s):
        self.disc(cx, cy + .15 * s, .25 * s)
        for dx, dy in ((-.3, -.15), (-.1, -.33), (.1, -.33), (.3, -.15)):
            self.disc(cx + dx * s, cy + dy * s, .11 * s)

    def clock(self, cx, cy, s):
        self.ring(cx, cy, .42 * s)
        self.ln((cx, cy), (cx, cy - .26 * s))
        self.ln((cx, cy), (cx + .2 * s, cy + .08 * s))

    def hourglass(self, cx, cy, s):
        self.ln((cx - .3 * s, cy - .45 * s), (cx + .3 * s, cy - .45 * s))
        self.ln((cx - .3 * s, cy + .45 * s), (cx + .3 * s, cy + .45 * s))
        self.poly((cx - .25 * s, cy - .4 * s), (cx + .25 * s, cy - .4 * s), (cx, cy))
        self.outline((cx, cy), (cx + .25 * s, cy + .4 * s), (cx - .25 * s, cy + .4 * s), k=0.7)

    def coin(self, cx, cy, s, bg):
        self.disc(cx, cy, .4 * s)
        self.hole(cx, cy, .25 * s, bg)
        self.disc(cx, cy, .13 * s)

    def die(self, cx, cy, s, bg):
        h = .38 * s
        self.poly((cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h), (cx - h, cy + h))
        for dx, dy in ((-.18, -.18), (.18, .18), (0, 0), (.18, -.18), (-.18, .18)):
            self.hole(cx + dx * s, cy + dy * s, .07 * s, bg)

    def clover(self, cx, cy, s):
        for dx, dy in ((0, -.22), (.22, 0), (0, .22), (-.22, 0)):
            self.disc(cx + dx * s, cy + dy * s, .18 * s)
        self.ln((cx, cy), (cx + .15 * s, cy + .5 * s), k=0.7)

    def plus(self, cx, cy, s, k=1.2):
        self.ln((cx - .3 * s, cy), (cx + .3 * s, cy), k=k)
        self.ln((cx, cy - .3 * s), (cx, cy + .3 * s), k=k)

    def minus(self, cx, cy, s, k=1.2):
        self.ln((cx - .3 * s, cy), (cx + .3 * s, cy), k=k)

    def up(self, cx, cy, s):
        self.poly((cx, cy - .4 * s), (cx + .35 * s, cy), (cx + .14 * s, cy), (cx + .14 * s, cy + .4 * s),
                  (cx - .14 * s, cy + .4 * s), (cx - .14 * s, cy), (cx - .35 * s, cy))

    def down(self, cx, cy, s):
        self.poly((cx, cy + .4 * s), (cx + .35 * s, cy), (cx + .14 * s, cy), (cx + .14 * s, cy - .4 * s),
                  (cx - .14 * s, cy - .4 * s), (cx - .14 * s, cy), (cx - .35 * s, cy))

    def swirl(self, cx, cy, s):
        self.arc(cx, cy, .42 * s, 200, 520)
        self.arc(cx, cy, .22 * s, 20, 300)

    def burst(self, cx, cy, s, n=8):
        self.star(cx, cy, .5 * s, n, 0.5)

    def leaf(self, cx, cy, s, a=-45):
        r = math.radians(a)
        pts = []
        for i in range(17):
            t = i / 16
            y = -.5 + t
            x = .28 * math.sin(math.pi * t)
            pts.append((x, y))
        pts += [(-x, y) for x, y in reversed(pts)]
        pts = [(cx + (x * math.cos(r) - y * math.sin(r)) * s, cy + (x * math.sin(r) + y * math.cos(r)) * s) for x, y in pts]
        self.poly(*pts)

    def tree(self, cx, cy, s):
        self.ln((cx, cy + .5 * s), (cx, cy), k=1.3)
        for dx, dy, r in ((0, -.2, .3), (-.22, -.02, .2), (.22, -.02, .2)):
            self.disc(cx + dx * s, cy + dy * s, r * s)

    def doll(self, cx, cy, s, bg):
        self.disc(cx, cy - .3 * s, .18 * s)
        self.poly((cx - .3 * s, cy - .08 * s), (cx + .3 * s, cy - .08 * s), (cx + .18 * s, cy + .5 * s),
                  (cx - .18 * s, cy + .5 * s))
        self.ln((cx - .1 * s, cy + .15 * s), (cx + .1 * s, cy + .3 * s), k=0.5)
        self.d.line([self.P(cx - .1 * s, cy + .15 * s), self.P(cx + .1 * s, cy + .3 * s)], fill=bg, width=int(self.w * .5))
        self.d.line([self.P(cx + .1 * s, cy + .15 * s), self.P(cx - .1 * s, cy + .3 * s)], fill=bg, width=int(self.w * .5))

    def flask(self, cx, cy, s):
        self.poly((cx - .1 * s, cy - .45 * s), (cx + .1 * s, cy - .45 * s), (cx + .1 * s, cy - .15 * s),
                  (cx + .38 * s, cy + .4 * s), (cx - .38 * s, cy + .4 * s), (cx - .1 * s, cy - .15 * s))

    def mug(self, cx, cy, s, bg):
        self.poly((cx - .32 * s, cy - .3 * s), (cx + .2 * s, cy - .3 * s), (cx + .2 * s, cy + .4 * s),
                  (cx - .32 * s, cy + .4 * s))
        self.arc(cx + .2 * s, cy + .05 * s, .18 * s, 270, 450)
        self.cloud(cx - .06 * s, cy - .38 * s, .45 * s)

    def bamboo(self, x0, y0, x1, y1):
        self.ln((x0, y0), (x1, y1), k=1.5)
        for t in (.33, .66):
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            self.ring(x, y, .05, k=0.4)

    def foot(self, cx, cy, s):
        self.poly((cx - .2 * s, cy - .45 * s), (cx + .1 * s, cy - .45 * s), (cx + .1 * s, cy + .15 * s),
                  (cx + .45 * s, cy + .25 * s), (cx + .45 * s, cy + .45 * s), (cx - .2 * s, cy + .45 * s))

    def fist(self, cx, cy, s):
        self.poly((cx - .35 * s, cy - .2 * s), (cx + .35 * s, cy - .2 * s), (cx + .35 * s, cy + .25 * s),
                  (cx + .1 * s, cy + .4 * s), (cx - .35 * s, cy + .3 * s))
        for i in range(4):
            self.disc(cx - .26 * s + i * .175 * s, cy - .25 * s, .09 * s)

    def spikes(self, cx, cy, s):
        self.ln((cx - .5 * s, cy + .3 * s), (cx + .5 * s, cy + .3 * s))
        for i in range(4):
            x = cx - .36 * s + i * .24 * s
            self.poly((x - .1 * s, cy + .3 * s), (x + .1 * s, cy + .3 * s), (x, cy - .25 * s))

    def chain(self, x0, y0, x1, y1, n=3):
        for i in range(n):
            t = (i + .5) / n
            self.ring(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, .11, k=0.7)

    def ghost(self, cx, cy, s, bg):
        self.disc(cx, cy - .12 * s, .35 * s)
        self.poly((cx - .35 * s, cy - .12 * s), (cx + .35 * s, cy - .12 * s), (cx + .35 * s, cy + .45 * s),
                  (cx + .18 * s, cy + .32 * s), (cx, cy + .45 * s), (cx - .18 * s, cy + .32 * s), (cx - .35 * s, cy + .45 * s))
        for dx in (-.13, .13):
            self.hole(cx + dx * s, cy - .12 * s, .07 * s, bg)

    def shovel(self, x0, y0, x1, y1):
        self.ln((x0, y0), (x1, y1), k=1.0)
        a = math.atan2(y1 - y0, x1 - x0)
        cx, cy = x1 + .1 * math.cos(a), y1 + .1 * math.sin(a)
        self.disc(cx, cy, .17)
        self.ln((x0 - .08 * math.sin(a), y0 + .08 * math.cos(a)), (x0 + .08 * math.sin(a), y0 - .08 * math.cos(a)))

    def bird(self, cx, cy, s):
        self.arc(cx - .22 * s, cy, .25 * s, 200, 340, k=1.1)
        self.arc(cx + .22 * s, cy, .25 * s, 200, 340, k=1.1)

    def bubble(self, cx, cy, s):
        self.ring(cx, cy, .3 * s, k=0.9)
        self.ring(cx + .32 * s, cy - .32 * s, .12 * s, k=0.7)
        self.arc(cx, cy, .18 * s, 200, 260, k=0.6)

    def target(self, cx, cy, s):
        self.ring(cx, cy, .42 * s, k=0.8)
        self.ring(cx, cy, .2 * s, k=0.8)
        self.disc(cx, cy, .06 * s)

    def mask(self, cx, cy, s, bg):
        self.poly((cx - .45 * s, cy - .2 * s), (cx + .45 * s, cy - .2 * s), (cx + .38 * s, cy + .18 * s),
                  (cx, cy + .1 * s), (cx - .38 * s, cy + .18 * s))
        for dx in (-.2, .2):
            self.hole(cx + dx * s, cy - .03 * s, .09 * s, bg)

    def sheep(self, cx, cy, s, bg):
        for dx, dy in ((-.25, 0), (0, -.15), (.25, 0), (0, .15)):
            self.disc(cx + dx * s, cy + dy * s, .22 * s)
        self.hole(cx + .35 * s, cy - .05 * s, .12 * s, bg)
        self.arc(cx + .35 * s, cy - .05 * s, .12 * s, 0, 360, k=0.5)

    def cactus(self, cx, cy, s):
        self.disc(cx, cy, .3 * s)
        for i in range(8):
            a = i * math.pi / 4
            self.ln((cx + .3 * s * math.cos(a), cy + .3 * s * math.sin(a)),
                    (cx + .48 * s * math.cos(a), cy + .48 * s * math.sin(a)), k=0.6)

    def tofu(self, cx, cy, s, bg):
        self.disc(cx, cy, .32 * s)
        self.poly((cx + .3 * s, cy - .05 * s), (cx + .52 * s, cy), (cx + .3 * s, cy + .08 * s))
        self.hole(cx + .1 * s, cy - .1 * s, .07 * s, bg)
        self.ln((cx - .1 * s, cy - .32 * s), (cx - .18 * s, cy - .5 * s), k=0.6)


def lightbg(el):
    return EL[el]


# One glyph per spell: (draw function) — p is the Pen, bg the field colour.
G = {
    # Feca
    31: lambda p, bg: (p.cloud(.5, .4, .8), [p.ln((x, .7), (x - .06, .9), k=.7) for x in (.32, .52, .72)]),
    32: lambda p, bg: (p.shield(.5, .5, .95), p.bolt(.5, .48, .5)),
    33: lambda p, bg: (p.shield(.5, .5, .95), p.rock(.5, .52, .45)),
    34: lambda p, bg: (p.shield(.5, .5, .95, True),),
    35: lambda p, bg: (p.shield(.5, .45, .7), p.down(.78, .7, .45)),
    36: lambda p, bg: (p.shield(.5, .5, .95), p.star(.5, .45, .2)),
    137: lambda p, bg: (p.bubble(.45, .55, .9),),
    138: lambda p, bg: (p.shield(.3, .5, .6), p.arrow(.95, .2, .6, .5), p.arrow(.6, .5, .95, .8)),
    139: lambda p, bg: (p.leaf(.35, .55, .6, -30), p.leaf(.65, .55, .6, 30), p.ln((.5, .25), (.5, .95), k=.6)),
    140: lambda p, bg: (p.swirl(.5, .5, .9),),
    # Osamodas
    51: lambda p, bg: (p.tofu(.48, .52, .9, bg),),
    55: lambda p, bg: (p.paw(.5, .58, .7), p.star(.8, .2, .14), p.star(.2, .25, .1)),
    57: lambda p, bg: (p.ln((.15, .9), (.3, .7), k=1.4), p.arc(.55, .5, .32, 150, 360), p.ln((.87, .5), (.95, .7), k=.7)),
    61: lambda p, bg: (p.bird(.5, .45, .9), p.flame(.5, .78, .32)),
    110: lambda p, bg: (p.sheep(.48, .5, .95, bg),),
    111: lambda p, bg: (p.cactus(.5, .5, .95),),
    141: lambda p, bg: (p.ln((.2, .85), (.65, .4), k=1.0), p.disc(.72, .32, .14), p.bolt(.3, .3, .35)),
    142: lambda p, bg: (p.arc(.5, .7, .48, 180, 360, k=1.3), [p.ln((x, .7), (x, .3 + abs(x - .5) * .4), k=.6) for x in (.3, .5, .7)]),
    143: lambda p, bg: (p.rock(.5, .6, .85), p.ln((.35, .35), (.5, .5), (.42, .62), k=.5)),
    144: lambda p, bg: (p.paw(.35, .55, .55), p.arc(.62, .5, .2, 300, 420, k=.7), p.arc(.62, .5, .34, 300, 420, k=.7)),
    # Enutrof
    37: lambda p, bg: (p.fist(.45, .55, .7), p.ln((.75, .15), (.9, .35), k=.7), p.ln((.9, .15), (.75, .35), k=.7)),
    38: lambda p, bg: (p.coin(.35, .6, .6, bg), p.coin(.68, .35, .5, bg)),
    39: lambda p, bg: (p.wind(.42, .5, .8), p.arrow(.55, .5, .95, .5)),
    40: lambda p, bg: (p.shovel(.15, .9, .62, .4), p.ghost(.78, .3, .38, bg)),
    41: lambda p, bg: (p.shovel(.15, .9, .62, .4), [p.ln((.72, y), (.95, y - .08), k=.6) for y in (.2, .38)]),
    49: lambda p, bg: (p.hourglass(.5, .5, .95), p.plus(.85, .2, .35, .8)),
    145: lambda p, bg: (p.rock(.3, .62, .5), p.rock(.68, .62, .55), p.rock(.5, .35, .5)),
    147: lambda p, bg: (p.coin(.5, .5, .85, bg), p.arrow(.15, .15, .3, .3, .1)),
    148: lambda p, bg: (p.rock(.5, .58, .9), p.eye(.5, .5, .5, lightbg('earth'))),
    149: lambda p, bg: (p.fist(.3, .6, .5), p.fist(.68, .4, .5)),
    # Sram
    63: lambda p, bg: (p.sword(.2, .2, .85, .85, .8), p.mask(.32, .7, .45, bg)),
    65: lambda p, bg: (p.mask(.5, .45, .9, bg), p.swirl(.5, .8, .3)),
    67: lambda p, bg: (p.ghost(.5, .5, .9, bg),),
    69: lambda p, bg: (p.ghost(.35, .5, .6, bg), p.ghost(.68, .5, .6, bg)),
    71: lambda p, bg: (p.heart(.38, .55, .6), p.arrow(.55, .45, .92, .45)),
    73: lambda p, bg: (p.skull(.5, .5, .9, bg),),
    151: lambda p, bg: (p.eye(.5, .5, .9, bg), p.ln((.1, .9), (.9, .1), k=.8)),
    152: lambda p, bg: (p.eye(.38, .45, .6, bg), p.eye(.65, .65, .6, bg), p.ln((.1, .95), (.95, .1), k=.6)),
    153: lambda p, bg: (p.cloud(.5, .42, .85), p.cloud(.4, .72, .5)),
    154: lambda p, bg: (p.spikes(.5, .62, .9), p.skull(.5, .2, .35, bg)),
    # Xelor
    42: lambda p, bg: (p.clock(.42, .5, .8), p.down(.85, .72, .35)),
    43: lambda p, bg: (p.ln((.2, .8), (.75, .25), k=1.4), p.poly((.75, .25), (.92, .08), (.82, .32)), p.ring(.2, .8, .08, .6)),
    44: lambda p, bg: (p.clock(.5, .5, .95),),
    45: lambda p, bg: (p.hourglass(.45, .5, .8), p.swirl(.82, .25, .35)),
    46: lambda p, bg: (p.clock(.5, .55, .7), p.heart(.8, .2, .3)),
    47: lambda p, bg: (p.doll(.5, .5, .95, bg), [p.ln((.25, y), (.75, y + .06), k=.5) for y in (.4, .58)]),
    150: lambda p, bg: (p.shield(.42, .5, .7), p.arrow(.5, .2, .95, .2, .12), p.arrow(.95, .45, .6, .8, .14)),
    155: lambda p, bg: (p.hourglass(.5, .45, .7), [p.disc(x, .9, .05) for x in (.2, .4, .6, .8)]),
    156: lambda p, bg: (p.clock(.4, .5, .7), p.fist(.8, .55, .35)),
    157: lambda p, bg: (p.ring(.5, .5, .42), [p.ln((.5 + .32 * math.cos(a), .5 + .32 * math.sin(a)), (.5 + .42 * math.cos(a), .5 + .42 * math.sin(a)), k=.6) for a in [i * math.pi / 6 for i in range(12)]], p.ln((.5, .5), (.65, .3), k=.8)),
    # Ecaflip
    10: lambda p, bg: (p.coin(.5, .5, .9, bg), p.arc(.5, .5, .48, 300, 360, k=.6)),
    11: lambda p, bg: (p.paw(.5, .5, .8), p.wind(.5, .85, .35)),
    12: lambda p, bg: (p.paw(.3, .7, .45), p.arc(.6, .6, .35, 190, 340), p.arrow(.88, .45, .93, .6, .12)),
    13: lambda p, bg: (p.die(.32, .58, .55, bg), p.die(.7, .38, .5, bg)),
    14: lambda p, bg: (p.clover(.5, .45, .9),),
    15: lambda p, bg: (p.clover(.45, .45, .7), p.ln((.1, .9), (.9, .1), k=.8)),
    134: lambda p, bg: (p.ring(.5, .5, .42), [p.ln((.5, .5), (.5 + .42 * math.cos(a), .5 + .42 * math.sin(a)), k=.5) for a in [i * math.pi / 3 for i in range(6)]], p.disc(.5, .5, .08)),
    158: lambda p, bg: (p.eye(.5, .5, .95, bg),),
    159: lambda p, bg: (p.star(.3, .35, .25), p.star(.65, .6, .3), p.star(.72, .2, .14)),
    160: lambda p, bg: (p.swirl(.5, .5, .9), p.heart(.5, .5, .25)),
    # Eniripsa
    21: lambda p, bg: (p.plus(.5, .5, 1.1, 1.5),),
    22: lambda p, bg: (p.heart(.5, .5, .85), p.plus(.5, .45, .35, .7)),
    23: lambda p, bg: (p.up(.35, .55, .6), p.up(.7, .45, .5)),
    24: lambda p, bg: (p.heart(.5, .55, .8), p.flame(.5, .2, .3)),
    25: lambda p, bg: (p.leaf(.45, .5, .85), p.plus(.82, .2, .3, .8)),
    48: lambda p, bg: (p.heart(.35, .55, .5), p.heart(.68, .4, .5)),
    133: lambda p, bg: (p.swirl(.5, .5, .75), p.plus(.5, .5, .3, .8)),
    161: lambda p, bg: (p.ln((.15, .75), (.85, .75), k=.7), p.poly((.25, .6), (.7, .2), (.9, .4), (.45, .8))),
    162: lambda p, bg: (p.star(.5, .5, .45, 4, .35), p.star(.82, .2, .15, 4, .35)),
    163: lambda p, bg: (p.chain(.1, .3, .9, .3), p.flame(.5, .7, .45)),
    # Iop
    4: lambda p, bg: (p.ln((.5, .05), (.5, .6)), p.poly((.28, .45), (.72, .45), (.5, .75)), p.ln((.1, .95), (.9, .95))),
    5: lambda p, bg: (p.sword(.15, .9, .85, .1), p.ring(.78, .78, .12, .8)),
    6: lambda p, bg: (p.arc(.5, .7, .4, 180, 360), p.poly((.82, .55), (.98, .78), (.7, .78)), p.ln((.05, .95), (.3, .95))),
    7: lambda p, bg: (p.heart(.5, .52, .85), p.plus(.5, .45, .3, .7)),
    8: lambda p, bg: (p.ln((.2, .05), (.2, .98), k=1.3), p.outline((.2, .08), (.9, .2), (.62, .35), (.9, .5), (.2, .5))),
    9: lambda p, bg: (p.ln((.15, .2), (.45, .85)), p.ln((.4, .1), (.7, .8)), p.ln((.65, .05), (.92, .62))),
    164: lambda p, bg: (p.ln((.1, .85), (.9, .15), k=1.6),),
    165: lambda p, bg: (p.sword(.5, .98, .5, .3), p.flame(.5, .2, .4)),
    166: lambda p, bg: (p.sword(.3, .95, .7, .25), p.star(.8, .15, .18)),
    167: lambda p, bg: (p.up(.5, .3, .6), p.up(.5, .72, .6)),
    # Cra
    3: lambda p, bg: (p.fletched(.1, .85, .7, .35), p.target(.78, .25, .4)),
    16: lambda p, bg: (p.fletched(.1, .9, .8, .2), p.star(.25, .25, .14)),
    17: lambda p, bg: (p.fletched(.1, .9, .8, .2), [p.ln((.72 + .14 * math.cos(a), .72 + .14 * math.sin(a)), (.72 - .14 * math.cos(a), .72 - .14 * math.sin(a)), k=.5) for a in (0, math.pi / 3, 2 * math.pi / 3)]),
    18: lambda p, bg: (p.fletched(.1, .9, .7, .3), p.flame(.78, .22, .35)),
    19: lambda p, bg: (p.eye(.5, .5, .85, bg), p.poly((.1, .5), (.9, .5), (.9, .1), (.1, .1))),
    20: lambda p, bg: (p.eye(.5, .55, .8, bg), p.poly((.5, .02), (.62, .22), (.38, .22))),
    168: lambda p, bg: (p.fletched(.9, .5, .2, .5), p.ln((.1, .2), (.1, .8))),
    169: lambda p, bg: (p.fletched(.1, .9, .65, .35), p.ring(.75, .25, .2, .7)),
    170: lambda p, bg: (p.fletched(.1, .9, .75, .25), p.bolt(.75, .7, .4)),
    171: lambda p, bg: (p.eye(.5, .45, .8, bg), p.swirl(.5, .82, .3)),
    # Sadida
    75: lambda p, bg: (p.arc(.5, .5, .4, 180, 470, k=1.1), [p.poly((x, y), (x + .08, y - .12), (x + .12, y + .02)) for x, y in ((.18, .45), (.55, .15), (.78, .6))]),
    79: lambda p, bg: (p.doll(.4, .5, .85, bg), p.star(.8, .2, .14)),
    83: lambda p, bg: (p.ln((.05, .7), (.3, .55), (.5, .75), (.7, .5), (.95, .7), k=1.1), p.rock(.5, .3, .4)),
    85: lambda p, bg: (p.doll(.5, .55, .8, bg), p.flame(.5, .12, .25)),
    109: lambda p, bg: (p.doll(.5, .5, .9, bg), p.swirl(.85, .2, .25)),
    112: lambda p, bg: (p.doll(.4, .5, .8, bg), p.shield(.78, .6, .4, True)),
    136: lambda p, bg: (p.tree(.5, .5, .95),),
    173: lambda p, bg: (p.drop(.5, .5, .9), p.skull(.5, .62, .35, lightbg('neutral'))),
    174: lambda p, bg: (p.doll(.5, .5, .9, bg), p.heart(.82, .2, .25)),
    175: lambda p, bg: (p.tree(.5, .55, .85), p.ln((.2, .95), (.8, .95), k=.7)),
    # Sacrier
    26: lambda p, bg: (p.arrow(.1, .5, .9, .5, .25), p.arrow(.1, .25, .6, .25, .15), p.arrow(.1, .75, .6, .75, .15)),
    27: lambda p, bg: (p.arrow(.95, .3, .55, .3, .15), p.arrow(.95, .7, .55, .7, .15), p.ln((.2, .15), (.2, .85), k=1.2), p.arc(.3, .5, .35, 270, 450)),
    28: lambda p, bg: (p.arrow(.1, .35, .85, .35, .15), p.arrow(.9, .65, .15, .65, .15)),
    29: lambda p, bg: (p.drop(.5, .5, .8), p.drop(.85, .2, .3)),
    30: lambda p, bg: (p.flame(.5, .5, .95),),
    50: lambda p, bg: (p.fist(.5, .4, .75), p.ln((.1, .9), (.9, .9)), p.ln((.3, .8), (.2, .72), k=.6), p.ln((.7, .8), (.8, .72), k=.6)),
    135: lambda p, bg: (p.heart(.5, .5, .7), p.swirl(.5, .5, .95)),
    176: lambda p, bg: (p.heart(.25, .5, .4), p.arrow(.4, .5, .65, .5, .12), p.heart(.8, .5, .4)),
    204: lambda p, bg: (p.foot(.5, .5, .95),),
    409: lambda p, bg: (p.swirl(.4, .45, .7), p.swirl(.75, .7, .4)),
    # Pandawa
    126: lambda p, bg: (p.mug(.5, .55, .85, bg),),
    127: lambda p, bg: (p.mug(.4, .55, .7, bg), p.arrow(.65, .4, .95, .15, .12)),
    128: lambda p, bg: (p.flask(.5, .55, .8), p.burst(.75, .2, .4)),
    129: lambda p, bg: (p.fist(.5, .45, .75), p.burst(.5, .85, .35)),
    130: lambda p, bg: (p.ln((.5, .1), (.5, .8), k=1.3), p.ln((.2, .9), (.8, .9), k=1.3), p.arc(.5, .8, .3, 180, 360, k=.8)),
    131: lambda p, bg: (p.cloud(.4, .45, .6), p.flame(.75, .6, .4)),
    132: lambda p, bg: (p.mug(.45, .5, .6, bg), p.plus(.82, .2, .3, .8), p.ln((.1, .92), (.9, .92), k=.6)),
    179: lambda p, bg: (p.ln((.3, .1), (.3, .75), k=1.1), p.ln((.7, .1), (.7, .75), k=1.1), p.ln((.1, .88), (.9, .88), k=1.3)),
    407: lambda p, bg: (p.mug(.4, .5, .6, bg), p.mug(.72, .6, .45, bg)),
    408: lambda p, bg: (p.bamboo(.15, .9, .85, .15), p.burst(.25, .25, .3)),
    # the close-combat weapon slot of every fighter (fight_view, sid -2)
    'weapon': lambda p, bg: (p.sword(.15, .85, .85, .15, .9), p.sword(.85, .85, .15, .15, .9)),
}


def icon(sid, el):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = int(N * 0.12)
    sq = [(k, 0), (N, 0), (N - k, N), (0, N)]
    col = EL[el]
    d.polygon(sq, fill=col + (255,))
    d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 5)
    G[sid](Pen(d, (255, 255, 255)), col)
    return img.resize((PX, PX), Image.LANCZOS)


def main():
    data = json.load(open('assets/gamedata/spells.json'))
    spells = [s for k in sorted(data, key=int) for s in data[k]]
    os.makedirs(OUT, exist_ok=True)
    missing = [s['id'] for s in spells if s['id'] not in G]
    if missing:
        sys.exit(f'no glyph for spells {missing}')
    for s in spells:
        icon(s['id'], s.get('fx', {}).get('e', 'neutral')).save(f"{OUT}/{s['id']}.png")
    icon('weapon', 'neutral').save(f"{OUT}/weapon.png")
    print(f'{len(spells)} icons in {OUT}')
    if '--sheet' in sys.argv:
        out = sys.argv[sys.argv.index('--sheet') + 1]
        font = ImageFont.truetype('assets/ui/fonts/Nunito-Variable.ttf', 11)
        W = 10
        rows = len(data)
        sheet = Image.new('RGBA', (W * 104 + 20, rows * 118 + 20), (233, 236, 241, 255))
        dd = ImageDraw.Draw(sheet)
        for r, k in enumerate(sorted(data, key=int)):
            for c, s in enumerate(data[k]):
                x, y = 10 + c * 104, 10 + r * 118
                sheet.alpha_composite(Image.open(f"{OUT}/{s['id']}.png"), (x, y))
                dd.text((x, y + 98), s['name'][:16], font=font, fill=(60, 64, 80))
        sheet.convert('RGB').save(out)
        print(out)


if __name__ == '__main__':
    main()
