extends SceneTree

## S05 service audit: every service the walkable hall used to reach, through
## the lobby's City panel, against a live server.
##
##   godot --path godot -s test/world_smoke.gd [-- --worlds=35,79] [--shot-dir=D]
##
## Needs a local server on 127.0.0.1:5555. The full tour takes ~4 minutes;
## --worlds keeps only those stops (the Zaap/GM hop to each still runs).
## --shot-dir (needs a real renderer: xvfb-run, not --headless) saves the
## lobby, each world's City panel and the first Card Master it opens.
##
## Login -> lobby -> press the real "City" menu button -> press each service
## button in the panel -> check the evidence that service leaves (its retail
## dialog, its pane, or the server's reply) -> Zaap to the next island through
## the panel's destination buttons. Worlds no Zaap card reaches (35, 79, 80,
## 85) are visited with the GM /world command (the `test` account is admin)
## and reported as such: their services work, but a player can't get there.
##
## Prints one "[audit]" line per service and exits 0 only if every one passed.
## It replaces the old hall walk (`_main.get_node("World")`), which died with
## the deprecated hall in S03.

const Codec := preload("res://src/net/codec.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

## Island tour: [world, how to get there]. A card id travels through the City
## panel's Zaap button; "gm" uses /world (not reachable by players).
const TOUR := [[25, 204], [23, 202], [37, 255], [24, 203], [26, 208],
	[27, 206], [28, 207], [35, "gm"], [79, "gm"], [80, "gm"], [85, "gm"]]

var _sess: Node
var _main
var _ready_count := 0          # 4516s seen — one per world entry
var _seen := {}                # opcode -> times seen since the last reset
var _results: Array = []       # [world, kind, label, ok, detail]
var _shot_dir := ""
var _shot_taken := {}


func _init() -> void:
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
	await create_timer(1.0).timeout
	await _shot("lobby")
	await _tour()
	_report()


func _send_login() -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	_sess.send(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode("test")
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
			w.put_u8(4)
			w.put_bytes("test".to_ascii_buffer())
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


func _tour() -> void:
	var only := []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--worlds="):
			for w in a.trim_prefix("--worlds=").split(","):
				only.append(int(w))
	for stop in TOUR:
		var world := int(stop[0])
		if not only.is_empty() and not world in only:
			continue
		if State.current_world != world:
			var before := _ready_count
			if str(stop[1]) == "gm":
				_main.log._on_submit("/world %d" % world)
			else:
				var b := await _city_button("nativeZaap", int(stop[1]))
				if b == null:
					_record(world, 4, "Zaap", false,
						"no enabled destination button for card %s" % stop[1])
					continue
				b.pressed.emit()
			var ok: bool = await _wait(func(): return _ready_count > before \
				and State.current_world == world, 8.0)
			_record(world, 4, "Zaap" if str(stop[1]) != "gm" else "/world (GM)",
				ok, "world now %d" % State.current_world)
			if not ok:
				continue
			await create_timer(0.8).timeout
		await _audit_world(world, str(stop[1]) == "gm")


## Open City, then press every service button it lists for this world.
func _audit_world(world: int, gm_only: bool) -> void:
	var panel = await _open_city()
	if panel == null:
		_record(world, -1, "City panel", false, "did not open")
		return
	await _shot("city-%d" % world)
	var city: Dictionary = _main._gui.gui.model.get_value("city")
	if city == null or city.get("groups", []).is_empty():
		_record(world, -1, "City panel", false, "no services listed")
		return
	var services: Array = []
	for g in city.groups:
		for s in g.services:
			services.append([int(g.kind), s])
	_close_all()
	for entry in services:
		var kind: int = entry[0]
		var s: Dictionary = entry[1]
		var b := await _city_button("nativeUseElement", int(s.id))
		if b == null:
			_record(world, kind, str(s.label), false, "button missing")
			continue
		_seen.clear()
		b.pressed.emit()
		var res: Array = await _evidence(kind)
		if kind == 1 and bool(res[0]) and not _shot_taken.has(world):
			_shot_taken[world] = true
			await _shot("cardmaster-%d" % world)
		var note := str(res[1]) + (" [GM-only world]" if gm_only else "")
		_record(world, kind, str(s.label), bool(res[0]), note)
		_close_all()
		await create_timer(0.2).timeout


## What each kind must leave behind within a couple of seconds.
func _evidence(kind: int) -> Array:
	var dlg: Control = _main.get_node("UI/ElementDlg")
	var elem_open := func(): return dlg.visible
	match kind:
		1:
			var ok: bool = await _wait(func(): return _seen.has(5401) \
				and _main._gui.is_open("cardMasterDialog"), 3.0)
			return [ok, "5401 + cardMasterDialog"]
		2:
			var ok: bool = await _wait(func(): return _seen.has(15001) \
				and _main._gui.is_open("mailboxDialog"), 3.0)
			return [ok, "15001 + mailboxDialog (%d letters)" % _main._mails.size()]
		10:
			var ok: bool = await _wait(elem_open, 2.0)
			return [ok, "graveyard pane '%s'" % _title()]
		14:
			var ok: bool = await _wait(func(): return _main._gui.is_open("fusionLabDialog"), 2.0)
			return [ok, "fusionLabDialog"]
		12:
			var ok: bool = await _wait(func(): return _main._gui.is_open("fireworkDialog") \
				or dlg.visible, 2.0)
			return [ok, "fireworkDialog" if _main._gui.is_open("fireworkDialog") else "firework pane"]
		11:
			var ok: bool = await _wait(func(): return _seen.has(27511) and dlg.visible, 3.0)
			return [ok, "27511 demon ladder + pane"]
		13:
			var ok: bool = await _wait(func(): return _seen.has(17003), 3.0)
			return [ok, "17003 calendar%s" % (" + 28602 list" if _seen.has(28602) else "")]
		3, 6, 7:
			var ok: bool = await _wait(elem_open, 2.0)
			var rows: int = _main.get_node("UI/ElementDlg/VBox/Scroll/List").item_count
			return [ok, "pane '%s', %d rows" % [_title(), rows]]
		5, 9, 15:
			var ok: bool = await _wait(elem_open, 2.0)
			return [ok and _title() != "", "pane '%s'" % _title()]
	return [false, "no check for kind %d" % kind]


func _shot(name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.6).timeout
	var img := root.get_texture().get_image()
	if img != null:
		img.save_png(_shot_dir.path_join(name + ".png"))
		print("[audit] shot ", name)


func _title() -> String:
	return str(_main.get_node("UI/ElementDlg/VBox/Title").text)


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


## The panel button that fires `event` with this id/card (opens City first).
func _city_button(event: String, id: int) -> Button:
	var panel = await _open_city()
	if panel == null:
		return null
	var city: Dictionary = _main._gui.gui.model.get_value("city")
	var want := ""
	if event == "nativeZaap":
		for d in city.get("zaaps", []):
			if int(d.card) == id and not bool(d.get("here", false)):
				want = str(d.name)
	else:
		for g in city.get("groups", []):
			for s in g.services:
				if int(s.id) == id:
					want = str(s.label)
	if want == "":
		return null
	var found: Array = []
	_collect_buttons(panel, want, found)
	# Same label twice (two Card Masters of one catalogue) — the panel lists
	# them in id order, and so do we.
	return found[0] if not found.is_empty() else null


func _collect_buttons(node: Node, text: String, out: Array) -> void:
	for c in node.get_children():
		if c is Button and not c.disabled and c.text == text:
			out.append(c)
		_collect_buttons(c, text, out)


func _close_all() -> void:
	for n in _main._gui.dialogs.keys():
		_main._gui.close(n)
	_main.get_node("UI/ElementDlg").visible = false


func _record(world: int, kind: int, label: String, ok: bool, detail: String) -> void:
	_results.append([world, kind, label, ok, detail])
	print("[audit] %s world=%d kind=%d %s — %s" % [
		"OK  " if ok else "FAIL", world, kind, label, detail])


func _report() -> void:
	var fails := _results.filter(func(r): return not r[3])
	print("[audit] %d checks, %d failed" % [_results.size(), fails.size()])
	quit(0 if fails.is_empty() else 1)
