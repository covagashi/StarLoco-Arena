"""S35: the short skeleton of the summons without two arms (chick 8005,
sheep 8006, pangolin 8004; owner, 2026-11-10) and their versions of the
10 base animations, under the same names as rig_anims.py so the game
plays them the same way.

Bones: root, hips → chest (the body), head, one leg.<id> + foot.<id>
chain per leg (front legs hang from the chest, the rest from the hips)
and an optional tail.0 … tail.n. The joints come from a JSON
(meshy_summon.py --shape=creature):

    {"hips": [x, y, z], "chest": […], "neck": […], "top": […],
     "legs": {"L": [hip, knee, toe], …}, "front": ["FL", "FR"],
     "tail": [[x, y, z], …]}
"""
import math

import bpy
from mathutils import Quaternion, Vector

import rig_anims
from rig_anims import X_AX, Y_AX, Z_AX, mix

REST = rig_anims.REST


def bones_from(J):
    V = lambda k: Vector(J[k])
    B = [("root", Vector((0, 0, 0)), Vector((0, 0.15, 0)), None),
         ("hips", V("hips"), V("chest"), "root"),
         ("chest", V("chest"), V("neck"), "hips"),
         ("head", V("neck"), V("top"), "chest")]
    front = set(J.get("front", []))
    for leg, (hip, knee, toe) in J["legs"].items():
        parent = "chest" if leg in front else "hips"
        B += [(f"leg.{leg}", Vector(hip), Vector(knee), parent),
              (f"foot.{leg}", Vector(knee), Vector(toe), f"leg.{leg}")]
    tail = [Vector(p) for p in J.get("tail", [])]
    for i in range(len(tail) - 1):
        B.append((f"tail.{i}", tail[i], tail[i + 1], "hips" if i == 0 else f"tail.{i - 1}"))
    return B


def legs(rig):
    return [b.name[4:] for b in rig.data.bones if b.name.startswith("leg.")]


def pose(**kw):
    """lean forwards (+), roll to its left (+), bob (hips up), head (up +),
    head_turn, leg_<id> forward swing, knee_<id> bend, tail (to its left +),
    tail_up, x/y/z root move, fall (tips over backwards), fall_roll."""
    g = kw.get
    rot, loc = {}, {}
    for b, k in (("hips", 0.5), ("chest", 0.5)):
        q = Quaternion(Vector(X_AX), math.radians(g("lean", 0) * k))
        q = Quaternion(Vector(Y_AX), math.radians(-g("roll", 0) * k)) @ q
        rot[b] = REST[b].inverted() @ q @ REST[b]
    hq = Quaternion(Vector(X_AX), math.radians(-g("head", 0)))
    hq = Quaternion(Vector(Z_AX), math.radians(g("head_turn", 0))) @ hq
    rot["head"] = REST["head"].inverted() @ hq @ REST["head"]
    for name in REST:
        if name.startswith("leg."):
            i = name[4:]
            rot[name] = rig_anims.q_world(name, X_AX, -g(f"leg_{i}", 0))
            rot[f"foot.{i}"] = rig_anims.q_world(f"foot.{i}", X_AX, g(f"knee_{i}", 0))
        elif name.startswith("tail."):
            q = Quaternion(Vector(Z_AX), math.radians(g("tail", 0)))
            q = Quaternion(Vector(X_AX), math.radians(g("tail_up", 0))) @ q
            rot[name] = REST[name].inverted() @ q @ REST[name]
    rq = Quaternion(Vector(X_AX), math.radians(-g("fall", 0)))
    rq = Quaternion(Vector(Y_AX), math.radians(g("fall_roll", 0))) @ rq
    rot["root"] = REST["root"].inverted() @ rq @ REST["root"]
    loc["hips"] = REST["hips"].inverted() @ Vector((0, 0, g("bob", 0)))
    loc["root"] = REST["root"].inverted() @ Vector((g("x", 0), g("y", 0), g("z", 0)))
    return rot, loc


def set_pose(rig, kw):
    rot, loc = pose(**kw)
    for pb in rig.pose.bones:
        pb.rotation_quaternion = rot.get(pb.name, Quaternion())
        pb.location = loc.get(pb.name, Vector())
    bpy.context.view_layer.update()


def sole(rig):
    return min(rig.pose.bones[f"foot.{i}"].tail.z for i in legs(rig))


def keys(rig, name, frames, loop):
    """As rig_anims.keys: one action per NLA track, soles on the floor
    unless the pose is in the air (z) or falling."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    for f, kw in frames:
        set_pose(rig, kw)
        if not kw.get("z") and not kw.get("fall") and not kw.get("fall_roll"):
            set_pose(rig, dict(kw, z=-sole(rig)))
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    track = rig.animation_data.nla_tracks.new()
    track.name = name + ("_loop" if loop else "")
    strip = track.strips.new(track.name, int(frames[0][0]), act)
    strip.name = track.name
    rig.animation_data.action = None


def gait(rig, phase_of, amp, knee):
    """leg_<id> / knee_<id> for a stride at angle w: each leg swings with
    its own phase (biped: opposite; quadruped: diagonal pairs together)."""
    def at(w):
        out = {}
        for i in legs(rig):
            s = math.sin(w + phase_of(i))
            out[f"leg_{i}"] = amp * s
            out[f"knee_{i}"] = max(0.0, -knee * math.cos(w + phase_of(i)))
        return out
    return at


def animate(rig):
    rig_anims._rest(rig)
    ids = legs(rig)
    quad = len(ids) >= 4
    # biped: L and R opposite; quadruped: FL with BR, FR with BL
    phase = {"L": 0, "R": math.pi, "FL": 0, "BR": 0, "FR": math.pi, "BL": math.pi}
    stride = gait(rig, lambda i: phase.get(i, 0), 22 if quad else 28, 30)
    bend = lambda deg: {f"knee_{i}": deg for i in ids} | {f"leg_{i}": deg / 2 for i in ids}
    base = {}

    # idle: breathing, a slow sway, the head looks about, the tail swishes
    fr = []
    for i in range(0, 49, 6):
        w = 2 * math.pi * i / 48
        fr.append((i, dict(bob=-0.01 + 0.012 * math.cos(2 * w), roll=2 * math.sin(w), lean=1.5 * math.sin(w),
                           head=3 * math.sin(w + 1), head_turn=8 * math.sin(w), tail=12 * math.sin(w))))
    keys(rig, "idle", fr, True)

    # walk: in place; a biped waddles side to side, a quadruped bobs
    fr = []
    for i in range(0, 25, 3):
        w = 2 * math.pi * i / 24
        kw = dict(stride(w), lean=4, bob=0.02 * abs(math.cos(w)), head=-2, tail=10 * math.sin(w))
        if not quad:
            kw["roll"] = 7 * math.sin(w)
        fr.append((i, kw))
    keys(rig, "walk", fr, True)

    # cast: rears back, then thrusts the head up and forward
    wind = dict(bend(25), lean=-14, head=15, bob=-0.05, tail_up=20)
    shot = dict(lean=16, head=-5, y=-0.06, tail_up=-10)
    keys(rig, "cast", [(0, base), (7, wind), (12, shot), (18, mix(shot, base, 0.25)), (30, base)], False)

    # melee: winds up, then a lunge, head first
    up = dict(bend(30), lean=-16, head=18, bob=-0.05, y=0.05)
    down = dict(lean=30, head=-20, y=-0.16, bob=-0.03)
    keys(rig, "melee", [(0, base), (8, up), (12, down), (16, mix(down, base, 0.2)), (24, base)], False)

    # hit: knocked back and squashed, recovers
    hit = dict(bend(20), lean=-20, head=-15, roll=6, bob=-0.05, y=0.06, tail=-20)
    keys(rig, "hit", [(0, base), (3, hit), (8, mix(hit, base, 0.6)), (15, base)], False)

    # die: sags, rolls onto its side, a small bounce, still
    sag = dict(bend(40), lean=12, head=-20, bob=-0.1)
    flat = dict(bend(15), head=-25, fall_roll=85, z=0.04)
    bounce = dict(flat, fall_roll=78, z=0.07)
    keys(rig, "die", [(0, base), (6, mix(base, sag, 0.6)), (12, sag), (22, flat), (26, bounce),
                      (30, flat), (40, flat)], False)

    # jump (also teleport): crouch, up, land, settle
    crouch = dict(bend(50), lean=14, bob=-0.1, head=-10, tail_up=-15)
    air = dict(bend(15), lean=-6, z=0.45, head=8, tail_up=25)
    land = dict(crouch, bob=-0.08)
    keys(rig, "jump", [(0, base), (6, crouch), (12, air), (16, dict(air, z=0.35)), (20, dict(base, z=0.0)),
                       (23, land), (32, base)], False)

    # celebrate: two hops, head up, tail wagging
    hop = dict(bend(20), z=0.16, head=18, lean=-8, tail=25, tail_up=20)
    dip = dict(bend(40), bob=-0.06, head=10, tail=-25)
    keys(rig, "celebrate", [(0, base), (6, dip), (11, hop), (16, dip), (21, hop), (26, dip), (36, base)], False)

    # carry: a summon is carried, it does not carry; a crouched idle
    fr = []
    for i in range(0, 25, 6):
        w = 2 * math.pi * i / 24
        fr.append((i, dict(bend(20), bob=-0.03 + 0.01 * math.cos(w), head=6 + 3 * math.sin(w), tail=10 * math.sin(w))))
    keys(rig, "carry", fr, True)

    # throw: a short shove forward
    back = dict(bend(25), lean=-12, head=10, bob=-0.04)
    toss = dict(lean=22, head=-10, y=-0.08)
    keys(rig, "throw", [(0, fr[0][1]), (6, back), (11, toss), (16, mix(toss, base, 0.3)), (26, base)], False)
