"""Arena 5's broken fence pair (retail 200), in Blender: two rough log posts
with moss and splinters and a sagging log rail between them (kiln's layout)."""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, Piece  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

p = Piece()
r = p.rng

def post(x, z, h, seed):
    """A rustic log post: leaning a little, rough, cut flat with splinters
    round the rim, split slats at its foot, moss knobs up its lower half."""
    rr = 0.11
    lean = Vector((r.uniform(-0.02, 0.02), r.uniform(-0.02, 0.02), 0))
    base, top = K(x, 0, z), K(x, h, z) + lean
    p.tube([base, base.lerp(top, 0.5) + Vector((r.uniform(-0.01, 0.01), 0, 0)), top], rr * 1.06, rr * 0.95,
           mat="log", sides=8, twist=0.8)
    p.lathe([(rr * 0.9, 0), (0, 0.004)], "logL", sides=8, c=top + Vector((0, 0, 0.002)))
    for i in range(4):  # splinters round the rim
        a = math.radians(i * 90 + seed * 13 + r.uniform(-20, 20))
        q = top + Vector((math.cos(a), math.sin(a), 0)) * rr * 0.8
        p.crystal(q - Vector((0, 0, 0.02)), Vector((math.cos(a) * 0.15, math.sin(a) * 0.15, 1)), 0.014,
                  r.uniform(0.05, 0.09), mats=("logD", "log"), sides=3, tip=0.6)
    for i in range(5):  # split slats leaning out at the foot
        a = math.radians(i * 72 + seed * 7 + r.uniform(-15, 15))
        d = Vector((math.cos(a), math.sin(a), 0))
        p.crystal(base + d * (rr + 0.01), d * 0.35 + Vector((0, 0, 1)), 0.022, r.uniform(0.12, 0.2),
                  mats=("logL" if i % 2 else "log", "logD"), sides=4, tip=0.35)
    for i in range(int(h * 30)):  # moss up the lower half, thicker at the foot
        a = r.uniform(0, math.tau)
        zz = h * 0.45 * r.random() ** 1.6
        q = base.lerp(top, zz / h) + Vector((math.cos(a), math.sin(a), 0)) * rr
        s = r.uniform(0.025, 0.045)
        p.blob(q, s, "moss", scale=(1.2, 1.2, 1.0), sub=1, jitter=s * 0.15)


def rail(a, b):
    """A crooked log rail sagging between a and b (kiln points)."""
    A, B = K(*a), K(*b)
    m = A.lerp(B, 0.5) + Vector((0.01, 0, -0.025))
    p.tube([A, A.lerp(m, 0.5) + Vector((0, 0.008, 0)), m, m.lerp(B, 0.5) - Vector((0, 0.008, 0)), B], 0.038, 0.032,
           mat="log", sides=7, twist=1.2)

post(0, 0.32, 0.5, 3)
post(0, -0.32, 0.72, 5)
rail([0, 0.36, 0.28], [0, 0.48, -0.28])
p.finish("fence_pair", fit="max")
