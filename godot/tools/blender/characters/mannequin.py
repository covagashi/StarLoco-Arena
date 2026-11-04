"""S35 step 1: the common rig, its base animations and a neutral doll to
show them. Every fighter, summon and coach will share this skeleton, so an
animation is made once and serves all 12 classes in all 8 directions (the
game turns the model).

    blender -b -P tools/blender/characters/mannequin.py -- [out.glb]

Blender is z-up and the doll faces -Y (glTF: +Z, the way the S33 prototype
and the arenas expect it); .L is the doll's left, +X. 1 unit = 1 cell, the
kit's metre. Height 1.30 without a hat: ~70 px at game zoom, as the style
sheet asks; the head is ~37 % of it and a class hat takes it to ~45 %.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.normpath(os.path.join(HERE, "..", "..", "..", "art", "characters", "out", "mannequin.glb"))
FPS = 30

# ---------------------------------------------------------------- skeleton

BONES = [  # name, head, tail, parent
    ("root", (0, 0, 0), (0, 0.15, 0), None),
    ("hips", (0, 0, 0.44), (0, 0, 0.56), "root"),
    ("spine", (0, 0, 0.56), (0, 0, 0.67), "hips"),
    ("chest", (0, 0, 0.67), (0, 0, 0.79), "spine"),
    ("neck", (0, 0, 0.79), (0, 0, 0.85), "chest"),
    ("head", (0, 0, 0.85), (0, 0, 1.30), "neck"),
]
for S, X in (("L", 1), ("R", -1)):
    BONES += [
        (f"shoulder.{S}", (0.05 * X, 0, 0.76), (0.15 * X, 0, 0.76), "chest"),
        (f"upper_arm.{S}", (0.15 * X, 0, 0.76), (0.20 * X, 0, 0.61), f"shoulder.{S}"),
        (f"forearm.{S}", (0.20 * X, 0, 0.61), (0.225 * X, -0.02, 0.47), f"upper_arm.{S}"),
        (f"hand.{S}", (0.225 * X, -0.02, 0.47), (0.235 * X, -0.03, 0.38), f"forearm.{S}"),
        (f"thigh.{S}", (0.085 * X, 0, 0.44), (0.095 * X, 0, 0.25), "hips"),
        (f"shin.{S}", (0.095 * X, 0, 0.25), (0.095 * X, 0.01, 0.07), f"thigh.{S}"),
        (f"foot.{S}", (0.095 * X, 0.01, 0.07), (0.095 * X, -0.11, 0.025), f"shin.{S}"),
    ]


def build_armature():
    arm = bpy.data.armatures.new("rig")
    ob = bpy.data.objects.new("rig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, parent in BONES:
        b = arm.edit_bones.new(name)
        b.head, b.tail = Vector(h), Vector(t)
        b.roll = 0
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = (b.parent.tail - b.head).length < 1e-6
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


# ---------------------------------------------------------------- body

def mat(name, hexcol, rough=0.8):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    c = tuple(int(hexcol[i:i + 2], 16) / 255 for i in (0, 2, 4))
    c = tuple(x ** 2.2 for x in c) + (1,)  # sRGB → linear
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = c
    bsdf.inputs["Roughness"].default_value = rough
    return m


def blob(bm, centre, radii, sub=3):
    g = bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in g["verts"]:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(centre)


def capsule(bm, a, b, ra, rb, steps=6):
    """A tapering chain of spheres from a to b: the remesh fuses it."""
    a, b = Vector(a), Vector(b)
    for i in range(steps + 1):
        k = i / steps
        r = ra + (rb - ra) * k
        blob(bm, a.lerp(b, k), (r, r, r), sub=2)


def bone(name):
    for n, h, t, _ in BONES:
        if n == name:
            return Vector(h), Vector(t)


def build_body():
    bm = bmesh.new()
    blob(bm, (0, 0.005, 0.56), (0.135, 0.115, 0.15))   # belly and pelvis
    blob(bm, (0, 0, 0.69), (0.15, 0.115, 0.115))       # chest
    capsule(bm, (0, 0, 0.74), (0, 0, 0.88), 0.055, 0.05, 3)  # neck
    for S in "LR":
        X = 1 if S == "L" else -1
        capsule(bm, (0.08 * X, 0, 0.745), (0.15 * X, 0, 0.755), 0.06, 0.058, 3)  # shoulder
        capsule(bm, *bone(f"upper_arm.{S}"), 0.055, 0.046)
        capsule(bm, *bone(f"forearm.{S}"), 0.046, 0.04)
        h, t = bone(f"hand.{S}")
        blob(bm, h.lerp(t, 0.55), (0.035, 0.05, 0.06))            # mitten
        thumb = h.lerp(t, 0.3) + Vector((-0.012 * X, -0.035, 0))
        capsule(bm, h.lerp(t, 0.2) + Vector((0, -0.02, 0)), thumb, 0.02, 0.016, 3)
        capsule(bm, (0.085 * X, 0, 0.47), (0.095 * X, 0, 0.25), 0.075, 0.06)  # thigh
        capsule(bm, *bone(f"shin.{S}"), 0.06, 0.05)
        blob(bm, (0.095 * X, -0.03, 0.045), (0.062, 0.1, 0.05))   # boot
    me = bpy.data.meshes.new("body")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("body", me)
    bpy.context.collection.objects.link(ob)
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.011
    apply(ob, m)
    m = ob.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
    m.iterations = 6
    m.smooth_type = "LENGTH_WEIGHTED"
    m.use_only_smooth = True
    apply(ob, m)
    m = ob.modifiers.new("lod", "DECIMATE")
    m.ratio = 0.1
    apply(ob, m)
    return ob


def build_head():
    bm = bmesh.new()
    blob(bm, (0, 0, 1.065), (0.25, 0.235, 0.235), sub=4)       # skull
    blob(bm, (0, -0.07, 0.985), (0.19, 0.16, 0.13), sub=3)     # cheeks and jaw
    blob(bm, (0, -0.235, 1.03), (0.03, 0.025, 0.026), sub=2)   # nose
    for X in (1, -1):
        blob(bm, (0.235 * X, -0.01, 1.05), (0.035, 0.03, 0.05), sub=2)  # ear
    me = bpy.data.meshes.new("head")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("head", me)
    bpy.context.collection.objects.link(ob)
    m = ob.modifiers.new("remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.01
    apply(ob, m)
    m = ob.modifiers.new("smooth", "CORRECTIVE_SMOOTH")
    m.iterations = 4
    m.use_only_smooth = True
    apply(ob, m)
    m = ob.modifiers.new("lod", "DECIMATE")
    m.ratio = 0.3
    apply(ob, m)
    return ob


def build_eyes():
    """Two dark ovals sunk into the face: they tell where the doll looks
    from every direction, and a class swaps them for its own face."""
    bm = bmesh.new()
    for X in (1, -1):
        blob(bm, (0.085 * X, -0.205, 1.075), (0.03, 0.03, 0.045), sub=2)
        blob(bm, (0.072 * X, -0.228, 1.1), (0.008, 0.005, 0.009), sub=1)  # glint
    me = bpy.data.meshes.new("eyes")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("eyes", me)
    bpy.context.collection.objects.link(ob)
    return ob


def apply(ob, m):
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)


def paint(body, head, eyes):
    """Materials by height: boots, trousers, belt, tunic, skin."""
    skin, tunic, belt = mat("skin", "e0b088"), mat("tunic", "4d6e5f"), mat("belt", "6b4a33")
    pants, boots = mat("pants", "8a7a62"), mat("boots", "4a3222")
    eye, glint = mat("eye", "2a1d14", 0.3), mat("glint", "fff6e6", 0.3)
    me = body.data
    # clean cuts where one material meets the next, not a ragged edge of
    # whole remesh faces
    bm = bmesh.new()
    bm.from_mesh(me)
    for z in (0.115, 0.38, 0.425, 0.465, 0.6, 0.8):
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1))
    bm.to_mesh(me)
    bm.free()
    for m in (skin, tunic, belt, pants, boots):
        me.materials.append(m)
    for p in me.polygons:
        c = p.center
        arm = abs(c.x) > 0.165 and c.z > 0.36
        if c.z < 0.115 and not arm:
            p.material_index = 4
        elif arm:
            p.material_index = 1 if c.z > 0.6 else 0          # short sleeve
        elif c.z < 0.38:
            p.material_index = 3
        elif c.z < 0.425:
            p.material_index = 1                               # tunic hem
        elif c.z < 0.465:
            p.material_index = 2
        elif c.z < 0.8:
            p.material_index = 1
        else:
            p.material_index = 0
    head.data.materials.append(skin)
    eyes.data.materials.append(eye)
    eyes.data.materials.append(glint)
    for p in eyes.data.polygons:
        p.material_index = 1 if p.center.y < -0.226 and p.center.z > 1.088 else 0
    for o in (body, head, eyes):
        for p in o.data.polygons:
            p.use_smooth = True


def skin_to(rig, body, head, eyes):
    """Body: Blender's automatic (heat) weights. Head and eyes ride the
    head bone alone, so the face never smears."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for o in (head, eyes):
        vg = o.vertex_groups.new(name="head")
        vg.add(range(len(o.data.vertices)), 1.0, "REPLACE")
        o.parent = rig
        m = o.modifiers.new("rig", "ARMATURE")
        m.object = rig
    # the neck's top ring goes to the head too, so it turns with it
    for v in body.data.vertices:
        if v.co.z > 0.86:
            for g in list(v.groups):
                body.vertex_groups[g.group].remove([v.index])
            body.vertex_groups["head"].add([v.index], 1.0, "REPLACE")


# ---------------------------------------------------------------- poses
# A pose is {bone: rotation}. Turning a bone about an armature axis means
# opposite things for bones pointing up and down, so pose() speaks in body
# terms (lean, arm forward, knee bend) and turns them into rotations.

REST = {}


def _rest(rig):
    for b in rig.data.bones:
        REST[b.name] = b.matrix_local.to_quaternion()


def q_world(name, axis, deg):
    """The local rotation of bone name that turns it by deg about a
    direction given in armature space (rest frame)."""
    r = REST[name]
    return r.inverted() @ Quaternion(Vector(axis), math.radians(deg)) @ r


X_AX, Y_AX, Z_AX = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def side(S):
    return 1 if S == "L" else -1


def pose(**kw):
    """Body-language pose → {bone: quaternion}, {bone: location}.

    lean      forwards (+) / back (−), split over hips, spine and chest
    twist     the torso turns to its left (+)
    tilt      the torso leans to its left (+)
    head      looks up (+), head_turn to its left, head_tilt
    arm_<S>   (forward, out, twist): forward raises it in front (90 =
              horizontal, 180 = overhead), out lifts it to the side
    elbow_<S> bend in degrees
    hand_<S>  wrist bend (forward)
    leg_<S>   forward swing of the thigh, knee_<S> bend, foot_<S> toes up (+)
    leg_out_<S> spread
    bob       hips up (+) in units; drop root (z), x/y move the whole body
    fall      the root tips over backwards (death), roll sideways
    """
    g = kw.get
    rot, loc = {}, {}
    lean, twist, tilt = g("lean", 0), g("twist", 0), g("tilt", 0)
    for b, k in (("hips", 0.2), ("spine", 0.4), ("chest", 0.4)):
        q = Quaternion()
        q = Quaternion(Vector(X_AX), math.radians(lean * k)) @ q
        q = Quaternion(Vector(Z_AX), math.radians(twist * k)) @ q
        q = Quaternion(Vector(Y_AX), math.radians(-tilt * k)) @ q
        rot[b] = REST[b].inverted() @ q @ REST[b]
    hq = Quaternion(Vector(X_AX), math.radians(-g("head", 0)))
    hq = Quaternion(Vector(Z_AX), math.radians(g("head_turn", 0))) @ hq
    hq = Quaternion(Vector(Y_AX), math.radians(-g("head_tilt", 0))) @ hq
    rot["head"] = REST["head"].inverted() @ hq @ REST["head"]
    for S in "LR":
        X = side(S)
        fwd, out, tw = (tuple(g(f"arm_{S}", (0, 0, 0))) + (0, 0, 0))[:3]
        q = Quaternion(Vector(X_AX), math.radians(-fwd))
        q = Quaternion(Vector(Y_AX), math.radians(-out * X)) @ q
        q = Quaternion(Vector(Z_AX), math.radians(tw * X)) @ q
        rot[f"upper_arm.{S}"] = REST[f"upper_arm.{S}"].inverted() @ q @ REST[f"upper_arm.{S}"]
        rot[f"forearm.{S}"] = q_world(f"forearm.{S}", X_AX, -g(f"elbow_{S}", 10))
        rot[f"hand.{S}"] = q_world(f"hand.{S}", X_AX, -g(f"hand_{S}", 0))
        lq = Quaternion(Vector(X_AX), math.radians(-g(f"leg_{S}", 0)))
        lq = Quaternion(Vector(Y_AX), math.radians(-g(f"leg_out_{S}", 0) * X)) @ lq
        rot[f"thigh.{S}"] = REST[f"thigh.{S}"].inverted() @ lq @ REST[f"thigh.{S}"]
        rot[f"shin.{S}"] = q_world(f"shin.{S}", X_AX, g(f"knee_{S}", 0))
        rot[f"foot.{S}"] = q_world(f"foot.{S}", X_AX, -g(f"foot_{S}", 0))
    rq = Quaternion(Vector(X_AX), math.radians(-g("fall", 0)))
    rq = Quaternion(Vector(Y_AX), math.radians(g("roll", 0))) @ rq
    rot["root"] = REST["root"].inverted() @ rq @ REST["root"]
    # locations are in the bone's rest frame too
    loc["hips"] = REST["hips"].inverted() @ Vector((0, 0, g("bob", 0)))
    loc["root"] = REST["root"].inverted() @ Vector((g("x", 0), g("y", 0), g("z", 0)))
    return rot, loc


IDLE_ARMS = dict(arm_L=(4, 8), arm_R=(4, 8), elbow_L=14, elbow_R=14)


def keys(rig, name, frames, loop):
    """frames: [(frame, pose kwargs)] → an action pushed to its own NLA
    track, so the exporter writes one glTF animation per action."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, kw in frames:
        set_pose(rig, kw)
        if not kw.get("z") and not kw.get("fall"):  # grounded: soles on the floor
            set_pose(rig, dict(kw, z=-sole(rig)))
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name + ("_loop" if loop else "")
    strip = track.strips.new(track.name, int(frames[0][0]), act)
    strip.name = track.name
    rig.animation_data.action = None


def set_pose(rig, kw):
    rot, loc = pose(**kw)
    for pb in rig.pose.bones:
        pb.rotation_quaternion = rot.get(pb.name, Quaternion())
        pb.location = loc.get(pb.name, Vector())
    bpy.context.view_layer.update()


def sole(rig):
    """Height of the lowest point of either boot (heel under the ankle,
    toe under the foot bone's tail) in the current pose."""
    lo = 1e9
    for S in "LR":
        pb = rig.pose.bones[f"foot.{S}"]
        lo = min(lo, pb.head.z - 0.07, pb.tail.z - 0.025)
    return lo


def mix(a, b, k):
    """Blend two pose dicts (numbers and tuples)."""
    out = {}
    for key in set(a) | set(b):
        va, vb = a.get(key), b.get(key)
        if isinstance(va or vb, tuple):
            va = tuple(va or (0, 0, 0)) + (0, 0, 0)
            vb = tuple(vb or (0, 0, 0)) + (0, 0, 0)
            out[key] = tuple(x + (y - x) * k for x, y in zip(va[:3], vb[:3]))
        else:
            out[key] = (va or 0) + ((vb or 0) - (va or 0)) * k
    return out


def animate(rig):
    _rest(rig)
    base = dict(IDLE_ARMS)

    # idle: breathing, a slow sway, the head looks about a little
    fr = []
    for i in range(0, 49, 6):
        w = 2 * math.pi * i / 48
        fr.append((i, dict(base, bob=-0.008 + 0.008 * math.cos(2 * w), lean=1.5 + 1.5 * math.sin(w),
                           tilt=1.5 * math.sin(w), head=-2 * math.sin(w + 1), head_turn=6 * math.sin(w),
                           arm_L=(4 + 2 * math.sin(w + 0.5), 8), arm_R=(4 + 2 * math.sin(w + 0.5), 8),
                           knee_L=3, knee_R=3)))
    keys(rig, "idle", fr, True)

    # walk: in place, 24 frames a cycle (the game slides the root along)
    fr = []
    for i in range(0, 25, 2):
        w = 2 * math.pi * i / 24
        s = math.sin(w)
        fr.append((i, dict(lean=6, twist=-6 * s, bob=-0.02 + 0.025 * abs(math.cos(w)),
                           leg_L=30 * s, leg_R=-30 * s,
                           knee_L=max(0, -40 * math.cos(w)) + 8, knee_R=max(0, 40 * math.cos(w)) + 8,
                           foot_L=12 * s, foot_R=-12 * s,
                           arm_L=(-28 * s, 8), arm_R=(28 * s, 8),
                           elbow_L=20 + 10 * max(0, -s), elbow_R=20 + 10 * max(0, s),
                           head=-3, head_turn=3 * s)))
    keys(rig, "walk", fr, True)

    # cast: wind-up, the staff hand thrusts forward at frame 12, settles
    wind = dict(base, lean=-8, twist=-20, arm_R=(60, 20, -30), elbow_R=70, arm_L=(10, 20), elbow_L=30,
                leg_L=10, leg_R=-8, knee_L=10, knee_R=14, bob=-0.03, head=4)
    shot = dict(base, lean=14, twist=18, arm_R=(95, 5), elbow_R=5, hand_R=-25, arm_L=(-15, 25), elbow_L=25,
                leg_L=16, leg_R=-14, knee_L=18, knee_R=6, bob=-0.04, head=-6)
    keys(rig, "cast", [(0, base), (7, wind), (12, shot), (18, mix(shot, base, 0.25)), (30, base)], False)

    # melee: overhead swing with the right arm, a step in
    up = dict(base, lean=-10, twist=-25, arm_R=(165, 15), elbow_R=50, arm_L=(30, 15), elbow_L=40,
              leg_L=12, knee_L=12, bob=-0.01, head=6)
    down = dict(base, lean=28, twist=22, arm_R=(40, 0), elbow_R=15, hand_R=20, arm_L=(-25, 20), elbow_L=30,
                leg_L=30, knee_L=35, leg_R=-15, knee_R=10, y=-0.08, bob=-0.07, head=-10)
    keys(rig, "melee", [(0, base), (8, up), (12, down), (16, mix(down, base, 0.2)), (24, base)], False)

    # hit: knocked back, then recovers (the game adds the flash and shake)
    hit = dict(base, lean=-18, head=-22, head_tilt=8, arm_L=(35, 30), arm_R=(30, 35), elbow_L=40, elbow_R=40,
               knee_L=12, knee_R=12, bob=-0.03, y=0.05)
    keys(rig, "hit", [(0, base), (3, hit), (8, mix(hit, base, 0.6)), (15, base)], False)

    # die: knees give, falls on its back, a small bounce, still
    sag = dict(base, lean=20, head=25, arm_L=(-10, 25), arm_R=(-10, 25), elbow_L=30, elbow_R=30,
               knee_L=45, knee_R=40, leg_L=25, leg_R=20, bob=-0.12)
    flat = dict(lean=-5, head=-15, head_turn=25, arm_L=(-20, 75), arm_R=(-10, 60), elbow_L=25, elbow_R=40,
                leg_L=10, leg_R=-5, knee_L=20, knee_R=8, fall=88, z=0.06, y=0.1)
    bounce = dict(flat, fall=80, z=0.09)
    keys(rig, "die", [(0, base), (6, mix(base, sag, 0.6)), (12, sag), (22, flat), (26, bounce),
                      (30, flat), (40, flat)], False)

    # jump (also teleport): crouch, up, land, settle; z is height in cells
    crouch = dict(base, lean=18, bob=-0.12, leg_L=40, leg_R=40, knee_L=70, knee_R=70, foot_L=-25, foot_R=-25,
                  arm_L=(-30, 15), arm_R=(-30, 15), elbow_L=20, elbow_R=20, head=-10)
    air = dict(base, lean=-4, z=0.45, leg_L=20, leg_R=8, knee_L=40, knee_R=30, arm_L=(70, 35), arm_R=(70, 35),
               elbow_L=20, elbow_R=20, head=5)
    land = dict(crouch, bob=-0.09)
    keys(rig, "jump", [(0, base), (6, crouch), (12, air), (16, dict(air, z=0.35)), (20, dict(base, z=0.0)),
                       (23, land), (32, base)], False)

    # celebrate: both fists up and two hops
    joy = dict(lean=-8, head=12, arm_L=(25, 140), arm_R=(25, 140), elbow_L=20, elbow_R=20, knee_L=5, knee_R=5)
    hop = dict(joy, z=0.16, knee_L=25, knee_R=25, leg_L=15, leg_R=15, arm_L=(15, 155), arm_R=(15, 155))
    dip = dict(joy, bob=-0.06, knee_L=30, knee_R=30, leg_L=20, leg_R=20, lean=4)
    keys(rig, "celebrate", [(0, base), (6, dip), (11, hop), (16, dip), (21, hop), (26, dip), (36, base)], False)

    # carry: holds someone over its head (the game parents the carried one
    # to the hands); loops while carrying
    fr = []
    for i in range(0, 25, 6):
        w = 2 * math.pi * i / 24
        fr.append((i, dict(lean=-4 + math.sin(w), bob=-0.03 + 0.01 * math.cos(w), arm_L=(40, 125), arm_R=(40, 125),
                           elbow_L=60, elbow_R=60, hand_L=-20, hand_R=-20, knee_L=12, knee_R=12, head=8)))
    keys(rig, "carry", fr, True)

    # throw: from the carry pose, heave forward
    back = dict(lean=-16, bob=-0.06, arm_L=(20, 135), arm_R=(20, 135), elbow_L=70, elbow_R=70,
                knee_L=18, knee_R=18, head=12, leg_R=-10)
    toss = dict(lean=24, arm_L=(110, 30), arm_R=(110, 30), elbow_L=5, elbow_R=5, leg_L=25, knee_L=25,
                leg_R=-15, y=-0.05, bob=-0.05, head=-8)
    keys(rig, "throw", [(0, fr[0][1]), (6, back), (11, toss), (16, mix(toss, base, 0.3)), (26, base)], False)


# ---------------------------------------------------------------- export

def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    rig = build_armature()
    body, head, eyes = build_body(), build_head(), build_eyes()
    paint(body, head, eyes)
    skin_to(rig, body, head, eyes)
    animate(rig)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_force_sampling=True, export_frame_step=1,
                              export_def_bones=False, export_yup=True)
    tris = sum(len(p.vertices) - 2 for o in (body, head, eyes) for p in o.data.polygons)
    print(f"[mannequin] {OUT}: {len(BONES)} bones, {tris} tris, "
          f"{len(rig.animation_data.nla_tracks)} animations")


main()
