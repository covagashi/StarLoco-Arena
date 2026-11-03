"""Arena 2's autumn bush-tree (retail 1029), in Blender.

A pale forked stem in a dark hollow, leaves in a ring round it, dark
branches out of the top and sprays reaching out at both sides; kiln's
layout and colouring (lib.foliage) with one curving stem and denser,
lighter-weight leaves. Run by build_models.py (art/blender.json).
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
p.twig([(0, 0, 0), (0.02, 0.45, 0), (0.0, 0.8, 0), (-0.18, 1.25, 0), (-0.3, 1.6, 0), (-0.45, 2.2, 0)], 0.1, sides=8)
p.twig([(0.0, 0.78, 0), (0.18, 1.1, 0), (0.35, 1.5, 0), (0.5, 2.2, 0)], 0.07, sides=7)
p.foliage([(0, 0.5, 0.05, 0.85, 0.55, 0.5), (-0.65, 1.3, 0.05, 0.55, 0.75, 0.42), (0.65, 1.35, 0, 0.55, 0.8, 0.42),
           (0.05, 2.15, -0.05, 0.8, 0.55, 0.45), (0.05, 1.3, -0.35, 0.6, 0.7, 0.3)], 180, 0.24, shade,
          hollow=(0.0, 1.3, 0.42, 0.45))
p.twig([(0.0, 2.3, 0), (0.05, 2.9, 0), (-0.05, 3.35, 0), (0.0, 3.6, 0)], 0.04, mat="twig", tip=0.2)
p.twig([(0.05, 2.9, 0), (0.25, 3.05, 0), (0.4, 3.15, 0), (0.55, 3.3, 0)], 0.022, mat="twig")
p.twig([(0.3, 2.4, 0), (0.45, 2.7, 0), (0.55, 2.9, 0), (0.6, 3.1, 0)], 0.02, mat="twig")
p.twig([(-0.6, 1.1, 0.2), (-0.9, 1.3, 0.18), (-1.1, 1.4, 0.15), (-1.35, 1.55, 0.1)], 0.025, tip=0.22)
p.twig([(0.6, 1.6, 0.2), (0.85, 1.8, 0.15), (1.05, 1.95, 0.1), (1.3, 2.0, 0.05)], 0.025, tip=0.22)
p.finish("autumn_tree")
