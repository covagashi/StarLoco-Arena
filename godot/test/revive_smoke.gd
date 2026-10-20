extends "res://test/world_smoke.gd"

## S18: the fallen fighters in the Team panel, end to end, against a live
## server. The old graveyard is no longer a place or a service: dead and
## retired fighters are a section of the Team panel's evolution tab.
##
##   godot --path godot -s test/revive_smoke.gd [-- --shot-dir=D]
##
## Checks the Services panel no longer lists a graveyard, opens Team from the
## lobby menu, checks the dead/retired fighters sit in the "Fallen" table and
## not among the living, then resurrects one dead (2 → titular) and one
## retired (3 → bench) fighter with the panel's own button, waiting for the
## server's 6006 and the card count to drop. Spends two resurrection cards
## of the `test` coach on every run. With the server stopped, seed
## server/arena.db (card 305 "Resurrection" is 100 %, so the roll can't fail).
## Only evolution fighters (fighters.evolution = 1; on `test`, ids 1 and 15)
## can die; a classic one set to state 2 is sent without a state at all.
## The card row is deleted when its count reaches 0, so insert it again:
##   update fighters set state=2 where id=15;
##   update fighters set state=3 where id=1;
##   insert into coach_cards(coach_id,template_id,quantity,pos) values(1,305,2,0)
## Reuses world_smoke's login and report helpers.

const REVIVE_CARD := 305


func _audit() -> void:
	var city = await _open_city()
	var kinds: Array = []
	if city != null:
		for g in _main._gui.gui.model.get_value("city").get("groups", []):
			kinds.append(int(g.kind))
	_record(10, "services", city != null and not 10 in kinds,
		"no graveyard among %d service kinds" % kinds.size())
	_close_all()
	var panel = await _open_team()
	if panel == null:
		_record(10, "team", false, "Team panel did not open")
		return
	var fallen := _fallen_in_roster()
	var tree: Tree = panel.find_child("Fallen", true, false)
	var rows := _tree_items(tree)
	var living_ok := true
	for t in panel.find_children("*", "Tree", true, false):
		if t != tree:
			for it in _tree_items(t):
				living_ok = living_ok and not int(it.get("state", 0)) in [2, 3]
	_record(10, "fallen", tree != null and rows.size() == fallen.size() and living_ok,
		"%d fallen in the roster, %d in the Fallen table, none among the living" % [
			fallen.size(), rows.size()])
	await _shot("revive-team")
	for st in [2, 3]:
		await _revive(panel, st)


func _revive(panel, st: int) -> void:
	var item := {}
	for it in _tree_items(panel.find_child("Fallen", true, false)):
		if int(it.get("state", 0)) == st:
			item = it
			break
	if item.is_empty():
		_record(10, "revive %d" % st, false, "no fighter in state %d (seed the db)" % st)
		return
	panel.selected = item
	panel.schedule_refresh()
	await create_timer(0.3).timeout
	_record(10, "fits %d" % st, _fits(panel), "detail of a %s fighter, no scroll" % (
		"dead" if st == 2 else "retired"))
	await _shot("revive-detail-%d" % st)
	var b: Button = panel.find_child("Revive", true, false)
	if b == null or b.disabled:
		_record(10, "revive %d" % st, false, "no enabled Resurrect button (%s)" % (
			"no resurrection card owned" if b == null else "disabled"))
		return
	var fid := int(item.get("id", -1))
	var qty := int(State.inventory.get(REVIVE_CARD, 0))
	_seen.clear()
	b.pressed.emit()
	var done: bool = await _wait(func():
		var f = _main._fighter_by_id(fid)
		return f != null and not int(f.get("state", 0)) in [2, 3] \
			and _main._revive_pending.is_empty(), 4.0)
	await create_timer(0.4).timeout
	var f = _main._fighter_by_id(fid)
	var now := int(f.get("state", -1)) if f != null else -1
	var status: Dictionary = _main._gui.gui.model.get_value("evolutionTeam").get("reviveStatus", {})
	var want := 0 if st == 2 else 1
	_record(10, "revive %d" % st, done and now == want and _seen.has(6006)
		and bool(status.get("ok", false)) and int(State.inventory.get(REVIVE_CARD, 0)) <= qty - 1
		and panel.find_child("ReviveStatus", true, false) != null and _fits(panel),
		"%s: state %d → %d, card %d → %d, '%s' in the footer, no scroll" % [item.get("name", "?"), st, now,
			qty, int(State.inventory.get(REVIVE_CARD, 0)), status.get("text", "")])
	await _shot("revive-done-%d" % st)


## Press the lobby's Team menu button on the evolution tab.
func _open_team():
	_close_all()
	_main._gui.gui.model.set_value("gamePreferences", 0, "lastSelectedGameModeId")
	var lobby = _main._lobby_screen
	if lobby == null:
		return null
	for b in lobby._menu_buttons:
		if b.text == root.get_node("I18n").t("nav.team"):
			b.pressed.emit()
			break
	await create_timer(0.5).timeout
	return _main._gui.dialogs.get("teamManagementDialog")


func _fallen_in_roster() -> Array:
	return State.roster.filter(func(f): return int(f.get("type", 2)) == 2 \
		and int(f.get("state", 0)) in [2, 3])


func _tree_items(tree: Tree) -> Array:
	var out: Array = []
	if tree == null or tree.get_root() == null:
		return out
	for it in tree.get_root().get_children():
		var m: Variant = it.get_metadata(0)
		if m is Dictionary:
			out.append(m)
	return out


## The panel's body fits its window: the scroll bar has nothing to scroll.
func _fits(panel) -> bool:
	var found: Array = panel.find_children("*", "ScrollContainer", true, false)
	if found.is_empty():
		return false
	var bar: VScrollBar = found[0].get_v_scroll_bar()
	return bar.max_value - bar.page <= 1.0


## Select a fallen fighter in state `st` on the panel; {} when none.
func _select_fallen(panel, st: int) -> Dictionary:
	for it in _tree_items(panel.find_child("Fallen", true, false)):
		if int(it.get("state", 0)) == st:
			panel.selected = it
			panel.schedule_refresh()
			await create_timer(0.3).timeout
			return it
	return {}
