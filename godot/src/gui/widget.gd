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
var bind := {}                   # last <property>/<data> bind (legacy)
var binds: Array = []            # all <property> binds {attribute,name,field,data_id,condition}
var item_binds: Array = []       # {attribute, field, item, condition}
var item_bind := ""              # <item attribute="..."> inside itemRenderer
var renderers: Array = []        # list: [{cond, template}] itemRenderer pool
var item_value = null            # bound item object (renderer rows / <data>)
var data_value = null           # resolved object under <data id> alias
var data_id := ""                # <data id> alias this widget exposes
var enabled := true
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
	if _viewer_spr != null:
		_viewer_place()
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
		var t: Texture2D = a.get("pixmap_tex")
		if t == null:
			var px: Dictionary = a.get("pixmap", {})
			t = guitheme.pixmap_tex(px)
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
		order.assign(["pressedSelected", "pressed", "selected"] if selected else ["pressed"])
	elif _hover:
		order.assign(["mouseHoverSelected", "mouseHover", "selected"] if selected else ["mouseHover"])
	elif selected:
		order.assign(["selected"])
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
	elif what == NOTIFICATION_RESIZED and _viewer_spr != null:
		_viewer_place()


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
	rebuild_items()
	queue_redraw()


## ---- model binding ------------------------------------------------------
func apply_model(v, b: Dictionary = {}) -> void:
	var bb: Dictionary = b if not b.is_empty() else bind
	var attr: String = bb.get("attribute", "")
	if bb.has("data_id"):
		data_id = bb["data_id"]
		data_value = v
	var pcond: Dictionary = bb.get("condition", {})
	if not pcond.is_empty():
		v = GuiConditions.eval(pcond, v)
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
		"enabled":
			set_enabled_flag(_truthy(v))
		"visible":
			visible = _truthy(v)
		"animatedElement":
			_viewer_set("lib", v)
		"animName":
			_viewer_set("anim", v)
		"direction":
			_viewer_set("dir", v)
		"material":
			_viewer_set("material", v)
		_:
			# model object → apply any bound FIELDS as item binds would
			if v is Dictionary and bb.get("field", "") != "":
				_apply_attr(attr, v.get(bb["field"]))
	queue_redraw()


func _truthy(v) -> bool:
	if v is bool:
		return v
	if v is String:
		return v == "true" or v == "1"
	return v != null and v != 0 and v != 0.0


func set_enabled_flag(v: bool) -> void:
	enabled = v
	mouse_filter = MOUSE_FILTER_STOP if v else MOUSE_FILTER_IGNORE
	if not v:
		set_state("disabled")
	else:
		refresh_state()


func _apply_attr(attr: String, v) -> void:
	match attr:
		"text":
			set_text(str(v))
		"visible":
			visible = _truthy(v)
		"enabled":
			set_enabled_flag(_truthy(v))
		"selected":
			set_selected(_truthy(v))
		"texture", "pixmap":
			_set_item_texture(str(v))
		"content":
			set_content(v)
		"value":
			data_value = v
		_:
			set_meta("attr_" + attr, v)
	queue_redraw()


func _set_item_texture(url: String) -> void:
	# item icon url -> look up in theme image index (e.g. spells/eq icons)
	var bn := url.get_file()
	if bn.get_extension() == "":
		bn += ".png"
	var p := "res://assets/gui/images/" + bn
	var px := {"texture": "", "rect": Rect2()}
	var img := Image.new()
	for cand in [p, "res://assets/gui/images/spells/" + bn,
			"res://assets/gui/images/spells/icons/" + bn,
			"res://assets/gui/images/equipments/" + bn,
			"res://assets/gui/images/breeds/" + bn,
			"res://assets/gui/images/miscellaneous/" + bn]:
		if FileAccess.file_exists(cand):
			if img.load(cand) == OK:
				_appear("default")["pixmap_tex"] = ImageTexture.create_from_image(img)
				return
	# theme texture id fallback
	if guitheme != null and guitheme.textures.has(url):
		_appear("default")["pixmap"] = {"texture": url,
			"rect": Rect2(Vector2.ZERO, guitheme.texture(url).get_size())}


## animatedElementViewer — lazily hosts an AnmSprite bound to model fields
var _viewer := {"lib": "", "anim": "", "dir": 0, "material": null}
var _viewer_spr = null

func _appear(state: String) -> Dictionary:
	if not states.has(state):
		states[state] = {}
	return states[state]


func _viewer_set(k: String, v) -> void:
	_viewer[k] = v
	if _viewer_spr == null and _viewer["lib"] != "":
		_viewer_spr = load("res://src/anims/anm_sprite.gd").new()
		add_child(_viewer_spr)
		_viewer_spr.centered = true
	_viewer_place()
	if _viewer_spr != null and _viewer["lib"] != "":
		var set_dir := str(_viewer["lib"])
		if not set_dir.begins_with("res://"):
			set_dir = "res://assets/anims/" + set_dir
		var anim := str(_viewer["anim"]) if _viewer["anim"] != "" else "AnimStatique"
		if _viewer["material"] is Dictionary:
			_viewer_spr.tints = _viewer["material"]
		var dir := int(_viewer["dir"])
		# exported actions carry their facing: "<dir>_<Anim>"
		if not anim[0].is_valid_int():
			anim = "%d_%s" % [dir, anim]
		if not _viewer_spr.load_action(set_dir, anim):
			# facing may be missing in the set — try the canonical two
			for d in [5, 2, 0, 6, 1, 3, 7, 4]:
				var try := "%d_%s" % [d, anim.split("_", false, 1)[-1]]
				if _viewer_spr.load_action(set_dir, try):
					break
		_viewer_spr.flip_h = dir in [1, 2, 3]


func _viewer_place() -> void:
	if _viewer_spr == null:
		return
	var sc: float = get_meta("viewer_scale", 1.0)
	_viewer_spr.scale = Vector2(sc, sc)
	_viewer_spr.position = size / 2.0 + Vector2(0, get_meta("viewer_offy", 0.0))


## item context — for renderer rows and <data>-bound widgets
func apply_item(v) -> void:
	item_value = v
	if bind.has("data_id"):
		data_id = bind["data_id"]
		data_value = v
	for b in item_binds:
		var fv = v.get(b["field"]) if v is Dictionary and b.get("field", "") != "" else v
		# a <condition> on an item transforms the value (visible <- isFalse(usable))
		var cond: Dictionary = b.get("condition", {})
		if not cond.is_empty():
			fv = GuiConditions.eval(cond, fv)
		_apply_attr(b["attribute"], fv)
	queue_redraw()


## list row materialization — called when content_items changes
func rebuild_items() -> void:
	if kind != "list" and kind != "comboboxplus" and kind != "comboBox":
		return
	# drop old rows (renderer templates stay hidden, owned by us). free()
	# now — queue_free defers and a same-frame rebuild would double them.
	for ch in get_children().duplicate():
		if ch is GWidget and ch.get_meta("list_row", false):
			remove_child(ch)
			ch.free()
	if renderers.is_empty() or content_items.is_empty():
		return
	# retail List is a fixed grid: cols = floor(width/cellW), row-major.
	var cell := cell_size
	if cell == Vector2.ZERO:
		cell = Vector2(20, 20)
	# grid width: live size, else the sld size the dialog gave us
	var box_w := size.x
	if box_w <= 0 and layout_data.has("size"):
		var sv: Array = layout_data["size"]
		if not (sv[0] is String):
			box_w = float(sv[0])
	var cols: int = max(1, int(box_w / cell.x)) if box_w > 0 else 1
	var i := 0
	for item in content_items:
		var tpl: GWidget = null
		for r in renderers:
			var cond: Dictionary = r.get("cond", {})
			if cond.is_empty() or GuiConditions.eval(cond, item):
				tpl = r["template"]
				break
		if tpl == null:
			tpl = renderers[0]["template"]
		var row: GWidget = tpl.duplicate_widget()
		row.set_meta("list_row", true)
		row.visible = true
		row.item_value = item
		row.size = cell
		row.custom_minimum_size = cell
		row.position = Vector2((i % cols) * cell.x, (i / cols) * cell.y)
		add_child(row)
		row.apply_item_deep(item)
		# each row is a sl canvas (templates position with sld)
		row.layout = {"type": "sl"}
		GuiLayouts.apply(row)
		i += 1


func apply_item_deep(v) -> void:
	apply_item(v)
	for ch in get_children().duplicate():
		if ch is GWidget:
			ch.apply_item_deep(v)


func duplicate_widget() -> GWidget:
	var w := GWidget.new()
	w.guitheme = guitheme
	w.kind = kind
	w.type_style = type_style
	w.states = states.duplicate(true)
	w.margin = margin
	w.layout = layout.duplicate()
	w.layout_data = layout_data.duplicate()
	w.pref_size = pref_size
	w.min_size = min_size
	w.expandable = expandable
	w.shrinkable = shrinkable
	w.widget_id = widget_id
	w.group_id = group_id
	w.value = value
	w.visible = visible
	w.enabled = enabled
	w.selected = selected
	w.text = text
	w.password = password
	w.horizontal = horizontal
	w.cell_size = cell_size
	w.events = events.duplicate()
	w.bind = bind.duplicate()
	w.binds = binds.duplicate(true)
	w.item_binds = item_binds.duplicate(true)
	w.data_id = data_id
	w.model = model
	w.mouse_filter = mouse_filter
	w.gui_event.connect(_forward_event)
	# renderer templates -> their duplicated counterparts (nested lists in rows)
	var tpl_map := {}
	for ch in get_children():
		if ch is GWidget:
			var c: GWidget = ch.duplicate_widget()
			w.add_child(c)
			tpl_map[ch] = c
		elif ch == text_editor:
			pass  # embedded LineEdit — not part of renderer templates
	for r in renderers:
		var t: GWidget = r["template"]
		if tpl_map.has(t):
			w.renderers.append({"cond": r.get("cond", {}), "template": tpl_map[t]})
	if item_renderer != null and tpl_map.has(item_renderer):
		w.item_renderer = tpl_map[item_renderer]
	return w


func _forward_event(a: String) -> void:
	gui_event.emit(a)


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
