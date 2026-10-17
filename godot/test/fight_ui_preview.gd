extends Node2D

## Fight HUD preview (visual lane): a 4-vs-4 mid-fight on map 10 — damage,
## buffs, a summon, a dead and an invisible fighter, our fighter acting —
## so the S17 cards, medallion, banner and spell row can be judged at each
## resolution. Then the result modal and its focus round-trip.
##
## ARENA_ART_STYLE=onebit renders the 1-bit style; FIGHT_UI_SHOT overrides
## the capture path (default /tmp/fight-ui.png). For the S17 option sheets:
## ARENA_HUD_LIFE=ring, FIGHT_UI_CHAT=open, FIGHT_UI_CROWD=<n> (n extra
## summons per team, to load the columns), FIGHT_UI_HOVER=<fid> (pointer on
## that fighter's card), FIGHT_UI_SPECTATE=1 (watching, not playing),
## FIGHT_UI_PLACEMENT=1 (the placement phase instead of turn 7),
## FIGHT_UI_MAP=<arena> (default 10).

const State := preload("res://src/state.gd")

const FIGHTERS := [
	# id, name, coach, team, breed, sex, spells
	[1, "Arel", 7, 0, 8, 0, [4, 5, 6, 7, 8, 9]],
	[2, "Brune", 8, 1, 11, 1, []],
	[3, "Cael", 7, 0, 3, 1, []],
	[4, "Dorna", 8, 1, 5, 0, []],
	[5, "Eris", 7, 0, 12, 1, []],
	[6, "Faro", 8, 1, 2, 0, []],
	[8, "Hugo", 8, 1, 7, 0, []],
]


func _ready() -> void:
	State.fight_world = 10 if OS.get_environment("FIGHT_UI_MAP") == "" \
		else int(OS.get_environment("FIGHT_UI_MAP"))
	State.my_coach_id = 7
	State.fighters = {}
	var timeline := []
	for r in FIGHTERS:
		State.fighters[r[0]] = {"id": r[0], "name": r[1], "coach": r[2],
			"team": r[3], "breed": r[4], "sex": r[5], "spells": r[6], "cards": []}
		timeline.append(r[0])
	# a summon of Cael's, right after its caster (insertSummonIntoTimeline)
	State.fighters[7] = {"id": 7, "name": "Bouftou", "coach": 7, "team": 0,
		"look": 8002, "summon": true, "hp": 30, "spells": [], "cards": []}
	timeline.insert(timeline.find(3) + 1, 7)
	var crowd := int(OS.get_environment("FIGHT_UI_CROWD"))
	for i in crowd * 2:
		var id := 100 + i
		var caster := 5 if i % 2 == 0 else 8
		State.fighters[id] = {"id": id, "name": "Invo %d" % (i + 1),
			"coach": 7 if i % 2 == 0 else 8, "team": i % 2,
			"look": [8001, 8004, 8006, 8007, 8010][i % 5], "summon": true,
			"hp": 20, "spells": [], "cards": []}
		timeline.insert(timeline.find(caster) + 1, id)
	State.fight_data = {"timeline": timeline, "ca": 30000}
	State.spectating = OS.get_environment("FIGHT_UI_SPECTATE") == "1"
	var fight := preload("res://src/fight/fight_view.tscn").instantiate()
	add_child(fight)
	_stage(fight)
	fight._table_turn = 7
	fight._on_turn_begin(1)
	if OS.get_environment("FIGHT_UI_PLACEMENT") == "1":
		fight._placement = true
		fight._current_fid = -1
		fight._selected = 1
		fight._refresh_timeline()
		fight.queue_redraw()
	if OS.get_environment("FIGHT_UI_HOVER") != "":
		fight._on_card_hover(int(OS.get_environment("FIGHT_UI_HOVER")), true)
	if OS.get_environment("FIGHT_UI_CHAT") == "open":
		fight._set_chat_open(true)
		fight._fight_log("Brune lanza el hechizo Ataque nuboso.")
		fight._fight_log("Arel ha sido placado.")
	await get_tree().create_timer(1.0).timeout
	if not State.spectating and \
			get_viewport().gui_get_focus_owner() != fight.get_node("UI/PassBtn"):
		push_error("Combat actions have no initial keyboard focus")
		get_tree().quit(1)
		return
	if fight._fight_hud.cards.size() != timeline.size():
		push_error("HUD: %d cards for %d fighters" % [
			fight._fight_hud.cards.size(), timeline.size()])
		get_tree().quit(1)
		return
	for spr in fight._sprites.values():
		if spr.get_node_or_null("HP") != null or spr.get_node_or_null("Buffs") != null:
			push_error("HUD: life or buffs still float over a fighter")
			get_tree().quit(1)
			return
	# No renderer under --headless — skip the screenshot (same hang this
	# guards against in ui_review_preview.gd's _shot()) so the focus
	# assertions still run windowless.
	var shot := OS.get_environment("FIGHT_UI_SHOT")
	if shot.is_empty():
		shot = "/tmp/fight-ui.png"
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
	State.fight_result = {"win_str": {7: "Arel"}, "won_cards": [1], "lost_cards": []}
	fight._show_fight_result()
	await get_tree().process_frame
	if not fight._result_modal.is_ancestor_of(get_viewport().gui_get_focus_owner()):
		push_error("Result did not capture keyboard focus")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			shot.get_basename() + "-result.png" if shot != "/tmp/fight-ui.png"
			else "/tmp/fight-result-ui.png")
	fight._close_fight_result()
	await get_tree().process_frame
	if not State.spectating and \
			get_viewport().gui_get_focus_owner() != fight.get_node("UI/PassBtn"):
		push_error("Result did not restore keyboard focus")
		get_tree().quit(1)
		return
	get_tree().quit()


## Fighters on the map's own spawn cells, then the mid-fight state the HUD
## has to show: damage, buffs, one dead, one invisible.
func _stage(fight: Node) -> void:
	var slots := {0: fight._fmd.get("team0", []), 1: fight._fmd.get("team1", [])}
	var used := {0: 0, 1: 0}
	for fid in State.fight_data.timeline:
		var f: Dictionary = State.fighters[fid]
		var t := int(f.team)
		var cells: Array = slots[t]
		if cells.is_empty():
			continue
		var c: Dictionary = cells[used[t] % cells.size()]
		used[t] += 1
		fight._place_actor({"id": fid, "x": int(c.x), "y": int(c.y),
			"z": int(c.z), "dir": 1 if t == 0 else 5})
	fight._hp_lost[1] = 23
	fight._hp_lost[2] = 61
	fight._hp_lost[4] = 12
	fight._hp_lost[7] = 9
	fight._attach_buff(1, 15, 9001, 2, 2, false)     # +2 AP for 2 turns
	fight._attach_buff(1, 65, 9002, 0, 1, false)     # rooted
	fight._attach_buff(2, 57, 9003, 0, 0, true)      # invisible
	fight._attach_buff(4, 16, 9004, 1, 3, false)     # -1 AP
	fight._attach_buff(4, 126, 9005, 0, 2, false)    # drunk
	fight._attach_buff(4, 19, 9006, 1, 1, false)     # +1 MP
	fight._attach_buff(4, 20, 9007, 1, 1, false)     # -1 MP (4th chip → "+2")
	var spr = fight._sprites.get(2)
	if spr != null:
		spr.modulate.a = 0.0                           # unseen enemy
	fight._kill_actor(6)
	fight._refresh_timeline()
