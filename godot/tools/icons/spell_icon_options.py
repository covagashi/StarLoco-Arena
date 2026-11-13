"""S38 pilot: the Iop's 10 spell icons in three style-B options."""
import math, sys
from PIL import Image, ImageDraw, ImageFont
S = 4
N = 64 * S
INK = (28, 32, 48)
EL = {'neutral': (120, 126, 146), 'fire': (232, 84, 52), 'water': (47, 116, 240), 'air': (54, 180, 140), 'earth': (176, 120, 52)}
PALE = {k: tuple(round(255 - (255 - c) * 0.22) for c in v) for k, v in EL.items()}

def P(x, y):  # 0..1 units → pixels in the glyph box (inset 14%)
    m = 0.16 * N
    return (m + x * (N - 2 * m), m + y * (N - 2 * m))

def glyphs(d, col, w):
    def L(*pts, width=w): d.line([P(*p) for p in pts], fill=col, width=width, joint='curve')
    def poly(*pts): d.polygon([P(*p) for p in pts], fill=col)
    def circ(cx, cy, r, fill=None):
        a, b = P(cx - r, cy - r), P(cx + r, cy + r)
        d.ellipse([a, b], outline=None if fill else col, fill=fill, width=w)
    def sword(x0, y0, x1, y1):
        L((x0, y0), (x1, y1), width=int(w * 1.5))
        dx, dy = x1 - x0, y1 - y0
        l = math.hypot(dx, dy); nx, ny = -dy / l, dx / l
        gx, gy = x0 + dx * 0.78, y0 + dy * 0.78
        L((gx - nx * .18, gy - ny * .18), (gx + nx * .18, gy + ny * .18))
    def arc(cx, cy, r, a0, a1):
        a, b = P(cx - r, cy - r), P(cx + r, cy + r)
        d.arc([a, b], a0, a1, fill=col, width=w)
    return {
        4: lambda: (L((.5, .05), (.5, .6)), poly((.28, .45), (.72, .45), (.5, .75)), L((.1, .95), (.9, .95)), L((.2, .82), (.35, .9)), L((.8, .82), (.65, .9))),
        5: lambda: (sword(.15, .9, .85, .1), circ(.78, .78, .12)),
        6: lambda: (arc(.5, .7, .4, 180, 360), poly((.82, .55), (.98, .78), (.7, .78)), L((.05, .95), (.3, .95)), L((.7, .95), (.95, .95))),
        7: lambda: (d.polygon([P(.5, .92), P(.08, .45), P(.2, .15), P(.5, .3), P(.8, .15), P(.92, .45)], outline=col, width=w), L((.5, .42), (.5, .72)), L((.35, .57), (.65, .57))),
        8: lambda: (L((.2, .05), (.2, .98), width=int(w * 1.3)), d.polygon([P(.2, .08), P(.9, .2), P(.62, .35), P(.9, .5), P(.2, .5)], outline=col, width=w)),
        9: lambda: (L((.15, .2), (.45, .85)), L((.4, .1), (.7, .8)), L((.65, .05), (.92, .62))),
        164: lambda: (L((.1, .85), (.9, .15), width=int(w * 1.6)), L((.1, .85), (.25, .8)),),
        165: lambda: (sword(.5, .98, .5, .2), d.polygon([P(.5, .0), P(.62, .2), P(.75, .1), P(.7, .35), P(.3, .35), P(.25, .1), P(.38, .2)], fill=col)),
        166: lambda: (sword(.3, .95, .7, .25), poly((.78, .02), (.82, .14), (.95, .16), (.84, .23), (.88, .36), (.78, .28), (.68, .36), (.72, .23), (.61, .16), (.74, .14))),
        167: lambda: (poly((.5, .02), (.85, .38), (.62, .38), (.62, .55), (.38, .55), (.38, .38), (.15, .38)), poly((.5, .45), (.85, .8), (.62, .8), (.62, .98), (.38, .98), (.38, .8), (.15, .8))),
    }

def icon(sid, el, style):
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = int(N * 0.12)
    sq = [(k, 0), (N, 0), (N - k, N), (0, N)]
    if style == 'A':      # ink line on the element's pale field
        d.polygon(sq, fill=PALE[el] + (255,))
        d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 4)
        glyphs(d, INK, int(S * 4.2))[sid]()
    elif style == 'B':    # white on the element's colour, ink rule on top
        d.polygon(sq, fill=EL[el] + (255,))
        d.line([(k, S * 2), (N, S * 2)], fill=INK, width=S * 4)
        glyphs(d, (255, 255, 255), int(S * 4.6))[sid]()
    else:                 # ink on white, the element as a diagonal band
        d.polygon(sq, fill=(255, 255, 255, 255))
        d.polygon([(0, N * .78), (N, N * .38), (N, N * .58), (0, N * .98)], fill=EL[el] + (90,))
        d.polygon(sq, outline=INK, width=S * 2)
        glyphs(d, INK, int(S * 4.2))[sid]()
    return img.resize((64, 64), Image.LANCZOS)

spells = [(4, 'earth', 'Pressure'), (5, 'air', 'Sword of Fate'), (6, 'neutral', 'Jump'), (7, 'neutral', 'Vitality'),
          (8, 'neutral', 'Bravery Guide'), (9, 'air', 'Mutilation'), (164, 'neutral', 'Cut'), (165, 'fire', "Iop's Wrath"),
          (166, 'earth', 'Celestial Sword'), (167, 'neutral', 'Increase')]
font = ImageFont.truetype('/var/home/davian/codigo/StarLoco-Arena/godot/assets/ui/fonts/SairaCondensed-ExtraBold.ttf', 22)
small = ImageFont.truetype('/var/home/davian/codigo/StarLoco-Arena/godot/assets/ui/fonts/Nunito-Variable.ttf', 12)
W, H = 1280, 720
sheet = Image.new('RGBA', (W, H), (233, 236, 241, 255))
d = ImageDraw.Draw(sheet)
d.text((30, 20), 'S38 · ICONOS DE HECHIZO · PILOTO YOPUKA — TRES OPCIONES', font=font, fill=INK)
for r, st in enumerate('ABC'):
    label = {'A': 'A · trazo tinta sobre el pálido del elemento', 'B': 'B · blanco sobre el color del elemento', 'C': 'C · tinta sobre blanco, banda del elemento'}[st]
    y = 80 + r * 210
    d.text((30, y), label, font=font, fill=INK)
    for i, (sid, el, nm) in enumerate(spells):
        x = 30 + i * 122
        ic = icon(sid, el, st).resize((96, 96), Image.LANCZOS)
        sheet.alpha_composite(ic, (x, y + 40))
        d.text((x, y + 142), nm, font=small, fill=(107, 113, 131))
# in the fight's spell bar at real size
y = 720 - 70
d.rectangle([30, y - 10, 30 + 10 * 64 + 24, y + 62], fill=(18, 21, 42))
for i, (sid, el, nm) in enumerate(spells):
    sheet.alpha_composite(icon(sid, el, 'B').resize((52, 52), Image.LANCZOS), (42 + i * 64, y - 2))
d.text((700, y + 10), '< B en la barra del combate, a su tamaño', font=small, fill=INK)
sheet.convert('RGB').save(sys.argv[1])
