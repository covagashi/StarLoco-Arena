"""Arena 2's tall autumn bush (retail 1021, 1035), in Blender.

A leafy mass with bare branches climbing out of it, forking, a few sprays
left on their tips; kiln's layout (lib.foliage) with continuous curving
branches and denser leaves.
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
p.foliage([(0, 0.82, 0, 0.9, 0.88, 0.5), (0.45, 1.45, 0, 0.6, 0.5, 0.4), (-0.6, 0.55, 0.1, 0.45, 0.55, 0.35)], 140, 0.22, shade)
p.twig([(-0.1, 0.8, 0.1), (-0.2, 1.3, 0.1), (-0.3, 1.8, 0.1), (-0.55, 2.8, 0.05), (-0.5, 3.6, 0)], 0.036, tip=0.2)
p.twig([(-0.4, 2.3, 0.05), (-0.65, 2.6, 0.05), (-0.85, 2.85, 0.05), (-1.0, 3.2, 0)], 0.025, tip=0.18)
p.twig([(0.1, 1.2, 0.1), (0.15, 1.6, 0.08), (0.2, 2.0, 0.05), (0.35, 2.8, 0), (0.3, 3.2, 0)], 0.032)
p.twig([(0.3, 2.4, 0), (0.8, 2.6, 0), (1.05, 2.8, 0), (1.3, 3.0, 0), (1.55, 3.1, 0)], 0.028)
p.twig([(0.9, 2.65, 0), (0.98, 2.85, 0), (1.05, 3.05, 0), (1.0, 3.3, 0)], 0.018)
p.twig([(-0.2, 1.0, 0.25), (-0.55, 1.15, 0.22), (-0.9, 1.35, 0.2), (-1.3, 1.6, 0.1)], 0.025, tip=0.2)
p.finish("autumn_bush_tall")
