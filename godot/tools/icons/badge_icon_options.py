"""S38b: achievement, token and peseta icons in style B — an option sheet.
Achievements: a pictogram per category (combat, tournaments, feats,
collection, progress), the grade (points / 5, 1..5) as its metal, a padlock
while pending, in three treatments. Tokens (types 1, 2, 3, 5) and pesetas
(type 10, text today): three coin treatments, also at their real size beside
an amount. Run from godot/: python3 tools/icons/badge_icon_options.py out.png
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFont

S = 4
N = 64 * S
INK = (28, 32, 48)
WHITE = (255, 255, 255)
# grade (retail: olive, copper, silver, gold, crystal) → ours: bronze .. crystal
GRADE = {1: (176, 112, 64), 2: (140, 152, 172), 3: (222, 166, 36), 4: (214, 64, 92), 5: (64, 182, 206)}
GREY = (176, 180, 192)
# achievement category (npcdialogs.json "cat")
CAT = {1: ('Combate', (226, 74, 60)), 3: ('Torneos', (122, 88, 204)), 5: ('Hazañas', (238, 138, 36)),
       6: ('Colección', (47, 116, 240)), 8: ('Progreso', (48, 168, 118))}
# token type → colour; 10 = pesetas
TOKEN = {1: ('Fichas', (255, 77, 109)), 2: ('Tipo 2', (47, 116, 240)), 3: ('Tipo 3', (48, 168, 118)),
         5: ('Tipo 5', (122, 88, 204)), 10: ('Pesetas', (217, 154, 43))}
FONT = 'assets/ui/fonts/SairaCondensed-ExtraBold.ttf'
BODY = 'assets/ui/fonts/Nunito-Variable.ttf'


def lighter(c, k=0.35):
    return tuple(round(v + (255 - v) * k) for v in c)


def darker(c, k=0.3):
    return tuple(round(v * (1 - k)) for v in c)


class Pen:
    """Draws a pictogram in 0..1 units inside a box (x, y, side) of a draw."""

    def __init__(self, d, box, col, w):
        self.d, (self.x, self.y, self.s), self.col, self.w = d, box, col, w

    def P(self, x, y):
        return (self.x + x * self.s, self.y + y * self.s)

    def line(self, *pts, k=1.0):
        self.d.line([self.P(*p) for p in pts], fill=self.col, width=int(self.w * k), joint='curve')

    def poly(self, *pts, fill=None):
        self.d.polygon([self.P(*p) for p in pts], fill=fill or self.col)

    def disc(self, cx, cy, r, fill=None):
        self.d.ellipse([self.P(cx - r, cy - r), self.P(cx + r, cy + r)], fill=fill or self.col)

    def ring(self, cx, cy, r, a0=0, a1=360, k=1.0):
        self.d.arc([self.P(cx - r, cy - r), self.P(cx + r, cy + r)], a0, a1, fill=self.col, width=int(self.w * k))

    def rect(self, cx, cy, w, h, ang, fill=None):
        a = math.radians(ang)
        pts = []
        for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            pts.append((cx + dx * math.cos(a) - dy * math.sin(a), cy + dx * math.sin(a) + dy * math.cos(a)))
        self.poly(*pts, fill=fill)


def glyph(p, what, back):
    """`back` is the colour under the glyph (for cut-outs)."""
    if what == 1:     # combat: two crossed swords (hilt low, point high)
        for (hx, hy), (tx, ty) in (((.2, .86), (.86, .14)), ((.8, .86), (.14, .14))):
            dx, dy = tx - hx, ty - hy
            l = math.hypot(dx, dy)
            ux, uy, nx, ny = dx / l, dy / l, -dy / l, dx / l
            gx, gy = hx + ux * .2, hy + uy * .2      # the guard
            w0, w1 = .075, .05
            p.poly((gx + nx * w0, gy + ny * w0), (tx - ux * .1 + nx * w1, ty - uy * .1 + ny * w1), (tx, ty),
                   (tx - ux * .1 - nx * w1, ty - uy * .1 - ny * w1), (gx - nx * w0, gy - ny * w0))
            p.line((gx - nx * .17, gy - ny * .17), (gx + nx * .17, gy + ny * .17), k=1.1)
            p.line((hx, hy), (gx, gy), k=1.0)
            p.disc(hx, hy, .06)
    elif what == 3:   # tournaments: a cup
        p.poly((.2, .12), (.8, .12), (.72, .45), (.6, .55), (.4, .55), (.28, .45))
        p.ring(.2, .3, .14, 90, 270)
        p.ring(.8, .3, .14, 270, 90)
        p.rect(.5, .66, .12, .2, 0)
        p.rect(.5, .84, .44, .1, 0)
    elif what == 5:   # feats: an impact burst
        pts = []
        for i in range(16):
            r = .46 if i % 2 == 0 else .2
            a = math.radians(i * 22.5 - 90)
            pts.append((.5 + r * math.cos(a), .52 + r * math.sin(a)))
        p.poly(*pts)
    elif what == 6:   # collection: three cards fanned
        for ang, dx in ((-22, -.16), (0, 0), (22, .16)):
            p.rect(.5 + dx, .52 + abs(dx) * .3, .38, .56, ang, fill=back)
            p.rect(.5 + dx, .52 + abs(dx) * .3, .32, .5, ang)
    elif what == 8:   # progress: three rank chevrons
        for y in (.1, .38, .66):
            p.poly((.12, y + .26), (.5, y), (.88, y + .26), (.88, y + .14), (.5, y - .12 + .12), (.12, y + .14))
            p.poly((.12, y + .26), (.5, y + .02), (.88, y + .26), (.88, y + .14), (.5, y - .1), (.12, y + .14))
    elif what == 'lock':
        p.ring(.5, .4, .2, 180, 360, k=1.4)
        p.line((.3, .4), (.3, .48), k=1.4)
        p.line((.7, .4), (.7, .48), k=1.4)
        p.rect(.5, .66, .56, .4, 0)
        p.disc(.5, .63, .06, fill=back)
        p.rect(.5, .72, .05, .1, 0, fill=back)
    elif what == 'star':   # a token's mark
        pts = []
        for i in range(10):
            r = .46 if i % 2 == 0 else .2
            a = math.radians(i * 36 - 90)
            pts.append((.5 + r * math.cos(a), .52 + r * math.sin(a)))
        p.poly(*pts)
    elif what == 'peseta':  # the peseta sign: a P crossed by a bar
        f = ImageFont.truetype(FONT, int(p.s * 1.05))
        cx, cy = p.P(.5, .5)
        p.d.text((cx, cy), 'P', font=f, fill=p.col, anchor='mm')
        p.line((.1, .4), (.9, .4), k=1.0)

def plate(d, fill):
    k = int(N * 0.12)
    d.polygon([(k, 0), (N, 0), (N - k, N), (0, N)], fill=fill + (255,))
    d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 4)


def ach(cat, grade, done, style):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    metal = GRADE[grade] if done else GREY
    what = cat if done else 'lock'
    if style == 'A':      # the spells' slanted plate, in the grade's metal
        plate(d, metal)
        glyph(Pen(d, (N * .2, N * .2, N * .6), WHITE, S * 5), what, metal)
    elif style == 'B':    # a medallion: metal rim, the category's colour inside
        inner = CAT[cat][1] if done else lighter(GREY, .2)
        d.ellipse((S * 2, S * 2, N - S * 2, N - S * 2), fill=INK)
        d.ellipse((S * 6, S * 6, N - S * 6, N - S * 6), fill=metal)
        d.arc((S * 9, S * 9, N - S * 9, N - S * 9), 200, 320, fill=lighter(metal, .5), width=S * 3)
        d.ellipse((S * 17, S * 17, N - S * 17, N - S * 17), fill=INK)
        d.ellipse((S * 19, S * 19, N - S * 19, N - S * 19), fill=inner)
        glyph(Pen(d, (N * .3, N * .3, N * .4), WHITE, S * 4), what, inner)
    else:                 # a rosette: metal disc, ribbon tails in the category's colour
        tail = CAT[cat][1] if done else GREY
        for sx in (-1, 1):
            cx = N / 2 + sx * N * .14
            pts = [(cx - N * .1, N * .5), (cx + N * .1, N * .5), (cx + N * .1 + sx * N * .06, N * .98),
                   (cx + sx * N * .04, N * .86), (cx - N * .1 + sx * N * .06, N * .98)]
            d.polygon(pts, fill=INK)
            inset = [(x + (S * 2 if x < cx else -S * 2), y + S * 2) for x, y in pts]
            d.polygon(inset, fill=tail)
        r = N * .36
        c = (N / 2, N * .4)
        teeth = []
        for i in range(32):
            rr = r if i % 2 == 0 else r * .9
            a = math.radians(i * 11.25)
            teeth.append((c[0] + rr * math.cos(a), c[1] + rr * math.sin(a)))
        d.polygon(teeth, fill=INK)
        d.ellipse((c[0] - r * .84, c[1] - r * .84, c[0] + r * .84, c[1] + r * .84), fill=metal)
        d.arc((c[0] - r * .7, c[1] - r * .7, c[0] + r * .7, c[1] + r * .7), 200, 320, fill=lighter(metal, .5), width=S * 3)
        glyph(Pen(d, (c[0] - r * .5, c[1] - r * .52, r), WHITE, S * 4), what, metal)
    return img


def token(t, style):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    col = TOKEN[t][1]
    what = 'peseta' if t == 10 else 'star'
    if style == 'A':      # a flat chip: notched rim, white mark
        d.ellipse((S * 2, S * 2, N - S * 2, N - S * 2), fill=INK)
        d.ellipse((S * 6, S * 6, N - S * 6, N - S * 6), fill=col)
        for i in range(8):
            a = math.radians(i * 45)
            cx, cy = N / 2 + N * .38 * math.cos(a), N / 2 + N * .38 * math.sin(a)
            d.ellipse((cx - S * 7, cy - S * 7, cx + S * 7, cy + S * 7), fill=WHITE)
        d.ellipse((N * .24, N * .24, N * .76, N * .76), fill=darker(col, .15))
        glyph(Pen(d, (N * .32, N * .31, N * .36), WHITE, S * 4), what, col)
    elif style == 'B':    # a coin in three-quarters: its edge below the face
        top, h = N * .16, N * .5
        d.ellipse((S * 2, top + N * .16, N - S * 2, top + h + N * .16), fill=INK)
        d.rectangle((S * 2, top + h / 2, N - S * 2, top + h / 2 + N * .16), fill=INK)
        d.ellipse((S * 6, top + N * .16, N - S * 6, top + h + N * .16 - S * 4), fill=darker(col, .3))
        d.rectangle((S * 6, top + h / 2, N - S * 6, top + h / 2 + N * .14), fill=darker(col, .3))
        d.ellipse((S * 2, top - S * 2, N - S * 2, top + h + S * 2), fill=INK)
        d.ellipse((S * 6, top + S * 2, N - S * 6, top + h - S * 2), fill=col)
        d.arc((S * 14, top + S * 6, N - S * 14, top + h - S * 8), 190, 330, fill=lighter(col, .5), width=S * 3)
        face = Image.new('RGBA', (N, N), (0, 0, 0, 0))
        glyph(Pen(ImageDraw.Draw(face), (N * .3, N * .3, N * .4), WHITE, S * 5), what, col)
        face = face.resize((N, int(N * .55)), Image.LANCZOS)   # the mark lies on the face
        img.alpha_composite(face, (0, int(top + h / 2 - face.height / 2)))
    else:                 # a hexagonal token, slanted like the plates
        pts = [(N / 2 + N * .46 * math.cos(math.radians(a)), N / 2 + N * .46 * math.sin(math.radians(a)))
               for a in range(30, 390, 60)]
        d.polygon(pts, fill=INK)
        inner = [(N / 2 + N * .4 * math.cos(math.radians(a)), N / 2 + N * .4 * math.sin(math.radians(a)))
                 for a in range(30, 390, 60)]
        d.polygon(inner, fill=col)
        d.line([inner[3], inner[4], inner[5]], fill=lighter(col, .45), width=S * 3)
        glyph(Pen(d, (N * .28, N * .27, N * .44), WHITE, S * 5), what, col)
    return img


def at(im, px):
    return im.resize((px, px), Image.LANCZOS)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'badge_options.png'
    W, H = 1280, 720
    sheet = Image.new('RGBA', (W, H), (233, 236, 241, 255))
    d = ImageDraw.Draw(sheet)
    title = ImageFont.truetype(FONT, 26)
    head = ImageFont.truetype(FONT, 19)
    small = ImageFont.truetype(BODY, 12)
    num = ImageFont.truetype(FONT, 22)
    d.text((24, 14), 'S38b · LOGROS, FICHAS Y PESETAS — OPCIONES', font=title, fill=INK)
    labels = {'A': 'A · placa de los hechizos, del metal del grado',
              'B': 'B · medallón: borde de metal, centro del color de la categoría',
              'C': 'C · escarapela: disco de metal, cintas de la categoría'}
    for r, st in enumerate('ABC'):
        y = 58 + r * 150
        d.text((24, y), labels[st], font=head, fill=INK)
        x = 24
        for cat in CAT:
            sheet.alpha_composite(at(ach(cat, 3, True, st), 80), (x, y + 28))
            d.text((x + 4, y + 112), CAT[cat][0], font=small, fill=(107, 113, 131))
            x += 88
        x += 24
        for g in range(1, 6):
            sheet.alpha_composite(at(ach(1, g, True, st), 64), (x, y + 40))
            d.text((x + 6, y + 112), 'grado %d' % g, font=small, fill=(107, 113, 131))
            x += 70
        x += 24
        sheet.alpha_composite(at(ach(5, 3, False, st), 80), (x, y + 28))
        d.text((x + 6, y + 112), 'pendiente', font=small, fill=(107, 113, 131))
        x += 100
        # in the achievements list at its real size (52 px, lobby_panels.gd)
        d.rectangle((x, y + 34, x + 300, y + 102), fill=(255, 255, 255), outline=(200, 204, 214))
        sheet.alpha_composite(at(ach(6, 4, True, st), 52), (x + 8, y + 42))
        d.text((x + 70, y + 46), 'Tiris Set', font=ImageFont.truetype(BODY, 14), fill=INK)
        d.rectangle((x + 70, y + 70, x + 280, y + 76), fill=(220, 224, 232))
        d.rectangle((x + 70, y + 70, x + 196, y + 76), fill=(255, 77, 109))
        d.text((x + 70, y + 80), '20 pts', font=small, fill=(255, 77, 109))
    y = 520
    d.line((24, y - 8, W - 24, y - 8), fill=(200, 204, 214), width=2)
    tl = {'A': 'A · ficha plana, muescas', 'B': 'B · moneda de tres cuartos', 'C': 'C · ficha hexagonal'}
    for i, st in enumerate('ABC'):
        x = 24 + i * 420
        d.text((x, y), tl[st], font=head, fill=INK)
        for j, t in enumerate(TOKEN):
            sheet.alpha_composite(at(token(t, st), 64), (x + j * 76, y + 30))
            d.text((x + j * 76 + 4, y + 98), TOKEN[t][0], font=small, fill=(107, 113, 131))
        # beside an amount, the size the cards and the header use (~24 px)
        bx = x
        for t, amount in ((1, '1.120'), (10, '300')):
            d.text((bx, y + 124), amount, font=num, fill=INK)
            wv = d.textlength(amount, font=num)
            sheet.alpha_composite(at(token(t, st), 26), (int(bx + wv + 6), y + 127))
            bx += int(wv) + 50
    sheet.convert('RGB').save(out)
    print(out)


if __name__ == '__main__':
    main()
