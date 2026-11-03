"""Arena 5's moss patch (retail 1681, 1683), in Blender: soft low
cushions of moss, lighter on top, darker round their edges."""
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


def cushion(cx, cy, rx, ry, n):
    """A cushion of moss: overlapping faceted knobs in three greens, low at
    the rim and fuller in the middle."""
    for _ in range(n):
        a, d = r.uniform(0, math.tau), math.sqrt(r.random())
        x, y = cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d
        rad = r.uniform(0.07, 0.12) * (1.15 - 0.5 * d)
        mat = 'padL' if r.random() < 0.35 and d < 0.7 else 'padD' if d > 0.85 else 'pad'
        p.blob(Vector((x, y, rad * 0.1)), rad, mat, scale=(1.3, 1.1, 0.5), sub=1, jitter=rad * 0.12)


cushion(-0.15, 0.18, 0.32, 0.14, 26)
cushion(-0.02, -0.15, 0.38, 0.15, 30)
cushion(0.42, 0.08, 0.15, 0.09, 8)
p.finish('moss_patch', fit='max')
