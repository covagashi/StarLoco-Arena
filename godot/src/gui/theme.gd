class_name GuiTheme
extends RefCounted
## XULOR2 theme loader — parses assets/gui/xml/theme/default.xml.
## Resource registries: textures/pixmaps/pixmap_borders/pixmap_backgrounds/
## colors/fonts/cursors, plus per-widget theme elements keyed "typeStyle"
## (e.g. "buttonGreen") holding per-state appearance dicts.

const GUI_ROOT := "res://assets/gui/"

var textures := {}        # id -> image path (res://...png)
var pixmaps := {}         # id -> {texture: String, rect: Rect2, flip_h: bool, flip_v: bool}
var pixmap_borders := {}  # id -> {pos_name -> {texture, rect, flip_h, flip_v}}
var pixmap_bgs := {}      # id -> {pixmap: {...}, scaled: bool, enabled: bool}
var colors := {}          # id -> Color
var fonts := {}           # id -> {path, size, style, aa}
var cursors := {}
var elements := {}        # "buttonGreen" -> {margin: Insets, states: {state -> appearance_dict}}
var tooltip := {}

var _tex_cache := {}      # res path -> Texture2D
var _atlas_cache := {}    # "tex|x,y,w,h" -> AtlasTexture
var _font_cache := {}     # font id -> FontFile
var _image_index := {}    # basename.png -> res path (built lazily)


func _init(path := GUI_ROOT + "xml/theme/default.xml") -> void:
	load_theme(path)


func load_theme(path: String) -> void:
	var p := XMLParser.new()
	if p.open(path) != OK:
		push_error("[guitheme] cannot open " + path)
		return
	# element name stack so we know whether an appearance tag belongs to a
	# themeElement inside a <typeStyle> wrapper or to an init resource.
	var stack: Array[String] = []
	var elem_stack: Array[String] = []  # theme-element name stack (nesting-safe)
	var cur_element := ""        # current <typeStyle> name
	var cur_state := "default"
	var cur_appear := {}         # appearance dict being filled
	var cur_border_id := ""      # inside <PixmapBorder id>
	var cur_bg_id := ""
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := p.get_node_name()
				var a := _attrs(p)
				stack.append(tag)
				match tag:
					"font":
						fonts[a.get("id", "")] = _parse_font_decl(a)
					"color":
						if a.has("id"):
							colors[a["id"]] = _parse_color(a.get("color", "1,1,1,1"))
					"cursor":
						cursors[a.get("id", "")] = a
					"texture":
						textures[a.get("id", "")] = _resolve_image(a.get("path", ""))
					"tooltip":
						tooltip = a
					"Pixmap":
						var px := _parse_pixmap(a)
						if cur_border_id != "":
							pixmap_borders[cur_border_id][px["position"]] = px
						elif cur_bg_id != "":
							pixmap_bgs[cur_bg_id]["pixmap"] = px
						elif a.has("id"):
							pixmaps[a["id"]] = px
						elif cur_element != "":
							# inline pixmap inside an appearance
							cur_appear["pixmap"] = px
					"PixmapBorder":
						if a.has("id"):
							cur_border_id = a["id"]
							pixmap_borders[cur_border_id] = {}
						elif a.has("ref"):
							cur_appear["border"] = a["ref"]
						else:
							cur_appear["border_inline"] = {}
							cur_border_id = "__inline__"
							pixmap_borders["__inline__"] = {}
					"PixmapBackground":
						if a.has("id"):
							cur_bg_id = a["id"]
							pixmap_bgs[cur_bg_id] = {
								"scaled": a.get("scaled", "false") == "true",
								"enabled": a.get("enabled", "true") == "true",
								"pixmap": {},
							}
						elif a.has("ref"):
							cur_appear["bg"] = a["ref"]
						else:
							cur_bg_id = "__inlinebg__"
							pixmap_bgs[cur_bg_id] = {
								"scaled": a.get("scaled", "false") == "true",
								"enabled": a.get("enabled", "true") == "true",
								"pixmap": {},
							}
					"PlainBackground":
						cur_appear["plain_bg"] = true
					"margin":
						var ins := _parse_insets(a.get("insets", a.get("spacing", "0,0,0,0")))
						if cur_element != "":
							cur_appear["margin"] = ins
						# margin can also hang directly under themeElement
						elif stack.size() >= 2 and stack[-2] == "themeElement":
							pass
					"Font":
						if a.has("ref"):
							cur_appear["font"] = a["ref"]
					"Color":
						if a.has("ref"):
							cur_appear["color"] = a["ref"]
						elif a.has("color"):
							cur_appear["color_value"] = _parse_color(a["color"])
					"themeElement", "ThemeElement":
						# may carry name="..." for engine-internal elements —
						# scope it under the enclosing type wrapper so that
						# <window><themeElement name="content"> registers as
						# "windowContent" (flat "content" collides across the
						# six different parents that define one)
						var nm: String = a.get("name", "")
						if nm != "":
							var par := ""
							for i in range(elem_stack.size() - 1, -1, -1):
								if elem_stack[i] != "":
									par = elem_stack[i]
									break
							cur_element = par + nm.capitalize() if par != "" else nm
						elem_stack.append(nm)
					_:
						if tag.ends_with("Appearance"):
							# appearance decl — attrs on the tag itself
							cur_state = a.get("state", "default")
							cur_appear = _parse_appearance_tag(tag, a)
						elif tag[0] == tag[0].to_lower() and \
								not tag in ["init", "theme", "initResources"]:
							# top-level <typeStyle> element wrapper
							elem_stack.append(tag)
							cur_element = tag
			XMLParser.NODE_ELEMENT_END:
				var tag: String = p.get_node_name()
				match tag:
					"PixmapBorder":
						if cur_border_id == "__inline__":
							cur_appear["border_inline"] = pixmap_borders["__inline__"]
							pixmap_borders.erase("__inline__")
						cur_border_id = ""
					"PixmapBackground":
						if cur_bg_id == "__inlinebg__":
							cur_appear["bg_inline"] = pixmap_bgs["__inlinebg__"]
							pixmap_bgs.erase("__inlinebg__")
						cur_bg_id = ""
					"themeElement", "ThemeElement":
						if not elem_stack.is_empty():
							elem_stack.pop_back()
						cur_element = elem_stack[-1] if not elem_stack.is_empty() else ""
					_:
						if tag.ends_with("Appearance") and cur_element != "":
							if not elements.has(cur_element):
								elements[cur_element] = {"margin": null, "states": {}}
							var st: Dictionary = elements[cur_element]["states"]
							st[cur_state] = _merge_appearance(st.get(cur_state, {}), cur_appear)
							cur_appear = {}
							cur_state = "default"
						elif not elem_stack.is_empty() and tag == elem_stack[-1]:
							# a margin that landed before any appearance
							if cur_appear.has("margin"):
								if not elements.has(cur_element):
									elements[cur_element] = {"margin": null, "states": {}}
								elements[cur_element]["margin"] = cur_appear["margin"]
								cur_appear.erase("margin")
							elem_stack.pop_back()
							cur_element = elem_stack[-1] if not elem_stack.is_empty() else ""


## Resolve one theme element for a widget type + style.
## <button style="green"> -> "buttonGreen"; empty style -> "button".
func elem(type: String, style: String = "") -> Dictionary:
	var key := type + style.capitalize()
	if elements.has(key):
		return elements[key]
	if elements.has(type):
		return elements[type]
	return {}


func color(id: String) -> Color:
	return colors.get(id, Color(1, 1, 1, 1))


func font(id: String) -> Font:
	if _font_cache.has(id):
		return _font_cache[id]
	var d: Dictionary = fonts.get(id, {})
	var f := FontFile.new()
	var p: String = d.get("path", "")
	if p != "" and FileAccess.file_exists(GUI_ROOT + p):
		f.load_dynamic_font(GUI_ROOT + p)
	else:
		f.load_dynamic_font(GUI_ROOT + "fonts/TAHOMA.TTF")
	_font_cache[id] = f
	return f


func font_size(id: String) -> int:
	return int(fonts.get(id, {}).get("size", 12))


func font_bordered(id: String) -> bool:
	return String(fonts.get(id, {}).get("style", "plain")).contains("border")


func texture(id: String) -> Texture2D:
	var p: String = textures.get(id, "")
	if p == "":
		return null
	if _tex_cache.has(p):
		return _tex_cache[p]
	var t: Texture2D = null
	var img := Image.new()
	if img.load(p) == OK:
		t = ImageTexture.create_from_image(img)
	_tex_cache[p] = t
	return t


## AtlasTexture for a pixmap dict {texture, rect, flip_h, flip_v}.
## AtlasTexture can't flip — flipped variants are whole-texture flips cached
## under a synthetic id ("id|h" / "id|v" / "id|hv").
func pixmap_tex(px: Dictionary) -> AtlasTexture:
	if px.is_empty():
		return null
	var tid: String = px.get("texture", "")
	var fh: bool = px.get("flip_h", false)
	var fv: bool = px.get("flip_v", false)
	var tex := texture(tid)
	var r: Rect2 = px.get("rect", Rect2())
	if (fh or fv) and tex != null:
		var fkey := "%s|%s%s" % [tid, "h" if fh else "", "v" if fv else ""]
		if _tex_cache.has(fkey):
			tex = _tex_cache[fkey]
		else:
			var img := tex.get_image()
			if fh:
				img.flip_x()
			if fv:
				img.flip_y()
			tex = ImageTexture.create_from_image(img)
			_tex_cache[fkey] = tex
		var w := tex.get_width()
		var h := tex.get_height()
		if fh:
			r.position.x = w - r.position.x - r.size.x
		if fv:
			r.position.y = h - r.position.y - r.size.y
	if tex == null:
		return null
	var key := "%s|%s|%d|%d" % [tid, r, int(fh), int(fv)]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = r
	_atlas_cache[key] = at
	return at


func pixmap_id(id: String) -> AtlasTexture:
	return pixmap_tex(pixmaps.get(id, {}))


func border(id: String) -> Dictionary:
	return pixmap_borders.get(id, {})


func background(id: String) -> Dictionary:
	return pixmap_bgs.get(id, {})


func _attrs(p: XMLParser) -> Dictionary:
	var d := {}
	for i in p.get_attribute_count():
		d[p.get_attribute_name(i)] = p.get_attribute_value(i)
	return d


func _parse_font_decl(a: Dictionary) -> Dictionary:
	# font="-plain-12" -> style "plain", size 12
	var spec: String = a.get("font", "-plain-12")
	var parts := spec.split("-")
	var style := parts[1] if parts.size() > 1 else "plain"
	var sz := int(parts[2]) if parts.size() > 2 else 12
	return {"path": a.get("path", ""), "size": sz, "style": style,
		"aa": a.get("antialiased", "false") == "true"}


func _parse_color(s: String) -> Color:
	var v := s.split_floats(",")
	return Color(v[0], v[1], v[2], v[3] if v.size() > 3 else 1.0) if v.size() >= 3 else Color.WHITE


func _parse_insets(s: String) -> Rect2:
	# insets="top,bottom,left,right" -> Rect2(x=left, y=top, w=right, h=bottom)
	var v := s.split_floats(",")
	while v.size() < 4:
		v.append(0.0)
	return Rect2(v[2], v[0], v[3], v[1])


func _parse_pixmap(a: Dictionary) -> Dictionary:
	if a.has("ref"):
		return pixmaps.get(a["ref"], {})
	var r := Rect2(float(a.get("x", "0")), float(a.get("y", "0")),
		float(a.get("width", "0")), float(a.get("height", "0")))
	return {
		"texture": a.get("texture", ""),
		"rect": r,
		"position": a.get("position", "center"),
		"flip_h": a.get("flipHorizontaly", "false") == "true",
		"flip_v": a.get("flipVerticaly", "false") == "true",
	}


func _parse_appearance_tag(tag: String, a: Dictionary) -> Dictionary:
	var d := {"_kind": tag}
	if a.has("alignment"):
		d["alignment"] = a["alignment"].to_lower()
	if a.has("textColor"):
		d["text_color"] = _parse_color(a["textColor"])
	return d


func _merge_appearance(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for k in over:
		out[k] = over[k]
	return out


func _resolve_image(path: String) -> String:
	# "images/loginBackground.tga" -> assets/gui/images/theme/images/loginBackground.png
	var bn := path.get_file().get_basename() + ".png"
	var direct := GUI_ROOT + "images/theme/images/" + bn
	if FileAccess.file_exists(direct):
		return direct
	if _image_index.is_empty():
		_scan_images(GUI_ROOT + "images")
	return _image_index.get(bn, direct)


func _scan_images(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		var p := dir_path + "/" + f
		if d.current_is_dir():
			if not f.begins_with("."):
				_scan_images(p)
		elif f.ends_with(".png"):
			_image_index[f] = p
		f = d.get_next()
	d.list_dir_end()
