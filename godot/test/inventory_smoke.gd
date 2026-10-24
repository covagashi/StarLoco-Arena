extends "res://test/world_smoke.gd"

## S22: the Inventario, filtered by what cards are for, sorted, live. Spanish.
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
	# consumables only
	# coach equipment (test owns some; no consumables)
	var kinds: OptionButton = p.find_child("KindPick", true, false)
	var ci := -1
	for i in kinds.item_count:
		if kinds.get_item_text(i) == i18n.t("inv.kind_coach"):
			ci = i
	kinds.select(ci)
	kinds.item_selected.emit(ci)
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
	kinds = p.find_child("KindPick", true, false)
	kinds.select(0)
	kinds.item_selected.emit(0)
	await create_timer(0.4).timeout
	var sort: OptionButton = p.find_child("SortPick", true, false)
	sort.select(1)
	sort.item_selected.emit(1)
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
	_close_all()
	i18n.set_locale(lang_before)


func _tiles(p) -> Array:
	var grid = p.find_child("CardGrid", true, false)
	return grid.get_children().filter(func(c): return c is Button) if grid != null else []
