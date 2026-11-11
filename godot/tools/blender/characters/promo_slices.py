"""S35b-marketing (tanda 3): how meshy_fighter.py finds the joints, drawn.
The Meshy figure, cleaned as for the build, cut by horizontal planes; each
cut drawn as a ring, coloured by how many pieces that slice has (1 body,
2 legs, 3 body and arms…). Writes layers for PIL to label:

    blender -b -P tools/blender/characters/promo_slices.py -- <meshy.glb> <out_dir>
        [--joints=<joints.json>] [--step=0.025] [--size=1080x1350] [--views=front,three]

<out_dir>/<view>_mesh.png   the figure, see-through
<out_dir>/<view>_rings.png  the slices
<out_dir>/<view>_solid.png  the figure, clay
<out_dir>/info.json         per view: landmarks (screen y, x span), the
                            skeleton (screen segments), and per slice its
                            height and piece count
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
argv = sys.argv[sys.argv.index("--") + 1:]
OUT_DIR = [a for a in argv if not a.startswith("--")][1]
OWN = {"step": "0.025", "size": "1080x1350", "views": "front,three"}
for a in argv:
    if a.startswith("--") and "=" in a and a[2:].split("=")[0] in OWN:
        k, v = a[2:].split("=", 1)
        OWN[k] = v
sys.argv[sys.argv.index("--") + 2] = os.path.join(OUT_DIR, "unused.glb")  # mf wants an output name
import meshy_fighter as mf  # noqa: E402

W, H = (int(x) for x in OWN["size"].split("x"))
COUNT_COL = {1: (0.62, 0.42, 1.0), 2: (0.15, 0.85, 0.75), 3: (1.0, 0.6, 0.12)}
OTHER = (1.0, 0.25, 0.3)


def cut(S, z):
    """The segments of one slice and its pieces (merged as Slicer does)."""
    parent, pts, segs = {}, {}, []

    def find(e):
        while parent[e] != e:
            parent[e] = parent[parent[e]]
            e = parent[e]
        return e
    for (a, b, c), lo, hi in S.tris:
        if not (lo < z < hi):
            continue
        es = []
        for u, v in ((a, b), (b, c), (c, a)):
            if (S.co[u].z - z) * (S.co[v].z - z) < 0:
                e = (min(u, v), max(u, v))
                if e not in pts:
                    pts[e] = S.cut(u, v, z)
                    parent[e] = e
                es.append(e)
        if len(es) == 2:
            segs.append((es[0], es[1]))
            ra, rb = find(es[0]), find(es[1])
            if ra != rb:
                parent[ra] = rb
    return pts, segs, len(S(z))


def ring_objects(S, top):
    by_col = {}
    slices = []
    z = 0.02
    while z < top - 0.01:
        pts, segs, n = cut(S, z)
        slices.append({"z": round(z, 3), "pieces": n})
        col = COUNT_COL.get(n, OTHER)
        verts, edges = by_col.setdefault(col, ([], []))
        idx = {}
        for a, b in segs:
            for e in (a, b):
                if e not in idx:
                    idx[e] = len(verts)
                    verts.append(pts[e])
            edges.append((idx[a], idx[b]))
        z += float(OWN["step"])
    obs = []
    for col, (verts, edges) in by_col.items():
        me = bpy.data.meshes.new("rings")
        me.from_pydata(verts, edges, [])
        ob = bpy.data.objects.new("rings", me)
        bpy.context.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.convert(target="CURVE")
        ob.data.bevel_depth = 0.0028
        ob.data.bevel_resolution = 1
        ob.color = col + (1,)
        obs.append(ob)
    return obs, slices


def camera(view):
    scn = bpy.context.scene
    cam = scn.camera or bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    scn.camera = cam
    cam.data.sensor_fit = "VERTICAL"
    cam.data.type = "PERSP"
    cam.data.lens = 50
    a = math.radians(0 if view == "front" else 32)
    cam.location = Vector((4.6 * math.sin(a), -4.6 * math.cos(a), 1.9))
    look = Vector((0, 0, 0.86)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()
    cam.data.shift_y = 0.07  # the figure under the title
    bpy.context.view_layer.update()
    return cam


def shade(kind):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.render.film_transparent = True
    scn.render.resolution_x, scn.render.resolution_y = W, H
    scn.view_settings.view_transform = "Standard"
    s = scn.display.shading
    s.light = "STUDIO" if kind != "rings" else "FLAT"
    s.show_xray = kind == "mesh"
    s.xray_alpha = 0.3
    s.show_cavity = kind == "solid"
    s.show_specular_highlight = kind == "solid"
    if kind == "rings":
        s.color_type = "OBJECT"
    else:
        s.color_type, s.single_color = "SINGLE", ((0.6, 0.7, 0.8) if kind == "mesh" else (0.72, 0.71, 0.69))


def screen(cam, p):
    c = world_to_camera_view(bpy.context.scene, cam, Vector(p))
    return [round(c.x * W, 1), round((1 - c.y) * H, 1)]


def main():
    ob = mf.load()
    mf.clean(ob)
    J = mf.find_joints(ob)
    S = mf.Slicer(ob)
    top = max(v.co.z for v in ob.data.vertices)
    rings, slices = ring_objects(S, top)
    lm = mf.LOG["landmarks"]
    info = {"landmarks": lm, "slices": slices, "views": {}}
    for view in OWN["views"].split(","):
        cam = camera(view)
        for kind in ("mesh", "solid", "rings"):
            shade(kind)
            ob.hide_render = kind == "rings"
            for r in rings:
                r.hide_render = kind != "rings"
            bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{view}_{kind}.png")
            bpy.ops.render.render(write_still=True)
        xs = [v.co.x for v in ob.data.vertices]
        marks = {}
        for k in ("ankle", "crotch", "armpit", "shoulder", "neck"):
            z = lm[k]
            marks[k] = [screen(cam, (min(xs), 0, z)), screen(cam, (max(xs), 0, z))]
        bones = [[n, screen(cam, h), screen(cam, t)] for n, h, t, _ in mf.bones_from(J) if n != "root"]
        info["views"][view] = {"marks": marks, "bones": bones,
                               "slices": [screen(cam, (0, 0, s["z"]))[1] for s in slices]}
    with open(os.path.join(OUT_DIR, "info.json"), "w") as f:
        json.dump(info, f)
    print("[promo_slices]", OUT_DIR, len(slices), "slices", json.dumps(lm))


main()
