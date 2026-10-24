extends "res://src/ui/lobby_panel.gd"
## The native conversation window (S18, tanda 2): replaces the debug
## ElementDlg for every talking element — challenges, breed masters, the
## demons, NPCs — and the tutorial monologues. A smaller window than the
## lobby panels: who speaks (the title), what they say, then the choices.
## Replies and challenges are a list of buttons; "Siguiente" / "Aceptar" /
## "Cerrar" go in the action row, the main one in the primary style.
##
## Reads the `talk` model (main.gd _talk_show): {name, text (BBCode), page,
## pages, choices:[{label, kind}]} with kind reply / challenge / primary /
## secondary. A click sends "nativeTalk" [index]; main.gd runs the choice.

const SIZE := Vector2(860, 500)


func _ready() -> void:
	panel_name = "npcTalkDialog"
	frame_size = SIZE
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "talk":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var talk: Dictionary = data("talk", {})
	title.text = str(talk.get("name", "")) if str(talk.get("name", "")) != "" else I18n.t("talk.title")
	var speech := RichTextLabel.new()
	speech.name = "Speech"
	speech.bbcode_enabled = true
	speech.fit_content = true
	speech.scroll_active = false
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speech.add_theme_font_override("normal_font", UiStyle.body_font())
	speech.add_theme_font_size_override("normal_font_size", 19)
	speech.add_theme_font_size_override("bold_font_size", 19)
	speech.add_theme_color_override("default_color", UiStyle.INK)
	speech.text = str(talk.get("text", ""))
	body.add_child(speech)
	var pages := int(talk.get("pages", 0))
	if pages > 1:
		var where := UiStyle.caption(I18n.t("talk.page", {"n": int(talk.get("page", 1)), "of": pages}))
		where.name = "Page"
		body.add_child(where)
	var rows: Array = talk.get("choices", [])
	var listed := rows.filter(func(c): return str(c.kind) in ["reply", "challenge"])
	if listed.any(func(c): return str(c.kind) == "challenge"):
		body.add_child(UiStyle.caption(I18n.t("talk.challenges")))
	var first: Button = null
	var main: Button = null
	for i in rows.size():
		var c: Dictionary = rows[i]
		var kind := str(c.kind)
		if kind in ["reply", "challenge"]:
			var b := button(body, ("› " if kind == "reply" else "") + str(c.label),
				func(): send("nativeTalk", [i]))
			b.name = "Choice%d" % i
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			if first == null:
				first = b
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	for kind in ["secondary", "primary"]:
		for i in rows.size():
			if str(rows[i].kind) != kind:
				continue
			var b := button(pinned_actions, str(rows[i].label), func(): send("nativeTalk", [i]))
			b.name = "Choice%d" % i
			b.custom_minimum_size.x = 150
			if kind == "primary":
				UiStyle.primary(b, 20)
				main = b
	var target: Button = main if main != null else first
	if target != null:
		target.grab_focus.call_deferred()
