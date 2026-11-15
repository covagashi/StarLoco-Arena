extends SceneTree

## Packs what the web demo (S44) reads raw into zip bundles beside the
## export, the browser's counterpart of the loose assets/ and art/ folders
## a desktop release ships (asset_paths.gd, arena_layout.gd root()):
##   godot --headless --path godot --export-release Web ../dist/web/index.html
##   godot --headless --path godot -s tools/web/pack_web.gd -- ../dist/web
## Writes <dist>/bundles/:
##   boot-K.<hash>.zip      assets/ (ui, i18n, audio, content), every 3D
##                          figure and every equipment piece: the first load
##   arena-NN-K.<hash>.zip  one arena's layout, shapes, kits and models,
##                          downloaded when a fight on it starts
##   manifest.json          group -> {"bytes", "parts": [{"url", "bytes"}]};
##                          the hash in each name lets the server cache the
##                          zips for good
## A group is cut into parts of about PART bytes: the browser holds a whole
## part in Godot's memory while it unpacks it, and that memory never shrinks
## (a 40 MB boot in one piece left the tab 100 MB bigger for good).
## src/util/web_assets.gd downloads a group and unzips it into memory.
## Build the art first (python3 tools/art/build.py): a missing file fails.

const Layout := preload("res://src/maps/arena_layout.gd")
const Pack := preload("res://tools/art/pack_arenas.gd")
const PART := 4 * 1024 * 1024


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -- <dist dir>  (the folder that holds index.html)")
		quit(2)
		return
	var dest := args[0].trim_suffix("/").path_join("bundles")
	if not dest.is_absolute_path():
		dest = ProjectSettings.globalize_path("res://").path_join(dest).simplify_path()
	var missing := []
	var groups := {}   # name -> {source (res://) -> path inside the zip}
	var boot := {}
	_assets("res://assets", "assets", boot)
	for files: Dictionary in [Pack.figure_files(), Pack.equipment_files()]:
		for src: String in files:
			boot[src] = "art/" + files[src]
	groups["boot"] = boot
	for arena in range(1, Layout.RELEASE + 1):
		var files := Pack.arena_files(arena, missing)
		var g := {}
		for src: String in files:
			g[src] = "art/" + files[src]
		groups["arena-%02d" % arena] = g
	for g: Dictionary in groups.values():
		for src: String in g:
			if not FileAccess.file_exists(src):
				missing.append(src)
	if not missing.is_empty():
		for m in missing:
			printerr("[web] missing: ", m)
		quit(1)
		return
	if DirAccess.dir_exists_absolute(dest):
		Pack.new()._remove(dest)   # stale bundles would otherwise ship
	DirAccess.make_dir_recursive_absolute(dest)
	var manifest := {}
	for name: String in groups:
		var keys: Array = groups[name].keys()
		keys.sort()   # same input, same bytes, same hash
		var parts := []
		var cut := [[]]
		var size := 0
		for src: String in keys:
			var n := FileAccess.get_file_as_bytes(src).size()
			if size > 0 and size + n > PART:
				cut.append([])
				size = 0
			cut[-1].append(src)
			size += n
		var total := 0
		for i in cut.size():
			var part := _zip(dest, "%s-%d" % [name, i], groups[name], cut[i])
			if part.is_empty():
				quit(1)
				return
			parts.append(part)
			total += int(part.bytes)
		manifest[name] = {"bytes": total, "parts": parts}
		print("[web] %s: %d files, %d parts, %.1f MB" % [name, keys.size(), parts.size(), total / 1048576.0])
	var f := FileAccess.open(dest.path_join("manifest.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t", true))
	f.close()
	quit(0)


## Writes one part: `files` (sources) into <dest>/<name>.<hash>.zip, at
## their paths in `paths`. {"url", "bytes"}, or {} when it can't.
func _zip(dest: String, name: String, paths: Dictionary, files: Array) -> Dictionary:
	var tmp := dest.path_join(name + ".zip")
	var zip := ZIPPacker.new()
	if zip.open(tmp) != OK:
		printerr("[web] cannot write ", tmp)
		return {}
	for src: String in files:
		zip.start_file(paths[src])
		zip.write_file(FileAccess.get_file_as_bytes(src))
		zip.close_file()
	zip.close()
	var bytes := FileAccess.get_file_as_bytes(tmp)
	var url := "%s.%s.zip" % [name, _hash(bytes)]
	DirAccess.rename_absolute(tmp, dest.path_join(url))
	return {"url": url, "bytes": bytes.size()}


## Every file under a res:// folder except Godot's own import sidecars.
func _assets(dir: String, inside: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		out[dir.path_join(f)] = inside.path_join(f)
	for d in DirAccess.get_directories_at(dir):
		_assets(dir.path_join(d), inside.path_join(d), out)


func _hash(bytes: PackedByteArray) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode().substr(0, 10)
