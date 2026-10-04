class_name GuiLayouts
extends RefCounted
## Static layout appliers — ports of azC (StaticLayout), et_1 (BorderLayout),
## ei_1 (RowLayout), ane_2 (GridLayout). Called from GWidget on resize.

const ALIGN := {
	"north": Vector2(0.5, 0.0), "north_east": Vector2(1.0, 0.0),
	"east": Vector2(1.0, 0.5), "south_east": Vector2(1.0, 1.0),
	"south": Vector2(0.5, 1.0), "south_west": Vector2(0.0, 1.0),
	"west": Vector2(0.0, 0.5), "north_west": Vector2(0.0, 0.0),
	"center": Vector2(0.5, 0.5),
}


static func apply(c: GWidget) -> void:
	if c.layout.is_empty():
		return
	match c.layout.get("type", ""):
		"sl":
			_static(c)
		"bl":
			_border(c)
		"rl":
			_row(c)
		"gl":
			_grid(c)


static func content_size(c: GWidget) -> Vector2:
	var cr := c.content_rect()
	return cr.size


static func _content_origin(c: GWidget) -> Vector2:
	return c.content_rect().position


static func _visible_children(c: GWidget) -> Array:
	var out := []
	for ch in c.get_children():
		if ch is GWidget and ch.visible:
			out.append(ch)
	return out


static func _child_pref(ch: GWidget) -> Vector2:
	if ch.pref_size.x >= 0 and ch.pref_size.y >= 0:
		return ch.pref_size
	var s: Vector2 = ch.get_minimum_size()
	if ch.pref_size.x >= 0:
		s.x = ch.pref_size.x
	if ch.pref_size.y >= 0:
		s.y = ch.pref_size.y
	return s


## ---- StaticLayout (azC) ----------------------------------------------
static func _static(c: GWidget) -> void:
	var o := _content_origin(c)
	var cs := content_size(c)
	for ch in _visible_children(c):
		var ld: Dictionary = ch.layout_data
		var want := _child_pref(ch)
		var size := want
		if ld.has("size"):
			var sv: Array = ld["size"]
			if sv[0] is String and String(sv[0]).ends_with("%"):
				size.x = cs.x * float(String(sv[0]).rstrip("%")) / 100.0
			elif float(sv[0]) == -2:
				size.x = want.x
			elif float(sv[0]) >= 0:
				size.x = float(sv[0])
			if sv[1] is String and String(sv[1]).ends_with("%"):
				size.y = cs.y * float(String(sv[1]).rstrip("%")) / 100.0
			elif float(sv[1]) == -2:
				size.y = want.y
			elif float(sv[1]) >= 0:
				size.y = float(sv[1])
		var pos := Vector2()
		if ld.has("x"):
			pos.x = float(ld["x"])
		elif ld.has("xPerc"):
			pos.x = cs.x * float(ld["xPerc"]) / 100.0
		else:
			var ax: float = ALIGN.get(String(ld.get("align", "north_west")).to_lower(), Vector2.ZERO).x
			pos.x = ax * (cs.x - size.x)
		if ld.has("y"):
			pos.y = float(ld["y"])
		elif ld.has("yPerc"):
			pos.y = cs.y * float(ld["yPerc"]) / 100.0
		else:
			var ay: float = ALIGN.get(String(ld.get("align", "north_west")).to_lower(), Vector2.ZERO).y
			pos.y = ay * (cs.y - size.y)
		pos.x += float(ld.get("xOff", 0))
		pos.y += float(ld.get("yOff", 0))
		ch.position = o + pos
		ch.size = size
		GuiLayouts.apply(ch)


## ---- BorderLayout (et_1) ----------------------------------------------
static func _border(c: GWidget) -> void:
	var o := _content_origin(c)
	var cs := content_size(c)
	var hgap: float = float(c.layout.get("hgap", 0))
	var vgap: float = float(c.layout.get("vgap", 0))
	var by := {}
	for ch in _visible_children(c):
		by[String(ch.layout_data.get("data", "center")).to_lower()] = ch
	var left := 0.0
	var right := cs.x
	var top := 0.0
	var bottom := cs.y
	if by.has("north"):
		var ch: GWidget = by["north"]
		var p := _child_pref(ch)
		var w := right - left if ch.expandable else p.x
		ch.size = Vector2(w, p.y)
		ch.position = o + Vector2(left + (0.0 if ch.expandable else (right - left - w) / 2.0), top)
		top += p.y + vgap
		GuiLayouts.apply(ch)
	if by.has("south"):
		var ch: GWidget = by["south"]
		var p := _child_pref(ch)
		var w := right - left if ch.expandable else p.x
		ch.size = Vector2(w, p.y)
		ch.position = o + Vector2(left + (0.0 if ch.expandable else (right - left - w) / 2.0), bottom - p.y)
		bottom -= p.y + vgap
		GuiLayouts.apply(ch)
	if by.has("east"):
		var ch: GWidget = by["east"]
		var p := _child_pref(ch)
		var h := bottom - top if ch.expandable else p.y
		ch.size = Vector2(p.x, h)
		ch.position = o + Vector2(right - p.x, top + (0.0 if ch.expandable else (bottom - top - h) / 2.0))
		right -= p.x + hgap
		GuiLayouts.apply(ch)
	if by.has("west"):
		var ch: GWidget = by["west"]
		var p := _child_pref(ch)
		var h := bottom - top if ch.expandable else p.y
		ch.size = Vector2(p.x, h)
		ch.position = o + Vector2(left, top + (0.0 if ch.expandable else (bottom - top - h) / 2.0))
		left += p.x + hgap
		GuiLayouts.apply(ch)
	if by.has("center"):
		var ch: GWidget = by["center"]
		if ch.expandable:
			ch.size = Vector2(right - left, bottom - top)
			ch.position = o + Vector2(left, top)
		else:
			var p := _child_pref(ch)
			ch.size = p
			ch.position = o + Vector2(left + (right - left - p.x) / 2.0,
				top + (bottom - top - p.y) / 2.0)
		GuiLayouts.apply(ch)


## ---- RowLayout (ei_1) ---------------------------------------------------
static func _row(c: GWidget) -> void:
	var o := _content_origin(c)
	var cs := content_size(c)
	var hgap: float = float(c.layout.get("hgap", 0))
	var vgap: float = float(c.layout.get("vgap", 0))
	var horiz: bool = c.layout.get("horizontal", "false") == "true"
	var kids := _visible_children(c)
	if horiz:
		var content_w := cs.x - 2 * hgap
		var content_h := cs.y - 2 * vgap
		var pref_total := 0.0
		var n_expand := 0
		for ch in kids:
			pref_total += _child_pref(ch).x
			if ch.expandable:
				n_expand += 1
		pref_total += max(0, kids.size() - 1) * hgap
		var leftover: float = max(0.0, content_w - pref_total)
		var share := leftover / n_expand if n_expand > 0 else 0.0
		var rem := leftover - share * n_expand
		var x := hgap + (0.0 if n_expand > 0 else _row_align(c) * (content_w - pref_total))
		for ch in kids:
			var p := _child_pref(ch)
			var w := p.x
			if ch.expandable and n_expand > 0:
				w += share
				if rem > 0:
					w += 1
					rem -= 1
			var h := content_h
			var y := 0.0
			if not ch.layout_data.is_empty() and ch.layout_data.has("align"):
				var ay: float = ALIGN.get(String(ch.layout_data["align"]).to_lower(), Vector2(0.5, 0.5)).y
				h = p.y
				y = ay * (content_h - h)
			ch.size = Vector2(w, h)
			ch.position = o + Vector2(x, vgap + y)
			x += w + hgap
			GuiLayouts.apply(ch)
	else:
		var content_w2 := cs.x - 2 * hgap
		var content_h2 := cs.y - 2 * vgap
		var pref_total2 := 0.0
		var n_expand2 := 0
		for ch in kids:
			pref_total2 += _child_pref(ch).y
			if ch.expandable:
				n_expand2 += 1
		pref_total2 += max(0, kids.size() - 1) * vgap
		var leftover2: float = max(0.0, content_h2 - pref_total2)
		var share2 := leftover2 / n_expand2 if n_expand2 > 0 else 0.0
		var rem2 := leftover2 - share2 * n_expand2
		var y2 := vgap + (0.0 if n_expand2 > 0 else _row_align_v(c) * (content_h2 - pref_total2))
		for ch in kids:
			var p := _child_pref(ch)
			var h := p.y
			if ch.expandable and n_expand2 > 0:
				h += share2
				if rem2 > 0:
					h += 1
					rem2 -= 1
			var w := content_w2
			var x2 := 0.0
			if not ch.layout_data.is_empty() and ch.layout_data.has("align"):
				var ax: float = ALIGN.get(String(ch.layout_data["align"]).to_lower(), Vector2(0.5, 0.5)).x
				w = p.x
				x2 = ax * (content_w2 - w)
			ch.size = Vector2(w, h)
			ch.position = o + Vector2(hgap + x2, y2)
			y2 += h + vgap
			GuiLayouts.apply(ch)


static func _row_align(c: GWidget) -> float:
	return ALIGN.get(String(c.layout.get("align", "center")).to_lower(), Vector2(0.5, 0.5)).x


static func _row_align_v(c: GWidget) -> float:
	return ALIGN.get(String(c.layout.get("align", "center")).to_lower(), Vector2(0.5, 0.5)).y


## ---- GridLayout (ane_2) — cells share space evenly -----------------------
static func _grid(c: GWidget) -> void:
	var o := _content_origin(c)
	var cs := content_size(c)
	var kids := _visible_children(c)
	var cols := int(c.layout.get("numColumns", 0))
	var rows := int(c.layout.get("numRows", 0))
	if cols <= 0 and rows <= 0:
		cols = ceili(sqrt(float(kids.size())))
		rows = ceili(float(kids.size()) / cols)
	elif cols <= 0:
		cols = ceili(float(kids.size()) / rows)
	elif rows <= 0:
		rows = ceili(float(kids.size()) / cols)
	var cw := cs.x / cols
	var chh := cs.y / rows
	for i in kids.size():
		var ch: GWidget = kids[i]
		var col := i % cols
		var row := i / cols
		ch.position = o + Vector2(col * cw, row * chh)
		ch.size = Vector2(cw, chh)
		GuiLayouts.apply(ch)
