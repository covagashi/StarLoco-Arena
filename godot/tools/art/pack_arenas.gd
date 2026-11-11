extends SceneTree

## Packs the prototype's arenas (1..RELEASE) for a release: copies what the
## fight reads into <out>/art/, the loose folder an exported game reads its
## arenas from (arena_layout.gd root()), beside the executable like assets/.
##   godot --headless --path godot -s tools/art/pack_arenas.gd -- <dist dir>
## e.g. -- ../dist/linux. Copies:
##   art/layouts/arena-NN.json   each arena's layout
##   art/shapes/arena-NN.json    each arena's base shape
##   art/<kit>/kit.json          every kit a layout uses
##   art/<kit>/out/models/*.glb  every model it places, in its loom, and the
##                               columns under its blocks (textures inside)
##   art/fight/<world>.json      the fight shapes (server/.../gamedata/arenas)
##   art/characters/out/*.glb    every 3D figure (Fighter3D: fighters,
##                               summons, coaches) and the coaches' masks
## Build the art first (python3 tools/art/build.py): a missing file fails
## the pack.

const Layout := preload("res://src/maps/arena_layout.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <dist dir>  (the folder that holds the executable)")
		quit(2)
		return
	var dest := args[0].trim_suffix("/").path_join("art")
	if not dest.is_absolute_path():
		dest = ProjectSettings.globalize_path("res://").path_join(dest).simplify_path()
	var files := {}   # source (res://) -> path under art/
	var missing := []
	for arena in range(1, Layout.RELEASE + 1):
		var world := Layout.world_of(arena)
		files[Layout.layout_path(arena)] = "layouts/arena-%02d.json" % arena
		files[Layout.shape_path(arena)] = "shapes/arena-%02d.json" % arena
		files[Layout.fight_path(world)] = "fight/%d.json" % world
		var layout := Layout.load_layout(arena)
		for items: Array in layout.cells.values():
			for it: Dictionary in items:
				var pc := Layout.piece(it.kit, it.piece)
				if pc.is_empty():
					missing.append("arena %d: %s/%s is in no kit.json" % [arena, it.kit, it.piece])
					continue
				files["%s/%s/kit.json" % [Layout.ART_DIR, it.kit]] = "%s/kit.json" % it.kit
				_model(files, it.kit, it.piece, it.loom)
				if pc.get("kind", "") == "tile" and pc.get("col", "") != "":
					_model(files, it.kit, pc.col, it.loom)
	for model in _figures():
		var src: String = Layout.ART_DIR.path_join(Fighter3D.MODEL_DIR % model)
		files[src] = src.trim_prefix(Layout.ART_DIR + "/")
		if model in Fighter3D.COACHES.values():
			for ext: String in ["_mask.png", "_mask.json"]:
				var m: String = src.get_basename() + ext
				files[m] = m.trim_prefix(Layout.ART_DIR + "/")
	var bytes := 0
	for src: String in files:
		if not FileAccess.file_exists(src):
			missing.append(src)
	if not missing.is_empty():
		for m in missing:
			printerr("[pack] missing: ", m)
		quit(1)
		return
	if DirAccess.dir_exists_absolute(dest):
		_remove(dest)   # a stale arena would otherwise ship
	for src: String in files:
		var to := dest.path_join(files[src])
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(src), to)
		if err != OK:
			printerr("[pack] copy failed: %s (%s)" % [src, error_string(err)])
			quit(1)
			return
		bytes += FileAccess.get_file_as_bytes(to).size()
	print("[pack] %d files, %.1f MB -> %s" % [files.size(), bytes / 1048576.0, dest])
	quit(0)


## Every figure the game can draw in 3D.
func _figures() -> Array:
	var out := []
	for pair: Array in Fighter3D.MODELS.values():
		out.append_array(pair)
	for s: Array in Fighter3D.SUMMONS.values():
		out.append(s[0])
	out.append_array(Fighter3D.COACHES.values())
	return out


func _model(files: Dictionary, kit: String, name: String, loom: String) -> void:
	var src := Layout.model_path(kit, name, loom)
	files[src] = src.trim_prefix(Layout.ART_DIR + "/")


func _remove(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(d))
	DirAccess.remove_absolute(dir)
