extends "res://test/world_smoke.gd"

## S18: what the tournament totem and the demon totem became, end to end
## against a live server. In Spanish. (S48: rewritten — the totems and the
## firework launcher left Services in S18/S26, and the lobby buttons are
## icons, found by their tooltip.)
##
##   godot --path godot -s test/totems_smoke.gd [-- --shot-dir=D]
##
## 1. Torneos → Calendario: the month's first played (not offline)
##    tournament open to us shows "Inscribirme"; register
##    (4607 → 28608) → "Inscrito", "Ver cuadro" (28649 → 28650) shows the
##    bracket. Torneos → Mis torneos: a tournament the test coach is in, with
##    its search window open, answers "Buscar rival" (28611).
## 2. Social → Clan: a clan with no demon; the leader opens the offering,
##    picks a demon, puts a card, offers (5470 → 5403): the clan now serves
##    it, the card is gone, the demon's clan ladder (27511) is refreshed — it
##    lists only ACTIVE clans (5+ members), so the 1-member test clan shows
##    the "no active clan" line instead.
##
## With the server stopped, seed server/arena.db (test coach = 1, its clan = 2):
##   update tournaments set search_period_start=datetime('now','-1 minute'),
##     search_period_minutes=60 where id=1;
##   update guilds set demon_id=0 where id=2;
##   insert into coach_cards(coach_id,template_id,quantity,pos) values(1,128,1,0)
## and restore afterwards (demon_id=16, the search period to 0, delete the
## guild_demon_reputations row the offering adds) — or play it on a copy:
##   godot/tools/no_retail_smoke.sh <seeded copy>  with SMOKES=totems_smoke

const OFFER_CARD := 128      # Weerdtrot Boots: tradable, value 57

var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.2).timeout
	await _calendar()
	await _clan_demon()
	i18n.set_locale(_lang_before)


func _menu(key: String, dialog: String):
	_close_all()
	# the lobby buttons are icons: their name is the tooltip (S45)
	for b in _main._lobby_screen._menu_buttons:
		if b.tooltip_text == root.get_node("I18n").t(key):
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
	if panel != null:
		panel.tab = 1   # S47: Torneos → Calendario
		panel.schedule_refresh()
	await _wait(func(): return _seen.has(17003) and _seen.has(28602), 3.0)
	await create_timer(0.3).timeout
	var cell := {}
	var ev := {}
	for c in _main._gui.model.get_value("calendar").get("calendar", []):
		for e in c.get("events", []):
			# the first played one we can enter: an offline tournament has no
			# search (S29), a ticketed one wants its entry card
			var enterable: bool = bool(e.get("regOpen", true)) and (int(e.get("entryCard", 0)) == 0
				or int(e.get("entryOwned", 0)) > 0)
			if not bool(e.get("offline", false)) and enterable and ev.is_empty():
				cell = c
				ev = e
	if panel == null or cell.is_empty():
		var seen_evs := []
		for c in _main._gui.model.get_value("calendar").get("calendar", []):
			for e in c.get("events", []):
				seen_evs.append("%s d%s off=%s reg=%s entry=%s/%s" % [e.get("id"), c.get("day"),
					e.get("offline"), e.get("regOpen"), e.get("entryCard"), e.get("entryOwned")])
		_record(13, "calendar", false, "no played tournament open to us: %s" % [seen_evs])
		return
	panel.selected = cell
	panel.schedule_refresh()
	await create_timer(0.3).timeout
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
	var slots: Dictionary = _main._gui.model.get_value("calendar").get("bracket", {}).get("slots", {})
	_record(13, "bracket", _seen.has(28650) and (drawn is HBoxContainer or empty != null),
		"28649 → 28650: %d seat(s) %s" % [slots.size(), slots.values()])
	await _shot("cal-bracket")
	await _search()


## Buscar rival from Torneos → Mis torneos: the first enabled one among the
## tournaments the test coach is in (the seed opens tournament 1's window;
## on 2026-11-19 it was 2600003's, open by its own schedule). Not the
## calendar's: registration closes once a search window opens.
func _search() -> void:
	var panel = await _menu("nav.calendar", "calendarDialog")
	if panel == null:
		_record(13, "search", false, "Torneos did not open")
		return
	panel.tab = 0
	panel.schedule_refresh()
	await create_timer(0.5).timeout
	var search: Button = null
	for b in panel.find_children("Search*", "Button", true, false):
		if not b.disabled:
			search = b
			break
	if search == null:
		_record(13, "search", false, "no Buscar rival in Mis torneos (is tournament 1's search seeded open?)")
		return
	var tid := int(str(search.name).trim_prefix("Search"))
	_seen.clear()
	search.pressed.emit()
	await _wait(func(): return _seen.has(28612) or _seen.has(28616), 3.0)
	await create_timer(0.4).timeout
	_record(13, "search", _seen.has(28612) or _seen.has(28616),
		"%d: 28611 → %s" % [tid, "28612" if _seen.has(28612) else ("28616" if _seen.has(28616) else "nothing")])
	await _shot("tourn-search")


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
	var d: Dictionary = _main._gui.model.get_value("demonNative")
	var clans: Array = d.get("ladder", []).map(func(r): return str(r.name))
	var guild := str(State.guild.get("guild", ""))
	_record(11, "offer", _seen.has(5403) and bool(d.get("status", {}).get("ok", false))
		and int(State.guild.get("demon_id", 0)) == demon and int(State.inventory.get(OFFER_CARD, 0)) == qty - 1
		and _seen.has(27511) and (guild in clans or dp.find_child("LadderEmpty", true, false) != null),
		"5470 → 5403 '%s'; clan serves %s; card %d → %d; ladder %s" % [d.get("status", {}).get("text", ""),
			d.get("demonName", ""), qty, int(State.inventory.get(OFFER_CARD, 0)), clans])
	await _shot("demon-done")
