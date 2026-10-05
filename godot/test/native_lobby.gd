extends SceneTree
## Windowed live regression: -- host:port login password.
var _main
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print("[lobby] %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		_failures += 1

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("Usage: -- host:port login password")
		quit(2)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	_main._login_screen.submit.emit(args[1], args[2], args[0])
	for i in range(300):
		await create_timer(0.1).timeout
		if _main._lobby_ready:
			break
	_check(_main._lobby_ready, "authenticated and instance ready")
	if not _main._lobby_ready:
		quit(1)
		return
	await create_timer(1.0).timeout
	var lobby = _main._lobby_screen
	_check(lobby != null and lobby.get_parent() == _main.get_node("UI"), "native lobby in UI CanvasLayer")
	_check(not _main._gui.is_open("menuBarDialog"), "retail menu bar replaced")
	_check(not _main.get_node("UI/VBox").visible, "debug bars hidden")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	_check(_main.get_node("UI/Chat/Row/Input").has_focus(), "Enter focuses chat")
	_main.get_node("UI/Chat/Row/Input").release_focus()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/native-lobby.png")
	for entry in lobby.MENUS:
		lobby.dialog_requested.emit(entry[1])
		await process_frame
		if entry[1] == "socialDialog":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/native-lobby-social.png")
		_check(_main._gui.is_open(entry[1]), "opens " + entry[1])
		lobby.dialog_requested.emit(entry[1])
		await process_frame
		_check(not _main._gui.is_open(entry[1]), "closes " + entry[1])
	lobby.debug_requested.emit()
	_check(_main.get_node("UI/VBox").visible, "debug controls reachable")
	lobby.debug_requested.emit()
	_main._gui.gui.model.set_value("localCoach", [{"name": "Aplaudir", "id": 57}], "equipedEmotes")
	_check(lobby._emotes.get_popup().item_count == 2, "model refreshes emote actions")
	_main._gui.gui.model.set_value("localCoach", [], "equipedEmotes")
	_main._lobby_screen.queue_free()
	await process_frame
	_main._show_lobby_screen()
	_check(_main._lobby_screen != null, "lobby remounts")
	# The actual native button invokes the unchanged practice handler.
	_main._lobby_screen._actions[0].pressed.emit()
	for i in range(100):
		await create_timer(0.1).timeout
		if not is_instance_valid(_main):
			break
	_check(not is_instance_valid(_main), "practice enters the fight scene")
	if not is_instance_valid(_main):
		_check(current_scene.scene_file_path == "res://src/fight/fight_view.tscn", "retail fight creation transition")
		current_scene.get_node("UI/TopBar/BackBtn").pressed.emit()
		await create_timer(1.0).timeout
		_check(current_scene.get_node_or_null("UI/LobbyScreen") != null, "return from fight restores lobby")
	print("[lobby] screenshot /private/tmp/native-lobby.png")
	quit(0 if _failures == 0 else 1)
