"""Arena 5's young green tree (retail 2556), in Blender.

A slim trunk leaning a little and turning as it climbs, two thin branches,
an open crown of big maple leaves; same leaves as the approved leaf_tree
(lib.maple_crown), sparser and larger. Run by build_models.py.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

p = Piece()
p.tube([K(0, 0, 0), K(0.07, 0.35, 0), K(0.0, 0.72, 0.02), K(0.11, 1.05, 0.02), K(0.05, 1.3, 0), K(0.1, 1.52, 0)],
       0.065, 0.03, mat="barkL", sides=8, twist=2.2)
p.roots(4, 0.05, 0.16, z=0.1, mat="barkL")
p.tube([K(0.09, 1.0, 0), K(0.32, 1.2, 0.06), K(0.48, 1.36, 0.1), K(0.6, 1.47, 0.1)], 0.025, 0.012, mat="bark", sides=6)
p.tube([K(0.09, 1.12, 0), K(-0.12, 1.3, -0.03), K(-0.3, 1.46, -0.05)], 0.024, 0.012, mat="bark", sides=6)
p.tube([K(0.08, 1.3, 0), K(0.2, 1.55, 0.15), K(0.25, 1.75, 0.2)], 0.02, 0.01, mat="bark", sides=5)
p.maple_crown([(K(0.1, 1.82, 0), 0.4), (K(0.6, 1.52, 0.1), 0.3), (K(-0.32, 1.6, -0.05), 0.3), (K(0.15, 2.12, -0.05), 0.26),
               (K(0.25, 1.65, 0.3), 0.24)], zmin=1.2, density=(22, 55), size=(1.6, 2.2), dark=0.74)
p.finish("leaf_tree_young")
