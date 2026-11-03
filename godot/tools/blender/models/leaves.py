"""Arena 1's frosted leaves (retail 176), in Blender: a rosette of broad
curved teal leaves opening out, snow on their tips and in the heart."""
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


tips = []
for i in range(8):
    az = i * 45 + r.uniform(-12, 12)
    a = math.radians(az)
    out = Vector((math.cos(a), math.sin(a), 0))
    ln = r.uniform(0.42, 0.55)
    p.strip(Vector((0, 0, 0.02)), dirv(az, 12 + (i % 2) * 12), out, ln, 0.26, ['leaf'], bend=0.55, shape='leaf', fold=0.3)
    tips.append(p.last_tip)
for t in tips:
    p.blob(t, 0.04, 'snow', scale=(1.2, 1, 0.75), sub=2, jitter=0.006)
p.finish('leaves', fit='max')
