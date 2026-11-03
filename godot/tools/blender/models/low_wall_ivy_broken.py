"""Arena 5's broken low wall with ivy (retail 194), in Blender: kiln's broken
plaster wall and grass kept; the ivy rebuilt as continuous vines climbing
over the broken top, two-tone cupped leaves, the red cluster spilling over
the far corner (kiln's layout).
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, Piece  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

p = Piece(keep={"plaster", "blade", "bladeD", "bladeL"})
r = p.rng

LEAF = []
for i in range(22):  # kiln's ivy leaf: a broad oval drawn to a point, stalk at the origin
    t = i / 22 * math.tau
    rr = 0.04 * (0.9 + 0.45 * max(0.0, math.sin(t)) ** 12)
    LEAF.append((math.cos(t) * rr * 0.95, math.sin(t) * rr * 1.15 + 0.045))
WALL_T = 0.23
FACE = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).to_4x4()   # leaf plane on the wall face (kiln +z)
TOP = Matrix(((1, 0, 0), (0, 1, 0), (0, 0, 1))).to_4x4()      # lying on the wall top


def along(pts, t):
    f = t * (len(pts) - 1)
    k = min(len(pts) - 2, int(f))
    return pts[k].lerp(pts[k + 1], f - k)


def leaves(pts, n, s0, s1, seed, h=9.0):
    for i in range(n):
        t = 1.0 if n == 1 else 0.06 + 0.94 * i / (n - 1)
        q = along(pts, t)
        sz = (s0 + (s1 - s0) * t) * r.uniform(0.9, 1.1)
        side = 1 if (i + seed) % 2 else -1
        on_top = q.z > h - 0.04
        base = TOP if on_top else FACE
        M = (Matrix.Translation(q) @ base @ Matrix.Rotation(math.radians(side * r.uniform(20, 70) * (2 if on_top else 1)), 4, "Z")
             @ Matrix.Rotation(math.radians(r.uniform(12, 32)), 4, "X"))
        lit = "ivyL" if (i + seed) % 3 == 0 else "ivy"
        p.cupped(LEAF, M @ Matrix.Scale(sz * 1.08, 4), ["ivyD"], cup=0.12, thick=0.004)
        p.cupped(LEAF, M @ Matrix.Translation((0, 0.002, 0.006)) @ Matrix.Scale(sz * 0.95, 4), [lit], cup=0.14, thick=0.004)


def plant(branches, seed, h):
    for k, (pts, r0, r1, n, s0, s1) in enumerate(branches):
        P = [K(x, y, WALL_T + 0.02 if z is None else z) for x, y, z in [(q + [None])[:3] for q in pts]]
        p.tube(P, r0, r1, mat="vineD" if r0 > 0.025 else "vine", sides=6, twist=1.0)
        leaves(P, int(n * 1.4), s0, s1, seed + k * 3, h)

plant([
    [[[0.08, 0, 0.3], [0.04, 0.16], [-0.08, 0.38], [-0.2, 0.6], [-0.3, 0.85], [-0.32, 1.06]], 0.042, 0.01, 10, 3.1, 1.2],
    [[[-0.31, 1.0], [-0.26, 1.14], [-0.2, 1.26, 0.16], [-0.08, 1.31, 0.04], [0.06, 1.31, -0.06]], 0.016, 0.007, 7, 1.4, 2.4],
    [[[-0.1, 0.45], [-0.32, 0.55], [-0.4, 0.66]], 0.015, 0.006, 4, 1.6, 1.0],
], 2, 1.3)
leaves([K(-0.02, 1.3, 0.04), K(0.06, 1.31, -0.04), K(0.1, 1.29, -0.12)], 7, 2.4, 2.0, 9, 1.3)
p.finish("low_wall_ivy_broken", fit="none")
