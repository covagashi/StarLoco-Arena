"""S35b-marketing (tanda 3): summon 8010 built piece by piece for the reel,
with crystal_8010.py's own parts: the oval, the frame, the eight rays one
by one, the shine, the tilt, then it floats and turns.

    blender -b -P tools/blender/characters/promo_crystal.py -- <out_dir> [--size=1080x1920]

<out_dir>/%04d.png (transparent) and steps.json (the frame each step starts).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
SIZE = next((a.split("=", 1)[1] for a in argv if a.startswith("--size=")), "1080x1920")
sys.argv[sys.argv.index("--") + 1] = os.path.join(OUT, "unused.glb")
import crystal_8010 as c8  # noqa: E402

STEPS = [("oval", 0, 20), ("frame", 24, 18), ("rays", 46, 48), ("shine", 98, 12), ("tilt", 114, 20), ("float", 138, 96)]


def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def pop(t):  # 0 → 1.15 → 1
    t = max(0.0, min(1.0, t))
    return ease(t / 0.7) * 1.15 if t < 0.7 else 1.15 - 0.15 * ease((t - 0.7) / 0.3)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glass, frame = c8.oval_glass(), c8.frame()
    rays = c8.rays()
    streak, cut = c8.shine()
    keep = glass.copy()
    keep.data = glass.data.copy()
    keep.scale = (c8.RX * 0.96, 0.2, c8.RZ * 0.96)
    bpy.context.collection.objects.link(keep)
    cut.operation, cut.object = "INTERSECT", keep
    bpy.context.view_layer.objects.active = streak
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(keep)
    pivot = bpy.data.objects.new("pivot", None)
    bpy.context.collection.objects.link(pivot)
    pivot.location = c8.CENTRE
    parts = [glass, frame, streak] + rays
    for p in parts:
        p.parent = pivot
        p.location = p.location - Vector((0, 0, 0))  # parts sit around the origin; the pivot lifts them
        for m in p.data.materials:  # workbench reads the viewport colour
            m.diffuse_color = m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value
        p["s"] = tuple(p.scale)
    for o in parts:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
    bpy.ops.object.shade_smooth()
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.render.film_transparent = True
    w, h = (int(x) for x in SIZE.split("x"))
    scn.render.resolution_x, scn.render.resolution_y = w, h
    scn.view_settings.view_transform = "Standard"
    sh = scn.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.show_specular_highlight = True
    sh.show_cavity = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.lens, cam.data.sensor_fit = 50, "VERTICAL"
    a = math.radians(14)
    cam.location = Vector((3.8 * math.sin(a), -3.8 * math.cos(a), 1.15))
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    start = {n: (f, d) for n, f, d in STEPS}
    total = STEPS[-1][1] + STEPS[-1][2]
    os.makedirs(OUT, exist_ok=True)
    for k in range(total):
        t = lambda n: (k - start[n][0]) / start[n][1]
        sc = {glass.name: pop(t("oval")), frame.name: pop(t("frame")), streak.name: ease(t("shine"))}
        for i, r in enumerate(rays):
            sc[r.name] = pop((k - start["rays"][0] - i * 6) / 8)
        for p in parts:
            s0 = Vector(p["s"])
            p.scale = s0 * max(sc[p.name], 1e-4)
            p.hide_render = sc[p.name] <= 0.001
        tf = t("float")
        pivot.rotation_euler = (0, math.radians(-18) * ease(t("tilt")),
                                math.radians(360 * ease(tf)) if tf > 0 else 0)
        pivot.location = c8.CENTRE + Vector((0, 0, 0.06 * math.sin(math.pi * 3 * max(0, tf)) + 0.1 * ease(tf * 3)))
        scn.render.filepath = os.path.join(OUT, f"{k:04d}.png")
        bpy.ops.render.render(write_still=True)
    with open(os.path.join(OUT, "steps.json"), "w") as f:
        json.dump(STEPS, f)
    print("[promo_crystal]", OUT, total, "frames")


main()
