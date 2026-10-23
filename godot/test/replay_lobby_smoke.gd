extends SceneTree

## S11, the replay path a player takes, through the real main scene:
## menu → Replays → pick one → Ver → fight_view on the recording (transport
## bar, ×4) → the result's "Continuar" → back to a working lobby on the live
## session → Borrar removes the file. Also: Options → Combate's "Guardar
## replays" writes saveReplays and the recorder obeys it, and Social has the
## "Ver combate" button.
##   godot --headless --path godot -s test/replay_lobby_smoke.gd
## Needs the local server and a recording from test/replay_smoke.gd (run it
## first): its newest file is copied into user://replays for the test and
## that copy is deleted again by the test itself.

const State := preload("res://src/state.gd")
const ReplayFile := preload("res://src/net/replay_file.gd")

var main
var failures := 0
var _copy := ""


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	print("[replays] %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1


func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null


func wait_for(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func run() -> void:
	var src := ReplayFile.list("user://replays_smoke")
	if src.is_empty():
		print("[replays] no recording — run test/replay_smoke.gd first")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ReplayFile.DIR)
	_copy = ReplayFile.DIR.path_join("zz_smoke_copy." + ReplayFile.EXT)
	DirAccess.copy_absolute(src[0].path, _copy)
	var i18n: Node = root.get_node("I18n")
	main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._login_screen.submit.emit("test", "test123", "127.0.0.1:5555")
	check(await wait_for(func(): return main._lobby_ready, 30.0), "live login")
	if not main._lobby_ready:
		return _end()
	await create_timer(1.0).timeout
	var live_net: Node = State.net
	# menu → Replays
	var menu = main._gui.open("menuDialog")
	await create_timer(0.2).timeout
	var entry := find_button(menu, i18n.t("menu.replays"))
	check(entry != null, "the menu has Replays")
	if entry == null:
		return _end()
	entry.pressed.emit()
	await create_timer(0.3).timeout
	check(main._gui.is_open("replayDialog"), "Replays opens its panel")
	var panel = main._gui.dialogs.get("replayDialog")
	var tree: Tree = _find(panel, func(n): return n is Tree)
	var row: TreeItem = null
	if tree != null:
		for it in tree.get_root().get_children():
			var meta: Variant = it.get_metadata(0)
			if meta is Dictionary and str(meta.get("path", "")) == _copy:
				row = it
	check(row != null, "the recording is listed")
	if row == null:
		return _end()
	check(row.get_text(2) == i18n.t("replay.result.loss"), "listed as a defeat (%s)" % row.get_text(2))
	row.select(0)
	await create_timer(0.3).timeout
	panel = main._gui.dialogs.get("replayDialog")
	var play: Button = _find(panel, func(n): return n is Button and n.name == "PlayReplay")
	check(play != null and not play.disabled, "Ver is enabled for the pick")
	if play == null or play.disabled:
		return _end()
	play.pressed.emit()
	check(await wait_for(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("fight_view.tscn"), 10.0), "Ver opens the fight view")
	var fv = current_scene
	if fv == null or not fv.scene_file_path.ends_with("fight_view.tscn"):
		return _end()
	check(State.replay != null and State.net == State.replay, "the fight reads the replay, not the socket")
	check(fv.get_node_or_null("UI/ReplayBar") != null, "the transport bar is up")
	check(not fv.get_node("UI/PassBtn").visible, "no PASS button in a replay")
	var speed: Button = fv.get_node("UI/ReplayBar").find_child("SpeedBtn", true, false)
	speed.pressed.emit()
	speed.pressed.emit()
	check(speed.text == "×4" and is_equal_approx(Engine.time_scale, 4.0), "×4 from the bar")
	check(await wait_for(func(): return fv._result_modal != null, 60.0), "the replay reaches the result screen")
	var cont := find_button(fv, i18n.t("fight.result.continue"))
	check(cont != null, "the result has Continuar")
	if cont == null:
		return _end()
	cont.pressed.emit()
	check(await wait_for(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("main.tscn"), 10.0), "Continuar goes back to the lobby")
	main = current_scene
	await create_timer(0.5).timeout
	check(State.replay == null and State.net == live_net, "the live session is back")
	check(Engine.time_scale == 1.0, "normal speed in the lobby")
	check(main._lobby_ready and is_instance_valid(main._lobby_screen) \
		and main._lobby_screen.is_visible_in_tree(), "the lobby is up and ready")
	check(State.fight_result.is_empty(), "no stray fight result pops in the lobby")
	# the live socket still answers: open the ladder (a server round trip)
	check(State.net.is_online(), "still connected")
	# Borrar
	panel = main._gui.open("replayDialog")
	await create_timer(0.3).timeout
	tree = _find(panel, func(n): return n is Tree)
	for it in tree.get_root().get_children():
		var meta: Variant = it.get_metadata(0)
		if meta is Dictionary and str(meta.get("path", "")) == _copy:
			it.select(0)
	await create_timer(0.3).timeout
	panel = main._gui.dialogs.get("replayDialog")
	var del: Button = _find(panel, func(n): return n is Button and n.name == "DeleteReplay")
	del.pressed.emit()
	await create_timer(0.2).timeout
	var dlg: ConfirmationDialog = _find(panel, func(n): return n is ConfirmationDialog)
	check(dlg != null, "Borrar asks first")
	if dlg != null:
		dlg.confirmed.emit()
	await create_timer(0.3).timeout
	check(not FileAccess.file_exists(_copy), "Borrar deletes the file")
	main._gui.close("replayDialog")
	# Options → Combate → Guardar replays
	var opts = main._gui.open("optionsDialog")
	await create_timer(0.3).timeout
	var save: CheckButton = _find(opts, func(n): return n is CheckButton and n.name == "saveReplays")
	check(save != null, "Options has Guardar replays")
	if save != null:
		var was := save.button_pressed
		save.button_pressed = false
		await create_timer(0.2).timeout
		var rec = root.get_node("Session").recorder
		check(not rec.enabled(), "off → the recorder stops recording")
		save.button_pressed = true
		await create_timer(0.2).timeout
		check(rec.enabled(), "on again")
		save.button_pressed = was
	main._gui.close("optionsDialog")
	# Social → Ver combate
	var social = main._gui.open("socialDialog")
	await create_timer(0.3).timeout
	check(_find(social, func(n): return n is Button and n.name == "WatchBtn") != null, "Social has Ver combate")
	_end()


func _find(node: Node, pred: Callable) -> Node:
	if node == null:
		return null
	if pred.call(node):
		return node
	for c in node.get_children():
		var f := _find(c, pred)
		if f != null:
			return f
	return null


func _end() -> void:
	if _copy != "" and FileAccess.file_exists(_copy):
		DirAccess.remove_absolute(_copy)
	print("[replays] %s" % ("all passed" if failures == 0 else "%d failed" % failures))
	quit(0 if failures == 0 else 1)
