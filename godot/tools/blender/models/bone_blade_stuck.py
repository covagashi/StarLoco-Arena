"""Arena 2's bone blade stuck in the ground (retail 2006), in Blender: a
curved blade of bone with a toothed back, its point buried and stained
green, a brass guard, a wrapped grip and a brass pommel."""
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
N = 24
st = []
for i in range(N + 1):
    t = i / N                      # 0: the buried point, 1: the guard
    z = -0.08 + t * 1.2
    c = Vector((0.1 * math.sin(t * 2.6) - 0.05, 0, z))
    w = 0.03 + 0.16 * min(1.0, t * 1.6) ** 0.7
    back = w * (1.35 if (i % 2 and 0.15 < t < 0.95) else 1.0)   # teeth on the back
    st.append((c, -X * w * 0.75, X * back, 0.035 * (0.4 + 0.6 * min(1.0, t * 2))))
p.bladeform(st, Y, ['bone', 'boneD', 'boneG'], pick=lambda i, k: 2 if i < 4 else 0)
top = st[-1][0]
p.blob(top + Vector((0, 0, 0.02)), 0.07, 'brass', scale=(2.6, 0.8, 0.45), sub=2)
for k in range(5):
    z0 = top.z + 0.05 + k * 0.07
    p.tube([Vector((top.x, 0, z0)), Vector((top.x + 0.004, 0, z0 + 0.07))], 0.042, 0.04, mat='grip' if k % 2 else 'gripL', sides=8)
p.blob(Vector((top.x + 0.01, 0, top.z + 0.45)), 0.06, 'brass', sub=2)
p.finish('bone_blade_stuck')
