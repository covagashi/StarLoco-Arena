extends "res://test/world_smoke.gd"

## S21: the Ayuda in four tabs and every panel's "?", live. In Spanish.
##
##   godot --path godot -s test/help_smoke.gd [-- --shot-dir=D]


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.4).timeout
	_close_all()
	_main._gui.open("tooltipDialog")
	await create_timer(0.5).timeout
	var p = _main._gui.dialogs.get("tooltipDialog")
	var names := [i18n.t("help.tab_start"), i18n.t("help.tab_modes"), i18n.t("help.tab_fight"), i18n.t("help.tab_panels")]
	var seen := []
	for n in names:
		var b: Button = null
		for c in p.find_children("*", "Button", true, false):
			if c.toggle_mode and c.text == n:
				b = c
		if b == null:
			continue
		b.pressed.emit()
		await create_timer(0.4).timeout
		var text := ""
		for l in p.body.find_children("*", "Label", true, false):
			text += l.text + "\n"
		seen.append(n)
		match n:
			"Modos":
				_record(0, "modes", i18n.t("help.mode_story") in text and i18n.t("help.mode_ranked") in text,
					"Historia, Ranking y Torneos explicados")
				await _shot("help-modes")
			"Combate":
				_record(0, "fight", "40 %" in text and "PASAR" in text, "the fight's rules")
			"Paneles":
				_record(0, "panels", i18n.t("help.panel_city") in text, "each lobby panel")
	_record(0, "tabs", seen == names, "tabs: %s" % ", ".join(seen))
	_close_all()
	# 2. "?" on a panel
	_main._gui.open("teamManagementDialog")
	await create_timer(0.5).timeout
	var team = _main._gui.dialogs.get("teamManagementDialog")
	var about: Button = team.find_child("About", true, false)
	var text: Label = team.find_child("AboutText", true, false)
	var hidden_first: bool = text != null and not text.visible
	if about != null:
		about.pressed.emit()
	await create_timer(0.3).timeout
	await _shot("help-about")
	_record(0, "about", hidden_first and text.visible and text.text == i18n.t("help.panel.teamManagementDialog"),
		"? shows: '%s…'" % (text.text.left(40) if text != null else "—"))
	_close_all()
	i18n.set_locale(lang_before)
