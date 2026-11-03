"""Arena 2's autumn bush (retail 1016, 1022, 1028, 1033, 1034), in Blender.

A dense hedge with a dark hollow low in its middle where the pale stems
show, twigs poking out of the top and sides with sprays at their ends;
kiln's layout (lib.foliage) with curving twigs and denser leaves.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece  # noqa: E402
from mathutils import Vector  # noqa: E402


def shade(ny, face, rng):
    # kiln's rule: lighter on top and facing the camera, darker below and behind
    light = ny * 0.55 + face * 0.45 + (rng.random() - 0.5) * 0.35
    # thresholds a little higher than kiln's: these cards face the camera more
    return ["leafL", "leaf"] if light > 0.5 else ["leaf", "leaf", "leafL"] if light > 0.08 else ["leafD", "leaf"]


p = Piece()
p.foliage([(0, 0.85, 0, 0.95, 0.9, 0.5), (-0.75, 0.55, 0.1, 0.5, 0.6, 0.38), (0.75, 0.6, 0, 0.5, 0.65, 0.38),
           (0.1, 1.55, -0.1, 0.6, 0.45, 0.4)], 155, 0.22, shade, hollow=(-0.05, 0.6, 0.36, 0.38))
p.twig([(-0.1, 0, 0.1), (-0.15, 0.6, 0.15), (-0.35, 1.3, 0.1), (-0.55, 2.2, 0.05), (-0.62, 2.45, 0)], 0.03, tip=0.22)
p.twig([(0.05, 0, 0.1), (0.12, 0.7, 0.15), (0.3, 1.4, 0.05), (0.5, 2.1, 0), (0.75, 2.35, 0)], 0.03, tip=0.22)
p.twig([(-0.2, 0.9, 0.2), (-0.55, 1.15, 0.18), (-0.8, 1.3, 0.15), (-1.25, 1.45, 0.1)], 0.025, tip=0.2)
p.twig([(0.2, 1.0, 0.2), (0.55, 1.3, 0.15), (0.85, 1.5, 0.1), (1.2, 1.75, 0.05)], 0.025, tip=0.2)
p.twig([(0.3, 1.8, 0), (0.33, 2.05, 0), (0.35, 2.3, 0), (0.5, 2.6, 0)], 0.02, mat="twig", tip=0.18)
p.finish("autumn_bush")
