"""S35c: the coach's clothes that bend with the body (torso, trousers,
skirt, boots), made from the coach figure itself, no Meshy.

    blender -b -P tools/blender/characters/coach_garment.py -- <coach.glb> <garments.json> <out_dir> [--only=a,b]

For each garment in garments.json ({"<name>": {"kind": …, …}}):

- torso / pants / boots: the body's own faces in the garment's region
  (cut clean at the hems with planes), pushed out along their normals by
  `ease`; one shell (a sleeve or a trouser leg has the body inside, so a
  `thick`ness only doubled the triangles). The faces keep the body's skin weights, so
  the cloth bends exactly as the skin under it and never lets it through.
- mark: a tattoo or scars, the skin round a point with an emblem on it
  (see mark()).
- skirt: a tube from the waist down, as wide as the hips and flaring, with
  its weights going from the hips at the belt to half the nearest thigh at
  the hem (it follows the legs, less).

Colour is flat, `base` with patterns on top (bands, stripes, side and
front stripes, harlequin diamonds, patches, one leg in another colour: see
paint()), along the garment from 0 at the top hem to 1 at the bottom one;
one material per colour, as the kiln pieces have: toon.gd outlines and
shades them. `puff` ([[from, to, metres]]) bulges the cloth out.

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
from mathutils import Matrix, Vector

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
# the marks' emblems (tools/art/mark_emblems.py), beside the garments' folder
MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(OUT_DIR))), "models")
MARKS_DIR = OPT.get("marks") or os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(OUT_DIR))), "marks")

DEFAULTS = {
    "torso": {"ease": 0.012, "thick": 0.0, "top": 0.0, "bottom": 0.0, "sleeve": 0.45},
    "pants": {"ease": 0.012, "thick": 0.0, "top": 0.0, "start": 0.0, "hem": 0.95, "flare": 0.0, "bag": 0.0},
    "boots": {"ease": 0.016, "thick": 0.0, "top": 0.25, "cuff": 0.0, "smooth": 24},
    "mark": {"ease": 0.003, "thick": 0.0, "size": 0.09},
    "skirt": {"ease": 0.02, "teeth": 0.0, "thick": 0.006, "top": 0.0, "length": 0.45, "flare": 0.06, "sides": 20, "rings": 6},
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
        bottom = K.waist - r["bottom"]   # at the belt; + longer, - a crop top
        cut(bm, Vector((0, 0, top)), up)
        cut(bm, Vector((0, 0, bottom)), up)
        sleeve = {}
        for s in ".L", ".R":
            # the sleeve ends `sleeve` down the arm: upper arm 0–1, forearm
            # 1–2; below 0 it is cut into the shoulder (sleeveless)
            t = r["sleeve"]
            a, b = B["upper_arm" + s] if t <= 1 else B["forearm" + s]
            f = t if t <= 1 else t - 1
            at = a.lerp(b, f)
            sleeve[s] = (at, (b - a).normalized())
            cut(bm, at, (b - a).normalized())
        arm_bones = {"upper_arm", "forearm", "hand"}

        def keep(v):
            if v.co.z > top + 1e-4:
                return False
            d = dominant(v, deform, K.names)
            if d.split(".")[0] in ("head", "neck"):
                return False
            if d.split(".")[0] in arm_bones or d.startswith("shoulder"):
                # a long sleeve hangs below the hem: only its own cut ends it
                at, n = sleeve[".L" if v.co.x > 0 else ".R"]
                return (v.co - at).dot(n) <= 1e-4
            if v.co.z < bottom - 1e-4:
                return False
            return d in ("hips", "spine", "chest", "root") or d.startswith("thigh")
        span = (top, bottom)
    elif kind == "pants":
        # start / hem: how far down from the belt to the ankle (0–1) the
        # garment begins and ends (greaves start at the knee)
        top = K.waist - (K.waist - K.ankle) * r["start"] - r["top"]
        hem = K.waist - (K.waist - K.ankle) * r["hem"]
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
    edges = [t for t0, t1, _ in r.get("bands", []) for t in (t0, t1)]
    for st in r.get("stripes", []):
        x = st["from"]
        while x < st.get("to", 1.0) - 1e-6:
            edges.append(x)
            x += st["every"]
    for p in r.get("puff", []):
        edges += [p[0], p[1]]
    for t in edges:   # clean colour edges
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
        for t0, t1, extra in r.get("puff", []):   # a bulge: puffed shorts, fur at the hem
            if t0 < t < t1:
                e += extra * math.sin(math.pi * (t - t0) / (t1 - t0))
        return e
    def out_of(v):
        a, b = B.get(dominant(v, deform, K.names), B["spine"])
        if dominant(v, deform, K.names) in ("hips", "spine", "chest", "root"):
            a, b = B["hips"][0], B["chest"][1]   # the trunk's axis
        return closest_on(v.co, a, b)
    push(bm, ease, out_of)
    if kind == "boots" and r["smooth"] > 0:
        # the male coach is barefoot: a boot copied from his foot had toes.
        # Relax the foot (below the ankle, the hem left alone), letting each
        # vertex move only outwards: the gaps between the toes fill in and
        # no toe tip comes through
        bm.normal_update()
        foot = [v for v in bm.verts if tpar(v.co) > 0.55 and not v.is_boundary]
        home = {v: (v.co.copy(), v.normal.copy()) for v in foot}
        for _ in range(int(r["smooth"])):
            bmesh.ops.smooth_vert(bm, verts=foot, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
            for v in foot:
                co, n = home[v]
                inward = (v.co - co).dot(n)
                if inward < 0:
                    v.co -= n * inward
    # one shell, drawn from outside only: every face faces away from its bone
    bm.normal_update()
    for f in bm.faces:
        c = f.calc_center_median()
        if f.normal.dot(c - out_of(f.verts[0])) < 0:
            f.normal_flip()
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

    def reach(i):
        """How long column i runs, of the skirt's length: `teeth` (a hem
        cut in points, every other column `depth` longer) and `flaps`
        (a panel hanging longer: [{ang, width, extra}], ang as in where())."""
        a = math.degrees((i + 0.5) / sides * 2 * math.pi)
        k = 1.0
        if r.get("teeth") and i % 2 == 0:
            k += r["teeth"]
        for fl in r.get("flaps", []):
            off = abs((a - fl["ang"] + 180) % 360 - 180)
            if off <= fl["width"] / 2:
                k += fl["extra"] * (1 - 0.3 * off / max(fl["width"] / 2, 1e-6))
        return k

    bm = bmesh.new()
    deform = bm.verts.layers.deform.verify()
    widest = [0.0] * sides
    grid = []
    for j in range(rings + 1):
        t = j / rings
        o = outline(min(top + (hem - top) * t, top - 0.01))
        widest = [max(a, b) for a, b in zip(widest, o)]   # never narrower going down
        row = []
        for i in range(sides):
            a = (i + 0.5) / sides * 2 * math.pi
            tl = t * reach(i)
            z = top + (hem - top) * tl
            rr = widest[i] + r["ease"] + r["flare"] * min(tl, 1.0)
            v = bm.verts.new((cx + rr * math.cos(a), cy + rr * math.sin(a), z))
            x = math.cos(a)
            follow = 0.5 * min(tl, 1.0) ** 2
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


def where(K, kind, co):
    """(side, angle) of a point round its limb or the trunk: side "L" or
    "R" (+X is the left), angle in degrees, 0 on the outside (the trunk's
    left), -90 at the front (-Y), 90 at the back."""
    B = K.bones
    side = "L" if co.x > 0 else "R"
    if kind in ("pants", "boots"):
        a, b = B["thigh." + side][0], B["shin." + side][1]
        if kind == "boots" or co.z < b.z:
            a, b = B["shin." + side][0], B["foot." + side][0]
    else:
        a, b = B["hips"][0], B["chest"][1]
        a, b = a.copy(), b.copy()
        a.x = b.x = 0.0
    d = co - closest_on(co, a, b)
    out = 1.0 if (side == "L" or kind not in ("pants", "boots")) else -1.0
    return side, math.degrees(math.atan2(d.y, d.x * out))


def paint(K, kind, r, t, co):
    """The colour of the cloth at `co` (t along the garment), from `base`
    and the patterns, later ones on top:
      bands   [[t0, t1, col]]                 across the garment
      stripes [{from, to, every, col}]        repeating bands
      side    [{width, col, from?, to?}]      down the outside of each leg
                                              (the sides, on a torso)
      front   [{width, col, from?, to?}]      down the front
      diamonds {cols: [a, b], n, rows, from?, to?}   harlequin
      patches [{leg?, t, ang, r, col}]        a round spot (r in t units)
      leg     {"R": col}                      one leg another colour
      flap_col                                a skirt's flaps, below the hem"""
    side, ang = where(K, kind, co)
    h = r.get("leg", {}).get(side, r["base"])
    dia = r.get("diamonds")
    if dia and dia.get("from", 0) <= t <= dia.get("to", 1):
        u = ang / 360 * dia["n"] + t * dia["rows"]
        v = ang / 360 * dia["n"] - t * dia["rows"]
        h = dia["cols"][(math.floor(u) + math.floor(v)) % 2]
    for t0, t1, c in r.get("bands", []):
        if t0 <= t <= t1:
            h = c
    if r.get("flap_col") and t > 1.0:   # a skirt's flap, below the hem
        h = r["flap_col"]
    for st in r.get("stripes", []):
        if st["from"] <= t <= st.get("to", 1.0) and int((t - st["from"]) / st["every"]) % 2 == 0:
            h = st["col"]
    for key, at in (("side", 0.0), ("front", -90.0)):
        for st in r.get(key, []):
            off = abs((ang - at + 180) % 360 - 180)
            if key == "side" and kind not in ("pants", "boots"):
                off = min(off, abs((ang - 180 + 180) % 360 - 180))   # both sides of the trunk
            if off <= st["width"] / 2 and st.get("from", 0) <= t <= st.get("to", 1):
                h = st["col"]
    for p in r.get("patches", []):
        if p.get("leg", side) != side:
            continue
        da = abs((ang - p["ang"] + 180) % 360 - 180) / 360
        if math.hypot(t - p["t"], da * 1.2) <= p["r"]:
            h = p["col"]
    return h


def along_arm(K, co):
    """How far down the arm a point is, in the units of a torso's `sleeve`
    (0 the shoulder joint, 1 the elbow, 2 the wrist)."""
    B = K.bones
    side = ".L" if co.x > 0 else ".R"
    a, b = B["upper_arm" + side]
    c, d = B["forearm" + side]
    t1 = (co - a).dot(b - a) / max((b - a).length_squared, 1e-9)
    if t1 <= 1.0:
        return max(t1, 0.0)
    return 1.0 + min(max((co - c).dot(d - c) / max((d - c).length_squared, 1e-9), 0.0), 1.0)


def colour(K, bm, tpar, r, ob):
    """Paint every face (paint()); on a torso the arm's faces are the
    sleeve: `sleeve_col` (else the body's colour) and a cuff at its end
    (`cuff`: [length, col], in sleeve units). `open` ([{width, from?, to?}])
    cuts the front open (a vest, an open jacket)."""
    deform = bm.verts.layers.deform.verify()
    faces, gone = [], []
    for f in bm.faces:
        c = f.calc_center_median()
        t = tpar(c)
        if r["kind"] == "torso":
            _, ang = where(K, "torso", c)
            if any(abs((ang + 270) % 360 - 180) <= o["width"] / 2 and o.get("from", 0) <= t <= o.get("to", 1)
                   for o in r.get("open", [])):
                gone.append(f)
                continue
        h = paint(K, r["kind"], r, t, c)
        if r["kind"] == "torso":
            d = dominant(f.verts[0], deform, K.names)
            if d.startswith(("upper_arm", "forearm")):
                h = r.get("sleeve_col", h)
                cuff = r.get("cuff")
                if cuff and along_arm(K, c) >= r["sleeve"] - cuff[0]:
                    h = cuff[1]
        faces.append((f, h))
    if gone:
        bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    order = list(dict.fromkeys([r["base"]] + [h for _, h in faces]))
    for h in order:
        m = bpy.data.materials.new("cloth_" + h.lstrip("#"))
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = hexcol(h)
        bsdf.inputs["Roughness"].default_value = 0.9
        ob.data.materials.append(m)
    for f, h in faces:
        f.material_index = order.index(h)


MARK_DIRS = {"out": None, "front": Vector((0, -1, 0)), "back": Vector((0, 1, 0)),
             "left": Vector((1, 0, 0)), "right": Vector((-1, 0, 0)), "up": Vector((0, 0, 1))}


def skin_point(K, bm, at):
    """The point on the skin for `at` {bone, t (along it), dir (out: away
    from the body's middle; front, back, left, right)}: (hit, d, core, own,
    bone) — the skin point, the direction, the point on the bone, the
    vertices of the bone and its neighbours (a hand hanging beside the
    thigh is not the thigh), the bone the point follows. `bm` is the welded
    body."""
    B = K.bones
    a, b = B[at["bone"]]
    core = a.lerp(b, at.get("t", 0.5))
    d = MARK_DIRS[at.get("dir", "out")]
    if d is None:
        d = Vector((1 if core.x > 0 else -1, 0, 0))
    deform = bm.verts.layers.deform.verify()
    side = at["bone"][-2:] if at["bone"][-2:] in (".L", ".R") else ""
    stem = at["bone"].split(".")[0]
    family = {at["bone"]} | {n + side for n in {
        "thigh": ["shin"], "shin": ["thigh", "foot"], "foot": ["shin"], "upper_arm": ["shoulder", "forearm"],
        "forearm": ["upper_arm", "hand"]}.get(stem, [])}
    if stem == "thigh":
        family.add("hips")
    if not side:
        family |= {"hips", "spine", "chest", "neck", "shoulder.L", "shoulder.R"}
    own = {v for v in bm.verts if dominant(v, deform, K.names) in family}
    # the vertex furthest along d among those near the ray
    near = [v for v in own if ((v.co - core) - d * (v.co - core).dot(d)).length < 0.03 and (v.co - core).dot(d) > 0]
    # (none near it: the bone's own vertex furthest that way, never a point
    # in the air — the toes stop short of the foot bone's tail)
    pool = near or [v for v in own if dominant(v, deform, K.names) == at["bone"]] or list(own)
    best = max(pool, key=lambda v: (v.co - core).dot(d)) if pool else None
    hit = best.co.copy() if best else core
    bone = dominant(best, deform, K.names) if best else at["bone"]
    return hit, d, core, own, bone



def mark(K, r, ob):
    """A mark (a tattoo, scars): the skin round a point, `ease` off it, the
    emblem (art/equipment/out/marks/<emblem>.png, tools/art/mark_emblems.py)
    projected flat on it, `size` metres across. The point: `at` {bone, t
    (along it), dir (out: away from the body's middle; front, back, left,
    right)}, taken on the skin."""
    bm = bmesh.new()
    bm.from_mesh(K.ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.normal_update()
    hit, d, core, own, _ = skin_point(K, bm, r["at"])
    half = r["size"] / 2
    # every face reaching into the emblem's square (the corners too), on
    # the side facing d (not the far side of a thin arm)
    gone = [f for f in bm.faces
            if min(max(abs((v.co - hit).dot(e)) for e in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))))
                   for v in f.verts) > half * 1.05 or f.normal.dot(d) < 0.2 or not all(v in own for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    up = Vector((0, 0, 1))
    up = (up - d * up.dot(d)).normalized()
    right = up.cross(d)   # seen from outside, +u to the viewer's right

    def out_of(v):
        return core
    push(bm, lambda v: r["ease"], out_of)
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        if f.normal.dot(d) < 0:
            f.normal_flip()
        for lp in f.loops:
            q = lp.vert.co - hit
            lp[uv].uv = (0.5 - q.dot(right) / r["size"], 0.5 + q.dot(up) / r["size"])
    img = bpy.data.images.load(os.path.join(MARKS_DIR, r["emblem"] + ".png"))
    m = bpy.data.materials.new("mark_" + r["emblem"])   # toon.gd: cut by its alpha, no outline
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.extension = "CLIP"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 1.0
    ob.data.materials.append(m)
    return bm


def limb_radius(K, bm, own, core, axis):
    """Median distance of the limb's vertices round `core` to its axis."""
    rs = sorted(((v.co - core) - axis * (v.co - core).dot(axis)).length for v in own
                if abs((v.co - core).dot(axis)) < 0.02)
    return rs[len(rs) // 2] if rs else 0.05


def add_extras(K, ob, r):
    """The garment's rigid parts (`extras`), kiln models
    (art/equipment/coach_extras.kx.js, out/models/<model>.glb) joined into
    it, each wholly on one bone so it moves rigid with it:
      {model, at: {bone, t, dir}, lift (m off the skin), scale, spin (deg
       about the skin's normal), pair (and mirrored on the other side)}
    A model stands on the skin at its origin, +Y (kiln up) out of it, +X up
    the body. With `ring`, the model is a ring round kiln +Y, put round the
    limb at the point (+Y along the bone, towards its head) and sized to it
    (modelled for a 0.05 m limb)."""
    todo = []
    for e in r.get("extras", []):
        todo.append(e)
        if e.get("pair"):
            at = dict(e["at"])
            bone = at["bone"]
            if bone.endswith((".L", ".R")):
                at["bone"] = bone[:-2] + (".R" if bone.endswith(".L") else ".L")
            if at.get("dir") in ("left", "right"):   # (a pair on the trunk: one each side)
                at["dir"] = "right" if at["dir"] == "left" else "left"
            todo.append({**e, "at": at, "pair": False, "mirror": True})
    if not todo:
        return
    bm = bmesh.new()
    bm.from_mesh(K.ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.normal_update()
    parts = []
    for e in todo:
        hit, d, core, own, bone = skin_point(K, bm, e["at"])
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS_DIR, e["model"] + ".glb"))
        new = [o for o in bpy.data.objects if o not in before]
        k = e.get("scale", 1.0)
        if e.get("ring"):
            a, b = K.bones[e["at"]["bone"]]
            axis = (a - b).normalized()
            k *= limb_radius(K, bm, own, core, axis) / 0.05 * 1.05
            z = axis
            x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
            x = (x - z * x.dot(z)).normalized()
            where = core
        else:
            z = d   # out of the skin
            up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, -1, 0))   # (on top of a foot: +X forward)
            x = (up - z * up.dot(z)).normalized()
            where = hit + d * e.get("lift", 0.0)
        y = z.cross(x)
        rot = Matrix((x, y, z)).transposed()   # columns: local x, y, z
        spin = Matrix.Rotation(math.radians(e.get("spin", 0.0)), 3, "Z")
        mirror = Matrix.Diagonal((1, -1, 1)) if e.get("mirror") else Matrix.Identity(3)
        # kiln +Y (out) is Blender +Z after the glTF import; kiln +X stays +X
        m = Matrix.Translation(where) @ (rot @ spin @ mirror @ Matrix.Diagonal((k, k, k))).to_4x4()
        for o in new:
            if o.type != "MESH":
                bpy.data.objects.remove(o)
                continue
            o.matrix_world = m @ o.matrix_world
            parts.append((o, bone))
    bm.free()
    for o, bone in parts:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.select_set(False)   # (a mirrored part's faces are turned back by the apply)
        g = o.vertex_groups.new(name=bone)
        g.add(range(len(o.data.vertices)), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    for o, _ in parts:
        o.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()


def build(K, rig, name, r):
    r = {**DEFAULTS[r["kind"]], **r}
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    for n in K.names:
        ob.vertex_groups.new(name=n)
    if r["kind"] == "mark":
        bm = mark(K, r, ob)
    else:
        bm, tpar = skirt(K, r) if r["kind"] == "skirt" else from_body(K, r)
        colour(K, bm, tpar, r, ob)
    # the hem and colour cuts split faces; where both halves took one
    # colour the cut only costs triangles: dissolve it back
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(3.0), verts=bm.verts[:], edges=bm.edges[:],
                             delimit={"MATERIAL"})
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob.parent = rig
    if r["thick"] > 0:   # a skirt: seen from under, the inside shows
        sol = ob.modifiers.new("thick", "SOLIDIFY")
        sol.thickness = r["thick"]
        sol.offset = -1.0      # inward, toward the skin it already clears
        sol.use_rim = True
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="thick")
    ob.parent = None   # joined in world space, then back on the rig
    add_extras(K, ob, r)
    ob.parent = rig
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
