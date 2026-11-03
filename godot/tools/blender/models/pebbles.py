"""Arena 1's pebbles (retail 161, 162, 163), in Blender: rounded pebbles
in a loose scatter, a soft cap of snow on each."""
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


for i in range(9):
    a = i * 2.4 + r.uniform(-0.3, 0.3)
    d = 0.08 + 0.32 * math.sqrt((i + 0.5) / 9)
    c = Vector((math.cos(a) * d, math.sin(a) * d, 0))
    s = r.uniform(0.045, 0.085) * (1.4 if i == 0 else 1)
    p.blob(c + Vector((0, 0, s * 0.35)), s, 'pebble', scale=(1.25, 1.0, 0.7), sub=2, jitter=s * 0.12)
    p.blob(c + Vector((0, 0, s * 0.98)), s * 0.62, 'snow', scale=(1.2, 1.0, 0.38), sub=2, jitter=s * 0.04)
p.finish('pebbles', fit='max')
