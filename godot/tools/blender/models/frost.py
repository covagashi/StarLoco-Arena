"""Arena 1's frost (retail 170), in Blender: a low line of snow with small
four-sided ice spikes standing out of it at all angles."""
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


def frost(length, n, hmax, seed_off=0):
    """A low ridge of snow along x with little ice spikes standing out of it."""
    balls = []
    for i in range(7):
        x = -length / 2 + length * i / 6
        balls.append(((x, r.uniform(-0.04, 0.04), 0.0), r.uniform(0.13, 0.18), (1.4, 0.9, 0.5)))
    p.lumps(balls, ["snow"], res=0.035)
    for i in range(n):
        x = -length / 2 * 0.9 + length * 0.9 * (i + r.uniform(0.2, 0.8)) / n
        y = r.uniform(-0.07, 0.07)
        az = 90 if y > 0 else 270
        p.crystal(Vector((x, y, 0.02)), dirv(az + r.uniform(-60, 60), r.uniform(10, 40)), r.uniform(0.03, 0.05),
                  hmax * r.uniform(0.45, 1.0), sides=4, tip=0.55)

frost(1.0, 11, 0.5)
p.finish('frost', fit='max')
