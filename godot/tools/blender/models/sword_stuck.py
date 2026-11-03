"""Arena 2's sword stuck in the ground (retail 1289), in Blender: a horn of
bone rising from the ground into a cloth-wrapped grip between brass rings,
a curved steel blade above with a bright edge."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece, maple  # noqa: E402,F401
from mathutils import Matrix, Vector  # noqa: E402,F401

p = Piece()
r = p.rng
UP = Vector((0, 0, 1))


def dirv(az, tilt):
    """A direction tilt degrees off vertical, towards azimuth az (degrees)."""
    a, t = math.radians(az), math.radians(tilt)
    return Vector((math.cos(a) * math.sin(t), math.sin(a) * math.sin(t), math.cos(t)))


X, Y = Vector((1, 0, 0)), Vector((0, 1, 0))
# the bone: a curved horn from the ground, wide at its foot
p.tube([Vector((-0.1, 0, -0.03)), Vector((-0.05, 0, 0.18)), Vector((0.0, 0, 0.42))], 0.1, 0.05, mat='bone', sides=8)
p.blob(Vector((0.0, 0, 0.44)), 0.055, 'brass', scale=(1, 1, 0.5), sub=2)
for k in range(5):  # the grip, wrapped in cloth
    z0 = 0.46 + k * 0.06
    p.tube([Vector((0.0, 0, z0)), Vector((0.003, 0, z0 + 0.06))], 0.042, 0.04, mat='cloth' if k % 2 else 'clothD', sides=8)
p.blob(Vector((0.005, 0, 0.78)), 0.06, 'brass', scale=(2.0, 1.0, 0.45), sub=2)
N = 16
st = []
for i in range(N + 1):
    t = i / N
    z = 0.8 + t * 0.72
    c = Vector((0.2 * t * t, 0, z))
    w = 0.075 * (1 - t) ** 0.5 + 0.004
    st.append((c, -X * w * 0.8, X * w * (1 + 0.9 * math.sin(t * math.pi)), 0.02))
p.bladeform(st, Y, ['steel', 'steelL'], pick=lambda i, k: 1 if k in (1, 2) else 0)
p.finish('sword_stuck')
