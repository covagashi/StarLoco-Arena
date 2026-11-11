"""S35: the common skeleton's poses and the 11 base animations, shared by
every rigged character (fighter1.py, meshy_fighter.py). A rig only needs
the 20 bones of fighter1.BONES (any proportions: pose() works from each
bone's rest frame) and, for the feet-on-the-floor fix, ANKLE and TOE: the
heights of the foot bone's head and tail above the sole.
"""
import math

import bpy
from mathutils import Quaternion, Vector

ANKLE, TOE = 0.075, 0.022  # fighter1's; meshy_fighter.py sets its own
# Short arms under a big head (the Meshy chibis) can't reach over it: arms
# raised past 100 degrees also open sideways by up to this many degrees, a
# V instead of hands on the face. fighter1's long arms need none.
OVERHEAD_OUT = 0.0
# A stubby limb fused to a big body (a sack's flaps) tears the body open
# when raised far: arm raises above this many degrees scale down into it
# (meshy_summon --arm_max). 180 = no limit.
ARM_MAX = 180.0

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
        if ARM_MAX < 180:
            fwd, out = fwd * ARM_MAX / 180, out * ARM_MAX / 180
        q = Quaternion(Vector(X_AX), math.radians(-fwd))
        q = Quaternion(Vector(Y_AX), math.radians(-out * X)) @ q
        q = Quaternion(Vector(Z_AX), math.radians(tw * X)) @ q
        # an arm pointing up opens outwards about +Y (left) / -Y (right):
        # the opposite of "out", which assumes an arm hanging down
        q = Quaternion(Vector(Y_AX), math.radians(OVERHEAD_OUT * X * max(0.0, min(1.0, (fwd - 100) / 60)))) @ q
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


IDLE_ARMS = dict(arm_L=(6, 10), arm_R=(6, 10), elbow_L=18, elbow_R=18, leg_out_L=5, leg_out_R=5)


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
        lo = min(lo, pb.head.z - ANKLE, pb.tail.z - TOE)
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

    # shoot (S35c, a bow's attack): the bow arm (left) comes up level, the
    # right hand draws the string back to the cheek, holds, lets go. The bow
    # is gripped along the hand (Fighter3D: upright with the arm down), so
    # the left wrist bends up to keep it upright, belly out, with the arm raised.
    aim = dict(base, lean=-2, twist=-18, head_turn=14, arm_L=(88, 8), elbow_L=4, hand_L=-85,
               arm_R=(80, -12), elbow_R=95, leg_out_L=12, leg_out_R=10, knee_L=6, knee_R=8)
    draw = dict(aim, lean=-5, twist=-26, head_turn=20, arm_R=(86, 22), elbow_R=150, bob=-0.02)
    loose = dict(draw, twist=-22, arm_R=(70, 45), elbow_R=70, hand_R=-25, lean=-2)
    keys(rig, "shoot", [(0, base), (7, aim), (14, draw), (20, draw), (22, loose), (27, mix(loose, base, 0.3)),
                        (36, base)], False)

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
    joy = dict(lean=-8, head=12, arm_L=(150, 35), arm_R=(150, 35), elbow_L=20, elbow_R=20, knee_L=5, knee_R=5)
    hop = dict(joy, z=0.16, knee_L=25, knee_R=25, leg_L=15, leg_R=15, arm_L=(165, 25), arm_R=(165, 25))
    dip = dict(joy, bob=-0.06, knee_L=30, knee_R=30, leg_L=20, leg_R=20, lean=4)
    keys(rig, "celebrate", [(0, base), (6, dip), (11, hop), (16, dip), (21, hop), (26, dip), (36, base)], False)

    # carry: holds someone over its head (the game parents the carried one
    # to the hands); loops while carrying
    fr = []
    for i in range(0, 25, 6):
        w = 2 * math.pi * i / 24
        fr.append((i, dict(lean=-4 + math.sin(w), bob=-0.03 + 0.01 * math.cos(w), arm_L=(160, 18), arm_R=(160, 18),
                           elbow_L=40, elbow_R=40, hand_L=-30, hand_R=-30, knee_L=12, knee_R=12, head=8)))
    keys(rig, "carry", fr, True)

    # throw: from the carry pose, heave forward
    back = dict(lean=-16, bob=-0.06, arm_L=(180, 12), arm_R=(180, 12), elbow_L=55, elbow_R=55,
                knee_L=18, knee_R=18, head=12, leg_R=-10)
    toss = dict(lean=24, arm_L=(100, 15), arm_R=(100, 15), elbow_L=5, elbow_R=5, leg_L=25, knee_L=25,
                leg_R=-15, y=-0.05, bob=-0.05, head=-8)
    keys(rig, "throw", [(0, fr[0][1]), (6, back), (11, toss), (16, mix(toss, base, 0.3)), (26, base)], False)
