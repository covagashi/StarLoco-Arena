"""Arena 5's grass tuft (retail 1754), in Blender: three clumps of thin
curving blades, the tall ones light, the short ones dark."""
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


for cx, cy, n, hmax in [(-0.15, 0.05, 22, 0.4), (0.18, -0.02, 18, 0.34), (0.0, 0.2, 14, 0.28)]:
    for i in range(n):
        az = r.uniform(0, 360)
        h = r.uniform(0.45, 1.0) * hmax
        p.strip(Vector((cx, cy, 0)) + dirv(az, 90) * 0.03, dirv(az, r.uniform(3, 25)), dirv(az, 90), h, 0.06,
                ['bladeL' if h > hmax * 0.8 else 'blade' if h > hmax * 0.6 else 'bladeD'], bend=r.uniform(0.2, 0.6),
                segs=4, shape='blade')
p.finish('grass_tuft', fit='max')
