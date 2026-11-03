"""Triangle / material / texture audit of kiln GLBs (Blender headless).

    blender -b -P godot/tools/blender/audit.py -- <list.txt> <art dir> <out.tsv>

list.txt: one "<path relative to art dir> <placements>" per line. Writes
path, placements, triangles, materials, images, image sizes.
"""
import os
import sys

import bpy

lst, root, out = sys.argv[sys.argv.index("--") + 1:][:3]
rows = []
for line in open(lst):
    p, cnt = line.split()
    path = os.path.join(root, p)
    if not os.path.exists(path):
        rows.append((p, cnt, -1, 0, 0, "MISSING"))
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    tris, mats = 0, set()
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        mats |= {s.material.name for s in o.material_slots if s.material}
    imgs = sorted({f"{i.size[0]}x{i.size[1]}" for i in bpy.data.images if i.size[0]})
    rows.append((p, cnt, tris, len(mats), len(bpy.data.images), ",".join(imgs)))
with open(out, "w") as f:
    for r in rows:
        f.write("\t".join(map(str, r)) + "\n")
