extends RefCounted
## Guards the degraded-read contract B-174 established: a generated JSON file
## that is truncated, or valid-but-the-wrong-kind at top level, must degrade
## to the caller's declared default instead of aborting the caller.
##
## Not hypothetical. assets/gamedata/*.json, the per-action meta.json files
## and the map atlases are all tools/asset-import output, so an interrupted
## importer run leaves a half-written file on disk. GDScript turns that into
## a hard stop: `var d: Dictionary = <Nil>` raises "Trying to assign value of
## type 'Nil' to a variable of type 'Dictionary'" and ABORTS the rest of the
## function, leaving the caller half-initialised with one line in the log.
## The symptom months later is "the animations don't show".
##
## Touches no real asset — fixtures are written under user://.

const BASE := "user://test_json_shape"
const ROOT := "user://test_json_shape/root"

## Set at the END of _typed_assignment_canary(). An abort inside that function
## skips the assignment and leaves this false, which is what makes the failure
## visible instead of silently shortening the run.
var _typed_ok := false


func run(t) -> void:
	t.suite("json_shape")
	if not _build(t):
		AssetPaths.reset_roots()
		return
	AssetPaths.set_roots([ROOT])

	# With a default, the default also declares the expected shape.
	var truncated: Variant = AssetPaths.read_json("truncated.json", {})
	t.ok(truncated is Dictionary and truncated.is_empty(),
		"truncated JSON degrades to the {} default")
	var wrong_kind: Variant = AssetPaths.read_json("array.json", {})
	t.ok(wrong_kind is Dictionary and wrong_kind.is_empty(),
		"top-level array degrades to the {} default")
	var missing: Variant = AssetPaths.read_json("nope.json", {})
	t.ok(missing is Dictionary and missing.is_empty(),
		"missing file degrades to the {} default")

	# A good file must still come through untouched.
	var good: Variant = AssetPaths.read_json("good.json", {})
	t.ok(good is Dictionary and good.get("fps") == 25,
		"well-formed object is returned as parsed")

	# Without a default the caller has opted into Variant handling, so the
	# shape check must NOT fire — an array-valued file is legitimate there.
	t.eq(AssetPaths.read_json("truncated.json"), null,
		"no default + truncated returns null")
	var raw: Variant = AssetPaths.read_json("array.json")
	t.ok(raw is Array and raw.size() == 3,
		"no default + top-level array passes through")

	# The shape the bug actually took in the wild.
	_typed_assignment_canary()
	t.ok(_typed_ok,
		"typed Dictionary assignment survives a top-level array (did not abort)")

	AssetPaths.reset_roots()
	_cleanup()


## Mirrors map_gfx.gd / kanodo.gd: the result goes straight into a statically
## typed Dictionary. Keep the flag assignment LAST so an abort is detectable.
func _typed_assignment_canary() -> void:
	var d: Dictionary = AssetPaths.read_json("array.json", {})
	_typed_ok = d.is_empty()


func _build(t) -> bool:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var ok := _write(ROOT + "/truncated.json", '{"fps": 25, "frames": [')
	ok = _write(ROOT + "/array.json", '[1, 2, 3]') and ok
	ok = _write(ROOT + "/good.json", '{"fps": 25}') and ok
	t.ok(ok, "fixtures written under user://")
	return ok


func _write(path: String, body: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(body)
	f.close()
	return true


func _cleanup() -> void:
	for name in ["truncated.json", "array.json", "good.json"]:
		DirAccess.remove_absolute(ROOT + "/" + name)
	DirAccess.remove_absolute(ROOT)
	DirAccess.remove_absolute(BASE)
