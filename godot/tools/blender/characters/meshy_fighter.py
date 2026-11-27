"""S35: a Meshy figure (owner's Flow → Meshy pipeline) made into a game
fighter: cleaned, scaled to the game's 1.45 cells, cut to the triangle and
texture budget of the web demo, fitted with the common 20-bone skeleton
(fighter1.BONES names and parents) and given the 11 base animations of
rig_anims.py.

    blender -b -P tools/blender/characters/meshy_fighter.py -- <in.glb> <out.glb>
        [--tris=5000] [--tex=1024] [--joints=<overrides.json>] [--arm_slack=0.03] [--thumb=0] [--sleeve=2.2] [--cut=<z>] [--debug=<dir>]
        [--overhead_out=40]   (raised arms open into a V: short arms, big head)
        [--weld_normals=1]    (one normal and one weight set per position: seams stay shut)
        [--lower_arms=10]     (an A-pose original: arms brought down to this many degrees
                               from the vertical, and that becomes the rest pose)
        [--nearest=1]         (--reduce=clean: each texel's colour from the original's nearest point
                               where that surface faces the same way; the rays' colour elsewhere)
        [--jpeg=90]           (the texture's JPEG quality: S53, the coaches' 2048² at 85 fits 2600 KB)
        [--head_uv=2]         (--reduce=clean: the charts above the neck get this many times the
                               texels per side: the face's brows and eyes at 1024²)
        [--claim_hands=1]     (S54: a vertex nearest an arm bone goes to it even fused to the body:
                               finger tips resting on a skirt or a bag, which tore into shards)
        [--drop=x0,x1,y0,y1,z0,z1;…]  (S54: delete the original's faces with a corner in these boxes,
                               metres on the cleaned figure: a fin Meshy left under a chin)
        [--arm_flap=0.03]     (a thin piece this close outside the arm is part of it: a gauntlet's flare)
        [--reduce=clean --hd_src=<original.glb>] [--charts=120] [--unwrap=MINIMUM_STRETCH] [--bake_margin=4] [--bake_extrusion=0.0015]
                              (the mesh reduced from the full original with MeshLab, needs
                               pymeshlab; fresh UVs, the original's colour baked onto them)

What it does, in order:
1. Joins the meshes, merges the seam duplicates Meshy leaves, drops
   crumbs, scales to 1.45 high, feet on z=0, centred on the feet, facing
   -Y (glTF +Z, the way the game expects it; Meshy's front already is).
2. Decimates to --tris triangles and resizes the texture to --tex px
   (--reduce=clean: the mesh made from --hd_src instead, with new UVs
   and the original's colour baked at --tex px).
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
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rig_anims  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"tris": "5000", "tex": "1024", "joints": "", "arm_slack": "0.03", "thumb": "0", "sleeve": "2.2", "cut": "", "debug": "", "overhead_out": "40", "drop_weapon": "", "menu": "", "weld_normals": "", "lower_arms": "",
       "reduce": "", "hd_src": "", "arm_flap": "", "charts": "120", "unwrap": "MINIMUM_STRETCH", "jpeg": "90", "nearest": "", "head_uv": "", "drop": "", "claim_hands": "", "bake_margin": "4", "bake_extrusion": "0.0015"}
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
PLACE = []  # clean()'s move: floor, scale, feet centre x, y


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
    PLACE[:] = [lo, k, cx, cy]
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
        # S47: a newer Meshy export also carries a normal and a
        # metallic-roughness map; the toon shader reads only the albedo, so
        # every image not feeding Base Color goes (smaller file, and the
        # coach masks find the albedo as the only image)
        bsdf = next((x for x in m.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            keep = set()
            todo = [l.from_node for l in bsdf.inputs["Base Color"].links]
            while todo:
                x = todo.pop()
                keep.add(x)
                todo += [l.from_node for i in x.inputs for l in i.links]
            for n in list(m.node_tree.nodes):
                if n.type == "TEX_IMAGE" and n not in keep:
                    m.node_tree.nodes.remove(n)
            for name in ["Normal", "Metallic", "Roughness"]:
                for l in list(bsdf.inputs[name].links):
                    m.node_tree.links.remove(l)
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


def drop_boxes(ob):
    """--drop: every face of the original with a corner inside any of the
    boxes goes (on the cleaned figure, 1.45 high, facing -Y): a box round a
    fin's loose tips takes the fin and leaves the chin it hangs from."""
    boxes = [[float(x) for x in b.split(",")] for b in OPT["drop"].split(";") if b.strip()]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    def inside(co):
        return any(b[0] <= co.x <= b[1] and b[2] <= co.y <= b[3] and b[4] <= co.z <= b[5] for b in boxes)
    gone = [f for f in bm.faces if any(inside(v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=gone, context="FACES")
    bm.to_mesh(ob.data)
    bm.free()
    LOG["dropped_faces"] = LOG.get("dropped_faces", 0) + len(gone)


def keep_high(ob):
    """S53 (A4): --hd_src, the full Meshy original (~676k triangles) the
    build's source was reduced from, moved the way clean() moved the figure."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.expanduser(OPT["hd_src"]))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in new:
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    hi = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    lo, k, cx, cy = PLACE
    hi.data.transform(Matrix.Translation((-cx, -cy, 0)) @ Matrix.Scale(k, 4) @ Matrix.Translation((0, 0, -lo)))
    hi.data.update()
    zs = [v.co.z for v in hi.data.vertices]
    LOG["hd_src"] = {"tris": tris(hi), "z": [round(min(zs), 4), round(max(zs), 4)]}
    hi.name = NAME + "_high"
    return hi


def reduce_clean(ob, hi, target):
    """S53 (A4, owner: "triángulos feos en los coaches: mujer en codo, muslo
    y pelo junto a la oreja"): Blender's collapse leaves one triangle in
    seven a sliver (an angle under 10 degrees), whether it starts from the
    80k copy or the original, with or without UVs; on the toon shading the
    slivers and the folds between them were the shards on the waist, the
    thighs and above the gauntlets. The figure's mesh is made instead from
    the original, welded (Meshy splits it at every UV seam; welded it is
    closed) and reduced with MeshLab's quadric collapse, which refuses a
    collapse that leaves a bad triangle and keeps the faces' orientation:
    0.5 % slivers, and a sixth as many faces turned away from the
    original's surface. (MeshLab's planar weight is lowered: the default
    evens the triangles a little more but rounds the garments' edges.)"""
    try:
        import pymeshlab
    except ImportError:
        raise SystemExit("[meshy] --reduce=clean needs pymeshlab in Blender's Python, e.g. "
                         "<blender>/<ver>/python/bin/python3.* -m pip install --no-deps "
                         "--target ~/.config/blender/<ver>/scripts/addons/modules pymeshlab")
    import numpy as np
    bm = bmesh.new()
    bm.from_mesh(hi.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=HEIGHT * 2e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=HEIGHT * 1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.index_update()
    co = np.array([v.co[:] for v in bm.verts], np.float64)
    fa = np.array([[v.index for v in f.verts] for f in bm.faces], np.int32)
    bm.free()
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(co, fa))
    # crumbs, as clean() drops them
    ms.meshing_remove_connected_component_by_face_number(mincomponentsize=int(0.002 * len(fa)))
    ms.meshing_decimation_quadric_edge_collapse(
        targetfacenum=target, qualitythr=0.6, preserveboundary=True, preservenormal=True,
        preservetopology=True, optimalplacement=True, planarquadric=True, planarweight=0.0003,
        qualityweight=False, autoclean=True)
    m = ms.current_mesh()
    me = bpy.data.meshes.new(NAME)
    me.from_pydata(m.vertex_matrix().tolist(), [], m.face_matrix().tolist())
    for mat in ob.data.materials:
        me.materials.append(mat)
    old = ob.data
    ob.data = me
    bpy.data.meshes.remove(old)
    for p in me.polygons:
        p.use_smooth = True
    LOG["tris"] = tris(ob)


def charts(bm, k, w=6.0, iters=4, minf=12):
    """Chart ids per face: k compact, nearly flat pieces grown from seeds
    spread over the mesh (the cost of a step grows with the turn away from
    the seed's normal), the seeds moved to their pieces' middles a few
    times; no face hangs on its chart by a single edge, and no piece is
    under minf faces (each joins the neighbour it shares most border with)."""
    import heapq
    import numpy as np
    bm.faces.ensure_lookup_table()
    n = len(bm.faces)
    cen = np.array([f.calc_center_median()[:] for f in bm.faces])
    nrm = np.array([f.normal[:] for f in bm.faces])
    area = np.array([f.calc_area() for f in bm.faces])
    nbr = [[] for _ in range(n)]
    elen = [{} for _ in range(n)]
    for e in bm.edges:
        if len(e.link_faces) == 2:
            a, b = e.link_faces[0].index, e.link_faces[1].index
            d = float(np.linalg.norm(cen[a] - cen[b]))
            nbr[a].append((b, d))
            nbr[b].append((a, d))
            elen[a][b] = elen[b][a] = e.calc_length()
    seeds = [int(np.argmax(cen[:, 2]))]   # farthest point sampling
    dmin = np.linalg.norm(cen - cen[seeds[0]], axis=1)
    while len(seeds) < k:
        s = int(np.argmax(dmin))
        seeds.append(s)
        dmin = np.minimum(dmin, np.linalg.norm(cen - cen[s], axis=1))
    for it in range(iters):
        sn = nrm[seeds]
        lab = -np.ones(n, np.int64)
        dist = np.full(n, np.inf)
        h = [(0.0, s, c) for c, s in enumerate(seeds)]
        heapq.heapify(h)
        while h:
            d, i, c = heapq.heappop(h)
            if lab[i] >= 0:
                continue
            lab[i] = c
            for j, l in nbr[i]:
                if lab[j] < 0:
                    dev = 1.0 - float(np.dot(nrm[j], sn[c]))
                    nd = d + l * (1.0 + 4 * w * dev * dev)
                    if nd < dist[j]:
                        dist[j] = nd
                        heapq.heappush(h, (nd, j, c))
        if it == iters - 1:
            break
        for c in range(len(seeds)):
            idx = np.nonzero(lab == c)[0]
            if len(idx):
                mc = (cen[idx] * area[idx, None]).sum(0) / area[idx].sum()
                mn = (nrm[idx] * area[idx, None]).sum(0)
                mn /= max(np.linalg.norm(mn), 1e-12)
                score = np.linalg.norm(cen[idx] - mc, axis=1) * (1 + w * (1 - nrm[idx] @ mn))
                seeds[c] = int(idx[np.argmin(score)])
    nxt = lab.max() + 1
    for i in range(n):   # a shell no seed reached: a chart of its own
        if lab[i] < 0:
            st = [i]
            lab[i] = nxt
            while st:
                q = st.pop()
                for j, _ in nbr[q]:
                    if lab[j] < 0:
                        lab[j] = nxt
                        st.append(j)
            nxt += 1
    for _ in range(50):
        moved = 0
        for i in range(n):
            if sum(1 for j, _ in nbr[i] if lab[j] == lab[i]) >= 2:
                continue
            c = {}
            for j, _ in nbr[i]:
                if lab[j] != lab[i]:
                    c[lab[j]] = c.get(lab[j], 0) + elen[i][j]
            if c:
                lab[i] = max(c, key=c.get)
                moved += 1
        if not moved:
            break
    reg = -np.ones(n, np.int64)
    r = 0
    for i in range(n):   # connected pieces
        if reg[i] < 0:
            st = [i]
            reg[i] = r
            while st:
                q = st.pop()
                for j, _ in nbr[q]:
                    if reg[j] < 0 and lab[j] == lab[i]:
                        reg[j] = r
                        st.append(j)
            r += 1
    for _ in range(10):
        size = np.bincount(reg, minlength=r)
        if not (size < minf).any():
            break
        for i in range(n):
            if size[reg[i]] < minf:
                c = {}
                for j, _ in nbr[i]:
                    if reg[j] != reg[i]:
                        c[reg[j]] = c.get(reg[j], 0) + elen[i][j] * (1 + size[reg[j]])
                if c:
                    reg[i] = max(c, key=c.get)
        _, reg = np.unique(reg, return_inverse=True)
        r = int(reg.max()) + 1
    # every chart a disk (V - E + F = 1): a closed shell or a band round a
    # limb can't be laid flat without crushing part of it, so it is split
    # in two, grown from its two faces farthest apart, until it is one
    for _ in range(8):
        split = 0
        for c in range(r):
            idx = np.nonzero(reg == c)[0]
            fs = [bm.faces[i] for i in idx]
            verts = {v for f in fs for v in f.verts}
            edges = {e for f in fs for e in f.edges}
            if len(verts) - len(edges) + len(fs) == 1 or len(idx) < 2:
                continue
            a = idx[np.argmax(np.linalg.norm(cen[idx] - cen[idx].mean(0), axis=1))]
            b = idx[np.argmax(np.linalg.norm(cen[idx] - cen[a], axis=1))]
            inside = set(idx.tolist())
            lab2 = {int(a): 0, int(b): 1}
            h = [(0.0, int(a), 0), (0.0, int(b), 1)]
            done = set()
            while h:
                d, i, s = heapq.heappop(h)
                if i in done:
                    continue
                done.add(i)
                lab2[i] = s
                for j, l in nbr[i]:
                    if j in inside and j not in done:
                        heapq.heappush(h, (d + l, j, s))
            for i, s in lab2.items():
                if s:
                    reg[i] = r
            r += 1
            split += 1
        if not split:
            break
        LOG["charts_split"] = LOG.get("charts_split", 0) + split
    return reg, r


def unwrap_charts(ob, px, neck=None):
    """S53 (A4): fresh UVs for the reduced mesh: compact charts (charts()),
    their borders the seams, each unwrapped (--unwrap, Minimum Stretch: Angle
    Based crushed 770 faces to under a tenth of their texels, smeared
    colour; it keeps 11), all at one texel density, packed --bake_margin px
    apart. (Smart UV Project cut the mesh into 1400 islands and filled a
    third of the texture; Meshy's own islands, carried over from the
    original, are jagged and filled 44 %.) S54: --head_uv=k gives the
    charts whose middle is above the neck k times the texels per side (at
    1024² a coach's brows were a texel wide and went)."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    reg, n = charts(bm, int(OPT["charts"]))
    for e in bm.edges:
        e.seam = bool(len(e.link_faces) == 2 and reg[e.link_faces[0].index] != reg[e.link_faces[1].index])
    bm.to_mesh(me)
    bm.free()
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UVMap")
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.unwrap(method=OPT["unwrap"], margin=0.0)
    # a chart that is a small closed shell (no seam opens it) unwraps to a
    # point: its faces are cut apart and unwrapped again, one by one
    bpy.ops.mesh.select_all(action="DESELECT")
    bm = bmesh.from_edit_mesh(me)
    uvl = bm.loops.layers.uv.active
    flat = [f for f in bm.faces if abs((f.loops[1][uvl].uv - f.loops[0][uvl].uv).cross(
        f.loops[2][uvl].uv - f.loops[0][uvl].uv)) < 1e-12]
    for f in flat:
        f.select_set(True)
        for e in f.edges:
            e.seam = True
    bmesh.update_edit_mesh(me)
    if flat:
        bpy.ops.uv.unwrap(method=OPT["unwrap"], margin=0.0)
    LOG["uv_rewrapped"] = len(flat)
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    if OPT["head_uv"] and neck is not None:
        k = float(OPT["head_uv"])
        bm = bmesh.from_edit_mesh(me)
        bm.faces.ensure_lookup_table()
        uvl = bm.loops.layers.uv.active
        by = {}
        for f in bm.faces:
            by.setdefault(reg[f.index], []).append(f)
        grown = 0
        for fs in by.values():
            z = sum(f.calc_center_median().z * f.calc_area() for f in fs) / max(sum(f.calc_area() for f in fs), 1e-12)
            if z < neck:
                continue
            ls = [l for f in fs for l in f.loops]
            c = sum((l[uvl].uv for l in ls), Vector((0.0, 0.0))) / len(ls)
            for l in ls:
                l[uvl].uv = c + (l[uvl].uv - c) * k
            grown += 1
        bmesh.update_edit_mesh(me)
        LOG["head_charts"] = grown
    bpy.ops.uv.pack_islands(rotate=True, rotate_method="CARDINAL", shape_method="CONCAVE",
                            margin_method="FRACTION", margin=int(OPT["bake_margin"]) / px)
    bpy.ops.object.mode_set(mode="OBJECT")
    for e in me.edges:
        e.use_seam = False
    me.calc_loop_triangles()
    uv = me.uv_layers[0].data
    fill = 0.0
    ratio = []
    for t in me.loop_triangles:
        a, b, c = (uv[i].uv for i in t.loops)
        ua = abs((b - a).cross(c - a)) / 2
        fill += ua
        ratio.append(ua / max(t.area, 1e-12))
    ratio.sort()
    med = ratio[len(ratio) // 2] or 1.0
    # faces laid out at under a tenth of the usual texels: smeared colour
    LOG["charts"] = {"charts": n, "fill": round(fill, 3), "squashed": sum(1 for x in ratio if x < 0.1 * med)}


def bake_colour(ob, hi, px):
    """S53 (A4): the original's base colour, read through its own UVs,
    baked onto the reduced mesh's (Cycles, selected to active): the colour
    only, as emission, no light, rays from --bake_extrusion m out; then the
    texels the rays missed or darkened (crevices()), and the charts'
    borders run on past the margin (bleed()) so filtering never reaches a
    neighbour's colour."""
    ext = float(OPT["bake_extrusion"])
    me = ob.data
    img = bpy.data.images.new(NAME, px, px, alpha=False)
    targets = []
    for i, m in enumerate(me.materials):
        m2 = m.copy()
        me.materials[i] = m2
        bsdf = next((x for x in m2.node_tree.nodes if x.type == "BSDF_PRINCIPLED"), None)
        node = None
        if bsdf:
            todo = [l.from_node for l in bsdf.inputs["Base Color"].links]
            while todo and not node:
                x = todo.pop()
                if x.type == "TEX_IMAGE":
                    node = x
                todo += [l.from_node for i2 in x.inputs for l in i2.links]
        if node is None:
            node = m2.node_tree.nodes.new("ShaderNodeTexImage")
            if bsdf:
                m2.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
        node.image = img
        for x in m2.node_tree.nodes:
            if x.type == "UVMAP":
                x.uv_map = "UVMap"
        # the target, unlinked: Cycles skips an image it also reads
        # ("circular dependency") and the bake came out black
        target = m2.node_tree.nodes.new("ShaderNodeTexImage")
        target.image = img
        m2.node_tree.nodes.active = target
        targets.append((m2, target))
    # the source shows its base colour as light (an emission bake): the
    # diffuse-colour pass came out black, metal and all
    src_img = None   # the original's albedo, for crevices()
    for i, m in enumerate(hi.data.materials):
        h = m.copy()
        hi.data.materials[i] = h
        nt = h.node_tree
        bsdf = next((x for x in nt.nodes if x.type == "BSDF_PRINCIPLED"), None)
        out = next((x for x in nt.nodes if x.type == "OUTPUT_MATERIAL"), None)
        if not (bsdf and out):
            continue
        todo = [l.from_node for l in bsdf.inputs["Base Color"].links]
        while todo and src_img is None:
            x = todo.pop()
            if x.type == "TEX_IMAGE" and x.image:
                src_img = x.image
            todo += [l.from_node for i2 in x.inputs for l in i2.links]
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Strength"].default_value = 1.0
        if bsdf.inputs["Base Color"].links:
            nt.links.new(bsdf.inputs["Base Color"].links[0].from_socket, em.inputs["Color"])
        else:
            em.inputs["Color"].default_value = bsdf.inputs["Base Color"].default_value
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 16
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.bake(type="EMIT", use_selected_to_active=True,
                        cage_extrusion=ext, max_ray_distance=2 * ext, margin=0,
                        use_clear=True, target="IMAGE_TEXTURES")
    for m2, target in targets:
        m2.node_tree.nodes.remove(target)
    crevices(ob, hi, img, src_img)
    skin_patches(ob, img)
    img.pack()
    LOG["bake"] = {"px": px, "margin": int(OPT["bake_margin"]), "extrusion": ext}


def crevices(ob, hi, img, src):
    """S53 (A4): where the reduced mesh bridges a gap of the original (the
    doll's shoulder ball in its socket, the man's joints), the bake's rays
    miss the original or pass through the gap to the dark inside of the
    crevice; the margin's fill then ran the neighbours' colour into the
    misses: brown streaks on the shoulder. Each texel is also read at the
    nearest point of the original's surface (across a gap: its rim); a
    texel the rays missed (left black) or made much darker than that takes
    the nearest point's colour; with --nearest every texel does whose
    nearest point faces the way its face does (the man's shoulder: the
    rays' colour streaked across the faces that bridge the ball's lip)."""
    if src is None:
        return
    import numpy as np
    from mathutils.bvhtree import BVHTree
    px = img.size[0]
    a = np.empty(px * px * 4, np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(px, px, 4)
    sw, sh = src.size
    s = np.empty(sw * sh * 4, np.float32)
    src.pixels.foreach_get(s)
    s = s.reshape(sh, sw, 4)[..., :3].copy()
    hme = hi.data
    hme.calc_loop_triangles()
    hco = np.empty(len(hme.vertices) * 3)
    hme.vertices.foreach_get("co", hco)
    hco = hco.reshape(-1, 3)
    htv = np.empty(len(hme.loop_triangles) * 3, np.int64)
    hme.loop_triangles.foreach_get("vertices", htv)
    htv = htv.reshape(-1, 3)
    htl = np.empty(len(hme.loop_triangles) * 3, np.int64)
    hme.loop_triangles.foreach_get("loops", htl)
    htl = htl.reshape(-1, 3)
    huv = np.empty(len(hme.loops) * 2)
    hme.uv_layers.active.data.foreach_get("uv", huv)
    huv = huv.reshape(-1, 2)
    tree = BVHTree.FromPolygons(hco.tolist(), htv.tolist(), all_triangles=True)
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    co = [v.co for v in me.vertices]
    pts, pix, nrm = [], [], []
    for t in me.loop_triangles:   # each texel's point on the reduced mesh
        P = np.array([uv[l].uv[:] for l in t.loops]) * px - 0.5
        x0, y0 = np.maximum(np.floor(P.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(P.max(0)).astype(int), px - 1)
        if x1 < x0 or y1 < y0:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = P
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12:
            continue
        l1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / d
        l2 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / d
        l3 = 1 - l1 - l2
        inside = (l1 >= 0) & (l2 >= 0) & (l3 >= 0)
        if not inside.any():
            continue
        A, B, C = (np.array(co[v][:]) for v in t.vertices)
        pts.append(l1[inside, None] * A + l2[inside, None] * B + l3[inside, None] * C)
        pix.append(np.stack([Y[inside], X[inside]], 1))
        nrm.append(np.repeat(np.array(t.normal[:])[None], int(inside.sum()), 0))
    pts = np.concatenate(pts)
    pix = np.concatenate(pix)
    nrm = np.concatenate(nrm)
    near = np.empty((len(pts), 3))
    hn = np.empty((len(pts), 3))
    tri = np.empty(len(pts), np.int64)
    for i, p in enumerate(pts.tolist()):
        loc, n, k, _ = tree.find_nearest(p)
        near[i] = loc
        hn[i] = n
        tri[i] = k
    # the nearest point's UV in the original, then its texel (bilinear)
    T = hco[htv[tri]]
    v0, v1, v2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0], near - T[:, 0]
    d00, d01, d11 = (v0 * v0).sum(1), (v0 * v1).sum(1), (v1 * v1).sum(1)
    d20, d21 = (v2 * v0).sum(1), (v2 * v1).sum(1)
    den = np.maximum(d00 * d11 - d01 * d01, 1e-30)
    w1 = (d11 * d20 - d01 * d21) / den
    w2 = (d00 * d21 - d01 * d20) / den
    U = huv[htl[tri]]
    q = U[:, 0] * (1 - w1 - w2)[:, None] + U[:, 1] * w1[:, None] + U[:, 2] * w2[:, None]
    fx = np.clip(q[:, 0] * sw - 0.5, 0, sw - 1.001)
    fy = np.clip(q[:, 1] * sh - 0.5, 0, sh - 1.001)
    ix, iy = fx.astype(int), fy.astype(int)
    tx, ty = (fx - ix)[:, None], (fy - iy)[:, None]
    col = (s[iy, ix] * (1 - tx) * (1 - ty) + s[iy, ix + 1] * tx * (1 - ty)
           + s[iy + 1, ix] * (1 - tx) * ty + s[iy + 1, ix + 1] * tx * ty)
    w = np.array([0.299, 0.587, 0.114])
    baked = a[pix[:, 0], pix[:, 1], :3]
    missed = (baked == 0).all(1)
    dark = ~missed & (baked @ w < col @ w - 0.2)
    fix = missed | dark
    if OPT["nearest"]:
        # the nearest point, where its surface faces the way the texel's
        # face does (across a groove the nearest is now the rim, now a wall)
        fix = missed | ((hn * nrm).sum(1) > 0.5)
    a[pix[fix, 0], pix[fix, 1], :3] = col[fix]
    cov = np.zeros((px, px), bool)
    cov[pix[:, 0], pix[:, 1]] = True
    bleed(a, cov, 4 * int(OPT["bake_margin"]))
    img.pixels.foreach_set(a.ravel())
    LOG["crevices"] = {"texels": int(len(pts)), "missed": int(missed.sum()), "darkened": int(dark.sum())}


def bleed(a, known, n):
    """The charts' colour run n texels on into the empty texels around."""
    import numpy as np
    rgb = a[..., :3]
    known = known.copy()
    for _ in range(n):
        acc = np.zeros_like(rgb)
        cnt = np.zeros(known.shape, np.float32)
        for sp, sq in (((slice(1, None),), (slice(None, -1),)), ((slice(None, -1),), (slice(1, None),)),
                       ((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
                       ((slice(None), slice(None, -1)), (slice(None), slice(1, None)))):
            k = known[sq]
            acc[sp] += rgb[sq] * k[..., None]
            cnt[sp] += k
        step = ~known & (cnt > 0)
        if not step.any():
            break
        rgb[step] = acc[step] / cnt[step][:, None]
        known |= step


def skin_patches(ob, img):
    """S53 (A4): Meshy painted a white stripe down the woman's inner thigh
    (and white flecks on the skin elsewhere); a dark skin showed it as a
    white scar. Below the neck (the eyes' whites are above it), the faces
    whose texels are mostly pale, joined over the mesh (a patch crosses
    the charts' seams), are skin when nearly all the faces around them are
    skin: their pale texels and those of the faces around are filled in
    from the skin beside them, texel by texel inwards. A boot's or a
    gauntlet's white is one big patch with straps around it, and stays."""
    import numpy as np
    px = img.size[0]
    a = np.empty(px * px * 4, np.float32)
    img.pixels.foreach_get(a)
    a = a.reshape(px, px, 4)
    rgb = a[..., :3]
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    zs = [v.co.z for v in me.vertices]
    fid = np.full((px, px), -1, np.int64)   # the face on each texel
    for t in me.loop_triangles:
        P = np.array([uv[l].uv[:] for l in t.loops]) * px - 0.5
        x0, y0 = np.maximum(np.floor(P.min(0)).astype(int), 0)
        x1, y1 = np.minimum(np.ceil(P.max(0)).astype(int), px - 1)
        if x1 < x0 or y1 < y0:
            continue
        X, Y = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        (ax, ay), (bx, by), (cx, cy) = P
        d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(d) < 1e-12:
            continue
        l1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / d
        l2 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / d
        inside = (l1 >= -0.02) & (l2 >= -0.02) & (l1 + l2 <= 1.02)
        fid[Y[inside], X[inside]] = t.polygon_index
    mx, mn = rgb.max(2), rgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    # coach_masks.py's skin and pale tests; the skin here light and peach
    # (a tan strap is warm too)
    warm = (r > g) & (g >= b) & (sat > 0.07) & (sat < 0.62) & (mx > 0.42) & ((r - b) > 0.06) & ~((mx < 0.7) & (sat > 0.45))
    peach = warm & (sat < 0.35) & (mx > 0.6)
    pale = (sat < 0.16) & (mx > 0.45)
    nf = len(me.polygons)
    on = fid >= 0
    f = fid[on]
    cnt = np.bincount(f, minlength=nf)
    f_pale = np.bincount(f, pale[on], minlength=nf) >= 0.5 * np.maximum(cnt, 1)
    f_skin = np.bincount(f, peach[on], minlength=nf) >= 0.5 * np.maximum(cnt, 1)
    low = np.array([max(zs[v] for v in p.vertices) <= 0.72 * HEIGHT for p in me.polygons])
    nbr = [[] for _ in range(nf)]
    edge_faces = {}
    for p in me.polygons:
        for k in p.edge_keys:
            edge_faces.setdefault(k, []).append(p.index)
    for fs in edge_faces.values():
        for i in fs:
            nbr[i] += [j for j in fs if j != i]
    cand = f_pale & low & (cnt > 0)
    seen = np.zeros(nf, bool)
    take = np.zeros(nf, bool)
    patches, biggest = 0, []
    for i in np.nonzero(cand)[0]:
        if seen[i]:
            continue
        comp, st = [], [i]
        seen[i] = True
        while st:
            k = st.pop()
            comp.append(k)
            for j in nbr[k]:
                if cand[j] and not seen[j]:
                    seen[j] = True
                    st.append(j)
        border = {j for k in comp for j in nbr[k] if not cand[j]}
        if border and sum(f_skin[j] for j in border) >= 0.85 * len(border) and len(comp) <= 400:
            take[comp] = True
            take[list(border)] = True
            patches += 1
            biggest.append(len(comp))
    fill = on & take[np.maximum(fid, 0)] & pale
    for _ in range(2):   # and its light rim, just short of pale
        grow = fill.copy()
        grow[1:] |= fill[:-1]
        grow[:-1] |= fill[1:]
        grow[:, 1:] |= fill[:, :-1]
        grow[:, :-1] |= fill[:, 1:]
        fill = grow & on & take[np.maximum(fid, 0)] & (sat < 0.2) & (mx > 0.45)
    LOG["skin_patches"] = {"patches": patches, "texels": int(fill.sum()),
                           "biggest": sorted(biggest, reverse=True)[:6]}
    known = ~fill & (mx > 0.05)
    while fill.any():
        acc = np.zeros_like(rgb)
        cnt2 = np.zeros((px, px), np.float32)
        for sp, sq in (((slice(1, None),), (slice(None, -1),)), ((slice(None, -1),), (slice(1, None),)),
                       ((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
                       ((slice(None), slice(None, -1)), (slice(None), slice(1, None)))):
            k = known[sq]
            acc[sp] += rgb[sq] * k[..., None]
            cnt2[sp] += k
        step = fill & (cnt2 > 0)
        if not step.any():
            break
        rgb[step] = acc[step] / cnt2[step][:, None]
        known |= step
        fill &= ~step
    a[..., :3] = rgb
    img.pixels.foreach_set(a.ravel())


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
        mid = [c for c in cl if c["x0"] < 0 < c["x1"]]
        for S, side in (("R", cl), ("L", cl[::-1])):
            X = 1 if S == "L" else -1
            # the outermost piece, unless it hangs well behind the torso
            # (a scarf's tail beside the arm): then the next one in
            c = side[0]
            for d in side:
                if d["x0"] < 0 < d["x1"] or not mid or abs(d["cy"] - mid[0]["cy"]) < 0.10:
                    c = d
                    break
            if c["cx"] * X > 0.08 and not (c["x0"] < 0 < c["x1"]):
                if OPT["arm_flap"]:
                    c = arm_flap(c, side, float(OPT["arm_flap"]))
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
        # a lone piece or two up there is a hair curl beside the face; a
        # run well behind the torso is a wing (or a cape's edge)
        def beside(run):
            off = []
            for r in run:
                mid = [c for c in table[round(r[0], 3)] if c["x0"] < 0 < c["x1"]]
                if mid:
                    off.append(abs(r[2] - mid[0]["cy"]))
            return not off or sorted(off)[len(off) // 2] < 0.10
        arm = max([r for r in runs if len(r) >= 3 and beside(r)] or runs, key=lambda run: (run[-1][0], len(run)))
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
    hidden = top == armpit_z  # long hair over the shoulders hides them: just under the neck
    if hidden:
        sh_z = max(sh_z, neck0 - 0.025)
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
        if hidden:  # the slices up there are hair: the arm's own top instead
            p = line(armpit_z)
            a = Vector((p.x, p.y, sh_z))
        J[f"upper_arm.{S}"] = a
        # elbow and wrist on the arm's own centre at their height (the arm
        # bends; the shoulder-to-hand line misses it by centimetres)
        rows = {round(r[0], 3): r for r in armrows[S]}
        for name, k in ((f"forearm.{S}", 0.42), (f"hand.{S}", 0.78)):
            q = a.lerp(b, k)
            r = rows.get(round(round(q.z / step) * step, 3))
            J[name] = Vector((r[1], r[2], q.z)) if r and r[4] - r[3] < 0.09 else q
        J[f"hand_tip.{S}"] = b
        J[f"shoulder.{S}"] = Vector((0.03 * X, a.y if hidden else torso_y(sh_z), sh_z))
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
        fix = json.load(open(OPT["joints"]))
        for k, v in fix.items():
            J[k] = Vector(v)
        for S in "LR":  # a hand moved lower: its slice pieces join the arm
            if f"hand_tip.{S}" in fix:
                extend_hand(S, J, table)
    LOG["landmarks"] = {"ankle": round(ankle_z, 3), "crotch": round(crotch_z, 3), "armpit": round(armpit_z, 3),
                        "shoulder_top": round(top, 3), "shoulder": round(sh_z, 3),
                        "neck": round(neck_z, 3), "height": round(H, 3)}
    if OPT["debug"]:
        os.makedirs(OPT["debug"], exist_ok=True)
        with open(os.path.join(OPT["debug"], NAME + "_slices.txt"), "w") as f:
            for z, cl in table.items():
                f.write(f"{z:.2f} " + "  ".join(f"[{c['x0']:+.3f},{c['x1']:+.3f} y{c['cy']:+.3f}]" for c in cl) + "\n")
    return J


def arm_flap(c, side, gap):
    """S53 (A4, --arm_flap=<m>): a gauntlet's flared top stands off the
    outside of the upper arm, so a slice there cuts it as a thin piece of
    its own beside the arm, and the outermost piece was that flap: the arm
    between it and the body went to the body, and the arm cut tore a ring
    open around it (the strokes above the coach's gauntlets). A thin
    outermost piece less than `gap` from a wider one just inside it is
    one piece with it."""
    i = side.index(c)
    if i + 1 >= len(side):
        return c
    d = side[i + 1]
    if d["x0"] < 0 < d["x1"]:
        return c
    apart = c["x0"] - d["x1"] if c["cx"] > 0 else d["x0"] - c["x1"]
    if not (0 <= apart < gap and c["x1"] - c["x0"] < d["x1"] - d["x0"]):
        return c
    x0, x1 = min(c["x0"], d["x0"]), max(c["x1"], d["x1"])
    LOG["arm_flaps"] = LOG.get("arm_flaps", 0) + 1
    return {"x0": x0, "x1": x1, "cx": (x0 + x1) / 2, "cy": d["cy"],
            "y0": min(c["y0"], d["y0"]), "y1": max(c["y1"], d["y1"]), "n": c["n"] + d["n"]}


def extend_hand(S, J, table):
    """The hand hangs apart under a part fused to the body (a bracer on a
    belt), so the slices missed it: below the arm's lowest piece, the
    piece around the forearm-hand-tip line is arm; the fused stretch in
    between takes the width of the pieces around it."""
    a = ARM[S]
    pieces = a["pieces"]
    chain = [J[f"forearm.{S}"], J[f"hand.{S}"], J[f"hand_tip.{S}"]]

    def x_at(z):
        for p, q in zip(chain, chain[1:]):
            if q.z <= z <= p.z:
                return p.x + (q.x - p.x) * (z - p.z) / (q.z - p.z)
        return None

    # the body runs close beside the hand: no slack on the inner edge
    # (arm_side allows 1.2 cm around a piece)
    inner = lambda x0, x1: (x0 + 0.012, x1) if S == "L" else (x0, x1 - 0.012)
    low = min(pieces)
    for z in sorted(table):
        x = x_at(z)
        if x is None or z > J[f"hand.{S}"].z + 0.03:
            continue
        free = [c for c in table[z] if not (c["x0"] < 0 < c["x1"])]
        for c in free:
            if c["x0"] - 0.01 <= x <= c["x1"] + 0.01 and c["x1"] - c["x0"] < 0.11:
                x0, x1 = pieces[z] if z >= low and z in pieces else (c["x0"], c["x1"])
                for t in free:  # the thumb: a small piece right beside the hand
                    if t is not c and t["x1"] - t["x0"] < 0.05 and min(abs(t["x1"] - x0), abs(t["x0"] - x1)) < 0.03:
                        x0, x1 = min(x0, t["x0"]), max(x1, t["x1"])
                pieces[z] = inner(x0, x1) if z < low else (x0, x1)
    # fused to the body (the outermost piece reaches the middle, a bracer
    # on the belt): the inner edge is the narrower of the free pieces
    # around, the outer edge the fused piece's (the arm is outermost)
    def outer(z):
        c = table[z][-1] if S == "L" else table[z][0]
        return c if (c["x0"] < 0.03 if S == "L" else c["x1"] > -0.03) else None
    free = sorted(z for z in pieces if not (table.get(z) and outer(z)))
    for z in sorted(table):
        if free[0] < z < free[-1] and table[z] and outer(z):
            lo = pieces[max(k for k in free if k < z)]
            hi = pieces[min(k for k in free if k > z)]
            c = outer(z)
            pieces[z] = (max(lo[0], hi[0]), c["x1"]) if S == "L" else (c["x0"], min(lo[1], hi[1]))
    # --thumb: a thumb fused to the body in front of the hand is that much
    # inside the hand's pieces (Pandawa m)
    t = float(OPT["thumb"])
    if t:
        for z in pieces:
            if z <= J[f"hand.{S}"].z:
                x0, x1 = pieces[z]
                pieces[z] = (x0 - t, x1) if S == "L" else (x0, x1 + t)
    known = sorted(pieces)
    a["tip"] = min(known[0] - 0.015, J[f"hand_tip.{S}"].z)
    a["hand_z"] = J[f"hand.{S}"].z + 0.03  # below: the hand's pieces bound it
    LOG.setdefault("hand_extended", {})[S] = round(known[0], 3)


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
        # a hand found by extend_hand is bounded by its pieces: more room
        # around the bone (a thumb in front of the hand)
        # (--arm_slack: room around the bones for armour sticking out of
        # the arm, a bracer's fins)
        slack = float(OPT["arm_slack"])
        if S and v.co.z < ARM[S].get("hand_z", -1):
            slack = max(slack, 0.05)
        if S and min(seg_dist(v.co, *segs[f"{b}.{S}"]) for b in ARM_CHAIN) <= ARM[S]["half"] + slack:
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
    # a loose piece (a sword in the hand) that is mostly arm goes whole
    seen = set()
    for i in allnbr:
        if i in seen:
            continue
        comp, stack = [], [i]
        seen.add(i)
        while stack:
            j = stack.pop()
            comp.append(j)
            for k in allnbr[j]:
                if k not in seen:
                    seen.add(k)
                    stack.append(k)
        for S in "LR":
            n = sum(arm_of.get(j) == S for j in comp)
            if n * 2 > len(comp) and all(me.vertices[j].co.z < ARM[S]["pit"] for j in comp):
                for j in comp:
                    arm_of[j] = S
                LOG.setdefault("loose_to_arm", []).append(len(comp))
                ARM.setdefault("loose", []).append(comp)
    return arm_of, cand


def cut_height():
    """Below this the arms are cut free and weighted strictly; above it
    (the armpit and shoulder) Blender's heat weights blend arm and body."""
    if OPT["cut"]:  # --cut: lower, for a thin arm with few vertices under the armpit
        return float(OPT["cut"])
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
    # above the cut, arm weights only this many arm radii from its bones
    # (--sleeve: more, for a puffed sleeve that must lift with the arm; then
    # a vertex the heat solve missed may also take the arm bone)
    reach = float(OPT["sleeve"])
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
                 if n.split(".")[0] not in ARM_CHAIN or d[n] < reach * ARM[n[-1]]["half"]}
        if not w:
            unweighted += 1
            body = {n: x for n, x in d.items() if n.split(".")[0] not in ARM_CHAIN
                    or (OPT["sleeve"] != "2.2" and p.z >= ARM["cut"] and x < reach * ARM[n[-1]]["half"])}
            w = {min(body, key=body.get): 1.0}
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top)
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        for n, x in top:
            vg[n].add([v.index], x / tot, "REPLACE")
    LOG["heat_fallbacks"] = unweighted
    # soften the jumps (sleeve tops, the armpit): the cut edges are split,
    # so nothing bleeds between an arm and the body below the cut. The passes
    # go by mesh neighbours, so a denser mesh needs more of them to soften
    # the same distance (S47: at ~21k triangles 4 passes left the elbows
    # tearing); 4 at the 5k figures, as before.
    passes = max(4, round(4 * (len(ob.data.polygons) / 5000) ** 0.5))
    LOG["weight_passes"] = passes
    smooth_weights(ob, factor=0.5, repeat=passes)
    names = {g.index: g.name for g in ob.vertex_groups}
    for v in ob.data.vertices:  # the head stays rigid
        if v.co.z > head_z:
            for g in list(v.groups):
                ob.vertex_groups[g.group].remove([v.index])
            vg["head"].add([v.index], 1.0, "REPLACE")
        elif v.index not in arm_of or v.co.z >= ARM["cut"]:
            far = lambda n: (v.co.z < ARM["cut"]
                             or seg_dist(v.co, *segs[n]) >= reach * ARM[n[-1]]["half"])
            gone = [g for g in v.groups if names[g.group].split(".")[0] in ARM_CHAIN and far(names[g.group])]
            if gone and len(gone) < len(v.groups):
                for g in gone:
                    ob.vertex_groups[g.group].remove([v.index])
                tot = sum(g.weight for g in v.groups)
                for g in v.groups:
                    g.weight /= tot


# ---------------------------------------------------------------- debug

def debug_render(ob, rig, J, bones=None):
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
    for _, h, t, _ in bones or bones_from(J):
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
    if OPT["drop"]:
        drop_boxes(ob)
    if OPT["reduce"] == "clean":
        # before the rest pose moves the arms: high and low still line up
        high = keep_high(ob)
        if OPT["drop"]:
            drop_boxes(high)   # the colour is baked from it: the same faces go
        reduce_clean(ob, high, int(OPT["tris"]))
        # S53 (A4): the joints and the arms' slices from the mesh that is
        # skinned (the 80k source only places the figure)
        J = find_joints(ob)
        unwrap_charts(ob, int(OPT["tex"]), J["neck"].z)
        bake_colour(ob, high, int(OPT["tex"]))
        hm = high.data
        bpy.data.objects.remove(high)
        bpy.data.meshes.remove(hm)
    else:
        J = find_joints(ob)  # on the full mesh: the cuts are denser
        decimate(ob, int(OPT["tris"]))
    shrink_textures(ob, int(OPT["tex"]))
    B = bones_from(J)
    if OPT["debug"]:
        debug_render(ob, None, J)
    rig = build_armature(B)
    skin(ob, rig, J)
    if OPT["claim_hands"]:
        # S54: where the original's hand rests on its skirt or a bag, Meshy
        # fused the finger tips to the cloth: they stayed with the body and
        # tore into shards when the hand moved. The hand takes what it holds.
        claim_arm_verts(ob, rig)
    if OPT["lower_arms"]:
        lower_arms(ob, rig, J, float(OPT["lower_arms"]))
    # the feet-on-the-floor fix measures from the sole: heel under the
    # ankle, toe under the foot bone's tail
    rig_anims.ANKLE = (J["foot.L"].z + J["foot.R"].z) / 2
    rig_anims.TOE = (J["toe.L"].z + J["toe.R"].z) / 2
    rig_anims.OVERHEAD_OUT = float(OPT["overhead_out"])
    rig_anims.MENU_CLIPS = bool(OPT["menu"])
    rig_anims.animate(rig)
    if OPT["drop_weapon"]:
        drop_weapon(ob)
    export(ob, rig, J)


def claim_arm_verts(ob, rig):
    """lower_arms' first step (S54: coach_hd_pose.py runs it before handing
    the weights to the original)."""
    # the weighting rules expect hanging arms: in an A-pose some arm
    # vertices (finger tips, the outside of the elbow) went to the body and
    # would stay behind; a vertex whose nearest bone is an arm's and that
    # has no weight on that arm goes to that bone
    segs = {bn.name: (bn.head_local.copy(), bn.tail_local.copy()) for bn in rig.data.bones if bn.use_deform}
    names = {g.index: g.name for g in ob.vertex_groups}
    claimed = 0
    for v in ob.data.vertices:
        near = min(segs, key=lambda n: seg_dist(v.co, *segs[n]))
        arm = ARM_CHAIN + ("hand_tip",)
        if near.split(".")[0] not in arm or "." not in near:
            continue
        side = near.split(".")[1]
        if any(names[g.group].endswith("." + side) and names[g.group].split(".")[0] in arm
               and g.weight > 0.05 for g in v.groups):
            continue
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        ob.vertex_groups[near].add([v.index], 1.0, "REPLACE")
        claimed += 1
    LOG["arm_verts_claimed"] = claimed


def lower_arms(ob, rig, J, deg, others=()):
    """S47 (--lower_arms): the newer Meshy originals stand in an A-pose,
    arms out at ~40 degrees; the clips (rig_anims) start from the rest pose,
    so the coach walked with its arms spread. Weighted in the A-pose (the
    arms stand clear of the body, which helps), each upper arm is turned
    down about the front axis until shoulder → hand is `deg` from the
    vertical, the mesh takes that pose and it becomes the new rest.
    `others` (S54, coach_hd_pose.py): meshes on the same rig that take the
    pose with it."""
    claim_arm_verts(ob, rig)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    turned = {}
    for S, sign in (("L", 1.0), ("R", -1.0)):
        pb = rig.pose.bones[f"upper_arm.{S}"]
        head = J[f"upper_arm.{S}"]
        hand = J[f"hand_tip.{S}"]
        v = hand - head
        now = math.degrees(math.atan2(abs(v.x), -v.z))
        turn = math.radians(max(0.0, now - deg)) * sign
        R = (Matrix.Translation(head) @ Matrix.Rotation(turn, 4, "Y") @ Matrix.Translation(-head))
        pb.matrix = R @ pb.matrix
        bpy.context.view_layer.update()
        turned[S] = round(now, 1)
    bpy.ops.object.mode_set(mode="OBJECT")
    # bake the pose into the mesh, then make it the rest
    for o in (ob,) + tuple(others):
        mod = next(m for m in o.modifiers if m.type == "ARMATURE")
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    for o in (ob,) + tuple(others):
        m = o.modifiers.new("Armature", "ARMATURE")
        m.object = rig
    LOG["arms_lowered_from"] = turned


def drop_weapon(ob):
    """S35c (--drop_weapon=1): delete the class's weapon fused in the hand
    (the loose piece longer than 25 cm that went whole with an arm). The
    owner (2026-11-11): the weapon is equipment, worn as a card, not part
    of the figure."""
    me = ob.data
    pick = set()
    for comp in ARM.get("loose", []):
        zs = [me.vertices[j].co for j in comp]
        span = max((a - b).length for a in zs[:: max(1, len(zs) // 40)] for b in zs[:: max(1, len(zs) // 40)])
        if span > 0.25:
            pick.update(comp)
    LOG["weapon_verts"] = len(pick)
    if not pick:
        return
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in pick], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def weld_normals(ob):
    """S47: vertices that share a position (the arm cut, UV seams) get the
    same normal, the average of theirs. The ink outline is the mesh pushed
    out along its normals (toon_outline.gdshader): with a normal per side, a
    split seam opened into dark spikes, which a dense mesh (the 21k coach)
    showed all along the arm cut."""
    me = ob.data
    groups = {}
    for v in me.vertices:
        groups.setdefault(tuple(round(c, 5) for c in v.co), []).append(v.index)
    normals = [v.normal.copy() for v in me.vertices]
    welded = 0
    moved = 0
    for idxs in groups.values():
        if len(idxs) < 2:
            continue
        avg = sum((me.vertices[i].normal for i in idxs), Vector()).normalized()
        for i in idxs:
            normals[i] = avg
        welded += len(idxs)
        # and the same weights, so the two sides of a seam move together
        # (with a weight per side the arm cut opened a slit when it bent)
        ws = [{g.group: g.weight for g in me.vertices[i].groups} for i in idxs]
        if all(w == ws[0] for w in ws):
            continue
        keys = set().union(*ws)
        mean = {k: sum(w.get(k, 0.0) for w in ws) / len(ws) for k in keys}
        top = sorted(((k, x) for k, x in mean.items() if x > 0.01), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top) or 1.0
        for i in idxs:
            for g in list(me.vertices[i].groups):
                ob.vertex_groups[g.group].remove([i])
            for k, x in top:
                ob.vertex_groups[k].add([i], x / tot, "REPLACE")
            moved += 1
    me.normals_split_custom_set_from_vertices(normals)
    LOG["welded_normals"] = welded
    LOG["welded_weights"] = moved


def export(ob, rig, J):
    if OPT["weld_normals"]:
        weld_normals(ob)
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True,
                              export_image_format="JPEG", export_image_quality=int(OPT["jpeg"]))
    LOG["bones"] = len(rig.data.bones)
    LOG["animations"] = len(rig.animation_data.nla_tracks)
    LOG["glb_kb"] = round(os.path.getsize(OUT) / 1024)
    LOG["joints"] = {k: [round(x, 3) for x in v] for k, v in J.items()}
    print("[meshy] " + OUT + " " + json.dumps(LOG))


if __name__ == "__main__":  # meshy_summon.py imports the steps
    main()
