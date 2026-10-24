extends "res://test/world_smoke.gd"

## S20: the modes the owner kept (2026-10-24). 2vs2 hidden and Leyendas
## removed (src/features.gd): the hub has Historia / Ranking / Torneos and no dúo, the Team panel
## shows Evolución / Élite / Torneos, an evolution fighter offers no
## "Convertir en leyenda", and no Legends tournament reaches the Calendar.
##
##   godot --path godot -s test/modes_smoke.gd [-- --shot-dir=D]


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.3).timeout
	var lobby = _main._lobby_screen
	# S20B: one card per mode kept; no dúo anywhere in the hub
	var titles: Array = ["story", "ranked", "tourn"].map(func(id): return lobby._cards[id].title.text)
	var texts: Array = lobby.find_children("*", "Button", true, false).map(func(b): return b.text)
	_record(0, "lobby", titles == [i18n.t("hub.story"), i18n.t("hub.ranked"), i18n.t("hub.tourn")]
		and not texts.has(i18n.t("lobby.action.duo")),
		"cards: %s" % ", ".join(titles))
	_close_all()
	for b in lobby._menu_buttons:
		if b.text == i18n.t("nav.team"):
			b.pressed.emit()
	await _wait(func(): return _main._gui.is_open("teamManagementDialog"), 3.0)
	await create_timer(0.5).timeout
	var team = _main._gui.dialogs.get("teamManagementDialog")
	var want := [i18n.t("team.tab_evolution"), i18n.t("team.tab_elite"), i18n.t("team.tab_tournaments")]
	var tabs: Array = []
	for b in team.find_children("*", "Button", true, false):
		if b.toggle_mode and b.text in [i18n.t("team.tab_evolution"), i18n.t("team.tab_elite"),
				i18n.t("team.tab_duo"), i18n.t("team.tab_tournaments"), i18n.t("team.tab_legends")]:
			tabs.append(b.text)
	_record(0, "team tabs", tabs == want, "tabs: %s" % ", ".join(tabs))
	# the Tournaments tab is mode 3, not the third button's index 2
	for b in team.find_children("*", "Button", true, false):
		if b.toggle_mode and b.text == i18n.t("team.tab_tournaments"):
			b.pressed.emit()
	await create_timer(0.6).timeout
	var mode := int(_main._gui.gui.model.get_value("gamePreferences", "lastSelectedGameModeId"))
	_record(0, "tab id", mode == 3 and int(team.tab) == 3, "Torneos → mode %d, tab %d" % [mode, int(team.tab)])
	await _shot("team-torneos")
	for b in team.find_children("*", "Button", true, false):
		if b.toggle_mode and b.text == i18n.t("team.tab_evolution"):
			b.pressed.emit()
	await create_timer(0.5).timeout
	for t in team.find_children("*", "Tree", true, false):
		for it in t.get_root().get_children():
			if it.get_metadata(0) is Dictionary:
				it.select(0)
				break
		break
	await create_timer(0.5).timeout
	var leg: Array = []
	_collect_buttons(team, i18n.t("team.make_legend"), leg)
	var sph: Array = []
	_collect_buttons(team, i18n.t("team.spheres"), sph)
	_record(0, "no legend", leg.is_empty() and not sph.is_empty(),
		"evolution fighter: Esferas=%d, Convertir en leyenda=%d" % [sph.size(), leg.size()])
	await _shot("team-evolucion")
	var legends := 0
	for cell in _main._gui.gui.model.get_value("calendar", "calendar") if _main._gui.gui.model.get_value("calendar", "calendar") is Array else []:
		for e in cell.get("events", []):
			if int(e.get("kind", 0)) == 4:
				legends += 1
	_record(0, "calendar", legends == 0, "%d Legends tournaments in the calendar" % legends)
	_close_all()
	i18n.set_locale(lang_before)
