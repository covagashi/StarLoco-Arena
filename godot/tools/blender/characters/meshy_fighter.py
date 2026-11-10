"""S35: a Meshy figure (owner's Flow → Meshy pipeline) made into a game
fighter: cleaned, scaled to the game's 1.45 cells, cut to the triangle and
texture budget of the web demo, fitted with the common 20-bone skeleton
(fighter1.BONES names and parents) and given the 10 base animations of
rig_anims.py.

    blender -b -P tools/blender/characters/meshy_fighter.py -- <in.glb> <out.glb>
        [--tris=5000] [--tex=1024] [--joints=<overrides.json>] [--debug=<dir>]
        [--overhead_out=40]   (raised arms open into a V: short arms, big head)

What it does, in order:
1. Joins the meshes, merges the seam duplicates Meshy leaves, drops
   crumbs, scales to 1.45 high, feet on z=0, centred on the feet, facing
   -Y (glTF +Z, the way the game expects it; Meshy's front already is).
2. Decimates to --tris triangles and resizes the texture to --tex px.
3. Finds the joints on the mesh from horizontal slices (legs, crotch,
   arms hanging in the A pose, neck) and builds the skeleton there. A
   joints JSON ({"elbow.L": [x, y, z], …}) overrides any of them; --debug
   writes the slices and an x-ray render of the bones over the mesh.
4. Weights: Blender's heat weights; each vertex then keeps only the bones
   near it (the heat solution reaches across gaps, e.g. a hand hanging by
   the skirt), at most 4, normalised; above the neck it rides the head.
5. The 10 animations (rig_anims.animate), exported as one GLB.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rig_anims  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"tris": "5000", "tex": "1024", "joints": "", "debug": "", "overhead_out": "40"}
POS = []
for a in argv:
    if a.startswith("--") and "=" in a:
        k, v = a[2:].split("=", 1)
        OPT[k] = v
    else:
        POS.append(a)
SRC, OUT = POS[0], POS[1]
HEIGHT = 1.45
FPS = 30
NAME = os.path.splitext(os.path.basename(OUT))[0]
LOG = {}
ARM = {}  # per side: the arm's x range per slice, the hand tip and the armpit


# ---------------------------------------------------------------- clean

def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=SRC)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    for o in bpy.data.objects:
        if o.type == "MESH":
            mw = o.matrix_world.copy()
            o.parent = None
            o.matrix_world = mw
    for o in [o for o in bpy.data.objects if o.type != "MESH"]:
        bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.name = ob.data.name = NAME
    LOG["source_tris"] = tris(ob)
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def clean(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    h = max(v.co.z for v in bm.verts) - min(v.co.z for v in bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=h * 2e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=h * 1e-5)
    # crumbs: islands under 0.2 % of the vertices
    seen, islands = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, isl = [v], []
        seen.add(v)
        while stack:
            u = stack.pop()
            isl.append(u)
            for e in u.link_edges:
                w = e.other_vert(u)
                if w not in seen:
                    seen.add(w)
                    stack.append(w)
        islands.append(isl)
    small = [v for isl in islands if len(isl) < 0.002 * len(bm.verts) for v in isl]
    LOG["islands"] = len(islands)
    LOG["crumbs_dropped"] = sum(1 for isl in islands if len(isl) < 0.002 * len(bm.verts))
    bmesh.ops.delete(bm, geom=small, context="VERTS")
    # scale and place: feet on z=0, the feet's centre at the origin
    zs = [v.co.z for v in bm.verts]
    lo, hi = min(zs), max(zs)
    k = HEIGHT / (hi - lo)
    for v in bm.verts:
        v.co = (v.co - Vector((0, 0, lo))) * k
    feet = [v.co for v in bm.verts if v.co.z < 0.06]
    cx = (min(c.x for c in feet) + max(c.x for c in feet)) / 2
    cy = (min(c.y for c in feet) + max(c.y for c in feet)) / 2
    for v in bm.verts:
        v.co.x -= cx
        v.co.y -= cy
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    LOG["scale"] = round(k, 4)
    LOG["non_manifold_edges"] = non_manifold(ob)


def non_manifold(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    n = sum(1 for e in bm.edges if not e.is_manifold)
    bm.free()
    return n


def decimate(ob, target):
    n = tris(ob)
    if n > target:
        m = ob.modifiers.new("decimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = target / n
        m.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in ob.data.polygons:
        p.use_smooth = True
    LOG["tris"] = tris(ob)


def shrink_textures(ob, px):
    sizes = []
    for m in ob.data.materials:
        m.name = NAME
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img = n.image
                if img.size[0] > px:
                    img.scale(px, px)
                img.pack()
                sizes.append(list(img.size))
                bsdf = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
                if bsdf:  # the toon shader only reads the albedo
                    bsdf.inputs["Metallic"].default_value = 0.0
                    bsdf.inputs["Roughness"].default_value = 1.0
    LOG["textures"] = sizes


# ---------------------------------------------------------------- joints

class Slicer:
    """Cross-sections of the mesh: the triangles cut by a horizontal plane,
    joined into loops through the edges they share; loops that overlap in
    x merge into one piece (a leg inside a skirt is one piece)."""

    def __init__(self, ob):
        me = ob.data
        self.co = [v.co.copy() for v in me.vertices]
        self.tris = []
        me.calc_loop_triangles()
        for t in me.loop_triangles:
            a, b, c = t.vertices
            zs = (self.co[a].z, self.co[b].z, self.co[c].z)
            self.tris.append(((a, b, c), min(zs), max(zs)))

    def cut(self, a, b, z):
        pa, pb = self.co[a], self.co[b]
        k = (z - pa.z) / (pb.z - pa.z)
        return pa.lerp(pb, k)

    def __call__(self, z):
        parent = {}

        def find(e):
            while parent[e] != e:
                parent[e] = parent[parent[e]]
                e = parent[e]
            return e

        pts = {}
        for (a, b, c), lo, hi in self.tris:
            if not (lo < z < hi):
                continue
            es = []
            for u, v in ((a, b), (b, c), (c, a)):
                if (self.co[u].z - z) * (self.co[v].z - z) < 0:
                    e = (min(u, v), max(u, v))
                    if e not in pts:
                        pts[e] = self.cut(u, v, z)
                        parent[e] = e
                    es.append(e)
            if len(es) == 2:
                ra, rb = find(es[0]), find(es[1])
                if ra != rb:
                    parent[ra] = rb
        loops = {}
        for e, p in pts.items():
            loops.setdefault(find(e), []).append(p)
        pieces = sorted(([min(p.x for p in L), max(p.x for p in L), L] for L in loops.values() if len(L) >= 3),
                        key=lambda r: r[0])
        merged = []
        for x0, x1, L in pieces:
            if merged and x0 <= merged[-1][1] + 0.004:
                merged[-1][1] = max(merged[-1][1], x1)
                merged[-1][2] = merged[-1][2] + L
            else:
                merged.append([x0, x1, L])
        res = []
        for x0, x1, L in merged:
            res.append({"x0": x0, "x1": x1, "cx": (x0 + x1) / 2,
                        "cy": (min(p.y for p in L) + max(p.y for p in L)) / 2,
                        "y0": min(p.y for p in L), "y1": max(p.y for p in L), "n": len(L)})
        return res


def fit_line(rows):
    """Least squares x(z), y(z) through [(z, x, y)]."""
    n = len(rows)
    mz = sum(r[0] for r in rows) / n
    mx = sum(r[1] for r in rows) / n
    my = sum(r[2] for r in rows) / n
    szz = sum((r[0] - mz) ** 2 for r in rows) or 1e-9
    ax = sum((r[0] - mz) * (r[1] - mx) for r in rows) / szz
    ay = sum((r[0] - mz) * (r[2] - my) for r in rows) / szz
    return lambda z: Vector((mx + ax * (z - mz), my + ay * (z - mz), z))


def find_joints(ob):
    sl = Slicer(ob)
    H = max(p.z for p in sl.co)
    step = 0.01
    zs = [i * step for i in range(1, int(H / step))]
    table = {round(z, 3): sl(z + 1e-4) for z in zs}
    J = {}

    # feet: the soles' two pieces, toe at the front (-y)
    sole = sorted(sl(0.02), key=lambda c: c["cx"])
    if len(sole) < 2:
        raise SystemExit("[meshy] can't find two feet at the sole")
    feet = {"R": sole[0], "L": sole[-1]}
    # ankle: going up, where the foot's depth drops below 60 % of the sole's
    ankle_z = 0.08
    for z in zs:
        if z < 0.04:
            continue
        cl = table[round(z, 3)]
        legs = [c for c in cl if c["cx"] > 0.01]
        if legs and (legs[-1]["y1"] - legs[-1]["y0"]) < 0.6 * (feet["L"]["y1"] - feet["L"]["y0"]):
            ankle_z = z
            break
    ankle_z = min(ankle_z, 0.16)
    # arms: with the arms hanging apart from the body a slice has the two
    # arms outermost; the arm is the outer run that reaches highest, and the
    # hand any lower outer piece in line with it (a hand touching the
    # trousers splits the run)
    armrows = {"L": [], "R": []}
    for z in zs:
        if z < H * 0.2 or z > H * 0.72:
            continue
        cl = table[round(z, 3)]
        if len(cl) < 3:
            continue
        for S, c in (("R", cl[0]), ("L", cl[-1])):
            X = 1 if S == "L" else -1
            if c["cx"] * X > 0.08 and not (c["x0"] < 0 < c["x1"]):
                armrows[S].append((z, c["cx"], c["cy"], c["x0"], c["x1"]))
    for S in "LR":
        rows, runs = armrows[S], []
        for r in rows:
            if runs and r[0] - runs[-1][-1][0] < 0.025:
                runs[-1].append(r)
            else:
                runs.append([r])
        if not runs:
            raise SystemExit(f"[meshy] can't find arm {S} apart from the body")
        arm = max(runs, key=lambda run: (run[-1][0], len(run)))
        line = fit_line([r[:3] for r in arm])
        top = arm[-1][0]
        keep = list(arm)
        width = sorted(r[4] - r[3] for r in arm)[len(arm) // 2]
        for r in rows:
            # the elbow bends the arm, so the line only roughly finds the
            # hand; a thin piece is a hem or a coat tip, not a hand
            if (r[0] < arm[0][0] and top - r[0] < 0.30 * H and abs(line(r[0]).x - r[1]) < 0.08
                    and 0.7 * width < r[4] - r[3] < 0.08):
                keep.append(r)
        for r in sorted(rows, reverse=True):  # fingertips: thin, but right under the hand
            lowest = min(k[0] for k in keep)
            if r[0] < lowest and lowest - r[0] < 0.015 and abs(r[1] - min(keep)[1]) < 0.03:
                keep.append(r)
        armrows[S] = sorted(keep)
        pieces = {round(r[0], 3): (r[3], r[4]) for r in armrows[S]}
        low = armrows[S][0]
        under = [c for c in table[round(low[0] - 0.02, 3)]
                 if c["x0"] - 0.005 < low[1] < c["x1"] + 0.005 and c["x1"] - c["x0"] > 1.3 * width]
        if under:  # the hand runs into the body (touches the coat): one hand length more
            hand = 0.065 * H
            for i in range(1, int(hand / step) + 1):
                pieces[round(low[0] - i * step, 3)] = (low[3], low[4])
            armrows[S].insert(0, (low[0] - hand, low[1], low[2], low[3], low[4]))
            LOG["hand_hidden_" + S] = True
        known = sorted(pieces)
        for z in zs:  # where the hand touches the body: between the pieces around it
            z = round(z, 3)
            if known[0] < z < known[-1] and z not in pieces:
                lo = max(k for k in known if k < z)
                hi = min(k for k in known if k > z)
                t = (z - lo) / (hi - lo)
                pieces[z] = tuple(pieces[lo][i] + (pieces[hi][i] - pieces[lo][i]) * t for i in (0, 1))
        ARM[S] = {"pieces": pieces, "tip": known[0] - 0.015, "pit": arm[-1][0],
                  "half": sorted((r[4] - r[3]) / 2 for r in armrows[S])[len(armrows[S]) // 2]}
    armpit_z = min(armrows["L"][-1][0], armrows["R"][-1][0])
    # crotch: the highest height below the arms with a gap between the legs
    crotch_z = None
    for z in zs:
        if 0.12 < z < armpit_z - 0.1 and not any(c["x0"] < 0 < c["x1"] for c in table[round(z, 3)]):
            crotch_z = z + step
    hip_z = crotch_z + 0.03
    # legs: the centre of each leg piece between the ankle and the crotch
    legrows = {"L": [], "R": []}
    for z in zs:
        if ankle_z + 0.02 < z < crotch_z - 0.01:
            cl = [c for c in table[round(z, 3)] if abs(c["cx"]) < 0.2]
            for S, X in (("L", 1), ("R", -1)):
                mine = [c for c in cl if c["cx"] * X > 0.01]
                if mine:
                    c = min(mine, key=lambda c: abs(c["cx"]))  # the leg, not a hand beside it
                    legrows[S].append((z, c["cx"], c["cy"]))
    # neck: the narrowest piece across x=0 between the armpits and the head
    best = None
    for z in zs:
        if armpit_z + 0.03 < z < H * 0.82:
            mid = [c for c in table[round(z, 3)] if c["x0"] < 0 < c["x1"]]
            if mid:
                w = mid[0]["x1"] - mid[0]["x0"]
                if best is None or w < best[0]:
                    best = (w, z, mid[0]["cy"])
    neck_z = best[1]

    def torso_y(z):
        mid = [c for c in table.get(round(round(z / step) * step, 3), []) if c["x0"] < 0 < c["x1"]]
        return mid[0]["cy"] if mid else 0.0

    # shoulder: its top is the last cut, going up, where the torso is still
    # clearly wider than the neck (just before it narrows into it); the
    # joint sits one arm radius under it (owner, 2026-11-10: armpit + 3.5 cm
    # put it on the biceps)
    neck_half = best[0] / 2
    top = armpit_z
    z = armpit_z
    while z < neck_z:
        mid = [c for c in sl(z) if c["x0"] < 0 < c["x1"]]
        if mid and min(mid[0]["x1"], -mid[0]["x0"]) > 1.8 * neck_half:
            top = z
        z += 0.005
    sh_z = top - 1.1 * (ARM["L"]["half"] + ARM["R"]["half"]) / 2
    sh_z = max(sh_z, armpit_z + 0.02)
    neck0 = neck_z - 0.035
    J["root"] = Vector((0, 0, 0))
    J["hips"] = Vector((0, torso_y(hip_z), hip_z))
    for name, k in (("spine", 0.286), ("chest", 0.629)):
        z = hip_z + (neck0 - hip_z) * k
        J[name] = Vector((0, torso_y(z), z))
    J["neck"] = Vector((0, best[2], neck0))
    J["head"] = Vector((0, best[2], neck_z + 0.035))
    J["top"] = Vector((0, best[2], H))
    for S, X in (("L", 1), ("R", -1)):
        line = fit_line([r[:3] for r in armrows[S]])
        tip_z = armrows[S][0][0] - 0.01
        a, b = line(sh_z), line(tip_z)
        # above the armpit the line runs on outwards; keep the joint inside
        # the shoulder, a little in from its outer edge
        mid = [c for c in sl(sh_z) if c["x0"] < 0 < c["x1"]]
        if mid:
            edge = mid[0]["x1"] if X > 0 else -mid[0]["x0"]
            a.x = X * min(abs(a.x), edge - 0.4 * ARM[S]["half"])
            a.y = torso_y(sh_z)
        J[f"upper_arm.{S}"] = a
        # elbow and wrist on the arm's own centre at their height (the arm
        # bends; the shoulder-to-hand line misses it by centimetres)
        rows = {round(r[0], 3): r for r in armrows[S]}
        for name, k in ((f"forearm.{S}", 0.42), (f"hand.{S}", 0.78)):
            q = a.lerp(b, k)
            r = rows.get(round(round(q.z / step) * step, 3))
            J[name] = Vector((r[1], r[2], q.z)) if r and r[4] - r[3] < 0.09 else q
        J[f"hand_tip.{S}"] = b
        J[f"shoulder.{S}"] = Vector((0.03 * X, torso_y(sh_z), sh_z))
        lr = legrows[S]
        leg = fit_line(lr) if len(lr) > 3 else (lambda z, X=X: Vector((0.08 * X, 0, z)))
        th = leg(hip_z)
        th.x *= 0.9
        J[f"thigh.{S}"] = th
        kz = ankle_z + (hip_z - ankle_z) * 0.48
        J[f"shin.{S}"] = leg(kz)
        an = leg(ankle_z)
        an.y = (feet[S]["y0"] + feet[S]["y1"]) / 2 + 0.25 * (feet[S]["y1"] - feet[S]["y0"])
        J[f"foot.{S}"] = an
        J[f"toe.{S}"] = Vector((an.x, feet[S]["y0"] + 0.025, 0.022))
    if OPT["joints"]:
        for k, v in json.load(open(OPT["joints"])).items():
            J[k] = Vector(v)
    LOG["landmarks"] = {"ankle": round(ankle_z, 3), "crotch": round(crotch_z, 3), "armpit": round(armpit_z, 3),
                        "shoulder_top": round(top, 3), "shoulder": round(sh_z, 3),
                        "neck": round(neck_z, 3), "height": round(H, 3)}
    if OPT["debug"]:
        os.makedirs(OPT["debug"], exist_ok=True)
        with open(os.path.join(OPT["debug"], NAME + "_slices.txt"), "w") as f:
            for z, cl in table.items():
                f.write(f"{z:.2f} " + "  ".join(f"[{c['x0']:+.3f},{c['x1']:+.3f} y{c['cy']:+.3f}]" for c in cl) + "\n")
    return J


def bones_from(J):
    B = [("root", J["root"], J["root"] + Vector((0, 0.15, 0)), None),
         ("hips", J["hips"], J["spine"], "root"),
         ("spine", J["spine"], J["chest"], "hips"),
         ("chest", J["chest"], J["neck"], "spine"),
         ("neck", J["neck"], J["head"], "chest"),
         ("head", J["head"], J["top"], "neck")]
    for S in "LR":
        B += [(f"shoulder.{S}", J[f"shoulder.{S}"], J[f"upper_arm.{S}"], "chest"),
              (f"upper_arm.{S}", J[f"upper_arm.{S}"], J[f"forearm.{S}"], f"shoulder.{S}"),
              (f"forearm.{S}", J[f"forearm.{S}"], J[f"hand.{S}"], f"upper_arm.{S}"),
              (f"hand.{S}", J[f"hand.{S}"], J[f"hand_tip.{S}"], f"forearm.{S}"),
              (f"thigh.{S}", J[f"thigh.{S}"], J[f"shin.{S}"], "hips"),
              (f"shin.{S}", J[f"shin.{S}"], J[f"foot.{S}"], f"thigh.{S}"),
              (f"foot.{S}", J[f"foot.{S}"], J[f"toe.{S}"], f"shin.{S}")]
    return B


def build_armature(B):
    arm = bpy.data.armatures.new("rig")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, parent in B:
        b = arm.edit_bones.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = (b.parent.tail - b.head).length < 1e-6
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    ob.data.bones["root"].use_deform = False
    return ob


# ---------------------------------------------------------------- weights

def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return (a + ab * t - p).length


def arm_side(p):
    """'L' / 'R' if the vertex is part of an arm below the armpit (the
    arm's own piece in that slice; where the hand touches the body, the
    pieces above and below it give the hand's width), else None."""
    S = "L" if p.x > 0 else "R"
    a = ARM[S]
    if not (a["tip"] <= p.z <= a["pit"] + 0.005):
        return None
    z = round(round(p.z / 0.01) * 0.01, 3)
    if z not in a["pieces"]:  # the fingertips, under the lowest cut
        z = min(a["pieces"]) if p.z < a["pit"] else None
        if z is None:
            return None
    x0, x1 = a["pieces"][z]
    return S if x0 - 0.012 <= p.x <= x1 + 0.012 else None


ARM_CHAIN = ("upper_arm", "forearm", "hand")


def arm_vertices(ob, segs):
    """{vertex: 'L' | 'R'} for the arms below the armpit: in the arm's
    slice piece and near its bones, joined through the mesh to the arm's
    core (upper arm, forearm), so a panel hanging by the hand stays out;
    then holes filled (a vertex mostly surrounded by arm is arm)."""
    me = ob.data
    cand = {}
    for v in me.vertices:
        S = arm_side(v.co)
        if S and min(seg_dist(v.co, *segs[f"{b}.{S}"]) for b in ARM_CHAIN) <= ARM[S]["half"] + 0.03:
            cand[v.index] = S
    nbr, allnbr = {i: [] for i in cand}, {}
    for e in me.edges:
        a, b = e.vertices
        allnbr.setdefault(a, []).append(b)
        allnbr.setdefault(b, []).append(a)
        if a in cand and b in cand and cand[a] == cand[b]:
            nbr[a].append(b)
            nbr[b].append(a)
    stack = [i for i, S in cand.items()
             if min(seg_dist(me.vertices[i].co, *segs[f"{b}.{S}"]) for b in ("upper_arm", "forearm")) < ARM[S]["half"]]
    arm_of = {i: cand[i] for i in stack}
    while stack:
        i = stack.pop()
        for j in nbr[i]:
            if j not in arm_of:
                arm_of[j] = cand[j]
                stack.append(j)
    for _ in range(3):
        grow = {}
        for i, ns in allnbr.items():
            if i in arm_of:
                continue
            co = me.vertices[i].co
            S = "L" if co.x > 0 else "R"
            if co.z < ARM[S]["pit"] and sum(arm_of.get(j) == S for j in ns) * 3 >= 2 * len(ns):
                grow[i] = S
        arm_of.update(grow)
    return arm_of, cand


def cut_height():
    """Below this the arms are cut free and weighted strictly; above it
    (the armpit and shoulder) Blender's heat weights blend arm and body."""
    return min(ARM["L"]["pit"], ARM["R"]["pit"]) - 0.03


def split_arms(ob, arm_of):
    """Meshy fuses an arm to the body where they touch (an elbow on the
    waist, a hand on the coat): those faces would stretch into a sheet
    when the arm lifts. Each face goes to the side most of its corners are
    on, and below the armpit the arm faces are cut free of the body faces
    (along shared edges, then at shared corners). Returns the new
    {vertex: side}: below the cut, a vertex is arm when its faces are."""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    tag = bm.verts.layers.int.new("arm")
    for v in bm.verts:
        v[tag] = {"L": 1, "R": 2}.get(arm_of.get(v.index), 0)
    cut_z = ARM["cut"]
    # a face's side comes from its corners below the cut (above it the heat
    # weights blend arm and body anyway; a long decimated sliver reaching
    # up past the cut must still follow the arm)
    side = {}
    for f in bm.faces:
        low = [v for v in f.verts if v.co.z < cut_z] or list(f.verts)
        side[f] = sum(v[tag] > 0 for v in low) * 2 > len(low)
    cut = [e for e in bm.edges if len(e.link_faces) == 2
           and side[e.link_faces[0]] != side[e.link_faces[1]]
           and max(v.co.z for v in e.verts) < cut_z]
    bmesh.ops.split_edges(bm, edges=cut)
    corners = 0
    for v in list(bm.verts):
        if v.co.z < cut_z and len({side[f] for f in v.link_faces}) > 1:
            for f in list(v.link_faces):
                if side[f]:
                    bmesh.utils.face_vert_separate(f, v)
                    corners += 1
    out = {}
    for i, v in enumerate(bm.verts):
        S = "L" if v.co.x > 0 else "R"
        if v.co.z < cut_z and v.link_faces:
            if side[v.link_faces[0]]:
                out[i] = {1: "L", 2: "R"}.get(v[tag], S)
        elif v[tag]:
            out[i] = {1: "L", 2: "R"}[v[tag]]
    LOG["arm_cut"] = {"edges": len(cut), "corners": corners}
    bm.to_mesh(ob.data)
    bm.free()
    return out


def smooth_weights(ob, factor, repeat, limit=4):
    """Each vertex's weights move factor of the way to its neighbours'
    average, repeat times; then the smallest beyond limit go and the rest
    are normalised."""
    me = ob.data
    nbr = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    W = [{g.group: g.weight for g in v.groups} for v in me.vertices]
    for _ in range(repeat):
        new = []
        for i, w in enumerate(W):
            if not nbr[i]:
                new.append(w)
                continue
            avg = {}
            for j in nbr[i]:
                for k, x in W[j].items():
                    avg[k] = avg.get(k, 0.0) + x / len(nbr[i])
            keys = set(w) | set(avg)
            new.append({k: (1 - factor) * w.get(k, 0.0) + factor * avg.get(k, 0.0) for k in keys})
        W = new
    for v, w in zip(me.vertices, W):
        top = sorted(((k, x) for k, x in w.items() if x > 0.01), key=lambda kv: -kv[1])[:limit]
        tot = sum(x for _, x in top)
        if not tot:
            continue
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        for k, x in top:
            ob.vertex_groups[k].add([v.index], x / tot, "REPLACE")


def skin(ob, rig, J):
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones if b.use_deform}
    ARM["cut"] = cut_height()
    arm_of, cand = arm_vertices(ob, segs)
    LOG["arm_rejected"] = len(cand) - len(arm_of)
    arm_of = split_arms(ob, arm_of)
    LOG["arm_verts"] = {S: sum(1 for x in arm_of.values() if x == S) for S in "LR"}
    if OPT["debug"]:
        weight_render(ob, arm_of, cand)
        LOG["cut_z"] = round(ARM["cut"], 3)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    groups = {g.index: g.name for g in ob.vertex_groups}
    vg = {g.name: g for g in ob.vertex_groups}
    for name in segs:
        if name not in vg:
            vg[name] = ob.vertex_groups.new(name=name)
    head_z = J["head"].z
    unweighted = 0
    for v in ob.data.vertices:
        p = v.co
        d = {n: seg_dist(p, a, b) for n, (a, b) in segs.items()}
        near = min(d.values())
        w = {groups[g.group]: g.weight for g in v.groups if groups.get(g.group) in segs}
        if p.z > head_z:
            w = {"head": 1.0}
        # keep the bones near this vertex: the heat solution leaks across gaps
        allowed = {n for n, x in d.items() if x < near * 1.5 + 0.03}
        w = {n: x for n, x in w.items() if n in allowed and x > 0.01}
        S = arm_of.get(v.index) if p.z < ARM["cut"] else None
        if S:  # an arm: its own chain only
            chain = {f"{b}.{S}" for b in ARM_CHAIN}
            w = {n: x for n, x in w.items() if n in chain} or {min(chain, key=d.get): 1.0}
        elif p.z < ARM["cut"]:  # body beside the arms: none of them
            w = {n: x for n, x in w.items() if n.split(".")[0] not in ARM_CHAIN + ("shoulder",)}
        else:  # shoulder and above: arm bones only close to the arm (not a backpack)
            w = {n: x for n, x in w.items()
                 if n.split(".")[0] not in ARM_CHAIN or d[n] < 2.2 * ARM[n[-1]]["half"]}
        if not w:
            unweighted += 1
            body = {n: x for n, x in d.items() if n.split(".")[0] not in ARM_CHAIN}
            w = {min(body, key=body.get): 1.0}
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top)
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        for n, x in top:
            vg[n].add([v.index], x / tot, "REPLACE")
    LOG["heat_fallbacks"] = unweighted
    # soften the jumps (sleeve tops, the armpit): the cut edges are split,
    # so nothing bleeds between an arm and the body below the cut
    smooth_weights(ob, factor=0.5, repeat=4)
    names = {g.index: g.name for g in ob.vertex_groups}
    for v in ob.data.vertices:  # the head stays rigid
        if v.co.z > head_z:
            for g in list(v.groups):
                ob.vertex_groups[g.group].remove([v.index])
            vg["head"].add([v.index], 1.0, "REPLACE")
        elif v.index not in arm_of or v.co.z >= ARM["cut"]:
            far = lambda n: (v.co.z < ARM["cut"]
                             or seg_dist(v.co, *segs[n]) >= 2.2 * ARM[n[-1]]["half"])
            gone = [g for g in v.groups if names[g.group].split(".")[0] in ARM_CHAIN and far(names[g.group])]
            if gone and len(gone) < len(v.groups):
                for g in gone:
                    ob.vertex_groups[g.group].remove([v.index])
                tot = sum(g.weight for g in v.groups)
                for g in v.groups:
                    g.weight /= tot


# ---------------------------------------------------------------- debug

def debug_render(ob, rig, J):
    """Front and side x-ray renders with the joints as red balls."""
    d = OPT["debug"]
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.show_xray = True
    scn.display.shading.xray_alpha = 0.35
    scn.display.shading.color_type = "TEXTURE"
    scn.render.resolution_x, scn.render.resolution_y = 600, 900
    mat = bpy.data.materials.new("joint")
    mat.diffuse_color = (1, 0, 0, 1)
    balls = []
    for k, p in J.items():
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.012, location=p)
        o = bpy.context.active_object
        o.data.materials.append(mat)
        balls.append(o)
    for _, h, t, _ in bones_from(J):
        v = Vector(t) - Vector(h)
        if v.length < 1e-4:
            continue
        bpy.ops.mesh.primitive_cylinder_add(radius=0.004, depth=v.length, location=(Vector(h) + Vector(t)) / 2)
        o = bpy.context.active_object
        o.rotation_mode = "QUATERNION"
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(v)
        o.data.materials.append(mat)
        balls.append(o)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.6
    scn.camera = cam
    for view, loc, rot in (("front", (0, -5, 0.75), (math.pi / 2, 0, 0)),
                           ("side", (5, 0, 0.75), (math.pi / 2, 0, math.pi / 2))):
        cam.location, cam.rotation_euler = loc, rot
        scn.render.filepath = os.path.join(d, f"{NAME}_bones_{view}.png")
        bpy.ops.render.render(write_still=True)
    for o in balls + [cam]:
        bpy.data.objects.remove(o)


def weight_render(ob, arm_of, cand):
    """Rest pose, arm vertices red (rejected candidates blue), front and back."""
    me = ob.data
    col = me.color_attributes.new("dbg", "BYTE_COLOR", "POINT")
    for v in me.vertices:
        c = ((1, 0.1, 0.1, 1) if arm_of.get(v.index) == "L" else (1, 0.6, 0.1, 1) if v.index in arm_of
             else (0.1, 0.3, 1, 1) if v.index in cand else (0.8, 0.8, 0.8, 1))
        col.data[v.index].color = c
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.show_xray = False
    scn.display.shading.color_type = "VERTEX"
    scn.render.resolution_x, scn.render.resolution_y = 600, 900
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.6
    scn.camera = cam
    for view, loc, rot, sc in (("front", (0, -5, 0.75), (math.pi / 2, 0, 0), 1.6),
                               ("back", (0, 5, 0.75), (math.pi / 2, 0, math.pi), 1.6),
                               ("side", (5, 0, 0.75), (math.pi / 2, 0, math.pi / 2), 1.6),
                               ("pit", (0.15, -5, ARM["cut"]), (math.pi / 2, 0, 0), 0.3),
                               ("pitback", (0.15, 5, ARM["cut"]), (math.pi / 2, 0, math.pi), 0.3)):
        cam.location, cam.rotation_euler = loc, rot
        cam.data.ortho_scale = sc
        scn.render.filepath = os.path.join(OPT["debug"], f"{NAME}_arm_{view}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    me.color_attributes.remove(col)


# ---------------------------------------------------------------- main

def main():
    ob = load()
    clean(ob)
    J = find_joints(ob)  # on the full mesh: the cuts are denser
    decimate(ob, int(OPT["tris"]))
    shrink_textures(ob, int(OPT["tex"]))
    B = bones_from(J)
    if OPT["debug"]:
        debug_render(ob, None, J)
    rig = build_armature(B)
    skin(ob, rig, J)
    # the feet-on-the-floor fix measures from the sole: heel under the
    # ankle, toe under the foot bone's tail
    rig_anims.ANKLE = (J["foot.L"].z + J["foot.R"].z) / 2
    rig_anims.TOE = (J["toe.L"].z + J["toe.R"].z) / 2
    rig_anims.OVERHEAD_OUT = float(OPT["overhead_out"])
    rig_anims.animate(rig)
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True,
                              export_image_format="JPEG", export_image_quality=90)
    LOG["bones"] = len(rig.data.bones)
    LOG["animations"] = len(rig.animation_data.nla_tracks)
    LOG["glb_kb"] = round(os.path.getsize(OUT) / 1024)
    LOG["joints"] = {k: [round(x, 3) for x in v] for k, v in J.items()}
    print("[meshy] " + OUT + " " + json.dumps(LOG))


main()
