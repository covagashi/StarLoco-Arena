extends "res://test/world_smoke.gd"

## S20B: the hub, live. In Spanish.
##
##   godot --path godot -s test/hub_smoke.gd [-- --shot-dir=D]
##
## 1. Three mode cards (Historia, Ranking, Torneos), each with its phrase,
##    what it pays and its team line; the Story card counts the starters.
## 2. Ranking names the team it fields: the picker lists the Elite presets and
##    picking one is the team the search sends (main._tm_preset_sel).
## 3. "Jugar" on Ranking searches (23103 → 23104) with the search card; after
##    20 s of an empty queue it offers a ghost; Cancelar ends it.
## 4. "Contra un fantasma" opens the ghosts panel.
## 5. The nine menus: six below, three in the top bar, each opens its panel.
## 6. Pad / keyboard: from Ranking's Jugar, right reaches Torneos' button and
##    down reaches the six panels.


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.6).timeout
	_close_all()
	await create_timer(0.3).timeout
	await _shot("hub")
	var lobby = _main._lobby_screen
	var c: Dictionary = lobby._cards
	var ok := true
	for id in ["story", "ranked", "tourn"]:
		ok = ok and c[id].phrase.text != "" and c[id].wins.text != "" and c[id].play.text != ""
	var titulars := 0
	for fr in State.roster:
		if int(fr.get("type", 2)) == 2 and int(fr.get("state", 0)) == 0:
			titulars += 1
	_record(0, "cards", ok and (titulars == 0 or str(titulars) in c.story.team.text),
		"Historia '%s' · Ranking '%s' · Torneos '%s'" % [c.story.team.text,
			c.ranked.pick.get_item_text(c.ranked.pick.selected) if c.ranked.pick.item_count > 0 else c.ranked.team.text,
			c.tourn.team.text])
	# 2. the Ranking team
	var pick: OptionButton = c.ranked.pick
	if pick.item_count >= 1:
		var last := pick.item_count - 1
		pick.select(last)
		pick.item_selected.emit(last)
		await create_timer(0.3).timeout
		_record(0, "ranked team", int(_main._tm_preset_sel) == pick.get_item_id(last),
			"picked '%s' → the search fields preset %d" % [pick.get_item_text(last), int(_main._tm_preset_sel)])
	else:
		_record(0, "ranked team", c.ranked.play.text == i18n.t("hub.ranked.make_team"),
			"no Elite team: the button says '%s'" % c.ranked.play.text)
	# 3. Ranking search, the ghost offer, cancel
	if pick.item_count >= 1:
		_seen.erase(23104)
		c.ranked.play.pressed.emit()
		await _wait(func(): return lobby._searching, 3.0)
		await create_timer(0.4).timeout
		var mode_ok: bool = lobby._search_mode.text == i18n.t("hub.ranked")
		lobby._search_started -= 21000   # as if the queue stayed empty for 21 s
		await create_timer(0.3).timeout
		await _shot("hub-searching")
		var offer: Button = lobby._ghost_offer
		_record(0, "search", lobby._searching and mode_ok and offer.is_visible_in_tree(),
			"searching '%s', ghost offer after 20 s: %s" % [lobby._search_mode.text, str(offer.is_visible_in_tree())])
		_seen.erase(23106)
		lobby._cancel_search.pressed.emit()
		await _wait(func(): return not lobby._searching, 3.0)
		_record(0, "cancel", not lobby._searching and c.ranked.root.is_visible_in_tree(), "Cancelar → the cards are back")
	# 4. ghosts
	c.ranked.extra.pressed.emit()
	await _wait(func(): return _main._gui.is_open("ghostDialog"), 3.0)
	_record(0, "ghost", _main._gui.is_open("ghostDialog"), "Contra un fantasma → ghostDialog")
	_close_all()
	await create_timer(0.3).timeout
	# 5. menus
	var opened := 0
	for b in lobby._menu_buttons:
		var dialog := str(b.name).trim_prefix("Menu_")
		b.pressed.emit()
		await create_timer(0.4).timeout
		var target: String = "cardBookDialog" if dialog == "coachInventoryDialog" else dialog
		if _main._gui.is_open(target) or _main._gui.is_open(dialog):
			opened += 1
		else:
			print("[audit] menu %s did not open" % dialog)
		_close_all()
		await create_timer(0.2).timeout
	_record(0, "menus", opened == lobby._menu_buttons.size(), "%d of %d menus open their panel" % [opened, lobby._menu_buttons.size()])
	# 6. focus moves by direction, as a pad does
	c.ranked.play.grab_focus()
	await process_frame
	await _press("ui_right")
	var right: Control = root.get_viewport().gui_get_focus_owner()
	c.ranked.play.grab_focus()
	await process_frame
	await _press("ui_down")
	var down: Control = root.get_viewport().gui_get_focus_owner()
	_record(0, "pad", right == c.tourn.play and down != null and down in lobby._menu_buttons,
		"right → %s, down → %s" % [right.name if right != null else "—", down.name if down != null else "—"])
	i18n.set_locale(lang_before)


func _press(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
