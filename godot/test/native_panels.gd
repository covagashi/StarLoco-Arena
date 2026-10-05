extends SceneTree
## Windowed native lobby regression. -- host:port login password
## Uses actual input events for close controls and Escape, not close() calls.
const PanelScript := preload("res://src/ui/lobby_panels.gd")
var main
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("[panels] %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures += 1

func click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = pos
	Input.parse_input_event(move)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = pos
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func key(code: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/panels-" + name + ".png")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		quit(2)
		return
	main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._login_screen.submit.emit(args[1], args[2], args[0])
	for i in 300:
		await create_timer(0.1).timeout
		if main._lobby_ready: break
	check(main._lobby_ready, "live login")
	if not main._lobby_ready:
		quit(1)
		return
	await create_timer(1.0).timeout
	for name in PanelScript.TITLES:
		if name == "fighterCreationDialog":
			main._on_new_fighter_dialog([], null, true)
		var panel = main._gui.open(name)
		await create_timer(0.15).timeout
		check(panel is PanelScript, "native " + name)
		check(main._gui.open(name) == panel, "opening twice is idempotent " + name)
		check(panel.frame.get_global_rect().end.x <= root.get_visible_rect().size.x + 1 and panel.frame.get_global_rect().end.y <= root.get_visible_rect().size.y + 1, "fits viewport " + name)
		await shot(name)
		await click(panel.close_button)
		check(not main._gui.is_open(name), "mouse closes " + name)
		main._gui.open(name)
		await create_timer(0.1).timeout
		await key(KEY_ESCAPE)
		check(not main._gui.is_open(name), "Escape closes " + name)
	await exercise_controls()
	# Legacy close events use an uppercase first letter and must canonicalize.
	main._gui.open("teamManagementDialog")
	main._gui._on_event("dofusarena", "closeTeamManagementDialog", [], null)
	check(not main._gui.is_open("teamManagementDialog"), "legacy case normalization")
	# Stacked subpanels close one at a time and leave their parent available.
	main._gui.open("teamManagementDialog")
	main._gui.open("tooltipDialog")
	await process_frame
	await key(KEY_ESCAPE)
	check(main._gui.is_open("teamManagementDialog") and not main._gui.is_open("tooltipDialog"), "Escape closes only the top panel")
	await key(KEY_ESCAPE)
	# Smaller window remains bounded; restore original dimensions afterwards.
	var original := root.size
	root.size = Vector2i(1024, 768)
	var team = main._gui.open("teamManagementDialog")
	await create_timer(0.2).timeout
	await shot("team-small")
	check(team.frame.get_global_rect().end.x <= 1024, "smaller window fits")
	await click(team.close_button)
	root.size = original
	await key(KEY_ENTER)
	check(main.get_node("UI/Chat/Row/Input").has_focus(), "chat focus after closing panels")
	quit(0 if failures == 0 else 1)


func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null


func exercise_controls() -> void:
	var panel = main._gui.open("teamManagementDialog")
	await create_timer(0.1).timeout
	for entry in [["Élite", 1], ["2v2", 2], ["Torneos", 3], ["Leyendas", 4], ["Evolución", 0]]:
		await click(find_button(panel, entry[0]))
		await create_timer(0.1).timeout
		check(main._tm_tab() == entry[1], "real tab click " + entry[0])
	await click(find_button(panel, "Crear luchador"))
	await create_timer(0.2).timeout
	check(main._gui.is_open("fighterCreationDialog"), "native fighter creation from team")
	var creation = main._gui.dialogs["fighterCreationDialog"]
	check(not creation._preview.current.is_empty(), "fighter preview loaded")
	await shot("fighter-preview")
	await click(creation.close_button)
	check(main._gui.is_open("teamManagementDialog"), "closing child keeps team panel")
	# Local-only fixtures cover populated and long rows without modifying the server.
	var rows: Array = []
	for i in 30:
		rows.append({"id": i+1, "name": "Luchador de prueba con nombre extenso %d" % i,
			"breedId": 8, "state": 0, "type": 2})
	main._gui.gui.model.set_value("teamManagement", {"fighters": rows}, "editableTeamPreset")
	await create_timer(0.2).timeout
	var tree: Tree = find_tree(panel)
	tree.get_root().get_first_child().select(0)
	await create_timer(0.1).timeout
	check(find_button(panel, "Equipamiento y hechizos") != null, "populated fighter selection exposes actions")
	await shot("team-populated")
	var fight_button := find_button(panel, "Buscar combate")
	check(fight_button.get_global_rect().end.y <= panel.frame.get_global_rect().end.y, "populated team combat footer fits")
	var original_size := root.size
	root.size = Vector2i(1024, 768)
	await create_timer(0.2).timeout
	await shot("team-populated-small")
	check(fight_button.get_global_rect().end.y <= root.get_visible_rect().size.y, "populated team footer fits smaller window")
	root.size = original_size
	await create_timer(0.1).timeout
	# Spy on the adapter boundary so fake fighter IDs never reach the wire.
	panel.requested.disconnect(main._on_native_lobby_action)
	var events: Array = []
	panel.requested.connect(func(event, args, item, index): events.append([event, args, item, index]))
	await click(find_button(panel, "Equipamiento y hechizos"))
	check(not events.is_empty() and events[0][0] == "editFighter" and events[0][2].id == 1, "native action carries selected fighter")
	await click(panel.close_button)
	main._push_team_model()
	# Options opened from the native menu must use the native factory too.
	panel = main._gui.open("menuDialog")
	await create_timer(0.1).timeout
	await click(find_button(panel, "Opciones"))
	await create_timer(0.1).timeout
	check(main._gui.is_open("optionsDialog") and not main._gui.is_open("menuDialog"), "menu navigation routes to native options")
	await key(KEY_ESCAPE)


func find_tree(node: Node) -> Tree:
	if node is Tree: return node
	for child in node.get_children():
		var found := find_tree(child)
		if found != null: return found
	return null
