extends "res://test/world_smoke.gd"

## S18: the native conversation window end to end, against a live server.
##
##   godot --path godot -s test/talk_smoke.gd [-- --shot-dir=D]
##
## In Spanish, from the Services panel: Demon I (kind 9) pages through its
## monologue and closes; the SuperBidi challenge (kind 3) lists its
## challenges by name and closes; a demon challenge (kind 7) plays its intro
## once, offers Aceptar / Rechazar, refuses, then offers straight away on
## the second visit, and "Aceptar" launches the fight (26330 → 8000). No
## debug pane opens on the way. Restores the UI language it found.

var TalkPanel: GDScript
var _lang_before := ""


func _audit() -> void:
	TalkPanel = load("res://src/ui/talk_panel.gd")
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.2).timeout
	var city = await _open_city()
	var by_kind := {}
	if city != null:
		for g in _main._gui.gui.model.get_value("city").get("groups", []):
			# by each service's own kind (S22: the Retos group mixes three)
			for sv in g.services:
				var k := int(sv.get("kind", g.kind))
				if not by_kind.has(k):
					by_kind[k] = []
				by_kind[k].append(sv)
	_close_all()
	await _demon1(by_kind.get(9, []))
	await _picker(by_kind.get(3, []))
	await _demon_challenge(by_kind.get(7, []))
	i18n.set_locale(_lang_before)


## Press a Services button; the conversation window (native, no debug pane).
func _talk_open(id: int):
	var b: Button = await _service_button(id)
	if b == null:
		return null
	b.pressed.emit()
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var panel = _main._gui.dialogs.get("npcTalkDialog")
	if not is_instance_of(panel, TalkPanel) or _debug_pane_shown():
		return null
	return panel


func _talk() -> Dictionary:
	var t: Variant = _main._gui.gui.model.get_value("talk")
	return t if t is Dictionary else {}


func _press(panel, kind: String, label := "") -> bool:
	var rows: Array = _talk().get("choices", [])
	for i in rows.size():
		if str(rows[i].kind) == kind and (label == "" or str(rows[i].label) == label):
			var b: Button = panel.find_child("Choice%d" % i, true, false)
			if b == null:
				return false
			b.pressed.emit()
			await create_timer(0.3).timeout
			return true
	return false


func _demon1(services: Array) -> void:
	if services.is_empty():
		_record(9, "Demon I", false, "not in Services")
		return
	var panel = await _talk_open(int(services[0].id))
	if panel == null:
		_record(9, "Demon I", false, "no native conversation window")
		return
	var t := _talk()
	var pages := int(t.get("pages", 0))
	var page_label = panel.find_child("Page", true, false)
	var spoken: String = panel.find_child("Speech", true, false).text
	_record(9, "opens", str(t.get("name", "")) == "Demonio I" and pages >= 2
		and page_label != null and spoken.length() > 20,
		"'%s', %d pages, '%s…'" % [t.get("name", ""), pages, spoken.left(40)])
	await _shot("talk-demon1")
	var walked := 1
	while _main._gui.is_open("npcTalkDialog") and walked <= pages + 1:
		if not await _press(panel, "primary"):
			break
		walked += 1
	_record(9, "pages", not _main._gui.is_open("npcTalkDialog") and walked == pages + 1,
		"Siguiente × %d, then OK closes" % (walked - 2))


func _picker(services: Array) -> void:
	var id := -1
	for s in services:
		var e: Dictionary = _main._element_info(int(s.id))
		if str(e.get("desc", "")).split(";").size() >= 3:
			id = int(s.id)
	var panel = await _talk_open(id) if id > 0 else null
	if panel == null:
		_record(3, "challenge", false, "no native conversation window")
		return
	var fields := str(_main._element_info(id).get("desc", "")).split(";")
	var rows: Array = _talk().get("choices", []).filter(func(c): return str(c.kind) == "challenge")
	var names := rows.map(func(c): return str(c.label))
	_record(3, "challenges", rows.size() == fields.size() - 2
		and not names.any(func(n): return n.begins_with("Challenge ")),
		"'%s': %s" % [_talk().get("name", ""), names])
	await _shot("talk-challenge")
	await _press(panel, "secondary")
	_record(3, "close", not _main._gui.is_open("npcTalkDialog"), "Cerrar closes it")


func _demon_challenge(services: Array) -> void:
	var id := -1
	for s in services:
		var f := str(_main._element_info(int(s.id)).get("desc", "")).split(";")
		if f.size() > 1 and int(f[1]) == 117:
			id = int(s.id)
	var panel = await _talk_open(id) if id > 0 else null
	if panel == null:
		_record(7, "demon challenge", false, "no native conversation window")
		return
	var intro := int(_talk().get("pages", 0))
	_record(7, "intro", intro == 3, "%d-page intro the first time" % intro)
	for _i in intro:
		await _press(panel, "primary")
	var offer: Array = _talk().get("choices", []).map(func(c): return str(c.label))
	_record(7, "offer", int(_talk().get("pages", 0)) == 0 and "Aceptar" in offer and "Rechazar" in offer,
		"then the offer: %s" % [offer])
	await _shot("talk-demon-offer")
	await _press(panel, "secondary", "Rechazar")
	var refused: bool = not _main._gui.is_open("npcTalkDialog")
	panel = await _talk_open(id)
	var again: Array = _talk().get("choices", []).map(func(c): return str(c.label)) if panel != null else []
	_record(7, "second visit", refused and panel != null and int(_talk().get("pages", 0)) == 0
		and "Aceptar" in again, "Rechazar closed it; reopened, the offer comes straight away")
	if panel == null:
		return
	_seen.clear()
	await _press(panel, "primary", "Aceptar")
	var fought: bool = await _wait(func(): return _seen.has(8000), 6.0)
	_record(7, "accept", fought and not _main._gui.is_open("npcTalkDialog"),
		"Aceptar → 26330 → 8000, the fight starts")
