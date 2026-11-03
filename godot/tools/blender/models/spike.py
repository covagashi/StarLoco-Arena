"""Arena 1's ice spike (retail 157), in Blender: a tall faceted crystal
leaning a little, small ones round its foot, a lumpy skirt of snow."""
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


def snow_base(rx, ry, n=5, h=0.12):
    """A lumpy skirt of snow round the foot."""
    balls = [((0, 0, 0.02), max(rx, ry) * 0.6, (rx / max(rx, ry), ry / max(rx, ry), h * 3))]
    for i in range(n):
        a = i * math.tau / n + r.uniform(-0.3, 0.3)
        balls.append(((math.cos(a) * rx * 0.75, math.sin(a) * ry * 0.75, 0.02), r.uniform(0.18, 0.26), (1.2, 1, 0.55)))
    p.lumps(balls, ["snow"])

p.crystal(Vector((0, 0, 0)), dirv(30, 6), 0.2, 2.25, tip=0.35)
for i, (az, tl, ln) in enumerate([(200, 35, 0.75), (290, 40, 0.55), (110, 38, 0.6), (20, 45, 0.4)]):
    a = math.radians(az)
    p.crystal(Vector((math.cos(a) * 0.17, math.sin(a) * 0.17, 0)), dirv(az, tl), 0.08, ln, tip=0.4)
snow_base(0.42, 0.38)
p.finish('spike', fit='max')
