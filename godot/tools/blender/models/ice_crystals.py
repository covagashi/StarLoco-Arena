"""Arena 1's ice crystals (retail 158), in Blender: a cluster of faceted
crystals fanning out, knobs of snow on some tips, snow round the foot."""
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

tips = []
for az, tl, ln, rr in [(0, 4, 1.5, 0.15), (60, 22, 1.25, 0.13), (150, 25, 1.15, 0.12), (220, 20, 1.3, 0.13),
                       (290, 28, 1.0, 0.11), (110, 40, 0.7, 0.09), (330, 45, 0.6, 0.08)]:
    a = math.radians(az)
    b = Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, 0)) if tl > 5 else Vector((0, 0, 0))
    d = dirv(az, tl)
    p.crystal(b, d, rr, ln, tip=0.3)
    tips.append(b + d * ln)
for t in tips[1:5:2]:  # snow knobs on a couple of tips, as the retail draws them
    p.blob(t + Vector((0, 0, -0.01)), 0.07, 'snow', scale=(1, 1, 0.85), sub=2)
snow_base(0.42, 0.36)
p.finish('ice_crystals', fit='max')
