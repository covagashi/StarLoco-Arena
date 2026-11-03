"""Arena 5's roof (retail 178), in Blender: a tilted board under rows of
curved clay tiles, each a thick shell wider at its lower end with a rounded
lip, staggered and overlapping the row below, three tones. Kiln's layout
(a board tilted 24 degrees towards the camera, three rows of six).
"""
import math
import os
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import K, Piece  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

p = Piece()
r = p.rng
TILT = math.radians(24)
DOWN = K(0, -math.sin(TILT), math.cos(TILT))   # down the slope
N = K(0, math.cos(TILT), math.sin(TILT))       # off the board
X = Vector((1, 0, 0))
ORIGIN = K(0, 0.25, 0)


def on_board(u, v, h=0.0):
    return ORIGIN + X * u + DOWN * v + N * h


# the board
bm = bmesh.new()
corners = [on_board(-0.54, -0.56, -0.06), on_board(0.54, -0.56, -0.06), on_board(0.54, 0.56, -0.06), on_board(-0.54, 0.56, -0.06)]
top = [bm.verts.new(c + N * 0.04) for c in corners]
bot = [bm.verts.new(c) for c in corners]
bm.faces.new(top)
bm.faces.new(list(reversed(bot)))
for i in range(4):
    j = (i + 1) % 4
    bm.faces.new((bot[i], bot[j], top[j], top[i]))
me = bpy.data.meshes.new("board")
bm.to_mesh(me)
bm.free()
p._link("board", me, ["timber"])


def tile(u, v_low, length, r0, r1, mat, lift):
    """A curved tile: lower end at v_low, running up the slope."""
    bm = bmesh.new()
    A, T = 8, 4
    outer, inner = [], []
    for ti in range(T + 1):
        t = ti / T
        rr = r0 + (r1 - r0) * t
        o_row, i_row = [], []
        for ai in range(A + 1):
            a = math.pi * ai / A
            for shell, row, k in ((outer, o_row, 1.0), (inner, i_row, 0.78)):
                x = math.cos(a) * rr * k
                h = math.sin(a) * rr * 0.95 * k + lift * (1 - t)
                row.append(bm.verts.new(on_board(u + x, v_low - t * length, h)))
        outer.append(o_row)
        inner.append(i_row)
    for ti in range(T):
        for ai in range(A):
            bm.faces.new((outer[ti][ai], outer[ti][ai + 1], outer[ti + 1][ai + 1], outer[ti + 1][ai]))
            bm.faces.new((inner[ti][ai + 1], inner[ti][ai], inner[ti + 1][ai], inner[ti + 1][ai + 1]))
    for ti in (0, T):  # the lip and the top end
        for ai in range(A):
            f = (outer[ti][ai], inner[ti][ai], inner[ti][ai + 1], outer[ti][ai + 1])
            bm.faces.new(f if ti == 0 else tuple(reversed(f)))
    for ai in (0, A):  # the long edges
        for ti in range(T):
            f = (outer[ti][ai], outer[ti + 1][ai], inner[ti + 1][ai], inner[ti][ai])
            bm.faces.new(f if ai == 0 else tuple(reversed(f)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for v in bm.verts:
        v.co += Vector([r.uniform(-0.003, 0.003) for _ in range(3)])
    me = bpy.data.meshes.new("tile")
    bm.to_mesh(me)
    bm.free()
    p._link("tile", me, [mat])


for row in range(3):           # the lowest row is laid last, over the others
    v_low = -0.56 + 0.44 + row * 0.34
    for c in range(6):
        u = -0.45 + c * 0.18 + (row % 2) * 0.09
        if u > 0.5:
            continue
        m = "roofL" if (c + row) % 3 == 0 else "roof" if (c + row) % 3 == 1 else "roofD"
        tile(u + r.uniform(-0.008, 0.008), v_low, 0.46, 0.098, 0.07, m, lift=0.035 + row * 0.02)
p.finish("roof", fit="max")
