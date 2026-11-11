"""S35b-marketing (tanda 3): frame sequences of a rigged fighter GLB for the
skeleton posts. The overlays (bones, labels) are drawn later in PIL from
the joints this writes, so the look can change without rendering again.

    blender -b -P tools/blender/characters/promo_bones.py -- <fighter.glb> <out_dir>
        [--anim=rest|walk_loop|…] [--frames=60] [--start=0] [--step=1]
        [--yaw0=0] [--yaw1=0] [--layers=grey,ghost,tex,weights]
        [--size=1080x1920] [--dist=3.6] [--lens=50] [--target_z=0.72] [--cam_z=0.95]
        [--pose=<json {bone: [x, y, z] degrees}>] [--pose_in=0] [--wmode=all|arms]

Layers (each in <out_dir>/<layer>/%04d.png, transparent background):
  grey    solid clay, the statue as it comes from Meshy
  ghost   x-ray: the mesh see-through, one tint
  tex     the textured fighter
  weights vertex colours from the skin weights (arms red/orange, legs
          blue/teal, body violet; --wmode=arms leaves the rest grey)
joints.json: per frame, each bone's head and tail on screen (pixels) and
its depth, so the overlay can draw the skeleton on top.

--pose rotates pose bones (XYZ degrees, local) on top of the action;
--pose_in eases it in over that many frames (0: from the first frame).
"""
import json
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"anim": "rest", "frames": "60", "start": "0", "step": "1", "yaw0": "0", "yaw1": "0",
       "layers": "grey,ghost,tex,weights", "size": "1080x1920", "dist": "3.6", "lens": "50",
       "target_z": "0.72", "cam_z": "0.95", "pose": "", "pose_in": "0", "wmode": "all"}
POS = []
for a in argv:
    if a.startswith("--") and "=" in a:
        k, v = a[2:].split("=", 1)
        OPT[k] = v
    else:
        POS.append(a)
SRC, OUT = POS[0], POS[1]
W, H = (int(x) for x in OPT["size"].split("x"))

ARM = ("shoulder", "upper_arm", "forearm", "hand")
LEG = ("thigh", "shin", "foot")
COL = {"L_arm": (0.95, 0.18, 0.16), "R_arm": (1.0, 0.58, 0.12), "L_leg": (0.2, 0.45, 1.0),
       "R_leg": (0.15, 0.8, 0.75), "body": (0.55, 0.35, 0.85), "head": (0.85, 0.85, 0.9)}


def group_of(name):
    base, _, side = name.partition(".")
    if base in ARM:
        return side + "_arm"
    if base in LEG or base == "leg":  # creatures: leg.FL … (front/back, left/right)
        return ("L" if side.endswith("L") else "R") + "_leg"
    return "head" if base in ("head", "neck") else "body"


def load():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=SRC)
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == rig)
    for o in bpy.data.objects:  # the importer's bone shape
        if o.type == "MESH" and o is not mesh:
            o.hide_render = True
    return rig, mesh


def weight_colours(mesh):
    me = mesh.data
    names = {g.index: g.name for g in mesh.vertex_groups}
    col = me.color_attributes.new("wcol", "BYTE_COLOR", "POINT")
    grey = (0.62, 0.62, 0.64)
    for v in me.vertices:
        c = Vector((0, 0, 0))
        tot = 0
        for g in v.groups:
            grp = group_of(names[g.group])
            rgb = COL[grp] if OPT["wmode"] == "all" or grp.endswith("_arm") else grey
            c += Vector(rgb) * g.weight
            tot += g.weight
        c = c / tot if tot else Vector(grey)
        col.data[v.index].color = (c.x, c.y, c.z, 1)
    return col


def camera():
    scn = bpy.context.scene
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    cam.data.lens = float(OPT["lens"])
    cam.data.sensor_fit = "VERTICAL"
    scn.camera = cam
    scn.render.resolution_x, scn.render.resolution_y = W, H
    scn.render.film_transparent = True
    return cam


def place(cam, yaw):
    d, tz, cz = float(OPT["dist"]), float(OPT["target_z"]), float(OPT["cam_z"])
    a = math.radians(yaw)
    cam.location = Vector((d * math.sin(a), -d * math.cos(a), cz))
    look = Vector((0, 0, tz)) - cam.location
    cam.rotation_euler = look.to_track_quat("-Z", "Y").to_euler()


def shading(layer):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    s = scn.display.shading
    s.light = "STUDIO"
    s.show_cavity = layer in ("grey", "tex")
    s.cavity_type = "WORLD"
    s.show_shadows = False
    s.show_xray = layer == "ghost"
    s.xray_alpha = 0.3
    s.show_specular_highlight = layer != "ghost"
    if layer == "grey":
        s.color_type, s.single_color = "SINGLE", (0.72, 0.71, 0.69)
    elif layer == "ghost":
        s.color_type, s.single_color = "SINGLE", (0.45, 0.85, 1.0)
    elif layer == "tex":
        s.color_type = "TEXTURE"
    else:
        s.color_type = "VERTEX"
    scn.view_settings.view_transform = "Standard"


def set_frame(rig, f, k, pose):
    bpy.context.scene.frame_set(int(f), subframe=f - int(f))
    if not rig.animation_data.action:  # rest: nothing resets the pose
        for pb in rig.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
    if pose:
        n = int(OPT["pose_in"])
        t = 1.0 if n <= 0 else min(1.0, k / n)
        t = t * t * (3 - 2 * t)
        for name, deg in pose.items():
            pb = rig.pose.bones[name]
            q = Euler([math.radians(x) * t for x in deg], "XYZ").to_quaternion()
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = pb.rotation_quaternion @ q
        bpy.context.view_layer.update()


def joints(rig, cam):
    scn = bpy.context.scene
    res = {}
    for pb in rig.pose.bones:
        out = []
        for p in (pb.head, pb.tail):
            w = rig.matrix_world @ p
            c = world_to_camera_view(scn, cam, w)
            out.append([round(c.x * W, 1), round((1 - c.y) * H, 1), round(c.z, 3)])
        res[pb.name] = {"head": out[0], "tail": out[1], "parent": pb.parent.name if pb.parent else None}
    return res


def main():
    rig, mesh = load()
    cam = camera()
    if OPT["anim"] != "rest":
        rig.animation_data.action = bpy.data.actions[OPT["anim"]]
        for t in rig.animation_data.nla_tracks:
            t.mute = True
    else:
        rig.animation_data.action = None
        for t in rig.animation_data.nla_tracks:
            t.mute = True
    pose = json.load(open(OPT["pose"])) if OPT["pose"] else None
    n, start, step = int(OPT["frames"]), float(OPT["start"]), float(OPT["step"])
    y0, y1 = float(OPT["yaw0"]), float(OPT["yaw1"])
    layers = [x for x in OPT["layers"].split(",") if x]
    if "weights" in layers:
        weight_colours(mesh)
    frames = []
    act = rig.animation_data.action
    span = (act.frame_range[1] - act.frame_range[0]) if act else 1
    for k in range(n):
        f = start + k * step
        if act and OPT["anim"].endswith("_loop"):
            f = act.frame_range[0] + (f - act.frame_range[0]) % span
        frames.append(f)
    for layer in layers:
        os.makedirs(os.path.join(OUT, layer), exist_ok=True)
    js = []
    for k, f in enumerate(frames):
        set_frame(rig, f, k, pose)
        place(cam, y0 + (y1 - y0) * (k / max(1, n - 1)))
        bpy.context.view_layer.update()
        js.append(joints(rig, cam))
        for layer in layers:
            shading(layer)
            bpy.context.scene.render.filepath = os.path.join(OUT, layer, f"{k:04d}.png")
            bpy.ops.render.render(write_still=True)
    with open(os.path.join(OUT, "joints.json"), "w") as fh:
        json.dump({"size": [W, H], "frames": js}, fh)
    print(f"[promo_bones] {OUT} {n} frames {layers}")


main()
