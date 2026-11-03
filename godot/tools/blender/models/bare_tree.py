"""Arena 2's bare tree (retail 2558, 2559), in Blender.

A slim pale trunk with a slight S and flared roots, knots up it, dead stubs
and crooked twigs, its top split in two leaders, a handful of leaves left
and moss at its foot; kiln's layout with one continuous tapering trunk.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

p = Piece()
p.tube([SP(0, 0, 0), SP(0.02, 0.5, 0), SP(-0.02, 1.2, 0), SP(0.02, 1.8, 0), SP(0, 2.1, 0)], 0.11, 0.045,
       mat="bark", sides=8, twist=1.2)
p.roots(5, 0.07, 0.26, z=0.14, mat="bark")
for i, (y, a) in enumerate([(0.35, 20), (0.8, 140), (1.15, 260), (1.5, 60), (1.9, 200)]):  # knots
    r = 0.085 - y * 0.018
    c = SP(0, y, 0) + Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0)) * r * 0.8
    p.blob(c, 0.045 - i * 0.004, "barkD" if i % 2 else "bark", scale=(1, 1, 1.6), sub=1)
p.twig([(0, 2.05, 0), (0.03, 2.2, 0), (0.05, 2.35, 0), (0.12, 2.6, 0)], 0.04, mat="bark")
p.twig([(0, 2.05, 0), (-0.04, 2.22, 0), (-0.08, 2.4, 0), (-0.14, 2.55, 0)], 0.035, mat="bark")
for y, a, ln, up, r in [(0.55, 30, 0.14, 25, 0.035), (0.95, 200, 0.18, 35, 0.03), (1.3, 100, 0.12, 20, 0.03),
                        (1.65, 300, 0.16, 40, 0.025), (0.75, 110, 0.1, 30, 0.028), (1.1, 330, 0.12, 15, 0.025),
                        (1.45, 230, 0.1, 45, 0.022), (1.95, 80, 0.12, 30, 0.02)]:  # dead stubs
    d = Vector((math.cos(math.radians(a)), math.sin(math.radians(a)), 0))
    rt = 0.08 - y * 0.017
    base = SP(0, y, 0) + d * rt * 0.6
    tip = base + (d * math.cos(math.radians(up)) + Vector((0, 0, math.sin(math.radians(up))))) * ln
    p.tube([base, base.lerp(tip, 0.5), tip], r, r * 0.55, mat="bark", sides=5)
    p.blob(tip, r * 0.65, "barkD", sub=1)
p.twig([(0.05, 1.45, 0), (0.28, 1.62, 0), (0.42, 1.6, 0), (0.48, 1.7, 0)], 0.018, mat="barkD")
p.twig([(-0.04, 1.85, 0), (-0.18, 1.98, 0), (-0.3, 2.05, 0), (-0.38, 2.2, 0)], 0.016, mat="barkD")
p.twig([(0.03, 2.3, 0), (0.18, 2.4, 0), (0.3, 2.45, 0), (0.42, 2.42, 0)], 0.014, mat="barkD")
for i, (u, y) in enumerate([(0.45, 1.72), (-0.38, 2.22), (0.42, 2.43), (0.14, 2.62), (-0.16, 1.1), (0.12, 0.75)]):
    n = SP(1 if u > 0 else -1, 0.4, 0.3)
    mats = ["leaf", "leafL"] if i % 2 else ["leafL", "leaf"]
    from lib import OVATE  # noqa: E402
    p.cards(p.spray(SP(u, y, 0.05), n, 2 + (i % 2), 0.16, mats, spread=70, out=20), OVATE, mats, thick=0.012 / 0.16)
for u, v, r in [(0.25, 0.04, 0.2), (-0.15, 0.05, 0.22), (0.0, 0.03, 0.3)]:  # moss at the foot
    p.blob(SP(u * 0.6, 0.0, v), r, "tuft", scale=(1, 0.75, 0.12), sub=1, jitter=0.01)
p.finish("bare_tree")
