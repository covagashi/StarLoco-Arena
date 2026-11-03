"""Arena 6's strap grass (retail 259), in Blender: long ribbon leaves
with rounded tips arching out of two crowns, banded with brown."""
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


for cx, cy, n in [(-0.15, 0.05, 10), (0.2, -0.05, 8)]:
    for i in range(n):
        az = i * 360 / n + r.uniform(-20, 20)
        tl = r.uniform(5, 35)
        mats = ['strapL', 'strap', 'band', 'strap'] if tl < 20 else ['strap', 'strapD', 'band', 'strapD']
        p.strip(Vector((cx, cy, 0)), dirv(az, tl), dirv(az, 90), r.uniform(0.75, 1.2), r.uniform(0.08, 0.11),
                mats, bend=r.uniform(0.5, 1.1), segs=8, shape='strap', fold=0.2, twist=r.uniform(-0.6, 0.6))
p.finish('strap_grass', fit='max')
