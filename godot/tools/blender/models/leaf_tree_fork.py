"""Arena 5's green tree with a Y trunk (retail 2550), in Blender.

The trunk splits half way up into two twisting arms under a wide round
crown; same crown as the approved leaf_tree (lib.maple_crown). Run by
build_models.py (art/blender.json) on the kiln GLB of each loom.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

p = Piece()
p.tube([K(0, 0, 0), K(0.03, 0.45, 0.01), K(0, 0.86, 0)], 0.11, 0.085, mat="barkL", sides=10, twist=2.0)
p.roots(5, 0.08, 0.22, mat="barkL")
for k in range(2):  # dark streaks winding up the trunk
    a0 = k * 3.0
    p.tube([K(0.1 * math.cos(a0 + t * 2.4), 0.05 + t * 0.75, 0.1 * math.sin(a0 + t * 2.4)) for t in (0, 0.33, 0.66, 1)],
           0.02, 0.012, mat="barkD", sides=4)
p.tube([K(0, 0.8, 0), K(-0.18, 1.08, 0.04), K(-0.32, 1.32, 0.05), K(-0.48, 1.66, 0)], 0.08, 0.045, mat="barkL", sides=8, twist=1.5)
p.tube([K(0, 0.8, 0), K(0.16, 1.05, -0.01), K(0.28, 1.27, -0.02), K(0.42, 1.62, -0.05)], 0.08, 0.045, mat="barkL", sides=8, twist=-1.5)
p.tube([K(-0.3, 1.3, 0.05), K(-0.6, 1.5, 0.15), K(-0.78, 1.62, 0.2)], 0.035, 0.015, mat="bark", sides=6)
p.tube([K(0.27, 1.25, -0.02), K(0.58, 1.45, 0.12), K(0.78, 1.58, 0.2)], 0.035, 0.015, mat="bark", sides=6)
p.maple_crown([(K(-0.5, 1.9, 0), 0.48), (K(0.48, 1.85, -0.05), 0.48), (K(0, 2.25, 0), 0.42), (K(0.8, 1.6, 0.2), 0.3),
               (K(-0.82, 1.65, 0.2), 0.28), (K(0, 1.7, 0.4), 0.32), (K(0, 1.95, -0.4), 0.34)], zmin=1.3)
p.finish("leaf_tree_fork")
