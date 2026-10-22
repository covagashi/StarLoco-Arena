extends "res://test/world_smoke.gd"

## S18: what the tournament totem, the demon totem and the firework launcher
## became, end to end against a live server. In Spanish.
##
##   godot --path godot -s test/totems_smoke.gd [-- --shot-dir=D]
##
## 1. Services lists no totem (kinds 11, 13) but still the fireworks (12).
## 2. Calendar: a tournament day shows "Inscribirme"; register (4607 → 28608)
##    → "Inscrito", "Ver cuadro" (28649 → 28650) shows the bracket, and with
##    the search window open "Buscar rival" (28611) answers in the detail.
## 3. Social → Clan: a clan with no demon; the leader opens the offering,
##    picks a demon, puts a card, offers (5470 → 5403): the clan now serves
##    it, the card is gone, the demon's clan ladder (27511) is refreshed — it
##    lists only ACTIVE clans (5+ members), so the 1-member test clan shows
##    the "no active clan" line instead.
## 4. Fireworks: two in the launcher, "Lanzar" → two 22094 → two fireworks
##    on the lobby sky.
##
## With the server stopped, seed server/arena.db (test coach = 1, its clan = 2):
##   update tournaments set search_period_start=datetime('now','-1 minute'),
##     search_period_minutes=60 where id=1;
##   update guilds set demon_id=0 where id=2;
##   insert into coach_cards(coach_id,template_id,quantity,pos) values(1,128,1,0),(1,515,2,0)
## and restore afterwards (demon_id=16, the search period to 0, delete the
## guild_demon_reputations row the offering adds, the leftover 515s).

const OFFER_CARD := 128      # Weerdtrot Boots: tradable, value 57
const FIREWORK := 515        # Yellow Fairywork (a rocket)

var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.2).timeout
	await _services()
	await _calendar()
	await _clan_demon()
	await _fireworks()
	i18n.set_locale(_lang_before)


func _services() -> void:
	var city = await _open_city()
	var kinds: Array = []
	if city != null:
		for g in _main._gui.gui.model.get_value("city").get("groups", []):
			kinds.append(int(g.kind))
	_record(13, "services", city != null and not 11 in kinds and not 13 in kinds and 12 in kinds,
		"no totems among %s, fireworks still there" % [kinds])
	_close_all()


func _menu(key: String, dialog: String):
	_close_all()
	for b in _main._lobby_screen._menu_buttons:
		if b.text == root.get_node("I18n").t(key):
			b.pressed.emit()
	await _wait(func(): return _main._gui.is_open(dialog), 3.0)
	await create_timer(0.5).timeout
	return _main._gui.dialogs.get(dialog)


func _confirm(panel) -> bool:
	for c in panel.get_children():
		if c is ConfirmationDialog:
			c.confirmed.emit()
			return true
	return false


func _calendar() -> void:
	var panel = await _menu("nav.calendar", "calendarDialog")
	await _wait(func(): return _seen.has(17003) and _seen.has(28602), 3.0)
	await create_timer(0.3).timeout
	var cell := {}
	for c in _main._gui.gui.model.get_value("calendar").get("calendar", []):
		if not c.get("events", []).is_empty():
			cell = c
			break
	if panel == null or cell.is_empty():
		_record(13, "calendar", false, "no tournament on this month's calendar")
		return
	panel.selected = cell
	panel.schedule_refresh()
	await create_timer(0.3).timeout
	var ev: Dictionary = cell.events[0]
	var tid := int(ev.id)
	var reg: Button = panel.find_child("Register%d" % tid, true, false)
	_record(13, "tournament", reg != null and not reg.disabled,
		"day %s: '%s' with Inscribirme" % [cell.day, ev.title])
	await _shot("cal-tournament")
	if reg == null:
		return
	_seen.clear()
	reg.pressed.emit()
	await create_timer(0.2).timeout
	_confirm(panel)
	await _wait(func(): return _seen.has(28608), 3.0)
	await create_timer(0.4).timeout
	var status = panel.find_child("TournStatus%d" % tid, true, false)
	var bracket_btn: Button = panel.find_child("Bracket%d" % tid, true, false)
	_record(13, "register", _seen.has(28608) and status != null and bracket_btn != null,
		"4607 → 28608, '%s', Ver cuadro shown" % (status.text if status != null else "—"))
	if bracket_btn == null:
		return
	_seen.clear()
	bracket_btn.pressed.emit()
	await _wait(func(): return _seen.has(28650), 3.0)
	await create_timer(0.4).timeout
	var drawn = panel.find_child("Draw%d" % tid, true, false)
	var empty = panel.find_child("BracketEmpty%d" % tid, true, false)
	var slots: Dictionary = _main._gui.gui.model.get_value("calendar").get("bracket", {}).get("slots", {})
	_record(13, "bracket", _seen.has(28650) and (drawn is HBoxContainer or empty != null),
		"28649 → 28650: %d seat(s) %s" % [slots.size(), slots.values()])
	await _shot("cal-bracket")
	var search: Button = panel.find_child("Search%d" % tid, true, false)
	if search == null:
		_record(13, "search", false, "no Buscar rival (is the search window seeded open?)")
		return
	_seen.clear()
	search.pressed.emit()
	await _wait(func(): return _seen.has(28612) or _seen.has(28616), 3.0)
	await create_timer(0.4).timeout
	var st = panel.find_child("TournStatus%d" % tid, true, false)
	_record(13, "search", (_seen.has(28612) or _seen.has(28616)) and st != null,
		"28611 → %s, '%s'" % ["28612" if _seen.has(28612) else "28616", st.text if st != null else "—"])


func _clan_demon() -> void:
	var panel = await _menu("nav.social", "socialDialog")
	if panel == null:
		_record(11, "clan", false, "Social did not open")
		return
	panel.tab = 2
	panel.schedule_refresh()
	await create_timer(0.4).timeout
	var line = panel.find_child("ClanDemon", true, false)
	var open_btn: Button = panel.find_child("DemonOffer", true, false)
	_record(11, "clan tab", line != null and open_btn != null,
		"'%s' + Ofrecer cartas al demonio" % (line.text if line != null else "—"))
	await _shot("clan-demon")
	if open_btn == null:
		return
	open_btn.pressed.emit()
	await _wait(func(): return _main._gui.is_open("demonAffiliationDialog"), 3.0)
	await create_timer(0.5).timeout
	var dp = _main._gui.dialogs.get("demonAffiliationDialog")
	var pick: OptionButton = dp.find_child("DemonPick", true, false) if dp != null else null
	_record(11, "offering", dp != null and pick != null and pick.item_count >= 20,
		"native panel, %d demons to choose" % (pick.item_count if pick != null else 0))
	if pick == null:
		return
	pick.select(3)
	pick.item_selected.emit(3)
	await create_timer(0.4).timeout
	var demon := int(_main._demon_id)
	dp.draft["add"] = OFFER_CARD
	dp.schedule_refresh()
	await create_timer(0.3).timeout
	var add: Button = dp.find_child("Add", true, false)
	if add == null or add.disabled:
		_record(11, "offer", false, "no Weerdtrot Boots to offer (seed the db)")
		return
	add.pressed.emit()
	await create_timer(0.4).timeout
	var qty := int(State.inventory.get(OFFER_CARD, 0))
	var offer: Button = dp.find_child("Offer", true, false)
	await _shot("demon-offer")
	_seen.clear()
	offer.pressed.emit()
	await create_timer(0.2).timeout
	_confirm(dp)
	await _wait(func(): return _seen.has(5403), 3.0)
	await _wait(func(): return _seen.has(27511), 2.0)
	await create_timer(0.5).timeout
	var d: Dictionary = _main._gui.gui.model.get_value("demonNative")
	var clans: Array = d.get("ladder", []).map(func(r): return str(r.name))
	var guild := str(State.guild.get("guild", ""))
	_record(11, "offer", _seen.has(5403) and bool(d.get("status", {}).get("ok", false))
		and int(State.guild.get("demon_id", 0)) == demon and int(State.inventory.get(OFFER_CARD, 0)) == qty - 1
		and _seen.has(27511) and (guild in clans or dp.find_child("LadderEmpty", true, false) != null),
		"5470 → 5403 '%s'; clan serves %s; card %d → %d; ladder %s" % [d.get("status", {}).get("text", ""),
			d.get("demonName", ""), qty, int(State.inventory.get(OFFER_CARD, 0)), clans])
	await _shot("demon-done")


func _fireworks() -> void:
	var city = await _open_city()
	var sid := -1
	if city != null:
		for g in _main._gui.gui.model.get_value("city").get("groups", []):
			if int(g.kind) == 12:
				sid = int(g.services[0].id)
	var b: Button = await _service_button(sid) if sid > 0 else null
	if b == null:
		_record(12, "fireworks", false, "no launcher in Services")
		return
	b.pressed.emit()
	await _wait(func(): return _main._gui.is_open("fireworkDialog"), 3.0)
	await create_timer(0.4).timeout
	var fp = _main._gui.dialogs.get("fireworkDialog")
	var add: Button = fp.find_child("Add%d" % FIREWORK, true, false) if fp != null else null
	if add == null or add.disabled:
		_record(12, "launcher", false, "no Yellow Fairywork to launch (seed the db)")
		return
	add.pressed.emit()
	await create_timer(0.3).timeout
	add = fp.find_child("Add%d" % FIREWORK, true, false)
	add.pressed.emit()
	await create_timer(0.3).timeout
	var slots: Array = _main._gui.gui.model.get_value("fireworkNative").get("slots", [])
	_record(12, "launcher", slots.size() == 2, "native launcher, %d in the show" % slots.size())
	await _shot("fw-launcher")
	var shown_before := int(_main._fw_shown)
	_seen.clear()
	fp.find_child("Launch", true, false).pressed.emit()
	await create_timer(0.9).timeout
	await _shot("fw-sky")
	await _wait(func(): return int(_main._fw_shown) - shown_before >= 2, 4.0)
	_record(12, "show", not _main._gui.is_open("fireworkDialog")
		and int(_main._fw_shown) - shown_before == 2,
		"Lanzar → %d × 22094 on the lobby sky" % (int(_main._fw_shown) - shown_before))
