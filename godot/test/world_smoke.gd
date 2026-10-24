extends SceneTree

## S05 service audit: every service the walkable hall used to reach, through
## the lobby's City panel, against a live server.
##
##   godot --path godot -s test/world_smoke.gd [-- --shot-dir=D]
##
## Needs a local server on 127.0.0.1:5555 (~2 minutes). Login -> lobby ->
## press the real "City" menu button -> press each service button in the
## panel -> check the evidence that service leaves (its dialog, its pane, or
## the server's reply). The panel merges every island's services and the
## coach never travels: the server resolves each 201 in any world.
## --shot-dir (needs a real renderer: xvfb-run, not --headless) saves the
## lobby, the City panel and the first Card Master it opens; add --shot-all
## for one capture of each kind of service screen.
##
## Prints one "[audit]" line per service and exits 0 only if every one passed.
## It replaces the old hall walk (`_main.get_node("World")`), which died with
## the deprecated hall in S03.

const Codec := preload("res://src/net/codec.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

var _sess: Node
var _main
var _ready_count := 0          # 4516s seen — one per world entry
var _seen := {}                # opcode -> times seen since the last reset
var _results: Array = []       # [kind, label, ok, detail]
var _shot_dir := ""
var _shot_taken := false
var _shot_all := false         # --shot-all: one capture per service kind
var _kind_shot := {}
var _as := "test"              # --as=NAME: log in as another account/coach


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--as="):
			_as = a.trim_prefix("--as=")
	await process_frame
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_sess.message.connect(_on_msg)
	_sess.connect_to("127.0.0.1", 5555)
	await create_timer(0.5).timeout
	_send_login()
	if not await _wait(func(): return _ready_count > 0, 15.0):
		push_error("[audit] never reached the lobby (no 4516)")
		quit(2)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.trim_prefix("--shot-dir=")
		_shot_all = _shot_all or a == "--shot-all"
	await create_timer(1.0).timeout
	await _shot("lobby")
	await _audit()
	_report()


func _send_login() -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	_sess.send(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode(_as)
	var p := CP1252.encode("test123")
	a.put_u8(l.size())
	a.put_bytes(l)
	a.put_u8(p.size())
	a.put_bytes(p)
	_sess.send(1025, a.raw(), 1)


func _on_msg(op: int, _raw: PackedByteArray) -> void:
	_seen[op] = int(_seen.get(op, 0)) + 1
	match op:
		2048:   # coach list -> pick "test"
			var w := WireWriter.new()
			w.put_u8(_as.length())
			w.put_bytes(_as.to_ascii_buffer())
			w.put_u8(1)
			w.put_u8(1)
			w.put_u8(0)
			_sess.send(2049, w.raw(), 2)
		4516:
			_ready_count += 1


func _wait(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


## Open City, then press every service button it lists.
func _audit() -> void:
	var panel = await _open_city()
	if panel == null:
		_record(-1, "City panel", false, "did not open")
		return
	await _shot("city")
	var city: Dictionary = _main._gui.gui.model.get_value("city")
	if city == null or city.get("groups", []).is_empty():
		_record(-1, "City panel", false, "no services listed")
		return
	var services: Array = []
	for g in city.groups:
		for s in g.services:
			# the element's own kind (S22: the Retos group mixes three)
			services.append([int(s.get("kind", g.kind)), s])
	_close_all()
	for entry in services:
		var kind: int = entry[0]
		var s: Dictionary = entry[1]
		var b := await _service_button(int(s.id))
		if b == null:
			_record(kind, str(s.label), false, "button missing")
			continue
		_seen.clear()
		b.pressed.emit()
		var res: Array = await _evidence(kind)
		if kind == 1 and bool(res[0]) and not _shot_taken:
			_shot_taken = true
			await _shot("cardmaster")
		elif _shot_all and bool(res[0]) and not _kind_shot.has(kind):
			_kind_shot[kind] = true
			await _shot("service-%d" % kind)
		_record(kind, str(s.label), bool(res[0]), str(res[1]))
		_close_all()
		await create_timer(0.2).timeout


## What each kind must leave behind within a couple of seconds.
func _evidence(kind: int) -> Array:
	match kind:
		1:
			var ok: bool = await _wait(func(): return _seen.has(5401) \
				and _main._gui.is_open("cardMasterDialog"), 3.0)
			return [ok, "5401 + cardMasterDialog"]
		2:
			var ok: bool = await _wait(func(): return _seen.has(15001) \
				and _main._gui.is_open("mailboxDialog"), 3.0)
			return [ok, "15001 + mailboxDialog (%d letters)" % _main._mails.size()]
		14:
			var ok: bool = await _wait(func(): return _main._gui.is_open("fusionLabDialog"), 2.0)
			return [ok, "fusionLabDialog"]
		12:
			var ok: bool = await _wait(func(): return _main._gui.is_open("fireworkDialog"), 2.0)
			return [ok, "fireworkDialog"]
		3, 5, 6, 7, 9, 15:
			# S18: the native conversation window, never the debug pane
			var ok: bool = await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 2.0)
			var talk: Variant = _main._gui.gui.model.get_value("talk")
			var t: Dictionary = talk if talk is Dictionary else {}
			return [ok and not _debug_pane_shown() and str(t.get("name", "")) != ""
				and not t.get("choices", []).is_empty(),
				"conversation '%s', %d choices" % [t.get("name", ""), t.get("choices", []).size()]]
	return [false, "no check for kind %d" % kind]


func _shot(name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.6).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(_shot_dir.path_join(name + ".png"))
		print("[audit] shot ", name)


## Press the lobby's City menu button (the real entry, not a shortcut).
func _open_city():
	_close_all()
	var lobby = _main._lobby_screen
	if lobby == null:
		return null
	for b in lobby._menu_buttons:
		if b.text == root.get_node("I18n").t("nav.city"):
			b.pressed.emit()
			break
	await create_timer(0.3).timeout
	return _main._gui.dialogs.get("cityDialog")


## The panel button for service `id` (opens City first). Since S22 the
## panel shows one group at a time: pick the group that holds it.
func _service_button(id: int) -> Button:
	var panel = await _open_city()
	if panel == null:
		return null
	var city: Dictionary = _main._gui.gui.model.get_value("city")
	var groups: Array = city.get("groups", [])
	for i in groups.size():
		for s in groups[i].services:
			if int(s.id) == id:
				panel.draft["group"] = i
				panel.schedule_refresh()
				await create_timer(0.3).timeout
				return panel.find_child("Service%d" % id, true, false)
	return null


func _collect_buttons(node: Node, text: String, out: Array) -> void:
	for c in node.get_children():
		if c is Button and not c.disabled and c.text == text:
			out.append(c)
		_collect_buttons(c, text, out)


func _close_all() -> void:
	for n in _main._gui.dialogs.keys():
		_main._gui.close(n)


## The debug pane is gone from main.tscn (S18); a smoke still asserts it
## never comes back.
func _debug_pane_shown() -> bool:
	var dlg = _main.get_node_or_null("UI/ElementDlg")
	return dlg != null and dlg.visible


func _record(kind: int, label: String, ok: bool, detail: String) -> void:
	_results.append([kind, label, ok, detail])
	print("[audit] %s kind=%d %s — %s" % ["OK  " if ok else "FAIL", kind, label, detail])


func _report() -> void:
	var fails := _results.filter(func(r): return not r[2])
	print("[audit] %d checks, %d failed" % [_results.size(), fails.size()])
	quit(0 if fails.is_empty() else 1)
