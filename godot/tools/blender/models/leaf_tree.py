"""Arena 5's green tree (retail gfx 2548) modelled in Blender headless.

A twisted pale trunk from tapered curves, with root flares and branches
into the crown; the crown is a dark core with maple leaves spread over its
surface, light on top and dark underneath. Uses the kiln piece's materials
(so looms and the game's dressing still match) and its size.

    blender -b -P godot/tools/blender/models/leaf_tree.py -- <kiln leaf_tree.glb> <out.glb> [seed]

Approved by the owner 2026-11-03 ("el árbol me gusta"); built for every loom
by tools/blender/build_models.py (art/blender.json).
"""
import math
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
rng = random.Random(int(args[2]) if len(args) > 2 else 7)

# --- the kiln piece: its materials and its size ------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
# loom variants name them tree_b, tree_c…: key them by the base name
mats = {}
for m in bpy.data.materials:
    base = m.name[:-2] if m.name[-2:] in ("_b", "_c") else m.name
    mats.setdefault(base, m)
lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
height = hi.z - lo.z  # Blender is z-up after import
for o in list(bpy.context.scene.objects):
    bpy.data.objects.remove(o)

parts = []


def curve_mesh(name, pts, r0, r1, sides=8, mat="bark", twist=0.0):
    """A tapered tube along pts (x, y, z with z up), as a mesh object."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = max(0, sides // 4 - 1)
    cu.resolution_u = 4
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for i, (p, bp) in enumerate(zip(pts, sp.bezier_points)):
        t = i / (len(pts) - 1)
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        bp.radius = r0 + (r1 - r0) * t
        bp.tilt = twist * t
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mats[mat])
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob.select_set(False)
    parts.append(ob)
    return ob


# --- trunk: an S with a twist, bark streaks winding up it --------------------
trunk_pts = [(0, 0, 0), (0.05, 0.02, 0.45), (-0.03, -0.01, 0.95), (0.03, 0.02, 1.35), (0.0, 0.0, 1.6)]
curve_mesh("trunk", trunk_pts, 0.11, 0.05, sides=10, mat="barkL", twist=2.5)
for k in range(3):  # dark streaks spiralling round the trunk
    a0 = k * 2.1
    pts = []
    for i in range(6):
        t = i / 5
        z = 0.05 + t * 1.25
        r = 0.105 - 0.045 * t
        a = a0 + t * 2.8
        cx = 0.05 * math.sin(t * 3)
        pts.append((cx + r * math.cos(a), r * math.sin(a), z))
    curve_mesh(f"streak{k}", pts, 0.022, 0.012, sides=4, mat="barkD")
for k in range(5):  # root flares: thick where they leave the trunk, sinking into the ground
    a = k * 1.26 + rng.uniform(-0.2, 0.2)
    d = Vector((math.cos(a), math.sin(a), 0))
    curve_mesh(f"root{k}", [(d * 0.03 + Vector((0, 0, 0.16))).to_tuple(), (d * 0.12 + Vector((0, 0, 0.04))).to_tuple(),
                            (d * 0.2 + Vector((0, 0, -0.02))).to_tuple()], 0.075, 0.03, sides=6, mat="barkL")
for k, (a, z0, ln) in enumerate([(0.3, 1.05, 0.5), (2.6, 1.2, 0.5), (4.4, 1.3, 0.42), (1.5, 1.4, 0.35)]):
    d = Vector((math.cos(a), math.sin(a), 0))
    curve_mesh(f"branch{k}", [(0, 0, z0), (d * ln * 0.5 + Vector((0, 0, z0 + 0.25))).to_tuple(),
                              (d * ln + Vector((0, 0, z0 + 0.4))).to_tuple()], 0.045, 0.015, sides=6, mat="bark")

# --- crown: clumps round a dark core -------------------------------------------
clumps = [((0, 0, 2.0), 0.5), ((0.5, 0.15, 1.7), 0.42), ((-0.5, 0.05, 1.75), 0.42), ((0.1, -0.1, 2.32), 0.36),
          ((-0.2, -0.42, 1.55), 0.34), ((0.25, 0.42, 1.5), 0.32), ((-0.38, 0.3, 2.15), 0.3), ((0.4, -0.35, 2.0), 0.3)]
core = bmesh.new()
for c, r in clumps:
    bmesh.ops.create_icosphere(core, subdivisions=2, radius=r * 0.62, matrix=Matrix.Translation(c))
for v in core.verts:
    v.co += Vector([rng.uniform(-0.03, 0.03) for _ in range(3)])
me = bpy.data.meshes.new("core")
core.to_mesh(me)
ob = bpy.data.objects.new("core", me)
bpy.context.collection.objects.link(ob)
me.materials.append(mats["treeD"])
parts.append(ob)

# a maple leaf outline (kiln's), as a thin flat polygon
outline = []
for i in range(20):
    t = i / 20 * math.pi * 2
    lobe = abs(math.cos(2.5 * (t - math.pi / 2))) ** 1.4
    r = 0.1 * (0.55 + 0.45 * lobe) * (1 - 0.4 * max(0, -math.sin(t)))
    outline.append((math.cos(t) * r, math.sin(t) * r + 0.03))

leaves = bmesh.new()
mat_order = ["treeL", "tree", "treeD", "treeX"]
leaf_mats = {n: i for i, n in enumerate(mat_order)}
for c, r in clumps:
    n = int(40 + r * 90)
    for i in range(n):
        # a point on the clump's surface, more of them on the sides and top
        u, w = rng.random(), rng.random()
        zz = 1 - 1.75 * u
        rr = math.sqrt(max(0.0, 1 - zz * zz))
        a = w * math.tau
        nrm = Vector((rr * math.cos(a), rr * math.sin(a), zz)).normalized()
        pos = Vector(c) + nrm * r * rng.uniform(0.7, 0.98)
        if pos.z < 1.25:
            continue
        # mostly mid green; light only right on top, dark inside and underneath
        depth = (pos - Vector(c)).length / r
        name = ("treeX" if rng.random() < 0.06 else "treeD" if nrm.z < -0.15 or depth < 0.78
                else "treeL" if nrm.z > 0.7 and rng.random() < 0.6 else "tree")
        s = rng.uniform(1.2, 1.7)
        # leaf plane faces out along the normal, tipped up, spun at random
        rot = nrm.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z") \
            @ Matrix.Rotation(math.radians(rng.uniform(-25, 25)), 4, "X")
        m = Matrix.Translation(pos) @ rot @ Matrix.Scale(s, 4)
        vs = [leaves.verts.new(m @ Vector((x, y, 0))) for x, y in outline]
        f = leaves.faces.new(vs)
        f.material_index = leaf_mats[name]
me = bpy.data.meshes.new("leaves")
leaves.to_mesh(me)
ob = bpy.data.objects.new("leaves", me)
bpy.context.collection.objects.link(ob)
for n in mat_order:
    me.materials.append(mats[n])
parts.append(ob)

# --- one mesh, flat-shaded like the rest of the kit, at the kiln piece's height
bpy.ops.object.select_all(action="DESELECT")
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
tree = bpy.context.active_object
tree.name = "leaf_tree"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
zs = [v.co.z for v in tree.data.vertices]
k = height / (max(zs) - min(zs))
tree.scale = (k, k, k)
bpy.ops.object.transform_apply(scale=True)
for p in tree.data.polygons:
    p.use_smooth = False
tree.data.calc_loop_triangles()
print(f"TREE tris={len(tree.data.loop_triangles)} height={height:.2f}")
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", use_selection=True)
