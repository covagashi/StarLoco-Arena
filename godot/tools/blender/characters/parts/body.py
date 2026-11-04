"""S35, fighter 1 by parts: the whole figure, still unrigged (owner
2026-11-04: "haz el cuerpo entero y enséñame solo 1 vista").

    blender -b -P tools/blender/characters/parts/body.py -- [out.glb]

Each part is its own low cage, subdivided: the torso a loft of rings, one
leg and one arm lofted along their bones and mirrored in X, one hand
(palm and fingers) mirrored, the boots, straps, collar, belt and tunic
tails as pieces of their own, and the head from head.py. Clothes are bands
of the loft (a ring sits on every hem, so each colour ends on a clean
line). Blender is z-up, the figure faces -Y, 1 unit = 1 cell; 1.45 tall
with the hair, the retail class 1 sprite's 78 px.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import head as H  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "art", "characters", "out", "parts", "body.glb"))

H.PALETTE.update({"vest": "77736c", "shirt": "e3ddd0", "pants": "3a7773", "belt": "6b4a33", "gold": "e2bd6e",
                  "boots": "5a3a26", "strap": "d9892b", "sole": "2e2219"})
NECK = 0.955        # the head part sits on the neck at this height
HEAD_SCALE = 1.08


# ---------------------------------------------------------------- lofts

def ring(c, rx, ry, n=12, back=1.0, front=1.0, ang0=0.0):
    """An ellipse of n points round c in the XY plane; back/front stretch
    the +Y / -Y halves (a flatter back, a fuller chest)."""
    pts = []
    for i in range(n):
        a = ang0 + 2 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a) * ry
        y *= back if y > 0 else front
        pts.append(Vector(c) + Vector((x, y, 0)))
    return pts


def tube_ring(a, b, r, n=10, sx=1.0, sy=1.0):
    """A ring round point a, perpendicular to the direction a→b."""
    d = (b - a).normalized()
    u = Vector((1, 0, 0))
    u = (u - d * u.dot(d)).normalized()
    v = d.cross(u)
    return [a + (u * math.cos(2 * math.pi * i / n) * sx + v * math.sin(2 * math.pi * i / n) * sy) * r for i in range(n)]


def loft(name, rings, mats, cap_start=True, cap_end=True, sub=2):
    """Bridge rings into quads; mats[i] is the material of the band between
    ring i and i+1 (a list of names). Caps are fans."""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    names = sorted(set(mats), key=mats.index)
    for i in range(len(vs) - 1):
        n = len(vs[i])
        for j in range(n):
            f = bm.faces.new((vs[i][j], vs[i][(j + 1) % n], vs[i + 1][(j + 1) % n], vs[i + 1][j]))
            f.material_index = names.index(mats[i])
    for cap, r, mi in ((cap_start, vs[0], mats[0]), (cap_end, vs[-1], mats[-1])):
        if cap:
            c = bm.verts.new(sum((v.co for v in r), Vector()) / len(r))
            for j in range(len(r)):
                f = bm.faces.new((r[j], r[(j + 1) % len(r)], c))
                f.material_index = names.index(mi)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = H.link(name, me)
    for m in names:
        ob.data.materials.append(H.mat(m))
    if sub:
        s = ob.modifiers.new("sub", "SUBSURF")
        s.levels = sub
    H.smooth(ob)
    return ob


def mirror(ob):
    m = ob.modifiers.new("mirror", "MIRROR")
    m.use_axis[0] = True
    m.use_bisect_axis[0] = False
    ob.modifiers.move(len(ob.modifiers) - 1, 0)  # mirror the cage, then subdivide
    return ob


def torus(name, c, rx, ry, r, mat, n=24, m=8, tilt=0.0):
    bm = bmesh.new()
    grid = []
    for i in range(n):
        a = 2 * math.pi * i / n
        ctr = Vector(c) + Vector((math.cos(a) * rx, math.sin(a) * ry, tilt * math.sin(a)))
        out = Vector((math.cos(a) * ry, math.sin(a) * rx, 0)).normalized()
        grid.append([bm.verts.new(ctr + (out * math.cos(2 * math.pi * k / m) + Vector((0, 0, 1)) * math.sin(2 * math.pi * k / m) * 0.8) * r)
                     for k in range(m)])
    for i in range(n):
        for k in range(m):
            bm.faces.new((grid[i][k], grid[(i + 1) % n][k], grid[(i + 1) % n][(k + 1) % m], grid[i][(k + 1) % m]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = H.link(name, me)
    ob.data.materials.append(H.mat(mat))
    H.smooth(ob)
    return ob


# ---------------------------------------------------------------- parts

def build_torso():
    """Hips to neck in one loft. Bands: trousers seat, belt, vest, skin."""
    R = [  # z, half width, half depth, back, front, material of the band above
        (0.55, 0.115, 0.085, 1.0, 1.0, "pants"),
        (0.6, 0.118, 0.088, 1.05, 1.0, "belt"),
        (0.645, 0.106, 0.078, 1.0, 1.0, "vest"),
        (0.72, 0.095, 0.07, 1.0, 1.0, "vest"),
        (0.8, 0.108, 0.074, 0.95, 1.08, "vest"),
        (0.87, 0.118, 0.072, 0.95, 1.05, "vest"),
        (0.915, 0.085, 0.058, 1.0, 1.0, "skin"),
        (0.945, 0.042, 0.04, 1.0, 1.0, "skin"),
        (0.99, 0.036, 0.036, 1.0, 1.0, "skin"),
    ]
    rings = [ring((0, 0, z), w, d, 14, b, f) for z, w, d, b, f, _ in R]
    return loft("torso", rings, [m for *_, m in R][:-1])


def build_leg():
    """One leg, mirrored: baggy trousers full at the knee and calf,
    gathered over the ankle."""
    X = 0.1
    R = [  # z, centre x, radius, material above
        (0.6, 0.065, 0.075, "pants"),
        (0.5, 0.085, 0.08, "pants"),
        (0.38, 0.095, 0.088, "pants"),
        (0.28, 0.1, 0.092, "pants"),
        (0.2, 0.102, 0.085, "pants"),
        (0.15, 0.104, 0.062, "pants"),
        (0.12, 0.105, 0.042, "pants"),
        (0.08, 0.105, 0.04, "pants"),
    ]
    rings = [ring((x, 0.005, z), r, r * 0.95, 12) for z, x, r, _ in R]
    leg = mirror(loft("leg", rings, [m for *_, m in R][:-1]))
    # boot: a rounded box with a toe, mirrored
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co
        toe = max(0.0, -y)  # the front half lower and narrower at the tip
        v.co = Vector((X + x * (0.09 - 0.02 * toe), -0.03 + y * 0.2, 0.05 + z * (0.09 - 0.035 * toe) - 0.015 * toe))
        v.co.z = max(v.co.z, 0.008)
    me = bpy.data.meshes.new("boot")
    bm.to_mesh(me)
    bm.free()
    boot = H.link("boot", me)
    boot.data.materials.append(H.mat("boots"))
    boot.modifiers.new("sub", "SUBSURF").levels = 2
    mirror(boot)
    H.smooth(boot)
    # sole: a thin dark slab under the boot
    sole = H.link("sole", bpy.data.meshes.new("sole"))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((X + v.co.x * 0.08, -0.035 + v.co.y * 0.185, 0.008 + v.co.z * 0.016))
    bm.to_mesh(sole.data)
    bm.free()
    sole.data.materials.append(H.mat("sole"))
    s = sole.modifiers.new("bevel", "BEVEL")
    s.width, s.segments = 0.006, 2
    mirror(sole)
    # three straps wound over the gathered cuff
    straps = [mirror(torus("strap", (X, 0.005, z), r, r * 0.95, 0.011, "strap", tilt=0.008)) for z, r in
              ((0.1, 0.046), (0.128, 0.052), (0.156, 0.06))]
    return [leg, boot, sole] + straps


def build_arm():
    """One arm, mirrored: a white sleeve from the shoulder (under the vest)
    to a loose open cuff."""
    pts = [Vector((0.09, 0.0, 0.89)), Vector((0.13, 0.005, 0.8)), Vector((0.145, 0.0, 0.7)),
           Vector((0.155, -0.012, 0.6)), Vector((0.162, -0.02, 0.53))]
    radii = [0.042, 0.038, 0.032, 0.035, 0.042]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        nxt = pts[min(i + 1, len(pts) - 1)] if i < len(pts) - 1 else p + (p - pts[i - 1])
        rings.append(tube_ring(p, nxt, r, 10))
    arm = mirror(loft("arm", rings, ["vest"] + ["shirt"] * 3, cap_start=True, cap_end=False))
    return arm


def build_hand():
    """One hand, mirrored: a palm and four slightly curled fingers and a
    thumb, each a little lofted tube (no spheres: no beads)."""
    wrist = Vector((0.163, -0.022, 0.525))
    down = Vector((0.02, -0.01, -1)).normalized()
    fwd = Vector((0, -1, 0))
    side = Vector((1, 0, 0))
    obs = []
    rings = [ring(wrist + down * k, 0.021 + 0.004 * math.sin(math.pi * k / 0.07), 0.03 + 0.006 * math.sin(math.pi * k / 0.07), 10)
             for k in (-0.005, 0.02, 0.045, 0.068)]
    obs.append(loft("palm", rings, ["skin"] * 3, sub=1))
    # four fat fingers curled into a loose fist, the tips tucked towards the palm
    for off, ln in ((-0.021, 0.036), (-0.007, 0.04), (0.007, 0.039), (0.02, 0.032)):
        base = wrist + down * 0.062 + fwd * -off
        j1 = base + (down * 0.8 - side * 0.6).normalized() * ln * 0.5
        tip = j1 + (down * 0.1 - side * 1.0).normalized() * ln * 0.45
        rings = [tube_ring(base, j1, 0.0115, 8), tube_ring(j1, tip, 0.011, 8), tube_ring(tip, tip + (tip - j1), 0.0095, 8)]
        obs.append(loft("finger", rings, ["skin"] * 2, sub=1))
    tb = wrist + down * 0.025 - fwd * 0.026 - side * 0.012
    tt = tb + (down * 0.55 - fwd * 0.45 - side * 0.7).normalized() * 0.04
    rings = [tube_ring(tb, tt, 0.013, 8), tube_ring(tt, tt + (tt - tb), 0.0095, 8)]
    obs.append(loft("thumb", rings, ["skin"], sub=1))
    return [mirror(o) for o in obs]


def build_collar():
    c = torus("collar", (0, -0.004, 0.93), 0.07, 0.058, 0.022, "gold", tilt=-0.012)
    knot = torus("knot", (0, 0, 0), 0.018, 0.012, 0.012, "gold")
    for v in knot.data.vertices:  # stood up facing forward, then put on the chest
        v.co = Vector((v.co.x, -v.co.z, v.co.y)) + Vector((0, -0.068, 0.895))
    return [c, knot]


def build_tails():
    """The tunic's tails, front and back, down to mid-thigh: two curved
    panels with thickness and a gold hem."""
    bm = bmesh.new()
    nu, nv = 8, 5
    for sgn in (-1, 1):
        grid = []
        for j in range(nv + 1):
            k = j / nv
            z = 0.62 - 0.2 * k
            half = 0.09 + 0.02 * k
            row = []
            for i in range(nu + 1):
                x = -half + 2 * half * i / nu
                bulge = 0.092 + 0.03 * k - 0.6 * x * x
                row.append((bm.verts.new((x, sgn * bulge, z)), bm.verts.new((x, sgn * (bulge - 0.014), z))))
            grid.append(row)
        for j in range(nv):
            for i in range(nu):
                for t in (0, 1):
                    q = (grid[j][i][t], grid[j][i + 1][t], grid[j + 1][i + 1][t], grid[j + 1][i][t])
                    f = bm.faces.new(q)
                    f.material_index = 1 if j == nv - 1 else 0
        for j in range(nv):
            for i in (0, nu):
                f = bm.faces.new((grid[j][i][0], grid[j + 1][i][0], grid[j + 1][i][1], grid[j][i][1]))
                f.material_index = 1 if j == nv - 1 else 0
        for i in range(nu):
            f = bm.faces.new((grid[nv][i][0], grid[nv][i + 1][0], grid[nv][i + 1][1], grid[nv][i][1]))
            f.material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tails")
    bm.to_mesh(me)
    bm.free()
    ob = H.link("tails", me)
    ob.data.materials.append(H.mat("vest"))
    ob.data.materials.append(H.mat("gold"))
    ob.modifiers.new("sub", "SUBSURF").levels = 1
    H.smooth(ob)
    return ob


def build_buckle():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.05, -0.092 + v.co.y * 0.012, 0.6225 + v.co.z * 0.036))
    me = bpy.data.meshes.new("buckle")
    bm.to_mesh(me)
    bm.free()
    ob = H.link("buckle", me)
    ob.data.materials.append(H.mat("gold"))
    b = ob.modifiers.new("bevel", "BEVEL")
    b.width, b.segments = 0.006, 2
    H.smooth(ob)
    return ob


def build_head():
    skull = H.build_skull()
    face = H.build_face(skull)
    hair, lens = H.build_hair(skull)
    parts = H.to_mesh(face + hair) + [skull]
    bpy.data.objects.remove(lens)
    for o in parts:
        H.apply_all(o)
        for v in o.data.vertices:
            v.co = Vector((0, 0, NECK)) + v.co * HEAD_SCALE
    return parts


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    head = build_head()
    body = [build_torso(), build_arm(), build_tails(), build_buckle()] + build_leg() + build_hand() + build_collar()
    for o in body:
        H.apply_all(o)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_yup=True)
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)
    zs = [(o.matrix_world @ v.co).z for o in obs for v in o.data.vertices]
    print(f"[body] {OUT}: {len(obs)} parts, {tris} tris, height {max(zs) - min(zs):.3f}")


if __name__ == "__main__":
    main()
