"""S54 (paso 2): are the feet flat? For a built figure GLB, every frame of
every clip: each foot standing on the floor (its lowest point within 3 cm
of it) and how far its sole tips from the rest (degrees, ignoring where it
points; not in "die", lying on its back), and whether the figure floats
(both feet off the floor on a frame of a clip that stays on the ground).

    blender -b -P tools/blender/characters/feet_check.py -- <figure.glb> [more.glb…] [--json=out.json]

Prints one line per clip: the worst tilt of a standing foot and its frame,
the frames floating. In "walk" two tilts are meant: the heel strike (the
foot down with its toes up, foot_<S> = 12) and the toe-off (the back foot
leaving the floor, heel first). The sole is measured from the mesh: the vertices the
foot bone moves most (weight > 0.5), their lowest 15 %.
"""
import json
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = next((a.split("=", 1)[1] for a in argv if a.startswith("--json=")), "")
FILES = [a for a in argv if not a.startswith("--")]
# clips where leaving the floor is the point
AIRBORNE = ("jump", "die", "celebrate")
STAND = 0.03
FLOAT = 0.01


def measure(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    def foot_verts(o, S):
        g = o.vertex_groups.get(f"foot.{S}")
        return [v.index for v in o.data.vertices if g and any(e.group == g.index and e.weight > 0.5 for e in v.groups)]

    # the mesh the feet are (a built figure may have a few: fighter1's boots)
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == rig]
    ob = max(meshes, key=lambda o: len(foot_verts(o, "L")), default=None)
    if ob is None or not foot_verts(ob, "L") or not foot_verts(ob, "R"):
        print(f"[feet] {path.rsplit('/', 1)[-1]} no feet, skipped")
        return {}
    me = ob.data
    soles = {}
    for S in "LR":
        idx = foot_verts(ob, S)
        idx.sort(key=lambda i: (ob.matrix_world @ me.vertices[i].co).z)
        soles[S] = idx[:max(3, len(idx) * 15 // 100)]
    rest = {S: rig.data.bones[f"foot.{S}"].matrix_local.to_3x3() for S in "LR"}
    if rig.animation_data is None:
        rig.animation_data_create()
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    out = {}
    for act in bpy.data.actions:
        rig.animation_data.action = act
        if act.slots:
            rig.animation_data.action_slot = act.slots[0]
        f0, f1 = (int(x) for x in act.frame_range)
        worst, at, floating = 0.0, f0, []
        for f in range(f0, f1 + 1):
            bpy.context.scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            ev = ob.evaluated_get(dg)
            em = ev.to_mesh()
            mw = ob.matrix_world
            low = {S: min((mw @ em.vertices[i].co).z for i in soles[S]) for S in "LR"}
            ev.to_mesh_clear()
            if min(low.values()) > FLOAT and not act.name.split("_")[0] in AIRBORNE:
                floating.append(f)
            if act.name.startswith("die"):
                continue   # lying on its back
            for S in "LR":
                if low[S] > STAND:
                    continue
                cur = rig.pose.bones[f"foot.{S}"].matrix.to_3x3()
                up = (cur @ rest[S].inverted()) @ Vector((0, 0, 1))
                tilt = math.degrees(up.angle(Vector((0, 0, 1))))
                if tilt > worst:
                    worst, at = tilt, f
        out[act.name] = {"tilt": round(worst, 1), "at": at, "floating": floating}
        print(f"[feet] {path.rsplit('/', 1)[-1]} {act.name:16s} tilt {worst:5.1f}° @ {at:3d}"
              + (f"  floats {floating}" if floating else ""))
    return out


res = {p: measure(p) for p in FILES}
if OUT:
    with open(OUT, "w") as fh:
        json.dump(res, fh, indent=1)
