class_name AssetPaths
extends RefCounted
## AssetPaths — the one place that turns a logical asset name
## ("gamedata/spells.json", "anims/coach_7000/2_AnimStatique/meta.json")
## into a path this build can actually open.
##
## Why it exists: everything under assets/ except ui/ and i18n/ is produced
## by tools/asset-import from a lawfully-owned retail client and is
## git-ignored on purpose (AGENTS.md — no Ankama bytes in the repo). Those
## files are read RAW, with Image.load_from_file / FileAccess /
## FontFile.load_dynamic_font, not through ResourceLoader. In the editor
## res:// is a real directory on disk, so a hardcoded "res://assets/…"
## works; from an exported binary res:// is the .pck and loose files that
## no importer ever claimed were never packed, so every one of those reads
## would come back empty. ProjectSettings.globalize_path() does not rescue
## it either — it maps res:// to the directory holding the executable's
## pack, where the files are equally absent.
##
## The release layout therefore mirrors the server's data-dist/: a plain
## `assets/` folder shipped next to the executable, which an operator can
## also regenerate from their own client. Roots are probed in order and the
## first one that HAS THE FILE wins.
##
## Per-file probing is the load-bearing detail: assets/ui/*.png and
## assets/i18n/*.json are tracked and imported, so "res://assets/" still
## exists inside an exported .pck. A root-level existence check would see
## that and wrongly pin every lookup to res://. Probing each file instead
## lets ui/login_bg.png come out of the pack while gamedata/spells.json
## falls through to the folder beside the binary.
##
## Callers pass logical names. Legacy "res://assets/…" strings still work —
## normalize() strips the prefix — which is what keeps this migration
## reversible and keeps the top-level test scripts (and deprecated_hall/)
## compiling untouched.

const PREFIX := "res://assets/"

## null until first use / after reset_roots(); an explicit empty override
## from set_roots() stays empty instead of silently reverting to defaults.
static var _roots = null
## normalized rel -> resolved path. Directory probes live in the same
## dictionary under a "dir:" key so a file and a folder of the same name
## cannot collide.
static var _cache := {}


## Logical name for an asset: "gamedata/spells.json". A leading
## "res://assets/" or "/" is dropped; anything else (including a "user://"
## or absolute path a test hands us) passes through untouched.
static func normalize(rel: String) -> String:
	var s := rel
	if s.begins_with(PREFIX):
		s = s.substr(PREFIX.length())
	while s.begins_with("/"):
		s = s.substr(1)
	return s


## Probe order. res:// first so a dev run (and the tracked ui/ + i18n/
## subsets in a release pack) keeps working with zero setup; then the
## `assets/` folder beside the executable, which is what a release ships;
## then user://assets/ as the escape hatch for an operator who dropped a
## freshly imported tree into the writable data dir.
static func roots() -> PackedStringArray:
	if _roots == null:
		_roots = PackedStringArray([
			PREFIX,
			OS.get_executable_path().get_base_dir() + "/assets/",
			"user://assets/",
		])
	return _roots


## Test seam — point the resolver at fixture trees. Trailing slashes are
## normalized so roots can be written either way.
static func set_roots(r) -> void:
	var out := PackedStringArray()
	for v in r:
		var s := str(v)
		if s != "" and not s.ends_with("/"):
			s += "/"
		out.append(s)
	_roots = out
	_cache.clear()


static func reset_roots() -> void:
	_roots = null
	_cache.clear()


## First root that actually holds `rel`. When no root has it, the first
## root wins anyway: the caller's own file_exists check still fails, but
## the push_error/"missing …" line it prints names a plausible path
## instead of a bare filename.
static func resolve(rel: String) -> String:
	var key := normalize(rel)
	if _cache.has(key):
		return _cache[key]
	var all := roots()
	var out := ""
	for root in all:
		var cand := root + key
		if FileAccess.file_exists(cand):
			out = cand
			break
	if out == "":
		out = (all[0] + key) if not all.is_empty() else key
	_cache[key] = out
	return out


static func exists(rel: String) -> bool:
	return FileAccess.file_exists(resolve(rel))


## "" when the file is missing — every gamedata table treats an empty read
## as "feature absent" rather than failing the boot.
static func read_text(rel: String) -> String:
	var p := resolve(rel)
	if not FileAccess.file_exists(p):
		return ""
	return FileAccess.get_file_as_string(p)


## Parsed JSON, or `default` when the file is missing OR malformed — the
## asset-import output is regenerated often, so a truncated table must not
## take the client down.
static func read_json(rel: String, default: Variant = null) -> Variant:
	var txt := read_text(rel)
	if txt == "":
		return default
	# JSON.new().parse() instead of the static JSON.parse_string(): the static
	# helper pushes an engine-level "Parse JSON failed" ERROR with no file
	# path, which in a CI log reads like a crash even when the caller handled
	# it cleanly. The instance API is silent and hands back a message and a
	# line number, so a broken generated asset produces ONE warning that
	# names the file — which is what someone debugging it actually needs.
	var json := JSON.new()
	if json.parse(txt) != OK:
		push_warning("asset json unusable: %s (line %d: %s)" % [
			rel, json.get_error_line(), json.get_error_message()])
		return default
	var parsed: Variant = json.data
	if parsed == null:
		return default
	# When a default is given it also declares the expected SHAPE (B-174). A
	# file that is valid JSON but the wrong kind at top level — an array where
	# an object belongs, say, after an importer changes shape — would otherwise
	# flow straight into `var x: Dictionary = read_json(...)` and abort the
	# caller mid-function with "Trying to assign value of type 'Array' to a
	# variable of type 'Dictionary'". Callers that genuinely accept anything
	# pass no default and type the result as Variant.
	if default != null and typeof(parsed) != typeof(default):
		return default
	return parsed


## Raw image decode (NOT ResourceLoader) — null when missing. The anim
## frames, map atlases and native-UI backgrounds all come through here.
static func load_image(rel: String) -> Image:
	var p := resolve(rel)
	# Dev-log hygiene, NOT behaviour. Godot warns "Loaded resource as image
	# file, this will not work on export" for any res:// path that has an
	# .import sibling, and it auto-imports every PNG it finds under res:// —
	# so one fight preview emitted ~60 of these and buried the warnings that
	# actually matter (the anchor ones). Mechanism verified in a throwaway
	# project: the warning fires on res:// + .import, and not on the same
	# file reached by an absolute path.
	#
	# Editor-gated on purpose. globalize_path() maps res:// to the directory
	# holding the executable's pack, where these files are absent, so it must
	# never run in a release build — which never reaches this branch anyway,
	# because there the exe-sibling root wins and is already absolute.
	return load_image_at(p)


## Image loader for a path that is ALREADY resolved. anm_sprite resolves one
## meta.json per action and derives every frame/mask path from its base dir —
## deliberately never re-probing per frame, so a split asset tree can't pair
## one root's meta.json with another root's PNGs. Those paths must therefore
## skip resolve() while still getting the editor detour above, which is the
## only reason this is public.
static func load_image_at(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var p := path
	if p.begins_with("res://") and OS.has_feature("editor"):
		p = ProjectSettings.globalize_path(p)
	return Image.load_from_file(p)


## Directory flavour of resolve(), probed with DirAccess (the _absolute
## variant — the plain one is an instance method): for the anim "set dir"
## prefixes ("anims/coach_7000") that callers extend with
## "/<Action>/f000.png", and for DirAccess.open() scans like the theme's
## lazy image index. Never returns a trailing slash.
static func dir(rel: String) -> String:
	var key := normalize(rel)
	while key.ends_with("/"):
		key = key.substr(0, key.length() - 1)
	var ck := "dir:" + key
	if _cache.has(ck):
		return _cache[ck]
	var all := roots()
	var out := ""
	for root in all:
		var cand := root + key
		if DirAccess.dir_exists_absolute(cand):
			out = cand
			break
	if out == "":
		out = (all[0] + key) if not all.is_empty() else key
	_cache[ck] = out
	return out
