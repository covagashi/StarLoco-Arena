#!/usr/bin/env python3
"""S38b: Nilo's idle loop, animated in AniCraft (owner 2026-11-13: "si quiere
animar que use anicraft"). Drives `anicraft-cli serve` (JSON lines): the
portrait (nilo_fable.vx.js) and its overlays (nilo_anim.vx.js) go in as the
2x PNG renders — exact, where the SVG import splits him into 136 layers and
skips 14 nested clips — and AniCraft does the timeline:
  - breath: the figure stretches 1.2 % up from his feet and back, eased;
  - the stone's glow pulses with it;
  - a blink (the lids layer, a hard switch on frames 31-34);
  - a sparkle by the stone turns and fades in and out early in the loop.
48 frames at 24 fps (2 s). Writes the .anicraft document, an animated GIF, a
sprite sheet (+ its JSON frame map) and a PNG sequence into OUT.
Run from godot/ after both vex builds (portrait --scales 1,2 into npc/fable,
overlays --scales 1,2 into npc/anim):
    python3 tools/portraits/nilo_anim.py <npc dir> <out dir>
"""
import json
import os
import subprocess
import sys

W, H, FPS, N = 340, 400, 24, 48
BREATH = 0.012        # how much taller at the top of the breath
BLINK = (30, 34)      # frames (0-based) the lids show: [from, to)
SPARK_C = (262, 188)  # the sparkle's centre on the 2x stage
SPARK = 56            # its sprite's side at 2x


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


def ease_in_out(t):
    return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2


def breath_at(f):
    """The breath's stretch at frame f (the tweens 0→24→47 ease in and out)."""
    t = f / 24 if f <= 24 else 1 - (f - 24) / (N - 1 - 24)
    return BREATH * ease_in_out(t)


def stretch(k):
    """A full-stage layer stretched by k from its feet (the stage bottom)."""
    return {"x": 0, "y": -H * k, "sx": 1 - k / 3, "sy": 1 + k}


def spark_at(scale, rot):
    """Scale and turn the sparkle about its centre (the registration point is
    the element's top-left corner)."""
    import math
    a = math.radians(rot)
    hx = hy = SPARK / 2 * scale
    ox = hx * math.cos(a) - hy * math.sin(a)
    oy = hx * math.sin(a) + hy * math.cos(a)
    return {"x": SPARK_C[0] - ox, "y": SPARK_C[1] - oy, "sx": scale, "sy": scale, "rotation": rot}


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    a = AniCraft()
    a("doc.set_stage", width=W, height=H, fps=FPS, background="#ffffff")
    layers = {}
    for name, path, at in [("nilo", "fable/sprites/nilo@2x.png", {"x": 0, "y": 0}),
                           ("glow", "anim/sprites/nilo_glow@2x.png", {"x": 0, "y": 0}),
                           ("blink", "anim/sprites/nilo_blink@2x.png", {"x": 0, "y": 0}),
                           ("spark", "anim/sprites/nilo_spark@2x.png", {"cx": SPARK_C[0], "cy": SPARK_C[1]})]:
        r = a("file.import", path=os.path.join(src, name and path), **at)
        layers[name] = r["layer"]
        a("layer.rename", layer=r["layer"], name=name)
    # the empty first layer the new document came with
    for l in a("doc.info")["layers"]:
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
    for name, alphas in [("nilo", None), ("glow", (0.35, 1.0, 0.35))]:
        L = layers[name]
        for i, f in enumerate((0, 24, N - 1)):
            key(L, f, stretch(breath_at(f)), alphas[i] if alphas else None, tween=f < N - 1)
        for f in (0, 24):
            a("timeline.set_easing", layer=L, frame=f, easing="ease_in_out")
    # the blink: hidden, shown on BLINK (where the breath has the figure), hidden
    L = layers["blink"]
    key(L, 0, stretch(0), alpha=0.0)
    key(L, BLINK[0], stretch(breath_at(BLINK[0])), alpha=1.0)
    key(L, BLINK[1], stretch(breath_at(BLINK[1])), alpha=0.0)
    # the sparkle: grows turning and fades, then rests hidden
    L = layers["spark"]
    key(L, 0, spark_at(0.2, 0), alpha=0.0, tween=True)
    key(L, 8, spark_at(1.0, 45), alpha=1.0, tween=True)
    key(L, 16, spark_at(0.2, 90), alpha=0.0)
    for f in (0, 8):
        a("timeline.set_easing", layer=L, frame=f, easing="ease_out")
    a("file.save", path=os.path.join(out, "nilo_idle.anicraft"))
    a("file.export_gif", path=os.path.join(out, "nilo_idle.gif"), scale=0.5, loop=True, confirm=True)
    a("doc.set_stage", background="#00000000") if False else None
    a("file.export_sprite_sheet", path=os.path.join(out, "nilo_idle_sheet.png"), columns=8, confirm=True)
    a("file.export_png_sequence", dir=os.path.join(out, "frames"))
    print(json.dumps({"layers": layers, "out": out}))


if __name__ == "__main__":
    main()
