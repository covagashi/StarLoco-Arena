"""Arena 5's little pink flowers on the ground (retail 126), in Blender:
nine five-petalled flowers lying open, cupped, a pale heart in each."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, SP, Piece, maple  # noqa: E402,F401
from mathutils import Matrix, Vector  # noqa: E402,F401

p = Piece()
r = p.rng
UP = Vector((0, 0, 1))


def dirv(az, tilt):
    """A direction tilt degrees off vertical, towards azimuth az (degrees)."""
    a, t = math.radians(az), math.radians(tilt)
    return Vector((math.cos(a) * math.sin(t), math.sin(a) * math.sin(t), math.cos(t)))


petal = [(0, 0), (0.035, 0.03), (0.045, 0.07), (0.03, 0.1), (0, 0.11), (-0.03, 0.1), (-0.045, 0.07), (-0.035, 0.03)]
for i in range(9):
    a = i * 2.4
    d = 0.06 + 0.36 * math.sqrt((i + 0.5) / 9)
    c = Vector((math.cos(a) * d, math.sin(a) * d, 0.01))
    s = r.uniform(0.7, 1.3)
    spin = r.uniform(0, math.tau)
    for k in range(5):
        M = (Matrix.Translation(c) @ Matrix.Rotation(spin + k * math.tau / 5, 4, 'Z')
             @ Matrix.Rotation(math.radians(-18), 4, 'X') @ Matrix.Scale(s, 4))
        p.cupped(petal, M, ['pink', 'pinkD'], cup=0.25, thick=0.006, pick=lambda j, k=k: k % 2 and j > 3)
    p.blob(c + Vector((0, 0, 0.012 * s)), 0.02 * s, 'pinkC', scale=(1, 1, 0.6), sub=1)
p.finish('petals', fit='max')
