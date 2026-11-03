"""Arena 1's dead tree (retail 150), in Blender.

A pale split trunk, no leaves, two slabs of it peeling outward, gnarled bare
limbs clawing out of its broken top; kiln's layout with the limbs as
continuous twisting curves instead of tubes and spheres. Textured bark
(deadBark), projected at the kiln tile size.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

p = Piece()
p.lathe([(0.36, 0), (0.25, 0.1), (0.18, 0.45), (0.15, 0.9), (0.13, 1.12), (0, 1.18)], "deadBark", sides=8,
        jitter=0.03, tilt=(0, 3))
p.lathe([(0.12, 0), (0.1, 0.4), (0.06, 0.75), (0, 0.82)], "deadBark", sides=6, c=K(0.13, 0.35, 0.05), jitter=0.02, tilt=(0, 16))
p.lathe([(0.1, 0), (0.08, 0.35), (0.04, 0.6), (0, 0.66)], "deadBarkD", sides=6, c=K(-0.12, 0.45, -0.04), jitter=0.02, tilt=(-8, -18))
p.roots(5, 0.13, 0.48, z=0.22, mat="deadBarkD", a0=0.5)


def limb(pts, r0, r1, twist=1.5):
    p.tube([K(*pts[i:i + 3]) for i in range(0, len(pts), 3)], r0, r1, mat="deadBarkD", sides=6, twist=twist)


limb([0.05, 1.0, 0, 0.3, 1.2, 0.05, 0.42, 1.42, 0.14, 0.62, 1.55, 0.12, 0.72, 1.72, 0.05], 0.08, 0.022)
limb([0.42, 1.42, 0.14, 0.58, 1.38, 0.3, 0.7, 1.5, 0.4], 0.035, 0.014)
limb([-0.03, 1.05, 0, -0.25, 1.25, -0.05, -0.42, 1.32, 0.06, -0.58, 1.52, 0.04, -0.66, 1.7, -0.04], 0.075, 0.02, -1.5)
limb([-0.42, 1.32, 0.06, -0.6, 1.28, -0.1, -0.74, 1.36, -0.16], 0.032, 0.012)
limb([0.0, 1.1, 0.02, 0.06, 1.42, -0.08, -0.02, 1.72, -0.14, 0.08, 1.9, -0.12], 0.065, 0.018)
limb([0.12, 0.72, 0.08, 0.4, 0.86, 0.14, 0.6, 1.02, 0.08, 0.7, 1.18, 0.12], 0.055, 0.016)
limb([-0.12, 0.9, -0.03, -0.4, 0.96, -0.18, -0.5, 1.12, -0.3], 0.05, 0.014)
p.finish("dead_tree")
