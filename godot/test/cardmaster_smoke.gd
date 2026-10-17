extends "res://test/world_smoke.gd"

## S18: the native Card Master end to end, against a live server.
##
##   godot --path godot -s test/cardmaster_smoke.gd [-- --shot-dir=D]
##
## Opens the first Card Master from the City panel, checks the native panel
## (not the retail XML), picks the cheapest card, offers inventory cards in
## the barter view until their value covers it, presses "Intercambiar" and
## waits for the server: 5403 OK, the card in the inventory, the result on
## the panel. Spends some of the `test` coach's cards on each run. When the
## catalogue holds a priced card the coach can afford, it also buys one with
## tokens (5450). Reuses world_smoke's login, City and report helpers.
## The `test` coach starts with no tradable cards (islands only): with the
## server stopped, add some to server/arena.db, e.g. Weerdtrot 128-137:
##   insert into coach_cards(coach_id,template_id,quantity,pos) values(1,128,3,0)

# load()ed at run time, not preload()ed: the panel names the I18n autoload,
# which a -s script cannot resolve while it compiles (see native_panels.gd).
var CardMasterPanel: GDScript


func _audit() -> void:
	CardMasterPanel = load("res://src/ui/card_master_panel.gd")
	var city_panel = await _open_city()
	var sid := -1
	if city_panel != null:
		var city: Dictionary = _main._gui.gui.model.get_value("city")
		for g in city.get("groups", []):
			if int(g.kind) == 1 and not g.services.is_empty():
				sid = int(g.services[0].id)
				break
	var b: Button = await _service_button(sid) if sid > 0 else null
	if b == null:
		_record(1, "Card Master", false, "no Card Master in the City panel")
		return
	_seen.clear()
	b.pressed.emit()
	var ok: bool = await _wait(func(): return _seen.has(5401) \
		and _main._gui.is_open("cardMasterDialog"), 3.0)
	var panel = _main._gui.dialogs.get("cardMasterDialog")
	_record(1, "opens", ok and is_instance_of(panel, CardMasterPanel),
		"native panel" if is_instance_of(panel, CardMasterPanel) else "not native: %s" % panel)
	if not is_instance_of(panel, CardMasterPanel):
		return
	await create_timer(0.3).timeout
	var trade: Dictionary = _main._gui.gui.model.get_value("cardMasterTrade")
	var catalog: Array = trade.get("catalog", [])
	_record(1, "catalogue", not catalog.is_empty()
		and panel.find_child("Card%d" % int(catalog[-1].id), true, false) != null,
		"%d cards, set '%s'" % [catalog.size(), trade.get("setName", "")])
	await _shot("cm-catalogue")
	await _buy_tokens(panel, catalog)
	await _barter(panel, catalog)


## Pick the cheapest card by clicking its tile, then barter for it.
func _barter(panel, catalog: Array) -> void:
	var want: Dictionary = {}
	for c in catalog:
		if not c.uniqueOwned and int(c.value) > 0 \
				and (want.is_empty() or int(c.value) < int(want.value)):
			want = c
	if want.is_empty():
		_record(1, "barter", false, "nothing to barter for")
		return
	var wid := int(want.id)
	panel.find_child("Card%d" % wid, true, false).pressed.emit()
	await create_timer(0.3).timeout
	var trade: Dictionary = _main._gui.gui.model.get_value("cardMasterTrade")
	_record(1, "select", int(trade.selectedId) == wid, str(want.name))
	panel.find_child("Barter", true, false).pressed.emit()
	await create_timer(0.3).timeout
	# Offer the cheapest cards that, together, cover the price: the grid is
	# sorted by value, so walk it from the end.
	var offer: Array = trade.get("offer", [])
	# Scrolled down, a click must not throw the grid back to the top.
	panel._grid_scroll.scroll_vertical = 100000
	await create_timer(0.1).timeout
	var low: int = panel._grid_scroll.scroll_vertical
	var guard := 0
	while not bool(_main._gui.gui.model.get_value("cardMasterTrade").canBuyCards) \
			and guard < 40:
		guard += 1
		trade = _main._gui.gui.model.get_value("cardMasterTrade")
		offer = trade.offer
		var pick := -1
		for i in range(offer.size() - 1, -1, -1):
			if int(offer[i].owned) > int(offer[i].staged) and int(offer[i].value) > 0:
				pick = int(offer[i].id)
				break
		if pick < 0:
			break
		var tile: Button = panel.find_child("Offer%d" % pick, true, false)
		if tile == null:
			break
		tile.pressed.emit()
		await create_timer(0.15).timeout
		if guard == 1:
			_record(1, "keeps scroll", low > 0
				and panel._grid_scroll.scroll_vertical == low,
				"%d → %d" % [low, panel._grid_scroll.scroll_vertical])
	trade = _main._gui.gui.model.get_value("cardMasterTrade")
	_record(1, "stage", bool(trade.canBuyCards),
		"offering %d of %d with %d kinds" % [int(trade.offered), int(trade.wanted),
			trade.staged.size()])
	await _shot("cm-barter")
	if not bool(trade.canBuyCards):
		return
	var before := int(State.inventory.get(wid, 0))
	_seen.clear()
	panel.find_child("Trade", true, false).pressed.emit()
	var done: bool = await _wait(func(): return _seen.has(5403) \
		and int(State.inventory.get(wid, 0)) > before, 4.0)
	trade = _main._gui.gui.model.get_value("cardMasterTrade")
	_record(1, "trade", done and bool(trade.statusOk) and trade.staged.is_empty(),
		"5403, %s %d → %d, status '%s'" % [want.name, before,
			int(State.inventory.get(wid, 0)), trade.status])
	await _shot("cm-traded")


## Token purchase (5450), only when a priced card is affordable.
func _buy_tokens(panel, catalog: Array) -> void:
	var item: Dictionary = {}
	for c in catalog:
		if bool(c.canBuyTokens):
			item = c
			break
	if item.is_empty():
		print("[audit] skip token buy: no affordable priced card here")
		return
	var cid := int(item.id)
	panel.find_child("Card%d" % cid, true, false).pressed.emit()
	await create_timer(0.3).timeout
	var before := int(State.inventory.get(cid, 0))
	_seen.clear()
	panel.find_child("Buy", true, false).pressed.emit()
	var done: bool = await _wait(func(): return _seen.has(5403) \
		and int(State.inventory.get(cid, 0)) > before, 4.0)
	_record(1, "buy", done, "%s %d → %d" % [item.name, before,
		int(State.inventory.get(cid, 0))])
