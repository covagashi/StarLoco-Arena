class_name GuiLoader
extends RefCounted
## XULOR2 XML loader — builds GWidget trees from assets/gui/xml/dialogs/*.xml.
## Port of ye_2's tag registry + DS.java's attribute semantics.

const WIDGET_TAGS := [
	"container", "button", "label", "image", "textView", "textEditor",
	"texteditor", "checkBox", "checkbox", "radioButton", "radioGroup",
	"comboboxplus", "comboBox", "list", "stackList", "form", "window", "scrollContainer",
	"slider", "progressBar", "tabbedContainer", "tree", "table", "map",
	"renderableContainer", "itemRenderer", "spacer", "separator", "iconLabel",
	"tabItem",
	"toggleButton", "stack", "progressIcon", "dnd", "windowMovePoint",
	"colorPicker", "text", "simpleMessage", "scrollBar",
	"animatedElementViewer", "elementEditor",
]
const COND_OPS := ["isNull", "isNotNull", "isTrue", "isFalse", "isGreater",
	"isLess", "isEqual", "isDifferent", "isNullOrEmpty", "isNotNullOrEmpty",
	"Not", "not", "and", "or"]
const LAYOUT_TAGS := ["sl", "bl", "rl", "gl", "tl", "SPL", "al"]
const LDATA_TAGS := ["sld", "bld", "rld", "gld", "tld", "spl", "ald"]

var theme: GuiTheme
var i18n := {}
var model: GuiModel
var by_id := {}          # id -> GWidget (per loaded dialog)
var data_ids := {}       # <data id> alias -> GWidget (per loaded dialog)
var unknown_tags := {}


func _init(t: GuiTheme, strings: Dictionary, m: GuiModel) -> void:
	theme = t
	i18n = strings
	model = m


var _depth := 0  # template/include recursion — ids + wire only at depth 0


func load_file(path: String) -> GWidget:
	var p := XMLParser.new()
	if p.open(path) != OK:
		push_error("[guiloader] cannot open " + path)
		return null
	_depth += 1
	if _depth == 1:
		by_id.clear()
		data_ids.clear()
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
						if a.has("color"):
							_appear(parent, "default")["plain_bg_color"] = \
								_color(a["color"])
				elif tag == "valueReplacer":
					# <property ...><valueReplacer key="size"/></property>
					var cframe4 = _cond_frame(stack)
					if cframe4 != null:
						var node4 := {"op": "valueReplacer",
							"key": a.get("key", ""), "children": []}
						if cframe4["cond_ops"].is_empty():
							cframe4["cond_root"].append(node4)
						else:
							cframe4["cond_ops"][-1]["children"].append(node4)
						cframe4["cond_ops"].append(node4)
				elif tag == "include":
					# <include id="x" path="../components/foo.xml"/> — graft a
					# component tree here under the local id
					if a.has("path") and parent != null:
						var sub := load_file(
							(path.get_base_dir() + "/" + a["path"])
								.simplify_path())
						if sub != null:
							if a.get("id", "") != "":
								sub.widget_id = a["id"]
								by_id[a["id"]] = sub
							parent.add_child(sub)
				elif tag == "template":
					# <template path="x.xml"> — the root is the template file;
					# children <templateElement> retarget its templateId anchors
					if stack.is_empty() and a.has("path"):
						root = load_file(
							(path.get_base_dir() + "/" + a["path"])
								.simplify_path())
						if not p.is_empty():
							stack.append({"w": null, "tag": tag})
				elif tag == "templateElement":
					# <templateElement templateRef="x"> — retarget the widget
					# in the template whose templateId == templateRef
					var tgt: GWidget = _find_template_id(
						root, a.get("templateRef", ""))
					if tgt != null:
						_apply_telem(tgt, a)
						if not p.is_empty():
							stack.append({"w": tgt, "tag": tag})
					elif not p.is_empty():
						stack.append({"w": null, "tag": tag})
				elif tag == "popup":
					# hover overlay owned by its parent widget
					var pw := GWidget.new()
					pw.guitheme = theme
					pw.kind = "container"
					pw.type_style = a.get("style", "")
					var pe: Dictionary = theme.elem("container", pw.type_style)
					pw.states = pe.get("states", {}).duplicate(true)
					if not pw.states.has("default"):
						pw.states["default"] = {}
					pw.set_meta("popup", true)
					pw.set_meta("popup_align", a.get("align", "south"))
					pw.visible = false
					pw.mouse_filter = Control.MOUSE_FILTER_IGNORE
					if parent != null:
						parent.add_child(pw)
						pw.position = Vector2(0, parent.size.y)
					if not p.is_empty():
						stack.append({"w": pw, "tag": tag})
				elif tag == "property":
					var cframe3 = _cond_frame(stack)
					if cframe3 != null:
						# <property name= attribute="comparedValue"> inside a
						# condition op — resolves a model value as operand
						var node3 := {"op": "propertyValue",
							"name": a.get("name", ""),
							"attribute": a.get("attribute", ""),
							"children": []}
						if cframe3["cond_ops"].is_empty():
							cframe3["cond_root"].append(node3)
						else:
							cframe3["cond_ops"][-1]["children"].append(node3)
						cframe3["cond_ops"].append(node3)
						if not p.is_empty():
							stack.append({"w": null, "tag": tag})
					elif parent != null:
						var b := {
							"attribute": a.get("attribute", ""),
							"name": a.get("name", ""),
							"field": a.get("field", ""),
						}
						var did := _data_id(stack)
						if did != "":
							b["data_id"] = did
						# widgets can carry several <property> binds
						# (animatedElementViewer has four) — keep them all
						parent.binds.append(b)
						parent.bind = b
				elif tag == "item":
					_parse_item(parent, a, stack)
					if not p.is_empty():
						stack.append({"w": null, "tag": tag})
				elif tag == "pixmap":
					# <image><pixmap><item attribute="texture" field="iconUrl"/></pixmap></image>
					var px_slot := {"attribute": "pixmap", "field": "",
						"item": true}
					if parent != null:
						parent.item_binds.append(px_slot)
					if not p.is_empty():
						stack.append({"w": null, "tag": tag,
							"bind_slot": px_slot})
				elif tag == "data":
					if not p.is_empty():
						stack.append({"w": parent, "tag": tag,
							"data_id": a.get("id", "")})
				elif tag == "condition":
					# condition tree built by child op nodes; assigned on END
					# (value=/elseValue= pick between two values on eval)
					var host = _bind_host(parent, stack)
					stack.append({"w": null, "tag": tag, "cond_root": [],
						"cond_ops": [], "cond_host": host,
						"cond_value": a.get("value", ""),
						"cond_else": a.get("elseValue", ""),
						"cond_ret": a.get("returnOriginalValue", "")})
				elif tag == "itemCondition" or tag == "listCondition":
					# scope nodes inside a <condition>/<and>/<or>: carry
					# their single child (and key for listCondition)
					var cframe2 = _cond_frame(stack)
					var node2 := {"op": tag, "key": a.get("key", ""),
						"children": []}
					if cframe2 != null:
						if cframe2["cond_ops"].is_empty():
							cframe2["cond_root"].append(node2)
						else:
							cframe2["cond_ops"][-1]["children"].append(node2)
						cframe2["cond_ops"].append(node2)
					if not p.is_empty():
						stack.append({"w": null, "tag": tag})
				elif tag in COND_OPS:
					var cframe = _cond_frame(stack)
					var node := {"op": tag, "value": a.get("value", ""),
						"children": []}
					if cframe != null:
						if cframe["cond_ops"].is_empty():
							cframe["cond_root"].append(node)
						else:
							cframe["cond_ops"][-1]["children"].append(node)
						cframe["cond_ops"].append(node)
					if not p.is_empty():
						stack.append({"w": null, "tag": tag})
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
						# only the direct child of an <itemRenderer> is the
						# row template — its descendants are just content
						if not stack.is_empty() \
								and stack[-1].get("tag") == "itemRenderer":
							w.visible = false
							var owner: GWidget = _nearest_list(parent)
							if owner != null:
								owner.renderers.append(
									{"cond": _renderer_cond(stack),
										"template": w})
								if owner.item_renderer == null:
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
				if tag in COND_OPS or tag == "itemCondition" or tag == "listCondition":
					var cframe = _cond_frame(stack)
					if cframe != null and not cframe["cond_ops"].is_empty():
						cframe["cond_ops"].pop_back()
				elif tag == "condition":
					for i in range(stack.size() - 1, -1, -1):
						if stack[i].get("tag") == tag:
							var fr: Dictionary = stack[i]
							var host = fr.get("cond_host")
							if host != null and not fr["cond_root"].is_empty():
								var tests: Array = []
								var cond_meta := {
									"value": fr.get("cond_value", ""),
									"elseValue": fr.get("cond_else", ""),
									"returnOriginalValue":
										fr.get("cond_ret", "")}
								# propertyValue children carry roles —
								# elseValue/comparedValue operands are not tests
								for n in fr["cond_root"]:
									match n.get("op"):
										"propertyValue":
											match n.get("attribute"):
												"elseValue":
													cond_meta["else_bind"] = n
												"comparedValue":
													cond_meta["cmp_bind"] = n
												_:
													tests.append(n)
										_:
											tests.append(n)
								if not tests.is_empty():
									cond_meta["tree"] = tests[0] \
										if tests.size() == 1 else \
											{"op": "and", "children": tests}
									host["condition"] = cond_meta
							stack.resize(i)
							break
					continue
				for i in range(stack.size() - 1, -1, -1):
					if stack[i].get("tag") == tag:
						stack.resize(i)
						break
	if _depth == 1 and root != null:
		_wire(root)
		# lists bind before their itemRenderer children register — rebuild now
		var all: Array = []
		_collect_widgets(root, all)
		for w in all:
			if is_instance_valid(w) and w.kind in ["list", "stackList", "comboboxplus", "comboBox"]:
				w.rebuild_items()
	_depth -= 1
	return root


## template support — find the widget in a template tree whose
## templateId matches, then graft the dialog's customisation onto it
func _find_template_id(w: GWidget, ref: String) -> GWidget:
	if w == null:
		return null
	if w.template_id == ref:
		return w
	for ch in w.get_children():
		if ch is GWidget:
			var r := _find_template_id(ch, ref)
			if r != null:
				return r
	return null


func _apply_telem(tgt: GWidget, a: Dictionary) -> void:
	if a.get("id", "") != "":
		tgt.widget_id = a["id"]
		by_id[a["id"]] = tgt
	if a.get("style", "") != "":
		tgt.type_style = a["style"]
		var e: Dictionary = theme.elem(tgt.kind, tgt.type_style)
		if not e.is_empty():
			tgt.states = e.get("states", {}).duplicate(true)
	if a.get("visible", "") == "false":
		tgt.visible = false
	if a.has("prefSize"):
		var v: PackedFloat64Array = a["prefSize"].split_floats(",")
		tgt.pref_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])


func _nearest_list(w: GWidget) -> GWidget:
	var n: Node = w
	while n != null:
		if n is GWidget and n.kind in ["list", "stackList", "comboboxplus", "comboBox"]:
			return n
		n = n.get_parent()
	return null


## condition parsed by the enclosing <itemRenderer><condition><itemCondition>
func _renderer_cond(stack: Array) -> Dictionary:
	for i in range(stack.size() - 1, -1, -1):
		var fr: Dictionary = stack[i]
		if fr.get("tag") == "itemRenderer":
			return fr.get("renderer_cond", {}).get("condition", {})
	return {}


static func _collect_widgets(n: Node, out: Array) -> void:
	if n is GWidget:
		out.append(n)
	for c in n.get_children():
		_collect_widgets(c, out)


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
	w.template_id = a.get("templateId", "")
	if tag == "animatedElementViewer":
		w.set_meta("viewer_scale", float(a.get("scale", "1")))
		w.set_meta("viewer_offy", float(a.get("offsetY", "0")))
		if a.get("animName", "") != "":
			w._viewer["anim"] = a["animName"]
	w.value = a.get("value", "")
	w.tabs_alignment = a.get("tabsAlignment", "north")
	w.expandable = a.get("expandable", "true") == "true"
	w.shrinkable = a.get("shrinkable", "true") == "true"
	w.password = a.get("password", "false") == "true"
	w.selected = a.get("selected", "false") == "true"
	w.horizontal = a.get("horizontal", "false") == "true"
	w.text = i18n_str(a.get("text", ""))
	if a.has("prefSize"):
		var v: PackedFloat64Array = a["prefSize"].split_floats(",")
		w.pref_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])
	if a.has("displaySize"):
		var v: PackedFloat64Array = a["displaySize"].split_floats(",")
		w.pref_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])
		w.min_size = w.pref_size
	if a.has("minSize"):
		var v: PackedFloat64Array = a["minSize"].split_floats(",")
		w.min_size = Vector2(v[0], v[1] if v.size() > 1 else v[0])
	if a.has("cellSize"):
		w.cell_size = _size_spec(a["cellSize"])
	if a.get("nonBlocking", "false") == "true":
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if a.get("visible", "true") == "false":
		w.visible = false
	if a.get("enabled", "true") == "false":
		w.enabled = false
	if a.get("focused", "false") == "true":
		w.set_meta("focused", true)
	# editor for textEditor
	if tag == "textEditor" or tag == "texteditor":
		var le := LineEdit.new()
		le.flat = true
		le.secret = w.password
		le.text = w.text
		if a.has("maxChars"):
			le.max_length = int(a["maxChars"])
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
		# model binding — one watcher per <property> bind
		if model != null:
			w.model = model
			for b in w.binds:
				if not b.has("name"):
					continue
				model.watch(w, b["name"], b.get("field", ""), b)
				var v = model.get_value(b["name"], b.get("field", ""))
				if v != null:
					w.apply_model(v, b)
		# <data id> aliases resolve event args
		if w.bind.has("data_id"):
			w.data_id = w.bind["data_id"]
		if w.data_id != "":
			data_ids[w.data_id] = w


func _on_event(action: String, w: GWidget) -> void:
	# "dofusarena:logon(loginForm)" -> dispatch via dialog callback
	if dialog_cb.is_valid():
		dialog_cb.call(action, w, self)


var dialog_cb := Callable()


func resolve_arg(arg: String) -> Variant:
	if by_id.has(arg):
		return by_id[arg]
	return arg


## enclosing <data id="X"> frame's id, or ""
func _data_id(stack: Array) -> String:
	for i in range(stack.size() - 1, -1, -1):
		var d: String = stack[i].get("data_id", "")
		if d != "":
			return d
	return ""


## nearest enclosing condition-building frame, or null
func _cond_frame(stack: Array):
	for i in range(stack.size() - 1, -1, -1):
		if stack[i].has("cond_root"):
			return stack[i]
	return null


## the dict a <condition> writes its tree into on close
func _bind_host(parent: GWidget, stack: Array):
	for i in range(stack.size() - 1, -1, -1):
		var fr: Dictionary = stack[i]
		if fr.has("bind_slot"):
			return fr["bind_slot"]
		if fr.has("data_id"):
			if parent != null:
				return parent.bind
			return null
		if fr.get("tag") == "itemRenderer":
			if not fr.has("renderer_cond"):
				fr["renderer_cond"] = {}
			return fr["renderer_cond"]
	if parent != null:
		if not parent.item_binds.is_empty():
			return parent.item_binds[-1]
		return parent.bind
	return null


## <item attribute="A" field="F"/> — item-level bind. Inside <data> it sets
## the parent's bind; inside <pixmap> it fills the bind_slot; elsewhere it
## appends to the parent's item_binds.
func _parse_item(parent: GWidget, a: Dictionary, stack: Array) -> void:
	for i in range(stack.size() - 1, -1, -1):
		var fr: Dictionary = stack[i]
		if fr.has("bind_slot"):
			fr["bind_slot"]["attribute"] = a.get("attribute", "texture")
			fr["bind_slot"]["field"] = a.get("field", "")
			return
	for i in range(stack.size() - 1, -1, -1):
		var fr: Dictionary = stack[i]
		if fr.has("data_id"):
			if parent != null:
				parent.bind = {"attribute": a.get("attribute", "value"),
					"field": a.get("field", ""), "item": true,
					"data_id": fr["data_id"]}
			return
	if parent != null:
		parent.item_binds.append({"attribute": a.get("attribute", "value"),
			"field": a.get("field", ""), "item": true})
