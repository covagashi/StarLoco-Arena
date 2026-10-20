extends "res://test/revive_smoke.gd"

## S18: the two resurrection outcomes revive_smoke.gd cannot reach, live.
##
##   godot --path godot -s test/revive_edge_smoke.gd [-- --shot-dir=D]
##
## 1. A failed roll. Every resurrection card is 100 %, but the server takes
##    any card whose effect resurrects (an equipment card's "% to come back
##    during a fight" too) and spends it. The Weerdtrot Jacket (137) gives
##    1 %, so the smoke sends 22099 with it through main's own revive call
##    (the panel never offers it) and expects: the card spent, no 6006, the
##    fighter still dead, "the roll failed" in the footer. 1 run in 100 rolls
##    the 1 %: reseed and run again.
## 2. A full bench (7): a retired fighter's Resurrect button is disabled with
##    the reason; forced anyway, the server refuses without spending the card
##    and the footer says so.
##
## With the server stopped, seed server/arena.db (ids are the `test` coach's;
## 4-10 are classic fighters, which the server counts on the bench like any
## other — restore them to 0 afterwards, and 1 → 1, 15 → 0):
##   update fighters set state=2 where id=1;
##   update fighters set state=3 where id=15;
##   update fighters set state=1 where id between 4 and 10;
##   insert into coach_cards(coach_id,template_id,quantity,pos) values(1,137,3,0),(1,305,1,0)

const LUCKLESS := 137


func _audit() -> void:
	var panel = await _open_team()
	if panel == null:
		_record(10, "team", false, "Team panel did not open")
		return
	await _failed_roll(panel)
	await _bench_full(panel)


func _failed_roll(panel) -> void:
	var item: Dictionary = await _select_fallen(panel, 2)
	if item.is_empty():
		_record(10, "failed roll", false, "no dead fighter (seed the db)")
		return
	var offered: Array = _main._gui.gui.model.get_value("evolutionTeam").get("reviveCards", [])
	_record(10, "offered", offered.all(func(c): return int(c.id) != LUCKLESS),
		"the panel offers %s, not the equipment card" % [offered.map(func(c): return c.name)])
	var fid := int(item.id)
	var qty := int(State.inventory.get(LUCKLESS, 0))
	if qty <= 0:
		_record(10, "failed roll", false, "no Weerdtrot Jacket owned (seed the db)")
		return
	_seen.clear()
	_main._revive_fighter(fid, LUCKLESS)
	await _wait(func(): return _main._revive_pending.is_empty(), 4.0)
	await create_timer(0.4).timeout
	var f = _main._fighter_by_id(fid)
	var st := int(f.get("state", -1)) if f != null else -1
	if st != 2:
		_record(10, "failed roll", false, "the 1 %% roll succeeded (state %d): reseed and run again" % st)
		return
	var status: Dictionary = _main._gui.gui.model.get_value("evolutionTeam").get("reviveStatus", {})
	var want: String = root.get_node("I18n").t("team.revive_fail",
		{"card": _card_name(LUCKLESS), "name": item.get("name", "?")})
	var footer: Label = panel.find_child("ReviveStatus", true, false)
	_record(10, "failed roll", not bool(status.get("ok", true)) and str(status.get("text", "")) == want
		and not _seen.has(6006) and int(State.inventory.get(LUCKLESS, 0)) == qty - 1
		and footer != null and footer.text == want and _fits(panel),
		"state stays 2, card %d → %d, no 6006, footer '%s'" % [qty,
			int(State.inventory.get(LUCKLESS, 0)), footer.text if footer != null else "—"])
	await _shot("revive-failed")


func _bench_full(panel) -> void:
	var item: Dictionary = await _select_fallen(panel, 3)
	if item.is_empty():
		_record(10, "bench full", false, "no retired fighter (seed the db)")
		return
	var bench := State.roster.filter(func(f): return int(f.get("state", 0)) == 1).size()
	var b: Button = panel.find_child("Revive", true, false)
	_record(10, "bench full", bench >= 7 and b != null and b.disabled
		and panel.find_child("BenchFull", true, false) != null and _fits(panel),
		"%d on the bench, Resurrect disabled with the reason" % bench)
	await _shot("revive-bench-full")
	var fid := int(item.id)
	var qty := int(State.inventory.get(REVIVE_CARD, 0))
	if qty <= 0:
		_record(10, "refused", false, "no resurrection card owned (seed the db)")
		return
	_seen.clear()
	_main._revive_fighter(fid, REVIVE_CARD)
	await _wait(func(): return _main._revive_pending.is_empty(), 4.0)
	await create_timer(0.4).timeout
	var f = _main._fighter_by_id(fid)
	var status: Dictionary = _main._gui.gui.model.get_value("evolutionTeam").get("reviveStatus", {})
	var want: String = root.get_node("I18n").t("team.revive_refused", {"name": item.get("name", "?")})
	_record(10, "refused", f != null and int(f.get("state", -1)) == 3
		and str(status.get("text", "")) == want and int(State.inventory.get(REVIVE_CARD, 0)) == qty,
		"forced anyway: state stays 3, card %d → %d, '%s'" % [qty,
			int(State.inventory.get(REVIVE_CARD, 0)), status.get("text", "")])


func _card_name(cid: int) -> String:
	return str(load("res://src/gamedata/cards.gd").name_of(cid))
