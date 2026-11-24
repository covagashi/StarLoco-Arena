extends "res://src/ui/lobby_panel.gd"
## «Guardar mi progreso» (S51): a web demo account becomes a real one with an
## email and a password, without losing anything. Three steps in one sheet:
##   ask  — after the first won fight: "¿Guardas tu progreso?", the coach
##          cheering beside the why, "Más tarde" / "Ahora";
##   form — correo, contraseña, repetir contraseña, Guardar (also opened from
##          Opciones while the account is a demo one);
##   done — saved: from now on «Ya tengo cuenta» opens it anywhere.
##
## Reads `saveAccount` {stage, error (i18n key), busy, email}; answers
## "nativeSaveLater", "nativeSaveNow", "nativeSaveSubmit" [email, password,
## again] and "nativeSaveDone". main.gd sends 60070 and reads 60071.

const SIZE := Vector2(760, 500)
const FORM_SIZE := Vector2(760, 590)   # three fields and an error line


func _ready() -> void:
	panel_name = "saveAccountDialog"
	frame_size = SIZE
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "saveAccount":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	var focus := remember_focus()
	clear_body()
	var stage := str(data("saveAccount.stage", "ask"))
	frame_size = FORM_SIZE if stage == "form" else SIZE
	match stage:
		"form": _form()
		"done": _done()
		_: _ask()
	if focus != "" and focus != "Close":
		restore_focus.call_deferred(focus)   # after the default grabs below


## The coach on the left (the login's own art, standing proud), the words
## on the right.
func _split() -> VBoxContainer:
	var split := row(body)
	split.add_theme_constant_override("separation", 22)
	var stage := Control.new()
	stage.name = "Coach"
	stage.custom_minimum_size = Vector2(200, 270)
	split.add_child(stage)
	var fig := UiStyle.figure(stage, "coach", Vector2(0, 0), 262)
	if fig.texture != null:   # centred in its column
		fig.position.x += (200.0 - fig.size.x * 0.62) * 0.5
	var col := column(split)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	return col


func _ask() -> void:
	title.text = I18n.t("save.ask.title")
	var col := _split()
	col.add_child(UiStyle.tag(I18n.t("save.ask.tag"), UiStyle.B_CORAL))
	label(col, I18n.t("save.ask.text"), 20).name = "Why"
	label(col, I18n.t("save.ask.more"), 16).add_theme_color_override("font_color", UiStyle.B_MUTE)
	_actions([["Later", "save.later", false, func(): send("nativeSaveLater")],
		["Now", "save.now", true, func(): send("nativeSaveNow")]])


func _form() -> void:
	title.text = I18n.t("save.form.title")
	label(body, I18n.t("save.form.text"), 17).name = "Intro"
	var busy := bool(data("saveAccount.busy", false))
	var email := _add_input("email", "save.email", "save.email_ph", false)
	var pw := _add_input("password", "save.password", "save.password_ph", true)
	var again := _add_input("again", "save.again", "save.again_ph", true)
	email.focus_next = email.get_path_to(pw)
	pw.focus_next = pw.get_path_to(again)
	var err := str(data("saveAccount.error", ""))
	if err != "":
		var e := label(body, I18n.t(err), 16)
		e.name = "Error"
		e.add_theme_color_override("font_color", UiStyle.B_CORAL)
		e.add_theme_font_override("font", UiStyle.bold(800))
	for f: LineEdit in [email, pw, again]:
		f.editable = not busy
		f.text_submitted.connect(func(_t): _submit())
	var save := _actions([["Save", "save.submit", true, _submit]], false)
	save.disabled = busy
	if email.text == "":
		email.grab_focus.call_deferred()


func _done() -> void:
	title.text = I18n.t("save.done.title")
	var col := _split()
	col.add_child(UiStyle.tag(I18n.t("save.done.tag"), UiStyle.B_CORAL))
	var who := label(col, str(data("saveAccount.email", "")), 22)
	who.name = "Email"
	who.add_theme_font_override("font", UiStyle.bold(800))
	label(col, I18n.t("save.done.text"), 18).name = "Next"
	_actions([["Ok", "save.ok", true, func(): send("nativeSaveDone")]])


## A tag above a style B field (the login's look), kept in `draft`.
func _add_input(key: String, tag_key: String, placeholder_key: String, secret: bool) -> LineEdit:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	body.add_child(box)
	box.add_child(UiStyle.tag(I18n.t(tag_key)))
	var e := LineEdit.new()
	e.name = key.capitalize().replace(" ", "")
	e.placeholder_text = I18n.t(placeholder_key)
	e.text = str(draft.get(key, ""))
	e.secret = secret
	e.max_length = 72 if secret else 64
	e.custom_minimum_size.y = 44
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	StyleB.field(e, 18)
	e.text_changed.connect(func(v): draft[key] = v)
	box.add_child(e)
	return e


## The footer's buttons, right-aligned: [name, i18n key, primary, callback].
## Returns the last one (the main action).
func _actions(list: Array, grab := true) -> Button:
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var last: Button
	for a in list:
		var b := button(pinned_actions, I18n.t(a[1]), a[3])
		b.name = a[0]
		b.custom_minimum_size.x = 170
		if a[2]:
			UiStyle.primary(b, 20)
		last = b
	if grab:
		last.grab_focus.call_deferred()
	return last


func _submit() -> void:
	if bool(data("saveAccount.busy", false)):
		return
	send("nativeSaveSubmit", [str(draft.get("email", "")), str(draft.get("password", "")),
		str(draft.get("again", ""))])
