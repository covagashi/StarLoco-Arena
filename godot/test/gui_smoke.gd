extends SceneTree
## gui_smoke.gd — loads the retail theme + logonDialog.xml, checks the
## widget tree binds, then renders the dialog to a PNG for visual review.

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var gui := GuiLib.new("es")
	print("[smoke] theme: %d elements, %d colors, %d fonts, %d textures, %d borders in %dms" % [
		gui.theme.elements.size(), gui.theme.colors.size(), gui.theme.fonts.size(),
		gui.theme.textures.size(), gui.theme.pixmap_borders.size(),
		Time.get_ticks_msec() - t0])

	var model := {
		"account.name": "test",
		"account.password": "secret",
		"account.remember": true,
		"buildVersion": "2.70 (72909)",
		"gamePreferences": {"language": "es"},
		"proxy": {"list": [{"text": "127.0.0.1:5555"}], "selected": "127.0.0.1:5555"},
	}
	var root := gui.open_dialog("logonDialog", model)
	if root == null:
		push_error("[smoke] logonDialog failed to load")
		quit(1)
		return
	root.gui_event.connect(func(a): print("[event] ", a))
	gui.event_sink = func(m, args, w): print("[dofusarena] ", m, " args=", args)

	# host the dialog in a viewport
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 768)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.size = Vector2(1024, 768)
	vp.add_child(root)
	get_root().add_child(vp)

	# let frames run so layout + draw settle
	for i in 6:
		await process_frame
	GuiLayouts.apply(root)
	await process_frame
	print("[smoke] tree:")
	print(GuiLib.dump(root))
	var img := vp.get_texture().get_image()
	img.save_png("res://test/gui_logon.png")
	print("[smoke] wrote test/gui_logon.png")
	if gui.loader.unknown_tags.size() > 0:
		print("[smoke] unknown tags: ", gui.loader.unknown_tags.keys())
	quit(0)
