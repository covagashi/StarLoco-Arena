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
##   art/characters/out/portraits/<coach>/<frame>/  the menus' picture of
##                               each coach, in layers (S54)
##   art/equipment/pieces.json   which card shows which piece (S35c), and
##   art/equipment/out/models/*.glb  every piece it names (a garment,
##   art/equipment/garments.json: out/garments/<coach>/<piece>.glb)
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
		files.merge(arena_files(arena, missing))
	files.merge(figure_files())
	files.merge(portrait_files())
	files.merge(equipment_files())
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


## What one arena's fight reads: its layout, base shape and fight shape,
## every kit.json its layout uses and every model it places (in its loom,
## and the columns under its blocks). source (res://) -> path under art/.
## A piece no kit.json knows goes to `missing`.
static func arena_files(arena: int, missing: Array) -> Dictionary:
	var files := {}
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
	return files


## Every 3D figure (Fighter3D: fighters, summons, coaches) and the
## coaches' masks.
static func figure_files() -> Dictionary:
	var files := {}
	for model in _figures():
		var src: String = Layout.ART_DIR.path_join(Fighter3D.MODEL_DIR % model)
		files[src] = src.trim_prefix(Layout.ART_DIR + "/")
		if model in Fighter3D.COACHES.values():
			for ext: String in ["_mask.png", "_mask.json"]:
				var m: String = src.get_basename() + ext
				files[m] = m.trim_prefix(Layout.ART_DIR + "/")
	return files


## S54: the menus' picture of each coach, every layer of every frame
## (tools/art/coach_portrait.gd; build.py makes them).
static func portrait_files() -> Dictionary:
	var files := {}
	for c: String in Fighter3D.COACHES.values():
		var base: String = Layout.ART_DIR.path_join("characters/out/portraits").path_join(c)
		for fr in DirAccess.get_directories_at(base):
			for f in DirAccess.get_files_at(base.path_join(fr)):
				var src := base.path_join(fr).path_join(f)
				files[src] = src.trim_prefix(Layout.ART_DIR + "/")
		if not DirAccess.dir_exists_absolute(base):
			files[base.path_join("thigh/index.json")] = ""   # missing: fails the pack
	return files


## Which card shows which piece (S35c) and every piece it names: a rigid
## model, or one garment per coach figure (equipment/garments.json).
static func equipment_files() -> Dictionary:
	var files := {}
	var pieces_src: String = Layout.ART_DIR.path_join(Fighter3D.PIECES)
	files[pieces_src] = Fighter3D.PIECES
	var garments_src: String = Layout.ART_DIR.path_join("equipment/garments.json")
	var tables = JSON.parse_string(FileAccess.get_file_as_string(pieces_src))
	var garments = JSON.parse_string(FileAccess.get_file_as_string(garments_src))
	if not garments is Dictionary:
		garments = {}
	if tables is Dictionary:
		for table: Dictionary in [tables.get("fighter", {}), tables.get("coach", {})]:
			for piece: String in table.values():
				var src: String = Layout.ART_DIR.path_join(Fighter3D.EQUIP_DIR % piece)
				if garments.has(piece):   # one per coach figure
					for c: String in Fighter3D.COACHES.values():
						src = Layout.ART_DIR.path_join(Fighter3D.GARMENT_DIR % [c.get_file().get_basename(), piece])
						files[src] = src.trim_prefix(Layout.ART_DIR + "/")
					continue
				files[src] = src.trim_prefix(Layout.ART_DIR + "/")
	return files

## Every figure the game can draw in 3D.
static func _figures() -> Array:
	var out := []
	for pair: Array in Fighter3D.MODELS.values():
		out.append_array(pair)
	for s: Array in Fighter3D.SUMMONS.values():
		out.append(s[0])
	out.append_array(Fighter3D.COACHES.values())
	return out


static func _model(files: Dictionary, kit: String, name: String, loom: String) -> void:
	var src := Layout.model_path(kit, name, loom)
	files[src] = src.trim_prefix(Layout.ART_DIR + "/")


func _remove(dir: String) -> void:
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_remove(dir.path_join(d))
	DirAccess.remove_absolute(dir)
