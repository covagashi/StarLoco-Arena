"""Arena 2's spiky grass (retail 246), in Blender: a tussock of long
pointed blades fanning from one root, curving out, banded light and dark."""
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


for i in range(36):
    az = i * 137.5 + r.uniform(-20, 20)
    tl = r.uniform(4, 32)
    out = dirv(az, 90)
    p.strip(Vector((0, 0, 0)), dirv(az, tl), out, r.uniform(0.75, 1.35), r.uniform(0.11, 0.16),
            ['blade', 'bladeL'] if i % 3 else ['bladeL', 'blade'], bend=r.uniform(0.2, 0.55), segs=6, shape='blade')
p.finish('spiky_grass', fit='max')
