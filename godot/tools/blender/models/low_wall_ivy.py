"""Arena 5's low wall with ivy (retail 195), in Blender: kiln's plaster wall
and grass skirt kept as they are; the ivy rebuilt as one continuous woody
vine per branch with two-tone cupped leaves, more of them, big low down and
small towards the tips (kiln's branch layout).
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
    [[[-0.08, 0, 0.3], [-0.12, 0.12], [-0.18, 0.3], [-0.25, 0.52], [-0.3, 0.74], [-0.28, 0.9]], 0.04, 0.009, 10, 3.0, 1.1],
    [[[-0.14, 0.2], [-0.02, 0.33], [0.06, 0.47], [0.1, 0.62]], 0.02, 0.007, 6, 1.9, 1.0],
    [[[-0.22, 0.42], [-0.36, 0.55], [-0.4, 0.68]], 0.015, 0.006, 4, 1.6, 1.0],
], 1, 1.28)
p.finish("low_wall_ivy", fit="none")
