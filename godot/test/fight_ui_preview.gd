extends Node2D

const State := preload("res://src/state.gd")

func _ready() -> void:
	State.fight_world = 10
	State.my_coach_id = 7
	State.fighters = {
		1: {"id": 1, "name": "Arel", "coach": 7, "team": 0,
			"breed": 8, "spells": [31, 32, 33], "cards": []},
		2: {"id": 2, "name": "Brune", "coach": 8, "team": 1,
			"breed": 11, "spells": [], "cards": []},
	}
	State.fight_data = {"timeline": [1, 2], "ca": 30000}
	var fight := preload("res://src/fight/fight_view.tscn").instantiate()
	add_child(fight)
	fight._on_turn_begin(1)
	await get_tree().create_timer(1.0).timeout
	if get_viewport().gui_get_focus_owner() != fight.get_node("UI/TopBar/EndTurnBtn"):
		push_error("Combat actions have no initial keyboard focus")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/fight-ui.png")
	State.fight_result = {"win_str": {7: "Arel"}, "won_cards": [1], "lost_cards": []}
	fight._show_fight_result()
	await get_tree().process_frame
	if not fight._result_modal.is_ancestor_of(get_viewport().gui_get_focus_owner()):
		push_error("Result did not capture keyboard focus")
		get_tree().quit(1)
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/private/tmp/fight-result-ui.png")
	fight._close_fight_result()
	await get_tree().process_frame
	if get_viewport().gui_get_focus_owner() != fight.get_node("UI/TopBar/EndTurnBtn"):
		push_error("Result did not restore keyboard focus")
		get_tree().quit(1)
		return
	get_tree().quit()
