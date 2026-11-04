"""S35: the common rig, its base animations and the first fighter, drawn
after retail class 1 (fighter -110, owner 2026-11-04: "no me gustan los
diseños, toma como referencia 1 del retail"): long and slim, a small face
in a big mop of spiky hair, long arms, baggy trousers gathered at the
ankle, a grey vest over white sleeves, a gold collar, an open stance.
Every fighter, summon and coach shares this skeleton, so an animation is
made once and serves all 12 classes in all 8 directions (the game turns
the model).

    blender -b -P tools/blender/characters/fighter1.py -- [out.glb]

Blender is z-up and the fighter faces -Y (glTF: +Z, the way the arenas
expect it); .L is its left, +X. 1 unit = 1 cell, the kit's metre. Height
1.45 with the hair: the retail sprite's 78 px at game zoom.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.normpath(os.path.join(HERE, "..", "..", "..", "art", "characters", "out", "fighter1.glb"))
FPS = 30
ANKLE, TOE = 0.075, 0.022  # foot bone head / tail above the sole
HEAD_SCALE = 1.15  # head, face and hair about the neck

# ---------------------------------------------------------------- skeleton

BONES = [  # name, head, tail, parent
    ("root", (0, 0, 0), (0, 0.15, 0), None),
    ("hips", (0, 0, 0.58), (0, 0, 0.68), "root"),
    ("spine", (0, 0, 0.68), (0, 0, 0.80), "hips"),
    ("chest", (0, 0, 0.80), (0, 0, 0.93), "spine"),
    ("neck", (0, 0, 0.93), (0, 0, 1.00), "chest"),
    ("head", (0, 0, 1.00), (0, 0, 1.40), "neck"),
]
for S, X in (("L", 1), ("R", -1)):
    BONES += [
        (f"shoulder.{S}", (0.03 * X, 0, 0.905), (0.10 * X, 0, 0.905), "chest"),
        (f"upper_arm.{S}", (0.10 * X, 0, 0.905), (0.135 * X, 0.005, 0.72), f"shoulder.{S}"),
        (f"forearm.{S}", (0.135 * X, 0.005, 0.72), (0.155 * X, -0.015, 0.55), f"upper_arm.{S}"),
        (f"hand.{S}", (0.155 * X, -0.015, 0.55), (0.16 * X, -0.025, 0.46), f"forearm.{S}"),
        (f"thigh.{S}", (0.075 * X, 0, 0.58), (0.10 * X, 0, 0.32), "hips"),
        (f"shin.{S}", (0.10 * X, 0, 0.32), (0.105 * X, 0.01, ANKLE), f"thigh.{S}"),
        (f"foot.{S}", (0.105 * X, 0.01, ANKLE), (0.105 * X, -0.115, TOE), f"shin.{S}"),
    ]


def build_armature():
    arm = bpy.data.armatures.new("rig")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, parent in BONES:
        b = arm.edit_bones.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = (b.parent.tail - b.head).length < 1e-6
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


# ---------------------------------------------------------------- materials

PALETTE = {  # own colours; the retail sprite is only the shape reference
    "skin": "e6bf9a", "hair": "d9c48e", "shirt": "d6cfc0", "vest": "77736c",
    "pants": "3a7773", "belt": "6b4a33", "gold": "e2bd6e", "boots": "5a3a26",
    "strap": "d9892b", "eye": "2a1d14", "mouth": "8e4a3a", "sclera": "f2ede4",
    "iris": "3d5f6b", "glint": "fff8ec", "sole": "2e2219", "brow": "a38c55",
}
# loom maps (art/characters/fighter1.tx.js) per material, and the metres
# one tile covers
LOOM = os.path.normpath(os.path.join(HERE, "..", "..", "..", "art", "characters", "out"))
TEX = {"vest": ("vestTex", 0.4), "pants": ("pantsTex", 0.55), "shirt": ("shirtTex", 0.3),
       "boots": ("leatherTex", 0.12), "belt": ("leatherTex", 0.12), "strap": ("leatherTex", 0.1),
       "hair": ("hairTex", 0.3), "brow": ("hairTex", 0.06), "skin": ("skinTex", 0.15),
       "gold": ("goldTex", 0.08)}
MATS = {}


def mat(name):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        h = PALETTE[name]
        c = tuple((int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1,)
        bsdf = m.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = c
        bsdf.inputs["Roughness"].default_value = 0.8
        if name in TEX:
            loom_maps(m, bsdf, TEX[name][0])
        MATS[name] = m
    return MATS[name]


def loom_maps(m, bsdf, stem):
    """The loom albedo multiplied by the material's colour, and its normal
    map (kiln's way, as tools/blender/models/lib.py does for the kits)."""
    d = os.path.join(LOOM, stem)
    alb = bpy.data.images.load(os.path.join(d, stem + "_albedo.png"), check_existing=True)
    nor = bpy.data.images.load(os.path.join(d, stem + "_normal.png"), check_existing=True)
    nor.colorspace_settings.name = "Non-Color"
    nt = m.node_tree
    ti = nt.nodes.new("ShaderNodeTexImage")
    ti.image = alb
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1
    mul.inputs[7].default_value = bsdf.inputs["Base Color"].default_value
    nt.links.new(ti.outputs["Color"], mul.inputs[6])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = nor
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])


def uv_box(ob):
    """Box-project UVs in rest space, each face at its material's tile size,
    so a texture keeps one scale over the whole figure."""
    me = ob.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uv = me.uv_layers.new(name="UVMap").data
    for p in me.polygons:
        m = me.materials[p.material_index] if me.materials else None
        tile = TEX.get(m.name.split(".")[0], (None, 0.2))[1] if m else 0.2
        n = p.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (co[a] / tile, co[b] / tile)


# ---------------------------------------------------------------- shapes

def blob(bm, centre, radii, sub=3, tag=None, tags=None):
    g = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in g["verts"]:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(centre)
    if tags is not None:
        for f in {f for v in g["verts"] for f in v.link_faces}:
            tags[f] = tag
    return g


def capsule(bm, a, b, ra, rb, steps=6, tag=None, tags=None):
    """A tapering chain of spheres from a to b: the remesh fuses it."""
    a, b = Vector(a), Vector(b)
    for i in range(steps + 1):
        k = i / steps
        r = ra + (rb - ra) * k
        blob(bm, a.lerp(b, k), (r, r, r), sub=2, tag=tag, tags=tags)


def bone(name):
    for n, h, t, _ in BONES:
        if n == name:
            return Vector(h), Vector(t)


def new_object(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


def apply(ob, m):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)


def soften(ob, voxel, ratio, smooth=6):
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = voxel
    apply(ob, m)
    m = ob.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
    m.iterations = smooth
    m.use_only_smooth = True
    apply(ob, m)
    m = ob.modifiers.new("lod", "DECIMATE")
    m.ratio = ratio
    apply(ob, m)
    drop_crumbs(ob)


def drop_crumbs(ob, keep=0.02):
    """Delete loose islands smaller than keep of the mesh: a spike tip the
    voxels cut off would float beside the head."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen, islands = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, isl = [v], []
        seen.add(v)
        while stack:
            a = stack.pop()
            isl.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b not in seen:
                    seen.add(b)
                    stack.append(b)
        islands.append(isl)
    big = max(len(i) for i in islands)
    bmesh.ops.delete(bm, geom=[v for i in islands if len(i) < big * keep for v in i], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def build_body():
    """One fused skin for torso and legs (the arms are apart, build_arm). Each primitive is tagged
    with its part; after the remesh a face takes the part of the nearest
    primitive, and paint_body() turns part + height into a material."""
    bm, tags = bmesh.new(), {}
    T = dict(tags=tags)
    blob(bm, (0, 0.0, 0.62), (0.105, 0.08, 0.08), tag="hips", **T)        # seat of the trousers
    blob(bm, (0, 0.0, 0.72), (0.085, 0.068, 0.09), tag="torso", **T)      # waist
    blob(bm, (0, 0.005, 0.835), (0.1, 0.072, 0.085), tag="torso", **T)    # chest
    capsule(bm, (0, 0, 0.88), (0, 0, 1.03), 0.034, 0.03, 4, tag="neck", **T)
    for S in "LR":
        X = 1 if S == "L" else -1
        capsule(bm, (0.04 * X, 0, 0.89), (0.105 * X, 0, 0.895), 0.047, 0.046, 3, tag="torso", **T)
        # baggy trousers: full at the knee and calf, gathered at the ankle
        capsule(bm, (0.07 * X, 0, 0.6), (0.1 * X, 0, 0.32), 0.07, 0.085, tag="leg", **T)
        capsule(bm, (0.1 * X, 0, 0.32), (0.104 * X, 0.005, 0.18), 0.088, 0.078, 4, tag="leg", **T)
        capsule(bm, (0.104 * X, 0.005, 0.18), (0.105 * X, 0.01, 0.09), 0.066, 0.04, 3, tag="cuff", **T)
        blob(bm, (0.105 * X, -0.035, 0.04), (0.045, 0.085, 0.042), tag="boot", **T)
    bm.faces.ensure_lookup_table()
    src_tags = [tags.get(f) for f in bm.faces]
    tree = BVHTree.FromBMesh(bm)
    ob = new_object("body", bm)
    soften(ob, 0.008, 0.16)
    wrinkle(ob)
    # clean cuts where one material meets the next
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    cuts = [((0, 0, z), (0, 0, 1)) for z in (0.6, 0.645)]
    for co, no in cuts:
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
    bm.to_mesh(ob.data)
    bm.free()
    part = []
    for p in ob.data.polygons:
        _, _, i, _ = tree.find_nearest(p.center)
        part.append(src_tags[i] if i is not None else "torso")
    names = ["skin", "vest", "pants", "belt", "boots", "strap"]
    for n in names:
        ob.data.materials.append(mat(n))
    for p, pt in zip(ob.data.polygons, part):
        z = p.center.z
        if pt == "boot":
            m = "boots"
        elif pt == "cuff":
            m = "pants"
        elif pt in ("leg", "hips"):
            m = "pants" if z < 0.6 else ("belt" if z < 0.645 else "vest")
        elif pt == "torso":
            m = "pants" if z < 0.6 else ("belt" if z < 0.645 else "vest")
        else:
            m = "skin"
        p.material_index = names.index(m)
    return ob


def wrinkle(ob):
    """Folds in the trousers: rings bunched up over the gathered ankle,
    softer diagonal folds behind the knee, nothing above the hips."""
    for v in ob.data.vertices:
        z = v.co.z
        if z > 0.56 or z < 0.07:
            continue
        X = 1 if v.co.x > 0 else -1
        r = Vector((v.co.x - 0.1 * X, v.co.y, 0))
        if r.length < 1e-4:
            continue
        a = math.atan2(r.y, r.x)
        cuff = max(0.0, 1 - (z - 0.1) / 0.16)            # strong over the ankle
        knee = math.exp(-((z - 0.33) / 0.07) ** 2)       # around the knee
        top = min(1.0, (0.56 - z) / 0.08)                # fades out at the belt
        cuff *= min(1.0, max(0.0, (z - 0.09) / 0.05))       # but not the very rim
        d = 0.0045 * cuff * math.sin(z * 260 + 1.5 * math.sin(a * 3)) \
            + 0.004 * knee * math.sin(z * 110 + a * 2) + 0.0025 * math.sin(z * 70 + a * 5)
        v.co += r.normalized() * d * top


def build_arm(S):
    """One arm on its own: hung beside the baggy trousers, a fused skin
    would join sleeve and leg and drag one with the other."""
    X = 1 if S == "L" else -1
    bm = bmesh.new()
    capsule(bm, (0.1 * X, 0, 0.875), *bone(f"upper_arm.{S}")[:1], 0.03, 0.036, 3)
    capsule(bm, *bone(f"upper_arm.{S}"), 0.037, 0.031)
    fh, ft = bone(f"forearm.{S}")
    capsule(bm, fh, ft.lerp(fh, 0.12), 0.031, 0.034)   # the sleeve widens to the wrist
    axis = (ft - fh).normalized()
    blob(bm, ft - axis * 0.012, (0.04, 0.04, 0.04), sub=3)  # a loose cuff
    ob = new_object(f"arm.{S}", bm)
    soften(ob, 0.006, 0.18, 4)
    # open the cuff: cut off its end so the hand comes out of a sleeve
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=ft + axis * 0.012,
                           plane_no=axis, clear_outer=True)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0.84),
                           plane_no=(0, 0, 1))
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.append(mat("shirt"))
    ob.data.materials.append(mat("vest"))
    for p in ob.data.polygons:  # the vest covers the top of the shoulder
        p.material_index = 1 if p.center.z > 0.84 else 0
    return ob


def build_hand(S):
    """A hand with a palm, four fingers a little curled and a thumb, rigid
    on the hand bone; its own fine voxels, so the fingers stay round."""
    X = 1 if S == "L" else -1
    h, t = bone(f"hand.{S}")
    down = (t - h).normalized()
    fwd = Vector((0, -1, 0))
    side = down.cross(fwd).normalized() * X   # the palm faces the leg
    bm = bmesh.new()
    palm = h + down * 0.03
    blob(bm, palm, (0.02, 0.026, 0.026), sub=2)
    blob(bm, h + down * 0.005, (0.017, 0.021, 0.016), sub=2)  # wrist
    for i, (off, ln) in enumerate(((-0.017, 0.042), (-0.006, 0.047), (0.006, 0.045), (0.016, 0.037))):
        base = palm + down * 0.02 + fwd * off
        mid = base + down * ln * 0.55 - side * 0.004
        tip = mid + (down * 0.7 - side * 0.7).normalized() * ln * 0.45
        capsule(bm, base, mid, 0.0075, 0.007, 8)
        capsule(bm, mid, tip, 0.007, 0.0058, 8)
    tb = palm + fwd * -0.022 - side * 0.006
    capsule(bm, tb, tb + (fwd * -0.6 + down * 0.6 - side * 0.5).normalized() * 0.035, 0.009, 0.007, 8)
    ob = new_object(f"hand.{S}", bm)
    soften(ob, 0.0025, 0.12, 3)
    ob.data.materials.append(mat("skin"))
    return ob


def build_flaps():
    """The tunic's tails, front and back, down to mid-thigh over the
    trousers: two curved panels (a skirt would cut through the legs when
    they swing), bent round the hips and flaring a little at the hem."""
    bm = bmesh.new()
    nu, nv = 8, 5
    for sgn in (-1, 1):  # front, back
        grid = []
        for j in range(nv + 1):
            k = j / nv  # 0 at the belt, 1 at the hem
            z = 0.645 - 0.2 * k
            half = 0.085 + 0.02 * k
            row = []
            for i in range(nu + 1):
                x = -half + 2 * half * i / nu
                bulge = 0.085 + 0.025 * k - 0.6 * x * x
                for t in (0, 1):  # outer and inner skin, 1.6 cm apart
                    row.append(bm.verts.new((x, sgn * (bulge - 0.016 * t), z)))
            grid.append(row)
        for j in range(nv):
            for i in range(nu):
                for t in (0, 1):
                    a, b = grid[j][2 * i + t], grid[j][2 * i + 2 + t]
                    c, d = grid[j + 1][2 * i + 2 + t], grid[j + 1][2 * i + t]
                    bm.faces.new((a, b, c, d) if (sgn < 0) != (t == 1) else (d, c, b, a))
        for j in range(nv):  # side edges
            for i in (0, 2 * nu):
                a, b = grid[j][i], grid[j][i + 1]
                c, d = grid[j + 1][i + 1], grid[j + 1][i]
                bm.faces.new((a, b, c, d))
        for i in range(nu):  # hem
            a, b = grid[nv][2 * i], grid[nv][2 * i + 2]
            c, d = grid[nv][2 * i + 3], grid[nv][2 * i + 1]
            bm.faces.new((a, b, c, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_object("flaps", bm)
    ob.data.materials.append(mat("vest"))
    ob.data.materials.append(mat("gold"))
    for p in ob.data.polygons:  # a gold hem
        p.material_index = 1 if p.center.z < 0.47 else 0
    return ob


def ring(bm, c, rx, ry, thick, n=16):
    for i in range(n):
        a = 2 * math.pi * i / n
        blob(bm, (c[0] + rx * math.cos(a), c[1] + ry * math.sin(a), c[2]), (thick, thick, thick * 0.8), sub=1)


def build_feet(S):
    """Straps wound over the gathered trouser cuff (on the shin) and a sole
    under the boot (on the foot)."""
    X = 1 if S == "L" else -1
    bm = bmesh.new()
    for z, r in ((0.095, 0.042), (0.125, 0.05), (0.155, 0.056)):
        ring(bm, (0.105 * X, 0.008, z), r, r * 0.95, 0.012)
    straps = new_object(f"straps.{S}", bm)
    soften(straps, 0.004, 0.2, 2)
    straps.data.materials.append(mat("strap"))
    bm = bmesh.new()
    for k in range(7):
        f = k / 6
        blob(bm, (0.105 * X, 0.03 - 0.13 * f, 0.009), (0.034 - 0.006 * abs(f - 0.4), 0.026, 0.009), sub=2)
    sole = new_object(f"sole.{S}", bm)
    soften(sole, 0.005, 0.25, 2)
    sole.data.materials.append(mat("sole"))
    return straps, sole


def build_buckle():
    bm = bmesh.new()
    blob(bm, (0, -0.088, 0.623), (0.026, 0.008, 0.02), sub=3)
    ob = new_object("buckle", bm)
    ob.data.materials.append(mat("gold"))
    return ob


def build_collar():
    """The gold collar: a thick ring on the shoulders with a knot in front."""
    bm = bmesh.new()
    n = 14
    for i in range(n):
        a = 2 * math.pi * i / n
        blob(bm, (0.065 * math.cos(a), 0.055 * math.sin(a), 0.925 - 0.012 * math.sin(a)), (0.026, 0.026, 0.02), sub=2)
    blob(bm, (0, -0.07, 0.895), (0.03, 0.022, 0.035), sub=2)
    blob(bm, (0, -0.072, 0.85), (0.018, 0.012, 0.03), sub=2)
    ob = new_object("collar", bm)
    soften(ob, 0.006, 0.12, 3)
    ob.data.materials.append(mat("gold"))
    return ob


def build_head():
    bm = bmesh.new()
    blob(bm, (0, 0.005, 1.115), (0.105, 0.1, 0.112), sub=4)    # skull
    blob(bm, (0, -0.035, 1.055), (0.075, 0.07, 0.065), sub=3)  # jaw, a small pointed chin
    blob(bm, (0, -0.105, 1.09), (0.014, 0.014, 0.016), sub=2)  # nose
    for X in (1, -1):
        blob(bm, (0.1 * X, 0.0, 1.1), (0.018, 0.016, 0.03), sub=2)  # ear
    ob = new_object("head", bm)
    soften(ob, 0.006, 0.08, 4)
    ob.data.materials.append(mat("skin"))
    return ob


def build_face():
    """Eyes and mouth sunk into the face: they tell where it looks."""
    bm = bmesh.new()
    parts = {"sclera": [], "iris": [], "eye": [], "glint": [], "brow": [], "mouth": []}
    for X in (1, -1):
        parts["sclera"].append(((0.04 * X, -0.087, 1.115), (0.021, 0.014, 0.027)))
        parts["iris"].append(((0.037 * X, -0.097, 1.112), (0.013, 0.008, 0.019)))
        parts["eye"].append(((0.037 * X, -0.1025, 1.111), (0.007, 0.004, 0.011)))
        parts["glint"].append(((0.032 * X, -0.106, 1.121), (0.0035, 0.002, 0.0045)))
        for k in range(4):  # brow: a short tapering arc, raised at the outer end
            f = k / 3
            parts["brow"].append(((X * (0.022 + 0.04 * f), -0.094 + 0.012 * f * f, 1.152 + 0.008 * f),
                                  (0.009 - 0.002 * f, 0.006, 0.0055 - 0.0015 * f)))
    for k in range(5):  # mouth: a small smirk
        f = k / 4 - 0.5
        parts["mouth"].append(((0.03 * f, -0.094 + 0.01 * f * f, 1.048 + 0.006 * f + 0.004 * f * f),
                               (0.007, 0.004, 0.003)))
    obs = []
    for name, blobs in parts.items():
        bm = bmesh.new()
        for c, r in blobs:
            blob(bm, c, r, sub=2)
        ob = new_object(name, bm)
        ob.data.materials.append(mat(name))
        obs.append(ob)
    return obs


def build_hair():
    """A mop of long spikes: tapering cones from the crown out and up,
    longer at the back and the top, a fringe of short ones over the brow."""
    rng = random.Random(1)
    bm = bmesh.new()
    blob(bm, (0, 0.012, 1.14), (0.112, 0.108, 0.105), sub=3)   # cap over the skull
    spikes = []
    for i in range(34):  # spread over the top and back half of a sphere
        u, v = rng.random(), rng.random()
        th = 2 * math.pi * u
        ph = math.acos(1 - 1.55 * v)        # polar angle from straight up, down past the ears
        d = Vector((math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)))
        if d.y < -0.3 and d.z < 0.6:       # keep the face clear
            continue
        spikes.append((d, 0.1 + 0.05 * rng.random() + 0.04 * max(0, d.y)))
    for x in (-0.06, -0.02, 0.025, 0.065):  # fringe
        spikes.append((Vector((x * 4, -0.9, 0.35)).normalized(), 0.06 + 0.02 * rng.random()))
    for d, ln in spikes:
        base = Vector((0, 0.012, 1.14)) + Vector((d.x * 0.09, d.y * 0.088, d.z * 0.085))
        up = (d + Vector((0, 0.1, 0.12))).normalized()    # out all round, a little up and back
        bend = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 0.6))) * 0.25
        # a clump: the main lock and two thinner ones beside it, each a
        # little curved, so the mop reads as hair and not as horns
        for j, (k_ln, k_r, off) in enumerate(((1.0, 1.0, 0), (0.7, 0.6, 1), (0.6, 0.55, -1))):
            side = up.cross(Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))).normalized()
            b0 = base + side * 0.018 * off
            n = 10
            for k in range(n + 1):
                t = k / n
                r = (0.04 * (1 - t) ** 1.3 + 0.004) * k_r + 0.001
                p = b0 + (up + bend * t) * ln * k_ln * t
                blob(bm, p, (r, r, r), sub=2)
    ob = new_object("hair", bm)
    soften(ob, 0.0035, 0.035, 2)
    ob.data.materials.append(mat("hair"))
    return ob


def skin_to(rig, body, arms, rigid):
    """Body and arms: Blender's automatic (heat) weights, each arm then
    kept to its own chain. rigid = {object: bone} ride one bone each, so
    the face and the collar never smear."""
    for o in [body] + arms:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for o in arms:
        S = o.name[-1]
        own = {"chest", f"shoulder.{S}", f"upper_arm.{S}", f"forearm.{S}", f"hand.{S}"}
        for g in list(o.vertex_groups):
            if g.name not in own:
                o.vertex_groups.remove(g)
        for v in o.data.vertices:
            tot = sum(g.weight for g in v.groups)
            if tot == 0:
                o.vertex_groups[f"shoulder.{S}"].add([v.index], 1.0, "REPLACE")
            for g in v.groups:
                g.weight = g.weight / tot if tot else g.weight
    # the arm bones hang beside the trousers: heat weighting hands them the
    # outside of the thighs, which then fly off with every gesture
    arm_bones = {g.name for g in body.vertex_groups
                 if g.name.split(".")[0] in ("upper_arm", "forearm", "hand")}
    for v in body.data.vertices:
        for g in list(v.groups):
            name = body.vertex_groups[g.group].name
            if name in arm_bones or (name.startswith("shoulder") and v.co.z < 0.85):
                body.vertex_groups[g.group].remove([v.index])
        tot = sum(g.weight for g in v.groups)
        if tot == 0:
            body.vertex_groups["chest" if v.co.z > 0.75 else "hips"].add([v.index], 1.0, "REPLACE")
        else:
            for g in v.groups:
                g.weight /= tot
    for o in arms:
        for p in o.data.polygons:
            p.use_smooth = True
    for o, b in rigid.items():
        vg = o.vertex_groups.new(name=b)
        vg.add(range(len(o.data.vertices)), 1.0, "REPLACE")
        o.parent = rig
        m = o.modifiers.new("rig", "ARMATURE")
        m.object = rig
    # the neck's top ring goes to the head too, so it turns with it
    for v in body.data.vertices:
        if v.co.z > 1.0:
            for g in list(v.groups):
                body.vertex_groups[g.group].remove([v.index])
            body.vertex_groups["head"].add([v.index], 1.0, "REPLACE")
    for o in [body] + list(rigid):
        for p in o.data.polygons:
            p.use_smooth = True


# ---------------------------------------------------------------- poses
# A pose is {bone: rotation}. Turning a bone about an armature axis means
# opposite things for bones pointing up and down, so pose() speaks in body
# terms (lean, arm forward, knee bend) and turns them into rotations.

REST = {}


def _rest(rig):
    for b in rig.data.bones:
        REST[b.name] = b.matrix_local.to_quaternion()


def q_world(name, axis, deg):
    """The local rotation of bone name that turns it by deg about a
    direction given in armature space (rest frame)."""
    r = REST[name]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r


X_AX, Y_AX, Z_AX = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def side(S):
    return 1 if S == "L" else -1


def pose(**kw):
    """Body-language pose → {bone: quaternion}, {bone: location}.

    lean      forwards (+) / back (−), split over hips, spine and chest
    twist     the torso turns to its left (+)
    tilt      the torso leans to its left (+)
    head      looks up (+), head_turn to its left, head_tilt
    arm_<S>   (forward, out, twist): forward raises it in front (90 =
              horizontal, 180 = overhead), out lifts it to the side
    elbow_<S> bend in degrees
    hand_<S>  wrist bend (forward)
    leg_<S>   forward swing of the thigh, knee_<S> bend, foot_<S> toes up (+)
    leg_out_<S> spread
    bob       hips up (+) in units; drop root (z), x/y move the whole body
    fall      the root tips over backwards (death), roll sideways
    """
    g = kw.get
    rot, loc = {}, {}
    lean, twist, tilt = g("lean", 0), g("twist", 0), g("tilt", 0)
    for b, k in (("hips", 0.2), ("spine", 0.4), ("chest", 0.4)):
        q = Quaternion()
        q = Quaternion(Vector(X_AX), math.radians(lean * k)) @ q
        q = Quaternion(Vector(Z_AX), math.radians(twist * k)) @ q
        q = Quaternion(Vector(Y_AX), math.radians(-tilt * k)) @ q
        rot[b] = REST[b].inverted() @ q @ REST[b]
    hq = Quaternion(Vector(X_AX), math.radians(-g("head", 0)))
    hq = Quaternion(Vector(Z_AX), math.radians(g("head_turn", 0))) @ hq
    hq = Quaternion(Vector(Y_AX), math.radians(-g("head_tilt", 0))) @ hq
    rot["head"] = REST["head"].inverted() @ hq @ REST["head"]
    for S in "LR":
        X = side(S)
        fwd, out, tw = (tuple(g(f"arm_{S}", (0, 0, 0))) + (0, 0, 0))[:3]
        q = Quaternion(Vector(X_AX), math.radians(-fwd))
        q = Quaternion(Vector(Y_AX), math.radians(-out * X)) @ q
        q = Quaternion(Vector(Z_AX), math.radians(tw * X)) @ q
        rot[f"upper_arm.{S}"] = REST[f"upper_arm.{S}"].inverted() @ q @ REST[f"upper_arm.{S}"]
        rot[f"forearm.{S}"] = q_world(f"forearm.{S}", X_AX, -g(f"elbow_{S}", 10))
        rot[f"hand.{S}"] = q_world(f"hand.{S}", X_AX, -g(f"hand_{S}", 0))
        lq = Quaternion(Vector(X_AX), math.radians(-g(f"leg_{S}", 0)))
        lq = Quaternion(Vector(Y_AX), math.radians(-g(f"leg_out_{S}", 0) * X)) @ lq
        rot[f"thigh.{S}"] = REST[f"thigh.{S}"].inverted() @ lq @ REST[f"thigh.{S}"]
        rot[f"shin.{S}"] = q_world(f"shin.{S}", X_AX, g(f"knee_{S}", 0))
        rot[f"foot.{S}"] = q_world(f"foot.{S}", X_AX, -g(f"foot_{S}", 0))
    rq = Quaternion(Vector(X_AX), math.radians(-g("fall", 0)))
    rq = Quaternion(Vector(Y_AX), math.radians(g("roll", 0))) @ rq
    rot["root"] = REST["root"].inverted() @ rq @ REST["root"]
    # locations are in the bone's rest frame too
    loc["hips"] = REST["hips"].inverted() @ Vector((0, 0, g("bob", 0)))
    loc["root"] = REST["root"].inverted() @ Vector((g("x", 0), g("y", 0), g("z", 0)))
    return rot, loc


IDLE_ARMS = dict(arm_L=(6, 10), arm_R=(6, 10), elbow_L=18, elbow_R=18, leg_out_L=5, leg_out_R=5)


def keys(rig, name, frames, loop):
    """frames: [(frame, pose kwargs)] → an action pushed to its own NLA
    track, so the exporter writes one glTF animation per action."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, kw in frames:
        set_pose(rig, kw)
        if not kw.get("z") and not kw.get("fall"):  # grounded: soles on the floor
            set_pose(rig, dict(kw, z=-sole(rig)))
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name + ("_loop" if loop else "")
    strip = track.strips.new(track.name, int(frames[0][0]), act)
    strip.name = track.name
    rig.animation_data.action = None


def set_pose(rig, kw):
    rot, loc = pose(**kw)
    for pb in rig.pose.bones:
        pb.rotation_quaternion = rot.get(pb.name, Quaternion())
        pb.location = loc.get(pb.name, Vector())
    bpy.context.view_layer.update()


def sole(rig):
    """Height of the lowest point of either boot (heel under the ankle,
    toe under the foot bone's tail) in the current pose."""
    lo = 1e9
    for S in "LR":
        pb = rig.pose.bones[f"foot.{S}"]
        lo = min(lo, pb.head.z - ANKLE, pb.tail.z - TOE)
    return lo


def mix(a, b, k):
    """Blend two pose dicts (numbers and tuples)."""
    out = {}
    for key in set(a) | set(b):
        va, vb = a.get(key), b.get(key)
        if isinstance(va or vb, tuple):
            va = tuple(va or (0, 0, 0)) + (0, 0, 0)
            vb = tuple(vb or (0, 0, 0)) + (0, 0, 0)
            out[key] = tuple(x + (y - x) * k for x, y in zip(va[:3], vb[:3]))
        else:
            out[key] = (va or 0) + ((vb or 0) - (va or 0)) * k
    return out


def animate(rig):
    _rest(rig)
    base = dict(IDLE_ARMS)

    # idle: breathing, a slow sway, the head looks about a little
    fr = []
    for i in range(0, 49, 6):
        w = 2 * math.pi * i / 48
        fr.append((i, dict(base, bob=-0.008 + 0.008 * math.cos(2 * w), lean=1.5 + 1.5 * math.sin(w),
                           tilt=1.5 * math.sin(w), head=-2 * math.sin(w + 1), head_turn=6 * math.sin(w),
                           arm_L=(4 + 2 * math.sin(w + 0.5), 8), arm_R=(4 + 2 * math.sin(w + 0.5), 8),
                           knee_L=3, knee_R=3)))
    keys(rig, "idle", fr, True)

    # walk: in place, 24 frames a cycle (the game slides the root along)
    fr = []
    for i in range(0, 25, 2):
        w = 2 * math.pi * i / 24
        s = math.sin(w)
        fr.append((i, dict(lean=6, twist=-6 * s, bob=-0.02 + 0.025 * abs(math.cos(w)),
                           leg_L=30 * s, leg_R=-30 * s,
                           knee_L=max(0, -40 * math.cos(w)) + 8, knee_R=max(0, 40 * math.cos(w)) + 8,
                           foot_L=12 * s, foot_R=-12 * s,
                           arm_L=(-28 * s, 8), arm_R=(28 * s, 8),
                           elbow_L=20 + 10 * max(0, -s), elbow_R=20 + 10 * max(0, s),
                           head=-3, head_turn=3 * s)))
    keys(rig, "walk", fr, True)

    # cast: wind-up, the staff hand thrusts forward at frame 12, settles
    wind = dict(base, lean=-8, twist=-20, arm_R=(60, 20, -30), elbow_R=70, arm_L=(10, 20), elbow_L=30,
                leg_L=10, leg_R=-8, knee_L=10, knee_R=14, bob=-0.03, head=4)
    shot = dict(base, lean=14, twist=18, arm_R=(95, 5), elbow_R=5, hand_R=-25, arm_L=(-15, 25), elbow_L=25,
                leg_L=16, leg_R=-14, knee_L=18, knee_R=6, bob=-0.04, head=-6)
    keys(rig, "cast", [(0, base), (7, wind), (12, shot), (18, mix(shot, base, 0.25)), (30, base)], False)

    # melee: overhead swing with the right arm, a step in
    up = dict(base, lean=-10, twist=-25, arm_R=(165, 15), elbow_R=50, arm_L=(30, 15), elbow_L=40,
              leg_L=12, knee_L=12, bob=-0.01, head=6)
    down = dict(base, lean=28, twist=22, arm_R=(40, 0), elbow_R=15, hand_R=20, arm_L=(-25, 20), elbow_L=30,
                leg_L=30, knee_L=35, leg_R=-15, knee_R=10, y=-0.08, bob=-0.07, head=-10)
    keys(rig, "melee", [(0, base), (8, up), (12, down), (16, mix(down, base, 0.2)), (24, base)], False)

    # hit: knocked back, then recovers (the game adds the flash and shake)
    hit = dict(base, lean=-18, head=-22, head_tilt=8, arm_L=(35, 30), arm_R=(30, 35), elbow_L=40, elbow_R=40,
               knee_L=12, knee_R=12, bob=-0.03, y=0.05)
    keys(rig, "hit", [(0, base), (3, hit), (8, mix(hit, base, 0.6)), (15, base)], False)

    # die: knees give, falls on its back, a small bounce, still
    sag = dict(base, lean=20, head=25, arm_L=(-10, 25), arm_R=(-10, 25), elbow_L=30, elbow_R=30,
               knee_L=45, knee_R=40, leg_L=25, leg_R=20, bob=-0.12)
    flat = dict(lean=-5, head=-15, head_turn=25, arm_L=(-20, 75), arm_R=(-10, 60), elbow_L=25, elbow_R=40,
                leg_L=10, leg_R=-5, knee_L=20, knee_R=8, fall=88, z=0.06, y=0.1)
    bounce = dict(flat, fall=80, z=0.09)
    keys(rig, "die", [(0, base), (6, mix(base, sag, 0.6)), (12, sag), (22, flat), (26, bounce),
                      (30, flat), (40, flat)], False)

    # jump (also teleport): crouch, up, land, settle; z is height in cells
    crouch = dict(base, lean=18, bob=-0.12, leg_L=40, leg_R=40, knee_L=70, knee_R=70, foot_L=-25, foot_R=-25,
                  arm_L=(-30, 15), arm_R=(-30, 15), elbow_L=20, elbow_R=20, head=-10)
    air = dict(base, lean=-4, z=0.45, leg_L=20, leg_R=8, knee_L=40, knee_R=30, arm_L=(70, 35), arm_R=(70, 35),
               elbow_L=20, elbow_R=20, head=5)
    land = dict(crouch, bob=-0.09)
    keys(rig, "jump", [(0, base), (6, crouch), (12, air), (16, dict(air, z=0.35)), (20, dict(base, z=0.0)),
                       (23, land), (32, base)], False)

    # celebrate: both fists up and two hops
    joy = dict(lean=-8, head=12, arm_L=(150, 35), arm_R=(150, 35), elbow_L=20, elbow_R=20, knee_L=5, knee_R=5)
    hop = dict(joy, z=0.16, knee_L=25, knee_R=25, leg_L=15, leg_R=15, arm_L=(165, 25), arm_R=(165, 25))
    dip = dict(joy, bob=-0.06, knee_L=30, knee_R=30, leg_L=20, leg_R=20, lean=4)
    keys(rig, "celebrate", [(0, base), (6, dip), (11, hop), (16, dip), (21, hop), (26, dip), (36, base)], False)

    # carry: holds someone over its head (the game parents the carried one
    # to the hands); loops while carrying
    fr = []
    for i in range(0, 25, 6):
        w = 2 * math.pi * i / 24
        fr.append((i, dict(lean=-4 + math.sin(w), bob=-0.03 + 0.01 * math.cos(w), arm_L=(160, 18), arm_R=(160, 18),
                           elbow_L=40, elbow_R=40, hand_L=-30, hand_R=-30, knee_L=12, knee_R=12, head=8)))
    keys(rig, "carry", fr, True)

    # throw: from the carry pose, heave forward
    back = dict(lean=-16, bob=-0.06, arm_L=(180, 12), arm_R=(180, 12), elbow_L=55, elbow_R=55,
                knee_L=18, knee_R=18, head=12, leg_R=-10)
    toss = dict(lean=24, arm_L=(100, 15), arm_R=(100, 15), elbow_L=5, elbow_R=5, leg_L=25, knee_L=25,
                leg_R=-15, y=-0.05, bob=-0.05, head=-8)
    keys(rig, "throw", [(0, fr[0][1]), (6, back), (11, toss), (16, mix(toss, base, 0.3)), (26, base)], False)


# ---------------------------------------------------------------- export

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    rig = build_armature()
    body = build_body()
    rigid = {o: "head" for o in build_face()}
    rigid.update({build_head(): "head", build_hair(): "head", build_collar(): "chest",
                  build_flaps(): "hips", build_buckle(): "hips"})
    for S in "LR":
        straps, sole = build_feet(S)
        rigid.update({build_hand(S): f"hand.{S}", straps: f"shin.{S}", sole: f"foot.{S}"})
    for o, b in rigid.items():  # the retail head is a third of the height
        if b == "head":
            for v in o.data.vertices:
                v.co = Vector((0, 0, 1.0)) + (v.co - Vector((0, 0, 1.0))) * HEAD_SCALE
    arms = [build_arm("L"), build_arm("R")]
    for o in [body] + arms + list(rigid):
        uv_box(o)
    skin_to(rig, body, arms, rigid)
    animate(rig)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True)
    tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in [body] + arms + list(rigid)}
    print(f"[fighter1] {OUT}: {len(BONES)} bones, {sum(tris.values())} tris {tris}, "
          f"{len(rig.animation_data.nla_tracks)} animations")


main()
