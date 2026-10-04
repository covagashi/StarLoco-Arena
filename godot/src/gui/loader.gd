class_name GuiLoader
extends RefCounted
## XULOR2 XML loader — builds GWidget trees from assets/gui/xml/dialogs/*.xml.
## Port of ye_2's tag registry + DS.java's attribute semantics.

const WIDGET_TAGS := [
	"container", "button", "label", "image", "textView", "textEditor",
	"texteditor", "checkBox", "checkbox", "radioButton", "radioGroup",
	"comboboxplus", "comboBox", "list", "form", "window", "scrollContainer",
	"slider", "progressBar", "tabbedContainer", "tree", "table", "map",
	"renderableContainer", "itemRenderer", "spacer", "separator", "iconLabel",
	"toggleButton", "stack", "progressIcon", "dnd", "windowMovePoint",
	"colorPicker", "text", "simpleMessage", "scrollBar",
]
const LAYOUT_TAGS := ["sl", "bl", "rl", "gl", "tl", "SPL", "al"]
const LDATA_TAGS := ["sld", "bld", "rld", "gld", "tld", "spl", "ald"]

var theme: GuiTheme
var i18n := {}
var model: GuiModel
var by_id := {}          # id -> GWidget (per loaded dialog)
var unknown_tags := {}


func _init(t: GuiTheme, strings: Dictionary, m: GuiModel) -> void:
	theme = t
	i18n = strings
	model = m


func load_file(path: String) -> GWidget:
	var p := XMLParser.new()
	if p.open(path) != OK:
		push_error("[guiloader] cannot open " + path)
		return null
	by_id.clear()
	var root: GWidget = null
	var stack: Array = []  # {w: GWidget, tag: String, structural: bool}
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := p.get_node_name()
				var a: Dictionary = _attrs(p)
				var parent: GWidget = null
				var in_renderer := false
				for i in range(stack.size() - 1, -1, -1):
					if stack[i]["w"] != null:
						parent = stack[i]["w"]
						break
				for fr in stack:
					if fr.get("tag") == "itemRenderer":
						in_renderer = true
				if tag in LAYOUT_TAGS:
					if parent != null:
						parent.layout = {"type": tag}
						for k in a:
							parent.layout[k] = a[k]
				elif tag in LDATA_TAGS:
					if parent != null:
						parent.layout_data = _parse_ldata(tag, a)
				elif tag.ends_with("Appearance") or tag == "appearance":
					if parent != null:
						_merge_appearance_into(parent, tag, a)
					if not p.is_empty():
						stack.append({"w": null, "tag": tag})
				elif tag == "margin":
					if parent != null:
						_appear(parent, "default")["margin"] = \
							_insets(a.get("insets", a.get("spacing", "0,0,0,0")))
				elif tag == "Font" or tag == "font":
					if parent != null and a.has("ref"):
						_appear(parent, "default")["font"] = a["ref"]
				elif tag == "Color" or tag == "color":
					if parent != null:
						if a.has("ref"):
							_appear(parent, "default")["color"] = a["ref"]
						elif a.has("color"):
							_appear(parent, "default")["color_value"] = _color(a["color"])
				elif tag == "PixmapBorder":
					if parent != null:
						if a.has("ref"):
							_appear(parent, "default")["border"] = a["ref"]
						else:
							_appear(parent, "default")["border_inline"] = _inline_border(p)
				elif tag == "PixmapBackground":
					if parent != null:
						if a.has("ref"):
							_appear(parent, "default")["bg"] = a["ref"]
						else:
							_appear(parent, "default")["bg_inline"] = {
								"scaled": a.get("scaled", "false") == "true",
								"enabled": a.get("enabled", "true") == "true",
								"pixmap": _inline_pixmap(p),
							}
				elif tag == "Pixmap":
					if parent != null:
						_appear(parent, "default")["pixmap"] = _pixmap(a)
				elif tag == "PlainBackground":
					if parent != null:
						_appear(parent, "default")["plain_bg"] = true
				elif tag == "property":
					if parent != null:
						parent.bind = {
							"attribute": a.get("attribute", ""),
							"name": a.get("name", ""),
							"field": a.get("field", ""),
						}
				elif tag == "item":
					if parent != null:
						parent.item_bind = a.get("attribute", "text")
				elif tag == "tooltip":
					if parent != null:
						parent.set_meta("tooltip", a)
				elif tag == "itemRenderer":
					if not p.is_empty():
						stack.append({"w": parent, "tag": tag, "structural": true})
				elif tag in WIDGET_TAGS or _looks_like_widget(tag):
					var w: GWidget = _make_widget(tag, a)
					if parent != null:
						parent.add_child(w)
						if in_renderer:
							w.visible = false
							# the owning list/combo keeps it as a row template
							var owner: GWidget = _nearest_list(parent)
							if owner != null:
								owner.item_renderer = w
					else:
						root = w
					if not p.is_empty():
						stack.append({"w": w, "tag": tag})
				else:
					unknown_tags[tag] = true
					if not p.is_empty():
						stack.append({"w": null, "tag": tag})
			XMLParser.NODE_ELEMENT_END:
				var tag := p.get_node_name()
				for i in range(stack.size() - 1, -1, -1):
					if stack[i].get("tag") == tag:
						stack.resize(i)
						break
	if root != null:
		_wire(root)
	return root


func _nearest_list(w: GWidget) -> GWidget:
	var n: Node = w
	while n != null:
		if n is GWidget and n.kind in ["list", "comboboxplus", "comboBox"]:
			return n
		n = n.get_parent()
	return null


func _looks_like_widget(tag: String) -> bool:
	return tag[0] == tag[0].to_lower() and not tag in ["init", "theme"]


func _make_widget(tag: String, a: Dictionary) -> GWidget:
	var w := GWidget.new()
	w.guitheme = theme
	w.kind = tag
	w.type_style = a.get("style", "")
	var e: Dictionary = theme.elem(_type_name(tag), w.type_style)
	w.states = e.get("states", {}).duplicate(true)
	if e.get("margin") != null:
		w.margin = e["margin"]
	if not w.states.has("default"):
		w.states["default"] = {}
	# widget attrs
	w.widget_id = a.get("id", "")
	if w.widget_id != "":
		by_id[w.widget_id] = w
	w.group_id = a.get("groupId", "")
	w.value = a.get("value", "")
	w.expandable = a.get("expandable", "true") == "true"
	w.shrinkable = a.get("shrinkable", "true") == "true"
	w.password = a.get("password", "false") == "true"
	w.selected = a.get("selected", "false") == "true"
	w.horizontal = a.get("horizontal", "false") == "true"
	w.text = i18n_str(a.get("text", ""))
	if a.has("prefSize"):
		var v: PackedFloat64Array = a["prefSize"].split_floats(",")
		w.pref_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])
	if a.has("minSize"):
		var v: PackedFloat64Array = a["minSize"].split_floats(",")
		w.min_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])
	if a.has("cellSize"):
		w.cell_size = _size_spec(a["cellSize"])
	if a.get("nonBlocking", "false") == "true":
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if a.get("focused", "false") == "true":
		w.set_meta("focused", true)
	# editor for textEditor
	if tag == "textEditor" or tag == "texteditor":
		var le := LineEdit.new()
		le.flat = true
		le.secret = w.password
		le.text = w.text
		le.select_all_on_focus = a.get("selectOnFocus", "false") == "true"
		var la: Dictionary = w.states.get("default", {}).get("label", w.states.get("default", {}))
		if la.has("font") and theme.fonts.has(la["font"]):
			le.add_theme_font_override("font", theme.font(la["font"]))
			le.add_theme_font_size_override("font_size", theme.font_size(la["font"]))
		le.add_theme_color_override("font_color", Color(0.29, 0.17, 0.07))
		le.add_theme_color_override("caret_color", Color(0.29, 0.17, 0.07))
		le.add_theme_color_override("selection_color", Color(0.5, 0.4, 0.2, 0.4))
		le.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		le.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		w.text_editor = le
		w.editable = true
		le.text_changed.connect(func(t): w.text = t; w._bind_write(t))
		le.text_submitted.connect(func(_t):
			w.emit_action("onKeyPress")
			w.submit_form())
	# events
	for k in a:
		if k.begins_with("on"):
			w.events[k] = a[k]
	w.gui_event.connect(_on_event.bind(w))
	return w


func _type_name(tag: String) -> String:
	# theme element prefix: lowerCamel tag; some tags share theme types
	match tag:
		"texteditor":
			return "textEditor"
		"checkbox":
			return "checkBox"
		"comboboxplus", "comboBox":
			return "comboBox"
	return tag


func _parse_ldata(_tag: String, a: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	if a.has("size"):
		var parts: PackedStringArray = a["size"].split(",")
		d["size"] = [parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else parts[0].strip_edges()]
	if a.has("align"):
		d["align"] = a["align"]
	if a.has("data"):
		d["data"] = a["data"]
	for k in ["x", "y", "xOffset", "yOffset", "xPerc", "yPerc", "hgap", "vgap"]:
		if a.has(k):
			d[{"xOffset": "xOff", "yOffset": "yOff"}.get(k, k)] = float(a[k])
	return d


func _insets(s: String) -> Rect2:
	var v: PackedFloat64Array = s.split_floats(",")
	while v.size() < 4:
		v.append(0.0)
	return Rect2(v[2], v[0], v[3], v[1])


func _size_spec(s: String) -> Vector2:
	var p: PackedStringArray = s.split(",")
	return Vector2(float(p[0].strip_edges().rstrip("%")),
		float(p[1].strip_edges().rstrip("%")) if p.size() > 1 else 0)


func _color(s: String) -> Color:
	var v: PackedFloat64Array = s.split_floats(",")
	return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0) if v.size() >= 3 else Color.WHITE


func _pixmap(a: Dictionary) -> Dictionary:
	if a.has("ref"):
		return theme.pixmaps.get(a["ref"], {})
	return {
		"texture": a.get("texture", ""),
		"rect": Rect2(float(a.get("x", "0")), float(a.get("y", "0")),
			float(a.get("width", "0")), float(a.get("height", "0"))),
		"flip_h": a.get("flipHorizontaly", "false") == "true",
		"flip_v": a.get("flipVerticaly", "false") == "true",
	}


func _inline_border(p: XMLParser) -> Dictionary:
	var out: Dictionary = {}
	var depth := 1
	while depth > 0 and p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Pixmap":
			var px: Dictionary = _pixmap(_attrs(p))
			out[p.get_attribute_value(p.get_attribute_count() - 1)] = px
			var a: Dictionary = _attrs(p)
			out[a.get("position", "center")] = px
		elif p.get_node_type() == XMLParser.NODE_ELEMENT_END and p.get_node_name() == "PixmapBorder":
			depth -= 1
	return out


func _inline_pixmap(p: XMLParser) -> Dictionary:
	var depth := 1
	while depth > 0 and p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Pixmap":
			return _pixmap(_attrs(p))
		if p.get_node_type() == XMLParser.NODE_ELEMENT_END:
			depth -= 1
	return {}


func _attrs(p: XMLParser) -> Dictionary:
	var d: Dictionary = {}
	for i in p.get_attribute_count():
		d[p.get_attribute_name(i)] = p.get_attribute_value(i)
	return d


func _merge_appearance_into(w: GWidget, _tag: String, a: Dictionary) -> void:
	var state: String = a.get("state", "default")
	var tgt: Dictionary = _appear(w, state)
	for k in a:
		if k == "state":
			continue
		match k:
			"textColor":
				tgt["text_color"] = _color(a[k])
			_:
				tgt[k] = a[k]


func _appear(w: GWidget, state: String) -> Dictionary:
	if not w.states.has(state):
		w.states[state] = {}
	return w.states[state]


func i18n_str(s: String) -> String:
	var out: String = s
	var i := 0
	while true:
		var a := out.find("%", i)
		if a < 0:
			break
		var b := out.find("%", a + 1)
		if b < 0:
			break
		var key := out.substr(a + 1, b - a - 1)
		if i18n.has(key):
			out = out.substr(0, a) + String(i18n[key]) + out.substr(b + 1)
		else:
			i = b + 1
	return out


func _wire(root: GWidget) -> void:
	var todo := [root]
	while not todo.is_empty():
		var w: GWidget = todo.pop_back()
		for ch in w.get_children():
			if ch is GWidget:
				todo.append(ch)
		# a form with no layout of its own inherits its parent's layout
		if w.layout.is_empty() and w.kind == "form":
			var gp := w.get_parent()
			if gp is GWidget and not gp.layout.is_empty():
				w.layout = gp.layout.duplicate()
		# model binding
		if model != null:
			w.model = model
			if not w.bind.is_empty():
				model.watch(w, w.bind["name"], w.bind["field"])
				var v = model.get_value(w.bind["name"], w.bind["field"])
				if v != null:
					w.apply_model(v)


func _on_event(action: String, w: GWidget) -> void:
	# "dofusarena:logon(loginForm)" -> dispatch via dialog callback
	if dialog_cb.is_valid():
		dialog_cb.call(action, w, self)


var dialog_cb := Callable()


func resolve_arg(arg: String) -> Variant:
	if by_id.has(arg):
		return by_id[arg]
	return arg
