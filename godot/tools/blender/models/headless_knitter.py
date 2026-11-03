"""Arena 10's headless knitter (retail 2763), in Blender: her body modelled
from scratch as soft continuous shapes (metaballs, one surface per
material): broad hips, a belly, a bust and a rounded back in the blue dress,
puffed sleeves, heavy arms tapering to the wrists and hands hanging over the
armrests, the white nightgown over thick thighs, the calves down into the
slippers. Kiln's layout (kit.kx.js: SEAT 0.48, the body leaning back 8°, the
whole turned -90° about y). Kept from kiln as they are: the rocking chair,
the neck stump, the slippers, the knitting and the yarn; the torn hems are
rebuilt here (kiln's flat flaps hung in the air round the calves).
Materials and their linen loom as in kiln.
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Piece  # noqa: E402
from mathutils import Matrix, Quaternion, Vector  # noqa: E402

p = Piece(keep={"chair", "chairV", "pale", "meat", "bone", "slipper", "slipperD", "eye", "knitG", "knitO",
                "steel", "yarnBall"})
SEAT = 0.48
LEAN = math.radians(8)


def W(x, y, z):
    """kiln's local model coordinates (x to her front, y up) to Blender."""
    return Vector((-z, -x, y))


def B(x, y, z):
    """her body's frame: on the seat, leaning back with the chair."""
    xr = x * math.cos(LEAN) - y * math.sin(LEAN)
    yr = x * math.sin(LEAN) + y * math.cos(LEAN)
    return W(xr - 0.06, yr + SEAT + 0.06, z)


def soft(name, mat, balls, res=0.018, grow=1.4):
    """One continuous surface from metaball ellipsoids (c, r, (sx, sy, sz))
    and capsules ('cap', a, b, r). A metaball's surface sits well inside its
    radius: grow makes the sizes the ones written here."""
    mb = bpy.data.metaballs.new(name)
    mb.resolution = mb.render_resolution = res
    mb.threshold = 0.6
    for e in balls:
        if e[0] == "cap":
            _, a, b, r = e
            el = mb.elements.new(type="CAPSULE")
            el.co = (a + b) / 2
            el.radius = r * grow
            el.size_x = (b - a).length / 2
            el.rotation = Vector((1, 0, 0)).rotation_difference((b - a).normalized())
        else:
            c, r, sc = e
            el = mb.elements.new(type="ELLIPSOID")
            el.co = c
            el.radius = r * grow
            el.size_x, el.size_y, el.size_z = sc
    ob = bpy.data.objects.new(name, mb)
    bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.view_layer.objects.active
    ob.select_set(False)
    d = ob.modifiers.new("decimate", "DECIMATE")
    d.ratio = 0.35
    p._apply(ob, d)
    ob.data.materials.clear()
    ob.data.materials.append(p.mat(mat))
    p.parts.append(ob)


S = SEAT
# the blue dress: hips, belly, back, bust, shoulders, puffed sleeves (the body
# frame's z is across her: ellipsoid sizes are given as Blender x, y, z =
# across, front-back, up)
soft("dressBody", "softDress", grow=1.45, balls=[
    (B(0.0, 0.1, 0), 0.34, (1.25, 1.0, 0.75)),
    (B(0.1, 0.26, 0), 0.27, (1.15, 1.0, 0.9)),
    (B(-0.07, 0.42, 0), 0.27, (1.25, 0.9, 0.8)),
    (B(-0.04, 0.53, 0), 0.2, (1.4, 0.9, 0.6)),          # the shoulders up to the stump
    (B(0.13, 0.42, -0.12), 0.13, (1, 1, 0.95)), (B(0.13, 0.42, 0.12), 0.13, (1, 1, 0.95)),
    (B(-0.03, 0.52, -0.26), 0.13, (1, 1, 0.9)), (B(-0.03, 0.52, 0.26), 0.13, (1, 1, 0.9)),
    (B(-0.03, 0.49, -0.34), 0.135, (1, 1, 1.0)), (B(-0.03, 0.49, 0.34), 0.135, (1, 1, 1.0)),
    (B(0.0, 0.58, 0), 0.1, (1.2, 1, 0.6)),
    (W(0.1, S + 0.02, 0), 0.26, (1.0, 0.9, 0.35)),      # the lap of the dress under the nightgown
])
# her skin: arms (upper arm, forearm), hands, knees and calves
skin = []
for k in (-1, 1):
    skin += [("cap", B(-0.03, 0.44, k * 0.39), B(0.0, 0.2, k * 0.45), 0.12),
             ("cap", B(0.0, 0.2, k * 0.46), B(0.04, -0.08, k * 0.48), 0.095),
             (B(0.045, -0.14, k * 0.48), 0.06, (0.6, 1.05, 1.25)),           # the palm, flat to her side
             ("cap", W(0.45, S - 0.1, k * 0.232), W(0.47, 0.16, k * 0.17), 0.095),  # the shin, the feet drawn in between the rockers
             (W(0.455, S - 0.21, k * 0.21), 0.105, (1, 1, 1.35)),               # the calf's bulge
             ("cap", W(0.48, 0.16, k * 0.165), W(0.52, 0.085, k * 0.145), 0.05)]  # the ankle, ending inside the slipper
soft("skin", "softPale", skin)
# the fingers: kiln's hanging hand (four fingers straight down, the thumb
# forward), as separate rounded fingers so they read at game scale
for k in (-1, 1):
    hx, hy, hz = 0.045, -0.14, k * 0.48
    for f in (-1.5, -0.5, 0.5, 1.5):
        a, b = B(hx + f * 0.022, hy - 0.04, hz), B(hx + f * 0.025, hy - 0.13 + abs(f) * 0.012, hz)
        p.tube([a, a.lerp(b, 0.5), b], 0.021, 0.017, mat="softPale", sides=6)
        p.blob(b, 0.017, "softPale", sub=1)
    a, b = B(hx + 0.05, hy - 0.01, hz), B(hx + 0.09, hy - 0.07, hz)
    p.tube([a, a.lerp(b, 0.5), b], 0.023, 0.019, mat="softPale", sides=6)
    p.blob(b, 0.019, "softPale", sub=1)
# the white nightgown over the thighs, a flat drape between them (no lump)
gown = []
for k in (-1, 1):
    gown += [("cap", W(0.06, S + 0.08, k * 0.15), W(0.4, S + 0.02, k * 0.2), 0.155)]
gown += [(W(0.25, S + 0.05, 0), 0.11, (1.0, 1.8, 0.4))]
soft("gown", "softApronW", gown, grow=1.15)
# the knee sleeve: kiln's exact lathe, so the torn hem (kept from kiln) lies
# flush round it instead of hanging off it like wings
for k in (-1, 1):
    p.lathe([(0.15, 0), (0.153, 0.1), (0.152, 0.2), (0.135, 0.26), (0.0, 0.27)], "softApronW", sides=14,
            c=W(0.455, S - 0.17, k * 0.232))
# the torn hem round each knee (kiln's flat flaps hung in the air round the
# calf): thick ragged tongues continuing the sleeve, each following the leg
# down and in until it lies on the calf; under them at the outer side a few
# longer tongues of the blue dress
import bmesh  # noqa: E402


def tongue(bm, axis, a, w, top, r_top, r_bot, length, thick, mi, tip):
    """One ragged tongue on the cone round axis (a vertical line through
    axis.x, axis.y): centred at angle a, w wide, from height top down by
    length, its radius going r_top to r_bot; tip: how far the point sits off
    centre (fraction of w)."""
    outline = [(-w / 2, 0), (w / 2, 0), (w * 0.42, length * 0.55), (w * tip, length), (-w * 0.45, length * 0.6)]
    def at(u, v, inset):
        t = v / length
        rr = r_top + (r_bot - r_top) * t - inset
        ang = a + u / r_top
        return Vector((axis.x + math.cos(ang) * rr, axis.y + math.sin(ang) * rr, top - v))
    front = [bm.verts.new(at(u, v, 0)) for u, v in outline]
    back = [bm.verts.new(at(u, v, thick)) for u, v in outline]
    fs = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        fs.append(bm.faces.new((front[j], front[i], back[i], back[j])))
    for f in fs:
        f.material_index = mi


rng = p.rng
for k in (-1, 1):
    axis = W(0.455, 0, k * 0.232)
    out_a = math.atan2(0, 1) if axis.x > 0 else math.pi   # the outer side (away from the other leg)
    bm = bmesh.new()
    top = S - 0.165
    n = 15
    for i in range(n):  # white, all round
        a = i / n * math.tau + rng.uniform(-0.05, 0.05)
        tongue(bm, axis, a, 2 * math.pi * 0.152 / n * 1.25, top, 0.153, 0.128, rng.uniform(0.05, 0.11), 0.01, 0,
               rng.uniform(-0.25, 0.25))
    for i in range(4):  # the blue dress under it at the outer side, a little longer
        a = out_a + (i - 1.5) * 0.42 + rng.uniform(-0.08, 0.08)
        tongue(bm, axis, a, 0.075, top + 0.01, 0.146, 0.122, rng.uniform(0.1, 0.14), 0.008, 1, rng.uniform(-0.3, 0.3))
    me = bpy.data.meshes.new("hem")
    bm.to_mesh(me)
    bm.free()
    p._link("hem", me, ["apronW", "dressD"])

# the slippers (kept from kiln) turned out a little at the toes, as the
# retail draws her feet, and moved forward and in: in kiln they ran through
# the chair's rockers (x 0.26..0.32, from y -0.49 back)
kept = p.parts[0]
bm = bmesh.new()
bm.from_mesh(kept.data)
mats = [m.name.split("_")[0] if m else "" for m in kept.data.materials]
for k in (-1, 1):
    pivot = W(0.455, 0, k * 0.25)
    FWD = W(0.065, 0, 0)  # forward, clear of the chair's front rail
    side = 1 if pivot.x > 0 else -1
    verts = {v for f in bm.faces if mats[f.material_index] in ("slipper", "slipperD", "eye")
             and (f.calc_center_median().x > 0) == (side > 0) and f.calc_center_median().z < 0.25 for v in f.verts}
    bmesh.ops.rotate(bm, verts=list(verts), cent=pivot, matrix=Matrix.Rotation(math.radians(12) * side, 3, "Z"))
    bmesh.ops.translate(bm, verts=list(verts), vec=FWD + Vector((-side * 0.105, 0, 0)))
bm.to_mesh(kept.data)
bm.free()
p.finish("headless_knitter", fit="none")
