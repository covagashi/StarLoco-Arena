"""Arena 6's broad-leaved plant (retail 1789), in Blender: a rosette of
broad curved leaves with a crease down each, thin stems trailing on the
ground, a few pebbles."""
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


def herb():
    """Broad curved leaves from one root, stems trailing on the ground, pebbles."""
    for cx, cy, n, sz in [(-0.08, 0.05, 7, 1.0), (0.22, 0.12, 5, 0.75)]:  # two rosettes, as the retail
        for i in range(n):
            az = i * 360 / n + r.uniform(-15, 15)
            tl = r.uniform(25, 50)
            p.strip(Vector((cx, cy, 0)), dirv(az, tl), dirv(az, 90), r.uniform(0.38, 0.52) * sz, r.uniform(0.2, 0.26) * sz,
                    ["herbL" if tl < 34 else "herb" if i % 3 else "herbD"], bend=r.uniform(0.4, 0.7), segs=6, shape="leaf", fold=0.3)
    for i in range(6):  # thin stems lying on the ground
        a = math.radians(i * 60 + r.uniform(-20, 20))
        d = Vector((math.cos(a), math.sin(a), 0))
        ln = r.uniform(0.35, 0.55)
        q = d.cross(UP)
        p.tube([d * 0.05 + Vector((0, 0, 0.01)), d * ln * 0.5 + q * r.uniform(-0.05, 0.05) + Vector((0, 0, 0.012)),
                d * ln + Vector((0, 0, 0.008))], 0.009, 0.005, mat="stem", sides=4)
    for i in range(3):
        a = r.uniform(0, math.tau)
        c = Vector((math.cos(a), math.sin(a), 0)) * r.uniform(0.25, 0.4)
        p.blob(c + Vector((0, 0, 0.012)), r.uniform(0.022, 0.035), "pebble", scale=(1.2, 1, 0.65), sub=1, jitter=0.004)

herb()
p.finish('herb')
