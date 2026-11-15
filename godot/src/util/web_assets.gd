class_name WebAssets
extends RefCounted
## WebAssets — the web demo's (S44) stand-in for the loose assets/ and art/
## folders a desktop release ships beside the executable. A browser has no
## disk there, so tools/web/pack_web.gd zips them into bundles beside
## index.html, and this downloads a bundle when the game first needs it and
## unzips it into ROOT, a folder of the browser's in-memory file system.
## AssetPaths and ArenaLayout.root() read from ROOT on the web, so every
## raw read in the game works unchanged.
##
## The bundles: "boot" (assets/, the coaches and their equipment) before
## the first screen (web_boot.gd); "figures" (LATER: fighters and summons)
## in the background from then on, and awaited by the first fight; "arena-NN" when a fight on that
## arena starts (fight_view.gd). Only one arena stays unpacked at a time:
## ROOT lives in memory, and a 2 GB device has no room for all six.
## One download at a time: ensure() calls queue behind each other.

## In memory, not user:// — that one is mirrored to IndexedDB and read
## back whole at every start.
const ROOT := "/tmp/pippop"
const ArenaLayout := preload("res://src/maps/arena_layout.gd")
const ARENA_PREFIX := "arena-"
## What the first screens don't draw: off the first load.
const LATER := ["figures"]

## group -> {"url", "bytes"}, from bundles/manifest.json
static var _manifest := {}
## group -> paths it unpacked under ROOT
static var _have := {}
## what drop_models left of an arena, deleted with the next one
static var _leftover := []
static var _req: HTTPRequest
## an ensure() is running; the next one waits for it
static var _busy := false
## the group being downloaded, its size and what of it is done, for
## progress()
static var _group := ""
static var _total := 0
static var _done := 0


static func active() -> bool:
	return OS.has_feature("web")


## Where the bundles live: bundles/ beside the page.
static func base_url() -> String:
	if not active():
		return ""
	return str(JavaScriptBridge.eval("new URL('bundles/', location.href).href"))


## The game server the page plays on: ?server=<ws url> when given (local
## tests), else /ws on the page's own host, over wss:// on an https page.
static func server_url() -> String:
	if not active():
		return ""
	return str(JavaScriptBridge.eval(
		"new URLSearchParams(location.search).get('server') || "
		+ "((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/ws')"))


static func has(group: String) -> bool:
	return _have.has(group)


## The bundle of the arena a world is played on ("" when it has none).
static func arena_group(world_id: int) -> String:
	var arena: int = ArenaLayout.WORLDS.find(world_id) + 1
	return "%s%02d" % [ARENA_PREFIX, arena] if arena >= 1 else ""


## 0..1 of the group being downloaded; 1 when nothing is.
static func progress() -> float:
	if _group == "" or _total <= 0:
		return 1.0
	var now := _done + (_req.get_downloaded_bytes() if _req != null else 0)
	return clampf(float(now) / _total, 0.0, 1.0)


static func downloading() -> String:
	return _group


## Downloads and unpacks the groups not yet here; false when one fails
## (no network, a bundle the manifest doesn't list). An arena group drops
## the arena unpacked before it.
static func ensure(groups: Array) -> bool:
	if not active():
		return true
	var tree := Engine.get_main_loop() as SceneTree
	while _busy:
		await tree.process_frame
	_busy = true
	var ok: bool = await _ensure(groups)
	_busy = false
	return ok


## Starts the LATER groups downloading without waiting for them.
static func fetch_later() -> void:
	if active():
		ensure(LATER)


static func _ensure(groups: Array) -> bool:
	if _manifest.is_empty() and not await _load_manifest():
		return false
	for g: String in groups:
		if g == "" or _have.has(g):
			continue
		if not _manifest.has(g):
			push_warning("web: no bundle %s" % g)
			return false
		if g.begins_with(ARENA_PREFIX):
			for old: String in _have.keys():
				if old.begins_with(ARENA_PREFIX):
					_drop(old)
			for p: String in _leftover:
				DirAccess.remove_absolute(p)
			_leftover.clear()
		if not await _fetch(g):
			return false
	return true


## The manifest names the parts of this build, so it must never come from
## the browser's cache (the parts themselves are cached for good: their
## names carry their hash).
static func _load_manifest() -> bool:
	var body: Variant = await _http_get(base_url() + "manifest.json?t=%d" % int(Time.get_unix_time_from_system()))
	if not body is PackedByteArray:
		return false
	var m: Variant = JSON.parse_string((body as PackedByteArray).get_string_from_utf8())
	if not m is Dictionary:
		return false
	_manifest = m
	return true


static func _fetch(group: String) -> bool:
	var entry: Dictionary = _manifest[group]
	DirAccess.make_dir_recursive_absolute(ROOT)
	_group = group
	_total = int(entry.get("bytes", 0))
	_done = 0
	var paths := []
	var ok := true
	for part: Dictionary in entry.get("parts", []):
		ok = await _unpack(base_url() + str(part.url), paths)
		_done += int(part.get("bytes", 0))
		if not ok:
			break
	_group = ""
	if not ok:
		for p: String in paths:
			DirAccess.remove_absolute(p)
		return false
	_have[group] = paths
	AssetPaths.reset_roots()   # a file that was missing may be here now
	return true


## Downloads one part and unpacks it into ROOT, adding what it wrote to
## `paths`.
static func _unpack(url: String, paths: Array) -> bool:
	var body: Variant = await _http_get(url)
	if body == null:
		return false
	# HTTPRequest.download_file writes nothing in a web build (4.7.1): the
	# body comes back in memory and goes to a file for ZIPReader.
	var tmp := ROOT.path_join("part.zip")
	var out := FileAccess.open(tmp, FileAccess.WRITE)
	out.store_buffer(body)
	out.close()
	body = null
	var zip := ZIPReader.new()
	if zip.open(tmp) != OK:
		push_warning("web: bad bundle part %s" % url)
		return false
	for name in zip.get_files():
		if name.ends_with("/"):
			continue
		var to := ROOT.path_join(name)
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		var f := FileAccess.open(to, FileAccess.WRITE)
		f.store_buffer(zip.read_file(name))
		f.close()
		paths.append(to)
	zip.close()
	DirAccess.remove_absolute(tmp)
	return true


## Deletes a group's models (.glb) once they are built into the scene: the
## browser keeps every unpacked file in memory. The group counts as gone, so
## a rebuild downloads it again (from the browser's cache); its small JSON
## files stay until the next arena replaces them.
static func drop_models(group: String) -> void:
	if not _have.has(group):
		return
	var rest := []
	for p: String in _have[group]:
		if p.get_extension() == "glb":
			DirAccess.remove_absolute(p)
		else:
			rest.append(p)
	_have.erase(group)
	_leftover.append_array(rest)


## Forgets a group's files. Runs before the next arena unpacks, so a kit
## two arenas share comes back with it.
static func _drop(group: String) -> void:
	for p: String in _have[group]:
		DirAccess.remove_absolute(p)
	_have.erase(group)


## The body of a GET, or null on failure.
static func _http_get(url: String) -> Variant:
	var tree := Engine.get_main_loop() as SceneTree
	_req = HTTPRequest.new()
	_req.accept_gzip = false
	_req.body_size_limit = -1
	tree.root.add_child(_req)
	var err := _req.request(url)
	var res: Array = [HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray()]
	if err == OK:
		res = await _req.request_completed
	_req.queue_free()
	_req = null
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		push_warning("web: %s -> result %d, http %d" % [url, res[0], res[1]])
		return null
	return res[3]
