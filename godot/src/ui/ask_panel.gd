extends "res://src/ui/lobby_panel.gd"
## The native invitation prompt (S18): replaces the Godot ConfirmationDialogs
## the lobby popped for an incoming challenge, a matchmaking pair, a clan,
## duo or trade invitation. Who asks in the title, what in one line,
## "Aceptar" (primary) and "Rechazar". Closing it (Cerrar / Esc) refuses.
## main.gd queues prompts that arrive while one is open (_ask).
##
## Reads `ask` {title, text}; answers "nativeAsk" [accepted].

const SIZE := Vector2(720, 300)
var _answered := false


func _ready() -> void:
	panel_name = "askDialog"
	frame_size = SIZE
	super._ready()
	closed.connect(func():
		if not _answered:
			_answered = true
			send("nativeAsk", [false]))


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "ask":
		_answered = false
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var a: Dictionary = data("ask", {})
	title.text = str(a.get("title", ""))
	label(body, str(a.get("text", "")), 19).name = "Question"
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var no := button(pinned_actions, I18n.t("btn.refuse"), func(): _answer(false))
	no.name = "Refuse"
	no.custom_minimum_size.x = 150
	var yes := button(pinned_actions, I18n.t("btn.accept"), func(): _answer(true))
	yes.name = "Accept"
	yes.custom_minimum_size.x = 150
	OneBit.primary(yes, 20)
	yes.grab_focus.call_deferred()


func _answer(accepted: bool) -> void:
	if _answered:
		return
	_answered = true
	send("nativeAsk", [accepted])
