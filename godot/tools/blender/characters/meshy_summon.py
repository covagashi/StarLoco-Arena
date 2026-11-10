"""S35: a Meshy summon made into a game piece. The fighters' slice fit
(meshy_fighter.py) reads a chibi human; a doll, a sack, a golem or a tree
breaks it, so here the joints come whole from a JSON and the weights are
Blender's heat weights, kept to the bones near each vertex, with the head
rigid. Built at the fighters' 1.45 (the game scales each summon down).

    blender -b -P tools/blender/characters/meshy_summon.py -- <in.glb> <out.glb>
        --joints=<joints.json> [--head_r=<m>] [--tris=5000] [--tex=1024] [--debug=<dir>]

--head_r: only what is that near the head bone's axis rides it rigidly (a
golem's shoulder boulders reach above its head's base and must follow
the arms). --strict_arms=1: arm bones weigh only where an arm bone is the
nearest (a sack's flaps are fused to its sides, which must not lift).
--rigid_islands=<f>: a loose piece under that fraction of the vertices
rides one bone whole, the one nearest it (a golem's rocks).
--arm_max=<deg>: arm raises scale down so overhead is that many degrees
(rig_anims.ARM_MAX; a sack's flaps fused to its sides).

The JSON names every joint of meshy_fighter.bones_from() (the common 20
bones and rig_anims' 10 animations), or, with --shape=creature, the short
skeleton of creature_anims.py (no arms: chick, sheep, pangolin).
"""
import json
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import creature_anims  # noqa: E402
import meshy_fighter as mf  # noqa: E402  (parses the same argv)
import rig_anims  # noqa: E402
from mathutils import Vector  # noqa: E402


def skin(ob, rig, head):
    """Heat weights; each vertex keeps the bones near it (at most 4), the
    head rides its bone alone, then the weights are smoothed."""
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones if b.use_deform}
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    vg = {g.name: g for g in ob.vertex_groups}
    for name in segs:
        if name not in vg:
            vg[name] = ob.vertex_groups.new(name=name)
    names = {g.index: g.name for g in ob.vertex_groups}
    r = float(mf.OPT.get("head_r") or 1e9)
    on_head = lambda p: head is not None and p.z > head.z and (p.xy - head.xy).length < r
    strict = mf.OPT.get("strict_arms") == "1"
    missed = 0
    for v in ob.data.vertices:
        d = {n: mf.seg_dist(v.co, a, b) for n, (a, b) in segs.items()}
        near = min(d.values())
        w = {names[g.group]: g.weight for g in v.groups if names[g.group] in segs}
        w = {n: x for n, x in w.items() if x > 0.01 and d[n] < near * 1.5 + 0.03}
        if strict and min(d, key=d.get).split(".")[0] not in mf.ARM_CHAIN:
            w = {n: x for n, x in w.items() if n.split(".")[0] not in mf.ARM_CHAIN}
        if on_head(v.co):
            w = {"head": 1.0}
        if not w:
            missed += 1
            w = {min(d, key=d.get): 1.0}
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(x for _, x in top)
        for g in list(v.groups):
            ob.vertex_groups[g.group].remove([v.index])
        for n, x in top:
            vg[n].add([v.index], x / tot, "REPLACE")
    mf.LOG["heat_fallbacks"] = missed
    mf.smooth_weights(ob, factor=0.5, repeat=4)
    for v in ob.data.vertices:
        if on_head(v.co):
            for g in list(v.groups):
                ob.vertex_groups[g.group].remove([v.index])
            vg["head"].add([v.index], 1.0, "REPLACE")


def rigid_islands(ob, rig, frac):
    """Each loose piece smaller than frac of the mesh takes, whole, the bone
    nearest its vertices on average."""
    segs = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in rig.data.bones if b.use_deform}
    me = ob.data
    nbr = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        nbr[a].append(b)
        nbr[b].append(a)
    names = {g.index: g.name for g in ob.vertex_groups}
    seen, done = set(), 0
    for i in range(len(me.vertices)):
        if i in seen:
            continue
        comp, stack = [], [i]
        seen.add(i)
        while stack:
            j = stack.pop()
            comp.append(j)
            for k in nbr[j]:
                if k not in seen:
                    seen.add(k)
                    stack.append(k)
        if len(comp) >= frac * len(me.vertices):
            continue
        tot = {n: sum(mf.seg_dist(me.vertices[j].co, a, b) for j in comp) for n, (a, b) in segs.items()}
        bone = min(tot, key=tot.get)
        for j in comp:
            for g in list(me.vertices[j].groups):
                ob.vertex_groups[g.group].remove([j])
            ob.vertex_groups[bone].add([j], 1.0, "REPLACE")
        done += 1
    mf.LOG["rigid_islands"] = done


def main():
    if not mf.OPT["joints"]:
        raise SystemExit("[summon] --joints=<json> is required")
    raw = json.load(open(mf.OPT["joints"]))
    creature = mf.OPT.get("shape") == "creature"
    ob = mf.load()
    mf.clean(ob)
    mf.decimate(ob, int(mf.OPT["tris"]))
    mf.shrink_textures(ob, int(mf.OPT["tex"]))
    if creature:
        B = creature_anims.bones_from(raw)
        J = {name: h for name, h, _, _ in B}
        J["top"] = Vector(raw["top"])
        head = None
    else:
        J = {k: Vector(v) for k, v in raw.items()}
        J.setdefault("root", Vector((0, 0, 0)))
        B = mf.bones_from(J)
        head = J["head"]
    if mf.OPT["debug"]:
        mf.debug_render(ob, None, J, B)
    rig = mf.build_armature(B)
    skin(ob, rig, head)
    if mf.OPT.get("rigid_islands"):
        rigid_islands(ob, rig, float(mf.OPT["rigid_islands"]))
    if creature:
        creature_anims.animate(rig)
    else:
        rig_anims.ANKLE = (J["foot.L"].z + J["foot.R"].z) / 2
        rig_anims.TOE = (J["toe.L"].z + J["toe.R"].z) / 2
        rig_anims.OVERHEAD_OUT = float(mf.OPT["overhead_out"])
        rig_anims.ARM_MAX = float(mf.OPT.get("arm_max") or 180)
        rig_anims.animate(rig)
    mf.export(ob, rig, J)


main()
