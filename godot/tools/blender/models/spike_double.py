"""Arena 1's double ice spike (retail 159), in Blender: two faceted
crystals in a V, small ones at their foot, a lumpy skirt of snow."""
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

p.crystal(Vector((-0.08, 0, 0)), dirv(160, 6), 0.19, 2.25, tip=0.35)
p.crystal(Vector((0.12, 0.02, 0)), dirv(10, 28), 0.15, 1.5, tip=0.35)
for az, tl, ln in [(230, 40, 0.6), (300, 42, 0.45), (90, 40, 0.5)]:
    a = math.radians(az)
    p.crystal(Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, 0)), dirv(az, tl), 0.075, ln, tip=0.4)
snow_base(0.5, 0.36)
p.finish('spike_double', fit='max')
