# S47: pre-reduce a Meshy HD original before meshy_fighter.py (the Python
# clean-up is unworkable at 600k+ triangles; the modifier is fast).
#   blender -b -P tools/blender/characters/predecimate.py -- in.glb out.glb 80000
import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
src, dst, tris = a[0], a[1], int(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    n = sum(len(p.vertices) - 2 for p in o.data.polygons)
    m = o.modifiers.new("dec", "DECIMATE")
    m.ratio = min(1.0, tris / n)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier="dec")
    print("[predecimate]", o.name, n, "->", sum(len(p.vertices) - 2 for p in o.data.polygons))
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
