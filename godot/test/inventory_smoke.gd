extends "res://test/world_smoke.gd"

## S22: the Inventario, filtered by what cards are for, sorted, live. Spanish.
## S41: a picked card says what it does (its effects, our text) and a set its
## bonuses — when the `test` coach owns card 409 (a two-condition potion),
## card 137 (worn: resurrection bonus) and a card of set 1, those are checked.
## S47: the order is three choices; with card 316 the paper scrolls.
##
##   godot --path godot -s test/inventory_smoke.gd [-- --shot-dir=D]


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await _wait(func(): return _seen.has(5200), 4.0)
	await create_timer(0.4).timeout
	_close_all()
	_main._gui.open("cardBookDialog")
	await create_timer(0.6).timeout
	var p = _main._gui.dialogs.get("cardBookDialog")
	var all := _tiles(p)
	_record(5200, "all", all.size() == State.inventory.size(), "%d tiles, inventory %d" % [all.size(), State.inventory.size()])
	await _shot("inventory-cards")
	# consumables only
	# coach equipment (test owns some; no consumables)
	# S47: what the cards are for is the screen's left list now
	(p.find_child("Kind_coach", true, false) as Button).pressed.emit()
	await create_timer(0.5).timeout
	var cons := _tiles(p)
	var want := 0
	for cid in State.inventory:
		if int(load("res://src/gamedata/cards.gd").meta(int(cid)).get("type", 0)) in range(2, 14):
			want += 1
	_record(5200, "coach gear", cons.size() == want and want > 0, "%d coach-gear tiles (want %d)" % [cons.size(), want])
	if not cons.is_empty():
		cons[0].pressed.emit()
		await create_timer(0.4).timeout
		var use: Label = p.find_child("CardUse", true, false)
		_record(5200, "what for", use != null and use.text == i18n.t("inv.use_coach"), "'%s'" % (use.text.left(50) if use != null else "—"))
		await _shot("inventory-coach")
	# by value, every type (controls are rebuilt on refresh: find them again)
	(p.find_child("Kind_all", true, false) as Button).pressed.emit()
	await create_timer(0.4).timeout
	(p.find_child("Sort_value", true, false) as Button).pressed.emit()   # S47: the order is three choices
	await create_timer(0.5).timeout
	var vals: Array = []
	var cards = load("res://src/gamedata/cards.gd")
	for t in _tiles(p):
		vals.append(cards.value_of(int(str(t.name).trim_prefix("Card"))))
	var sorted_ok := true
	for i in range(1, vals.size()):
		if vals[i] > vals[i - 1]:
			sorted_ok = false
	_record(5200, "by value", sorted_ok and vals.size() > 1, "%d tiles, highest %d first" % [vals.size(), vals[0] if not vals.is_empty() else 0])
	# S41: what a card does, from its effects
	var tile409: Variant = p.find_child("Card409", true, false)
	if tile409 != null:
		tile409.pressed.emit()
		await create_timer(0.4).timeout
		var fx: Label = p.find_child("CardEffects", true, false)
		var txt := fx.text if fx != null else ""
		_record(5200, "card effects", txt.count(" durante 3 combates") == 2, "'%s'" % txt.replace("\n", " / "))
		var nm: Label = p.find_child("CardName", true, false)
		_record(5200, "own name", nm != null and nm.text == "Pócima pegajosa", "'%s'" % (nm.text if nm != null else "—"))
		await _shot("inventory-effects")
	var tile137: Variant = p.find_child("Card137", true, false)
	if tile137 != null:
		tile137.pressed.emit()
		await create_timer(0.4).timeout
		var fx: Label = p.find_child("CardEffects", true, false)
		var txt := fx.text if fx != null else ""
		_record(5200, "worn effects", txt.contains("+25 % a tus cartas de resurrección") and txt.contains("combate de Historia"), "'%s'" % txt.replace("\n", " / "))
		await _shot("inventory-worn")
	# S47: a long sheet scrolls (card 316, four effects): the paper's body can go down
	var tile316: Variant = p.find_child("Card316", true, false)
	if tile316 != null:
		tile316.pressed.emit()
		await create_timer(0.6).timeout
		var bar: VScrollBar = p.sheet_scroll.get_v_scroll_bar()
		_record(5200, "long sheet scrolls", bar.max_value > bar.page + 1.0, "range %d, page %d" % [bar.max_value, bar.page])
		await _shot("inventory-long")
		p.sheet_scroll.scroll_vertical = int(bar.max_value)   # to its foot: the last line whole, no cue
		await create_timer(0.3).timeout
		await _shot("inventory-long-end")
	# S41: a rule card on a class or a spell takes that one's name
	if p.find_child("Card559", true, false) != null:
		_record(5200, "rule card names", cards.name_of(559) == i18n.t("breed.1") \
			and cards.name_of(573) == load("res://src/gamedata/spells.gd").name_of(34),
			"559 '%s', 573 '%s'" % [cards.name_of(559), cards.name_of(573)])
	var set1: Variant = null
	for st in _main._gui.model.get_value("localCoach.cardSets") if _main._gui.model.get_value("localCoach.cardSets") is Array else []:
		if int(st.get("id", 0)) == 1 and int(st.get("completion", 0)) > 0:
			set1 = st
	if set1 != null:
		p.tab = 1
		p.selected = set1
		p.schedule_refresh()
		await create_timer(0.5).timeout
		var sb: Label = p.find_child("SetBonuses", true, false)
		var stxt := sb.text if sb != null else ""
		_record(5200, "set bonuses", stxt.begins_with("Con ") and stxt.contains(" puestas: "), "'%s'" % stxt.replace("\n", " / "))
		await _shot("inventory-set-bonuses")
	# S47: the album: collections started, one picked
	p.tab = 1
	p.selected = {}
	p.schedule_refresh()
	await create_timer(0.8).timeout
	var album = p.find_child("Album", true, false)
	var strips: Array = album.get_children().filter(func(c): return c is Button) if album != null else []
	_record(5200, "album", album != null, "%d collections started" % strips.size())
	# S47: the hint on an empty paper wraps; it used to widen the paper off the screen
	_record(5200, "paper fits", p._paper.size.x <= p.R_SHEET.size.x + 0.5, "paper %d wide" % p._paper.size.x)
	await _shot("inventory-album")
	if not strips.is_empty():
		strips[0].pressed.emit()
		await create_timer(0.6).timeout
		var miss = p.find_child("SetMissing", true, false)
		_record(5200, "album pick", p.sheet_title.text != "", "'%s', missing: %s" % [p.sheet_title.text, miss != null])
		await _shot("inventory-album-pick")
	_close_all()
	i18n.set_locale(lang_before)


func _tiles(p) -> Array:
	var grid = p.find_child("CardGrid", true, false)
	return grid.get_children().filter(func(c): return c is Button) if grid != null else []
