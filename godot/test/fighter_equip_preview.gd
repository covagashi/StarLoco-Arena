extends Node

## S35c: the fighter equipment panel (lobby_panels._equipment) with its 3D
## figure wearing the cards, without a server. Shoots it, swaps the hat card
## for none and the weapon in, and checks the figure was kept (only the
## pieces change), then shoots again. Last, a cape and a pet: the figure
## walks and the cape must swing back from its rest.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 test/fighter_equip_preview.tscn -- \
##       [--out=/tmp/fe] [--breed=8] [--sex=1]

const Panels := preload("res://src/ui/lobby_panels.gd")
const FightView := preload("res://src/fight/fight_view.gd")

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k):
			return a.get_slice("=", 1)
	return d


func _fighter(cards: Dictionary) -> Dictionary:
	var breed := int(_arg("breed", "1"))
	var sex := int(_arg("sex", "0"))
	var f := {"name": "Arel", "breedId": breed, "sex": sex, "value": 120,
		"actorDescriptorLibrary": "fighter_%s" % FightView.FIGHTER_FILES[(breed - 1) * 2 + sex],
		"spells": [], "breedSpells": []}
	for field in Panels.EQ_FIELDS:
		f[field] = {}
	for field in cards:
		f[field] = {"id": cards[field], "name": "#%d" % cards[field]}
	return f


func _shot(path: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[fe] " + path)


func _run() -> void:
	var out := _arg("out", "/tmp/fe")
	var model := GuiModel.new()
	model.set_value("teamManagement", {"editableFighter": _fighter(
		{"hatEquipment": 108, "dofusEquipment": 118}), "selectedItemCardListType": 3,
		"selectedItemCardList": []})
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Panels.new()
	panel.panel_name = "fighterEquipmentDialog"
	panel.model = model
	panel.tab = 1
	layer.add_child(panel)
	await get_tree().process_frame
	panel.refresh()
	await _shot(out + "-1.png")
	var fig = panel._eq_fig
	var m3d = fig.model3d if fig else null
	if m3d == null:
		_fails += 1
		push_error("[fe] no 3D figure in the panel")
	else:
		if not m3d.worn().has("hat") or not m3d.worn().has("dofus"):
			_fails += 1
			push_error("[fe] hat and dofus not worn: %s" % m3d.worn().keys())
	model.set_value("teamManagement", _fighter({"weaponEquipment": 1, "dofusEquipment": 118}), "editableFighter")
	panel.refresh()
	await _shot(out + "-2.png")
	if fig != panel._eq_fig or (m3d != null and fig.model3d != m3d):
		_fails += 1
		push_error("[fe] the figure was rebuilt on a change of card")
	elif m3d != null and (m3d.worn().has("hat") or not m3d.worn().has("weapon")):
		_fails += 1
		push_error("[fe] after the swap: %s" % m3d.worn().keys())
	model.set_value("teamManagement", _fighter({"cloakEquipment": 97, "petEquipment": 92}), "editableFighter")
	panel.refresh()
	if m3d != null:
		if not m3d.worn().has("cape") or not m3d.worn().has("pet"):
			_fails += 1
			push_error("[fe] cape and pet not worn: %s" % m3d.worn().keys())
		else:
			m3d.take("1_AnimMarche", false, false)
			for i in 40:
				await get_tree().process_frame
			var p: Node3D = m3d.worn().cape.get_child(0)
			var lift := rad_to_deg((p.get_meta("rest") as Transform3D).basis.get_rotation_quaternion().angle_to(p.transform.basis.get_rotation_quaternion()))
			print("[fe] cape lifted %.1f deg walking" % lift)
			if lift < 3.0:
				_fails += 1
				push_error("[fe] the cape doesn't swing while walking")
	await _shot(out + "-3.png")
	print("[fe] %s" % ("ok" if _fails == 0 else "%d failure(s)" % _fails))
	get_tree().quit(1 if _fails else 0)
