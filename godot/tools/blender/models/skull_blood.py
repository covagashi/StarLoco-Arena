"""Arena 10's bloody skull (retail 2764), in Blender: kiln's cranium, brow,
face, cheekbones and teeth merged into one sculpted skull, the eye sockets
and the nose hole carved into it where kiln had them (the blood in the
sockets and the dark nose kept, now inside the holes); the pool kept.
Textured with arena 10's loom bone, as in kiln.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import Piece  # noqa: E402
from mathutils import Vector  # noqa: E402

LOOM = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "art", "arena10", "out"))

p = Piece(keep={"softBlood", "bloodLit", "meatD", "coal"})
carve = [(c, r * 1.05, (1, 1, 1)) for c, n, r, a, f in p.comps.get("meatD", [])]
carve += [(c, r * 0.9, (1, 1, 1.3)) for c, n, r, a, f in p.comps.get("coal", [])]
p.soften({"softSkull", "softSkullD"}, voxel=0.006, smooth=3, ratio=0.2, carve=carve)
p.finish("skull_blood", fit="none")
