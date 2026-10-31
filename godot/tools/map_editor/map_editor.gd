extends Control

## M7 (S36 phase C): the owner's arena editor. It loads an arena's shape
## (the fight topology: cells, altitudes, obstacles, start cells; never
## edited) and lets the owner place our kiln pieces on it, seen exactly as
## the game shows them: orthographic 2:1, 86-px cells at "escala de juego",
## the game's light. Saves art/layouts/arena-NN.json (arena_layout.gd).
##
##   godot --path godot tools/map_editor/map_editor.tscn [-- --arena=N]
##
## Mouse: left = the tool (paint while dragging blocks and caps), right =
## remove the cell's top piece, Alt+left = eyedropper, Shift+left = put the
## decoration on top of the cell's highest one, middle drag or Space+drag =
## pan, wheel = zoom. Keys: see HELP.

const Layout := preload("res://src/maps/arena_layout.gd")
const ArenaScene := preload("res://src/maps/arena_scene.gd")
const MapGfx := preload("res://src/maps/map_gfx.gd")

const HELP := """[b]Ratón[/b]
Izq.: herramienta (arrastra para pintar suelos)
Der.: quitar la pieza de arriba
Alt+izq.: cuentagotas · Mayús+izq.: apilar encima
Rueda: zoom · botón central o Espacio+arrastrar: mover

[b]Teclas[/b]
B pincel · S seleccionar · X borrar · I cuentagotas
C casillas: clic pone el papel elegido (suelo, obstáculo,
  salida 1 o 2), arrastra para varias; der.: el original
1 2 3: loom a b c
R / Mayús+R: girar 90° · , y . : girar 15°
F: reflejar · + y −: escala
AvPág / RePág: subir / bajar (Mayús: más)
Ctrl+flechas: desplazar (Mayús: más) · Inicio: centrar
Supr: quitar la seleccionada · Esc: deseleccionar
Flechas: mover la vista · G rejilla · V retail
Ctrl+Z / Ctrl+Y: deshacer / rehacer · Ctrl+S: guardar
H: esta ayuda"""

const KIND_NAMES := {"tile": "bloque de suelo", "cap": "capa sobre el bloque",
	"flat": "plana, sobre la casilla", "deco": "decoración", "side": "por un lado",
	"wall": "en una pared", "cliff": "acantilado"}
const GROUPS := [["Todo", []], ["Suelos", ["tile", "cap"]], ["Planas", ["flat"]],
	["Decoración", ["deco", "side", "wall", "cliff"]]]
const ROLE_COLORS := {"floor": Color(1, 1, 1, 0.16), "obstacle": Color(1.0, 0.35, 0.3, 0.55),
	"team0": Color(0.3, 0.6, 1.0, 0.75), "team1": Color(1.0, 0.45, 0.25, 0.75),
	"coach": Color(1.0, 0.82, 0.3, 0.8)}
const ROLE_NAMES := {"floor": "suelo", "obstacle": "obstáculo", "team0": "salida equipo 1",
	"team1": "salida equipo 2", "coach": "pedestal del entrenador"}
const TINTS := ["ffffff", "e8e0ff", "d6e6ff", "ffe6c8", "e0f0d0", "c8c8c8", "a0a0a0", "ffd0d0"]
const THUMB := 72

var arena := 1
var shape := {}
var layout := {}
var builder := ArenaScene.new()
var palette := []
var brush := {}
var tool := "paint"
## the fight role the cells tool gives a cell
var cell_role := "obstacle"
## {"cell": Vector2i, "i": int} or {}
var selected := {}
var random_rot := false
var dirty := false
var zoom := 1.0
var show_grid := true

var _undo := []
var _redo := []
var _cells := {}          # Vector2i -> Node3D
var _hover = null         # Vector2i or null
var _painting := false
var _last_paint = null
var _panning := false
var _space := false
var _group := 0
var _all := false
var _thumbs := {}         # "kit/piece" -> Texture2D
var _thumb_queue := []
var _thumb_busy := false

var _vp: SubViewport
var _vpc: SubViewportContainer
var _world: Node3D
var _cam: Camera3D
var _overlay: MeshInstance3D
var _hover_mesh: MeshInstance3D
var _sel_mesh: MeshInstance3D
var _retail_layer: CanvasLayer
var _retail: Node2D
var _retail_ok := false

var _arena_pick: OptionButton
var _status: Label
var _hover_label: Label
var _list: ItemList
var _search: LineEdit
var _scope: OptionButton
var _group_bar: HBoxContainer
var _piece_label: Label
var _piece_note: Label
var _tool_buttons := {}
var _loom_buttons := []
var _rot_label: Label
var _flip_check: CheckBox
var _scale_slider: HSlider
var _scale_label: Label
var _tint_button: ColorPickerButton
var _off_label: Label
var _rand_check: CheckBox
var _fill_button: Button
var _cell_label: Label
var _role_buttons := {}
var _starts_label: Label
var _grid_check: CheckButton
var _retail_check: CheckButton
var _retail_alpha: HSlider
var _help: PanelContainer
var _syncing := false


func _ready() -> void:
	get_window().title = "Editor de arenas — Pippop Arena"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arena="):
			arena = clampi(int(a.substr(8)), 1, Layout.WORLDS.size())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_view()
	# the view's size settles after the first layout pass; fit to it
	await get_tree().process_frame
	await get_tree().process_frame
	load_arena(arena)


func _notification(what: int) -> void:
	# the owner's work is never lost: closing the window saves
	if what == NOTIFICATION_WM_CLOSE_REQUEST and dirty:
		save()


# --- arena ---------------------------------------------------------------

func load_arena(n: int) -> void:
	if dirty:
		save()
	arena = n
	_arena_pick.select(n - 1)
	shape = Layout.shape(Layout.world_of(n))
	layout = Layout.load_layout(n)
	Layout.apply_roles(shape, layout.roles)
	_undo.clear()
	_redo.clear()
	selected = {}
	dirty = false
	for c in _cells.values():
		c.queue_free()
	_cells.clear()
	for p: Vector2i in layout.cells:
		_rebuild_cell(p)
	_rebuild_overlay()
	_load_retail()
	_fill_palette()
	if brush.is_empty() or _palette_index(brush.kit, brush.piece) < 0:
		var first := _first_of_kind("tile")
		if first >= 0:
			_pick_piece(first)
			_select_palette(brush.kit, brush.piece)
	fit_view()
	_refresh_inspector()
	_update_status()


func save() -> void:
	var err := Layout.save_layout(layout)
	if err == OK:
		dirty = false
		_update_status("Guardado en " + Layout.layout_path(arena).trim_prefix("res://"))
	else:
		_update_status("No se pudo guardar: " + error_string(err))


# --- edits (all go through _commit so they can be undone) ------------------

func _snapshot() -> void:
	_undo.append(_state())
	if _undo.size() > 300:
		_undo.pop_front()
	_redo.clear()


func _commit(changed: Array) -> void:
	dirty = true
	for p in changed:
		_rebuild_cell(p)
	_rebuild_overlay()
	_refresh_selection()
	_update_status()


func undo() -> void:
	_swap(_undo, _redo)


func redo() -> void:
	_swap(_redo, _undo)


## What undo keeps: the pieces and the role changes.
func _state() -> Dictionary:
	return {"cells": layout.cells.duplicate(true), "roles": layout.roles.duplicate()}


func _swap(from: Array, to: Array) -> void:
	if from.is_empty():
		return
	var before: Dictionary = layout.cells
	to.append(_state())
	var st: Dictionary = from.pop_back()
	layout.cells = st.cells
	layout.roles = st.roles
	Layout.apply_roles(shape, layout.roles)
	var changed := {}
	for p in before:
		if not layout.cells.has(p) or layout.cells[p] != before[p]:
			changed[p] = true
	for p in layout.cells:
		if not before.has(p):
			changed[p] = true
	selected = {}
	_commit(changed.keys())


func _items(p: Vector2i) -> Array:
	return layout.cells.get(p, [])


func _set_items(p: Vector2i, items: Array) -> void:
	if items.is_empty():
		layout.cells.erase(p)
	else:
		layout.cells[p] = items


## Puts the brush on cell p. stack: on top of the cell's highest decoration.
func place(p: Vector2i, stack := false, snap := true) -> void:
	if brush.is_empty() or not shape.cells.has(p):
		return
	var it: Dictionary = brush.duplicate(true)
	if random_rot:
		it.rot = float(randi() % 4 * 90)
	if stack and not Layout.kind_of(it) in ["tile", "cap"]:
		it.off[1] = _stack_top(p)
	var items := Layout.add_item(_items(p), it)
	if snap:
		_snapshot()
	_set_items(p, items)
	selected = {"cell": p, "i": items.size() - 1}
	_commit([p])


## Removes the top piece of cell p.
func remove_top(p: Vector2i) -> void:
	var items := _items(p).duplicate()
	var i := Layout.top_index(items)
	if i < 0:
		return
	_remove(p, i)


func _remove(p: Vector2i, i: int) -> void:
	var items := _items(p).duplicate()
	_snapshot()
	items.remove_at(i)
	_set_items(p, items)
	selected = {}
	_commit([p])


## Every shape cell without a block (or a cap, for a cap brush) gets the brush.
func fill_empty() -> void:
	var kind := Layout.kind_of(brush)
	if not kind in ["tile", "cap"]:
		return
	var changed := []
	for p: Vector2i in shape.cells:
		var has := false
		for x: Dictionary in _items(p):
			if Layout.kind_of(x) == kind:
				has = true
		if has:
			continue
		if changed.is_empty():
			_snapshot()
		var it: Dictionary = brush.duplicate(true)
		if random_rot:
			it.rot = float(randi() % 4 * 90)
		_set_items(p, Layout.add_item(_items(p), it))
		changed.append(p)
	if not changed.is_empty():
		_commit(changed)
		_update_status("Rellenadas %d casillas" % changed.size())


## Gives cell p the fight role r (the cells tool). Its role from the fight
## data is kept apart, so giving it back removes the change. snap = false
## inside a drag, so the stroke is one undo step.
func set_role(p: Vector2i, r: String, snap := true) -> void:
	if not shape.cells.has(p) or not r in Layout.EDITABLE_ROLES:
		return
	var c: Dictionary = shape.cells[p]
	if c.base_role == "coach" or c.role == r:
		return
	if snap:
		_snapshot()
	if r == c.base_role:
		layout.roles.erase(p)
	else:
		layout.roles[p] = r
	Layout.apply_roles(shape, layout.roles)
	dirty = true
	_rebuild_overlay()
	_update_status()
	_update_hover_label()


## Cell p back to its role from the fight data.
func reset_role(p: Vector2i) -> void:
	if shape.cells.has(p):
		set_role(p, shape.cells[p].base_role)


func clear_all() -> void:
	if layout.cells.is_empty():
		return
	_snapshot()
	var changed: Array = layout.cells.keys()
	layout.cells = {}
	selected = {}
	_commit(changed)


## Applies f(item) to the brush and to the selected piece.
func edit(f: Callable) -> void:
	f.call(brush)
	if not selected.is_empty():
		var p: Vector2i = selected.cell
		var items := _items(p).duplicate(true)
		if selected.i < items.size():
			_snapshot()
			f.call(items[selected.i])
			_set_items(p, items)
			_commit([p])
	_refresh_inspector()


func set_loom(l: String) -> void:
	edit(func(it: Dictionary) -> void: it.loom = l)


func turn(deg: float) -> void:
	edit(func(it: Dictionary) -> void: it.rot = fposmod(it.rot + deg, 360.0))


func flip() -> void:
	edit(func(it: Dictionary) -> void: it.flip = not it.flip)


func rescale(s: float) -> void:
	edit(func(it: Dictionary) -> void: it.scale = clampf(s, 0.5, 1.5))


func set_tint(hex: String) -> void:
	edit(func(it: Dictionary) -> void: it.tint = hex)


func nudge(d: Vector3) -> void:
	edit(func(it: Dictionary) -> void:
		it.off = [it.off[0] + d.x, it.off[1] + d.y, it.off[2] + d.z])


func reset_offset() -> void:
	edit(func(it: Dictionary) -> void: it.off = [0.0, 0.0, 0.0])


## Copies cell p's top piece into the brush.
func eyedrop(p: Vector2i) -> void:
	var items := _items(p)
	var i := Layout.top_index(items)
	if i < 0:
		return
	brush = Layout.full_item(items[i])
	brush.off = [0.0, 0.0, 0.0]
	selected = {}
	_select_palette(brush.kit, brush.piece)
	_set_tool("paint")
	_refresh_selection()
	_refresh_inspector()


## Selects cell p's top piece; clicking the same cell again walks down.
func select_at(p: Vector2i) -> void:
	var items := _items(p)
	if items.is_empty():
		selected = {}
	elif not selected.is_empty() and selected.cell == p:
		selected = {"cell": p, "i": posmod(selected.i - 1, items.size())}
	else:
		selected = {"cell": p, "i": Layout.top_index(items)}
	if not selected.is_empty():
		var it: Dictionary = items[selected.i]
		brush = it.duplicate(true)
		_select_palette(it.kit, it.piece)
	_refresh_selection()
	_refresh_inspector()


## Height over the surface of the cell's highest decoration (m).
func _stack_top(p: Vector2i) -> float:
	var node: Node3D = _cells.get(p)
	var top := 0.0
	if node == null:
		return top
	var items := _items(p)
	for ch in node.get_children():
		if not ch.has_meta("item") or ch.has_meta("column"):
			continue
		var i: int = ch.get_meta("item")
		if i < items.size() and not Layout.kind_of(items[i]) in ["tile", "cap"]:
			top = maxf(top, ArenaScene.node_bounds(ch, node).end.y)
	return top


# --- 3D view -------------------------------------------------------------

func _build_view() -> void:
	_world = Node3D.new()
	_vp.add_child(_world)
	ArenaScene.add_lights(_world)
	_cam = ArenaScene.game_camera(720.0, 1.0, Vector3.ZERO)
	_world.add_child(_cam)
	_cam.make_current()
	_overlay = MeshInstance3D.new()
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(_overlay)
	_hover_mesh = MeshInstance3D.new()
	_hover_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover_mesh.mesh = _diamond_mesh(Color(1.0, 0.9, 0.2), true)
	_hover_mesh.visible = false
	_world.add_child(_hover_mesh)
	_sel_mesh = MeshInstance3D.new()
	_sel_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sel_mesh.visible = false
	_world.add_child(_sel_mesh)
	_retail_layer = CanvasLayer.new()
	_vp.add_child(_retail_layer)
	_retail = MapGfx.new()
	_retail_layer.add_child(_retail)
	_retail_layer.visible = false


func _rebuild_cell(p: Vector2i) -> void:
	if _cells.has(p):
		_cells[p].queue_free()
		_cells.erase(p)
	var items := _items(p)
	if items.is_empty() or not shape.cells.has(p):
		return
	var n := builder.build_cell(p, shape.cells[p], items, shape.floor_y)
	_world.add_child(n)
	_cells[p] = n


func _surface_y(p: Vector2i) -> float:
	return shape.cells[p].surface * Layout.ALT


## The shape overlay: every cell's outline at its surface, tinted by role,
## and a translucent fill on start cells, pedestals, obstacles and on cells
## that have no ground yet.
func _rebuild_overlay() -> void:
	var lines := PackedVector3Array()
	var lcol := PackedColorArray()
	var tris := PackedVector3Array()
	var tcol := PackedColorArray()
	for p: Vector2i in shape.cells:
		var c: Dictionary = shape.cells[p]
		var y := _surface_y(p) + 0.02
		var col: Color = ROLE_COLORS[c.role]
		var q := [Vector3(p.x + 0.04, y, p.y + 0.04), Vector3(p.x + 0.96, y, p.y + 0.04),
			Vector3(p.x + 0.96, y, p.y + 0.96), Vector3(p.x + 0.04, y, p.y + 0.96)]
		for k in 4:
			lines.append(q[k])
			lines.append(q[(k + 1) % 4])
			lcol.append(col)
			lcol.append(col)
		var has_ground := false
		for x: Dictionary in _items(p):
			if Layout.kind_of(x) in ["tile", "cap"]:
				has_ground = true
		var fill := Color(0.6, 0.6, 0.6, 0.35) if not has_ground else Color(0, 0, 0, 0)
		if c.role != "floor":
			fill = Color(col, 0.3)
		if fill.a > 0.0:
			for k in [0, 1, 2, 0, 2, 3]:
				tris.append(q[k])
				tcol.append(fill)
	var mesh := ArrayMesh.new()
	if not lines.is_empty():
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = lines
		a[Mesh.ARRAY_COLOR] = lcol
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
		# over the pieces: snow caps and tufts stand above the walk surface
		mesh.surface_set_material(mesh.get_surface_count() - 1, _flat_mat(true))
	if not tris.is_empty():
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = tris
		a[Mesh.ARRAY_COLOR] = tcol
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _flat_mat(true))
	_overlay.mesh = mesh
	_overlay.visible = show_grid


func _flat_mat(on_top: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = on_top
	if on_top:
		m.render_priority = 10
	return m


## A cell-sized outline (or a box) drawn over everything.
func _diamond_mesh(col: Color, fill: bool) -> ArrayMesh:
	var q := [Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]
	var v := PackedVector3Array()
	for k in 4:
		v.append(q[k])
		v.append(q[(k + 1) % 4])
	var mesh := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_COLOR] = PackedColorArray([col, col, col, col, col, col, col, col])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, a)
	mesh.surface_set_material(0, _flat_mat(true))
	if fill:
		var t := PackedVector3Array([q[0], q[1], q[2], q[0], q[2], q[3]])
		var b := []
		b.resize(Mesh.ARRAY_MAX)
		b[Mesh.ARRAY_VERTEX] = t
		var fc := Color(col, 0.18)
		b[Mesh.ARRAY_COLOR] = PackedColorArray([fc, fc, fc, fc, fc, fc])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		mesh.surface_set_material(1, _flat_mat(true))
	return mesh


func _box_mesh(bb: AABB, col: Color) -> ArrayMesh:
	var v := PackedVector3Array()
	var e := bb.end
	var o := bb.position
	var c := [Vector3(o.x, o.y, o.z), Vector3(e.x, o.y, o.z), Vector3(e.x, o.y, e.z), Vector3(o.x, o.y, e.z)]
	for k in 4:
		var a: Vector3 = c[k]
		var b: Vector3 = c[(k + 1) % 4]
		v.append_array([a, b, Vector3(a.x, e.y, a.z), Vector3(b.x, e.y, b.z), a, Vector3(a.x, e.y, a.z)])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var cols := PackedColorArray()
	cols.resize(v.size())
	cols.fill(col)
	arr[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, _flat_mat(true))
	return mesh


func _refresh_selection() -> void:
	_sel_mesh.visible = false
	if selected.is_empty() or not _cells.has(selected.cell):
		return
	var node: Node3D = _cells[selected.cell]
	var bb := AABB()
	var first := true
	for ch in node.get_children():
		if ch.has_meta("item") and int(ch.get_meta("item")) == selected.i:
			var b := ArenaScene.node_bounds(ch, _world)
			bb = b if first else bb.merge(b)
			first = false
	if first:
		return
	_sel_mesh.mesh = _box_mesh(bb.grow(0.02), Color(0.3, 1.0, 0.95))
	_sel_mesh.visible = true


## The cell under a viewport point: the first cell surface the camera ray
## meets (the shape's surfaces, not the pieces on them).
func cell_at(pos: Vector2) -> Variant:
	var o := _cam.project_ray_origin(pos)
	var d := _cam.project_ray_normal(pos)
	if absf(d.y) < 0.0001:
		return null
	var best = null
	var best_t := INF
	for p: Vector2i in shape.cells:
		var t := (_surface_y(p) - o.y) / d.y
		if t < 0.0 or t >= best_t:
			continue
		var h := o + d * t
		if h.x >= p.x and h.x < p.x + 1 and h.z >= p.y and h.z < p.y + 1:
			best = p
			best_t = t
	return best


func fit_view() -> void:
	if shape.cells.is_empty():
		return
	var lo := Vector2(INF, INF)
	var hi := -lo
	var ylo := INF
	var yhi := -INF
	for p: Vector2i in shape.cells:
		lo = lo.min(Vector2(p))
		hi = hi.max(Vector2(p) + Vector2.ONE)
		ylo = minf(ylo, _surface_y(p))
		yhi = maxf(yhi, _surface_y(p))
	var center := Vector3((lo.x + hi.x) * 0.5, (ylo + yhi) * 0.5, (lo.y + hi.y) * 0.5)
	# the shape's screen box at zoom 1: x spans (dx + dy) * 43, y the half
	var w := ((hi.x - lo.x) + (hi.y - lo.y)) * 43.0
	var h := ((hi.x - lo.x) + (hi.y - lo.y)) * 21.5 + (yhi - ylo) / Layout.ALT * 10.0 + 120.0
	var vs := Vector2(_vp.size)
	zoom = clampf(minf(vs.x / w, vs.y / h) * 0.95, 0.25, 4.0)
	_cam.position = center + _cam.transform.basis.z * 60.0
	_apply_zoom()


func game_scale() -> void:
	zoom = 1.0
	_apply_zoom()


func _apply_zoom() -> void:
	_cam.size = maxf(1.0, _vp.size.y) / (Layout.PX * zoom)
	_sync_retail()


func _pan(px: Vector2) -> void:
	var k := 1.0 / (Layout.PX * zoom)
	_cam.position -= _cam.transform.basis.x * px.x * k - _cam.transform.basis.y * px.y * k
	_sync_retail()


func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.2, 5.0)
	_apply_zoom()
	_update_status()


# --- the retail map as a reference layer ----------------------------------

func _load_retail() -> void:
	_retail_ok = (_retail as MapGfx).load_world(Layout.world_of(arena))
	_retail_check.disabled = not _retail_ok
	_retail_check.tooltip_text = "" if _retail_ok else "No hay arte retail de este mapa en assets/mapgfx"
	if not _retail_ok:
		_retail_check.button_pressed = false
	_retail_layer.visible = _retail_ok and _retail_check.button_pressed
	_sync_retail()


## Lines the painted retail map up with the 3D: the retail puts cell (x, y)
## at ((x - y) * 43, (x + y) * 21.5) - alt * 10; read where the camera puts
## the same points and map one plane onto the other.
func _sync_retail() -> void:
	if _retail_layer == null or not _retail_layer.visible:
		return
	var o := _cam.unproject_position(Vector3(0.5, 0, 0.5))
	var ex := _cam.unproject_position(Vector3(1.5, 0, 0.5)) - o
	var ey := _cam.unproject_position(Vector3(0.5, 0, 1.5)) - o
	_retail_layer.transform = Transform2D((ex - ey) / 86.0, (ex + ey) / 43.0, o)
	_retail.modulate.a = _retail_alpha.value
	_retail.queue_redraw()


# --- input ---------------------------------------------------------------

func _on_view_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		if _panning:
			_pan(e.relative)
			return
		_set_hover(cell_at(e.position))
		if _painting and _hover != null and _hover != _last_paint:
			_last_paint = _hover
			if tool == "cells":
				set_role(_hover, cell_role, false)
			else:
				place(_hover, false, false)   # one undo step for the whole stroke
	elif e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_by(1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_by(1.0 / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and _space):
			_panning = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var p = cell_at(mb.position)
			if p != null:
				if tool == "cells":
					reset_role(p)
				else:
					remove_top(p)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if not mb.pressed:
				_painting = false
				_last_paint = null
				return
			var p = cell_at(mb.position)
			if p == null:
				selected = {}
				_refresh_selection()
				_refresh_inspector()
				return
			if tool == "cells":
				_snapshot()
				set_role(p, cell_role, false)
				_painting = true
				_last_paint = p
			elif mb.alt_pressed or tool == "pick":
				eyedrop(p)
			elif tool == "select":
				select_at(p)
			elif tool == "erase":
				remove_top(p)
			else:
				place(p, mb.shift_pressed)
				# blocks and caps paint while dragging; decorations go one per click
				if Layout.kind_of(brush) in ["tile", "cap", "flat"] and not mb.shift_pressed:
					_painting = true
					_last_paint = p


func _set_hover(p: Variant) -> void:
	_hover = p
	_hover_mesh.visible = p != null
	if p != null:
		_hover_mesh.position = Vector3(p.x, _surface_y(p) + 0.03, p.y)
	_update_hover_label()


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null:
		return
	if k.keycode == KEY_SPACE:
		_space = k.pressed
		return
	if not k.pressed:
		return
	var step := 0.25 if k.shift_pressed else 0.05
	var handled := true
	if k.ctrl_pressed:
		match k.keycode:
			KEY_S: save()
			KEY_Z:
				if k.shift_pressed:
					redo()
				else:
					undo()
			KEY_Y: redo()
			KEY_LEFT: nudge(_screen_dir(Vector2(-1, 0)) * step)
			KEY_RIGHT: nudge(_screen_dir(Vector2(1, 0)) * step)
			KEY_UP: nudge(_screen_dir(Vector2(0, -1)) * step)
			KEY_DOWN: nudge(_screen_dir(Vector2(0, 1)) * step)
			_: handled = false
	else:
		match k.keycode:
			KEY_B: _set_tool("paint")
			KEY_S: _set_tool("select")
			KEY_X: _set_tool("erase")
			KEY_I: _set_tool("pick")
			KEY_C: _set_tool("cells")
			KEY_1: set_loom("a")
			KEY_2: set_loom("b")
			KEY_3: set_loom("c")
			KEY_R: turn(-90.0 if k.shift_pressed else 90.0)
			KEY_COMMA: turn(-15.0)
			KEY_PERIOD: turn(15.0)
			KEY_F: flip()
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL: rescale(brush.get("scale", 1.0) + 0.05)
			KEY_MINUS, KEY_KP_SUBTRACT: rescale(brush.get("scale", 1.0) - 0.05)
			KEY_PAGEUP: nudge(Vector3(0, step, 0))
			KEY_PAGEDOWN: nudge(Vector3(0, -step, 0))
			KEY_HOME: reset_offset()
			KEY_DELETE, KEY_BACKSPACE:
				if not selected.is_empty():
					_remove(selected.cell, selected.i)
			KEY_ESCAPE:
				selected = {}
				_refresh_selection()
				_refresh_inspector()
			KEY_LEFT: _pan(Vector2(60, 0))
			KEY_RIGHT: _pan(Vector2(-60, 0))
			KEY_UP: _pan(Vector2(0, 60))
			KEY_DOWN: _pan(Vector2(0, -60))
			KEY_G: _grid_check.button_pressed = not _grid_check.button_pressed
			KEY_V:
				if _retail_ok:
					_retail_check.button_pressed = not _retail_check.button_pressed
			KEY_H, KEY_F1: _help.visible = not _help.visible
			_: handled = false
	if handled:
		get_viewport().set_input_as_handled()


## A screen direction as a step on the ground plane.
func _screen_dir(s: Vector2) -> Vector3:
	var r := _cam.transform.basis.x
	var u := -_cam.transform.basis.z
	var v := Vector3(r.x, 0, r.z).normalized() * s.x + Vector3(u.x, 0, u.z).normalized() * -s.y
	return v


# --- UI ------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("23262b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	_arena_pick = OptionButton.new()
	for i in Layout.WORLDS.size():
		var kits := []
		for kn: String in Layout.kits():
			if Layout.WORLDS[i] in Layout.kits()[kn].get("arenas", []):
				kits.append(Layout.kits()[kn].get("biome", kn))
		_arena_pick.add_item("Arena %d · mundo %d · %s" % [i + 1, Layout.WORLDS[i], ", ".join(kits)])
	_arena_pick.item_selected.connect(func(i: int) -> void: load_arena(i + 1))
	top.add_child(_arena_pick)
	_button(top, "Guardar", save, "Ctrl+S")
	_button(top, "Deshacer", undo, "Ctrl+Z")
	_button(top, "Rehacer", redo, "Ctrl+Y")
	_button(top, "Encuadrar", fit_view, "Todo el mapa en la vista")
	_button(top, "Escala de juego", game_scale, "Zoom 1: casillas de 86 px, como en el combate")
	_grid_check = CheckButton.new()
	_grid_check.text = "Rejilla"
	_grid_check.button_pressed = true
	_grid_check.toggled.connect(func(on: bool) -> void:
		show_grid = on
		_overlay.visible = on)
	top.add_child(_grid_check)
	_retail_check = CheckButton.new()
	_retail_check.text = "Retail"
	_retail_check.tooltip_text = "El mapa retail encima, como referencia"
	_retail_check.toggled.connect(func(on: bool) -> void:
		_retail_layer.visible = on and _retail_ok
		_sync_retail())
	top.add_child(_retail_check)
	_retail_alpha = HSlider.new()
	_retail_alpha.min_value = 0.1
	_retail_alpha.max_value = 1.0
	_retail_alpha.step = 0.05
	_retail_alpha.value = 0.5
	_retail_alpha.custom_minimum_size.x = 90
	_retail_alpha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_retail_alpha.value_changed.connect(func(_v: float) -> void: _sync_retail())
	top.add_child(_retail_alpha)
	_button(top, "Ayuda", func() -> void: _help.visible = not _help.visible, "H")

	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(mid)
	mid.add_child(_build_palette())
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.focus_mode = Control.FOCUS_CLICK
	_vpc.gui_input.connect(_on_view_input)
	_vpc.mouse_exited.connect(func() -> void: _set_hover(null))
	mid.add_child(_vpc)
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.handle_input_locally = false
	_vp.size_changed.connect(func() -> void:
		if _cam != null:
			_apply_zoom())
	_vpc.add_child(_vp)
	mid.add_child(_build_inspector())

	var bottom := HBoxContainer.new()
	root.add_child(bottom)
	_status = Label.new()
	bottom.add_child(_status)
	_hover_label = Label.new()
	_hover_label.clip_text = true
	_hover_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_hover_label)

	_help = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.92)
	sb.set_content_margin_all(14)
	sb.set_corner_radius_all(6)
	_help.add_theme_stylebox_override("panel", sb)
	var help := RichTextLabel.new()
	help.bbcode_enabled = true
	help.fit_content = true
	help.custom_minimum_size = Vector2(430, 0)
	help.text = HELP
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_child(help)
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.set_anchors_preset(Control.PRESET_CENTER)
	_help.visible = false
	add_child(_help)
	_help.resized.connect(func() -> void: _help.position = (size - _help.size) * 0.5)


func _button(parent: Control, text: String, f: Callable, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(f)
	parent.add_child(b)
	return b


func _build_palette() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 300
	_scope = OptionButton.new()
	_scope.add_item("Piezas de esta arena")
	_scope.add_item("Piezas de todas las arenas")
	_scope.focus_mode = Control.FOCUS_NONE
	_scope.item_selected.connect(func(i: int) -> void:
		_all = i == 1
		_fill_palette())
	box.add_child(_scope)
	_search = LineEdit.new()
	_search.placeholder_text = "Buscar…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _fill_list())
	box.add_child(_search)
	_group_bar = HBoxContainer.new()
	var bg := ButtonGroup.new()
	for i in GROUPS.size():
		var b := Button.new()
		b.text = GROUPS[i][0]
		b.toggle_mode = true
		b.button_group = bg
		b.button_pressed = i == 0
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_group = i
			_fill_list())
		_group_bar.add_child(b)
	box.add_child(_group_bar)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.fixed_icon_size = Vector2i(THUMB, THUMB)
	_list.icon_mode = ItemList.ICON_MODE_LEFT
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(i: int) -> void:
		_pick_piece(int(_list.get_item_metadata(i))))
	box.add_child(_list)
	return box


func _build_inspector() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 270
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	_heading(box, "Herramienta")
	var tools := GridContainer.new()
	tools.columns = 2
	var tg := ButtonGroup.new()
	for t in [["paint", "Pincel (B)"], ["select", "Seleccionar (S)"], ["erase", "Borrar (X)"],
			["pick", "Cuentagotas (I)"], ["cells", "Casillas (C)"]]:
		var b := Button.new()
		b.text = t[1]
		b.toggle_mode = true
		b.button_group = tg
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _set_tool(t[0]))
		tools.add_child(b)
		_tool_buttons[t[0]] = b
	box.add_child(tools)
	_tool_buttons.paint.button_pressed = true

	_heading(box, "Casillas del combate (C)")
	var roles := GridContainer.new()
	roles.columns = 2
	var rg := ButtonGroup.new()
	for r: String in Layout.EDITABLE_ROLES:
		var b := Button.new()
		b.text = {"floor": "Suelo", "obstacle": "Obstáculo", "team0": "Salida equipo 1",
			"team1": "Salida equipo 2"}[r]
		b.toggle_mode = true
		b.button_group = rg
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_color_override("font_color", Color(ROLE_COLORS[r], 1.0) if r != "floor" else Color.WHITE)
		b.pressed.connect(func() -> void:
			cell_role = r
			_set_tool("cells"))
		roles.add_child(b)
		_role_buttons[r] = b
	box.add_child(roles)
	_role_buttons[cell_role].button_pressed = true
	_starts_label = Label.new()
	_starts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_starts_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_starts_label)

	_heading(box, "Pieza")
	_piece_label = Label.new()
	_piece_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_piece_label)
	_piece_note = Label.new()
	_piece_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_piece_note.add_theme_font_size_override("font_size", 12)
	_piece_note.modulate = Color(1, 1, 1, 0.6)
	box.add_child(_piece_note)

	_heading(box, "Loom (1 2 3)")
	var lg := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = lg
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var l: String = ["a", "b", "c"][i]
		b.pressed.connect(func() -> void: set_loom(l))
		box.add_child(b)
		_loom_buttons.append(b)

	_heading(box, "Giro (R, Mayús+R, coma, punto)")
	var rot := HBoxContainer.new()
	_button(rot, "−90°", func() -> void: turn(-90.0))
	_button(rot, "−15°", func() -> void: turn(-15.0))
	_rot_label = Label.new()
	_rot_label.custom_minimum_size.x = 48
	_rot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rot.add_child(_rot_label)
	_button(rot, "+15°", func() -> void: turn(15.0))
	_button(rot, "+90°", func() -> void: turn(90.0))
	box.add_child(rot)
	_flip_check = CheckBox.new()
	_flip_check.text = "Reflejar (F)"
	_flip_check.focus_mode = Control.FOCUS_NONE
	_flip_check.toggled.connect(func(on: bool) -> void:
		if not _syncing and on != bool(brush.get("flip", false)):
			flip())
	box.add_child(_flip_check)
	_rand_check = CheckBox.new()
	_rand_check.text = "Giro al azar al pintar"
	_rand_check.focus_mode = Control.FOCUS_NONE
	_rand_check.toggled.connect(func(on: bool) -> void: random_rot = on)
	box.add_child(_rand_check)

	_heading(box, "Escala (+ −)")
	var sc := HBoxContainer.new()
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 1.5
	_scale_slider.step = 0.05
	_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scale_slider.focus_mode = Control.FOCUS_NONE
	_scale_slider.drag_ended.connect(func(_c: bool) -> void: rescale(_scale_slider.value))
	sc.add_child(_scale_slider)
	_scale_label = Label.new()
	_scale_label.custom_minimum_size.x = 44
	sc.add_child(_scale_label)
	box.add_child(sc)

	_heading(box, "Tinte")
	var tints := HBoxContainer.new()
	_tint_button = ColorPickerButton.new()
	_tint_button.custom_minimum_size = Vector2(48, 28)
	_tint_button.edit_alpha = false
	_tint_button.focus_mode = Control.FOCUS_NONE
	_tint_button.popup_closed.connect(func() -> void:
		set_tint(_tint_button.color.to_html(false)))
	tints.add_child(_tint_button)
	for hex in TINTS:
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(22, 22)
		sw.focus_mode = Control.FOCUS_NONE
		sw.tooltip_text = "Sin tinte" if hex == "ffffff" else "#" + hex
		var st := StyleBoxFlat.new()
		st.bg_color = Color.html(hex)
		st.set_corner_radius_all(3)
		sw.add_theme_stylebox_override("normal", st)
		sw.add_theme_stylebox_override("hover", st)
		sw.add_theme_stylebox_override("pressed", st)
		sw.pressed.connect(func() -> void: set_tint(hex))
		tints.add_child(sw)
	box.add_child(tints)

	_heading(box, "Altura y posición")
	_off_label = Label.new()
	box.add_child(_off_label)
	var off := HBoxContainer.new()
	_button(off, "▲", func() -> void: nudge(Vector3(0, 0.05, 0)), "AvPág")
	_button(off, "▼", func() -> void: nudge(Vector3(0, -0.05, 0)), "RePág")
	_button(off, "Centrar", reset_offset, "Inicio")
	box.add_child(off)

	_heading(box, "Mapa")
	_fill_button = _button(box, "Rellenar casillas vacías", fill_empty,
		"Pone el suelo del pincel en cada casilla que aún no tiene")
	_button(box, "Vaciar el mapa", clear_all, "Quita todas las piezas (se puede deshacer)")

	_heading(box, "Casilla")
	_cell_label = Label.new()
	_cell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_cell_label)
	return scroll


func _heading(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("e0c070"))
	l.add_theme_font_size_override("font_size", 13)
	parent.add_child(l)


func _set_tool(t: String) -> void:
	tool = t
	_tool_buttons[t].button_pressed = true
	if t != "select":
		selected = {}
		_refresh_selection()
	_refresh_inspector()


func _fill_palette() -> void:
	palette = Layout.palette(Layout.world_of(arena), _all)
	_fill_list()


func _fill_list() -> void:
	_list.clear()
	var kinds: Array = GROUPS[_group][1]
	var q := _search.text.strip_edges().to_lower()
	for i in palette.size():
		var p: Dictionary = palette[i]
		if not kinds.is_empty() and not p.kind in kinds:
			continue
		var label := String(p.get("label", p.name))
		if q != "" and not (q in label.to_lower() or q in String(p.name).to_lower()):
			continue
		var key := "%s/%s" % [p.kit, p.name]
		var row := _list.add_item(label, _thumbs.get(key))
		_list.set_item_metadata(row, i)
		_list.set_item_tooltip(row, "%s · %s · %s" % [p.name, KIND_NAMES.get(p.kind, p.kind), p.kit])
		if not _thumbs.has(key) and not key in _thumb_queue:
			_thumb_queue.append(key)
		if not brush.is_empty() and brush.kit == p.kit and brush.piece == p.name:
			_list.select(row)
	if not _thumb_busy and not _thumb_queue.is_empty():
		_render_thumbs()


func _palette_index(kit: String, name: String) -> int:
	for i in palette.size():
		if palette[i].kit == kit and palette[i].name == name:
			return i
	return -1


func _first_of_kind(kind: String) -> int:
	for i in palette.size():
		if palette[i].kind == kind:
			return i
	return 0 if not palette.is_empty() else -1


func _pick_piece(i: int) -> void:
	if i < 0 or i >= palette.size():
		return
	var p: Dictionary = palette[i]
	var keep := brush.duplicate(true)
	brush = Layout.new_item(p.kit, p.name, keep.get("loom", "a"))
	brush.tint = keep.get("tint", "ffffff")
	selected = {}
	if tool != "paint":
		_set_tool("paint")
	_refresh_selection()
	_refresh_inspector()


func _select_palette(kit: String, name: String) -> void:
	for row in _list.item_count:
		var i: int = _list.get_item_metadata(row)
		if palette[i].kit == kit and palette[i].name == name:
			_list.select(row)
			_list.ensure_current_is_visible()
			return
	_list.deselect_all()


func _refresh_inspector() -> void:
	_syncing = true
	var p := Layout.piece(brush.get("kit", ""), brush.get("piece", ""))
	var editing := not selected.is_empty()
	_piece_label.text = ("Editando: " if editing else "") + String(p.get("label", brush.get("piece", "—"))) \
		+ "\n(" + KIND_NAMES.get(p.get("kind", ""), "") + ")"
	_piece_note.text = String(p.get("note", ""))
	var names := Layout.loom_names(p)
	for i in 3:
		var l: String = ["a", "b", "c"][i]
		_loom_buttons[i].text = "%s · %s" % [l, names[i]]
		_loom_buttons[i].button_pressed = brush.get("loom", "a") == l
	_rot_label.text = "%d°" % int(round(float(brush.get("rot", 0.0))))
	_flip_check.button_pressed = bool(brush.get("flip", false))
	_scale_slider.value = float(brush.get("scale", 1.0))
	_scale_label.text = "×%.2f" % float(brush.get("scale", 1.0))
	_tint_button.color = Color.html(brush.get("tint", "ffffff"))
	var o: Array = brush.get("off", [0.0, 0.0, 0.0])
	_off_label.text = "altura %+.2f m · desplazamiento %+.2f, %+.2f" % [o[1], o[0], o[2]]
	_fill_button.disabled = not p.get("kind", "") in ["tile", "cap"]
	_syncing = false
	_update_hover_label()


func _update_status(msg := "") -> void:
	if _status == null:
		return
	var n := 0
	for items in layout.get("cells", {}).values():
		n += items.size()
	var s := "Arena %d%s · %d piezas en %d/%d casillas · zoom %.2f" % [arena,
		" (sin guardar)" if dirty else "", n, layout.get("cells", {}).size(),
		shape.get("cells", {}).size(), zoom]
	if not builder.missing.is_empty():
		s += " · faltan %d modelos: compila el kit con kiln" % builder.missing.size()
	if _starts_label != null and shape.has("cells"):
		var n2 := Layout.start_counts(shape)
		var changed: int = layout.get("roles", {}).size()
		_starts_label.text = "Salidas: equipo 1 %d · equipo 2 %d%s\n%d casillas cambiadas. Clic der.: volver al original." % [
			n2.team0, n2.team1, "  ⚠ no son iguales" if n2.team0 != n2.team1 else "", changed]
	if msg != "":
		s = msg + " · " + s
	_status.text = s


func _update_hover_label() -> void:
	var lines := []
	for pair in [["Bajo el ratón", _hover], ["Seleccionada", selected.get("cell")]]:
		var p = pair[1]
		if p == null:
			continue
		var c: Dictionary = shape.cells.get(p, {})
		var names := []
		for it: Dictionary in _items(p):
			names.append("%s (%s)" % [Layout.piece(it.kit, it.piece).get("label", it.piece), it.loom])
		lines.append("%s: %d,%d · %s · altura %d · %s" % [pair[0], p.x, p.y,
			ROLE_NAMES.get(c.get("role", ""), "?"), int(c.get("alt", 0)),
			", ".join(names) if not names.is_empty() else "vacía"])
	_hover_label.text = "   " + "   |   ".join(lines)
	if _cell_label != null:
		_cell_label.text = lines[-1] if not lines.is_empty() else "—"


# --- palette thumbnails ----------------------------------------------------

## One small shot per piece (loom a), rendered a few at a time off screen.
func _render_thumbs() -> void:
	_thumb_busy = true
	var vp := SubViewport.new()
	vp.size = Vector2i(THUMB * 2, THUMB * 2)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var stage := Node3D.new()
	vp.add_child(stage)
	ArenaScene.add_lights(stage)
	(stage.get_child(0) as WorldEnvironment).environment.background_mode = Environment.BG_CLEAR_COLOR
	var cam := ArenaScene.game_camera(vp.size.y, 1.0, Vector3.ZERO)
	stage.add_child(cam)
	cam.make_current()
	while not _thumb_queue.is_empty():
		var key: String = _thumb_queue.pop_front()
		var kp := key.split("/")
		var m := builder.model(Layout.model_path(kp[0], kp[1]))
		if m == null:
			continue
		stage.add_child(m)
		var bb := ArenaScene.node_bounds(m)
		var ext := maxf(bb.size.y * 0.9 + maxf(bb.size.x, bb.size.z) * 0.7, 0.6)
		cam.size = ext * 1.15
		cam.position = bb.get_center() + cam.transform.basis.z * 30.0
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(THUMB, THUMB, Image.INTERPOLATE_LANCZOS)
		_thumbs[key] = ImageTexture.create_from_image(img)
		m.queue_free()
		_apply_thumb(key)
	vp.queue_free()
	_thumb_busy = false
	_update_status()


func _apply_thumb(key: String) -> void:
	for row in _list.item_count:
		var p: Dictionary = palette[int(_list.get_item_metadata(row))]
		if "%s/%s" % [p.kit, p.name] == key:
			_list.set_item_icon(row, _thumbs[key])
