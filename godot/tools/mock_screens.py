#!/usr/bin/env python3
"""S18 direction sketches: the same three screens in three visual directions.

    python3 tools/mock_screens.py OUT_DIR [--fight=/tmp/fight-ui.png]
        [--fight1bit=/tmp/fight-ui-onebit.png]

Run from godot/. Writes OUT_DIR/<dir>-<screen>.png at 1280x720 for
directions A (S17 fight HUD family), B (1-bit, S04) and C (card table), and
screens login / ranking / cardmaster. These are sketches for the owner to
choose a direction (sprints/S18), not the implementation: the chosen one is
rebuilt as Godot controls. Real art: card illustrations and breed portraits
from assets/gui/images; the fight captures come from the visual test lane
(./run_tests.sh writes them to /tmp).
"""

import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1280, 720
F_COPPER = "assets/gui/fonts/COPRGTB.TTF"
F_BODY = "assets/gui/fonts/TAHOMA.TTF"
CARD_ART = "assets/gui/images/equipments/coachs/illustrations/%d.png"
PORTRAIT = "assets/gui/images/theme/images/breeds/%d.png"

# Sample content: one Card Master set (Gobkool, set 5) and placeholder ladder
# rows. Mock data, labelled as such on the sheet.
SET_CARDS = [16, 17, 18, 19, 20, 21, 22, 23]
LADDER = [("1", "Kerubim", "212", "40"), ("2", "Nox", "198", "51"),
          ("3", "Arel", "190", "38"), ("4", "Lou", "171", "66"),
          ("5", "Sadida07", "160", "70"), ("6", "Goultard", "152", "49"),
          ("7", "Test", "140", "61"), ("8", "Remington", "133", "72")]
ME = "Arel"
TABS = ["1v1", "Jefes", "2v2", "Clanes", "Torneos", "Pro", "Demonios"]


def font(path, size):
    return ImageFont.truetype(path, size)


def card_names():
    try:
        d = json.load(open("assets/gamedata/cards.json"))
        return {int(k): v["name"] for k, v in d.items()}
    except OSError:
        return {}


NAMES = card_names()


def bayer(img: Image.Image) -> Image.Image:
    """Ordered 4x4 Bayer to pure black/white, like the S04 1-bit maps."""
    m = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9],
                  [15, 7, 13, 5]]) / 16.0
    g = np.asarray(img.convert("L"), dtype=float) / 255.0
    h, w = g.shape
    t = np.tile(m, (h // 4 + 1, w // 4 + 1))[:h, :w]
    return Image.fromarray(((g > t) * 255).astype(np.uint8)).convert("RGB")


class Style:
    name = ""

    def __init__(self, fight, fight1):
        self.fight, self.fight1 = fight, fight1

    # --- to override ---------------------------------------------------
    def background(self) -> Image.Image: ...
    def panel(self, im, d, r): ...
    def title(self, d, xy, text, size=34, anchor="la"): ...
    def text(self, d, xy, text, size=18, anchor="la", muted=False): ...
    def button(self, im, d, r, text, primary=False): ...
    def field(self, im, d, r, label, value): ...
    def tab(self, im, d, r, text, on): ...
    def row(self, im, d, r, cells, xs, me=False, head=False): ...
    def card(self, im, d, r, cid, selected=False): ...
    def art(self, img): return img


def rounded(d, r, rad, **kw):
    x, y, w, h = r
    d.rounded_rectangle([x, y, x + w, y + h], rad, **kw)


def shadow(im, r, rad, off=6, blur=10, alpha=150):
    x, y, w, h = r
    s = Image.new("RGBA", im.size)
    ImageDraw.Draw(s).rounded_rectangle([x, y + off, x + w, y + h + off], rad,
                                        fill=(0, 0, 0, alpha))
    im.alpha_composite(s.filter(ImageFilter.GaussianBlur(blur)))


def paste_fit(im, img, r):
    x, y, w, h = r
    img = img.copy()
    img.thumbnail((w, h), Image.LANCZOS)
    im.alpha_composite(img.convert("RGBA"),
                       (x + (w - img.width) // 2, y + (h - img.height) // 2))


def load(path):
    try:
        return Image.open(path).convert("RGBA")
    except OSError:
        return Image.new("RGBA", (80, 110), (90, 90, 90, 255))


# --- A: the S17 fight HUD family ---------------------------------------------
class Arena(Style):
    name = "A"
    GOLD = (214, 172, 92)
    INK = (240, 228, 196)

    def background(self):
        bg = self.fight.resize((W, H), Image.LANCZOS).filter(
            ImageFilter.GaussianBlur(9))
        dark = Image.new("RGBA", (W, H), (10, 12, 18, 150))
        bg = bg.convert("RGBA")
        bg.alpha_composite(dark)
        return bg

    def panel(self, im, d, r):
        shadow(im, r, 18)
        x, y, w, h = r
        p = Image.new("RGBA", im.size)
        pd = ImageDraw.Draw(p)
        pd.rounded_rectangle([x, y, x + w, y + h], 18, fill=(20, 24, 32, 232),
                             outline=self.GOLD, width=3)
        pd.line([x + 20, y + 4, x + w - 20, y + 4], fill=(255, 230, 170, 70), width=2)
        im.alpha_composite(p)

    def title(self, d, xy, text, size=34, anchor="la"):
        d.text(xy, text.upper(), font=font(F_COPPER, size), fill=(240, 205, 120),
               anchor=anchor, stroke_width=2, stroke_fill=(40, 26, 8))

    def text(self, d, xy, text, size=18, anchor="la", muted=False):
        d.text(xy, text, font=font(F_BODY, size), anchor=anchor,
               fill=(170, 160, 140) if muted else self.INK)

    def button(self, im, d, r, text, primary=False):
        x, y, w, h = r
        if primary:
            shadow(im, r, 16, off=4, blur=6)
            g = Image.new("RGBA", (w, h))
            for i in range(h):
                t = i / max(1, h - 1)
                c = tuple(int(a + (b - a) * t) for a, b in zip((176, 116, 40), (112, 70, 18)))
                ImageDraw.Draw(g).line([0, i, w, i], fill=c + (255,))
            m = Image.new("L", (w, h))
            ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], 16, fill=255)
            im.paste(g, (x, y), m)
            rounded(d, r, 16, outline=(246, 226, 176), width=3)
            d.text((x + w / 2, y + h / 2), text.upper(), font=font(F_COPPER, min(24, int(h * 0.42))),
                   fill=(252, 240, 210), anchor="mm", stroke_width=2, stroke_fill=(60, 36, 8))
        else:
            rounded(d, r, 10, fill=(32, 38, 50), outline=(120, 110, 90), width=2)
            d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 17), fill=self.INK, anchor="mm")

    def field(self, im, d, r, label, value):
        x, y, w, h = r
        self.text(d, (x, y - 24), label.upper(), 14, muted=True)
        rounded(d, r, 10, fill=(10, 12, 18), outline=(90, 84, 70), width=2)
        self.text(d, (x + 14, y + h / 2), value, 19, anchor="lm")

    def tab(self, im, d, r, text, on):
        x, y, w, h = r
        if on:
            rounded(d, r, 12, fill=(150, 100, 34), outline=(246, 226, 176), width=2)
        else:
            rounded(d, r, 12, fill=(30, 34, 44), outline=(90, 84, 70), width=1)
        d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 16), anchor="mm",
               fill=(252, 240, 210) if on else (190, 180, 160))

    def row(self, im, d, r, cells, xs, me=False, head=False):
        x, y, w, h = r
        if head:
            d.line([x, y + h, x + w, y + h], fill=self.GOLD, width=2)
        elif me:
            rounded(d, r, 8, fill=(40, 70, 130), outline=(120, 170, 255), width=2)
        for i, c in enumerate(cells):
            d.text((x + xs[i], y + h / 2), c.upper() if head else c,
                   font=font(F_COPPER if head else F_BODY, 15 if head else 18),
                   anchor="lm", fill=(240, 205, 120) if head else self.INK)

    def card(self, im, d, r, cid, selected=False):
        x, y, w, h = r
        shadow(im, r, 10, off=3, blur=5)
        rounded(d, r, 10, fill=(14, 16, 22),
                outline=(120, 170, 255) if selected else self.GOLD, width=4 if selected else 2)
        paste_fit(im, load(CARD_ART % cid), (x + 6, y + 6, w - 12, h - 34))
        d.text((x + w / 2, y + h - 15), NAMES.get(cid, str(cid))[:16], font=font(F_BODY, 12),
               anchor="mm", fill=self.INK)


# --- B: 1-bit (S04) ------------------------------------------------------------
class OneBit(Style):
    name = "B"

    def background(self):
        g = self.fight.resize((W, H), Image.LANCZOS).filter(
            ImageFilter.GaussianBlur(6)).convert("L").point(lambda v: int(v * 0.55))
        return bayer(g).convert("RGBA")

    def panel(self, im, d, r):
        x, y, w, h = r
        d.rectangle([x + 8, y + 8, x + w + 8, y + h + 8], fill=(255, 255, 255))
        d.rectangle([x, y, x + w, y + h], fill=(0, 0, 0), outline=(255, 255, 255), width=3)

    def title(self, d, xy, text, size=34, anchor="la"):
        d.text(xy, text.upper(), font=font(F_COPPER, size), fill=(255, 255, 255), anchor=anchor)

    def text(self, d, xy, text, size=18, anchor="la", muted=False):
        d.text(xy, text, font=font(F_BODY, size), anchor=anchor,
               fill=(150, 150, 150) if muted else (255, 255, 255))

    def button(self, im, d, r, text, primary=False):
        x, y, w, h = r
        if primary:
            d.rectangle([x + 5, y + 5, x + w + 5, y + h + 5], fill=(255, 255, 255))
            d.rectangle([x, y, x + w, y + h], fill=(0, 0, 0), outline=(255, 255, 255), width=3)
            d.rectangle([x + 6, y + 6, x + w - 6, y + h - 6], fill=(255, 255, 255))
            d.text((x + w / 2, y + h / 2), text.upper(), font=font(F_COPPER, min(24, int(h * 0.42))),
                   fill=(0, 0, 0), anchor="mm")
        else:
            d.rectangle([x, y, x + w, y + h], fill=(0, 0, 0), outline=(255, 255, 255), width=2)
            d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 17), fill=(255, 255, 255), anchor="mm")

    def field(self, im, d, r, label, value):
        x, y, w, h = r
        self.text(d, (x, y - 24), label.upper(), 14, muted=True)
        d.rectangle([x, y, x + w, y + h], fill=(0, 0, 0), outline=(255, 255, 255), width=2)
        self.text(d, (x + 14, y + h / 2), value + "_", 19, anchor="lm")

    def tab(self, im, d, r, text, on):
        x, y, w, h = r
        d.rectangle([x, y, x + w, y + h], fill=(255, 255, 255) if on else (0, 0, 0),
                    outline=(255, 255, 255), width=2)
        d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 16), anchor="mm",
               fill=(0, 0, 0) if on else (255, 255, 255))

    def row(self, im, d, r, cells, xs, me=False, head=False):
        x, y, w, h = r
        if head:
            d.line([x, y + h, x + w, y + h], fill=(255, 255, 255), width=2)
        elif me:
            d.rectangle([x, y, x + w, y + h], fill=(255, 255, 255))
        for i, c in enumerate(cells):
            d.text((x + xs[i], y + h / 2), c.upper() if head else c,
                   font=font(F_COPPER if head else F_BODY, 15 if head else 18),
                   anchor="lm", fill=(0, 0, 0) if me and not head else (255, 255, 255))
        # the player's own team colour, the only colour on screen (as in S04)
        if me:
            d.rectangle([x, y, x + 8, y + h], fill=(60, 120, 255))

    def card(self, im, d, r, cid, selected=False):
        x, y, w, h = r
        if selected:
            d.rectangle([x + 6, y + 6, x + w + 6, y + h + 6], fill=(255, 255, 255))
        d.rectangle([x, y, x + w, y + h], fill=(0, 0, 0), outline=(255, 255, 255),
                    width=4 if selected else 2)
        a = load(CARD_ART % cid)
        flat = Image.new("RGBA", a.size, (255, 255, 255, 255))
        flat.alpha_composite(a)
        paste_fit(im, bayer(flat), (x + 6, y + 6, w - 12, h - 34))
        d.text((x + w / 2, y + h - 15), NAMES.get(cid, str(cid))[:16], font=font(F_BODY, 12),
               anchor="mm", fill=(255, 255, 255))


# --- C: card table (felt and paper) ---------------------------------------------
class Table(Style):
    name = "C"
    PAPER = (240, 230, 206)
    INK = (48, 36, 26)
    ORANGE = (234, 122, 36)

    def background(self):
        rng = np.random.default_rng(7)
        n = rng.normal(0, 9, (H, W))
        yy, xx = np.mgrid[0:H, 0:W]
        v = 1 - 0.55 * (((xx - W / 2) / (W / 1.2)) ** 2 + ((yy - H / 2) / (H / 1.1)) ** 2)
        base = np.stack([22 + n, 74 + n, 52 + n], -1) * v[..., None]
        return Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")

    def panel(self, im, d, r):
        shadow(im, r, 20, off=10, blur=14, alpha=170)
        x, y, w, h = r
        rounded(d, r, 20, fill=self.PAPER, outline=(200, 184, 150), width=2)
        rounded(d, (x + 10, y + 10, w - 20, h - 20), 14, outline=(214, 198, 166), width=1)

    def title(self, d, xy, text, size=34, anchor="la"):
        d.text(xy, text.upper(), font=font(F_COPPER, size), fill=(132, 44, 30), anchor=anchor)

    def text(self, d, xy, text, size=18, anchor="la", muted=False):
        d.text(xy, text, font=font(F_BODY, size), anchor=anchor,
               fill=(130, 112, 90) if muted else self.INK)

    def button(self, im, d, r, text, primary=False):
        x, y, w, h = r
        if primary:
            shadow(im, r, h // 2, off=5, blur=4, alpha=120)
            rounded(d, r, h // 2, fill=self.ORANGE, outline=(150, 66, 14), width=3)
            d.text((x + w / 2, y + h / 2), text.upper(), font=font(F_COPPER, min(24, int(h * 0.42))),
                   fill=(255, 250, 236), anchor="mm", stroke_width=2, stroke_fill=(150, 66, 14))
        else:
            rounded(d, r, h // 2, fill=(226, 212, 182), outline=(170, 150, 116), width=2)
            d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 17), fill=self.INK, anchor="mm")

    def field(self, im, d, r, label, value):
        x, y, w, h = r
        self.text(d, (x, y - 24), label.upper(), 14, muted=True)
        rounded(d, r, 10, fill=(252, 247, 236), outline=(190, 170, 136), width=2)
        self.text(d, (x + 14, y + h / 2), value, 19, anchor="lm")

    def tab(self, im, d, r, text, on):
        x, y, w, h = r
        rounded(d, r, 12, fill=(132, 44, 30) if on else (226, 212, 182),
                outline=(150, 66, 14) if on else (190, 170, 136), width=2)
        d.text((x + w / 2, y + h / 2), text, font=font(F_BODY, 16), anchor="mm",
               fill=(255, 246, 228) if on else self.INK)

    def row(self, im, d, r, cells, xs, me=False, head=False):
        x, y, w, h = r
        if head:
            d.line([x, y + h, x + w, y + h], fill=(132, 44, 30), width=2)
        elif me:
            rounded(d, r, 8, fill=(250, 214, 168), outline=self.ORANGE, width=2)
        for i, c in enumerate(cells):
            d.text((x + xs[i], y + h / 2), c.upper() if head else c,
                   font=font(F_COPPER if head else F_BODY, 15 if head else 18),
                   anchor="lm", fill=(132, 44, 30) if head else self.INK)

    def card(self, im, d, r, cid, selected=False):
        x, y, w, h = r
        shadow(im, r, 10, off=5 if selected else 3, blur=6)
        rounded(d, r, 10, fill=(255, 252, 244),
                outline=self.ORANGE if selected else (190, 170, 136), width=4 if selected else 2)
        paste_fit(im, load(CARD_ART % cid), (x + 6, y + 6, w - 12, h - 34))
        d.text((x + w / 2, y + h - 15), NAMES.get(cid, str(cid))[:16], font=font(F_BODY, 12),
               anchor="mm", fill=self.INK)


# --- screens ------------------------------------------------------------------
def login(st: Style) -> Image.Image:
    im = st.background()
    d = ImageDraw.Draw(im)
    st.title(d, (W / 2, 150), "Arena", 96, anchor="mm")
    st.text(d, (W / 2, 214), "Ligas PvE y PvP", 20, anchor="mm", muted=True)
    r = (440, 262, 400, 330)
    st.panel(im, d, r)
    d = ImageDraw.Draw(im)
    st.field(im, d, (480, 316, 320, 46), "Cuenta", "arel")
    st.field(im, d, (480, 406, 320, 46), "Contraseña", "••••••••")
    st.field(im, d, (480, 496, 320, 46), "Servidor", "Local (127.0.0.1)")
    st.button(im, d, (520, 620, 240, 64), "Conectar", primary=True)
    st.button(im, d, (1100, 30, 150, 40), "Español")
    st.text(d, (30, 690), "versión 2.70 - Godot", 14, muted=True)
    return im


def ranking(st: Style) -> Image.Image:
    im = st.background()
    d = ImageDraw.Draw(im)
    r = (90, 60, 1100, 600)
    st.panel(im, d, r)
    d = ImageDraw.Draw(im)
    st.title(d, (130, 92), "Clasificación", 34)
    st.button(im, d, (1040, 86, 110, 40), "Cerrar")
    x = 130
    for i, t in enumerate(TABS):
        w = 120
        st.tab(im, d, (x, 150, w, 40), t, i == 0)
        x += w + 10
    xs = [20, 140, 640, 840]
    st.row(im, d, (130, 210, 1020, 34), ["Puesto", "Jugador", "Victorias", "Derrotas"], xs, head=True)
    y = 252
    for row in LADDER:
        st.row(im, d, (130, y, 1020, 40), list(row), xs, me=row[1] == ME)
        y += 44
    for i, t in enumerate(["« Primero", "‹ Anterior", "Mi puesto", "Siguiente ›"]):
        st.button(im, d, (130 + i * 170, 612, 160, 40), t, primary=(t == "Mi puesto"))
    st.text(d, (1150, 632), "datos de ejemplo", 13, anchor="rm", muted=True)
    return im


def cardmaster(st: Style) -> Image.Image:
    im = st.background()
    d = ImageDraw.Draw(im)
    r = (60, 50, 1160, 620)
    st.panel(im, d, r)
    d = ImageDraw.Draw(im)
    st.title(d, (100, 82), "Card Master - Set Jalatranki", 30)
    st.text(d, (1060, 98), "1.250 fichas", 20, anchor="rm")
    st.button(im, d, (1080, 78, 100, 40), "Cerrar")
    for i, cid in enumerate(SET_CARDS):
        cx, cy = 100 + (i % 4) * 160, 150 + (i // 4) * 240
        st.card(im, d, (cx, cy, 145, 220), cid, selected=(i == 1))
    # detail of the selected card
    sel = SET_CARDS[1]
    st.card(im, d, (800, 150, 220, 320), sel, selected=True)
    st.text(d, (1040, 160), NAMES.get(sel, "")[:14], 20)
    st.text(d, (1040, 196), "Valor 120", 17, muted=True)
    st.text(d, (1040, 224), "Precio 300 fichas", 17, muted=True)
    st.text(d, (1040, 252), "Tienes 0", 17, muted=True)
    st.button(im, d, (800, 500, 180, 58), "Comprar", primary=True)
    st.button(im, d, (1000, 506, 180, 46), "Trueque…")
    st.text(d, (100, 650), "Arrastra cartas tuyas para el trueque", 15, muted=True)
    return im


def main(argv):
    if not argv:
        print(__doc__, file=sys.stderr)
        return 2
    out = argv[0]
    opts = dict(a[2:].split("=", 1) for a in argv[1:] if a.startswith("--"))
    fight = Image.open(opts.get("fight", "/tmp/fight-ui.png")).convert("RGB")
    fight1 = Image.open(opts.get("fight1bit", "/tmp/fight-ui-onebit.png")).convert("RGB")
    os.makedirs(out, exist_ok=True)
    for cls in (Arena, OneBit, Table):
        st = cls(fight, fight1)
        for scr in (login, ranking, cardmaster):
            p = os.path.join(out, "%s-%s.png" % (st.name, scr.__name__))
            scr(st).convert("RGB").save(p)
            print("wrote", p)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
