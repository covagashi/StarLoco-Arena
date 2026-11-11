"""S35: summon 8010, the floating crystal mirror (owner, 2026-11-09: not
from Meshy, modelled here as a rigid piece). An oval glass in a frame
with eight rays, hovering; one bone carries it through the 10 base
animations (names as rig_anims.py), so the game plays it like the
others. Built at the fighters' 1.45 scale; Fighter3D.SUMMONS scales it.

    blender -b -P tools/blender/characters/crystal_8010.py -- <out.glb>
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

OUT = sys.argv[sys.argv.index("--") + 1]
FPS = 30
CENTRE = Vector((0, 0, 0.78))   # hovering: the oval's middle
RX, RZ, DEPTH = 0.24, 0.32, 0.07


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.35
    return m


def oval_glass():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1)
    ob = bpy.context.object
    ob.scale = (RX, DEPTH / 2, RZ)
    ob.data.materials.append(mat("glass", (0.07, 0.13, 0.13)))
    return ob


def frame():
    bpy.ops.mesh.primitive_torus_add(major_segments=40, minor_segments=8, major_radius=1, minor_radius=0.07)
    ob = bpy.context.object
    ob.rotation_euler = (math.pi / 2, 0, 0)
    ob.scale = (RX * 1.04, RZ * 1.04, 0.45)
    ob.data.materials.append(mat("frame", (0.10, 0.11, 0.11)))
    return ob


def rays():
    out = []
    m = mat("ray", (0.07, 0.08, 0.08))
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        d = Vector((math.cos(a) * RX, 0, math.sin(a) * RZ))
        n = Vector((math.cos(a) / RX, 0, math.sin(a) / RZ)).normalized()  # out of the oval
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.022, radius2=0.0, depth=0.12)
        ob = bpy.context.object
        ob.location = d * 1.06 + n * 0.06
        ob.rotation_euler = Vector((0, 0, 1)).rotation_difference(n).to_euler()
        ob.data.materials.append(m)
        out.append(ob)
    return out


def shine():
    """The pale diagonal streak across the glass (the retail sprite's)."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.object
    ob.scale = (0.035, 0.004, RZ * 1.5)
    ob.location = (-0.05, -DEPTH / 2 - 0.004, 0)
    ob.rotation_euler = (0, math.radians(-28), 0)
    ob.data.materials.append(mat("shine", (0.80, 0.92, 0.90)))
    # keep it on the glass: cut what pokes past the oval
    mod = ob.modifiers.new("in", "BOOLEAN")
    return ob, mod


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    parts = [oval_glass(), frame()] + rays()
    streak, cut = shine()
    keep = parts[0].copy()
    keep.data = parts[0].data.copy()
    keep.scale = (RX * 0.96, 0.2, RZ * 0.96)
    bpy.context.collection.objects.link(keep)
    cut.operation = "INTERSECT"
    cut.object = keep
    bpy.context.view_layer.objects.active = streak
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(keep)
    parts.append(streak)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = "crystal_8010"
    # a slight turn, as on the retail sprite, then lifted to its hover
    ob.rotation_euler = (0, math.radians(-18), 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ob.location = CENTRE
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    bpy.ops.object.shade_smooth()
    return ob


def rig(ob):
    arm = bpy.data.armatures.new("rig")
    r = bpy.data.objects.new("rig", arm)
    bpy.context.collection.objects.link(r)
    bpy.context.view_layer.objects.active = r
    bpy.ops.object.mode_set(mode="EDIT")
    root = arm.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0.15, 0)
    body = arm.edit_bones.new("body")
    body.head, body.tail = CENTRE, CENTRE + Vector((0, 0, 0.3))
    body.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    r.data.bones["root"].use_deform = False
    for pb in r.pose.bones:
        pb.rotation_mode = "XYZ"
    g = ob.vertex_groups.new(name="body")
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    ob.parent = r
    ob.modifiers.new("rig", "ARMATURE").object = r
    return r


def keys(r, name, frames, loop):
    """frames: [(frame, {z, y, spin, tilt, scale})] on the body bone; z
    and y move it (cells), spin turns it about up, tilt leans it."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    r.animation_data_create()
    r.animation_data.action = act
    pb = r.pose.bones["body"]
    for f, kw in frames:
        # the body bone points up: its local y is world z, its local z world -y
        pb.location = Vector((0, kw.get("z", 0), -kw.get("y", 0)))
        pb.rotation_euler = Euler((math.radians(kw.get("tilt", 0)), math.radians(kw.get("spin", 0)), 0))
        s = kw.get("scale", 1.0)
        pb.scale = Vector((s, s, s))
        for path in ("location", "rotation_euler", "scale"):
            pb.keyframe_insert(path, frame=f)
    track = r.animation_data.nla_tracks.new()
    track.name = name + ("_loop" if loop else "")
    strip = track.strips.new(track.name, int(frames[0][0]), act)
    strip.name = track.name
    r.animation_data.action = None


def animate(r):
    bob = lambda i, n, a: a * math.sin(2 * math.pi * i / n)
    keys(r, "idle", [(i, dict(z=bob(i, 48, 0.03), spin=bob(i, 48, 12), tilt=bob(i, 96, 4))) for i in range(0, 49, 6)], True)
    keys(r, "walk", [(i, dict(z=bob(i, 24, 0.04), tilt=8, spin=bob(i, 24, 6))) for i in range(0, 25, 3)], True)
    keys(r, "cast", [(0, {}), (7, dict(z=0.06, scale=0.9, tilt=-10)), (12, dict(z=0.02, scale=1.18, spin=40)),
                     (18, dict(scale=1.05, spin=10)), (30, {})], False)
    keys(r, "melee", [(0, {}), (8, dict(y=0.06, tilt=-15)), (12, dict(y=-0.18, tilt=25)), (16, dict(y=-0.05, tilt=8)),
                      (24, {})], False)
    keys(r, "hit", [(0, {}), (2, dict(spin=-18, y=0.04)), (4, dict(spin=14)), (6, dict(spin=-8)), (9, dict(spin=4)),
                    (15, {})], False)
    keys(r, "die", [(0, {}), (8, dict(z=0.05, spin=60, scale=1.05)), (20, dict(z=-0.5, spin=200, scale=0.5)),
                    (30, dict(z=-0.7, spin=270, scale=0.05)), (40, dict(z=-0.7, spin=270, scale=0.05))], False)
    keys(r, "jump", [(0, {}), (6, dict(z=-0.08, scale=0.92)), (12, dict(z=0.45, spin=90)), (16, dict(z=0.35, spin=150)),
                     (20, dict(spin=180)), (23, dict(z=-0.05, spin=180)), (32, dict(spin=180))], False)
    keys(r, "celebrate", [(0, {}), (10, dict(z=0.12, spin=180)), (20, dict(z=0.0, spin=360)), (28, dict(z=0.08, spin=450)),
                          (36, dict(spin=360))], False)
    keys(r, "carry", [(i, dict(z=bob(i, 24, 0.02), spin=bob(i, 24, 10))) for i in range(0, 25, 6)], True)
    keys(r, "throw", [(0, {}), (6, dict(y=0.05, tilt=-12)), (11, dict(y=-0.15, tilt=20)), (16, dict(y=-0.04)), (26, {})], False)


def main():
    ob = build()
    r = rig(ob)
    animate(r)
    os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    r.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True)
    print("[crystal] %s %d tris %d KB" % (OUT, sum(len(p.vertices) - 2 for p in ob.data.polygons),
                                         os.path.getsize(OUT) // 1024))


if __name__ == "__main__":  # promo_crystal.py imports the parts
    main()
