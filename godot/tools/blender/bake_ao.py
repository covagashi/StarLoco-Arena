"""Bake ambient occlusion into a kiln GLB's vertex colours (Blender headless).

The game draws with Godot's Compatibility renderer, which has no SSAO, so
kiln's flat pieces get no contact shading. This bakes AO with Cycles into a
vertex colour layer that multiplies the albedo; Godot's glTF importer uses it
as-is. Review (2026-11-03): clear gain on snow caps, rubble and scaffolds;
too dark on grass blocks and autumn foliage at 0.5. Not in the pipeline yet:
the owner picks which pieces get it.

    blender -b -P godot/tools/blender/bake_ao.py -- <in.glb> <out.glb> [strength=0.5]

strength 0..1: 0 leaves the piece as it was, 1 is the full baked AO.
"""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
strength = float(args[2]) if len(args) > 2 else 0.5

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 64
# a ground plane gives the base contact occlusion; removed before export
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
ground = bpy.context.active_object
meshes = [o for o in sc.objects if o.type == "MESH" and o is not ground]


def key(me, loop):
    return tuple(round(x * 2000) for x in me.vertices[loop.vertex_index].co)


for o in meshes:
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    me = o.data
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    ca = me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
    me.color_attributes.active_color = ca
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    # kiln splits vertices per face: average by position or every face gets
    # its own tone and smooth snow looks faceted; then soften toward white
    acc = {}
    for li, loop in enumerate(me.loops):
        k = key(me, loop)
        s, n = acc.get(k, (0.0, 0))
        acc[k] = (s + ca.data[li].color[0], n + 1)
    for li, loop in enumerate(me.loops):
        s, n = acc[key(me, loop)]
        v = 1 - (1 - s / n) * strength
        ca.data[li].color = (v, v, v, 1)
    # multiply it into the base colour so Blender's own renders match
    for slot in o.material_slots:
        m = slot.material
        if not m or not m.use_nodes:
            continue
        nt = m.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if not bsdf:
            continue
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "AO"
        inp = bsdf.inputs["Base Color"]
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs["Factor"].default_value = 1
        if inp.links:
            nt.links.new(inp.links[0].from_socket, mul.inputs[6])
        else:
            mul.inputs[6].default_value = inp.default_value
        nt.links.new(attr.outputs["Color"], mul.inputs[7])
        nt.links.new(mul.outputs[2], inp)

bpy.data.objects.remove(ground)
os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_vertex_color="ACTIVE",
                          export_all_vertex_colors=False)
print("BAKED", dst)
