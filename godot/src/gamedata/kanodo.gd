extends RefCounted

## Sphere-board ("Kanodo") catalogue — godot/assets/gamedata/spheres.json,
## dumped from record types 900/901 by server/cmd/dumpspheres.
##
## boards[id] = {breed, season, root:[x,y]}; nodes[id] = {board, x, y, xp,
## kind, spell, pool, barrier[], tx, ty, fx[]}. Node kind is the client's own
## aKZ classification exported ready-made: spell | bonus | malus | summon |
## barrier | teleport | item | deadend | empty. "empty" nodes are the path
## segments between paying spheres — they are what Reachable may cross.

const PATH := "res://assets/gamedata/spheres.json"

static var _loaded := false
static var boards := {}          # int id -> {breed, season, root:[x,y]}
static var nodes := {}           # int id -> node dict
static var _by_cell := {}        # "%d:%d,%d" % [board,x,y] -> node dict
static var _by_breed := {}       # int breed -> int board id (first season)


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var d: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(PATH))
	for k in d.get("boards", {}):
		var b: Dictionary = d.boards[k]
		boards[int(k)] = b
		var breed := int(b.breed)
		if not _by_breed.has(breed):
			_by_breed[breed] = int(k)
	for k in d.get("nodes", {}):
		var n: Dictionary = d.nodes[k]
		var id := int(k)
		nodes[id] = n
		_by_cell["%d:%d,%d" % [int(n.board), int(n.x), int(n.y)]] = n


static func board_id_for_breed(breed: int) -> int:
	_ensure()
	return int(_by_breed.get(breed, 0))


static func at(board: int, x: int, y: int) -> Dictionary:
	_ensure()
	return _by_cell.get("%d:%d,%d" % [board, x, y], {})


static func has_payload(n: Dictionary) -> bool:
	return not n.is_empty() and String(n.get("kind", "empty")) != "empty"


## Client-faithful reachability (server gamedata.SphereBoards.Reachable /
## client ajM.a): BFS from TARGET back to the cursor, crossing only
## payload-free cells; dead ends block; the cursor's own portal arrival
## counts as the cursor cell. Wire cursor is the node's own (x,y).
static func reachable(board: int, from: Dictionary, to: Dictionary) -> bool:
	_ensure()
	if from.is_empty() or to.is_empty() or int(from.get("id", -1)) == \
			int(to.get("id", -2)):
		return false
	var reaches_from := func(n: Dictionary) -> bool:
		return int(n.get("id", -1)) == int(from.get("id", -2)) \
			or (int(from.get("tx", 0)) == int(n.x) \
				and int(from.get("ty", 0)) == int(n.y))
	if reaches_from.call(to):
		return true
	var visited := {int(to.get("id", -1)): true}
	var stack := [to]
	var first := true
	while not stack.is_empty():
		var n: Dictionary = stack.pop_back()
		if n.get("kind", "") == "deadend":
			continue
		if not first and has_payload(n):
			continue
		first = false
		for d in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
			var nb := at(board, int(n.x) + d[0], int(n.y) + d[1])
			if nb.is_empty() or visited.has(int(nb.get("id", -1))) \
					or nb.get("kind", "") == "deadend":
				continue
			if reaches_from.call(nb):
				return true
			visited[int(nb.get("id", -1))] = true
			stack.append(nb)
	return false
