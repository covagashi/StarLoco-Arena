#!/usr/bin/env python3
"""S38b: the NPC portraits' idle loops, animated in AniCraft (owner
2026-11-13: "si quiere animar que use anicraft"). Drives `anicraft-cli serve`
(JSON lines): each portrait (<npc>_fable.vx.js) and its overlays
(<npc>_anim.vx.js) go in as the 2x PNG renders — exact, where the SVG import
splits a portrait into a hundred layers and skips nested clips — and AniCraft
does the timeline:
  - breath: the figure stretches 1.2 % up from its feet and back, eased;
  - the glow layer pulses with it (clipped to what shines: a soft halo over
    the ink came out muddy, AniCraft does not premultiply);
  - a blink (the lids layer, a hard switch);
  - a sparkle (at the overlay file's `// SPARK_C = [x, y]`) turns and fades.
48 frames at 24 fps (2 s).
S53: a portrait that touches the stage's top or sides (Aldebrán's sticks,
Demon I's wings, Demon III's horn, Nilo's ears) showed cut flat in the talk
window, the breath lifting it further; fit() moves the figure down (the
bottom sits under the screen's edge, a cut there never shows) or shrinks it
about its feet until MARGIN is free, and its overlays and the sparkle follow.
It also writes the still portrait (<npc>.png) the window shows without the
sheet. Writes per NPC, into OUT/<npc>/, the .anicraft
document, a GIF to look at and AniCraft's sprite sheet; then packs the game's
sheet — every other frame (12 fps, the loop is slow), WebP — as
assets/ui/portraits/npc/<npc>_idle.webp + .json, which talk_panel.gd plays.
Run from godot/ after the vex builds (portraits --scales 1,2 into
<npc dir>/fable*/, overlays --scales 1,2 into <npc dir>/anim/):
    python3 tools/portraits/npc_anim.py <npc dir> <out dir> [npc ...]
"""
import io
import json
import math
import os
import re
import subprocess
import sys

from PIL import Image

W, H, FPS, N = 340, 400, 24, 48
BREATH = 0.012        # how much taller at the top of the breath
SPARK = 56            # the sparkle sprite's side at 2x
STEP = 2              # the game keeps every STEP-th frame (24 fps → 12)
MARGIN = 12           # free 2x pixels at the top and sides (the breath takes 5)
ASSETS = "assets/ui/portraits/npc"
# npc → the portrait's render (under <npc dir>) and the frames its lids show
NPCS = {
    "nilo": {"portrait": "fable/sprites/nilo@2x.png", "blink": (30, 34)},
    "aldebran": {"portrait": "fable_aldebran/sprites/aldebran@2x.png", "blink": (36, 40)},
    # S53: these two portraits are drawn 16 units lower (*_fable.vx.js); their
    # overlays, drawn where the figure was, follow by `lower` 2x pixels
    "demon1": {"portrait": "fable_demon1/sprites/demon1@2x.png", "blink": (26, 30), "lower": 32},
    "demon3": {"portrait": "fable_demon3/sprites/demon3@2x.png", "blink": (32, 36), "lower": 32},
}


class AniCraft:
    def __init__(self):
        self.p = subprocess.Popen(["anicraft-cli", "serve"], stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, text=True)
        self.p.stdout.readline()   # {"app": "AniCraft", "ready": true, ...}
        self.n = 0

    def __call__(self, cmd, **params):
        self.n += 1
        self.p.stdin.write(json.dumps({"id": self.n, "cmd": cmd, "params": params}) + "\n")
        self.p.stdin.flush()
        while True:
            r = json.loads(self.p.stdout.readline())
            if r.get("id") == self.n:
                if not r.get("ok"):
                    raise RuntimeError(f"{cmd} {params}: {r}")
                return r.get("result")

    def close(self):
        self.p.stdin.close()
        self.p.wait()


def ease_in_out(t):
    return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2


def breath_at(f):
    """The breath's stretch at frame f (the tweens 0→24→47 ease in and out)."""
    t = f / 24 if f <= 24 else 1 - (f - 24) / (N - 1 - 24)
    return BREATH * ease_in_out(t)


def stretch(k):
    """A full-stage layer stretched by k from its feet (the stage bottom)."""
    return {"x": 0, "y": -H * k, "sx": 1 - k / 3, "sy": 1 + k}


def spark_at(c, scale, rot):
    """Scale and turn the sparkle about its centre c (the registration point
    is the element's top-left corner)."""
    a = math.radians(rot)
    h = SPARK / 2 * scale
    return {"x": c[0] - (h * math.cos(a) - h * math.sin(a)),
            "y": c[1] - (h * math.sin(a) + h * math.cos(a)),
            "sx": scale, "sy": scale, "rotation": rot}


def spark_centre(npc):
    src = open(f"tools/portraits/{npc}_anim.vx.js").read()
    m = re.search(r"//\s*SPARK_C\s*=\s*\[\s*([\d.]+)\s*,\s*([\d.]+)\s*\]", src)
    return (float(m.group(1)) * 2, float(m.group(2)) * 2)   # 1x → the 2x stage


def fit(npc, src, work):
    """The figure and its overlays moved down / shrunk about the feet so the
    portrait keeps MARGIN free at the top and sides; returns the file names
    (under `work`) and the sparkle centre, moved the same way."""
    cfg = NPCS[npc]
    names = {"figure": cfg["portrait"], "glow": f"anim/sprites/{npc}_glow@2x.png",
             "blink": f"anim/sprites/{npc}_blink@2x.png"}
    fig = Image.open(os.path.join(src, names["figure"])).convert("RGBA")
    x0, y0, x1, _ = fig.getchannel("A").getbbox()
    cx = W / 2
    dy = max(0, MARGIN - y0)   # down first: the cut falls below the screen
    s = 1.0
    if x0 < MARGIN:
        s = min(s, (cx - MARGIN) / (cx - x0))
    if x1 > W - MARGIN:
        s = min(s, (W - MARGIN - cx) / (x1 - cx))
    ox, oy = cx - cx * s, H - H * s + dy

    def move(img, lower=0):
        if lower:
            img = img.crop((0, -lower, img.width, img.height - lower))
        img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS) if s < 1 else img
        out = Image.new("RGBA", (W, H))
        out.alpha_composite(img, (round(ox), round(oy)))
        return out
    os.makedirs(os.path.join(work, npc), exist_ok=True)
    files = {}
    for k, rel in names.items():
        files[k] = os.path.join(work, npc, k + ".png")
        lower = 0 if k == "figure" else cfg.get("lower", 0)
        move(Image.open(os.path.join(src, rel)).convert("RGBA"), lower).save(files[k])
    c = spark_centre(npc)
    c = (c[0], c[1] + cfg.get("lower", 0))
    still = move(fig)
    still.save(f"{ASSETS}/{npc}.png")
    return files, (ox + c[0] * s, oy + c[1] * s), (s, dy)


def animate(npc, src, out):
    cfg = NPCS[npc]
    files, c, how = fit(npc, src, out)
    print(f"{npc}: fit scale {how[0]:.3f}, down {how[1]} px")
    a = AniCraft()
    a("doc.set_stage", width=W, height=H, fps=FPS, background="#ffffff")
    layers = {}
    for name, path, at in [("figure", files["figure"], {"x": 0, "y": 0}),
                           ("glow", files["glow"], {"x": 0, "y": 0}),
                           ("blink", files["blink"], {"x": 0, "y": 0}),
                           ("spark", os.path.join(src, f"anim/sprites/{npc}_spark@2x.png"), {"cx": c[0], "cy": c[1]})]:
        r = a("file.import", path=os.path.abspath(path), **at)
        layers[name] = r["layer"]
        a("layer.rename", layer=r["layer"], name=name)
    for l in a("doc.info")["layers"]:   # the empty layer a new document has
        if l["id"] not in layers.values():
            a("layer.delete", layer=l["id"])
    a("timeline.insert_frame", layers=list(layers.values()), frame=N - 1)

    def key(layer, f, transform=None, alpha=None, tween=False):
        if f > 0:
            a("timeline.insert_keyframe", layer=layer, frame=f)
        a("timeline.goto", frame=f)
        a("layer.select", layer=layer, select=True)
        if transform is not None:
            a("element.set_transform", **transform)
        if alpha is not None:
            a("element.set_alpha", alpha=alpha)
        if tween:
            a("timeline.create_tween", layer=layer, frame=f)

    # breath and glow: keys at 0, 24, 47, classic tweens between, eased
    for name, alphas in [("figure", None), ("glow", (0.35, 1.0, 0.35))]:
        L = layers[name]
        for i, f in enumerate((0, 24, N - 1)):
            key(L, f, stretch(breath_at(f)), alphas[i] if alphas else None, tween=f < N - 1)
        for f in (0, 24):
            a("timeline.set_easing", layer=L, frame=f, easing="ease_in_out")
    # the blink: hidden, shown where the breath has the figure, hidden
    L = layers["blink"]
    b0, b1 = cfg["blink"]
    key(L, 0, stretch(0), alpha=0.0)
    key(L, b0, stretch(breath_at(b0)), alpha=1.0)
    key(L, b1, stretch(breath_at(b1)), alpha=0.0)
    # the sparkle: grows turning and fades, then rests hidden
    L = layers["spark"]
    key(L, 0, spark_at(c, 0.2, 0), alpha=0.0, tween=True)
    key(L, 8, spark_at(c, 1.0, 45), alpha=1.0, tween=True)
    key(L, 16, spark_at(c, 0.2, 90), alpha=0.0)
    for f in (0, 8):
        a("timeline.set_easing", layer=L, frame=f, easing="ease_out")
    os.makedirs(out, exist_ok=True)
    a("file.save", path=os.path.join(out, f"{npc}_idle.anicraft"))
    a("file.export_gif", path=os.path.join(out, f"{npc}_idle.gif"), loop=True, confirm=True)
    sheet = os.path.join(out, f"{npc}_idle_sheet.png")
    a("file.export_sprite_sheet", path=sheet, columns=8, confirm=True)
    a.close()
    return sheet


def pack(npc, sheet):
    """AniCraft's sheet (8 columns, transparent) → the game's: every STEP-th
    frame, 8 columns, WebP."""
    src = Image.open(sheet).convert("RGBA")
    keep = list(range(0, N, STEP))
    cols = 8
    rows = (len(keep) + cols - 1) // cols
    out = Image.new("RGBA", (cols * W, rows * H))
    for i, f in enumerate(keep):
        cell = src.crop(((f % 8) * W, (f // 8) * H, (f % 8 + 1) * W, (f // 8 + 1) * H))
        out.paste(cell, ((i % cols) * W, (i // cols) * H))
    os.makedirs(ASSETS, exist_ok=True)
    b = io.BytesIO()
    out.save(b, "WEBP", quality=90, method=6)
    open(f"{ASSETS}/{npc}_idle.webp", "wb").write(b.getvalue())
    json.dump({"frames": len(keep), "columns": cols, "w": W, "h": H, "fps": FPS // STEP},
              open(f"{ASSETS}/{npc}_idle.json", "w"), indent=1)
    return len(b.getvalue())


def main():
    src, out = sys.argv[1], sys.argv[2]
    for npc in sys.argv[3:] or NPCS:
        sheet = animate(npc, src, os.path.join(out, npc))
        print(f"{npc}: {pack(npc, sheet) // 1024} KB")


if __name__ == "__main__":
    main()
