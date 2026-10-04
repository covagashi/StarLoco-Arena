class_name GWidget
extends Control
## One XULOR2 widget instance. Draws its theme appearance (plain/pixmap
## background, 9-slice pixmap border, text, image) and reports pref sizes.
## Layout is performed by GuiLayouts on the parent — this node only draws.

signal gui_event(action: String)

const POS_KEYS := ["NORTH_WEST", "NORTH", "NORTH_EAST", "EAST",
	"SOUTH_EAST", "SOUTH", "SOUTH_WEST", "WEST"]

var guitheme: GuiTheme
var kind := "container"          # widget tag name
var type_style := ""             # raw style attr
var states := {}                 # state -> appearance dict
var margin := Rect2()            # appearance margin insets (x=left y=top w=right h=bottom)
var layout := {}                 # {type: sl|bl|rl|gl, ...attrs}
var layout_data := {}            # child's own layout data (sld/bld/rld/gld)
var pref_size := Vector2(-1, -1) # explicit preferred size, -1 = auto
var min_size := Vector2(-1, -1)
var expandable := true
var shrinkable := true
var widget_id := ""
var group_id := ""
var value := ""
var text := ""
var selected := false
var password := false
var editable := false
var horizontal := false
var cell_size := Vector2(-1, -1)
var events := {}                 # signal name -> "dofusarena:method(args)"
var bind := {}                   # {attribute, name, field}
var item_bind := ""              # <item attribute="..."> inside itemRenderer
var model = null                 # GuiModel
var dialog = null                # owning GuiDialog (event dispatch)
var state := "default"
var text_editor: LineEdit = null # embedded editor control for textEditor
var item_renderer: GWidget = null   # template for list rows
var list_widget: GWidget = null     # combobox dropdown list
var renderable_label: GWidget = null
var content_items: Array = []    # bound list content
var content_value = null         # bound scalar (radioGroup value, etc.)
var _hover := false
var _pressed := false


func _ready() -> void:
	clip_contents = true
	resized.connect(func(): GuiLayouts.apply(self))
	if text_editor != null:
		add_child(text_editor)
		text_editor.position = Vector2.ZERO
		text_editor.size = size
	if focused_editable():
		call_deferred("_grab_focus")


func focused_editable() -> bool:
	return text_editor != null and meta_get("focused")


func meta_get(k: String):
	return get_meta(k) if has_meta(k) else null


func _grab_focus() -> void:
	if text_editor != null:
		text_editor.grab_focus()


func appearance() -> Dictionary:
	var a: Dictionary = states.get(state, states.get("default", {}))
	if a.is_empty() and state != "default":
		a = states.get("default", {})
	return a


func label_appearance() -> Dictionary:
	return appearance().get("label", appearance())


func insets() -> Rect2:
	# content insets = appearance margin + border edge sizes + margin element
	var m: Rect2 = margin
	var a := appearance()
	if a.has("margin"):
		m = a["margin"]
	var b := _border_parts()
	if not b.is_empty():
		var west: Dictionary = b.get("WEST", {})
		var east: Dictionary = b.get("EAST", {})
		var north: Dictionary = b.get("NORTH", {})
		var south: Dictionary = b.get("SOUTH", {})
		m.position.x += west.get("rect", Rect2()).size.x
		m.size.x += east.get("rect", Rect2()).size.x
		m.position.y += north.get("rect", Rect2()).size.y
		m.size.y += south.get("rect", Rect2()).size.y
	return m


func content_rect() -> Rect2:
	var m := insets()
	return Rect2(m.position.x, m.position.y,
		size.x - m.position.x - m.size.x,
		size.y - m.position.y - m.size.y)


func _get_minimum_size() -> Vector2:
	var m := insets()
	var s := Vector2()
	if pref_size.x >= 0:
		s.x = pref_size.x
	else:
		s.x = m.position.x + m.size.x + _content_pref().x
	if pref_size.y >= 0:
		s.y = pref_size.y
	else:
		s.y = m.position.y + m.size.y + _content_pref().y
	return s


func _content_pref() -> Vector2:
	match kind:
		"label", "textView", "button", "checkBox", "radioButton":
			var la := label_appearance()
			var f := _font(la)
			var fs := _font_size(la)
			var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			return Vector2(w + 4, fs + 4)
		"image":
			var px: Dictionary = appearance().get("pixmap", {})
			return px.get("rect", Rect2()).size
		"textEditor", "texteditor":
			return Vector2(80, 20)
		_:
			return Vector2.ZERO


func _font(la: Dictionary) -> Font:
	var fid: String = la.get("font", "")
	if fid == "":
		fid = "defaultFont"
	if guitheme != null and guitheme.fonts.has(fid):
		return guitheme.font(fid)
	if guitheme != null:
		return guitheme.font("styledLightFont")
	return ThemeDB.fallback_font


func _font_size(la: Dictionary) -> int:
	var fid: String = la.get("font", "defaultFont")
	if guitheme != null and guitheme.fonts.has(fid):
		return guitheme.font_size(fid)
	return 12


func _font_bordered(la: Dictionary) -> bool:
	var fid: String = la.get("font", "defaultFont")
	return guitheme != null and guitheme.font_bordered(fid)


func _text_color(la: Dictionary) -> Color:
	if la.has("text_color"):
		return la["text_color"]
	if la.has("color_value"):
		return la["color_value"]
	if la.has("color"):
		return guitheme.color(la["color"])
	if la.has("fontColor"):
		return guitheme.color(la["fontColor"])
	return Color(0.29, 0.17, 0.07)


func _border_parts() -> Dictionary:
	var a := appearance()
	if a.has("border"):
		return guitheme.border(a["border"])
	return a.get("border_inline", {})


func _bg_decl() -> Dictionary:
	var a := appearance()
	if a.has("bg"):
		return guitheme.background(a["bg"])
	return a.get("bg_inline", {})


func _draw() -> void:
	var a := appearance()
	# 1. background
	if a.has("plain_bg"):
		var c := _text_color(a)
		draw_rect(Rect2(Vector2.ZERO, size), c, true)
	var bg := _bg_decl()
	if not bg.is_empty() and bg.get("enabled", true):
		var t := guitheme.pixmap_tex(bg.get("pixmap", {}))
		if t != null:
			if bg.get("scaled", false):
				draw_texture_rect(t, Rect2(Vector2.ZERO, size), false)
			else:
				draw_texture(t, (size - t.get_size()) / 2.0)
	# 2. single pixmap image (image widget / appearances with inline pixmap)
	if kind == "image":
		var px: Dictionary = a.get("pixmap", {})
		var t := guitheme.pixmap_tex(px)
		if t != null:
			var cr := content_rect()
			draw_texture(t, cr.position + (cr.size - t.get_size()) / 2.0)
	# 3. 9-slice border
	_draw_border()
	# 4. text
	if text != "" and kind != "image":
		_draw_text()


func _draw_border() -> void:
	var b := _border_parts()
	if b.is_empty():
		return
	var nw: Dictionary = b.get("NORTH_WEST", {})
	var n: Dictionary = b.get("NORTH", {})
	var ne: Dictionary = b.get("NORTH_EAST", {})
	var e: Dictionary = b.get("EAST", {})
	var se: Dictionary = b.get("SOUTH_EAST", {})
	var s: Dictionary = b.get("SOUTH", {})
	var sw: Dictionary = b.get("SOUTH_WEST", {})
	var w: Dictionary = b.get("WEST", {})
	var cw: float = nw.get("rect", Rect2()).size.x
	var chh: float = nw.get("rect", Rect2()).size.y
	var ew: float = ne.get("rect", Rect2()).size.x
	var eh: float = ne.get("rect", Rect2()).size.y
	var sw_h: float = sw.get("rect", Rect2()).size.y
	var se_w: float = se.get("rect", Rect2()).size.x
	_slice(guitheme.pixmap_tex(nw), Rect2(0, 0, cw, chh))
	_slice(guitheme.pixmap_tex(ne), Rect2(size.x - ew, 0, ew, eh))
	_slice(guitheme.pixmap_tex(sw), Rect2(0, size.y - sw_h, sw.get("rect", Rect2()).size.x, sw_h))
	_slice(guitheme.pixmap_tex(se), Rect2(size.x - se_w, size.y - se.get("rect", Rect2()).size.y,
		se_w, se.get("rect", Rect2()).size.y))
	# edges stretch
	var n_h: float = n.get("rect", Rect2()).size.y
	var s_h: float = s.get("rect", Rect2()).size.y
	var e_w: float = e.get("rect", Rect2()).size.x
	var w_w: float = w.get("rect", Rect2()).size.x
	_slice(guitheme.pixmap_tex(n), Rect2(cw, 0, size.x - cw - ew, n_h))
	_slice(guitheme.pixmap_tex(s), Rect2(sw.get("rect", Rect2()).size.x,
		size.y - s_h, size.x - sw.get("rect", Rect2()).size.x - se_w, s_h))
	_slice(guitheme.pixmap_tex(w), Rect2(0, chh, w_w, size.y - chh - sw_h))
	_slice(guitheme.pixmap_tex(e), Rect2(size.x - e_w, eh, e_w, size.y - eh - se.get("rect", Rect2()).size.y))


func _slice(t: Texture2D, r: Rect2) -> void:
	if t == null or r.size.x <= 0 or r.size.y <= 0:
		return
	draw_texture_rect(t, r, false)


func _draw_text() -> void:
	var la := label_appearance()
	var f := _font(la)
	var fs := _font_size(la)
	var c := _text_color(la)
	var cr := content_rect()
	var align := String(la.get("alignment", "center")).to_lower()
	var ha := HORIZONTAL_ALIGNMENT_CENTER
	var va := VERTICAL_ALIGNMENT_CENTER
	match align:
		"west", "north_west", "south_west":
			ha = HORIZONTAL_ALIGNMENT_LEFT
		"east", "north_east", "south_east":
			ha = HORIZONTAL_ALIGNMENT_RIGHT
	match align:
		"north", "north_west", "north_east":
			va = VERTICAL_ALIGNMENT_TOP
		"south", "south_west", "south_east":
			va = VERTICAL_ALIGNMENT_BOTTOM
	var shown := text
	if password:
		shown = "*".repeat(text.length())
	elif shown.contains("<"):
		shown = _strip_markup(shown)
	if _font_bordered(la):
		draw_string_outline(f, Vector2(cr.position.x, cr.position.y + cr.size.y - 4),
			shown, ha, cr.size.x, fs, 4, Color(0.1, 0.06, 0.02))
	draw_multiline_string(f, cr.position + Vector2(0, (cr.size.y - fs) / 2.0),
		shown, ha, cr.size.x, fs, -1, c)


static func _strip_markup(s: String) -> String:
	var re := RegEx.new()
	re.compile("<[^>]+>")
	return re.sub(s, "", true)


func set_state(s: String) -> void:
	if s == state:
		return
	state = s
	queue_redraw()


func refresh_state() -> void:
	var order: Array[String] = []
	if _pressed:
		order = ["pressedSelected", "pressed", "selected"] if selected else ["pressed"]
	elif _hover:
		order = ["mouseHoverSelected", "mouseHover", "selected"] if selected else ["mouseHover"]
	elif selected:
		order = ["selected"]
	order.append("default")
	for s in order:
		if states.has(s):
			set_state(s)
			return
	set_state("default")


func emit_action(sig: String) -> void:
	var a: String = events.get(sig, "")
	if a != "":
		gui_event.emit(a)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		refresh_state()
		emit_action("onMouseEnter")
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		_pressed = false
		refresh_state()
		emit_action("onMouseExit")


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_pressed = true
			refresh_state()
		else:
			var was := _pressed
			_pressed = false
			refresh_state()
			if was:
				activate()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click:
		emit_action("onDoubleClick")


func _unhandled_input(ev: InputEvent) -> void:
	if text_editor != null and text_editor.has_focus() and \
			ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER:
			emit_action("onKeyPress")
			submit_form()


func set_text(t: String) -> void:
	text = t
	if text_editor != null and text_editor.text != t:
		text_editor.text = t
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	refresh_state()


func set_content(v) -> void:
	if v is Array:
		content_items = v
	else:
		content_value = v
	queue_redraw()


## ---- model binding ------------------------------------------------------
func apply_model(v) -> void:
	var attr: String = bind.get("attribute", "")
	match attr:
		"text":
			set_text(str(v))
		"selected":
			set_selected(bool(v))
		"value", "selectedValue":
			content_value = v
			_sync_group()
		"content":
			set_content(v)
		"style":
			type_style = str(v)
			var e := guitheme.elem(_type_name(), type_style)
			states = e.get("states", {}).duplicate(true)
			refresh_state()
	queue_redraw()


func _type_name() -> String:
	match kind:
		"texteditor":
			return "textEditor"
		"checkbox":
			return "checkBox"
		"comboboxplus":
			return "comboBox"
	return kind


func _bind_write(v) -> void:
	if bind.is_empty() or model == null:
		return
	model.set_value(bind["name"], v, bind["field"])


func _sync_group() -> void:
	# radioGroup value model -> member radio buttons reflect it
	if kind == "radioGroup":
		for ch in get_children():
			if ch is GWidget and ch.group_id == widget_id:
				ch.set_selected(ch.value == str(content_value))


## widget semantic click — toggle/select + write model, then events fire
func activate() -> void:
	match kind:
		"checkBox", "checkbox":
			set_selected(not selected)
			_bind_write(selected)
		"radioButton":
			set_selected(true)
			_bind_write(value)
			# deselect siblings sharing groupId
			var p := get_parent()
			if p != null:
				for sib in p.get_children():
					if sib is GWidget and sib != self and sib.group_id == group_id:
						sib.set_selected(false)
		"toggleButton":
			set_selected(not selected)
			_bind_write(selected)
	emit_action("onMouseRelease")
	emit_action("onClick")


## form submit — collect or validate; called on Enter inside textEditor
func submit_form() -> void:
	var f := _find_form()
	if f != null:
		f.emit_action("validate")


func _find_form() -> GWidget:
	var n := get_parent()
	while n != null:
		if n is GWidget and n.kind == "form":
			return n
		n = n.get_parent()
	return null
