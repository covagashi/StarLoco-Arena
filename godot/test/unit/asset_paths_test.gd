extends RefCounted
## Guards src/util/asset_paths.gd — the resolver every raw asset read goes
## through (B-173).
##
## The hazard it exists for: everything under assets/ except ui/ and i18n/ is
## tools/asset-import output, git-ignored, and read RAW (Image.load_from_file,
## FileAccess, FontFile.load_dynamic_font) rather than as a Godot resource. A
## hardcoded "res://assets/…" works in the editor and silently reads nothing
## from an exported .pck, so release builds resolve against an `assets/`
## folder shipped beside the executable instead — the same shape as the
## server's data-dist/.
##
## The subtle part, and the reason for most of what follows: probing is PER
## FILE, not per root. assets/ui/*.png and assets/i18n/*.json ARE tracked and
## imported, so "res://assets/" still exists inside an exported pack; a
## root-level existence check would see it and wrongly pin every lookup to
## res://, re-breaking gamedata/anims/gui. "root precedence" and
## "fall-through" below are that invariant in test form.
##
## This suite must stay runnable on a machine that has never run the asset
## importer, so it touches no real asset: it builds two throwaway root trees
## under user:// with FileAccess + Image.save_png, points set_roots() at
## them, and reset_roots() before returning.

const BASE := "user://test_asset_paths"
const ROOT_A := "user://test_asset_paths/root_a"
const ROOT_B := "user://test_asset_paths/root_b"


func run(t) -> void:
	t.suite("asset_paths")
	_check_normalize(t)
	_check_defaults(t)
	if not _build_fixtures(t):
		AssetPaths.reset_roots()
		return
	# Trailing slashes deliberately omitted — set_roots() must add them.
	AssetPaths.set_roots([ROOT_A, ROOT_B])
	_check_roots_override(t)
	_check_precedence(t)
	_check_fallthrough(t)
	_check_missing(t)
	_check_text_and_json(t)
	_check_images(t)
	_check_dirs(t)
	_check_cache_invalidation(t)
	AssetPaths.reset_roots()
	_check_reset(t)
	_cleanup()


## normalize() is what keeps the migration reversible: the top-level smoke
## scripts, deprecated_hall/ and the gui model's actorDescriptorLibrary values
## still hand out "res://assets/anims/…" strings and must keep working.
func _check_normalize(t) -> void:
	t.eq(AssetPaths.PREFIX, "res://assets/", "PREFIX is the legacy asset root")
	t.eq(AssetPaths.normalize("res://assets/gamedata/spells.json"),
		"gamedata/spells.json", "normalize() strips the legacy res:// prefix")
	t.eq(AssetPaths.normalize("gamedata/spells.json"),
		"gamedata/spells.json", "normalize() leaves a logical name alone")
	t.eq(AssetPaths.normalize("/gamedata/spells.json"),
		"gamedata/spells.json", "normalize() strips a leading slash")
	t.eq(AssetPaths.normalize("res://assets//gui/xml/theme/default.xml"),
		"gui/xml/theme/default.xml",
		"normalize() strips the prefix and the slash it left behind")
	t.eq(AssetPaths.normalize(""), "", "normalize() passes an empty name through")
	# Anything that is not an assets/ path is NOT ours to rewrite: scripts
	# live in the pack and are preloaded, and tests hand us user:// fixtures.
	t.eq(AssetPaths.normalize("res://src/main.gd"), "res://src/main.gd",
		"normalize() leaves a non-asset res:// path unchanged")
	t.eq(AssetPaths.normalize("user://assets/gamedata/x.json"),
		"user://assets/gamedata/x.json",
		"normalize() leaves a user:// path unchanged")


## The shipped probe order, before any test override touches it.
func _check_defaults(t) -> void:
	AssetPaths.reset_roots()
	var roots := AssetPaths.roots()
	t.eq(roots.size(), 3, "three default roots")
	t.eq(roots[0], AssetPaths.PREFIX, "res://assets/ is probed first")
	t.eq(roots[1], OS.get_executable_path().get_base_dir() + "/assets/",
		"the executable's sibling assets/ is probed second")
	t.eq(roots[2], "user://assets/", "user://assets/ is the last resort")


func _check_roots_override(t) -> void:
	var roots := AssetPaths.roots()
	t.eq(roots.size(), 2, "set_roots() replaces the default list")
	t.eq(roots[0], ROOT_A + "/", "set_roots() appends the missing slash")
	t.eq(roots[1], ROOT_B + "/", "set_roots() keeps the given order")


## Both roots hold "both.txt": the first one wins.
func _check_precedence(t) -> void:
	t.eq(AssetPaths.resolve("both.txt"), ROOT_A + "/both.txt",
		"resolve() takes the first root that has the file")
	t.eq(AssetPaths.read_text("both.txt"), "from A",
		"read_text() reads the winning root's copy")
	t.ok(AssetPaths.exists("both.txt"), "exists() true for a present file")
	# Legacy callers must land on the same place.
	t.eq(AssetPaths.resolve("res://assets/both.txt"),
		AssetPaths.resolve("both.txt"),
		"a legacy res://assets/ path resolves like its logical name")


## The invariant that per-file probing buys: root A exists and holds files,
## yet a file only root B has still resolves to B. This is ui/login_bg.png
## (packed) vs gamedata/spells.json (beside the executable) in miniature.
func _check_fallthrough(t) -> void:
	t.eq(AssetPaths.resolve("b_only.txt"), ROOT_B + "/b_only.txt",
		"resolve() falls through to the second root per FILE, not per root")
	t.eq(AssetPaths.read_text("b_only.txt"), "only in B",
		"read_text() reads the root that actually has the file")
	t.ok(AssetPaths.exists("b_only.txt"), "exists() true for a fall-through file")


## A miss still names a path, so "cannot open <x>" stays diagnosable.
func _check_missing(t) -> void:
	t.eq(AssetPaths.resolve("gamedata/nope.json"),
		ROOT_A + "/gamedata/nope.json",
		"a missing file resolves under the FIRST root")
	t.ok(not AssetPaths.exists("gamedata/nope.json"),
		"exists() false for a missing file")
	t.eq(AssetPaths.read_text("gamedata/nope.json"), "",
		"read_text() is empty for a missing file")
	t.eq(AssetPaths.read_json("gamedata/nope.json"), null,
		"read_json() defaults to null for a missing file")
	t.eq(AssetPaths.read_json("gamedata/nope.json", {}), {},
		"read_json() honors the caller's default")


func _check_text_and_json(t) -> void:
	t.eq(AssetPaths.read_json("a_table.json"), {"name": "alpha"},
		"read_json() parses a table")
	t.eq(AssetPaths.read_json("b_table.json"), {"name": "bravo"},
		"read_json() parses a table from the fall-through root")
	# Truncated import output must not take the client down — every gamedata
	# table treats a null parse as "feature absent". The two
	# "Parse JSON failed" ERROR lines the lane prints are the engine
	# reporting THIS fixture: JSON.parse_string logs before returning null,
	# which is the behaviour the client wants (a half-written table should
	# say so in the log, not vanish quietly). Nothing to chase.
	t.eq(AssetPaths.read_json("bad.json"), null,
		"read_json() returns null for malformed JSON")
	t.eq(AssetPaths.read_json("bad.json", {}), {},
		"read_json() returns the default for malformed JSON")
	t.eq(AssetPaths.read_text("bad.json"), "{\"truncated\": ",
		"read_text() still hands back the raw malformed bytes")


func _check_images(t) -> void:
	var a := AssetPaths.load_image("pic.png")
	t.ok(a != null, "load_image() decodes a present image")
	if a != null:
		# A's pic.png is 4x2, B's is 8x8 — the width proves which root won.
		t.eq(a.get_width(), 4, "load_image() honors root precedence")
	var b := AssetPaths.load_image("b_pic.png")
	t.ok(b != null, "load_image() decodes a fall-through image")
	if b != null:
		t.eq(b.get_width(), 8, "load_image() read the second root's image")
	t.eq(AssetPaths.load_image("missing.png"), null,
		"load_image() is null for a missing image")


## dir() is the DirAccess flavour — the anim set-dir prefixes and the theme's
## lazy image-index scan both need a folder, not a file.
func _check_dirs(t) -> void:
	t.eq(AssetPaths.dir("shared_dir"), ROOT_A + "/shared_dir",
		"dir() takes the first root that has the folder")
	t.eq(AssetPaths.dir("b_dir"), ROOT_B + "/b_dir",
		"dir() falls through to the second root")
	t.eq(AssetPaths.dir("b_dir/"), AssetPaths.dir("b_dir"),
		"dir() ignores a trailing slash on the request")
	t.ok(not AssetPaths.dir("b_dir").ends_with("/"),
		"dir() never returns a trailing slash")
	t.eq(AssetPaths.dir("no_such_dir"), ROOT_A + "/no_such_dir",
		"a missing folder resolves under the FIRST root")
	t.eq(AssetPaths.dir("anims/coach_7000"), ROOT_B + "/anims/coach_7000",
		"dir() resolves a nested anim set dir")
	# "ambi" is a FILE in A and a FOLDER in B: the file and directory caches
	# must not answer each other's questions.
	t.eq(AssetPaths.resolve("ambi"), ROOT_A + "/ambi",
		"resolve() picks the root where `ambi` is a file")
	t.eq(AssetPaths.dir("ambi"), ROOT_B + "/ambi",
		"dir() picks the root where `ambi` is a folder")


## set_roots() must drop the memo, or a second suite (or a relocated asset
## tree) keeps seeing the first run's answers.
func _check_cache_invalidation(t) -> void:
	t.eq(AssetPaths.resolve("both.txt"), ROOT_A + "/both.txt",
		"both.txt resolves to A before the override")
	AssetPaths.set_roots([ROOT_B])
	t.eq(AssetPaths.resolve("both.txt"), ROOT_B + "/both.txt",
		"set_roots() clears the resolution cache")
	t.eq(AssetPaths.read_text("both.txt"), "from B",
		"the new root's copy is the one read")
	t.eq(AssetPaths.dir("shared_dir"), ROOT_B + "/shared_dir",
		"set_roots() clears the directory cache too")
	AssetPaths.set_roots([ROOT_A, ROOT_B])


func _check_reset(t) -> void:
	t.eq(AssetPaths.roots()[0], AssetPaths.PREFIX,
		"reset_roots() restores the shipped probe order")
	t.eq(AssetPaths.resolve("both.txt"), "res://assets/both.txt",
		"reset_roots() clears the cache — the fixture answer is gone")


## Two root trees under user://. Returns false (with a recorded failure) if
## the sandbox is not writable, so the rest of the suite can bail instead of
## reporting a cascade of unrelated misses.
func _build_fixtures(t) -> bool:
	_cleanup()
	for d in [ROOT_A, ROOT_B, ROOT_A + "/shared_dir", ROOT_B + "/shared_dir",
			ROOT_B + "/b_dir", ROOT_B + "/anims/coach_7000",
			ROOT_B + "/ambi"]:
		DirAccess.make_dir_recursive_absolute(d)
	var ok := _write(ROOT_A + "/both.txt", "from A")
	ok = _write(ROOT_B + "/both.txt", "from B") and ok
	ok = _write(ROOT_B + "/b_only.txt", "only in B") and ok
	ok = _write(ROOT_A + "/a_table.json", '{"name": "alpha"}') and ok
	ok = _write(ROOT_B + "/b_table.json", '{"name": "bravo"}') and ok
	ok = _write(ROOT_A + "/bad.json", '{"truncated": ') and ok
	ok = _write(ROOT_A + "/ambi", "a file in A, a folder in B") and ok
	ok = _png(ROOT_A + "/pic.png", 4, 2) and ok
	ok = _png(ROOT_B + "/pic.png", 8, 8) and ok
	ok = _png(ROOT_B + "/b_pic.png", 8, 8) and ok
	t.ok(ok, "user:// fixture roots were created")
	return ok


func _write(path: String, text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


func _png(path: String, w: int, h: int) -> bool:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	return img.save_png(path) == OK


func _cleanup() -> void:
	_rm_tree(BASE)


func _rm_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			_rm_tree(path + "/" + f)
		else:
			d.remove(f)
		f = d.get_next()
	d.list_dir_end()
	DirAccess.remove_absolute(path)
