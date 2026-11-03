"""Arena 10's skinned rat (retail 1634), in Blender + loom: kiln's heap of
pink lumps merged into one soft lumpy mass, with arena 10's loom flesh
(fleshTex: pale, thin red veins, as the retail draws it); the tail and the
blood spatter kept from kiln.
Needs arena 10's loom built first (loom build kit.tx.js --only fleshTex).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

LOOM = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "art", "arena10", "out"))

p = Piece(keep={"pink", "bloodLit"})
p.soften({"flesh", "fleshD"}, voxel=0.01, smooth=3, ratio=0.12)
p.loom_tex("flesh", os.path.join(LOOM, "fleshTex"), 0.22)
p.loom_tex("fleshD", os.path.join(LOOM, "fleshTex"), 0.22)
p.finish("rat_skinned", fit="none")
