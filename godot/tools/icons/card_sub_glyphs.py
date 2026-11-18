"""S47 (point 11): the sub-family pictograms of the cards — what tells a
pócima from a pomada, a rune from a flag, a rocket from a fountain, so the
inventory no longer shows one icon on hundreds of cards.

Same ink as the family pictograms (card_template_options.pictogram): a white
silhouette drawn with badge_icon_options' Pen at one stroke weight (S * 4 on
the 4x canvas), its details carved out to transparency. A colour is only an
accent and always sits inside the white (a gem's body, a rocket's band, the
iris of an eye), so it reads on every family colour.

A pictogram is `base` + an optional `variant` + `mods`:
  base     the object (BASES: name → function(g, colour) → mark slot or None);
  variant  VARIANTS: name → (mark, colour). The mark goes in the slot the base
           returns (carved, or in its colour); a base without a slot uses the
           colour itself (a candy's stripe, a book's ribbon, a gem's body);
  mods     "small" (drawn smaller: a lesser rune), "ban" (a no-entry ring
           over it), or "badge:<mark>" (a small mark at the top right: the
           sparkle of a "gran", the crown of a "suprema", a moon, a +/−…).
card_art.py picks them for every card from its type and Spanish name.
"""
import math

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import badge_icon_options as opt
import card_template_options as tpl

S = opt.S
W = S * 4                      # the stroke, as the family pictograms
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
FONT = "assets/ui/fonts/SairaCondensed-ExtraBold.ttf"

# accents
FIRE, WATER, AIR, EARTH = (255, 106, 61), (47, 157, 240), (57, 192, 138), (160, 116, 60)
ICE, BOLT = (150, 214, 250), (255, 206, 46)
STAT = {"fuerza": EARTH, "ingenio": FIRE, "suerte": WATER, "agilidad": AIR,
        "vigor": (238, 64, 96), "sabiduría": (140, 96, 230), "marfil": (236, 226, 196), "oro": (232, 176, 40)}


class G:
    """A glyph box on an image: `p` draws white, `q` carves (transparent)."""

    def __init__(self, img, box):
        self.img, self.box = img, box
        self.d = ImageDraw.Draw(img)
        self.p = opt.Pen(self.d, box, WHITE, W)
        self.q = opt.Pen(self.d, box, CLEAR, W)

    def sub(self, x0, y0, side):
        x, y, s = self.box
        return G(self.img, (x + x0 * s, y + y0 * s, side * s))

    def slot(self, cx, cy, r):
        return self.sub(cx - r, cy - r, 2 * r)

    def pen(self, col):
        return opt.Pen(self.d, self.box, tuple(col)[:3] + (255,), W)

    # shapes the Pen lacks (unit coordinates)
    def ell(self, pen, x0, y0, x1, y1):
        pen.d.ellipse([pen.P(x0, y0), pen.P(x1, y1)], fill=pen.col)

    def rr(self, pen, x0, y0, x1, y1, r):
        pen.d.rounded_rectangle([pen.P(x0, y0), pen.P(x1, y1)], radius=int(r * pen.s), fill=pen.col)

    def chord(self, pen, x0, y0, x1, y1, a0, a1):
        pen.d.chord([pen.P(x0, y0), pen.P(x1, y1)], a0, a1, fill=pen.col)

    def pie(self, pen, x0, y0, x1, y1, a0, a1):
        pen.d.pieslice([pen.P(x0, y0), pen.P(x1, y1)], a0, a1, fill=pen.col)

    def arc(self, pen, x0, y0, x1, y1, a0, a1, k=1.0):
        pen.d.arc([pen.P(x0, y0), pen.P(x1, y1)], a0, a1, fill=pen.col, width=int(W * k))

    def stroke(self, pen, *pts, k=1.0):
        """A line with round caps."""
        pen.line(*pts, k=k)
        for x, y in (pts[0], pts[-1]):
            pen.disc(x, y, W * k / 2 / pen.s)

    def text(self, pen, cx, cy, t, size):
        f = ImageFont.truetype(FONT, int(pen.s * size))
        pen.d.text(pen.P(cx, cy), t, font=f, fill=pen.col, anchor="mm")

    def tint(self, col):
        """Paint the inside of what is drawn so far in `col`, leaving a
        white ink rim of one stroke round every edge (and round every
        carving)."""
        a = self.img.getchannel("A").point(lambda v: 255 if v > 200 else 0)
        inner = a.filter(ImageFilter.BoxBlur(W)).point(lambda v: 255 if v > 250 else 0)
        fill = Image.new("RGBA", self.img.size, tuple(col)[:3] + (255,))
        self.img.paste(fill, (0, 0), inner)


def sparkle(pen, cx, cy, r, waist):
    tpl._sparkle(pen, cx, cy, r, waist)


def star(pen, cx, cy, r, n=5, inner=.42, rot=-90):
    pts = []
    for i in range(n * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(i * 180 / n + rot)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    pen.poly(*pts)


def flame_pts(cx, cy, w, h):
    """A flame: a round foot, a pointed lick leaning right."""
    pts = []
    for i in range(0, 181, 15):           # the round foot (bottom half circle)
        a = math.radians(i)
        pts.append((cx + w / 2 * math.cos(a), cy + w / 2 * math.sin(a)))
    pts += [(cx - w / 2, cy - h * .15), (cx - w * .28, cy - h * .45), (cx - w * .2, cy - h * .3),
            (cx - w * .02, cy - h * .78), (cx + w * .16, cy - h * .5), (cx + w * .3, cy - h * .62),
            (cx + w / 2, cy - h * .15)]
    return pts


# --- marks: drawn in a slot's own 0..1 box; p fills, q details ------------
def m_agua(g, p, q):
    p.disc(.5, .64, .3)
    p.poly((.215, .56), (.5, .04), (.785, .56))
    q.ring(.5, .64, .17, 100, 170, k=.8)


def m_fuego(g, p, q):
    p.poly(*flame_pts(.5, .72, .62, .78))
    q.poly(*flame_pts(.5, .8, .24, .3))


def m_tierra(g, p, q):
    p.poly((.02, .88), (.36, .2), (.52, .48), (.66, .32), (.98, .88))
    q.poly((.36, .2), (.46, .4), (.36, .36), (.28, .4))


def m_aire(g, p, q):
    for y, x1, r in ((.28, .62, .14), (.52, .8, .12), (.76, .54, .1)):
        g.stroke(p, (.06, y), (x1, y), k=1.15)
        p.ring(x1, y - r, r, -90, 150 if y != .76 else 120, k=1.15)


def m_escarcha(g, p, q):
    for a in (90, 30, -30):
        r = math.radians(a)
        dx, dy = .44 * math.cos(r), .44 * math.sin(r)
        g.stroke(p, (.5 - dx, .5 - dy), (.5 + dx, .5 + dy), k=1.1)
        for sgn in (1, -1):
            tx, ty = .5 + sgn * dx * .62, .5 + sgn * dy * .62
            for t in (35, -35):
                rr = math.radians(a + (180 if sgn < 0 else 0) + 180 + t)
                g.stroke(p, (tx, ty), (tx + .17 * math.cos(rr), ty + .17 * math.sin(rr)), k=.9)


def m_rayo(g, p, q):
    p.poly((.62, .02), (.16, .58), (.46, .58), (.34, .98), (.86, .38), (.54, .38), (.7, .02))


def m_ala(g, p, q):
    p.poly((.06, .3), (.5, .1), (.94, .06), (.88, .3), (.8, .42), (.84, .52), (.68, .66), (.7, .76),
           (.5, .9), (.36, .86), (.16, .62))
    for a, b in (((.34, .5), (.86, .3)), ((.38, .66), (.74, .52)), ((.4, .8), (.6, .74))):
        q.line(a, b, k=.8)


def m_escudo(g, p, q):
    p.poly((.12, .1), (.5, .02), (.88, .1), (.88, .48), (.5, .98), (.12, .48))
    q.line((.5, .2), (.5, .76), k=.9)
    q.line((.28, .4), (.72, .4), k=.9)


def m_ojo(g, p, q):
    g.chord(p, -.02, .18, 1.02, 1.1, 200, 340)
    g.chord(p, -.02, -.1, 1.02, .82, 20, 160)
    q.disc(.5, .5, .22)
    p.disc(.5, .5, .12)


def m_diana(g, p, q):
    p.disc(.5, .5, .46)
    q.disc(.5, .5, .34)
    p.disc(.5, .5, .24)
    q.disc(.5, .5, .12)


def m_fuerza(g, p, q):
    star(p, .5, .5, .5, n=8, inner=.5)


def m_corazon(g, p, q):
    p.disc(.3, .36, .24)
    p.disc(.7, .36, .24)
    p.poly((.07, .44), (.5, .94), (.93, .44), (.5, .3))


def m_luna(g, p, q):
    p.disc(.5, .5, .44)
    q.disc(.68, .38, .36)


def m_rapido(g, p, q):
    for x in (.12, .5):
        p.poly((x, .14), (x + .22, .14), (x + .46, .5), (x + .22, .86), (x, .86), (x + .24, .5))


def m_coraje(g, p, q):
    p.poly((.5, .04), (.94, .5), (.68, .5), (.68, .96), (.32, .96), (.32, .5), (.06, .5))


def m_moneda(g, p, q):
    p.disc(.5, .5, .46)
    q.ring(.5, .5, .3, k=.9)
    q.rect(.5, .5, .1, .3, 0)


def m_estrella(g, p, q):
    star(p, .5, .54, .5)


def m_halo(g, p, q):
    g.arc(p, .02, .26, .98, .74, 0, 360, k=1.5)


def m_eco(g, p, q):
    p.disc(.2, .5, .12)
    for r in (.3, .5, .7):
        p.ring(.2, .5, r, -48, 48, k=1.1)


def m_pegajosa(g, p, q):
    g.rr(p, .08, .08, .92, .46, .18)
    for x, y, r in ((.24, .62, .12), (.52, .78, .14), (.8, .58, .1)):
        p.rect(x, (y + .3) / 2, r * 1.6, y - .3, 0)
        p.disc(x, y, r)


def m_cruz(g, p, q):
    p.rect(.5, .5, .3, .9, 0)
    p.rect(.5, .5, .9, .3, 0)


def m_gema(g, p, q):
    p.poly((.24, .14), (.76, .14), (.96, .4), (.5, .94), (.04, .4))
    q.line((.04, .4), (.96, .4), k=.8)
    q.line((.3, .4), (.5, .9), (.7, .4), k=.8)


def m_hoja(g, p, q):
    edge = [(.5 - .4 * math.sin(math.pi * t / 20), .04 + .92 * t / 20) for t in range(21)]
    p.poly(*edge, *[(1 - x, y) for x, y in reversed(edge)])
    q.line((.5, .22), (.5, .9), k=.85)
    for y in (.4, .6):
        q.line((.5, y + .1), (.3, y), k=.7)
        q.line((.5, y + .1), (.7, y), k=.7)


def m_copa(g, p, q):
    opt.glyph(p, 3, q.col)


def m_rombo(g, p, q):
    p.poly((.5, .02), (.94, .5), (.5, .98), (.06, .5))
    q.poly((.5, .26), (.72, .5), (.5, .74), (.28, .5))


def m_interrogacion(g, p, q):
    g.text(p, .5, .52, "?", 1.1)


def m_sol(g, p, q):
    g.chord(p, .18, .42, .82, 1.06, 180, 360)
    for a in (180, 216, 252, 288, 324, 360):
        r = math.radians(a)
        g.stroke(p, (.5 + .42 * math.cos(r), .74 + .42 * math.sin(r)), (.5 + .56 * math.cos(r), .74 + .56 * math.sin(r)), k=1)
    p.rect(.5, .86, 1.0, .1, 0)


def m_ola(g, p, q):
    for y in (.34, .66):
        for x in (.18, .5, .82):
            p.ring(x, y, .17, 200, 340, k=1.2)


def m_candado(g, p, q):
    opt.glyph(p, "lock", q.col)


def m_mas(g, p, q):
    p.rect(.5, .5, .28, .9, 0)
    p.rect(.5, .5, .9, .28, 0)


def m_menos(g, p, q):
    p.rect(.5, .5, .9, .28, 0)


def m_destello(g, p, q):
    sparkle(p, .5, .5, .52, .13)


def m_corona(g, p, q):
    p.poly((.04, .82), (.04, .26), (.28, .5), (.5, .14), (.72, .5), (.96, .26), (.96, .82))
    q.line((.12, .7), (.88, .7), k=.7)


def m_figura(g, p, q):
    p.disc(.5, .28, .22)
    g.chord(p, .08, .52, .92, 1.36, 180, 360)


def m_espadas(g, p, q):
    opt.glyph(opt.Pen(p.d, (p.x, p.y, p.s), p.col, W * 1.1), 1, q.col)


def m_roca(g, p, q):
    p.poly((.04, .86), (.12, .46), (.36, .22), (.66, .18), (.9, .4), (.96, .86))
    q.line((.36, .22), (.46, .5), (.3, .86), k=.8)
    q.line((.46, .5), (.76, .56), k=.8)


def m_tronco(g, p, q):
    p.disc(.5, .5, .46)
    q.ring(.5, .5, .3, k=.8)
    q.disc(.5, .5, .08)


# the sello emblems: a class's tool
def m_yunque(g, p, q):
    p.poly((.04, .26), (.78, .26), (.98, .36), (.78, .44), (.68, .5), (.6, .62), (.4, .62), (.32, .5), (.12, .44))
    p.rect(.5, .7, .3, .2, 0)
    p.rect(.5, .86, .7, .14, 0)


def m_cayado(g, p, q):
    p.ring(.58, .3, .22, 180, 360, k=1.4)
    p.ring(.58, .3, .22, 0, 60, k=1.4)
    g.stroke(p, (.36, .3), (.36, .96), k=1.4)


def m_colmillo(g, p, q):
    p.poly((.18, .06), (.82, .06), (.74, .36), (.58, .72), (.46, .96), (.4, .6), (.3, .3))


def m_arado(g, p, q):
    g.stroke(p, (.14, .12), (.62, .64), k=1.3)
    p.poly((.5, .54), (.96, .7), (.84, .94), (.42, .78))
    g.stroke(p, (.14, .12), (.32, .1), k=1.3)


def m_hacha(g, p, q):
    g.stroke(p, (.3, .96), (.62, .1), k=1.3)
    p.poly((.48, .12), (.88, .02), (.96, .4), (.82, .5), (.5, .38))


def m_varita(g, p, q):
    g.stroke(p, (.1, .94), (.56, .46), k=1.3)
    star(p, .7, .32, .3)


def m_arco(g, p, q):
    p.ring(.18, .5, .6, -68, 68, k=1.4)
    p.line((.4, -.06 + .1), (.4, .96), k=.7)
    g.stroke(p, (.06, .5), (.92, .5), k=.9)
    p.poly((.98, .5), (.82, .4), (.82, .6))


def m_canica(g, p, q):
    p.disc(.5, .5, .46)
    q.ring(.5, .5, .25, 200, 380, k=.9)
    q.disc(.34, .3, .07)


MARKS = {k[2:]: v for k, v in dict(globals()).items() if k.startswith("m_")}


def mark(g, name, cx, cy, r, mode="carve", col=None):
    """Draw MARKS[name] in the slot (cx, cy, r) of g: carved out of the white,
    solid white (details carved), or in `col` (details white)."""
    s = g.slot(cx, cy, r)
    if mode == "solid":
        p, q = s.p, s.q
    elif col is not None:
        p, q = s.pen(col), s.p
    else:
        p, q = s.q, s.p
    MARKS[name](s, p, q)


def badge(g, name, cx=.84, cy=.16, r=.15, col=None):
    """A small solid mark at the top right, cut free of what is under it."""
    g.q.disc(cx, cy, r * 1.42)
    mark(g, name, cx, cy, r, "solid" if col is None else "col", col)


# --- bases: draw in g's box, return the mark slot (cx, cy, r[, mode]) --------
def b_pocima(g, col):         # the round flask (the family's, the bubbles left out)
    p = g.p
    p.rect(.5, .1, .18, .1, 0)
    p.rect(.5, .17, .3, .07, 0)
    p.rect(.5, .3, .2, .22, 0)
    p.disc(.5, .64, .31)
    return (.5, .65, .2)


def b_media_pocima(g, col):   # half a flask: the top of the body hollow
    b_pocima(g, col)
    g.q.disc(.5, .64, .31 - W / g.p.s * 1.0)
    g.chord(g.p, .19, .33, .81, .95, 10, 170)
    g.p.rect(.5, .7, .56, W / g.p.s * 1.0, 0)
    return (.5, .82, .09)


def b_pomada(g, col):         # an open jar of ointment, a peak of cream
    p, q = g.p, g.q
    g.rr(p, .16, .5, .84, .92, .12)
    g.rr(p, .08, .4, .92, .54, .05)
    q.line((.08, .54), (.92, .54), k=.8)
    g.chord(p, .2, .22, .8, .62, 180, 360)
    p.poly((.42, .3), (.58, .08), (.62, .32))
    q.ring(.5, .42, .16, 205, 300, k=.8)
    return (.5, .72, .13)


def b_elixir(g, col):         # a tall slim bottle
    p, q = g.p, g.q
    p.rect(.5, .07, .16, .1, 0)
    p.rect(.5, .23, .14, .24, 0)
    p.poly((.42, .32), (.58, .32), (.74, .46), (.26, .46))
    g.rr(p, .26, .42, .74, .96, .1)
    q.line((.36, .54), (.36, .84), k=.9)
    return (.55, .7, .14)


def b_conjuro(g, col):        # a wand, a star (or the mark) at its tip
    g.stroke(g.p, (.12, .92), (.56, .44), k=1.7)
    g.q.disc(.12, .92, .02)
    sparkle(g.p, .24, .22, .12, .03)
    sparkle(g.p, .88, .66, .1, .025)
    return (.7, .3, .26, "solid")


def b_ritual(g, col):         # three candles on a dish
    p, q = g.p, g.q
    for cx, top, w in ((.24, .58, .16), (.5, .38, .2), (.76, .58, .16)):
        p.rect(cx, (top + .86) / 2, w, .86 - top, 0)
        p.poly(*flame_pts(cx, top - .06, w * .7, .24))
        q.line((cx + w * .2, top + .02), (cx + w * .2, top + .1), k=.8)
    g.rr(p, .06, .84, .94, .94, .05)
    return None


def b_bandera(g, col):        # a pennant on a pole
    p, q = g.p, g.q
    g.stroke(p, (.22, .1), (.22, .94), k=1.3)
    p.disc(.22, .07, .06)
    p.poly((.25, .12), (.6, .2), (.9, .32), (.6, .42), (.25, .54))
    q.line((.25, .33), (.72, .33), k=.85)
    p.rect(.22, .94, .28, .06, 0)
    return None


def b_estandarte(g, col):     # a banner hung from a crossbar, swallowtail
    p, q = g.p, g.q
    g.stroke(p, (.5, .1), (.5, .96), k=1.1)
    g.stroke(p, (.14, .14), (.86, .14), k=1.1)
    p.disc(.5, .06, .06)
    p.poly((.2, .18), (.8, .18), (.8, .8), (.5, .64), (.2, .8))
    q.poly((.5, .28), (.62, .42), (.5, .56), (.38, .42))
    return None


RUNES = {   # rune strokes in the stone's face
    "pegajosa": [((.32, .26), (.68, .74)), ((.68, .26), (.32, .74)), ((.3, .5), (.7, .5))],
    "escurridiza": [((.64, .24), (.38, .4), (.62, .58), (.36, .76))],
    "corpulenta": [((.38, .24), (.38, .76)), ((.38, .24), (.64, .38), (.38, .5)), ((.38, .5), (.64, .63), (.38, .76))],
    "rapida": [((.5, .26), (.5, .78)), ((.32, .44), (.5, .26), (.68, .44))],
    "robusta": [((.32, .26), (.32, .74)), ((.68, .26), (.68, .74)), ((.32, .26), (.68, .74)), ((.68, .26), (.32, .74))],
    "resistente": [((.5, .3), (.5, .78)), ((.3, .28), (.5, .5), (.7, .28))],
    "campeona": [((.5, .24), (.68, .42), (.5, .6), (.32, .42), (.5, .24)), ((.36, .78), (.5, .6), (.64, .78))],
}


def b_runa(g, col, rune="pegajosa"):   # a rune stone
    p, q = g.p, g.q
    p.poly((.3, .08), (.66, .06), (.82, .18), (.86, .62), (.78, .9), (.5, .96), (.2, .9), (.14, .56), (.18, .2))
    for pts in RUNES[rune]:
        g.stroke(q, *pts, k=1.05)
    return None


def b_polvo(g, col):          # a heap of powder, sparkles over it
    p = g.p
    g.chord(p, .06, .58, .94, 1.14, 180, 360)
    p.rect(.5, .88, .9, .06, 0)
    sparkle(p, .5, .3, .18, .045)
    sparkle(p, .22, .44, .09, .025)
    sparkle(p, .8, .2, .1, .025)
    g.q.disc(.36, .76, .03)
    g.q.disc(.62, .7, .03)
    return None


# dofus
def b_caramelo(g, col):       # a wrapped sweet, a stripe of its flavour
    p, q = g.p, g.q
    p.poly((.04, .3), (.3, .44), (.3, .56), (.04, .7), (.12, .5))
    p.poly((.96, .3), (.7, .44), (.7, .56), (.96, .7), (.88, .5))
    g.ell(p, .22, .28, .78, .72)
    if col:
        g.tint(col)
        q.line((.4, .32), (.34, .68), k=.9)
        q.line((.6, .32), (.54, .68), k=.9)
    else:
        q.line((.4, .32), (.34, .68), k=.9)
    return None


def b_gominola(g, col):       # a jelly bear
    p, q = g.p, g.q
    p.disc(.5, .26, .2)
    p.disc(.33, .1, .08)
    p.disc(.67, .1, .08)
    g.ell(p, .28, .38, .72, .9)
    g.ell(p, .14, .44, .36, .62)
    g.ell(p, .64, .44, .86, .62)
    g.ell(p, .22, .78, .44, .96)
    g.ell(p, .56, .78, .78, .96)
    if col:
        g.tint(col)
    q.disc(.43, .24, .03)
    q.disc(.57, .24, .03)
    return None


def b_hoja_papel(g, col):     # a sheet, its corner folded, a seal of its stat
    p, q = g.p, g.q
    p.poly((.18, .06), (.64, .06), (.84, .26), (.84, .94), (.18, .94))
    q.poly((.64, .06), (.64, .26), (.84, .26), (.84, .2), (.7, .06))
    p.poly((.62, .08), (.62, .28), (.82, .28))
    q.line((.62, .08), (.62, .28), (.82, .28), k=.7)
    for y, x1 in ((.38, .7), (.5, .7), (.62, .52)):
        q.line((.3, y), (x1, y), k=.8)
    seal(g, .68, .8, .14, col)
    return None


def seal(g, cx, cy, r, col):
    g.q.disc(cx, cy, r + W / g.p.s)
    g.p.disc(cx, cy, r)
    if col:
        g.pen(col).disc(cx, cy, r - W / g.p.s)


def b_rollo(g, col):          # a rolled scroll tied with a ribbon
    p, q = g.p, g.q
    g.rr(p, .12, .28, .88, .72, .2)
    g.q.disc(.17, .5, .07)
    p.disc(.17, .5, .035)
    q.line((.3, .3), (.3, .7), k=.8)
    band = g.pen(col) if col else q
    band.rect(.6, .5, .14, .48, 0)
    p.poly((.56, .74), (.5, .94), (.6, .86), (.7, .94), (.64, .74))
    if col:
        g.pen(col).poly((.58, .78), (.54, .88), (.6, .83), (.66, .88), (.62, .78))
    return None


def b_tomo(g, col):           # a thick closed book, a gem of its stat on the cover
    p, q = g.p, g.q
    g.rr(p, .18, .06, .84, .94, .06)
    p.rect(.22, .5, .12, .88, 0)
    q.line((.32, .1), (.32, .9), k=.8)
    for y in (.2, .8):
        q.line((.2, y), (.3, y), k=.8)
    q.rect(.83, .5, .05, .76, 0)
    seal(g, .56, .46, .15, col)
    return None


def b_codice(g, col):         # an open book, a ribbon of its stat
    p, q = g.p, g.q
    p.poly((.04, .2), (.3, .14), (.5, .22), (.7, .14), (.96, .2), (.96, .82), (.7, .76), (.5, .86), (.3, .76), (.04, .82))
    q.line((.5, .24), (.5, .84), k=.9)
    for y in (.34, .46, .58):
        q.line((.14, y), (.4, y - .03), k=.7)
        q.line((.6, y - .03), (.86, y), k=.7)
    if col:
        g.pen(col).poly((.64, .14), (.76, .14), (.76, .98), (.7, .9), (.64, .98))
        g.q.line((.62, .14), (.62, .9), k=.5)
        g.q.line((.78, .14), (.78, .9), k=.5)
    return None


def b_fajo(g, col):           # a bundle of sheets tied with a band
    p, q = g.p, g.q
    for i, (x0, y0) in enumerate(((.24, .08), (.17, .16), (.1, .24))):
        if i:
            g.rr(q, x0 - .04, y0 - .04, x0 + .7, y0 + .7, .06)
        g.rr(p, x0, y0, x0 + .66, y0 + .66, .04)
    for y in (.44, .56, .68, .8):
        q.line((.2, y), (.66, y), k=.7)
    band = g.pen(col) if col else q
    q.rect(.5, .57, .24, .68, 0)
    band.rect(.5, .57, .14, .68, 0)
    return None


def b_gorrion(g, col):        # a wind-up sparrow, its key on its back
    p, q = g.p, g.q
    g.ell(p, .14, .38, .74, .82)
    p.disc(.7, .4, .16)
    p.poly((.82, .36), (.98, .42), (.82, .46))
    p.poly((.18, .56), (.02, .4), (.08, .7))
    q.disc(.72, .37, .035)
    q.ring(.44, .56, .2, 200, 330, k=.8)
    g.stroke(p, (.4, .82), (.4, .94), k=.8)
    g.stroke(p, (.56, .82), (.56, .94), k=.8)
    g.stroke(p, (.42, .4), (.42, .2), k=1)
    for dx in (-1, 1):
        p.disc(.42 + dx * .1, .16, .08)
    q.disc(.32, .16, .03)
    q.disc(.52, .16, .03)
    return None


def b_huevo(g, col):          # a plain egg, cracked, its element on it
    p, q = g.p, g.q
    pts = []
    for i in range(72):
        t = math.radians(i * 5)
        rx = .34 + .04 * math.sin(t)
        pts.append((.5 + rx * math.cos(t), .54 + .42 * math.sin(t)))
    p.poly(*pts)
    q.line((.18, .4), (.3, .46), (.38, .38), (.48, .46), (.58, .38), (.68, .46), (.82, .4), k=.8)
    return (.5, .7, .16)


def b_sello(g, col):          # a wax seal, ribbon tails, a class's tool on it
    p, q = g.p, g.q
    p.poly((.32, .6), (.22, .98), (.36, .9), (.44, .98), (.48, .64))
    p.poly((.68, .6), (.78, .98), (.64, .9), (.56, .98), (.52, .64))
    q.line((.42, .62), (.38, .96), k=.6)
    q.line((.58, .62), (.62, .96), k=.6)
    pts = []
    for i in range(48):
        a = math.radians(i * 7.5)
        r = .4 + .03 * math.cos(i * math.pi / 2)
        pts.append((.5 + r * math.cos(a), .42 + r * math.sin(a)))
    p.poly(*pts)
    q.ring(.5, .42, .31, k=.7)
    return (.5, .42, .2)


def b_hadita(g, col):         # a little fairy, her wings in her colour
    p, q = g.p, g.q
    wings = Image.new("RGBA", g.img.size, CLEAR)
    gw = G(wings, g.box)
    for sx in (-1, 1):
        gw.p.poly((.5, .46), (.5 + sx * .44, .1), (.5 + sx * .48, .38), (.5 + sx * .2, .56))
        gw.p.poly((.5, .54), (.5 + sx * .38, .78), (.5 + sx * .3, .92), (.5 + sx * .1, .66))
    if col:
        gw.tint(col)
    g.img.alpha_composite(wings)
    g.q.disc(.5, .3, .16)
    g.q.poly((.5, .36), (.38, .9), (.62, .9))
    p.disc(.5, .3, .11)
    p.poly((.5, .38), (.42, .86), (.58, .86))
    sparkle(p, .82, .9, .08, .02)
    return None


def b_estuche(g, col):        # a case with a clasp, a mark on its lid
    p, q = g.p, g.q
    g.rr(p, .08, .3, .92, .88, .08)
    q.line((.08, .48), (.92, .48), k=.9)
    g.rr(p, .36, .18, .64, .3, .04)
    q.rect(.5, .48, .14, .14, 0)
    p.rect(.5, .48, .08, .08, 0)
    return (.5, .7, .13)


def b_gema(g, col):           # a step-cut gem seen from above, in its colour
    p, q = g.p, g.q
    o = [(.3, .1), (.7, .1), (.92, .32), (.92, .68), (.7, .9), (.3, .9), (.08, .68), (.08, .32)]
    p.poly(*o)
    if col:
        g.tint(col)
    i = [(.38, .3), (.62, .3), (.72, .4), (.72, .6), (.62, .7), (.38, .7), (.28, .6), (.28, .4)]
    for a, b in zip(o, i):
        p.line(a, b, k=.7)
    p.line(*(i + [i[0]]), k=.7)
    g.ell(p, .32, .32, .44, .44) if not col else None
    return None


def b_esencia(g, col):        # a wisp of essence in a round phial
    p, q = g.p, g.q
    p.rect(.5, .1, .16, .1, 0)
    p.rect(.5, .2, .24, .06, 0)
    p.disc(.5, .6, .38)
    q.disc(.5, .6, .38 - W / p.s)
    q.rect(.5, .22, .12, .02, 0)
    return (.5, .6, .24)


def b_amuleto(g, col):
    p, q = g.p, g.q
    p.ring(.5, .06, .42, 30, 150, k=.9)
    p.disc(.5, .62, .26)
    q.disc(.5, .62, .12)
    p.rect(.5, .38, .1, .08, 0)
    return None


def b_anillo(g, col):
    p, q = g.p, g.q
    p.ring(.5, .62, .3, k=1.7)
    p.poly((.34, .3), (.66, .3), (.74, .18), (.6, .06), (.4, .06), (.26, .18))
    q.line((.26, .18), (.74, .18), k=.6)
    return None


def b_botas(g, col):
    p, q = g.p, g.q
    p.poly((.3, .08), (.62, .08), (.62, .62), (.9, .74), (.94, .92), (.22, .92), (.24, .6))
    q.line((.24, .24), (.64, .24), k=.8)
    q.line((.22, .82), (.94, .82), k=.7)
    return None


def b_capa(g, col):           # a cloak: a clasp, the folds falling
    p, q = g.p, g.q
    p.poly((.36, .1), (.64, .1), (.72, .26), (.92, .9), (.08, .9), (.28, .26))
    q.line((.42, .3), (.32, .86), k=.8)
    q.line((.58, .3), (.68, .86), k=.8)
    q.disc(.5, .14, .08)
    p.disc(.5, .14, .045)
    return None


def b_cinturon(g, col):       # a belt: the strap round, a big buckle
    p, q = g.p, g.q
    g.arc(p, .04, .24, .96, .8, 0, 360, k=2.4)
    g.q.rect(.5, .74, .4, .28, 0)
    g.rr(p, .3, .6, .7, .9, .06)
    g.rr(q, .38, .66, .62, .84, .03)
    g.stroke(p, (.5, .75), (.66, .75), k=.9)
    return None


def b_mascara(g, col):        # a domino mask
    p, q = g.p, g.q
    p.poly((.04, .34), (.3, .26), (.5, .34), (.7, .26), (.96, .34), (.92, .62), (.7, .72), (.5, .58),
           (.3, .72), (.08, .62))
    g.ell(q, .18, .38, .42, .56)
    g.ell(q, .58, .38, .82, .56)
    return None


# cosmetic
def b_cohete(g, col):         # a rocket climbing, its band in its colour
    p, q = g.p, g.q
    rocket = Image.new("RGBA", g.img.size, CLEAR)
    r = G(rocket, g.box)
    r.p.poly((.38, .3), (.5, .02), (.62, .3))
    r.rr(r.p, .38, .26, .62, .78, .04)
    r.p.poly((.38, .54), (.2, .82), (.38, .76))
    r.p.poly((.62, .54), (.8, .82), (.62, .76))
    r.p.rect(.5, .8, .14, .08, 0)
    band = r.pen(col) if col else r.q
    band.rect(.5, .46, .24 - W / r.p.s * 2, .14, 0)
    rocket = rocket.rotate(-32, resample=Image.BICUBIC, center=r.p.P(.5, .5))
    g.img.alpha_composite(rocket)
    for x, y, rr in ((.24, .9, .055), (.12, .8, .04), (.32, .98, .035)):
        p.disc(x, y, rr)
    sparkle(p, .86, .18, .1, .025)
    return None


def b_estrella_fuego(g, col):  # a firework burst, its heart in its colour
    p, q = g.p, g.q
    for i in range(12):
        a = math.radians(i * 30)
        r0, r1 = .2, (.46 if i % 2 == 0 else .36)
        g.stroke(p, (.5 + r0 * math.cos(a), .5 + r0 * math.sin(a)), (.5 + r1 * math.cos(a), .5 + r1 * math.sin(a)), k=1.05)
    p.disc(.5, .5, .15)
    if col:
        g.pen(col).disc(.5, .5, .15 - W / p.s)
    else:
        q.disc(.5, .5, .06)
    return None


def b_fuente(g, col):         # a fountain firework: a tube, a spray of sparks
    p, q = g.p, g.q
    p.poly((.32, .56), (.68, .56), (.74, .96), (.26, .96))
    band = g.pen(col) if col else q
    band.poly((.35, .67), (.65, .67), (.675, .84), (.325, .84))
    for a0, r in ((200, .32), (230, .4), (270, .46), (310, .4), (340, .32)):
        a = math.radians(a0)
        g.stroke(p, (.5 + .1 * math.cos(a), .52 + .1 * math.sin(a)), (.5 + r * math.cos(a), .52 + r * math.sin(a)), k=1.05)
    for a0, r in ((215, .46), (250, .52), (290, .52), (325, .46)):
        a = math.radians(a0)
        p.disc(.5 + r * math.cos(a), .52 + r * math.sin(a), .04)
    return None


def b_pelo(g, col):           # the haircut pictogram, the hair in its colour
    tpl.pictogram(g.d, "hair", g.box, WHITE)
    if col:
        g.tint(col)
    return None


def b_piel(g, col):           # an open hand in the skin's colour
    p = g.p
    g.rr(p, .28, .42, .8, .92, .16)
    for x, top in ((.33, .2), (.46, .1), (.59, .12), (.72, .22)):
        g.rr(p, x - .055, top, x + .055, .6, .055)
    g.stroke(p, (.34, .72), (.12, .46), k=3.4)
    if col:
        g.tint(col)
    for x, top in ((.395, .3), (.525, .28), (.655, .34)):
        g.q.line((x, top + .1), (x, .54), k=.7)
    return None


def b_ojos(g, col):           # an eye, its iris in the colour
    p, q = g.p, g.q
    g.chord(p, -.04, .18, 1.04, 1.12, 198, 342)
    g.chord(p, -.04, -.12, 1.04, .82, 18, 162)
    q.disc(.5, .5, .25)
    p.disc(.5, .5, .2)
    if col:
        g.pen(col).disc(.5, .5, .2 - W / p.s * .9)
    q.disc(.5, .5, .08)
    p.disc(.56, .44, .035)
    for x in (.24, .5, .76):
        g.stroke(p, (x, .14 if x == .5 else .2), (x + (x - .5) * .3, .04 if x == .5 else .1), k=.8)
    return None


def b_titulo(g, col):         # a ribbon banner under a star
    p, q = g.p, g.q
    p.poly((.04, .52), (.2, .52), (.2, .84), (.04, .84), (.12, .68))
    p.poly((.96, .52), (.8, .52), (.8, .84), (.96, .84), (.88, .68))
    q.poly((.17, .74), (.24, .84), (.24, .74))
    q.poly((.83, .74), (.76, .84), (.76, .74))
    p.poly((.16, .44), (.84, .44), (.84, .74), (.16, .74))
    q.line((.26, .59), (.74, .59), k=.9)
    star(p, .5, .22, .2)
    return None


def face(g):
    g.p.disc(.5, .52, .42)


def b_aplaudir(g, col):       # two hands clapping, motion strokes
    for sx in (-1, 1):
        h = Image.new("RGBA", g.img.size, CLEAR)
        t = G(h, g.box)
        b_piel(t, None)
        h = h.resize((int(h.width * .78), int(h.height * .78)), Image.LANCZOS)
        if sx > 0:
            h = h.transpose(Image.FLIP_LEFT_RIGHT)
        h = h.rotate(sx * 16, resample=Image.BICUBIC)
        layer = Image.new("RGBA", g.img.size, CLEAR)
        x, y = g.p.P(.5 + sx * .21, .6)
        layer.alpha_composite(h, (int(x - h.width / 2), int(y - h.height / 2)))
        g.img.alpha_composite(layer)
    for a, b in (((.12, .2), (.22, .3)), ((.5, .02), (.5, .14)), ((.88, .2), (.78, .3))):
        g.stroke(g.p, a, b, k=.9)
    return None


def b_leer(g, col):           # an open book
    return b_codice(g, None)


def b_declarar(g, col):       # a heart, a small one beside
    s = g.sub(.04, .14, .8)
    m_corazon(s, s.p, s.q)
    badge(g, "corazon", .82, .2, .14)
    return None


def b_enfadarse(g, col):      # a cross face, an anger mark
    face(g)
    q = g.q
    q.line((.26, .38), (.44, .46), k=1)
    q.line((.74, .38), (.56, .46), k=1)
    q.disc(.36, .52, .05)
    q.disc(.64, .52, .05)
    q.ring(.5, .84, .16, 230, 310, k=1)
    g.q.disc(.84, .16, .2)
    for a in (0, 90, 180, 270):
        r = math.radians(a + 45)
        g.p.ring(.84 + .12 * math.cos(r), .16 + .12 * math.sin(r), .08, a + 45 + 90, a + 45 + 270, k=.9)
    return None


def b_laud(g, col):           # a lute
    p, q = g.p, g.q
    l = Image.new("RGBA", g.img.size, CLEAR)
    t = G(l, g.box)
    t.ell(t.p, .26, .4, .74, .96)
    t.p.rect(.5, .26, .14, .4, 0)
    t.p.rect(.5, .06, .2, .1, 0)
    t.q.disc(.5, .64, .08)
    t.q.line((.5, .74), (.5, .9), k=.5)
    t.q.rect(.5, .86, .2, .03, 0)
    l = l.rotate(-28, resample=Image.BICUBIC, center=t.p.P(.5, .55))
    g.img.alpha_composite(l)
    return None


def b_senalar(g, col):        # a pointing hand
    p, q = g.p, g.q
    g.rr(p, .1, .36, .54, .82, .12)
    g.rr(p, .36, .36, .94, .5, .07)
    for y in (.5, .62, .74):
        g.rr(p, .4, y, .6, y + .1, .05)
    q.line((.4, .5), (.56, .5), k=.6)
    q.line((.4, .62), (.6, .62), k=.6)
    q.line((.4, .74), (.6, .74), k=.6)
    g.rr(p, .18, .24, .3, .5, .05)
    return None


def b_troncharse(g, col):     # laughing: shut eyes, a wide open mouth
    face(g)
    q = g.q
    for x in (.34, .66):
        q.ring(x, .48, .08, 200, 340, k=1)
    g.chord(q, .26, .46, .74, .88, 0, 180)
    g.p.ring(.12, .36, .06, 0, 360, k=.6)
    return None


def b_asustarse(g, col):      # scared: round eyes, a wavy mouth, a drop
    face(g)
    q = g.q
    for x in (.36, .64):
        q.disc(x, .46, .08)
    q.line((.32, .74), (.4, .68), (.5, .74), (.6, .68), (.68, .74), k=.9)
    g.q.disc(.86, .2, .14)
    s = g.slot(.86, .2, .11)
    m_agua(s, s.p, s.q)
    return None


def b_llorar(g, col):         # crying: tears running down
    face(g)
    q = g.q
    for x in (.34, .66):
        q.ring(x, .44, .08, 20, 160, k=1)
    q.ring(.5, .86, .14, 220, 320, k=1)
    tear = g.pen(WATER)
    for x in (.32, .68):
        tear.rect(x, .6, .07, .18, 0)
        tear.disc(x, .7, .045)
    return None


def b_negar(g, col):          # a face shaking: closed mouth, swing marks
    s = g.sub(.1, .06, .8)
    face(s)
    s.q.disc(.36, .46, .06)
    s.q.disc(.64, .46, .06)
    s.q.line((.36, .72), (.64, .72), k=1)
    for sx in (-1, 1):
        g.p.ring(.5, .48, .48, (180 if sx < 0 else 0) - 22, (180 if sx < 0 else 0) + 22, k=1)
    return None


# fusion
def b_fragmento(g, col):      # broken shards of a gem
    p, q = g.p, g.q
    p.poly((.1, .62), (.34, .14), (.56, .36), (.46, .86))
    p.poly((.58, .48), (.8, .26), (.94, .62), (.7, .9))
    if col:
        g.tint(col)
    p.line((.34, .14), (.4, .56), (.46, .86), k=.6)
    p.line((.8, .26), (.76, .6), (.7, .9), k=.6)
    return None


def b_brillo(g, col):         # a small gem, a great glint
    s = g.sub(.08, .3, .62)
    s.p.poly((.24, .14), (.76, .14), (.96, .4), (.5, .94), (.04, .4))
    if col:
        s.tint(col)
    s.p.line((.04, .4), (.96, .4), k=.7)
    s.p.line((.3, .4), (.5, .9), (.7, .4), k=.7)
    g.q.disc(.74, .26, .22)
    sparkle(g.p, .74, .26, .24, .055)
    sparkle(g.p, .9, .66, .08, .02)
    return None


def b_bruto(g, col):          # a rough stone, crystals breaking out of it
    p, q = g.p, g.q
    crystals = Image.new("RGBA", g.img.size, CLEAR)
    c = G(crystals, g.box)
    c.p.poly((.32, .5), (.36, .12), (.5, .04), (.56, .48))
    c.p.poly((.52, .52), (.66, .2), (.78, .24), (.72, .56))
    if col:
        c.tint(col)
    g.img.alpha_composite(crystals)
    q.poly((.02, .5), (.98, .5), (.98, .58), (.02, .58))
    p.poly((.06, .9), (.1, .62), (.3, .52), (.62, .5), (.86, .56), (.96, .82), (.8, .94), (.3, .96))
    q.line((.3, .52), (.42, .74), (.3, .96), k=.7)
    q.line((.42, .74), (.8, .7), k=.7)
    return None


# arena
def b_islote(g, col):         # a floating island: a tree on a grass cap, a rock below
    p, q = g.p, g.q
    g.ell(p, .06, .5, .94, .7)
    p.poly((.1, .62), (.9, .62), (.7, .82), (.56, .86), (.5, .98), (.42, .86), (.28, .8))
    q.line((.06, .62), (.94, .62), k=.8)
    q.line((.36, .74), (.62, .74), k=.7)
    p.rect(.36, .44, .06, .16, 0)
    p.disc(.36, .3, .14)
    p.disc(.68, .5, .06)
    return (.84, .16, .14, "badge")


def b_faro(g, col):           # a lighthouse, its beams
    p, q = g.p, g.q
    p.poly((.4, .32), (.6, .32), (.68, .9), (.32, .9))
    p.rect(.5, .92, .6, .06, 0)
    p.rect(.5, .26, .3, .06, 0)
    g.rr(p, .41, .12, .59, .24, .02)
    p.poly((.38, .12), (.5, .02), (.62, .12))
    q.rect(.5, .18, .08, .06, 0)
    q.poly((.37, .5), (.63, .5), (.64, .58), (.36, .58))
    q.poly((.35, .7), (.65, .7), (.66, .78), (.34, .78))
    for sx in (-1, 1):
        p.poly((.5 + sx * .16, .16), (.5 + sx * .46, .06), (.5 + sx * .46, .26))
    return None


def b_torre(g, col):          # a tower, its battlements, mist lines
    p, q = g.p, g.q
    p.rect(.5, .56, .4, .76, 0)
    for x in (.33, .5, .67):
        p.rect(x, .16, .1, .1, 0)
    p.rect(.5, .22, .5, .06, 0)
    g.chord(q, .4, .62, .6, .98, 180, 360)
    q.rect(.5, .92, .2, .12, 0)
    q.rect(.5, .38, .06, .12, 0)
    for y, x0, x1 in ((.56, .02, .3), (.68, .7, .98), (.8, .06, .28)):
        g.stroke(p, (x0, y), (x1, y), k=.9)
    return None


def b_bosque(g, col):         # pines
    p, q = g.p, g.q
    for cx, top, s in ((.3, .2, .8), (.7, .08, 1.0)):
        for i, (y, w) in enumerate(((top, .18), (top + .2 * s, .26), (top + .4 * s, .34))):
            q.poly((cx, y - .04), (cx + (w + .04) * s, y + .28 * s), (cx - (w + .04) * s, y + .28 * s)) if cx == .3 else None
            p.poly((cx, y), (cx + w * s, y + .26 * s), (cx - w * s, y + .26 * s))
        p.rect(cx, top + .7 * s, .08, .14 * s, 0)
    p.rect(.5, .94, .9, .04, 0)
    return None


def b_cienaga(g, col):        # a swamp: cattails over still water
    p, q = g.p, g.q
    for x, top, lean in ((.3, .14, -.06), (.5, .06, 0), (.7, .2, .06)):
        g.stroke(p, (x, .78), (x + lean, top + .12), k=.8)
        g.rr(p, x + lean - .05, top, x + lean + .05, top + .24, .05)
    g.p.poly((.12, .78), (.24, .52), (.3, .78))
    g.p.poly((.72, .78), (.84, .56), (.9, .78))
    for y, x0, x1 in ((.84, .06, .94), (.94, .2, .8)):
        g.stroke(p, (x0, y), (x1, y), k=.9)
    return None


def b_volcan(g, col):         # a volcano, lava at its mouth, smoke
    p, q = g.p, g.q
    p.poly((.04, .94), (.36, .4), (.64, .4), (.96, .94))
    q.poly((.4, .4), (.6, .4), (.56, .56), (.52, .5), (.48, .62), (.44, .5))
    p.disc(.44, .24, .1)
    p.disc(.58, .16, .12)
    p.disc(.74, .1, .08)
    return None


def b_vado(g, col):           # a ford: stepping stones over a river
    p, q = g.p, g.q
    for y in (.3, .5, .7):
        g.stroke(p, (.06, y), (.94, y), k=.8)
        g.q.line((.06, y), (.94, y), k=.2)
    for x, y in ((.24, .78), (.46, .56), (.66, .38), (.84, .2)):
        q.disc(x, y, .14)
        g.ell(p, x - .11, y - .08, x + .11, y + .08)
    return None


def b_cueva(g, col):          # a cave mouth in a rock, embers inside
    p, q = g.p, g.q
    p.poly((.02, .94), (.14, .44), (.34, .18), (.6, .1), (.84, .26), (.98, .94))
    g.chord(q, .26, .46, .74, 1.3, 180, 360)
    q.rect(.5, .92, .48, .06, 0)
    p.poly(*flame_pts(.5, .84, .16, .22))
    return None


def b_sendero(g, col):        # a winding path to a crystal
    p, q = g.p, g.q
    p.poly((.2, .98), (.5, .98), (.44, .8), (.66, .62), (.58, .44), (.5, .44), (.54, .62), (.3, .78))
    p.poly((.62, .38), (.68, .06), (.8, .02), (.82, .36))
    p.poly((.82, .38), (.9, .16), (.96, .38))
    q.line((.68, .06), (.74, .36), k=.6)
    return None


def b_ensenada(g, col):       # a sailing boat in a cove
    p, q = g.p, g.q
    p.poly((.12, .66), (.88, .66), (.74, .82), (.26, .82))
    g.stroke(p, (.5, .08), (.5, .66), k=.8)
    p.poly((.46, .1), (.46, .6), (.12, .6))
    p.poly((.54, .16), (.54, .6), (.84, .6))
    for x in (.2, .5, .8):
        p.ring(x, .98, .12, 200, 340, k=.9)
    return None


def b_dunas(g, col):          # dunes under a sun
    p, q = g.p, g.q
    p.disc(.72, .26, .14)
    g.chord(p, -.3, .52, .7, 1.4, 180, 360)
    g.q.ring(.7, 1.22, .48, 200, 300, k=1.8)
    g.chord(p, .3, .6, 1.3, 1.4, 180, 360)
    p.rect(.5, .96, 1.0, .08, 0)
    return None


def b_jardin(g, col):         # a flower with two leaves
    p, q = g.p, g.q
    for i in range(6):
        a = math.radians(i * 60)
        p.disc(.5 + .17 * math.cos(a), .32 + .17 * math.sin(a), .13)
    q.disc(.5, .32, .1)
    p.disc(.5, .32, .065)
    g.stroke(p, (.5, .52), (.5, .96), k=1)
    p.poly((.5, .8), (.2, .62), (.26, .82))
    p.poly((.5, .72), (.82, .58), (.76, .78))
    return None


def b_bastion(g, col):        # a keep: battlements, a gate, a flag
    p, q = g.p, g.q
    p.rect(.5, .66, .8, .56, 0)
    for x in (.16, .34, .5, .66, .84):
        p.rect(x, .36, .1, .08, 0)
    g.chord(q, .36, .58, .64, 1.1, 180, 360)
    q.rect(.5, .9, .28, .14, 0)
    g.stroke(p, (.5, .3), (.5, .06), k=.8)
    p.poly((.52, .06), (.76, .12), (.52, .2))
    return None


def b_callejon(g, col):       # a street lantern
    p, q = g.p, g.q
    g.stroke(p, (.36, .96), (.36, .16), k=1.2)
    g.stroke(p, (.36, .18), (.66, .18), k=1.0)
    g.stroke(p, (.66, .18), (.66, .3), k=.7)
    p.poly((.54, .32), (.78, .32), (.74, .62), (.58, .62))
    p.poly((.52, .34), (.66, .24), (.8, .34))
    q.poly((.6, .38), (.72, .38), (.7, .56), (.62, .56))
    p.poly(*flame_pts(.66, .52, .07, .12))
    p.rect(.36, .94, .26, .06, 0)
    return None


# combat
def b_mapa(g, col):           # a folded map, a pin
    p, q = g.p, g.q
    p.poly((.04, .26), (.34, .18), (.66, .26), (.96, .18), (.96, .86), (.66, .94), (.34, .86), (.04, .94))
    q.line((.34, .2), (.34, .86), k=.8)
    q.line((.66, .28), (.66, .92), k=.8)
    return (.5, .56, .2)


def b_reloj(g, col, num=None):   # a stopwatch, its seconds on its face
    p, q = g.p, g.q
    p.disc(.5, .56, .4)
    p.rect(.5, .1, .16, .08, 0)
    p.rect(.5, .16, .08, .06, 0)
    p.rect(.84, .2, .1, .08, 45)
    q.disc(.5, .56, .4 - W / p.s * 1.1)
    if num:
        g.text(p, .5, .58, num, .44)
    else:
        g.stroke(p, (.5, .56), (.5, .3), k=1.1)
        g.stroke(p, (.5, .56), (.68, .66), k=1.1)
    return None


def b_reloj_arena(g, col):    # an hourglass, little sand left
    p, q = g.p, g.q
    p.rect(.5, .08, .7, .08, 0)
    p.rect(.5, .92, .7, .08, 0)
    p.poly((.22, .12), (.78, .12), (.56, .5), (.78, .88), (.22, .88), (.44, .5))
    q.poly((.3, .17), (.7, .17), (.53, .48), (.47, .48))
    q.poly((.47, .52), (.53, .52), (.68, .8), (.32, .8))
    p.poly((.5, .58), (.62, .8), (.38, .8))
    return None


def b_turnos(g, col):         # two arrows chasing round (the turns)
    p = g.p
    p.ring(.5, .54, .34, 200, 330, k=1.4)
    p.ring(.5, .54, .34, 20, 150, k=1.4)
    for a in (330, 150):
        r = math.radians(a)
        x, y = .5 + .34 * math.cos(r), .54 + .34 * math.sin(r)
        t = math.radians(a + 90)
        p.poly((x + .14 * math.cos(t), y + .14 * math.sin(t)), (x + .13 * math.cos(r), y + .13 * math.sin(r)),
               (x - .13 * math.cos(r), y - .13 * math.sin(r)))
    return None


def b_calavera(g, col):       # sudden death: a skull
    p, q = g.p, g.q
    p.disc(.5, .44, .36)
    g.rr(p, .3, .56, .7, .9, .08)
    q.disc(.36, .48, .1)
    q.disc(.64, .48, .1)
    q.poly((.5, .58), (.56, .7), (.44, .7))
    for x in (.42, .58):
        q.line((x, .78), (x, .9), k=.8)
    return None


def b_figura(g, col):         # one fighter
    s = g.sub(.14, .1, .72)
    m_figura(s, s.p, s.q)
    g.p.rect(.5, .88, .8, .04, 0)
    return None


def _figures(g, xs, scale=.5, y=.24):
    for x in xs:
        s = g.sub(x - scale / 2, y, scale)
        s.q.disc(.5, .28, .3)
        s.chord(s.q, .0, .44, 1.0, 1.46, 180, 360)
        m_figura(s, s.p, s.q)


def b_dos(g, col):            # two fighters
    _figures(g, (.32, .68), .56, .22)
    return None


def b_equipo(g, col):         # a squad of three
    _figures(g, (.24, .76), .44, .26)
    _figures(g, (.5,), .52, .3)
    return None


def b_etiqueta(g, col):       # a price tag, a mark of what it prices
    p, q = g.p, g.q
    p.poly((.3, .1), (.9, .1), (.9, .7), (.5, .94), (.3, .7))
    p.poly((.3, .1), (.08, .4), (.3, .7))
    q.disc(.22, .4, .06)
    g.stroke(p, (.22, .4), (.04, .1), k=.6)
    return (.62, .44, .2)


def b_rebaja(g, col):         # a tag with a percent sign
    b_etiqueta(g, col)
    q = g.q
    q.ring(.5, .3, .07, k=.8)
    q.ring(.74, .58, .07, k=.8)
    q.line((.76, .24), (.48, .64), k=.9)
    return None


def b_precio_sube(g, col):    # a stack of coins, an arrow up
    p, q = g.p, g.q
    for y in (.82, .66, .5):
        g.ell(q, .02, y - .14, .66, y + .1)
        g.ell(p, .06, y - .12, .62, y + .08)
    s = g.slot(.8, .4, .22)
    m_coraje(s, s.p, s.q)
    return None


def b_precio_baja(g, col):    # a stack of coins, an arrow down
    p, q = g.p, g.q
    for y in (.82, .66):
        g.ell(q, .02, y - .14, .66, y + .1)
        g.ell(p, .06, y - .12, .62, y + .08)
    d = Image.new("RGBA", g.img.size, CLEAR)
    t = G(d, g.box)
    s = t.slot(.8, .5, .22)
    m_coraje(s, s.p, s.q)
    d = d.rotate(180, center=t.p.P(.8, .5))
    g.img.alpha_composite(d)
    return None


def b_cofre(g, col):          # a war chest
    p, q = g.p, g.q
    g.chord(p, .08, .14, .92, .66, 180, 360)
    p.rect(.5, .66, .84, .5, 0)
    q.line((.08, .44), (.92, .44), k=.9)
    for x in (.26, .74):
        q.line((x, .2), (x, .9), k=.7)
    q.rect(.5, .48, .14, .16, 0)
    p.rect(.5, .48, .07, .09, 0)
    return None


def b_bolsa(g, col):          # a bag of money, coins spilling
    p, q = g.p, g.q
    p.disc(.44, .62, .34)
    p.poly((.3, .36), (.58, .36), (.66, .12), (.22, .12))
    q.line((.28, .34), (.6, .34), k=.9)
    g.text(q, .44, .66, "P", .36)
    q.disc(.84, .84, .14)
    p.disc(.84, .84, .11)
    return None


def b_quiebra(g, col):        # a coin broken in two
    p, q = g.p, g.q
    p.disc(.5, .5, .42)
    q.ring(.5, .5, .28, k=.8)
    q.poly((.46, .02), (.58, .02), (.5, .3), (.6, .5), (.48, .72), (.56, .98), (.44, .98), (.38, .72), (.5, .5), (.4, .3))
    return None


def b_hechizo(g, col):        # a spell: a sparkle in a magic ring
    p, q = g.p, g.q
    p.ring(.5, .5, .42, k=1.1)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        p.disc(.5 + .42 * math.cos(a), .5 + .42 * math.sin(a), .045)
    sparkle(p, .5, .5, .32, .08)
    return None


def b_martillo(g, col):
    p, q = g.p, g.q
    g.stroke(p, (.24, .92), (.6, .4), k=1.4)
    p.rect(.62, .3, .5, .22, 35)
    q.rect(.62, .3, .04, .22, 35)
    return None


def b_jersey(g, col):         # the coach family's jersey (gear)
    tpl.pictogram(g.d, "coach", g.box, WHITE)
    return None


def b_clase_oculta(g, col):
    s = g.sub(.04, .14, .82)
    m_figura(s, s.p, s.q)
    return None


def b_ojo_tachado(g, col):    # hidden stats: an eye struck through
    s = g.sub(.04, .12, .92)
    m_ojo(s, s.p, s.q)
    g.q.line((.1, .1), (.9, .9), k=2.6)
    g.stroke(g.p, (.14, .14), (.86, .86), k=1.1)
    return None


# other: the pets' parts (types 15-19) and the clan/tournament papers
def b_mascota_nucleo(g, col):   # the heart of a pet
    s = g.sub(.08, .1, .84)
    m_corazon(s, s.p, s.q)
    s.q.ring(.3, .38, .12, 190, 260, k=.8)
    return None


def b_mascota_patas(g, col):    # a paw print
    p = g.p
    g.ell(p, .26, .46, .74, .9)
    for x, y, r in ((.18, .38, .09), (.36, .2, .1), (.64, .2, .1), (.82, .38, .09)):
        p.disc(x, y, r)
    return None


def b_mascota_cabeza(g, col):   # a pet's head: ears, eyes, a nose
    p, q = g.p, g.q
    p.disc(.5, .58, .36)
    p.poly((.16, .44), (.18, .06), (.44, .26))
    p.poly((.84, .44), (.82, .06), (.56, .26))
    q.disc(.37, .54, .06)
    q.disc(.63, .54, .06)
    q.poly((.44, .66), (.56, .66), (.5, .74))
    return None


def b_mascota_cuerpo(g, col):   # a stitched patch of hide (the body's stuff)
    p, q = g.p, g.q
    p.rect(.5, .5, .76, .7, 6)
    for i in range(7):            # the stitches round it
        t = i / 6
        for (x0, y0), (x1, y1) in ((((.22, .22)), (.78, .22)), ((.22, .78), (.78, .78))):
            x = x0 + (x1 - x0) * t
            q.rect(x, y0, .045, .09, 6)
    for i in range(5):
        t = i / 4
        for x in (.2, .8):
            q.rect(x, .3 + .4 * t, .09, .045, 6)
    g.stroke(q, (.4, .4), (.6, .6), k=1)
    g.stroke(q, (.6, .4), (.4, .6), k=1)
    return None


def b_mascota_juguete(g, col):  # a ball of yarn, its loose end
    p, q = g.p, g.q
    p.disc(.46, .46, .38)
    for r in (.3, .44, .58):          # one wind of strands, a band across it
        q.ring(.12, .86, r, 280, 360, k=.85)
    for r in (.22, .34):
        q.ring(.84, .2, r, 100, 190, k=.85)
    g.stroke(p, (.72, .74), (.84, .9), (.66, .96), (.92, .98), k=.9)
    return None

def b_clan(g, col):           # a clan's crest
    s = g.sub(.06, .04, .88)
    m_escudo(s, s.p, s.q)
    return None


def b_torneo(g, col):         # a tournament cup
    s = g.sub(.06, .06, .88)
    opt.glyph(s.p, 3, CLEAR)
    return None


def b_canica(g, col):         # a marble: glass with a twist of colours in it
    p, q = g.p, g.q
    p.disc(.5, .5, .42)
    g.tint((60, 150, 240))
    for (cx, cy), a0, a1, c in (((.36, .5), 270, 450, (250, 206, 40)), ((.64, .5), 90, 270, (240, 70, 100))):
        g.arc(g.pen(c), cx - .2, cy - .2, cx + .2, cy + .2, a0, a1, k=2.2)
    p.disc(.34, .3, .06)
    return None


def b_espadas(g, col):        # the fighter family's crossed swords (fighter gear)
    tpl.pictogram(g.d, "fighter", g.box, WHITE)
    return None


def b_pase(g, col):           # a ticket (the family's 'other'), a padlock
    tpl.pictogram(g.d, "other", g.box, WHITE)
    return None


BASES = {k[2:]: v for k, v in dict(globals()).items() if k.startswith("b_")}

# variant → (mark, accent colour or None); a base with no mark slot uses the colour
VARIANTS = {
    "agua": ("agua", WATER), "fuego": ("fuego", FIRE), "tierra": ("tierra", EARTH), "aire": ("aire", AIR),
    "ala": ("ala", AIR), "escarcha": ("escarcha", ICE), "rayo": ("rayo", BOLT),
    "escudo": ("escudo", None), "ojo": ("ojo", None), "diana": ("diana", None), "fuerza": ("fuerza", None),
    "corazon": ("corazon", None), "luna": ("luna", None), "rapido": ("rapido", None), "coraje": ("coraje", None),
    "moneda": ("moneda", None), "estrella": ("estrella", None), "halo": ("halo", None), "eco": ("eco", None),
    "pegajosa": ("pegajosa", None), "cruz": ("cruz", None), "gema": ("gema", None), "hoja": ("hoja", None),
    "savia": ("hoja", AIR), "copa": ("copa", None), "rombo": ("rombo", None), "destello": ("destello", None),
    "figura": ("figura", None), "espadas": ("espadas", None), "roca": ("roca", None), "tronco": ("tronco", None),
    "interrogacion": ("interrogacion", None),
    "yunque": ("yunque", None), "cayado": ("cayado", None), "colmillo": ("colmillo", None), "arado": ("arado", None),
    "hacha": ("hacha", None), "varita": ("varita", None), "arco": ("arco", None),
}


def draw(spec, px):
    """The pictogram for spec = (base, variant, colour, mods) at px pixels."""
    base, variant, colour, mods = spec
    n = px * S
    img = Image.new("RGBA", (n, n), CLEAR)
    g = G(img, (n * .14, n * .14, n * .72))
    badges = [m[6:] for m in mods if m.startswith("badge:")]
    inner = g
    if badges:
        inner = g.sub(0, .12, .88)
    elif "small" in mods:
        inner = g.sub(.12, .2, .76)
    if "ban" in mods:
        inner = g.sub(.15, .15, .7)
    mk, mcol = VARIANTS.get(variant, (None, None)) if variant else (None, None)
    col = colour if colour is not None else (mcol if mk is None else None)
    f = BASES[base]
    if base == "runa":
        slot = f(inner, col, rune=variant)
        mk = None
    elif base == "reloj":
        slot = f(inner, col, num=variant)
        mk = None
    else:
        slot = f(inner, col)
    if mk and slot:
        cx, cy, r = slot[:3]
        mode = slot[3] if len(slot) > 3 else "carve"
        if mode == "badge":
            badge(inner, mk, cx, cy, r)
        else:
            if mode == "solid":
                inner.q.disc(cx, cy, r * 1.05)
            mark(inner, mk, cx, cy, r, mode, mcol if mode != "solid" else None)
    if "ban" in mods:
        g.q.ring(.5, .5, .46, k=3.2)
        g.q.line((.18, .18), (.82, .82), k=3.2)
        g.p.ring(.5, .5, .46, k=1.5)
        g.stroke(g.p, (.19, .19), (.81, .81), k=1.5)
    for b in badges:
        badge(g, b)
    return img.resize((px, px), Image.LANCZOS)
