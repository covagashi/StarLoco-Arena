"""Arena 1's snowy tree (retail 175; kit piece "tree"), in Blender.

A broad old stump in two faceted masses, thin gnarled limbs out of the top
as continuous twisting curves, big round snow clumps on the broken tops and
limb ends (snowT: the game smooths it). Textured bark and snow, projected at
the kiln tile sizes. kiln's layout (tree.kx.js).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

p = Piece()
SNOW = p.first("snowT", "snow")  # the looms swap the tree's snow for the block's
p.lathe([(0.4, 0), (0.33, 0.12), (0.27, 0.45), (0.23, 0.85), (0.21, 1.12), (0.14, 1.16), (0, 1.17)], "bark", sides=8,
        c=K(-0.1, 0, -0.1), jitter=0.035, tilt=(0, 4))
p.lathe([(0.44, 0), (0.36, 0.1), (0.3, 0.35), (0.27, 0.6), (0.18, 0.65), (0, 0.66)], "bark", sides=8,
        c=K(0.14, 0, 0.13), jitter=0.035, tilt=(0, -3))
p.roots(5, 0.15, 0.55, z=0.24, mat="barkD", a0=0.3)


def limb(pts, r0, r1, twist=1.2):
    p.tube([K(*pts[i:i + 3]) for i in range(0, len(pts), 3)], r0, r1, mat="barkD", sides=6, twist=twist)


limb([-0.15, 0.95, -0.12, -0.35, 1.12, -0.1, -0.52, 1.18, -0.05, -0.66, 1.32, -0.02], 0.07, 0.03)
limb([-0.42, 1.14, -0.08, -0.45, 1.3, -0.2, -0.4, 1.42, -0.28], 0.035, 0.018)
limb([-0.05, 1.08, -0.1, 0.02, 1.3, -0.15, 0.06, 1.5, -0.12], 0.065, 0.028)
limb([0.22, 0.58, 0.18, 0.4, 0.75, 0.25, 0.48, 0.92, 0.2], 0.065, 0.03)
limb([0.3, 0.45, 0.1, 0.55, 0.52, 0.0, 0.78, 0.6, -0.05], 0.065, 0.026)
limb([0.6, 0.54, 0.0, 0.66, 0.66, -0.1], 0.03, 0.016)


def clump(x, y, z, r):
    p.blob(K(x, y + r * 0.15, z), r, SNOW, scale=(1.05, 1.05, 0.8), sub=3)
    p.blob(K(x - r * 0.35, y + r * 0.45, z - r * 0.2), r * 0.6, SNOW, scale=(1, 1, 0.85), sub=2)
    p.blob(K(x + r * 0.62, y - r * 0.45, z + r * 0.6), r * 0.22, SNOW, scale=(0.8, 0.8, 1.9), sub=2)
    p.blob(K(x - r * 0.75, y - r * 0.4, z + r * 0.45), r * 0.17, SNOW, scale=(0.8, 0.8, 1.7), sub=2)


clump(-0.1, 1.17, -0.1, 0.21)
clump(0.14, 0.67, 0.13, 0.29)
clump(-0.68, 1.34, -0.02, 0.08)
clump(0.06, 1.52, -0.12, 0.075)
clump(0.5, 0.94, 0.2, 0.075)
clump(0.8, 0.61, -0.05, 0.07)
p.finish("tree")
