"""Arena 1's snow mound (retail 505), in Blender: a soft lumpy drift,
higher at one end, with a small lump beside it (the game smooths snow)."""
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


# a drift: a high crest at one end running down, lumps on its back
balls = [((0, 0, 0.03), 0.4, (1.3, 0.9, 0.6)), ((-0.3, 0.04, 0.05), 0.3, (1.0, 0.9, 0.75)),
         ((0.36, -0.06, 0.02), 0.25, (1.2, 0.8, 0.7)), ((0.1, 0.22, 0.02), 0.2, (1.1, 0.8, 0.7)),
         ((-0.05, -0.2, 0.02), 0.22, (1.2, 0.8, 0.7)), ((-0.18, -0.02, 0.2), 0.14, (1, 1, 0.6)),
         ((0.12, 0.05, 0.16), 0.12, (1, 1, 0.6))]
p.lumps(balls, ['snow'])
p.lumps([((0.55, 0.32, 0), 0.09, (1.2, 1, 0.6))], ['snow'], res=0.025)
p.finish('mound', fit='max')
