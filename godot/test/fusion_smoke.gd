extends "res://test/world_smoke.gd"

## S18: the native fusion altar end to end, against a live server.
##
##   godot --path godot -s test/fusion_smoke.gd [-- --shot-dir=D]
##
## Opens, from the City panel, the altar with the best quality among those
## whose power covers Ruby Fragments (the cheapest power-side boost card),
## checks the native panel (no retail XML, no debug pane), picks that
## target, puts the coach's two most valuable tradable cards on the altar,
## takes one back and puts it again, reads the recipe the panel shows,
## presses "Fusionar" and waits for the server: 5491 and the inventory
## moved the way the result says (the target gained on success, the
## leftover back and the rest consumed on a failed roll). Spends cards of
## the `test` coach on every run (see cardmaster_smoke.gd for seeding).
## Reuses world_smoke's login, City and report helpers.

# load()ed at run time: the panel names the I18n autoload (see native_panels.gd).
var FusionPanel: GDScript

const TARGET := 943   # Ruby Fragments: power 5, quality 0, value 190


func _audit() -> void:
	FusionPanel = load("res://src/ui/fusion_panel.gd")
	var Cards := load("res://src/gamedata/cards.gd")
	var city_panel = await _open_city()
	# Every altar in the panel, with its lab record; keep the best die
	# among those whose power alone covers the target.
	var sid := -1
	var best := {}
	if city_panel != null:
		var city: Dictionary = _main._gui.gui.model.get_value("city")
		for g in city.get("groups", []):
			if int(g.kind) != 14:
				continue
			for s in g.services:
				var e: Dictionary = _main._element_info(int(s.id))
				var lab: Dictionary = Cards.lab(int(str(e.get("desc", "0"))))
				if int(lab.get("power", 0)) < int(Cards.meta(TARGET).get("fusPower", 0)):
					continue
				if best.is_empty() or int(lab.quality) > int(best.quality):
					best = lab
					sid = int(s.id)
	var b: Button = await _service_button(sid) if sid > 0 else null
	if b == null:
		_record(14, "altar", false, "no usable altar in the City panel")
		return
	_seen.clear()
	b.pressed.emit()
	var ok: bool = await _wait(func(): return _main._gui.is_open("fusionLabDialog"), 3.0)
	var panel = _main._gui.dialogs.get("fusionLabDialog")
	_record(14, "opens", ok and is_instance_of(panel, FusionPanel)
		and not _debug_pane_shown(),
		("native panel, altar power %d quality %d slots %d" % [int(best.power),
			int(best.quality), int(best.slots) - 1]) if is_instance_of(panel, FusionPanel) \
			else "not native: %s" % panel)
	if not is_instance_of(panel, FusionPanel):
		return
	await create_timer(0.3).timeout
	var trade: Dictionary = _main._gui.gui.model.get_value("fusionTrade")
	_record(14, "targets", trade.get("targets", []).size() == 7
		and panel.find_child("Target%d" % TARGET, true, false) != null
		and panel.find_child("Fuse", true, false).disabled,
		"%d boost cards on the strip, Fuse disabled before choosing" % trade.get("targets", []).size())
	await _shot("fus-open")
	await _fuse(panel)


func _fuse(panel) -> void:
	panel.find_child("Target%d" % TARGET, true, false).pressed.emit()
	await create_timer(0.3).timeout
	var trade: Dictionary = _main._gui.gui.model.get_value("fusionTrade")
	_record(14, "target", int(trade.get("targetId", -1)) == TARGET
		and panel.find_child("Power", true, false) != null
		and str(trade.get("reason", "")) == "fus.need_two",
		"%s chosen, recipe shown, reason '%s'" % [_card_name(TARGET), trade.get("reason", "")])
	var fuel: Array = trade.get("fuel", [])
	if fuel.size() < 2:
		_record(14, "give", false, "the test coach has fewer than two tradable cards")
		return
	var a := int(fuel[0].id)
	var b := int(fuel[1].id)
	var before := {a: int(State.inventory.get(a, 0)), b: int(State.inventory.get(b, 0)),
		TARGET: int(State.inventory.get(TARGET, 0))}
	panel.find_child("Fuel%d" % a, true, false).pressed.emit()
	await create_timer(0.2).timeout
	panel.find_child("Fuel%d" % b, true, false).pressed.emit()
	await create_timer(0.2).timeout
	# take one back, then put it again: the list and the grid follow
	panel.find_child("Staged%d" % b, true, false).pressed.emit()
	await create_timer(0.2).timeout
	var after_unstage: int = _main._gui.gui.model.get_value("fusionTrade").inputCount
	panel.find_child("Fuel%d" % b, true, false).pressed.emit()
	await create_timer(0.3).timeout
	trade = _main._gui.gui.model.get_value("fusionTrade")
	var fuse: Button = panel.find_child("Fuse", true, false)
	_record(14, "give", after_unstage == 1 and int(trade.get("inputCount", 0)) == 2
		and bool(trade.get("canFusion", false)) and fuse != null and not fuse.disabled,
		"%s + %s on the altar, power %d/%d, quality %d/%d, chance %d%%" % [
			_card_name(a), _card_name(b), int(trade.power.have), int(trade.power.need),
			int(trade.quality.have), int(trade.quality.need), int(trade.chance)])
	await _shot("fus-ready")
	if fuse == null or fuse.disabled:
		return
	_seen.clear()
	fuse.pressed.emit()
	var answered: bool = await _wait(func(): return _seen.has(5491) and _seen.has(5200) \
		and str(_main._gui.gui.model.get_value("fusionTrade").status) != "", 5.0)
	await create_timer(0.4).timeout
	trade = _main._gui.gui.model.get_value("fusionTrade")
	var got := bool(trade.get("statusOk", false))
	var moved := false
	if got:
		moved = int(State.inventory.get(TARGET, 0)) == before[TARGET] + 1 \
			and int(State.inventory.get(a, 0)) == before[a] - 1 \
			and int(State.inventory.get(b, 0)) == before[b] - 1
	else:
		# failed roll: both consumed, the first one given comes back
		moved = int(State.inventory.get(TARGET, 0)) == before[TARGET] \
			and int(State.inventory.get(a, 0)) == before[a] \
			and int(State.inventory.get(b, 0)) == before[b] - 1
	_record(14, "fuse", answered and moved and int(trade.get("inputCount", 0)) == 0
		and panel.find_child("Status", true, false) != null,
		"5491 %s: '%s'; %s %d→%d, %s %d→%d, %s %d→%d" % [
			"success" if got else "failed roll", trade.get("status", ""),
			_card_name(a), before[a], int(State.inventory.get(a, 0)),
			_card_name(b), before[b], int(State.inventory.get(b, 0)),
			_card_name(TARGET), before[TARGET], int(State.inventory.get(TARGET, 0))])
	await _shot("fus-result")


func _card_name(cid: int) -> String:
	return str(load("res://src/gamedata/cards.gd").name_of(cid))
