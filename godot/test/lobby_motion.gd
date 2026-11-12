extends Node2D

## S45: the lobby moving, for the owner to see the animations (style B).
## Offline, with sample data: the entrance, then the pointer over each tile
## and down the list. Record it with Godot's movie maker:
##   xvfb-run godot --path godot --resolution 1280x720 --fixed-fps 30 \
##     --write-movie /tmp/lobby.avi test/lobby_motion.tscn

const Lobby := preload("res://src/ui/lobby_screen.gd")
const Chat := preload("res://src/ui/chat_box.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var model := GuiModel.new()
	model.set_value("localCoach", {"name": "Arel", "level": 8, "sex": 0,
		"skin": 1, "hair": 1, "actorDirection": 1,
		"actorDescriptorLibrary": "coach_7000",
		"actorMaterial": Palettes.coach_tints(1, 1)})
	model.set_value("hub", {"story": {"titulars": 2, "bench": 1},
		"ranked": {"teams": [{"id": 1, "name": "Élite de prueba"}], "selected": 1},
		"tourn": {"label": "Torneo Clásico · hoy 21:00", "search_tid": -1}})
	model.set_value("season", {"number": 2, "ends": int(Time.get_unix_time_from_system()) + 19 * 86400})
	model.set_value("wallet", {1: 1130, 10: 300})
	var lobby := Lobby.new()
	add_child(lobby)
	var chat := Chat.instantiate()   # over the lobby, as main.gd's $UI/Chat is
	add_child(chat)
	lobby.bind_model(model, chat)
	lobby.set_actions_ready(true)
	if chat.has_method("log_line"):
		chat.log_line("[color=#ff4d6d]Mira:[/color] ¿alguien para un ranking?")
		chat.log_line("[color=#2f74f0]Torneo Clásico: inscripción abierta.[/color]")
	await get_tree().create_timer(3.0).timeout   # the entrance and the wave
	for id in ["story", "ranked", "tourn"]:
		var play: Button = lobby._cards[id].play
		play.grab_focus()
		await get_tree().create_timer(0.9).timeout
	var menus: Array = lobby._menu_buttons.filter(func(b): return b.get_parent() == lobby._box)
	for b in menus.slice(0, 4):
		b.grab_focus()
		await get_tree().create_timer(0.35).timeout
	lobby._quick.grab_focus()
	lobby._next_pose = 0.05   # its idle gesture, without waiting 14 s
	await get_tree().create_timer(2.4).timeout
	get_tree().quit()
