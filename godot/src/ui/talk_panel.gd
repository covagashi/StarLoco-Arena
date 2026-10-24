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

const SIZE := Vector2(900, 580)   # S23: room for the face


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
	# S23: the speaker's face beside what they say — "no sale la cara"
	var face: Dictionary = talk.get("face", {})
	if not face.is_empty() and _face_box(face) != null:
		var split := HBoxContainer.new()
		split.add_theme_constant_override("separation", 18)
		body.add_child(split)
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 6)
		split.add_child(side)
		side.add_child(_face_box(face, true))
		# who they are, in one line (S23: "Aldebrán se presenta")
		if str(face.get("who", "")) != "":
			var who := UiStyle.caption(I18n.t(str(face.who)))
			who.name = "Who"
			who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			who.custom_minimum_size.x = FACE_SIZE.x
			side.add_child(who)
		split.add_child(speech)
	else:
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



const FACE_SIZE := Vector2(170, 200)


## The face as a framed box: a retail animation (AnmSprite, looping) or a
## still image. With build=false it only says whether there is one to show.
func _face_box(face: Dictionary, build := false) -> Control:
	if face.has("image"):
		var img := AssetPaths.load_image(str(face.image))
		if img == null:
			return null
		if not build:
			return self
		var tr := TextureRect.new()
		tr.name = "Face"
		tr.texture = ImageTexture.create_from_image(img)
		tr.custom_minimum_size = FACE_SIZE
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return _framed(tr)
	if not face.has("anim"):
		return null
	var spr = preload("res://src/anims/anm_sprite.gd").new()
	if not spr.load_action(str(face.anim), str(face.get("action", ""))):
		spr.free()
		return null
	if not build:
		spr.free()
		return self
	var holder := Control.new()
	holder.name = "Face"
	holder.custom_minimum_size = FACE_SIZE
	holder.clip_contents = true
	holder.add_child(spr)
	# fit the first frame in the box, feet towards the bottom
	var w := 1.0
	var h := 1.0
	for f in spr._frames:
		w = maxf(w, float(f.w))
		h = maxf(h, float(f.h))
	var k := minf(minf((FACE_SIZE.x - 16) / w, (FACE_SIZE.y - 16) / h), 2.5)
	spr.scale = Vector2(k, k)
	spr.foot_pivot = true
	spr.position = Vector2(FACE_SIZE.x / 2.0, FACE_SIZE.y - 10)
	return _framed(holder)


func _framed(c: Control) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PAPER, UiStyle.RIM_HI, 2, 4))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(c)
	return frame
