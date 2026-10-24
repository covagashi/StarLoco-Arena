extends "res://src/ui/card_panel.gd"   # lobby_panel + the card tile helpers
## The fight report: the one place a fight's result is told (S21). The fight
## itself only flashes VICTORIA / DERROTA; this panel opens when the lobby is
## back. First what matters — the outcome in big letters and what you won,
## the cards as art tiles — then each fighter's report (XP, morale,
## tiredness, wounds) and, in a fight between coaches, the new strengths.
## "Continuar" closes it.
##
## Reads `fightReport` {outcome, summary[], coaches[], fighters[], cards[{id,
## name, qty}]} (main.gd _show_fight_result). Read-only: no events.


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
	var key: String = {"victory": "fight.result.victory", "defeat": "fight.result.defeat",
		"abandoned": "debrief.abandoned"}.get(outcome, "debrief.over")
	title.text = I18n.t("rp.title")
	var hero := label(body, I18n.t(key).to_upper(), 44)
	hero.name = "Outcome"
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_theme_font_override("font", UiStyle.title_font())
	hero.add_theme_constant_override("outline_size", 10)
	hero.add_theme_color_override("font_color",
		UiStyle.GOLD if outcome == "victory" else (Color("c9583f") if outcome == "defeat" else UiStyle.INK))
	var summary: Array = r.get("summary", [])
	if not summary.is_empty():
		var sl := label(body, "   ·   ".join(summary), 18)
		sl.name = "Summary"
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# what you won (as art) and your fighters, side by side: one screen, no
	# scroll at 720p
	var split := row(body)
	split.add_theme_constant_override("separation", 24)
	var left := column(split, false)
	left.custom_minimum_size.x = 330
	var cards: Array = r.get("cards", [])
	label(left, I18n.t("rp.won"), 20)
	if cards.is_empty():
		_muted(left, I18n.t("rp.no_cards"))
	else:
		var flow := HFlowContainer.new()
		flow.name = "Cards"
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		left.add_child(flow)
		for c in cards:
			var t := _tile(flow, {"id": int(c.get("id", 0)), "name": str(c.get("name", ""))}, false,
				"×%d" % int(c.get("qty", 1)) if int(c.get("qty", 1)) > 1 else "")
			t.focus_mode = Control.FOCUS_NONE
	var right := column(split)
	var fighters: Array = r.get("fighters", [])
	label(right, I18n.t("rp.fighters"), 20)
	if fighters.is_empty():
		_muted(right, I18n.t("rp.no_fighters"))
	else:
		var ft := table(right, [I18n.t("team.col_name"), I18n.t("rp.col_xp"), I18n.t("rp.col_morale"),
			I18n.t("rp.col_tired"), I18n.t("rp.col_state")],
			["name", "xp", "morale", "tired", "state"], fighters)
		ft.name = "Fighters"
		ft.custom_minimum_size.y = 40 + 38 * mini(fighters.size(), 4)
		ft.size_flags_vertical = Control.SIZE_FILL
	# the strengths only mean something between coaches: one line each,
	# under the fighters
	var coaches: Array = r.get("coaches", [])
	if coaches.size() > 1:
		label(right, I18n.t("rp.coaches"), 20)
		var lines := VBoxContainer.new()
		lines.name = "Coaches"
		right.add_child(lines)
		for c in coaches:
			var l := label(lines, "%s%s — %s — %s %s" % ["▶ " if c.get("me", false) else "",
				str(c.name), str(c.side), I18n.t("rp.col_strength"), str(c.strength)], 16)
			if c.get("me", false):
				l.add_theme_color_override("font_color", UiStyle.GOLD)
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var go := button(pinned_actions, I18n.t("fight.result.continue"), func(): closed.emit())
	go.name = "Continue"
	go.custom_minimum_size.x = 190
	UiStyle.primary(go, 20)
	go.grab_focus.call_deferred()
