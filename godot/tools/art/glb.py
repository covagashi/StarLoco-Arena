"""S34: just enough of a GLB reader for the asset checks (check.py), with
the standard library only: triangles, bones, animations, textures and the
bounds of the scene in world space (node transforms applied).

    from glb import Glb
    g = Glb("art/characters/out/feca_f.glb")
    g.tris, g.bones, g.anims, g.images, g.bounds()
"""
import json
import struct


class Glb:
    def __init__(self, path):
        self.path = path
        data = open(path, "rb").read()
        self.size = len(data)
        magic, _version, _length = struct.unpack_from("<4sII", data, 0)
        if magic != b"glTF":
            raise ValueError("not a GLB")
        off = 12
        self.json = {}
        self.bin = b""
        while off < len(data):
            n, kind = struct.unpack_from("<I4s", data, off)
            chunk = data[off + 8:off + 8 + n]
            if kind == b"JSON":
                self.json = json.loads(chunk)
            elif kind == b"BIN\x00":
                self.bin = chunk
            off += 8 + n
        j = self.json
        self.meshes = j.get("meshes", [])
        self.materials = [m.get("name", "") for m in j.get("materials", [])]
        self.anims = [a.get("name", "") for a in j.get("animations", [])]
        self.bones = max((len(s.get("joints", [])) for s in j.get("skins", [])), default=0)
        self.tris = 0
        for node in self._mesh_nodes():
            for p in self.meshes[node["mesh"]].get("primitives", []):
                if p.get("mode", 4) != 4:
                    continue
                if "indices" in p:
                    self.tris += j["accessors"][p["indices"]]["count"] // 3
                else:
                    self.tris += j["accessors"][p["attributes"]["POSITION"]]["count"] // 3
        self.images = [self._image(i) for i in range(len(j.get("images", [])))]

    def _mesh_nodes(self):
        return [n for n in self.json.get("nodes", []) if "mesh" in n]

    def _image(self, i):
        """{name, mime, w, h, bytes} of an embedded image (0×0 if unread)."""
        im = self.json["images"][i]
        out = {"name": im.get("name", str(i)), "mime": im.get("mimeType", ""), "w": 0, "h": 0, "bytes": 0}
        if "bufferView" not in im:
            return out
        bv = self.json["bufferViews"][im["bufferView"]]
        raw = self.bin[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        out["bytes"] = len(raw)
        out["w"], out["h"] = image_size(raw)
        return out

    def bounds(self):
        """(min xyz, max xyz) of every mesh's POSITION bounds, through the
        node transforms (the accessor min/max corners, so a rotated node's
        box is a little loose; skinned meshes use their bind pose)."""
        j = self.json
        nodes = j.get("nodes", [])
        parent = {}
        for i, n in enumerate(nodes):
            for c in n.get("children", []):
                parent[c] = i
        lo = [float("inf")] * 3
        hi = [float("-inf")] * 3
        for i, n in enumerate(nodes):
            if "mesh" not in n:
                continue
            m = _world(nodes, parent, i) if "skin" not in n else _identity()
            for p in self.meshes[n["mesh"]].get("primitives", []):
                acc = j["accessors"][p["attributes"]["POSITION"]]
                if "min" not in acc:
                    continue
                a, b = acc["min"], acc["max"]
                for x in (a[0], b[0]):
                    for y in (a[1], b[1]):
                        for z in (a[2], b[2]):
                            v = _apply(m, (x, y, z))
                            for k in range(3):
                                lo[k] = min(lo[k], v[k])
                                hi[k] = max(hi[k], v[k])
        return lo, hi


def image_size(raw):
    """(w, h) of a PNG or JPEG byte string, (0, 0) otherwise."""
    if raw[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", raw[16:24])
    if raw[:2] == b"\xff\xd8":
        i = 2
        while i + 9 <= len(raw):
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            if marker in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", raw[i + 5:i + 9])
                return w, h
            i += 2 + struct.unpack(">H", raw[i + 2:i + 4])[0]
    return 0, 0


def _identity():
    return [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]


def _mul(a, b):
    return [[sum(a[r][k] * b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def _local(n):
    if "matrix" in n:
        m = n["matrix"]  # column-major
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    tx, ty, tz = n.get("translation", [0, 0, 0])
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    sx, sy, sz = n.get("scale", [1, 1, 1])
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    s = (sx, sy, sz)
    return [[r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], tx],
            [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], ty],
            [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], tz],
            [0.0, 0.0, 0.0, 1.0]]


def _world(nodes, parent, i):
    m = _local(nodes[i])
    while i in parent:
        i = parent[i]
        m = _mul(_local(nodes[i]), m)
    return m


def _apply(m, v):
    return [m[r][0] * v[0] + m[r][1] * v[1] + m[r][2] * v[2] + m[r][3] for r in range(3)]
