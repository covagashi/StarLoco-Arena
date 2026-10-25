extends RefCounted

## M7: how our kiln GLBs are dressed for the game's look (shared by the
## tools/art renders).

## Snow: smooth normals; ice: rim light; everything: no specular glints.
static func dress(mi: MeshInstance3D) -> void:
	var src: Mesh = mi.mesh
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s) as BaseMaterial3D
		var mname := mat.resource_name if mat else ""
		if mname.begins_with("snow"):
			arrays[Mesh.ARRAY_NORMAL] = smooth(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL],
				arrays[Mesh.ARRAY_INDEX])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mat:
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if mname.begins_with("ice"):
				mat.rim_enabled = true
				mat.rim = 0.6
				mat.rim_tint = 0.2
			mesh.surface_set_material(s, mat)
	mi.mesh = mesh


## Average the flat normals of every vertex sharing a position.
static func smooth(verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var acc := {}
	var tri_n := normals.duplicate()
	if not idx.is_empty():
		# area-weighted face normals
		for t in range(0, idx.size(), 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var fn := (b - a).cross(c - a)
			if fn.dot(normals[idx[t]]) < 0.0:
				fn = -fn
			for k in 3:
				var key := Vector3i((verts[idx[t + k]] * 2000.0).round())
				acc[key] = acc.get(key, Vector3.ZERO) + fn
	else:
		for i in verts.size():
			var key := Vector3i((verts[i] * 2000.0).round())
			acc[key] = acc.get(key, Vector3.ZERO) + normals[i]
	for i in verts.size():
		var key := Vector3i((verts[i] * 2000.0).round())
		tri_n[i] = (acc[key] as Vector3).normalized()
	return tri_n
