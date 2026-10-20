extends "res://src/ui/lobby_panel.gd"
## The native fight report (S18): replaces the post-fight debrief that used
## the debug ElementDlg. The outcome in big letters, the coaches with their
## new ladder strength, what each of your fighters banked (XP, morale,
## tiredness, wounds) and the cards won. "Continuar" closes it.
##
## Reads `fightReport` (main.gd _show_fight_result). Read-only: no events.


func _ready() -> void:
	panel_name = "fightReportDialog"
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "fightReport":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var r: Dictionary = data("fightReport", {})
	var outcome := str(r.get("outcome", "over"))
	title.text = I18n.t({"victory": "fight.result.victory", "defeat": "fight.result.defeat",
		"abandoned": "debrief.abandoned"}.get(outcome, "debrief.over"))
	var summary: Array = r.get("summary", [])
	if not summary.is_empty():
		label(body, "   ".join(summary), 18).name = "Summary"
	var coaches: Array = r.get("coaches", [])
	if not coaches.is_empty():
		var t := table(body, [I18n.t("rp.col_coach"), I18n.t("rp.col_side"), I18n.t("rp.col_strength")],
			["name", "side", "strength"], coaches)
		t.name = "Coaches"
		t.custom_minimum_size.y = 40 + 38 * mini(coaches.size(), 3)
		t.size_flags_vertical = Control.SIZE_FILL
	var fighters: Array = r.get("fighters", [])
	label(body, I18n.t("rp.fighters"), 20)
	if fighters.is_empty():
		label(body, I18n.t("rp.no_fighters"))
	else:
		var ft := table(body, [I18n.t("team.col_name"), I18n.t("rp.col_xp"), I18n.t("rp.col_morale"),
			I18n.t("rp.col_tired"), I18n.t("rp.col_state")],
			["name", "xp", "morale", "tired", "state"], fighters)
		ft.name = "Fighters"
		ft.custom_minimum_size.y = 40 + 38 * mini(fighters.size(), 3)
		ft.size_flags_vertical = Control.SIZE_FILL
	var cards: Array = r.get("cards", [])
	if not cards.is_empty():
		# one line: a table here pushed the window into a scroll
		var won: Array = cards.map(func(c): return "%s ×%d" % [c.name, int(c.qty)])
		label(body, "%s: %s" % [I18n.t("fight.result.won"), ", ".join(won)], 18).name = "Cards"
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var go := button(pinned_actions, I18n.t("fight.result.continue"), func(): closed.emit())
	go.name = "Continue"
	go.custom_minimum_size.x = 170
	OneBit.primary(go, 20)
	go.grab_focus.call_deferred()
