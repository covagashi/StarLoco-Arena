extends Control

## Kanodo board renderer — draws the sphere graph of one board with
## _draw() (up to ~1800 nodes, far too many for child Controls) and
## hit-tests clicks back to the cell. Nodes live on a 1-based grid;
## cell_size px apart.
##
## set_state(board_id, owned_ids, cursor_xy) feeds the three overlays:
## owned nodes are bright-filled, the cursor gets a white ring, and
## nodes Kanodo-reachable from the cursor get a lit outline.

signal sphere_clicked(node: Dictionary)

const Kanodo := preload("res://src/gamedata/kanodo.gd")

const CELL := 16
const KIND_COLOR := {
	"empty": Color(0.32, 0.34, 0.38),
	"bonus": Color(0.30, 0.75, 0.35),
	"malus": Color(0.85, 0.30, 0.28),
	"summon": Color(0.95, 0.60, 0.20),
	"spell": Color(0.30, 0.75, 0.90),
	"barrier": Color(0.65, 0.35, 0.85),
	"teleport": Color(0.35, 0.45, 0.95),
	"item": Color(0.90, 0.75, 0.25),
	"deadend": Color(0.18, 0.18, 0.20),
}

var _board := 0
var _owned := {}
var _cursor := Vector2i(-1, -1)
var _lit := {}


func set_state(board: int, owned: Array, cursor: Vector2i) -> void:
	_board = board
	_owned = {}
	for id in owned:
		_owned[int(id)] = true
	_cursor = cursor
	_lit = {}
	# One flood-fill from the cursor crossing payload-free cells marks the
	# whole reachable frontier — equivalent to the server's per-target
	# Reachable() BFS but O(nodes) once instead of per node.
	var from := Kanodo.at(board, cursor.x, cursor.y)
	if not from.is_empty():
		var visited := {int(from.get("id", -1)): true}
		var stack := [from]
		# a portal cursor also occupies its arrival cell (reachesFrom);
		# expand through it only when it carries no payload itself
		if int(from.get("tx", 0)) != 0:
			var arr := Kanodo.at(board, int(from.tx), int(from.ty))
			if not arr.is_empty():
				visited[int(arr.get("id", -1))] = true
				if not Kanodo.has_payload(arr):
					stack.append(arr)
		while not stack.is_empty():
			var n: Dictionary = stack.pop_back()
			for d in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
				var nb := Kanodo.at(board, int(n.x) + d[0],
					int(n.y) + d[1])
				if nb.is_empty() or visited.has(int(nb.get("id", -1))):
					continue
				if nb.get("kind", "") == "deadend":
					continue
				if Kanodo.has_payload(nb):
					if not _owned.has(int(nb.get("id", -1))):
						_lit[int(nb.get("id", -1))] = true
					continue
				visited[int(nb.get("id", -1))] = true
				stack.append(nb)
	custom_minimum_size = Vector2(96 * CELL, 96 * CELL)
	queue_redraw()


func _draw() -> void:
	if _board == 0:
		return
	# path segments first, under the nodes
	for id in Kanodo.nodes:
		var n: Dictionary = Kanodo.nodes[id]
		if int(n.board) != _board:
			continue
		for d in [[1, 0], [0, 1]]:
			var nb := Kanodo.at(_board, int(n.x) + d[0],
				int(n.y) + d[1])
			if not nb.is_empty():
				draw_line(_cell(n), _cell(nb),
					Color(0.22, 0.24, 0.28), 1.5)
	for id in Kanodo.nodes:
		var n: Dictionary = Kanodo.nodes[id]
		if int(n.board) != _board:
			continue
		var kind := String(n.kind)
		var col: Color = KIND_COLOR.get(kind, Color.GRAY)
		var p := _cell(n)
		if kind == "empty":
			draw_circle(p, 2.5, col)
			continue
		var r := 6.0 if Kanodo.has_payload(n) else 3.0
		if _owned.has(int(n.id)):
			draw_circle(p, r, col.lightened(0.35))
		else:
			draw_circle(p, r, col.darkened(0.45))
			draw_arc(p, r, 0, TAU, 16, col, 1.5)
		if _lit.has(int(n.id)):
			draw_arc(p, r + 3, 0, TAU, 24, Color(1, 1, 0.6), 2.0)
		if kind == "deadend":
			draw_line(p + Vector2(-4, -4), p + Vector2(4, 4),
				Color(0.6, 0.2, 0.2), 1.5)
			draw_line(p + Vector2(4, -4), p + Vector2(-4, 4),
				Color(0.6, 0.2, 0.2), 1.5)
	if _cursor.x >= 0:
		draw_arc(_cell({"x": _cursor.x, "y": _cursor.y}), 10,
			0, TAU, 28, Color.WHITE, 2.5)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed \
			and ev.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(int(ev.position.x) / CELL,
			int(ev.position.y) / CELL)
		var n := Kanodo.at(_board, cell.x, cell.y)
		if not n.is_empty():
			sphere_clicked.emit(n)


func _cell(n: Dictionary) -> Vector2:
	# nodes are 1-based; center each cell
	return Vector2(int(n.x) * CELL + CELL * 0.5,
		int(n.y) * CELL + CELL * 0.5)
