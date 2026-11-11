#!/usr/bin/env python3
"""S34: tests for glb.py and check.py on made-up GLBs (no built art needed).

    python3 -I tools/art/test_check.py
"""
import json
import os
import shutil
import struct
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build  # noqa: E402
import check  # noqa: E402
from glb import Glb, image_size  # noqa: E402

PNG_2048x1024 = bytes.fromhex("89504e470d0a1a0a0000000d4948445200000800000004000806000000")


def write_glb(path, height=1.45, scale=1.0, tris=1, anims=check.ANIMS, image=b"", y0=0.0):
    """One mesh of `tris` triangles from y0 to y0 + height (before the node's scale)."""
    pos = struct.pack("<9f", -0.2, y0, 0, 0.2, y0, 0, 0, y0 + height, 0)
    idx = struct.pack("<%dH" % (3 * tris), *([0, 1, 2] * tris))
    pad = (4 - len(idx) % 4) % 4
    binary = pos + idx + b"\0" * pad + image
    j = {
        "asset": {"version": "2.0"},
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "scale": [scale] * 3}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
        "buffers": [{"byteLength": len(binary)}],
        "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": 36},
                        {"buffer": 0, "byteOffset": 36, "byteLength": len(idx)}],
        "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3",
                       "min": [-0.2, y0, 0], "max": [0.2, y0 + height, 0]},
                      {"bufferView": 1, "componentType": 5123, "count": 3 * tris, "type": "SCALAR"}],
        "animations": [{"name": a, "channels": [], "samplers": []} for a in anims],
    }
    if image:
        j["bufferViews"].append({"buffer": 0, "byteOffset": 36 + len(idx) + pad, "byteLength": len(image)})
        j["images"] = [{"bufferView": 2, "mimeType": "image/png"}]
    text = json.dumps(j).encode()
    text += b" " * ((4 - len(text) % 4) % 4)
    body = struct.pack("<I4s", len(text), b"JSON") + text + struct.pack("<I4s", len(binary), b"BIN\0") + binary
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + len(body)) + body)


class GlbTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_counts_and_bounds(self):
        p = os.path.join(self.dir, "a.glb")
        write_glb(p, height=1.0, scale=2.0, tris=4, image=PNG_2048x1024)
        g = Glb(p)
        self.assertEqual(g.tris, 4)
        self.assertEqual(g.anims, check.ANIMS)
        lo, hi = g.bounds()
        self.assertAlmostEqual(hi[1] - lo[1], 2.0)   # the node's scale applies
        self.assertEqual((g.images[0]["w"], g.images[0]["h"]), (2048, 1024))

    def test_image_size(self):
        self.assertEqual(image_size(PNG_2048x1024), (2048, 1024))
        jpeg = b"\xff\xd8\xff\xe0\x00\x04ab\xff\xc0\x00\x11\x08\x02\x00\x04\x00"
        self.assertEqual(image_size(jpeg), (1024, 512))
        self.assertEqual(image_size(b"nope"), (0, 0))


class FigureCheckTest(unittest.TestCase):
    """check_figures on a fake art/characters: each broken figure fails."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.out = os.path.join(self.dir, "characters", "out")
        os.makedirs(self.out)
        self.saved = check.ART
        check.ART = self.dir
        check.stale_figure = lambda name, fig: False

    def tearDown(self):
        check.ART = self.saved
        shutil.rmtree(self.dir)

    def run_check(self, **glb):
        figs = {"feca_f": {"script": "meshy_fighter.py", "src": "01_feca_f", "opts": {}}}
        with open(os.path.join(self.dir, "characters", "figures.json"), "w") as f:
            json.dump({"figures": figs}, f)
        write_glb(os.path.join(self.out, "feca_f.glb"), **glb)
        r = check.Report(quiet=True)
        check.check_figures(r)
        return [m for m in r.fails if m.startswith("figure feca_f")]

    def test_good_figure_passes(self):
        self.assertEqual(self.run_check(), [])

    def test_wrong_height(self):
        self.assertTrue(any("high" in m for m in self.run_check(height=1.2)))

    def test_floating_feet(self):
        self.assertTrue(any("feet" in m for m in self.run_check(y0=0.1)))

    def test_over_budget(self):
        self.assertTrue(any("triangles" in m for m in self.run_check(tris=5001)))

    def test_texture_too_big(self):
        self.assertTrue(any("texture" in m for m in self.run_check(image=PNG_2048x1024)))

    def test_missing_animation(self):
        self.assertTrue(any("die" in m for m in self.run_check(anims=[a for a in check.ANIMS if a != "die"])))

    def test_unrecipe_figure_drawn_by_the_game(self):
        # fighter3d.gd draws 35 figures; this fake figures.json has one
        r = check.Report(quiet=True)
        self.run_check()
        check.check_figures(r)
        self.assertTrue(any("has no recipe" in m for m in r.fails))


class StampTest(unittest.TestCase):
    def test_includes_follow_include_calls(self):
        d = tempfile.mkdtemp()
        try:
            with open(os.path.join(d, "a.kx.js"), "w") as f:
                f.write('include("b.kx.js")\n')
            with open(os.path.join(d, "b.kx.js"), "w") as f:
                f.write('include("../c.kx.js")\n')
            got = build.includes(os.path.join(d, "a.kx.js"))
            self.assertEqual([os.path.basename(p) for p in got], ["a.kx.js", "b.kx.js"])   # ../c is absent
            h1 = build.digest(*got)
            with open(os.path.join(d, "b.kx.js"), "a") as f:
                f.write("// edit\n")
            self.assertNotEqual(h1, build.digest(*got), "an edit in an included file changes the hash")
        finally:
            shutil.rmtree(d)


if __name__ == "__main__":
    unittest.main()
