"""Shared helpers for the Blender piece scripts (tools/blender/models/*.py).

A piece script replaces a kiln piece: it reads the kiln GLB for its
materials (by base name, so the looms' tree_b, tree_c… work), their
texture scale and the piece's height, builds its own mesh and writes it
over the kiln one (tools/blender/build_models.py runs it per loom).

    from lib import Piece, K
    p = Piece()                      # parses argv: <kiln.glb> <out.glb> [seed]
    p.tube([K(0, 0, 0), K(0, 1, 0)], 0.1, 0.05, mat="bark")
    p.finish("my_piece")

K(x, y, z) takes kiln's y-up coordinates (the ones in the .kx.js) and
returns Blender's z-up ones, so a script can follow the kiln layout the
owner approved. Everything is flat-shaded like the rest of the kit; the
game smooths "snow*" and "soft*" materials itself (kit_dress.gd).
"""
import math
import random
import statistics
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

# kiln's ovate leaf (arena 2): base at the origin, pointing +y, 1 long
OVATE = [(0, 0), (0.24, 0.16), (0.32, 0.45), (0.2, 0.78), (0, 1), (-0.2, 0.78), (-0.32, 0.45), (-0.24, 0.16)]


def maple(r=0.1):
    """Kiln's maple leaf outline (arena 5), roughly centred, r across."""
    out = []
    for i in range(20):
        t = i / 20 * math.pi * 2
        lobe = abs(math.cos(2.5 * (t - math.pi / 2))) ** 1.4
        rr = r * (0.55 + 0.45 * lobe) * (1 - 0.4 * max(0, -math.sin(t)))
        out.append((math.cos(t) * rr, math.sin(t) * rr + r * 0.3))
    return out


def K(x, y, z):
    """Kiln (y up, z towards the camera) to Blender (z up)."""
    return Vector((x, -z, y))


R2 = math.sqrt(0.5)
# kiln's screen space (arena 2: sp(u, y, v)): u across the screen, v towards
# the camera, y up; and the camera direction, in Blender axes
U_AX, V_AX, Y_AX = K(R2, 0, -R2), K(R2, 0, R2), Vector((0, 0, 1))
CAM = K(0.612, 0.5, 0.612).normalized()


def SP(u, y, v):
    return U_AX * u + V_AX * v + Y_AX * y


def base_name(name):
    return name[:-2] if name[-2:] in ("_b", "_c") else name


class Piece:
    def __init__(self):
        args = sys.argv[sys.argv.index("--") + 1:]
        self.src, self.dst = args[0], args[1]
        self.rng = random.Random(int(args[2]) if len(args) > 2 else 7)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=self.src)
        self.mats, self.tile = {}, {}
        lo, hi = Vector((1e9,) * 3), Vector((-1e9,) * 3)
        ratios = {}
        for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
            me = o.data
            for v in me.vertices:
                w = o.matrix_world @ v.co
                lo, hi = Vector(map(min, lo, w)), Vector(map(max, hi, w))
            uv = me.uv_layers.active.data if me.uv_layers.active else None
            if uv:  # kiln projects textures: uv = position / tile size
                for p in list(me.polygons)[::7]:
                    a, b = p.loop_indices[0], p.loop_indices[1]
                    d = (me.vertices[me.loops[a].vertex_index].co - me.vertices[me.loops[b].vertex_index].co).length
                    if d > 1e-4 and p.material_index < len(me.materials):
                        m = me.materials[p.material_index]
                        ratios.setdefault(m.name, []).append((uv[a].uv - uv[b].uv).length / d)
        for m in bpy.data.materials:
            self.mats.setdefault(base_name(m.name), m)
            textured = m.use_nodes and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes)
            if textured and ratios.get(m.name):
                self.tile[m.name] = 1 / statistics.median(ratios[m.name])
        self.lo, self.hi = lo, hi
        self.height = hi.z - lo.z
        for o in list(bpy.context.scene.objects):
            bpy.data.objects.remove(o)
        self.parts = []
        self.flat = set()  # materials on single-sided cards: exported double-sided

    def first(self, *names):
        """The first of names this piece has (a loom can swap a material)."""
        for n in names:
            if n in self.mats:
                return n
        raise KeyError(f"{self.src} has none of {names}")

    def mat(self, name):
        if name not in self.mats:
            raise KeyError(f"{self.src} has no material {name!r} (has {sorted(self.mats)})")
        return self.mats[name]

    def _link(self, name, me, mats):
        ob = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(ob)
        for m in mats:
            me.materials.append(self.mat(m))
        self.parts.append(ob)
        return ob

    # --- trunks, limbs, twigs ----------------------------------------------
    def tube(self, pts, r0, r1, mat="bark", sides=8, twist=0.0, res=4, caps=True):
        """A tube through pts (Vectors), radius r0 tapering to r1."""
        cu = bpy.data.curves.new("tube", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = 1.0
        cu.bevel_resolution = max(0, sides // 4 - 1)
        cu.resolution_u = res
        cu.use_fill_caps = caps
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        for i, (p, bp) in enumerate(zip(pts, sp.bezier_points)):
            t = i / (len(pts) - 1)
            bp.co = p
            bp.handle_left_type = bp.handle_right_type = "AUTO"
            bp.radius = r0 + (r1 - r0) * t
            bp.tilt = twist * t
        ob = bpy.data.objects.new("tube", cu)
        bpy.context.collection.objects.link(ob)
        ob.data.materials.append(self.mat(mat))
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.convert(target="MESH")
        ob.select_set(False)
        self.parts.append(ob)
        return ob

    def roots(self, n, r, length, z=0.16, mat="bark", a0=0.0, sides=6):
        """n root flares round the foot, thick at the trunk, sinking in."""
        for k in range(n):
            a = a0 + k * math.tau / n + self.rng.uniform(-0.25, 0.25)
            d = Vector((math.cos(a), math.sin(a), 0))
            ln = length * self.rng.uniform(0.8, 1.15)
            self.tube([d * r * 0.3 + Vector((0, 0, z)), d * ln * 0.55 + Vector((0, 0, z * 0.25)),
                       d * ln + Vector((0, 0, -0.02))], r, r * 0.35, mat=mat, sides=sides)

    # --- solid lumps -----------------------------------------------------------
    def blob(self, c, r, mat, scale=(1, 1, 1), sub=2, jitter=0.0, rot_z=0.0):
        """An icosphere at c, radius r, squashed by scale (Blender axes)."""
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        for v in bm.verts:
            v.co = Matrix.Rotation(rot_z, 3, "Z") @ Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) * r
            if jitter:
                v.co += Vector([self.rng.uniform(-jitter, jitter) for _ in range(3)])
            v.co += Vector(c)
        me = bpy.data.meshes.new("blob")
        bm.to_mesh(me)
        bm.free()
        return self._link("blob", me, [mat])

    def lathe(self, profile, mat, sides=8, c=(0, 0, 0), jitter=0.0, tilt=(0, 0)):
        """Revolve [(r, z), ...] about z, at c, leaning tilt (deg about x, y)."""
        bm = bmesh.new()
        rings = []
        for r, z in profile:
            ring = []
            for i in range(sides):
                a = i / sides * math.tau
                v = Vector((math.cos(a) * r, math.sin(a) * r, z))
                if jitter and r > 0:
                    v += Vector([self.rng.uniform(-jitter, jitter) for _ in range(3)])
                ring.append(bm.verts.new(v))
            rings.append(ring)
        for a, b in zip(rings, rings[1:]):
            for i in range(sides):
                j = (i + 1) % sides
                bm.faces.new((a[i], a[j], b[j], b[i]))
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(tilt[1]), 4, "Y") @ Matrix.Rotation(math.radians(tilt[0]), 4, "X")
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        me = bpy.data.meshes.new("lathe")
        bm.to_mesh(me)
        bm.free()
        return self._link("lathe", me, [mat])

    # --- leaves ------------------------------------------------------------------
    def cards(self, items, outline, mats, thick=0.0):
        """Leaf cards: items = [(matrix, mat name)], outline in the card
        plane. thick (before the card's scale) gives them kiln's thickness:
        paper-thin cards catch shadow acne stripes in the game."""
        bm = bmesh.new()
        index = {m: i for i, m in enumerate(mats)}
        for m, name in items:
            front = [bm.verts.new(m @ Vector((x, y, thick / 2))) for x, y in outline]
            faces = [bm.faces.new(front)]
            if thick:
                back = [bm.verts.new(m @ Vector((x, y, -thick / 2))) for x, y in outline]
                faces.append(bm.faces.new(list(reversed(back))))
                n = len(outline)
                for i in range(n):
                    j = (i + 1) % n
                    faces.append(bm.faces.new((front[j], front[i], back[i], back[j])))
            for f in faces:
                f.material_index = index[name]
        me = bpy.data.meshes.new("leaves")
        bm.to_mesh(me)
        bm.free()
        if not thick:
            self.flat |= set(mats)
        return self._link("leaves", me, mats)

    def leaf_at(self, pos, nrm, size, spin=None, tip=25):
        """A card at pos facing out along nrm, spun about it, tipped a little."""
        spin = self.rng.uniform(0, math.tau) if spin is None else spin
        rot = nrm.to_track_quat("Z", "Y").to_matrix().to_4x4() @ Matrix.Rotation(spin, 4, "Z") \
            @ Matrix.Rotation(math.radians(self.rng.uniform(-tip, tip)), 4, "X")
        return Matrix.Translation(pos) @ rot @ Matrix.Scale(size, 4)

    def spray(self, pos, nrm, n, size, mats, spread=190, out=35, camera=0.35):
        """n ovate leaves fanned from pos over the surface, tips leaning out."""
        nrm = nrm.normalized()
        t = nrm.orthogonal().normalized()
        b = nrm.cross(t)
        a0 = self.rng.uniform(0, math.tau)
        items = []
        for i in range(n):
            a = a0 + math.radians(-spread / 2 + spread * (i / max(1, n - 1)) + self.rng.uniform(-12, 12))
            d = (t * math.cos(a) + b * math.sin(a)).normalized()
            tipdir = (d * math.cos(math.radians(out)) + nrm * math.sin(math.radians(out))).normalized()
            # like kiln, the cards turn towards the camera (seen edge-on they
            # read as slivers), only tipped a little by the surface
            face = (nrm * camera + CAM * (1 - camera)).normalized()
            tipdir = tipdir - face * tipdir.dot(face)
            tipdir = tipdir.normalized() if tipdir.length > 1e-4 else Vector((0, 0, 1))
            x = tipdir.cross(face)
            m = Matrix((x, tipdir, face)).transposed().to_4x4()
            s = size * self.rng.uniform(0.8, 1.2)
            items.append((Matrix.Translation(pos) @ m @ Matrix.Scale(s, 4), mats[i % len(mats)]))
        return items

    def foliage(self, blobs, count, size, shade, core="leafS", hollow=None, per=5):
        """Kiln's autumn foliage, in its screen space (SP): sprays of ovate
        leaves over ellipsoids blobs = [(u, y, v, ru, ry, rv)], more of them
        up and towards the camera, none on the far side; a dark core inside
        each blob so no gaps show. shade(ny, face, rng) -> [material, ...]
        for the spray (face = how much it faces the camera). hollow =
        (u, y, ru, ry): no leaves on its camera side, the stem shows there."""
        vols = [b[3] * b[4] * b[5] for b in blobs]
        tot = sum(vols)
        if core:
            for u, y, v, ru, ry, rv in blobs:
                self.blob(SP(u, y, v), 0.7, core, scale=(ru, rv, ry), sub=1, jitter=0.03, rot_z=math.radians(45))
        items, names = [], set()
        for _ in range(count):
            t, k = self.rng.random() * tot, 0
            while t > vols[k] and k < len(blobs) - 1:
                t -= vols[k]
                k += 1
            u, y, v, ru, ry, rv = blobs[k]
            z = self.rng.random() * 2 - 0.7
            ph = self.rng.random() * math.tau
            rr = math.sqrt(max(0.0, 1 - min(1.0, z * z)))
            nu = math.cos(ph) * rr
            nv = math.sin(ph) * rr * 0.6 + 0.4 * abs(math.sin(ph) * rr)
            ny = min(1.0, z)
            d = 0.72 + self.rng.random() * 0.26
            pu, py, pv = u + nu * ru * d, y + ny * ry * d, v + nv * rv * d
            if hollow and math.hypot((pu - hollow[0]) / hollow[2], (py - hollow[1]) / hollow[3]) < 1 and pv > v:
                continue
            w = SP(nu, ny, nv)
            face = w.normalized().dot(CAM)
            if face < -0.35:
                continue
            mats = shade(ny, face, self.rng)
            names |= set(mats)
            items += self.spray(SP(pu, py, pv), w, per, size * (0.9 + 0.25 * d), mats, camera=0.5)
        self.cards(items, OVATE, sorted(names), thick=0.012 / size)

    def twig(self, pts, r, mat="twigP", tip=0.0, tip_mats=("leaf", "leafL", "leafD"), sides=5):
        """A twig through screen points [(u, y, v)], tapering by half, with a
        spray of leaves at its tip if tip (leaf size)."""
        w = [SP(*p) for p in pts]
        self.tube(w, r, r * 0.5, mat=mat, sides=sides)
        if tip:
            d = (w[-1] - w[-2]).normalized()
            self.cards(self.spray(w[-1], d, 5, tip, list(tip_mats), spread=200, out=20), OVATE, list(tip_mats), thick=0.012 / tip)

    def maple_crown(self, clumps, zmin, density=(40, 90), size=(1.2, 1.7), dark=0.78):
        """The approved green tree's crown (leaf_tree.py): a dark treeD core
        of icospheres, maple leaves over each clump [(centre, r)], light on
        top, dark inside and underneath, treeX now and then."""
        core = bmesh.new()
        for c, r in clumps:
            bmesh.ops.create_icosphere(core, subdivisions=2, radius=r * 0.62, matrix=Matrix.Translation(c))
        for v in core.verts:
            v.co += Vector([self.rng.uniform(-0.03, 0.03) for _ in range(3)])
        me = bpy.data.meshes.new("core")
        core.to_mesh(me)
        core.free()
        self._link("core", me, ["treeD"])
        outline = maple()
        items = []
        for c, r in clumps:
            for _ in range(int(density[0] + r * density[1])):
                zz = 1 - 1.75 * self.rng.random()
                rr = math.sqrt(max(0.0, 1 - zz * zz))
                a = self.rng.random() * math.tau
                nrm = Vector((rr * math.cos(a), rr * math.sin(a), zz)).normalized()
                pos = Vector(c) + nrm * r * self.rng.uniform(0.7, 0.98)
                if pos.z < zmin:
                    continue
                depth = (pos - Vector(c)).length / r
                name = ("treeX" if self.rng.random() < 0.06 else "treeD" if nrm.z < -0.15 or depth < dark
                        else "treeL" if nrm.z > 0.7 and self.rng.random() < 0.6 else "tree")
                items.append((self.leaf_at(pos, nrm, self.rng.uniform(*size)), name))
        self.cards(items, outline, ["treeL", "tree", "treeD", "treeX"])

    # --- out ---------------------------------------------------------------------
    def finish(self, name, height=None):
        """Join, box-project UVs for textured materials, scale to the kiln
        piece's height (or height), flat-shade, export."""
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.parts:
            o.select_set(True)
        ob = self.parts[0]  # join merges the selection into the active object
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.join()
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        ob.name = name
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        me = ob.data
        zs = [v.co.z for v in me.vertices]
        k = (height or self.height) / (max(zs) - min(zs))
        for v in me.vertices:  # about the origin (the foot), to the kiln height
            v.co = v.co * k
        while len(me.uv_layers) > 1:  # parts bring their own layers: keep one
            me.uv_layers.remove(me.uv_layers[-1])
        if not me.uv_layers:
            me.uv_layers.new(name="UVMap")
        me.uv_layers.active = me.uv_layers[0]
        uv = me.uv_layers[0].data
        for p in me.polygons:
            m = me.materials[p.material_index]
            tile = self.tile.get(m.name)
            if not tile:
                continue
            n = p.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            u, w = [(1, 2), (0, 2), (0, 1)][ax]
            for li in p.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co
                uv[li].uv = (co[u] / tile, co[w] / tile)
        for p in me.polygons:
            p.use_smooth = False
        for m in me.materials:
            if base_name(m.name) in self.flat:
                m.use_backface_culling = False
        me.calc_loop_triangles()
        print(f"PIECE {name} tris={len(me.loop_triangles)} height={(height or self.height):.2f}")
        bpy.ops.export_scene.gltf(filepath=self.dst, export_format="GLB", use_selection=True)
