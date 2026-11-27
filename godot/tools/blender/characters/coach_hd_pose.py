"""S54 (paso 0): a coach's full Meshy original (~676k triangles) in the menu
stance, for the menus' image instead of the 3D coach.

    blender -b -P tools/blender/characters/coach_hd_pose.py -- <hd.glb> <built.glb> <mask.png> <out.glb>
        [--frame=0] [the coach's figures.json opts]

The original is posed with the coach's own skeleton: the same steps as
meshy_fighter.py (clean, the MeshLab reduction, joints, bones, heat
weights) build the 40k figure in the A-pose, where it still lines up with
the original; its weights go onto the original (nearest face,
interpolated), the arms come down with it (--lower_arms) and the menu clip
(rig_anims "menu") poses it at --frame. The skin and hair mask comes from
the built figure (<built.glb> with <mask.png>, coach_masks.py): each vertex
of the original takes the mask under its nearest point on the built mesh,
in the rest pose, where both match. Out: one static mesh, the original's
UVs and texture, the mask as the vertex colour (R skin, G hair).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
argv = sys.argv[sys.argv.index("--") + 1:]
pos = [a for a in argv if not a.startswith("--")]
HD, BUILT, MASK, OUT = pos
# meshy_fighter reads its own argv: the original in, our out
sys.argv = [sys.argv[0], "--", HD, OUT, f"--hd_src={HD}"] + [a for a in argv if a.startswith("--")]
import meshy_fighter as mf  # noqa: E402
import rig_anims  # noqa: E402

FRAME = int(mf.OPT.get("frame", "0"))


def transfer_weights(lo, hi):
    for g in lo.vertex_groups:
        hi.vertex_groups.new(name=g.name)
    dt = hi.modifiers.new("weights", "DATA_TRANSFER")
    dt.object = lo
    dt.use_vert_data = True
    dt.data_types_verts = {"VGROUP_WEIGHTS"}
    dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"
    dt.layers_vgroup_select_dst = "NAME"
    bpy.context.view_layer.objects.active = hi
    bpy.ops.object.modifier_apply(modifier=dt.name)
    mf.LOG["hd_weighted"] = sum(1 for v in hi.data.vertices if v.groups)
    mf.LOG["hd_verts"] = len(hi.data.vertices)


def mask_from_built(hi):
    """Each vertex of the original: the mask texel under its nearest point
    on the built figure (both in the rest pose)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=BUILT)
    new = [o for o in bpy.data.objects if o not in before]
    built = next(o for o in new if o.type == "MESH")
    for md in list(built.modifiers):
        built.modifiers.remove(md)
    me = built.data
    mw = built.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    me.calc_loop_triangles()
    lts = list(me.loop_triangles)
    bvh = BVHTree.FromPolygons(verts, [tuple(t.vertices) for t in lts])
    uv = me.uv_layers.active.data
    img = bpy.data.images.load(MASK)
    W, H = img.size
    px = list(img.pixels)
    ch = img.channels

    def sample(u, v):
        x = min(W - 1, max(0, int(u * W)))
        y = min(H - 1, max(0, int(v * H)))  # Blender's pixels start at the bottom, as UVs do
        i = (y * W + x) * ch
        return px[i], px[i + 1]

    attr = hi.data.color_attributes.new("mask", "FLOAT_COLOR", "POINT")
    far = 0
    for v in hi.data.vertices:
        p, _, fi, d = bvh.find_nearest(v.co)
        if fi is None:
            attr.data[v.index].color = (0, 0, 0, 1)
            continue
        if d > 0.01:
            far += 1
        t = lts[fi]
        a, b, c = (verts[i] for i in t.vertices)
        # barycentric weights of p in a b c
        v0, v1, v2 = b - a, c - a, p - a
        d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
        d20, d21 = v2.dot(v0), v2.dot(v1)
        den = d00 * d11 - d01 * d01 or 1e-12
        wb = (d11 * d20 - d01 * d21) / den
        wc = (d00 * d21 - d01 * d20) / den
        wa = 1.0 - wb - wc
        ua, ub, uc = (uv[li].uv for li in t.loops)
        u = wa * ua.x + wb * ub.x + wc * uc.x
        w = wa * ua.y + wb * ub.y + wc * uc.y
        r, g = sample(u, w)
        attr.data[v.index].color = (r, g, 0.0, 1.0)
    hi.data.color_attributes.active_color = attr
    mf.LOG["mask_far_verts"] = far
    for o in new:
        bpy.data.objects.remove(o)


def menu_pose(rig, act, frame):
    """The clip's pose at `frame`, read off its curves (assigning the action
    and setting the frame left the last clip's last pose on the bones)."""
    from bpy_extras import anim_utils
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    rig.animation_data.action = None
    cb = anim_utils.action_get_channelbag_for_slot(act, act.slots[0])
    for fc in cb.fcurves:
        bone = fc.data_path.split('"')[1]
        prop = fc.data_path.rsplit(".", 1)[1]
        getattr(rig.pose.bones[bone], prop)[fc.array_index] = fc.evaluate(frame)
    bpy.context.view_layer.update()


def main():
    ob = mf.load()
    mf.clean(ob)
    hi = mf.keep_high(ob)
    mf.reduce_clean(ob, hi, int(mf.OPT["tris"]))
    J = mf.find_joints(ob)
    rig = mf.build_armature(mf.bones_from(J))
    mf.skin(ob, rig, J)
    if mf.OPT["lower_arms"]:
        mf.claim_arm_verts(ob, rig)  # the finger tips with the arm, before the original takes the weights
    transfer_weights(ob, hi)
    m = hi.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    if mf.OPT["lower_arms"]:
        mf.lower_arms(ob, rig, J, float(mf.OPT["lower_arms"]), others=(hi,))
    mask_from_built(hi)
    rig_anims.ANKLE = (J["foot.L"].z + J["foot.R"].z) / 2
    rig_anims.TOE = (J["toe.L"].z + J["toe.R"].z) / 2
    rig_anims.OVERHEAD_OUT = float(mf.OPT["overhead_out"])
    rig_anims.MENU_CLIPS = True
    rig_anims.animate(rig)
    menu_pose(rig, bpy.data.actions["menu"], FRAME)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = hi
    hi.select_set(True)
    mod = next(m for m in hi.modifiers if m.type == "ARMATURE")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    hi.vertex_groups.clear()
    for p in hi.data.polygons:
        p.use_smooth = True
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=False, export_skins=False, export_yup=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                              export_image_format="AUTO")
    mf.LOG["glb_kb"] = round(os.path.getsize(OUT) / 1024)
    print("[coach_hd_pose] " + OUT + " " + str(mf.LOG))


main()
