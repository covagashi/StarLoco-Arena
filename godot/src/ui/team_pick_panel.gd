extends "res://src/ui/lobby_panel.gd"
## The native team picker for an accepted challenge (S18): replaces the
## debug TeamPickDlg. One button per team preset (and the titular line-up);
## picking one confirms it (26303). Closing backs out of the challenge.
##
## Reads `teamPick` {presets:[{id, name, n}], evo}; answers nativeTeamPick
## [teamId] / nativeTeamPickCancel.

const SIZE := Vector2(720, 440)
var _done := false


func _ready() -> void:
	panel_name = "teamPickDialog"
	frame_size = SIZE
	super._ready()
	closed.connect(func():
		if not _done:
			_done = true
			send("nativeTeamPickCancel"))


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "teamPick":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	title.text = I18n.t("tp.title")
	var d: Dictionary = data("teamPick", {})
	label(body, I18n.t("tp.hint_evo") if bool(d.get("evo", false)) else I18n.t("tp.hint"))
	var first: Button = null
	for p in d.get("presets", []):
		var n := int(p.get("n", -1))
		var text: String = str(p.name) if n < 0 else I18n.t("tp.preset", {"name": p.name, "n": n})
		var b := button(body, text, func():
			_done = true
			send("nativeTeamPick", [int(p.id)]))
		b.name = "Team%d" % int(p.id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if first == null:
			first = b
	if first != null:
		first.grab_focus.call_deferred()
