"""Arena 10's dead rat (retail 2762), in Blender + loom: kiln's body and head
(two spheres) merged into one plump sculpted body, with arena 10's loom fur
(furTex) on it; the pink tail, ears, nose, paws, the crossed eyes and the
dark belly patch kept from kiln.
Needs arena 10's loom built first (loom build kit.tx.js --only furTex).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

LOOM = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "art", "arena10", "out"))

p = Piece(keep={"pink", "eye", "furD"})
p.soften({"fur"}, voxel=0.01, smooth=4, ratio=0.12)
p.loom_tex("fur", os.path.join(LOOM, "furTex"), 0.25)
p.finish("rat_dead", fit="none")
