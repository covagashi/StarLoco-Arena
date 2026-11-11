"""S35b-marketing (tanda 3): the "before" of the weights post. Builds a
fighter exactly as meshy_fighter.py does but skins it with Blender's
automatic heat weights alone (none of the arm cut, the bone reach or the
smoothing), so the posts can show what those fixes are for.

    blender -b -P tools/blender/characters/promo_naive.py -- <meshy.glb> <out.glb> [meshy_fighter options]
"""
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import meshy_fighter as mf  # noqa: E402  (parses the same argv)


def heat_only(ob, rig, J):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


mf.skin = heat_only
mf.main()
