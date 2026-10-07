extends Node2D

const Login := preload("res://src/ui/login_screen.gd")
const Creation := preload("res://src/ui/creation_screen.gd")
const Lobby := preload("res://src/ui/lobby_screen.gd")
const Panels := preload("res://src/ui/lobby_panels.gd")
const Chat := preload("res://src/ui/chat_box.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("[ui review] " + what)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	get_viewport().get_texture().get_image().save_png(
		"/private/tmp/ui-review-%s-%dx%d.png" % [name, int(vp.x), int(vp.y)])


func _run() -> void:
	var model := GuiModel.new()
	model.set_value("localCoach", {"name": "Arel", "level": 8, "sex": 0,
		"skin": 0, "hair": 0, "actorDirection": 5,
		"actorDescriptorLibrary": "coach_7000", "actorMaterial": {}})
	var login := Login.new()
	add_child(login)
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() == login.name_edit,
		"login initial focus")
	_check(login.name_edit.focus_next != NodePath(""), "login tab order")
	await _shot("login")
	login.queue_free()
	await get_tree().process_frame
	var creation := Creation.new()
	add_child(creation)
	creation.bind_model(model)
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() == creation.name_edit,
		"creation initial focus")
	for control in creation.get_child(0).get_children():
		if control is Button:
			_check(control.focus_mode != Control.FOCUS_NONE,
				"creation button outside keyboard traversal")
	await _shot("creation")
	creation.queue_free()
	await get_tree().process_frame
	var chat := Chat.instantiate()
	add_child(chat)
	var lobby := Lobby.new()
	add_child(lobby)
	lobby.bind_model(model, chat)
	await get_tree().process_frame
	await _shot("lobby")
	var vp := get_viewport().get_visible_rect().size
	for name in Panels.TITLES:
		var panel := Panels.new()
		panel.panel_name = name
		panel.model = model
		add_child(panel)
		await get_tree().process_frame
		_check(panel.frame.get_global_rect().position.x >= -1
			and panel.frame.get_global_rect().position.y >= -1
			and panel.frame.get_global_rect().end.x <= vp.x + 1
			and panel.frame.get_global_rect().end.y <= vp.y + 1,
			"panel outside viewport: " + name)
		if name in ["teamManagementDialog", "socialDialog", "cardBookDialog",
				"fighterCreationDialog", "optionsDialog"]:
			await _shot(name)
		panel.queue_free()
		await get_tree().process_frame
	var bug := preload("res://src/ui/bug_report.gd").new("")
	add_child(bug)
	bug.popup_centered()
	await get_tree().process_frame
	var bug_rect := Rect2(bug.position, bug.size)
	_check(bug_rect.position.y >= 0 and bug_rect.end.y <= vp.y,
		"bug report outside viewport")
	await _shot("bug-report")
	bug.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)
