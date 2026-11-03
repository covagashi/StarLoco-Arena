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
import os
import random
import statistics
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

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
    def __init__(self, keep=(), keep_flat=()):
        """keep: base names of kiln materials whose faces stay as they are
        (a kiln wall under Blender ivy); keep_flat: materials whose flat
        patches stay (kiln's painted-on moss) while their spiky ones are
        rebuilt; the rest of the kiln mesh is read only for self.comps, its
        patches per material: (centre, normal, radius, area, flatness 0..1)."""
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
        self.parts = []
        self.comps = {}
        kiln = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        for o in kiln:
            self._read_kiln(o, set(keep), set(keep_flat))
        for o in list(bpy.context.scene.objects):
            if o not in self.parts:
                bpy.data.objects.remove(o)
        self.flat = set()  # materials on single-sided cards: exported double-sided

    def _read_kiln(self, o, keep, keep_flat=frozenset()):
        """Patches per material (self.comps[base] = [(centre, normal, radius,
        area)]) and, if keep, a part holding the kept faces."""
        me = o.data.copy()
        me.transform(o.matrix_world)
        src = me.copy()  # the whole kiln mesh, for soften()
        self.kiln_src = getattr(self, "kiln_src", []) + [src]
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        names = [base_name(m.name) if m else "" for m in me.materials]
        seen, kept_faces = set(), set()
        bm.faces.ensure_lookup_table()
        for f in bm.faces:
            if f.index in seen or f.material_index >= len(names):
                continue
            mi = f.material_index
            stack, comp = [f], []
            seen.add(f.index)
            while stack:  # faces of the same material touching each other
                g = stack.pop()
                comp.append(g)
                for v in g.verts:
                    for h in v.link_faces:
                        if h.index not in seen and h.material_index == mi:
                            seen.add(h.index)
                            stack.append(h)
            area = sum(g.calc_area() for g in comp) or 1e-9
            c = sum((g.calc_center_median() * g.calc_area() for g in comp), Vector()) / area
            n = sum((g.normal * g.calc_area() for g in comp), Vector())
            n = n.normalized() if n.length > 1e-9 else Vector((0, 0, 1))
            rad = max((v.co - c).length for g in comp for v in g.verts)
            flat = sum((g.normal * g.calc_area() for g in comp), Vector()).length / area
            self.comps.setdefault(names[mi], []).append((c, n, rad, area, flat))
            if names[mi] in keep_flat and flat > 0.9:
                kept_faces.update(g.index for g in comp)
        if keep or keep_flat:
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in kept_faces and (
                f.material_index >= len(names) or names[f.material_index] not in keep)], context="FACES")
            bm.to_mesh(me)
            ob = bpy.data.objects.new(o.name + "_kept", me)
            bpy.context.collection.objects.link(ob)
            self.parts.append(ob)
        bm.free()

    def moss_over(self, mats_in, mats_out=("moss", "mossL"), per_area=900, rad=(0.025, 0.05), only_spiky=False):
        """Soft faceted moss knobs where the kiln piece had patches of the
        materials mats_in, lying on the surface; only_spiky: just where
        kiln's patch was not flat (its spiky tufts)."""
        for name in mats_in:
            for c, n, r_, area, flat in self.comps.get(name, []):
                if only_spiky and flat > 0.9:
                    continue
                k = max(2, min(14, int(area * per_area)))
                t = n.orthogonal().normalized()
                b = n.cross(t)
                for _ in range(k):
                    a, d = self.rng.uniform(0, math.tau), math.sqrt(self.rng.random()) * r_ * 0.8
                    q = c + (t * math.cos(a) + b * math.sin(a)) * d
                    s = self.rng.uniform(*rad)
                    m = mats_out[1] if self.rng.random() < 0.35 else mats_out[0]
                    rot = n.to_track_quat("Z", "Y").to_matrix()
                    ob = self.blob((0, 0, 0), s, m, scale=(1.3, 1.1, 0.55), sub=1, jitter=s * 0.12)
                    ob.data.transform(Matrix.Translation(q + n * s * 0.2) @ rot.to_4x4())

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


    # --- blades, crystals, lumps, cupped leaves (deco pieces) -----------------------
    def strip(self, base, up, out, length, width, mats, bend=0.6, segs=6, shape="blade", fold=0.25,
              thick=0.012, twist=0.0):
        """A curved leaf: from base along up, curving towards out by bend
        radians over its length, width by shape ('blade': wide at the foot to
        a point; 'strap': even, rounded tip; 'leaf': narrow foot, broad
        middle, pointed tip). A crease down the middle (fold) and kiln's
        thickness. mats cycle per segment (bands); one name = plain."""
        Y = up.normalized()
        Z = out - Y * out.dot(Y)
        Z = Z.normalized() if Z.length > 1e-6 else Y.orthogonal().normalized()
        X = Y.cross(Z)
        widths = {"blade": lambda t: (1 - t) ** 0.85,
                  "strap": lambda t: 1.0 if t < 0.8 else math.sqrt(max(0.0, 1 - ((t - 0.8) / 0.2) ** 2)),
                  "leaf": lambda t: math.sin(math.pi * min(1.0, t)) ** 0.7 * (0.35 + 0.65 * min(1.0, t * 2.5))}[shape]
        bm = bmesh.new()
        pos = Vector(base)
        rows = []
        for i in range(segs + 1):
            t = i / segs
            th = bend * t
            d = Y * math.cos(th) + Z * math.sin(th)
            n = X.cross(d).normalized()
            xa = Matrix.Rotation(twist * t, 3, d) @ X
            w = width * widths(t) / 2
            rows.append((pos.copy(), xa, n, w))
            pos = pos + d * (length / segs)
        self.last_tip = rows[-1][0]  # where the leaf ends, for snow or a flower on it
        for side, off in ((0, thick / 2), (1, -thick / 2)):
            vs = [[bm.verts.new(c + n * off - xa * w), bm.verts.new(c + n * off - n * fold * w),
                   bm.verts.new(c + n * off + xa * w)] for c, xa, n, w in rows]
            for i in range(segs):
                a, b = vs[i], vs[i + 1]
                for f in ((a[0], a[1], b[1], b[0]), (a[1], a[2], b[2], b[1])):
                    face = bm.faces.new(f if side == 0 else tuple(reversed(f)))
                    face.material_index = i % len(mats)
            if not thick:
                break
        me = bpy.data.meshes.new("strip")
        bm.to_mesh(me)
        bm.free()
        if not thick:
            self.flat |= set(mats)
        return self._link("strip", me, list(mats))

    def crystal(self, base, dirv, r, length, mats=("shard", "shardD"), sides=6, tip=0.3, sink=0.05):
        """A faceted ice crystal: a prism from base along dirv ending in a
        point; faces alternate between mats, so the facets read."""
        D = dirv.normalized()
        X = D.orthogonal().normalized()
        Yv = D.cross(X)
        a0 = self.rng.uniform(0, math.tau)
        ring = lambda h, rr: [base + D * h + (X * math.cos(a0 + i * math.tau / sides) + Yv * math.sin(a0 + i * math.tau / sides))
                              * rr * self.rng.uniform(0.85, 1.1) for i in range(sides)]
        bm = bmesh.new()
        lo = [bm.verts.new(v) for v in ring(-sink, r * 1.05)]
        hi = [bm.verts.new(v) for v in ring(length * (1 - tip), r * 0.92)]
        apex = bm.verts.new(base + D * length + X * r * self.rng.uniform(-0.2, 0.2))
        for i in range(sides):
            j = (i + 1) % sides
            bm.faces.new((lo[i], lo[j], hi[j], hi[i])).material_index = i % 2
            bm.faces.new((hi[i], hi[j], apex)).material_index = (i + 1) % 2
        bm.faces.new(list(reversed(lo))).material_index = 1
        me = bpy.data.meshes.new("crystal")
        bm.to_mesh(me)
        bm.free()
        return self._link("crystal", me, list(mats))

    def lumps(self, balls, mats, res=0.045, shade=None, clip=True):
        """A soft mass (snow drift, moss cushion) from metaball ellipsoids
        balls = [(centre, radius, (sx, sy, sz))], cut at the ground.
        shade(normal, centre-relative position, rng) -> index into mats."""
        mb = bpy.data.metaballs.new("mb")
        mb.resolution = mb.render_resolution = res
        mb.threshold = 0.6
        for c, r, sc in balls:
            e = mb.elements.new(type="ELLIPSOID")
            e.co = Vector(c)
            e.radius = r
            e.size_x, e.size_y, e.size_z = sc
        ob = bpy.data.objects.new("mb", mb)
        bpy.context.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.convert(target="MESH")
        ob = bpy.context.view_layer.objects.active
        ob.select_set(False)
        me = ob.data
        bm = bmesh.new()
        bm.from_mesh(me)
        if clip:
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v.co.z < 0.0 for v in f.verts)], context="FACES")
            for v in bm.verts:
                v.co.z = max(v.co.z, 0.0)
        for f in bm.faces:
            f.material_index = shade(f.normal, f.calc_center_median(), self.rng) if shade else 0
        bm.to_mesh(me)
        bm.free()
        me.materials.clear()
        for m in mats:
            me.materials.append(self.mat(m))
        self.parts.append(ob)
        return ob

    def cupped(self, outline, M, mats, cup=0.25, thick=0.01, pick=None):
        """A leaf or petal lying in its plane, edges lifted by cup (a fan
        round its centre), placed by matrix M. pick(i) -> index into mats
        per wedge (default 0)."""
        cx = sum(x for x, _ in outline) / len(outline)
        cy = sum(y for _, y in outline) / len(outline)
        rmax = max(math.hypot(x - cx, y - cy) for x, y in outline) or 1
        bm = bmesh.new()
        for off, flip in ((thick / 2, False), (-thick / 2, True)):
            c = bm.verts.new(M @ Vector((cx, cy, off)))
            ring = [bm.verts.new(M @ Vector((x, y, off + cup * (math.hypot(x - cx, y - cy) / rmax) ** 2 * rmax)))
                    for x, y in outline]
            for i in range(len(ring)):
                f = (c, ring[i], ring[(i + 1) % len(ring)])
                face = bm.faces.new(tuple(reversed(f)) if flip else f)
                face.material_index = pick(i) if pick else 0
            if not thick:
                break
        me = bpy.data.meshes.new("cupped")
        bm.to_mesh(me)
        bm.free()
        if not thick:
            self.flat |= set(mats)
        return self._link("cupped", me, list(mats))

    def bladeform(self, stations, n, mats, pick=None):
        """A blade with a diamond section: stations = [(centre, left, right,
        half-thickness)] (left/right: Vectors from the centre to each edge),
        n = the side the faces look to. pick(station, face) -> index into
        mats (face 0, 3: the left half; 1, 2: the right), default 0."""
        bm = bmesh.new()
        rows = []
        for c, l, rr, t in stations:
            rows.append([bm.verts.new(c + l), bm.verts.new(c + n * t), bm.verts.new(c + rr), bm.verts.new(c - n * t)])
        for i in range(len(rows) - 1):
            a, b = rows[i], rows[i + 1]
            for k, f in enumerate(((a[0], b[0], b[1], a[1]), (a[1], b[1], b[2], a[2]),
                                   (a[2], b[2], b[3], a[3]), (a[3], b[3], b[0], a[0]))):
                face = bm.faces.new(f)
                face.material_index = pick(i, k) if pick else 0
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("blade")
        bm.to_mesh(me)
        bm.free()
        return self._link("blade", me, list(mats))

    # --- sculpted shapes from kiln's primitives, loom maps --------------------------
    def _apply(self, ob, mod):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.select_set(False)

    def soften(self, mats, voxel=0.012, smooth=4, ratio=0.3, carve=(), extra=()):
        """Kiln builds bodies from overlapping spheres and capsules, which read
        as a pile of balls. This merges the faces of mats into one surface
        (voxel remesh), carves out carve = [(centre, radius, (sx, sy, sz))]
        (eye sockets), smooths it, lowers its triangles to ratio and gives
        each face the material of the nearest kiln face. extra = [(material,
        centre, radius, (sx, sy, sz))]: volumes added before the merge (a
        bust, a belly) that kiln didn't have."""
        src = self.kiln_src[0]
        names = [base_name(m.name) if m else "" for m in src.materials]
        bm = bmesh.new()
        bm.from_mesh(src)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index >= len(names)
                                    or names[f.material_index] not in mats], context="FACES")
        for mname, c, r_, sc in extra:
            mi = names.index(mname)
            geom = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
            for v in geom["verts"]:
                v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2])) * r_ + Vector(c)
            for f in {f for v in geom["verts"] for f in v.link_faces}:
                f.material_index = mi
        bm.faces.ensure_lookup_table()
        tree = BVHTree.FromBMesh(bm)
        face_mat = [f.material_index for f in bm.faces]
        me = bpy.data.meshes.new("soft")
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("soft", me)
        bpy.context.collection.objects.link(ob)
        m = ob.modifiers.new("remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        self._apply(ob, m)
        for c, r_, sc in carve:
            cut = bmesh.new()
            bmesh.ops.create_icosphere(cut, subdivisions=3, radius=1.0)
            for v in cut.verts:
                v.co = Vector((v.co.x * sc[0], v.co.y * sc[1], v.co.z * sc[2])) * r_ + Vector(c)
            cme = bpy.data.meshes.new("cut")
            cut.to_mesh(cme)
            cut.free()
            cob = bpy.data.objects.new("cut", cme)
            bpy.context.collection.objects.link(cob)
            b = ob.modifiers.new("carve", "BOOLEAN")
            b.operation = "DIFFERENCE"
            b.object = cob
            self._apply(ob, b)
            bpy.data.objects.remove(cob)
        if smooth:
            sm = ob.modifiers.new("smooth", "SMOOTH")
            sm.factor = 0.5
            sm.iterations = smooth
            self._apply(ob, sm)
        if ratio < 1:
            d = ob.modifiers.new("decimate", "DECIMATE")
            d.ratio = ratio
            self._apply(ob, d)
        me.materials.clear()  # a boolean can leave an empty slot that shifts the indices
        for mat in src.materials:
            me.materials.append(mat)
        for poly in me.polygons:
            hit = tree.find_nearest(poly.center)
            if hit[2] is not None:
                poly.material_index = face_mat[hit[2]]
        self.parts.append(ob)
        return ob

    def loom_tex(self, name, tex_dir, tile):
        """Put a loom material's maps (tex_dir/<x>_albedo.png, _normal.png) on
        the materials whose base name is name, kiln's way: the albedo
        multiplied by the material's colour, the normal map, projected at
        tile metres (finish() writes the UVs)."""
        stem = os.path.basename(tex_dir.rstrip("/"))
        alb = bpy.data.images.load(os.path.join(tex_dir, stem + "_albedo.png"), check_existing=True)
        nor = bpy.data.images.load(os.path.join(tex_dir, stem + "_normal.png"), check_existing=True)
        nor.colorspace_settings.name = "Non-Color"
        for m in bpy.data.materials:
            if base_name(m.name) != name or not m.use_nodes:
                continue
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if not bsdf:
                continue
            ti = nt.nodes.new("ShaderNodeTexImage")
            ti.image = alb
            mul = nt.nodes.new("ShaderNodeMix")
            mul.data_type = "RGBA"
            mul.blend_type = "MULTIPLY"
            mul.inputs["Factor"].default_value = 1
            mul.inputs[7].default_value = bsdf.inputs["Base Color"].default_value
            nt.links.new(ti.outputs["Color"], mul.inputs[6])
            nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = nor
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
            self.tile[m.name] = tile

    # --- out ---------------------------------------------------------------------
    def finish(self, name, height=None, fit="height"):
        """Join, box-project UVs for textured materials, scale to the kiln
        piece's height (or height; fit="max": its largest side, for flat or
        wide pieces), flat-shade, export."""
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
        if fit == "none":  # kiln faces kept: same units as kiln
            k = 1.0
        elif fit == "max":
            dims = [max(v.co[i] for v in me.vertices) - min(v.co[i] for v in me.vertices) for i in range(3)]
            k = max(self.hi - self.lo) / max(dims)
        else:
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
            tile = self.tile.get(m.name) if m else None
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
            if m and base_name(m.name) in self.flat:
                m.use_backface_culling = False
        me.calc_loop_triangles()
        print(f"PIECE {name} tris={len(me.loop_triangles)} height={(height or self.height):.2f}")
        bpy.ops.export_scene.gltf(filepath=self.dst, export_format="GLB", use_selection=True)
