"""Arena 1's loose snow (retail 503, 504), in Blender: four small soft
heaps on the ground, each with a crumb of snow beside it."""
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


for x, y, s in [(-0.22, 0.18, 1.0), (0.24, 0.2, 0.8), (-0.2, -0.2, 0.85), (0.22, -0.18, 1.05)]:
    p.lumps([((x, y, 0), 0.13 * s, (1.3, 1.0, 0.75)), ((x + 0.04, y + 0.03, 0.04), 0.08 * s, (1, 1, 0.9))], ['snow'], res=0.025)
    p.lumps([((x + 0.13 * s, y - 0.05, 0), 0.04 * s, (1, 1, 0.6))], ['snow'], res=0.015)
p.finish('loose_snow', fit='max')
