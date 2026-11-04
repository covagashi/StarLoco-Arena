"""S35, fighter 1 by parts (owner 2026-11-04: model the head, the torso,
one leg (mirrored) and one hand in Blender, then dress them with loom):
the head and its hair.

    blender -b -P tools/blender/characters/parts/head.py -- [out.glb]

Modelled the way it is done by hand: a low cage mirrored in X and
subdivided (no fused spheres), the eyes laid on the face by ray casts, and
the hair as tapering locks (bezier curves with a flat profile) over a cap.
Units: metres = cells; the origin is the base of the neck, the face looks
-Y. Reference: retail class 1 (fighter -110), ~31 % of the height: a small
face with a pointed chin under a star of wide, flat locks.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "art", "characters", "out", "parts", "head.glb"))

PALETTE = {"skin": "e6bf9a", "hair": "d9c48e", "sclera": "f4f0e8", "iris": "3d5f6b",
           "pupil": "1c1612", "glint": "ffffff", "brow": "a38c55", "mouth": "8e4a3a", "lash": "2a1d14"}
MATS = {}


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        h = PALETTE[name]
        c = tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = c
        b.inputs["Roughness"].default_value = 0.6
        MATS[name] = m
    return MATS[name]


def link(name, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def smooth(ob):
    for p in ob.data.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------- skull

C = Vector((0, 0.005, 0.15))  # centre of the cranium above the neck


def skull_shape(v):
    """Unit sphere → head. Wide cranium, a flat face, cheeks, and a jaw that
    narrows to a small pointed chin, the retail's shape."""
    x, y, z = v
    out = Vector((x * 0.118, y * 0.115, z * 0.12))
    if z < 0:  # the jaw: narrower, longer and forward to the chin
        k = -z
        out.x *= 1 - 0.55 * k ** 1.4
        out.z *= 1 + 0.35 * k
        if y < 0:
            out.y *= 1 - 0.25 * k
        out.y -= 0.012 * k ** 2
    if y < -0.2:  # a flatter face
        out.y *= 1 - 0.12 * (-y - 0.2)
    if y > 0:  # the back of the cranium rounder
        out.y *= 1.08
    # cheeks
    cheek = math.exp(-((z + 0.25) / 0.25) ** 2) * math.exp(-((abs(x) - 0.6) / 0.3) ** 2) * max(0.0, -y)
    out += Vector((0.006 * math.copysign(1, x), -0.004, 0)) * cheek
    return C + out


def build_skull():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=12, radius=1.0)
    for v in bm.verts:
        v.co = skull_shape(v.co)
    # the nose: pull the front vertices just below the middle
    for v in bm.verts:
        d = v.co - (C + Vector((0, -0.11, -0.03)))
        w = math.exp(-(d.x / 0.018) ** 2 - (d.z / 0.025) ** 2) * (1 if v.co.y < C.y - 0.08 else 0)
        v.co.y -= 0.016 * w
    me = bpy.data.meshes.new("skull")
    bm.to_mesh(me)
    bm.free()
    ob = link("skull", me)
    ob.modifiers.new("sub", "SUBSURF").levels = 2
    apply_all(ob)
    # ears: a flattened, slightly pointed lobe each side
    for X in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=1.0)
        for v in bm.verts:
            x, y, z = v.co
            v.co = C + Vector((X * (0.112 + 0.008 * x * X), 0.005 + 0.02 * y, -0.01 + 0.032 * z + 0.01 * max(0, z) * (-y)))
        e = bpy.data.meshes.new("ear")
        bm.to_mesh(e)
        bm.free()
        eo = link("ear", e)
        eo.modifiers.new("sub", "SUBSURF").levels = 1
        apply_all(eo)
        join(ob, eo)
    ob.data.materials.append(mat("skin"))
    smooth(ob)
    return ob


def join(a, b):
    bpy.ops.object.select_all(action="DESELECT")
    a.select_set(True)
    b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()


# ---------------------------------------------------------------- face

def surface(tree, x, z):
    """Point and normal on the face at (x, z), shooting from the front."""
    hit, n, _, _ = tree.ray_cast(Vector((x, -1, z)), Vector((0, 1, 0)))
    return hit, n


def decal(name, tree, x, z, w, h, lift, thick=0.004, rot=0.0):
    """A flat oval laid on the face at (x, z), w × h, lift above the skin."""
    p, n = surface(tree, x, z)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=1.0)
    up = Vector((0, 0, 1))
    side = up.cross(n).normalized()
    up = n.cross(side).normalized()
    r = Matrix.Rotation(rot, 3, n)
    side, up = r @ side, r @ up
    for v in bm.verts:
        v.co = p + n * (lift + v.co.z * thick) + side * v.co.x * w + up * v.co.y * h
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(name, me)
    ob.data.materials.append(mat(name if name in PALETTE else "pupil"))
    smooth(ob)
    return ob


def stroke(name, tree, pts, r0, r1, lift):
    """A tapering tube along points on the face (brows, mouth)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 2
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, (x, z) in enumerate(pts):
        p, n = surface(tree, x, z)
        k = i / (len(pts) - 1)
        sp.points[i].co = (*(p + n * lift), 1)
        sp.points[i].radius = r0 + (r1 - r0) * k
    ob = link(name, cu)
    ob.data.materials.append(mat(name))
    return ob


def build_face(skull):
    tree = BVHTree.FromObject(skull, bpy.context.evaluated_depsgraph_get())
    obs = []
    ez = C.z - 0.005
    for X in (1, -1):
        ex = 0.045 * X
        obs.append(decal("sclera", tree, ex, ez, 0.02, 0.026, 0.0005, 0.005))
        obs.append(decal("iris", tree, ex - 0.003 * X, ez - 0.002, 0.013, 0.02, 0.0035, 0.003))
        obs.append(decal("pupil", tree, ex - 0.004 * X, ez - 0.003, 0.006, 0.01, 0.005, 0.002))
        obs.append(decal("glint", tree, ex - 0.008 * X, ez + 0.008, 0.0035, 0.0045, 0.0065, 0.0015))
        # upper lid line: a dark arc that thickens to the outer corner
        obs.append(stroke("lash", tree, [(ex - 0.02 * X, ez + 0.017), (ex, ez + 0.026), (ex + 0.02 * X, ez + 0.02),
                                        (ex + 0.025 * X, ez + 0.015)], 0.002, 0.003, 0.002))
        obs.append(stroke("brow", tree, [(ex - 0.018 * X, ez + 0.04), (ex + 0.004 * X, ez + 0.046),
                                        (ex + 0.024 * X, ez + 0.043)], 0.004, 0.002, 0.002))
    obs.append(stroke("mouth", tree, [(-0.016, C.z - 0.083), (0, C.z - 0.086), (0.018, C.z - 0.08)], 0.0022, 0.0018, 0.0005))
    return obs


# ---------------------------------------------------------------- hair

def profile():
    """The lock's cross-section: a flat, slightly pointed lens."""
    cu = bpy.data.curves.new("lens", "CURVE")
    sp = cu.splines.new("POLY")
    pts = [(1, 0), (0.45, 0.36), (-0.45, 0.36), (-1, 0), (-0.45, -0.36), (0.45, -0.36)]
    sp.points.add(len(pts) - 1)
    for i, (x, y) in enumerate(pts):
        sp.points[i].co = (x, y, 0, 1)
    sp.use_cyclic_u = True
    return link("lens", cu)


def lock(lens, a, b, c, width, tilt, name="lock"):
    """One lock: a bezier from root a through b to tip c, full width at the
    root, a sharp tip."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_mode = "OBJECT"
    cu.bevel_object = lens
    cu.use_fill_caps = True
    cu.resolution_u = 4
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(2)
    for i, (p, r) in enumerate(((a, width), (b, width * 0.7), (c, 0.0005))):
        bp = sp.bezier_points[i]
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = r
        bp.tilt = tilt
    return link(name, cu)


def build_hair(skull):
    rng = random.Random(3)
    lens = profile()
    obs = []
    # cap: the skull blown up a little, kept over the cranium and the nape
    me = skull.data.copy()
    cap = link("hair_cap", me)
    bm = bmesh.new()
    bm.from_mesh(me)
    for v in bm.verts:
        v.co += v.normal * 0.012
    dead = [f for f in bm.faces if (f.calc_center_median().z < C.z + 0.03 and f.calc_center_median().y < C.y - 0.02)
            or f.calc_center_median().z < C.z - 0.1]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(me)
    bm.free()
    cap.data.materials.clear()
    cap.data.materials.append(mat("hair"))
    smooth(cap)
    obs.append(cap)
    # the star: wide flat locks radiating from the crown, all round
    golden = math.pi * (3 - math.sqrt(5))
    n = 24
    for i in range(n):
        zz = 1 - 1.55 * (i + 0.5) / n          # from the top down past the ears
        rr = math.sqrt(max(0.0, 1 - zz * zz))
        th = golden * i
        d = Vector((rr * math.cos(th), rr * math.sin(th), zz))
        if d.y < -0.35 and d.z < 0.45:          # the face stays clear (bangs below)
            continue
        root = C + Vector((d.x * 0.1, d.y * 0.1, d.z * 0.1))
        out = (d + Vector((0, 0.1, 0.12))).normalized()
        ln = rng.uniform(0.11, 0.15) + 0.025 * max(0.0, d.y)
        bend = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0, 1))) * 0.02
        mid = root + out * ln * 0.5 + bend
        tip = root + out * ln + bend * 2.5
        obs.append(lock(lens, root, mid, tip, rng.uniform(0.055, 0.068), rng.uniform(-0.6, 0.6)))
    # bangs: shorter locks falling over the brow, splayed
    for x, ang in ((-0.06, -0.5), (-0.025, -0.15), (0.015, 0.2), (0.055, 0.55)):
        root = C + Vector((x, -0.06, 0.08))
        tip = C + Vector((x + 0.035 * ang, -0.125, 0.025 - 0.01 * abs(ang)))
        mid = root.lerp(tip, 0.5) + Vector((0, -0.025, 0.01))
        obs.append(lock(lens, root, mid, tip, 0.036, 1.4 + ang * 0.3, "bang"))
    for o in obs:
        if o.type == "CURVE":
            o.data.materials.append(mat("hair"))
    return obs, lens


def to_mesh(obs):
    out = []
    for o in obs:
        if o.type != "CURVE":
            out.append(o)
            continue
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.convert(target="MESH")
        smooth(o)
        out.append(o)
    return out


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    skull = build_skull()
    face = build_face(skull)
    hair, lens = build_hair(skull)
    parts = to_mesh(face + hair)
    bpy.data.objects.remove(lens)
    hair_obs = [o for o in parts if o.name.startswith(("lock", "bang", "hair_cap"))]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"[head] {OUT}: {tris} tris, {len(hair_obs)} hair pieces")


main()
