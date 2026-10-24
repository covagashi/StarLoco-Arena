extends "res://test/totems_smoke.gd"

## S10: the tutorial a brand-new account meets, in the Godot client, against a
## live server. In Spanish. Run with a login nobody has used (auto-register):
##
##   godot --path godot -s test/tutorial_smoke.gd -- --as=novatoNNN [--shot-dir=D]
##
## 1. Adamai's intro (scenarios 0 + 1) on the very first lobby entry.
## 2. "Entrenamiento" with no fighters points at recruiting instead.
## 3. Ayuda → "Primeros pasos": the next step is achievement 275.
## 4. Servicios → "Aprendizaje": Nilo (retail's Baan), the twelve class masters
##    (our names, npc_rename.gd), Demon III.
## 5. A class master's "Reclutar un guerrero" opens the creation with its class.
## 6. Baan's "I'm new" (219), then Demon III (210): after three recruits
##    only challenge 29 is offered.
## 7. An achievement that opens a scenario (280 → 105) plays its monologue.
## 8. Baan's lesson (200 + 201) plays before his fight, which then starts.
## The fights themselves are the Go e2e TestTutorialChainOverTheWire.

const DEMON3 := 54
const BAAN := 143


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await _intro()
	await _practice_guard()
	await _first_steps()
	await _learning()
	await _recruit()
	await _baan_hello()
	await _demon3()
	await _achievement_scenario()
	await _baan()
	i18n.set_locale(_lang_before)


func _talk() -> Dictionary:
	var t = _main._gui.gui.model.get_value("talk")
	return t if t is Dictionary else {}


## Press the first choice until the monologue closes; returns the pages seen.
func _read_through(limit := 30) -> int:
	var n := 0
	while _main._gui.is_open("npcTalkDialog") and n < limit:
		_main._talk_choice(0)
		n += 1
		await create_timer(0.1).timeout
	return n


func _intro() -> void:
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 5.0)
	var t := _talk()
	_record(10, "intro", str(t.get("name", "")) == root.get_node("I18n").t("talk.adamai")
		and int(t.get("pages", 0)) == 8,
		"%s: '%s…' (%d pages)" % [t.get("name", "—"), str(t.get("text", "")).left(50), int(t.get("pages", 0))])
	await _shot("intro")
	var pages := await _read_through()
	_record(10, "intro read", pages == 12 and not _main._gui.is_open("npcTalkDialog"),
		"%d pages (scenario 0 then 1)" % pages)


func _practice_guard() -> void:
	_seen.clear()
	_main._on_practice_pressed()
	await create_timer(1.5).timeout
	_record(10, "practice guard", not _seen.has(8000) and State.roster.is_empty(),
		"no fighters → no fight, recruit hint")


func _first_steps() -> void:
	_close_all()
	_main._gui.open("tooltipDialog")
	await create_timer(0.6).timeout
	var p = _main._gui.dialogs.get("tooltipDialog")
	var step = p.find_child("Step275", true, false) if p != null else null
	_record(10, "first steps", step != null and str(step.text).begins_with("▶"),
		"'%s'" % (step.text if step != null else "—"))
	await _shot("first-steps")
	_close_all()


func _learning() -> void:
	var city = await _open_city()
	var group := {}
	for g in _main._gui.gui.model.get_value("city").get("groups", []):
		if int(g.kind) == 100:
			group = g
	var labels: Array = group.get("services", []).map(func(s): return s.label)
	_record(10, "learning", labels.size() == 14, "%d: %s" % [labels.size(), labels])
	await _shot("learning")
	_close_all()


func _master_id() -> int:
	for g in _main._gui.gui.model.get_value("city").get("groups", []):
		if int(g.kind) == 100:
			for s in g.services:
				if _main._element_info(int(s.id)).kind == 5:
					return int(s.id)
	return -1


func _recruit() -> void:
	var id := _master_id()
	_main._use_element(id)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var choices: Array = _talk().get("choices", [])
	var idx := -1
	for i in choices.size():
		if str(choices[i].label) == root.get_node("I18n").t("talk.recruit"):
			idx = i
	var breed := int(_main._desc_fields(_main._element_info(id).desc)[3])
	await _shot("master")
	if idx < 0:
		_record(10, "recruit", false, "no 'Reclutar' among %s" % [choices])
		return
	_main._talk_choice(idx)
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 3.0)
	await create_timer(0.3).timeout
	var ef = _main._gui.gui.model.get_value("teamManagement", "editableFighter")
	_record(10, "recruit", _main._gui.is_open("fighterCreationDialog") and int(ef.get("breedId", 0)) == breed,
		"creation opens with class %d" % breed)
	await _shot("recruit")
	_close_all()


## Baan's first line, "Soy nuevo…", reports criterion 219: half of 275.
func _baan_hello() -> void:
	_main._use_element(BAAN)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var first := str(_talk().get("choices", [{}])[0].get("label", ""))
	await _shot("baan")
	_main._talk_choice(0)
	await create_timer(0.4).timeout
	_record(10, "baan hello", int(State.criteria.get(219, 0)) == 1,
		"'%s…' → criterion 219" % first.left(40))
	_main._talk_close()


func _demon3() -> void:
	# three recruits over the wire (achievement 276)
	for name in ["Uno", "Dos", "Tres"]:
		var w := WireWriter.new()
		var blob := WireWriter.new()
		blob.put_u8(1); blob.put_u16(0); blob.put_u8(1)
		blob.put_str(name, "u8")
		blob.put_u8(0); blob.put_u8(255); blob.put_u8(1); blob.put_u8(2); blob.put_u8(1)
		blob.put_u16(0); blob.put_u16(0)
		w.put_u8(0); w.put_u16(0); w.put_u16(blob.raw().size()); w.put_bytes(blob.raw())
		_sess.send(6001, w.raw(), 2)
		await create_timer(0.4).timeout
	# first talk: the introduction (criterion 210, achievement 275)
	_main._use_element(DEMON3)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await _read_through()
	await create_timer(1.0).timeout
	_main._use_element(DEMON3)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var offers: Array = []
	for c in _talk().get("choices", []):
		if str(c.kind) == "challenge":
			offers.append(str(c.label))
	_record(10, "demon III order", offers.size() == 1,
		"offers %s (30 and 31 locked); text '%s…', criteria 210=%s 211=%s, 275=%s 276=%s" % [offers,
			str(_talk().get("text", "")).left(40), State.criteria.get(210), State.criteria.get(211),
			_main._ach_done(275), _main._ach_done(276)])
	await _shot("demon3")
	_main._talk_close()


func _achievement_scenario() -> void:
	var w := WireWriter.new()
	w.put_i16(280)
	var raw := w.raw()
	_main._on_message(22000, raw)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var t := _talk()
	_record(10, "achievement scenario", int(t.get("pages", 0)) == 2,
		"280 → scenario 105: '%s…'" % str(t.get("text", "")).left(50))
	await _shot("scenario-105")
	await _read_through()


func _baan() -> void:
	_seen.clear()
	_main._launch_challenge(46, 9)
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.3).timeout
	var t := _talk()
	var ok_lesson := str(t.get("name", "")) == "Nilo" and int(t.get("pages", 0)) == 10
	await _shot("baan-lesson")
	await _read_through()
	await _wait(func(): return _seen.has(8000), 5.0)
	_record(10, "baan", ok_lesson and _seen.has(8000),
		"lesson %s (10 pages), then the fight (8000 %s)" % [ok_lesson, _seen.has(8000)])
