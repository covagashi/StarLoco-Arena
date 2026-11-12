"""S35c: the coach's clothes that bend with the body (torso, trousers,
skirt, boots), made from the coach figure itself, no Meshy.

    blender -b -P tools/blender/characters/coach_garment.py -- <coach.glb> <garments.json> <out_dir> [--only=a,b]

For each garment in garments.json ({"<name>": {"kind": …, …}}):

- torso / pants / boots: the body's own faces in the garment's region
  (cut clean at the hems with planes), pushed out along their normals by
  `ease` and given `thick`ness. The faces keep the body's skin weights, so
  the cloth bends exactly as the skin under it and never lets it through.
- skirt: a tube from the waist down, as wide as the hips and flaring, with
  its weights going from the hips at the belt to half the nearest thigh at
  the hem (it follows the legs, less).

Colour is flat, by bands along the garment (`bands`: [[from, to, "#hex"]],
0 at the top hem and 1 at the bottom one; the rest is `base`), one material
per colour, as the kiln pieces have: toon.gd outlines and shades them.

The garment is exported with the coach's rig (no animations) to
<out_dir>/<name>.glb; fighter3d.gd puts its mesh on the figure's own
skeleton.
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"only": ""}
pos = []
for a in argv:
    if a.startswith("--") and "=" in a:
        k, v = a[2:].split("=", 1)
        OPT[k] = v
    else:
        pos.append(a)
SRC, RECIPES, OUT_DIR = pos[:3]

DEFAULTS = {
    "torso": {"ease": 0.012, "thick": 0.006, "top": 0.0, "bottom": 0.0, "sleeve": 0.45},
    "pants": {"ease": 0.012, "thick": 0.006, "top": 0.0, "hem": 0.95, "flare": 0.0, "bag": 0.0},
    "boots": {"ease": 0.016, "thick": 0.007, "top": 0.25, "cuff": 0.0},
    "skirt": {"ease": 0.02, "thick": 0.006, "top": 0.0, "length": 0.45, "flare": 0.06, "sides": 20, "rings": 6},
}


def hexcol(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c] + [1.0]


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC)
    body = rig = None
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE":
            rig = o
        elif o.type == "MESH" and o.vertex_groups:
            body = o
        elif o.type == "MESH":
            bpy.data.objects.remove(o)   # the importer's bone shape
    for o in bpy.data.objects:
        if o.animation_data:
            o.animation_data_clear()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    rig.data.pose_position = "REST"
    return body, rig


class Body:
    """Landmarks of the coach in rest pose, from its bones."""

    def __init__(self, body, rig):
        self.ob = body
        self.bones = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones}
        B = self.bones
        self.waist = (B["hips"][1].z + B["spine"][0].z) / 2 + 0.02     # the belt line
        self.crotch = B["thigh.L"][0].z
        self.neck = B["neck"][0].z + 0.005
        self.ankle = (B["foot.L"][0].z + B["foot.R"][0].z) / 2
        self.knee = (B["shin.L"][0].z + B["shin.R"][0].z) / 2
        self.names = [g.name for g in body.vertex_groups]


def dominant(v, deform, names):
    best, w = "", 0.0
    for gi, gw in v[deform].items():
        if gw > w:
            best, w = names[gi], gw
    return best


def cut(bm, co, no):
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)


def keep_faces(bm, keep_vert):
    """Delete every face with a vertex outside the garment, then loose bits."""
    kv = {v: keep_vert(v) for v in bm.verts}
    gone = [f for f in bm.faces if not all(kv[v] for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[e for e in bm.edges if not e.link_faces], context="EDGES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # crumbs: islands under 2% of the garment (a strand of hair, a finger tip)
    seen, islands = set(), []
    for f in bm.faces:
        if f in seen:
            continue
        isl, todo = [], [f]
        seen.add(f)
        while todo:
            g = todo.pop()
            isl.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h)
                        todo.append(h)
        islands.append(isl)
    total = len(bm.faces)
    crumbs = [f for isl in islands if len(isl) < total * 0.02 for f in isl]
    bmesh.ops.delete(bm, geom=crumbs, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")


def push(bm, ease_of, out_of):
    """Out along the (smoothed) vertex normal: `ease_of(v)` metres. Meshy's
    normals are not always outward (an inward one sank the cloth under the
    skin), so each points away from its bone (`out_of(v)`: the closest
    point on the bone the vertex follows most)."""
    bm.normal_update()
    raw = {}
    for v in bm.verts:
        n = v.normal.copy()
        away = v.co - out_of(v)
        if away.length > 1e-6:
            away.normalize()
            if n.length < 1e-6 or n.dot(away) < 0.2:
                n = away if n.length < 1e-6 or n.dot(away) < -0.2 else (n + away).normalized()
        raw[v] = n
    for v in bm.verts:
        n = raw[v] * 2
        for e in v.link_edges:
            n += raw[e.other_vert(v)]
        n = n.normalized() if n.length > 1e-6 else Vector((0, 0, 1))
        v.co += n * ease_of(v)


def closest_on(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return a + ab * t


def from_body(K, r):
    """torso / pants / boots: the body's faces in the region."""
    kind = r["kind"]
    B = K.bones
    bm = bmesh.new()
    bm.from_mesh(K.ob.data)
    # the GLB splits the skin at every UV seam (425 islands): weld it back,
    # or the cloth cracks along the seams and the crumbs pass eats it
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    deform = bm.verts.layers.deform.verify()
    up = Vector((0, 0, 1))
    if kind == "torso":
        top = K.neck - r["top"]
        bottom = K.waist - 0.04 - r["bottom"]
        cut(bm, Vector((0, 0, top)), up)
        cut(bm, Vector((0, 0, bottom)), up)
        sleeve = {}
        for s in ".L", ".R":
            # the sleeve ends `sleeve` down the arm: upper arm 0–1, forearm 1–2
            t = r["sleeve"]
            a, b = B["upper_arm" + s] if t <= 1 else B["forearm" + s]
            f = t if t <= 1 else t - 1
            at = a.lerp(b, f)
            sleeve[s] = (at, (b - a).normalized())
            cut(bm, at, (b - a).normalized())
        arm_bones = {"upper_arm", "forearm", "hand"}

        def keep(v):
            if v.co.z > top + 1e-4 or v.co.z < bottom - 1e-4:
                return False
            d = dominant(v, deform, K.names)
            if d.split(".")[0] in ("head", "neck"):
                return False
            if d.split(".")[0] in arm_bones or d.startswith("shoulder"):
                at, n = sleeve[".L" if v.co.x > 0 else ".R"]
                return (v.co - at).dot(n) <= 1e-4
            return d in ("hips", "spine", "chest", "root") or d.startswith("thigh")
        span = (top, bottom)
    elif kind == "pants":
        top = K.waist - r["top"]
        hem = top - (top - K.ankle) * r["hem"]
        cut(bm, Vector((0, 0, top)), up)
        cut(bm, Vector((0, 0, hem)), up)

        def keep(v):
            if v.co.z > top + 1e-4 or v.co.z < hem - 1e-4:
                return False
            d = dominant(v, deform, K.names).split(".")[0]
            return d in ("hips", "spine", "thigh", "shin", "foot", "root")
        span = (top, hem)
    else:   # boots
        top = K.ankle + (K.knee - K.ankle) * r["top"]
        cut(bm, Vector((0, 0, top)), up)

        def keep(v):
            if v.co.z > top + 1e-4:
                return False
            d = dominant(v, deform, K.names).split(".")[0]
            return d in ("shin", "foot")
        span = (top, -0.01)
    for t0, t1, _ in r.get("bands", []):   # clean colour edges
        for t in (t0, t1):
            if 0 < t < 1:
                cut(bm, Vector((0, 0, span[0] + (span[1] - span[0]) * t)), up)
    keep_faces(bm, keep)

    def tpar(co):
        return (span[0] - co.z) / (span[0] - span[1])

    def ease(v):
        t = min(max(tpar(v.co), 0.0), 1.0)
        e = r["ease"]
        if kind == "pants":
            e += r["bag"] * math.sin(math.pi * min(t / 0.85, 1.0)) + r["flare"] * t * t
        if kind == "boots":
            e += r["cuff"] * max(0.0, (0.25 - t) / 0.25)
        return e
    def out_of(v):
        a, b = B.get(dominant(v, deform, K.names), B["spine"])
        if dominant(v, deform, K.names) in ("hips", "spine", "chest", "root"):
            a, b = B["hips"][0], B["chest"][1]   # the trunk's axis
        return closest_on(v.co, a, b)
    push(bm, ease, out_of)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, tpar


def skirt(K, r):
    """A tube round the hips from the belt down, flaring; skinned to the
    hips at the top and half the nearest thigh at the hem."""
    me = K.ob.data
    B = K.bones
    top = K.waist - r["top"]
    hem = top - (top - K.ankle) * r["length"]
    names = K.names
    gi = {n: i for i, n in enumerate(names)}
    # the body's outline at a height: farthest vertex from the centre per
    # angle sector, among the trunk and the thighs
    trunk = {gi[n] for n in ("hips", "spine", "thigh.L", "thigh.R") if n in gi}
    cx = 0.0
    cy = (B["hips"][0].y + B["thigh.L"][0].y) / 2
    sides, rings = int(r["sides"]), int(r["rings"])

    def outline(z, band=0.03):
        rad = [0.0] * sides
        for v in me.vertices:
            if abs(v.co.z - z) > band:
                continue
            if not any(g.group in trunk and g.weight > 0.3 for g in v.groups):
                continue
            dx, dy = v.co.x - cx, v.co.y - cy
            a = math.atan2(dy, dx) % (2 * math.pi)
            k = int(a / (2 * math.pi) * sides) % sides
            rad[k] = max(rad[k], math.hypot(dx, dy))
        m = max(rad) or 0.1
        rad = [x if x > 0 else m for x in rad]
        return [max(rad[i], (rad[i - 1] + rad[(i + 1) % sides]) / 2) for i in range(sides)]

    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    widest = [0.0] * sides
    grid = []
    for j in range(rings + 1):
        t = j / rings
        z = top + (hem - top) * t
        o = outline(min(z, top - 0.01))
        widest = [max(a, b) for a, b in zip(widest, o)]   # never narrower going down
        row = []
        for i in range(sides):
            a = (i + 0.5) / sides * 2 * math.pi
            rr = widest[i] + r["ease"] + r["flare"] * t
            v = bm.verts.new((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
            x = math.cos(a)
            follow = 0.5 * t * t
            lean = min(abs(x) * 1.6, 1.0) * (1 if x > 0 else -1)   # front and back follow both legs
            v[deform][gi["hips"]] = 1.0 - follow
            v[deform][gi["thigh.L"]] = follow * (0.5 + 0.5 * lean)
            v[deform][gi["thigh.R"]] = follow * (0.5 - 0.5 * lean)
            row.append(v)
        grid.append(row)
    for j in range(rings):
        for i in range(sides):
            a, b = grid[j][i], grid[j][(i + 1) % sides]
            c, d = grid[j + 1][(i + 1) % sides], grid[j + 1][i]
            bm.faces.new((a, d, c, b))
    bm.normal_update()
    for f in bm.faces:   # outward
        if f.normal.dot(f.calc_center_median() - Vector((cx, cy, f.calc_center_median().z))) < 0:
            f.normal_flip()

    def tpar(co):
        return (top - co.z) / (top - hem)
    return bm, tpar


def colour(bm, tpar, r, ob):
    cols = [r["base"]] + [b[2] for b in r.get("bands", [])]
    order = list(dict.fromkeys(cols))
    for h in order:
        m = bpy.data.materials.new("cloth_" + h.lstrip("#"))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = hexcol(h)
        bsdf.inputs["Roughness"].default_value = 0.9
        ob.data.materials.append(m)
    for f in bm.faces:
        t = tpar(f.calc_center_median())
        h = r["base"]
        for t0, t1, c in r.get("bands", []):
            if t0 <= t <= t1:
                h = c
        f.material_index = order.index(h)


def build(K, rig, name, r):
    r = {**DEFAULTS[r["kind"]], **r}
    bm, tpar = skirt(K, r) if r["kind"] == "skirt" else from_body(K, r)
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for n in K.names:
        ob.vertex_groups.new(name=n)
    colour(bm, tpar, r, ob)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob.parent = rig
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = r["thick"]
    sol.offset = -1.0      # inward, toward the skin it already clears
    sol.use_rim = True
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier="thick")
    arm = ob.modifiers.new("rig", "ARMATURE")
    arm.object = rig
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, name + ".glb")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True,
                              export_animations=False, export_def_bones=False, export_yup=True)
    tri = sum(len(p.vertices) - 2 for p in me.polygons)
    print("[garment] %s %s tris=%d kb=%d" % (out, r["kind"], tri, os.path.getsize(out) // 1024))
    bpy.data.objects.remove(ob)


def main():
    body, rig = load()
    K = Body(body, rig)
    with open(RECIPES) as f:
        recipes = {k: v for k, v in json.load(f).items() if not k.startswith("_")}
    only = [x for x in OPT["only"].split(",") if x]
    for name, r in recipes.items():
        if only and name not in only:
            continue
        build(K, rig, name, r)


main()
