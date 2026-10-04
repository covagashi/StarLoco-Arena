extends SceneTree

var _gui: GuiLib

func _init() -> void:
	_gui = GuiLib.new("es")
	_gui.event_sink = func(ns, m, args, w): print("[", ns, "] ", m, " args=", args)
	var fighter := {
		"healthPoints": 45, "actionPoints": 6, "movePoints": 3,
		"actorDescriptorLibrary": "res://assets/anims/fighter_-110",
		"actorAnimation": "AnimStatique", "actorDirection": 2,
		"spells": [
			{"id": 31, "iconUrl": "31", "usable": true, "smallDescription": "Cloudy Attack", "cooldownInFight": 0},
			{"id": 32, "iconUrl": "32", "usable": false, "smallDescription": "Stormy Armor", "cooldownInFight": 2},
			null,
		],
		"coachSpells": [{"id": 10, "iconUrl": "10", "smallDescription": "Carta"}],
		"usableFighterCards": [],
		"closeCombatUsable": true,
	}
	var tl := _gui.open_dialog("timelineDialog", {"fight": {"timeline": {"display": true, "fighters": [{"teamId":0,"name":"Iop","timelineIconUrl":"80","hasBuff":false,"isSummoned":false,"runningEffects":[],"nextTableTurn":0,"hideInTimeline":false},{"teamId":1,"name":"Sacrieur","timelineIconUrl":"110","hasBuff":true,"isSummoned":false,"runningEffects":[],"nextTableTurn":0,"hideInTimeline":false}]}}})
	var root := _gui.open_dialog("fighterControlsDialog", {
		"fight": {"timeline": {"currentFighter": fighter},
			"endTurnState": true},
	})
	if root == null:
		push_error("load failed")
		quit(1)
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 170)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.size = Vector2(530, 150)
	vp.add_child(tl)
	tl.position = Vector2(0, 160)
	vp.add_child(root)
	get_root().add_child(vp)
	for i in 6:
		await process_frame
	GuiLayouts.apply(root)
	await process_frame
	print(GuiLib.dump(root))
	var all: Array = []
	_collect(root, all)
	for w in all:
		if w is GWidget and w.kind == "animatedElementViewer":
			print("VIEWER spr=", w._viewer_spr, " lib=", w._viewer["lib"], " anim=", w._viewer["anim"], " frames=", w._viewer_spr._frames.size() if w._viewer_spr != null else -1, " pos=", w._viewer_spr.position if w._viewer_spr != null else Vector2(), " live=", w.get_meta("viewer_live", false), " vis=", w.is_visible_in_tree())
		if w is GWidget and w.kind == "image":
			var ap: Dictionary = w.appearance()
			print("IMG vis=", w.visible, " size=", w.size, " tex=", ap.get("pixmap_tex"), " ib=", w.item_binds, " item=", w.item_value != null)
		if w is GWidget and w.kind == "list":
			print("LIST id=", w.widget_id, " bind=", w.bind, " renderers=", w.renderers.size(), " items=", w.content_items.size())
			for ch in w.get_children():
				print("  child kind=", ch.kind, " vis=", ch.visible, " item=", ch.item_value)
	vp.get_texture().get_image().save_png("res://test/gui_fight.png")
	print("wrote gui_fight.png")
	if _gui.loader.unknown_tags.size() > 0:
		print("unknown: ", _gui.loader.unknown_tags.keys())
	quit()


static func _collect(n: Node, out: Array) -> void:
	if n is GWidget:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)
