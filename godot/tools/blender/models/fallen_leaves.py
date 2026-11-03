"""Arena 2's fallen maple leaves (retail 127, 201, 202, 203), in Blender:
seven sharp-lobed leaves lying about, cupped, one curled up at its edge."""
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


spots = [(-0.3, 0.25), (0.05, 0.32), (0.32, 0.18), (-0.15, -0.02), (0.22, -0.1), (-0.32, -0.28), (0.08, -0.33)]
for i, (x, y) in enumerate(spots):
    M = (Matrix.Translation((x, y, 0.01)) @ Matrix.Rotation(r.uniform(0, math.tau), 4, 'Z')
         @ Matrix.Rotation(math.radians(r.uniform(-12, 12)), 4, 'X') @ Matrix.Scale(r.uniform(1.6, 2.2), 4))
    p.cupped(maple(0.1), M, ['leaf', 'leafL', 'leafD'], cup=0.6 if i == 2 else 0.25, thick=0.008,
             pick=lambda k, i=i: [0, 1, 0, 2][(k // 5 + i) % 4])
p.finish('fallen_leaves', fit='max')
