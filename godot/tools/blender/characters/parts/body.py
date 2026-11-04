"""S35, fighter 1 (class 1) modelled on the owner's boceto
(~/codigo/m7-referencias/s35/boceto-clase1-flow.jpg, 2026-11-04): front,
side and back drawn after the retail sprite. Still unrigged.

    blender -b -P tools/blender/characters/parts/body.py -- [out.glb]

The numbers below are measured, not guessed: the boceto's front and side
silhouettes (background flood-filled, 415 px = 1.45 m), read per height as
half widths and depths. Each part is a low cage subdivided: the torso a
loft of those sections, one leg, arm, hand and foot mirrored in X, the
tunic tails, sash, shoulder pads, armbands, sandals and the vest's panel
and emblem as pieces of their own, and the head from head.py. Skin and
hair are tint channels (materials skin*, hair*: the game recolours them
per fighter, like the retail). Blender is z-up, the figure faces -Y.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import head as H  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0] if args else os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "art", "characters", "out", "parts", "body.glb"))

# skin and hair are the default tints; the rest is the class's outfit
H.PALETTE.update({
    "skin": "e8bd96", "hair": "e3cf86", "hair_brow": "c9b26a",
    "vest": "2f3138", "vest_panel": "8d8c8a", "trim": "f0ebdf", "gold": "d9a83e",
    "sash": "eee8da", "tails": "6f6e6c", "pants": "4a8f96", "cuff": "eee8da",
    "wrap": "e9e6df", "sole": "5a4330", "strap": "d9a83e", "pad": "45474e",
})
NECK = 0.955        # the head part sits on the neck at this height
HEAD_SCALE = 1.08


# ---------------------------------------------------------------- lofts

def ring(c, rx, fwd, back, n=14):
    """A section round c: half width rx, reaching fwd to the front (-Y)
    and back to the back (+Y)."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        x, y = math.cos(a) * rx, math.sin(a)
        y *= back if y > 0 else fwd
        pts.append(Vector(c) + Vector((x, y, 0)))
    return pts


def tube_ring(a, b, r, n=10, sx=1.0, sy=1.0):
    d = (b - a).normalized()
    u = Vector((1, 0, 0))
    u = (u - d * u.dot(d)).normalized()
    v = d.cross(u)
    return [a + (u * math.cos(2 * math.pi * i / n) * sx + v * math.sin(2 * math.pi * i / n) * sy) * r for i in range(n)]


def loft(name, rings, mats, cap_start=True, cap_end=True, sub=2):
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
        ob.modifiers.new("sub", "SUBSURF").levels = sub
    H.smooth(ob)
    return ob


def mirror(ob):
    m = ob.modifiers.new("mirror", "MIRROR")
    m.use_axis[0] = True
    ob.modifiers.move(len(ob.modifiers) - 1, 0)
    return ob


def torus(name, c, rx, ry, r, mat, n=24, m=8, tilt=0.0, flat=0.8):
    bm = bmesh.new()
    grid = []
    for i in range(n):
        a = 2 * math.pi * i / n
        ctr = Vector(c) + Vector((math.cos(a) * rx, math.sin(a) * ry, tilt * math.sin(a)))
        out = Vector((math.cos(a) * ry, math.sin(a) * rx, 0)).normalized()
        grid.append([bm.verts.new(ctr + (out * math.cos(2 * math.pi * k / m) + Vector((0, 0, 1)) * math.sin(2 * math.pi * k / m) * flat) * r)
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


def box(name, c, half, mat, bevel=0.006, sub=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector(c) + Vector((v.co.x * 2 * half[0], v.co.y * 2 * half[1], v.co.z * 2 * half[2]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = H.link(name, me)
    ob.data.materials.append(H.mat(mat))
    if bevel:
        b = ob.modifiers.new("bevel", "BEVEL")
        b.width, b.segments = bevel, 2
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
    H.smooth(ob)
    return ob


def front_decal(name, target, poly, mat, lift=0.003, thick=0.004, side=-1):
    """A flat shape laid on a surface from the front (side=-1) or the back
    (+1): poly is an outline in (x, z). The outline is filled, subdivided
    and every vertex shot at target and lifted off it (a clean edge, no
    pixel steps), then given a thickness. For the vest's panel, hem and
    emblem: they follow the chest exactly."""
    dg = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(target, dg)
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0, z)) for x, z in poly]
    edges = [bm.edges.new((vs[i], vs[(i + 1) % len(vs)])) for i in range(len(vs))]
    bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges, normal=(0, -1, 0))
    for _ in range(3):
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    for v in bm.verts:
        hit, n, _, _ = tree.ray_cast(Vector((v.co.x, side * 1.0, v.co.z)), Vector((0, -side, 0)))
        if hit is not None:
            v.co = hit + n * lift
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = H.link(name, me)
    if (ob.data.polygons[0].normal.y > 0) == (side < 0):  # face away from the body
        for p in ob.data.polygons:
            p.flip()
    ob.data.materials.append(H.mat(mat))
    so = ob.modifiers.new("thick", "SOLIDIFY")
    so.thickness, so.offset = thick, 1.0
    H.smooth(ob)
    return ob


# ---------------------------------------------------------------- parts

def build_torso():
    """Hips to neck, the boceto's sections: a slim vest (0.16 wide at the
    chest), the sash at 0.62-0.665, the seat of the trousers below."""
    R = [  # z, half width, front, back, material of the band above
        (0.49, 0.125, 0.085, 0.09, "pants"),
        (0.56, 0.13, 0.09, 0.095, "pants"),
        (0.615, 0.132, 0.092, 0.095, "sash"),
        (0.64, 0.135, 0.097, 0.1, "sash"),
        (0.668, 0.115, 0.088, 0.088, "vest"),
        (0.72, 0.098, 0.08, 0.082, "vest"),
        (0.77, 0.088, 0.076, 0.08, "vest"),
        (0.82, 0.088, 0.076, 0.078, "vest"),
        (0.87, 0.11, 0.074, 0.074, "vest"),
        (0.91, 0.1, 0.066, 0.068, "vest"),
        (0.95, 0.055, 0.05, 0.055, "vest"),      # the high dark collar
        (0.985, 0.04, 0.039, 0.044, "skin"),
        (1.03, 0.034, 0.034, 0.038, "skin"),
    ]
    rings = [ring((0, 0, z), w, f, b, 16) for z, w, f, b, _ in R]
    return loft("torso", rings, [m for *_, m in R][:-1])


def build_vest_front(torso):
    """The boceto's chest: a pale panel down the front ending in a white
    curve over the sash, and the gold emblem at the top (a fork with two
    hooks), the same emblem smaller on the back."""
    panel = [(-0.03, 0.84), (0.03, 0.84), (0.05, 0.79), (0.075, 0.73), (0.085, 0.69), (0.05, 0.68), (0, 0.695),
             (-0.05, 0.68), (-0.085, 0.69), (-0.075, 0.73), (-0.05, 0.79)]
    hem = [(-0.095, 0.69), (-0.05, 0.676), (0, 0.694), (0.05, 0.676), (0.095, 0.69), (0.1, 0.672),
           (0.05, 0.656), (0, 0.672), (-0.05, 0.656), (-0.1, 0.672)]
    emblem = [(-0.03, 0.905), (-0.012, 0.905), (-0.012, 0.87), (0.012, 0.87), (0.012, 0.905), (0.03, 0.905),
              (0.03, 0.86), (0.045, 0.85), (0.04, 0.835), (0.012, 0.845), (0.012, 0.8), (-0.012, 0.8),
              (-0.012, 0.845), (-0.04, 0.835), (-0.045, 0.85), (-0.03, 0.86)]
    back = [(-0.03, 0.9), (-0.012, 0.9), (-0.012, 0.87), (0.012, 0.87), (0.012, 0.9), (0.03, 0.9),
            (0.03, 0.855), (0.045, 0.845), (0.04, 0.83), (0.012, 0.84), (0.012, 0.82), (-0.012, 0.82),
            (-0.012, 0.84), (-0.04, 0.83), (-0.045, 0.845), (-0.03, 0.855)]
    return [front_decal("vest_panel", torso, panel, "vest_panel"),
            front_decal("trim", torso, hem, "trim", lift=0.004),
            front_decal("emblem", torso, emblem, "gold", lift=0.006, thick=0.005),
            front_decal("emblem_back", torso, back, "gold", lift=0.004, thick=0.005, side=1)]


def build_shoulder_pads():
    """Rounded dark plates on the shoulders."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        z = max(z, -0.15)  # a dome, flattened underneath
        v.co = Vector((0.108 + x * 0.045, y * 0.05, 0.895 + z * 0.028))
    me = bpy.data.meshes.new("pad")
    bm.to_mesh(me)
    bm.free()
    pad = H.link("pad", me)
    pad.data.materials.append(H.mat("pad"))
    pad.modifiers.new("sub", "SUBSURF").levels = 1
    H.smooth(pad)
    return [mirror(pad)]


def build_leg():
    """One leg, mirrored: knee-length baggy trousers (full at the knee,
    flared at the cuff), a white cuff, a bare shin."""
    R = [  # z, centre x, half width, half depth, material above
        (0.5, 0.07, 0.085, 0.085, "pants"),
        (0.44, 0.075, 0.068, 0.08, "pants"),
        (0.38, 0.082, 0.072, 0.085, "pants"),
        (0.32, 0.088, 0.074, 0.09, "pants"),
        (0.28, 0.09, 0.08, 0.092, "pants"),
        (0.25, 0.088, 0.07, 0.08, "cuff"),
        (0.215, 0.086, 0.052, 0.054, "skin"),
        (0.19, 0.085, 0.034, 0.036, "skin"),
        (0.13, 0.084, 0.03, 0.032, "skin"),
        (0.085, 0.086, 0.028, 0.03, "skin"),
    ]
    rings = [ring((x, 0.005, z), w, d, d, 14) for z, x, w, d, _ in R]
    return mirror(loft("leg", rings, [m for *_, m in R][:-1], cap_end=False))


def build_foot():
    """A bare foot on a sandal: heel to toes along -Y, the sole and two
    gold straps (over the toes and round the ankle)."""
    X = 0.088
    secs = [  # y, half width, top z
        (0.055, 0.026, 0.07),
        (0.03, 0.032, 0.085),
        (-0.01, 0.035, 0.06),
        (-0.06, 0.04, 0.04),
        (-0.1, 0.04, 0.028),
        (-0.125, 0.032, 0.02),
    ]
    rings = []
    for y, hw, top in secs:
        c = Vector((X, y, 0.018 + (top - 0.018) * 0.5))
        h = (top - 0.018) * 0.5
        rings.append([c + Vector((math.cos(2 * math.pi * i / 12) * hw, 0, math.sin(2 * math.pi * i / 12) * h))
                      for i in range(12)])
    foot = mirror(loft("foot", rings, ["skin"] * (len(rings) - 1)))
    sole = mirror(box("sole", (X, -0.035, 0.009), (0.046, 0.1, 0.009), "sole", bevel=0.006))
    toe_strap = mirror(torus("strap", (X, -0.075, 0.028), 0.043, 0.012, 0.007, "strap", flat=0.6))
    ankle = mirror(torus("strap", (X, 0.02, 0.075), 0.034, 0.036, 0.007, "strap", flat=0.8))
    return [foot, sole, toe_strap, ankle]


def build_tails():
    """The tunic's tails from the boceto: two side panels hanging from the
    sash to mid-thigh, open at the front and the back (the legs pass), a
    gold trim along the hem and the front edge."""
    obs = []
    for X in (1, -1):
        bm = bmesh.new()
        nu, nv = 10, 6
        grid = []
        for j in range(nv + 1):
            k = j / nv
            r = 0.14 + 0.035 * k
            row = []
            for i in range(nu + 1):
                a = math.radians(-70 + 140 * i / nu)          # from the front-side round to the back-side
                # the hem curves: longest at the side, rising to the open edges
                z = 0.645 - (0.11 + 0.06 * math.cos(a * 1.25)) * k
                p = Vector((X * math.cos(a) * r, math.sin(a) * r * 0.85, z))
                inner = Vector((X * math.cos(a) * (r - 0.012), math.sin(a) * (r - 0.012) * 0.85, z))
                row.append((bm.verts.new(p), bm.verts.new(inner)))
            grid.append(row)
        for j in range(nv):
            for i in range(nu):
                hemline = j == nv - 1 or i == 0
                for t in (0, 1):
                    f = bm.faces.new((grid[j][i][t], grid[j][i + 1][t], grid[j + 1][i + 1][t], grid[j + 1][i][t]))
                    f.material_index = 1 if hemline else 0
        for i in range(nu):
            f = bm.faces.new((grid[nv][i][0], grid[nv][i + 1][0], grid[nv][i + 1][1], grid[nv][i][1]))
            f.material_index = 1
        for j in range(nv):
            for i in (0, nu):
                f = bm.faces.new((grid[j][i][0], grid[j + 1][i][0], grid[j + 1][i][1], grid[j][i][1]))
                f.material_index = 1 if i == 0 or j == nv - 1 else 0
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("tails")
        bm.to_mesh(me)
        bm.free()
        ob = H.link("tails", me)
        ob.data.materials.append(H.mat("tails"))
        ob.data.materials.append(H.mat("gold"))
        ob.modifiers.new("sub", "SUBSURF").levels = 1
        H.smooth(ob)
        obs.append(ob)
    return obs


def build_arm():
    """One arm, mirrored, held a little out (A pose, so the rig can bend
    it): bare upper arm, a gold band, white wraps from the elbow down."""
    pts = [Vector((0.085, 0.0, 0.885)), Vector((0.13, 0.0, 0.83)), Vector((0.155, 0.0, 0.77)),
           Vector((0.175, -0.004, 0.71)), Vector((0.19, -0.008, 0.66)), Vector((0.203, -0.012, 0.615))]
    radii = [0.042, 0.033, 0.031, 0.032, 0.028, 0.03]
    mats = ["skin", "skin", "wrap", "wrap", "wrap"]
    rings = []
    for i, (p, r) in enumerate(zip(pts, radii)):
        nxt = pts[i + 1] if i < len(pts) - 1 else p + (p - pts[i - 1])
        rings.append(tube_ring(p, nxt, r, 12))
    arm = mirror(loft("arm", rings, mats))
    band = torus("armband", (0, 0, 0), 0.034, 0.034, 0.006, "gold")
    a, b = pts[1], pts[2]
    d = (b - a).normalized()
    u = Vector((1, 0, 0))
    u = (u - d * u.dot(d)).normalized()
    w = d.cross(u)
    for v in band.data.vertices:  # stand the band across the upper arm
        co = v.co.copy()
        v.co = a.lerp(b, 0.55) + u * co.x + w * co.y + d * co.z
    return [arm, mirror(band)]


def build_hand():
    """One hand, mirrored: a big cartoon hand (the boceto's reach 0.61 to
    0.49), a palm, four fingers a little curled, a thumb."""
    wrist = Vector((0.205, -0.012, 0.61))
    down = Vector((0.1, -0.02, -1)).normalized()
    fwd = Vector((0, -1, 0))
    side = Vector((1, 0, 0))
    obs = []

    def bulge(k):
        return math.sin(math.pi * (k + 0.005) / 0.075)
    rings = [ring(wrist + down * k, 0.02 + 0.006 * bulge(k), 0.028 + 0.008 * bulge(k), 0.028 + 0.008 * bulge(k), 10)
             for k in (-0.005, 0.02, 0.045, 0.07)]
    obs.append(loft("palm", rings, ["skin"] * 3, sub=1))
    for off, ln in ((-0.024, 0.04), (-0.008, 0.046), (0.008, 0.044), (0.023, 0.036)):
        base = wrist + down * 0.066 + fwd * -off
        j1 = base + (down * 0.85 - side * 0.5).normalized() * ln * 0.55
        tip = j1 + (down * 0.4 - side * 0.9).normalized() * ln * 0.45
        rings = [tube_ring(base, j1, 0.0115, 8), tube_ring(j1, tip, 0.0108, 8), tube_ring(tip, tip + (tip - j1), 0.0092, 8)]
        obs.append(loft("finger", rings, ["skin"] * 2, sub=1))
    tb = wrist + down * 0.025 - fwd * 0.03 - side * 0.012
    tt = tb + (down * 0.5 - fwd * 0.45 - side * 0.75).normalized() * 0.042
    rings = [tube_ring(tb, tt, 0.013, 8), tube_ring(tt, tt + (tt - tb), 0.0095, 8)]
    obs.append(loft("thumb", rings, ["skin"], sub=1))
    return [mirror(o) for o in obs]


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
    build_head()
    torso = build_torso()
    H.apply_all(torso)
    body = [torso] + build_vest_front(torso) + build_shoulder_pads() + build_tails() + [build_leg()] \
        + build_foot() + build_arm() + build_hand()
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
