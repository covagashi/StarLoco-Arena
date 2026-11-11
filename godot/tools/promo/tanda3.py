"""S35b-marketing, tanda 3 (how the skeletons were made): composes the
reels (1080x1920, 30 fps, no music) and carousels (1080x1350) from the
renders of tanda3_render.sh. Same type and colours as tanda 2: Lato, gold
tag, ink title, top text clear of the app buttons.

    python3 -I tools/promo/tanda3.py [post …]     (30 … 38; none = all)

RAW (renders) = $T3_RAW or ~/codigo/marketing/_fuentes/raw3
OUT (posts)   = $T3_OUT or ~/codigo/marketing/tanda-3
"""
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

RAW = os.environ.get("T3_RAW", os.path.expanduser("~/codigo/marketing/_fuentes/raw3")) + "/"
OUT = os.environ.get("T3_OUT", os.path.expanduser("~/codigo/marketing/tanda-3")) + "/"
BOLD = "/usr/share/fonts/lato-fonts/Lato-Black.ttf"
REG = "/usr/share/fonts/lato-fonts/Lato-Bold.ttf"
MONO = "/usr/share/fonts/adobe-source-code-pro-fonts/SourceCodePro-Regular.otf"
GOLD, INK, GREY, BG = (242, 193, 78), (244, 240, 232), (150, 160, 175), (29, 28, 25)
CYAN = (120, 220, 255)
TAG = "PIPPOP ARENA  ·  DEVLOG"
FPS = 30
_fonts = {}


def F(p, s):
    if (p, s) not in _fonts:
        _fonts[(p, s)] = ImageFont.truetype(p, s)
    return _fonts[(p, s)]


# ---------------------------------------------------------------- type

def shade(im, h):  # soft dark band behind the top text
    band = Image.new("RGBA", (im.width, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(band)
    for y in range(h):
        d.line((0, y, im.width, y), fill=(15, 15, 13, int(170 * (1 - y / h) ** 1.4)))
    im.alpha_composite(band)


def text_card(title, sub="", gold="", w=1080, h=1920, top=150, size=96, dots=None, band=True, alpha=1.0):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if band:
        shade(im, top + 420)
    d = ImageDraw.Draw(im)
    d.text((70, top - 50), TAG, font=F(REG, 32), fill=GOLD)
    y = top
    for line in title.split("\n"):
        d.text((70, y), line, font=F(BOLD, size), fill=INK)
        y += int(size * 1.12)
    if gold:
        for line in gold.split("\n"):
            d.text((70, y), line, font=F(BOLD, size), fill=GOLD)
            y += int(size * 1.12)
    if sub:
        for line in sub.split("\n"):
            d.text((72, y + 6), line, font=F(REG, 50 if h > 1500 else 44), fill=GREY)
            y += 64
    if dots:
        i, n = dots
        for k in range(n):
            c = GOLD if k <= i else (70, 68, 62)
            d.ellipse((82 + k * 34 - 11, y + 40 - 11, 82 + k * 34 + 11, y + 40 + 11), fill=c)
    if alpha < 1:
        im.putalpha(im.getchannel("A").point(lambda a: int(a * alpha)))
    return im


def end_card(big, small, w=1080, h=1920):
    im = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(im)
    c = h // 2 - 260
    for y, t, f, col in [(c, big, F(BOLD, 110), INK), (c + 140, small, F(REG, 56), GREY),
                         (c + 380, "PIPPOP ARENA", F(BOLD, 64), GOLD), (c + 470, "follow the devlog", F(REG, 44), GREY)]:
        d.text(((w - d.textlength(t, font=f)) / 2, y), t, font=f, fill=col)
    return im


def backdrop(w=1080, h=1920):
    """BG with a soft lighter disc behind the figure."""
    im = Image.new("RGB", (w, h), BG)
    glow = Image.new("L", (w, h), 0)
    ImageDraw.Draw(glow).ellipse((w * 0.1, h * 0.38, w * 0.9, h * 0.98), fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(w * 0.12))
    lift = Image.new("RGB", (w, h), (64, 60, 52))
    return Image.composite(lift, im, glow).convert("RGBA")


def floor_ring(im, cx, cy, rx, alpha=1.0):
    d = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(d).ellipse((cx - rx, cy - rx * 0.22, cx + rx, cy + rx * 0.22), fill=(0, 0, 0, int(90 * alpha)))
    im.alpha_composite(d.filter(ImageFilter.GaussianBlur(14)))


# ---------------------------------------------------------------- layers

def layer(path):
    return Image.open(path).convert("RGBA")


def fade(im, a):
    if a >= 1:
        return im
    im = im.copy()
    im.putalpha(im.getchannel("A").point(lambda v: int(v * max(0.0, a))))
    return im


def wipe_up(im, t, h, soft=120):
    """Reveal im from the feet up: t=0 nothing, t=1 all (y from h*0.95 to h*0.25)."""
    y = h * 0.95 - t * (h * 0.95 - h * 0.25 + soft)
    m = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(m)
    for k in range(soft):
        d.line((0, y + k, im.width, y + k), fill=int(255 * k / soft))
    if y + soft < im.height:
        d.rectangle((0, y + soft, im.width, im.height), fill=255)
    out = im.copy()
    out.putalpha(ImageChops.multiply(im.getchannel("A"), m))
    return out, y + soft / 2


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- skeleton

ORDER = ["hips", "spine", "chest", "neck", "head", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R",
         "shoulder.L", "shoulder.R", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"]
LEAF = {"head", "hand.L", "hand.R", "foot.L", "foot.R"}


def segments(J, bones=None):
    """(bone, a, b): parent head → head, and head → tail for the leaves."""
    out = []
    for n in bones or (ORDER if "spine" in J else [n for n in J if n not in ("root", "body")] or ["body"]):
        if n not in J:
            continue
        b = J[n]
        p = b["parent"]
        if p and p in J and p != "root" and n != "body":
            out.append((n, J[p]["head"][:2], b["head"][:2]))
        if n in LEAF or not any(J[c]["parent"] == n for c in J):
            h, t = b["head"][:2], b["tail"][:2]
            if n.startswith("hand") and not b.get("exact"):  # glTF keeps no tails: the importer's runs past the fingers
                t = [h[0] + (t[0] - h[0]) * 0.65, h[1] + (t[1] - h[1]) * 0.65]
            out.append((n, h, t))
    return out


def draw_bones(size, J, shown=None, grow=None, col=GOLD, width=7, joint=11, alpha=1.0):
    """The skeleton as glowing gold sticks. shown: bones drawn; grow: the
    bone being drawn and how far (0–1)."""
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    pts = []
    for n, a, b in segments(J):
        if shown is not None and n not in shown and not (grow and grow[0] == n):
            continue
        if grow and grow[0] == n:
            b = (a[0] + (b[0] - a[0]) * grow[1], a[1] + (b[1] - a[1]) * grow[1])
        d.line((a[0], a[1], b[0], b[1]), fill=col + (255,), width=width)
        pts += [a, b]
    for x, y in pts:
        d.ellipse((x - joint, y - joint, x + joint, y + joint), fill=(255, 246, 220, 255), outline=col + (255,), width=3)
    glow = lay.filter(ImageFilter.GaussianBlur(10))
    out = Image.new("RGBA", size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(glow)
    out.alpha_composite(lay)
    return fade(out, alpha)


def joints(path):
    return json.load(open(path))["frames"]


# ---------------------------------------------------------------- video

class Reel:
    """Frames written as PNG, then one H.264 MP4."""

    def __init__(self, out, w=1080, h=1920):
        self.out, self.w, self.h = out, w, h
        self.dir = tempfile.mkdtemp(prefix="t3reel")
        self.n = 0

    def add(self, im, times=1):
        im = im.convert("RGB")
        for _ in range(times):
            im.save(os.path.join(self.dir, f"{self.n:05d}.png"), compress_level=1)
            self.n += 1

    def hold(self, im, sec):
        self.add(im, int(round(sec * FPS)))

    def done(self):
        os.makedirs(os.path.dirname(self.out), exist_ok=True)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", str(FPS),
                        "-i", os.path.join(self.dir, "%05d.png"), "-vf", "format=yuv420p",
                        "-c:v", "libx264", "-crf", "20", "-preset", "slow", "-movflags", "+faststart", self.out],
                       check=True)
        shutil.rmtree(self.dir)
        print("reel", self.out, f"{self.n / FPS:.1f}s")


def caption(folder, text):
    os.makedirs(OUT + folder, exist_ok=True)
    open(OUT + folder + "/texto.txt", "w").write(text.strip() + "\n")


TAGS = "#gamedev #indiedev #indiegame #godotengine #madewithgodot #blender #3dart #devlog #solodev #tacticsgame"


# ---------------------------------------------------------------- 30

def post30():
    """From statue to fighter: clay turn → x-ray, bones one by one → weights
    → paint from the feet up → it walks."""
    R = RAW + "r30"
    J0 = joints(R + "b/joints.json")[0]
    walkJ = joints(R + "c/joints.json")
    reel = Reel(OUT + "30-reel-de-estatua-a-luchador/reel-statue-to-fighter.mp4")
    bg = backdrop()
    grey0 = layer(R + "b/grey/0000.png")
    ghost = layer(R + "b/ghost/0000.png")
    weights = layer(R + "b/weights/0000.png")
    tex = layer(R + "b/tex/0000.png")
    hook = text_card("From statue", "", "to fighter")
    # 1 clay turn (2.5 s)
    for k in range(75):
        f = bg.copy()
        f.alpha_composite(layer(R + f"a/grey/{k:04d}.png"))
        f.alpha_composite(hook)
        reel.add(f)
    # 2 x-ray and the bones, one by one (3.4 s)
    t2 = text_card("Step 1", "the skeleton, found on the mesh", "20 bones")
    per = 4
    for k in range(15 + len(ORDER) * per + 12):
        f = bg.copy()
        a = ease(k / 15)
        f.alpha_composite(fade(grey0, 1 - a))
        f.alpha_composite(fade(ghost, a))
        i = (k - 15) // per
        shown = set(ORDER[:max(0, i)])
        grow = (ORDER[i], ((k - 15) % per + 1) / per) if 0 <= i < len(ORDER) else None
        f.alpha_composite(draw_bones(f.size, J0, shown, grow))
        f.alpha_composite(t2)
        reel.add(f)
    # 3 weights (2 s)
    t3 = text_card("Step 2", "every point of the skin\npicks the bones it follows", "weights")
    for k in range(60):
        f = bg.copy()
        a = ease(k / 15)
        f.alpha_composite(fade(ghost, 1 - a))
        f.alpha_composite(fade(weights, a))
        f.alpha_composite(draw_bones(f.size, J0, alpha=1 - 0.6 * a))
        f.alpha_composite(t3)
        reel.add(f)
    # 4 the paint, from the feet up (1.5 s)
    t4 = text_card("Step 3", "the texture goes back on", "paint")
    for k in range(45):
        f = bg.copy()
        f.alpha_composite(weights)
        top, y = wipe_up(tex, ease(k / 36), f.height)
        f.alpha_composite(top)
        f.alpha_composite(draw_bones(f.size, J0, alpha=0.4 * (1 - ease(k / 36))))
        ImageDraw.Draw(f).line((140, y, 940, y), fill=GOLD + (255,), width=3) if k < 36 else None
        f.alpha_composite(t4)
        reel.add(f)
    # 5 it walks (3.2 s); the bones fade in again over it for a moment
    t5 = text_card("Step 4", "10 animations on one skeleton", "it walks")
    for k in range(96):
        f = bg.copy()
        f.alpha_composite(layer(R + f"c/tex/{k:04d}.png"))
        a = ease((k - 40) / 12) * (1 - ease((k - 70) / 12))
        if a > 0:
            f.alpha_composite(fade(layer(R + f"c/ghost/{k:04d}.png"), 0.6 * a))
            f.alpha_composite(draw_bones(f.size, walkJ[k], alpha=a))
        f.alpha_composite(t5)
        reel.add(f)
    reel.hold(end_card("One figure,", "one skeleton, ten moves"), 1.6)
    reel.done()
    caption("30-reel-de-estatua-a-luchador", f"""
From statue to fighter. The figures arrive as a frozen sculpture: no bones, no joints, nothing that moves. A script finds where the skeleton goes, tells every point of the skin which bones to follow, puts the paint back on, and then it walks.

{TAGS} #rigging #characterart #3danimation""")


# ---------------------------------------------------------------- 31

COUNT_RGB = [(1, (158, 107, 255)), (2, (38, 217, 191)), (3, (255, 153, 31)), (4, (255, 64, 77))]


def seg_bones(size, bones, alpha=1.0, width=6, joint=9):
    J = {}
    for n, h, t in bones:  # promo_slices: [name, head, tail]
        J[n] = {"head": h, "tail": t, "parent": None, "exact": True}
    par = {"spine": "hips", "chest": "spine", "neck": "chest", "head": "neck"}
    for S in "LR":
        par.update({f"shoulder.{S}": "chest", f"upper_arm.{S}": f"shoulder.{S}", f"forearm.{S}": f"upper_arm.{S}",
                    f"hand.{S}": f"forearm.{S}", f"thigh.{S}": "hips", f"shin.{S}": f"thigh.{S}", f"foot.{S}": f"shin.{S}"})
    for n, p in par.items():
        if n in J:
            J[n]["parent"] = p
    return draw_bones(size, J, width=width, joint=joint, alpha=alpha)


def legend(im, y):
    d = ImageDraw.Draw(im)
    x = 72
    for n, col in COUNT_RGB:
        label = f"{n} piece" + ("s" if n > 1 else "") if n < 4 else "4 +"
        d.rounded_rectangle((x, y, x + 34, y + 34), 8, fill=col)
        d.text((x + 46, y - 2), label, font=F(REG, 34), fill=INK)
        x += 70 + d.textlength(label, font=F(REG, 34)) + 20


def post31():
    """How the bones find themselves: the slices, the count, the joints."""
    folder = "31-carrusel-como-se-encuentran-los-huesos"
    D = RAW + "s31/feca_f/"
    info = json.load(open(D + "info.json"))
    out = OUT + folder + "/"
    os.makedirs(out, exist_ok=True)
    size = (1080, 1350)
    bg = lambda: backdrop(*size)
    th = layer(D + "three_solid.png"), layer(D + "three_rings.png"), layer(D + "three_mesh.png")
    fr = layer(D + "front_solid.png"), layer(D + "front_rings.png"), layer(D + "front_mesh.png")
    # 1 cover: clay on the left, the slices on the right
    f = bg()
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon([(0, 0), (560, 0), (500, 1350), (0, 1350)], fill=255)
    f.alpha_composite(Image.composite(th[0], Image.new("RGBA", size, (0, 0, 0, 0)), m))
    inv = ImageChops.invert(m)
    f.alpha_composite(Image.composite(th[2], Image.new("RGBA", size, (0, 0, 0, 0)), inv))
    f.alpha_composite(Image.composite(th[1], Image.new("RGBA", size, (0, 0, 0, 0)), inv))
    f.alpha_composite(text_card("How the bones", "swipe  →", "find themselves", w=1080, h=1350, top=110, size=84))
    f.convert("RGB").save(out + "huesos-01.png")
    # 2 slice it, count the pieces
    f = bg()
    f.alpha_composite(fr[2])
    f.alpha_composite(fr[1])
    f.alpha_composite(text_card("Slice it", "every 2.5 cm, then count\nthe pieces in each slice", "57 times", w=1080, h=1350, top=110, size=76))
    legend(f, 1270)
    f.convert("RGB").save(out + "huesos-02.png")
    # 3 where the count changes there is a joint
    f = bg()
    f.alpha_composite(fr[2])
    f.alpha_composite(fade(fr[1], 0.45))
    d = ImageDraw.Draw(f)
    names = {"ankle": "ankle", "crotch": "hips", "armpit": "armpit", "neck": "neck"}
    for k, (a, b) in info["views"]["front"]["marks"].items():
        if k not in names:
            continue
        y = (a[1] + b[1]) / 2
        x0, x1 = 300, 760
        for x in range(int(x0), int(x1), 22):
            d.line((x, y, x + 12, y), fill=GOLD + (255,), width=4)
        d.text((x1 + 16, y - 22), names[k], font=F(BOLD, 38), fill=GOLD)
    f.alpha_composite(text_card("Where the count", "legs merge, arms split off:\nthe slices say where", "changes, a joint", w=1080, h=1350, top=110, size=76))
    f.convert("RGB").save(out + "huesos-03.png")
    # 4 the skeleton on top
    f = bg()
    f.alpha_composite(fr[2])
    f.alpha_composite(fade(fr[1], 0.25))
    f.alpha_composite(seg_bones(size, info["views"]["front"]["bones"]))
    f.alpha_composite(text_card("Then the bones", "placed by the script,\nnot by hand", "fall into place", w=1080, h=1350, top=110, size=76))
    f.convert("RGB").save(out + "huesos-04.png")
    # 5 same rule, three figures
    f = bg()
    for i, n in enumerate(("osamodas_f", "ocra_m", "zurcarak_m")):
        E = RAW + f"s31/{n}/"
        inf = json.load(open(E + "info.json"))
        p = Image.new("RGBA", size, (0, 0, 0, 0))
        p.alpha_composite(layer(E + "front_mesh.png"))
        p.alpha_composite(fade(layer(E + "front_rings.png"), 0.55))
        p.alpha_composite(seg_bones(size, inf["views"]["front"]["bones"], width=5, joint=7))
        p = p.crop((540 - 230, 120, 540 + 230, 1350)).resize((360, 963))
        f.alpha_composite(p, (i * 360, 1350 - 963))
    f.alpha_composite(text_card("Same rule,", "skirt, cape or tail:\nthe slices still find the legs", "any figure", w=1080, h=1350, top=110, size=76))
    f.convert("RGB").save(out + "huesos-05.png")
    caption(folder, f"""
How do you give a skeleton to a statue? Cut it into 57 slices and count the pieces in each one. Two pieces are legs; where they merge into one, that's the hips. Where one becomes three, the arms split off: armpit. The joints fall where the count changes, and the same rule works on all 24 fighters.

{TAGS} #rigging #proceduralgeneration #python""")
    print("carousel", folder)


# ---------------------------------------------------------------- 32

def side_by_side(a, b, la, lb, cl=INK):
    """Two 1080x1920 figure layers, each cropped to its middle half."""
    f = backdrop()
    for i, im in enumerate((a, b)):
        f.alpha_composite(im.crop((270, 0, 810, 1920)), (i * 540, 0))
    d = ImageDraw.Draw(f)
    for i, t in enumerate((la, lb)):
        d.text((i * 540 + (540 - d.textlength(t, font=F(BOLD, 44))) / 2, 1760), t, font=F(BOLD, 44), fill=cl)
    return f


def post32():
    """Weight painting in 8 seconds: red follows the left arm; the scarf
    painted as an arm flies; fixed."""
    R = RAW + "r32/"
    folder = "32-reel-pesos-en-8-segundos"
    reel = Reel(OUT + folder + "/reel-weights.mp4")
    bg = backdrop()
    hook = text_card("Weight painting", "", "in 8 seconds")
    w0, t0 = layer(R + "feca-rest/weights/0000.png"), layer(R + "feca-rest/tex/0000.png")
    for k in range(60):
        f = bg.copy()
        a = ease((k - 20) / 20)
        f.alpha_composite(fade(t0, 1 - a))
        f.alpha_composite(fade(w0, a))
        f.alpha_composite(hook)
        reel.add(f)
    t = text_card("Red follows", "orange the right one,\ngrey stays where it is", "the left arm")
    for k in range(58):
        f = bg.copy()
        f.alpha_composite(layer(R + f"feca/weights/{k:04d}.png"))
        f.alpha_composite(t)
        reel.add(f)
    for tag, title, gold, sub in (("before", "Paint the scarf red", "and it flies", "it hung by the arm,\nso the script took it for arm"),
                                  ("after", "Fixed:", "only the arm is arm", "the scarf stays with the chest")):
        t = text_card(title, sub, gold)
        for k in range(58):
            f = side_by_side(layer(R + f"scarf-{tag}/weights/{k:04d}.png"), layer(R + f"scarf-{tag}/tex/{k:04d}.png"),
                             "weights", "in game")
            f.alpha_composite(t)
            reel.add(f)
    reel.hold(end_card("All 24 fighters", "checked like this"), 1.6)
    reel.done()
    caption(folder, f"""
Weight painting in 8 seconds: every point of the skin says which bones it follows. Red rides the left arm, orange the right one. Paint a scarf red by mistake and it flies off with the arm. The script now checks what really belongs to the arm, on all 24 fighters.

{TAGS} #rigging #weightpainting #3danimation""")


# ---------------------------------------------------------------- 33

BUGS = [
    ("yopuka_f", "The sword stayed behind", "a loose piece now rides\nthe hand that holds it"),
    ("sram_f", "Floating thumbs", "the thumb was its own piece,\nleft by the hip"),
    ("aniripsa_m", "Wings for shoulders", "the shoulders landed\non the spines of his back"),
    ("aniripsa_f", "Shoulders in the chest", "long hair hid them (x-ray);\nnow they sit under the neck"),
    ("sacrogrito_m", "The scarf became an arm", "it hung by the arm,\nso it lifted with it"),
]
XRAY = {"aniripsa_f"}  # shown as the x-ray with its bones


def bug_cover(out):
    f = backdrop(1080, 1350)
    f.alpha_composite(layer(RAW + "r33/cover/tex/0000.png"))
    d = ImageDraw.Draw(f)
    d.rounded_rectangle((70, 1210, 330, 1290), 14, outline=(255, 95, 90), width=5)
    d.text((200 - d.textlength("BEFORE", font=F(BOLD, 46)) / 2, 1222), "BEFORE", font=F(BOLD, 46), fill=(255, 95, 90))
    f.alpha_composite(text_card("Bugs we hit", "5 of them, before and after  →", "(and fixed)", w=1080, h=1350, top=110, size=84))
    f.convert("RGB").save(out)


def pair_slide(n, title, sub, out):
    size = (1080, 1350)
    f = backdrop(*size)
    d = ImageDraw.Draw(f)
    for i, v in enumerate(("before", "after")):
        if n in XRAY:
            im = layer(RAW + f"r33/{n}-{v}/ghost/0000.png")
            im.alpha_composite(draw_bones(im.size, joints(RAW + f"r33/{n}-{v}/joints.json")[0], width=5, joint=8))
        else:
            im = layer(RAW + f"r33/{n}-{v}/tex/0000.png")
        f.alpha_composite(im, (i * 540, 390))
        t = v.upper()
        col = (255, 95, 90) if v == "before" else GOLD
        d.text((i * 540 + (540 - d.textlength(t, font=F(BOLD, 40))) / 2, 1290), t, font=F(BOLD, 40), fill=col)
    d.line((540, 420, 540, 1270), fill=(70, 68, 62), width=3)
    f.alpha_composite(text_card(title, sub, w=1080, h=1350, top=110, size=72))
    f.convert("RGB").save(out)


def post33():
    folder = "33-carrusel-bugs"
    out = OUT + folder + "/"
    os.makedirs(out, exist_ok=True)
    for old in os.listdir(out):
        if old.endswith(".png"):
            os.remove(out + old)
    bug_cover(out + "bugs-00-cover.png")
    for i, (n, t, sub) in enumerate(BUGS):
        pair_slide(n, t, sub, out + f"bugs-{i + 1:02d}.png")
    caption(folder, f"""
Bugs we hit while giving 24 fighters a skeleton (and fixed). A sword left lying on the floor, thumbs floating by the hips, a scarf that thought it was an arm, shoulders on a pair of wings. Each one became a rule in the script, and every fighter was rebuilt and checked again.

{TAGS} #rigging #bugs #gamedevlife""")
    print("carousel", folder)


# ---------------------------------------------------------------- 34

FIGHTERS = ["feca_f", "feca_m", "osamodas_f", "osamodas_m", "anutrof_f", "anutrof_m", "sram_f", "sram_m",
            "xelor_f", "xelor_m", "zurcarak_f", "zurcarak_m", "aniripsa_f", "aniripsa_m", "yopuka_f", "yopuka_m",
            "ocra_f", "ocra_m", "sadida_f", "sadida_m", "sacrogrito_f", "sacrogrito_m", "pandawa_f", "pandawa_m"]


def grid_frame(anim, k, top=400, ch=250):
    g = Image.new("RGBA", (1080, 1920), BG + (255,))
    for i, n in enumerate(FIGHTERS):
        idx = json.load(open(RAW + f"r34/{n}/index.json"))["index"][anim]["frames"]
        im = Image.open(RAW + f"r34/{n}/{anim}/S_{k % idx:02d}.png").convert("RGBA")
        im = im.crop((0, 30, 270, 30 + ch))
        g.alpha_composite(im, ((i % 4) * 270, top + (i // 4) * ch))
    return g


def zoom(im, z, cx, cy):
    """Scale im by z around (cx, cy), keeping that point where it is."""
    if z <= 1.001:
        return im
    w, h = im.size
    cw, chh = w / z, h / z
    x0 = min(max(cx - cw * cx / w, 0), w - cw)
    y0 = min(max(cy - chh * cy / h, 0), h - chh)
    return im.crop((int(x0), int(y0), int(x0 + cw), int(y0 + chh))).resize((w, h), Image.LANCZOS)


def post34():
    folder = "34-reel-24-luchadores-un-esqueleto"
    reel = Reel(OUT + folder + "/reel-24-fighters.mp4")
    t1 = text_card("24 fighters", "", "one skeleton", band=False)
    t2 = text_card("Same 20 bones,", "", "same 10 moves")
    for k in range(76):
        f = grid_frame("celebrate", k)
        f.alpha_composite(t1)
        reel.add(f)
    # melee twice while the camera closes in on one fighter (Yopuka f),
    # then her close-up, rendered big
    cx, cy = 2 * 270 + 135, 400 + 3 * 250 + 125
    for k in range(52):
        f = grid_frame("melee", k)
        z = 1 + 1.2 * ease((k - 14) / 38)
        f = zoom(f, z, cx, cy)
        f.alpha_composite(fade(t2, 1 - ease((k - 30) / 15)))
        reel.add(f)
    last = f
    t3 = text_card("Up close", "", "same melee", band=False)
    n = json.load(open(RAW + "r34/_close/index.json"))["index"]["melee"]["frames"]
    for k in range(n * 3):
        c = Image.new("RGBA", (1080, 1920), BG + (255,))
        c.alpha_composite(Image.open(RAW + f"r34/_close/melee/S_{(k + 52) % n:02d}.png").convert("RGBA"), (0, 520))
        if k < 10:
            c = Image.blend(last.convert("RGBA"), c, ease(k / 10))
        c.alpha_composite(t3)
        reel.add(c)
    reel.hold(end_card("Built once,", "shared by everyone"), 1.6)
    reel.done()
    caption(folder, f"""
24 fighters, one skeleton. Every class, girl and boy, runs on the same 20 bones, so one set of 10 animations works for all of them: celebrate, strike, cast, walk, carry, throw... Write a move once and the whole roster learns it.

{TAGS} #3danimation #characterdesign #animation""")


# ---------------------------------------------------------------- 35

def inset(f, im, box, label):
    """A small picture in a rounded frame, bottom right."""
    x0, y0, x1, y1 = box
    card = Image.new("RGBA", (x1 - x0, y1 - y0), (44, 42, 37, 255))
    pic = im.crop(im.getbbox())
    pic.thumbnail((x1 - x0 - 20, y1 - y0 - 60))
    card.alpha_composite(pic, ((card.width - pic.width) // 2, 10))
    m = Image.new("L", card.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, card.width - 1, card.height - 1), 22, fill=255)
    f.paste(card, (x0, y0), m)
    d = ImageDraw.Draw(f)
    d.rounded_rectangle(box, 22, outline=GOLD, width=3)
    d.text((x0 + (x1 - x0 - d.textlength(label, font=F(BOLD, 32))) / 2, y1 - 48), label, font=F(BOLD, 32), fill=GOLD)


def shrink(im, k):
    return im.resize((int(im.width * k), int(im.height * k)), Image.LANCZOS)


CREATURES = [("8005", "The chick", "7 bones: body, head,\ntwo legs, two feet", "2 legs"),
             ("8006", "The sheep", "front legs hang from the chest,\nback legs from the hips", "4 legs"),
             ("8004", "The pangolin", "its little arms ride the chest;\nthe tail gets two bones", "2 legs + tail")]


def post35():
    folder = "35-carrusel-no-todo-tiene-dos-brazos"
    out = OUT + folder + "/"
    os.makedirs(out, exist_ok=True)
    R = RAW + "r35/"
    size = (1080, 1350)

    def xray(n, k="rest", width=7, joint=11):
        g = layer(R + f"{n}-{k}/ghost/0000.png")
        g.alpha_composite(draw_bones(g.size, joints(R + f"{n}-{k}/joints.json")[0], width=width, joint=joint))
        return g
    # cover: the three in x-ray, side by side
    f = backdrop(*size)
    for i, (n, *_r) in enumerate(CREATURES):
        g = xray(n, width=10, joint=15).crop((140, 250, 940, 1350)).resize((400, 550))
        f.alpha_composite(g, (-30 + i * 330, 700))
    f.alpha_composite(text_card("Not everything", "a chick, a sheep, a pangolin\nand a golem  →", "has two arms", w=1080, h=1350, top=110, size=84))
    f.convert("RGB").save(out + "criaturas-01.png")
    for i, (n, title, sub, tag) in enumerate(CREATURES):
        f = backdrop(*size)
        f.alpha_composite(shrink(xray(n), 0.8), (0, 225))
        inset(f, layer(R + f"{n}-walk/tex/0000.png"), (690, 900, 1040, 1300), "walking")
        f.alpha_composite(text_card(title, sub, tag, w=1080, h=1350, top=110, size=76))
        f.convert("RGB").save(out + f"criaturas-{i + 2:02d}.png")
    f = backdrop(*size)
    f.alpha_composite(shrink(layer(R + "8007-cel/weights/0000.png"), 0.72), (20, 380))
    inset(f, layer(R + "8007-cel/tex/0000.png"), (690, 900, 1040, 1300), "in game")
    f.alpha_composite(text_card("The golem", "loose rocks: each one\nrides one bone, whole", "stays rigid", w=1080, h=1350, top=110, size=76))
    f.convert("RGB").save(out + "criaturas-05.png")
    caption(folder, f"""
Not everything has two arms. The summons needed their own skeletons: a chick on two legs, a sheep whose front legs hang from the chest, a pangolin with a two-bone tail. And the golem is a pile of loose rocks, so each rock follows one bone whole and never bends.

{TAGS} #rigging #creaturedesign #3danimation""")
    print("carousel", folder)


# ---------------------------------------------------------------- 36

def post36():
    """The crystal, from nothing: oval, frame, eight rays, shine, tilt; it
    floats; then the same piece in the game, on its cell."""
    R = RAW + "r36/"
    folder = "36-reel-el-cristal"
    reel = Reel(OUT + folder + "/reel-crystal.mp4")
    steps = json.load(open(R + "build/steps.json"))
    labels = {"oval": ("an oval", 1), "frame": ("a frame", 2), "rays": ("eight rays", 3), "shine": ("a shine", 4),
              "tilt": ("a tilt", 5), "float": ("and it floats", 6)}
    bg = backdrop()
    total = steps[-1][1] + steps[-1][2]
    cur = None
    for k in range(total):
        for n, f0, _ in steps:
            if k >= f0:
                cur = n
        name, i = labels[cur]
        f = bg.copy()
        f.alpha_composite(layer(R + f"build/{k:04d}.png"))
        f.alpha_composite(text_card("The crystal", "no sculpt, just code", name, dots=(i - 1, 6)))
        reel.add(f)
    last = f
    t = text_card("In the game", "a summon with one bone", "on its cell")
    for anim in ("idle_loop", "celebrate"):
        n = json.load(open(R + "game/index.json"))["index"][anim]["frames"]
        for k in range(n):
            c = Image.new("RGBA", (1080, 1920), BG + (255,))
            c.alpha_composite(Image.open(R + f"game/{anim}/S_{k:02d}.png").convert("RGBA"), (0, 560))
            if anim == "idle_loop" and k < 10:
                c = Image.blend(last, c, ease(k / 10))
            c.alpha_composite(t)
            reel.add(c)
    reel.hold(end_card("One summon,", "eight rays, one bone"), 1.6)
    reel.done()
    caption(folder, f"""
Not every piece comes from a sculpt. This crystal is built in a few lines of Blender Python: an oval, a frame, eight rays, a streak of shine, a tilt. One bone makes it float, spin and celebrate like any other summon in the game.

{TAGS} #blender3d #python #proceduralart""")


# ---------------------------------------------------------------- 37

def big_number(n, unit, sub, pic=None, at=300, size=(1080, 1350)):
    f = backdrop(*size)
    if pic is not None:
        f.alpha_composite(fade(pic, 0.9), (at, 0))
    d = ImageDraw.Draw(f)
    d.text((70, 420), n, font=F(BOLD, 190), fill=GOLD)
    d.text((76, 640), unit, font=F(BOLD, 70), fill=INK)
    y = 740
    for line in sub.split("\n"):
        d.text((78, y), line, font=F(REG, 44), fill=GREY)
        y += 60
    f.alpha_composite(text_card("Under the hood", "", w=1080, h=1350, top=110, size=60, band=False))
    return f


def terminal(line, size=(1080, 1350)):
    """The [meshy] line of the build log, one key per row, keys coloured."""
    data = json.loads(line[line.index("{"):])
    data.pop("joints", None)
    f = backdrop(*size)
    d = ImageDraw.Draw(f)
    x0, y0, x1, y1 = 60, 360, 1020, 1290
    d.rounded_rectangle((x0, y0, x1, y1), 24, fill=(14, 14, 12))
    for i, c in enumerate(((255, 95, 90), GOLD, (110, 200, 120))):
        d.ellipse((x0 + 30 + i * 40, y0 + 26, x0 + 52 + i * 40, y0 + 48), fill=c)
    d.text((x0 + 170, y0 + 20), "build fighter_01", font=F(MONO, 28), fill=GREY)
    fm = F(MONO, 28)
    y = y0 + 90
    d.text((x0 + 36, y), "$ blender -b -P meshy_fighter.py …", font=fm, fill=INK)
    y += 52
    d.text((x0 + 36, y), "[meshy] fighter_01.glb", font=fm, fill=GOLD)
    y += 48
    for k, v in data.items():
        txt = f"  {k}: "
        d.text((x0 + 36, y), txt, font=fm, fill=CYAN)
        x = x0 + 36 + d.textlength(txt, font=fm)
        val = json.dumps(v)
        room = int((x1 - 40 - x) / d.textlength("0", font=fm))
        for chunk in [val[i:i + room] for i in range(0, len(val), room)]:
            d.text((x, y), chunk, font=fm, fill=INK)
            y += 38
        if y > y1 - 50:
            break
    f.alpha_composite(text_card("The build log", "every fighter prints its numbers", w=1080, h=1350, top=110, size=72, band=False))
    return f


def post37():
    folder = "37-carrusel-los-numeros"
    out = OUT + folder + "/"
    os.makedirs(out, exist_ok=True)
    line = open(RAW + "r37/meshy_line.txt").read().strip()
    data = json.loads(line[line.index("{"):])
    secs = float(open(RAW + "r37/seconds.txt").read())
    kb, px = data["glb_kb"], data["textures"][0][0]
    # cover: the numbers as tiles
    f = backdrop(1080, 1350)
    d = ImageDraw.Draw(f)
    tiles = [(f"{data['tris']:,}", "triangles"), (str(data["bones"]), "bones"), (str(data["animations"]), "animations"),
             (f"{px}", "px texture"), (f"{kb}", "KB per fighter"), (f"{secs:.0f} s", "to build one")]
    for i, (n, u) in enumerate(tiles):
        x, y = 60 + (i % 2) * 490, 420 + (i // 2) * 300
        d.rounded_rectangle((x, y, x + 470, y + 270), 26, fill=(44, 42, 37))
        d.text((x + 36, y + 30), n, font=F(BOLD, 110), fill=GOLD)
        d.text((x + 40, y + 170), u, font=F(REG, 44), fill=INK)
    f.alpha_composite(text_card("Under the hood", "one fighter, in numbers  →", w=1080, h=1350, top=110, size=84, band=False))
    f.convert("RGB").save(out + "numeros-01.png")
    R30 = RAW + "r30b/"
    grey = layer(R30 + "grey/0000.png").crop((0, 200, 1080, 1550))
    ghost = layer(R30 + "ghost/0000.png")
    ghost.alpha_composite(draw_bones(ghost.size, joints(R30 + "joints.json")[0]))
    ghost = ghost.crop((0, 200, 1080, 1550))
    tex = layer(R30 + "tex/0000.png").crop((0, 200, 1080, 1550))
    big_number(f"{data['tris']:,}", "triangles", f"cut down from {data['source_tris']:,}\nso a phone can draw\na whole fight of them", grey).convert("RGB").save(out + "numeros-02.png")
    big_number(f"{data['bones']}", "bones, 10 moves", "the same skeleton\nfor all 24 fighters", ghost).convert("RGB").save(out + "numeros-03.png")
    big_number(f"{kb} KB", "the whole fighter", f"mesh, {px} px texture,\nskin and all 10 animations", tex, at=430).convert("RGB").save(out + "numeros-04.png")
    terminal(line).convert("RGB").save(out + "numeros-05.png")
    g = grid_frame("celebrate", 12).crop((540, 400, 1080, 1900))
    g = g.resize((int(g.width * 1350 / 1500), 1350))
    big_number(f"{secs:.1f} s", "to rebuild one", "change a rule in the script,\nrebuild all 24 in a minute",
               g, at=1080 - g.width).convert("RGB").save(out + "numeros-06.png")
    caption(folder, f"""
Under the hood of one fighter: {data['source_tris']:,} triangles cut down to {data['tris']:,}, a {px} px texture, 20 bones, 10 animations, {kb} KB in all. The build script prints these numbers for every fighter, and rebuilding one takes about {secs:.0f} seconds, so a new rule reaches all 24 in about a minute.

{TAGS} #blender3d #python #gameoptimization""")
    print("carousel", folder)


# ---------------------------------------------------------------- 38

# fight_promo.gd's beats (seconds) and what the title says over each
BEATS = [(0.0, "six fighters, all 3D"), (1.7, "a summon"), (3.8, "a strike"), (5.95, "a spell"),
         (8.15, "a knockout"), (10.5, "a win")]


def top_band(h=560, a=225):
    """A dark fade behind the title, for bright footage (the arena)."""
    im = Image.new("RGBA", (1080, 1920), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(h):
        d.line((0, y, 1080, y), fill=(15, 15, 13, int(a * min(1.0, (1 - y / h) * 1.6))))
    return im


TOP_BAND = None


def post38():
    global TOP_BAND
    TOP_BAND = top_band()
    folder = "38-reel-en-la-arena"
    reel = Reel(OUT + folder + "/reel-in-the-arena.mp4")
    frames = sorted(x for x in os.listdir(RAW + "r38") if x.endswith(".png"))
    for k, name in enumerate(frames):
        t = k / FPS
        i = max(j for j, (s, _) in enumerate(BEATS) if t >= s)
        f = Image.open(RAW + "r38/" + name).convert("RGBA")
        f.alpha_composite(TOP_BAND)
        f.alpha_composite(text_card("In the arena", "", BEATS[i][1], dots=(i, len(BEATS))))
        reel.add(f)
    reel.hold(end_card("Every fighter", "now in 3D"), 1.6)
    reel.done()
    caption(folder, f"""
In the arena: every fighter and summon on the board is now one of the rigged 3D figures. A summon, a strike, a spell, a knockout and a win, all played on the same 20-bone skeleton, in one of the six arenas of the prototype.

{TAGS} #tacticalrpg #turnbased #3danimation""")


POSTS = {"30": post30, "31": post31, "32": post32, "33": post33, "34": post34, "35": post35, "36": post36,
         "37": post37, "38": post38}

if __name__ == "__main__":
    for p in sys.argv[1:] or POSTS:
        POSTS[p]()
