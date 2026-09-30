extends RefCounted

## Type-210 static-effect templates exported by server/cmd/dumpeffects into
## assets/gamedata/areas.json — {"<id>": {"t": "TRAP"|"SPECIAL", "l": label,
## "s": areaShape, "z": [sizes], "m": maxExec, "w": firesOnWalkOn,
## "e": [innerEffectIds]}}. The 8120 creation broadcast (action 66 cell area /
## 176 caster aura) carries only the template id, so the footprint, fire budget
## and inner-effect list are resolved here — the same rf_2 catalog the retail
## client keeps.

const PATH := "res://assets/gamedata/areas.json"

static var _by_id := {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PATH))
	if data == null:
		return
	for k in data:
		var rec: Dictionary = data[k]
		# JSON numbers load as floats — sizes/triggers/inner ids are i32s
		for f in ["z", "e"]:
			rec[f] = Array(rec.get(f, [])).map(func(v): return int(v))
		_by_id[int(k)] = rec


## {"t","l","s","z","m","w","e"} for a template, {} if unknown.
static func meta(template_id: int) -> Dictionary:
	_ensure()
	return _by_id.get(template_id, {})


## Footprint cells around `center` per AreaShape/AreaSize — a port of server
## pointInArea (area.go): 1 point, 2 filled Manhattan diamond, 3 cross arms,
## 4/9 directional T, 5 diamond annulus, 6 square, 8 point-list. Directional
## shapes orient along the source→center cardinal step (for placed areas
## source==center, which is exactly how the server evaluates them).
static func footprint(template_id: int, center: Vector3i) -> Array:
	var m := meta(template_id)
	return footprint_cells(int(m.get("s", 1)), m.get("z", []), center, center)


## Shape/size-driven footprint — used both by placed-area markers (source =
## center) and by the spell AoE preview (source = the caster's live cell).
static func footprint_cells(shape: int, size: Array, center: Vector3i,
		source: Vector3i) -> Array:
	var cells: Array = []
	var r := int(size[0]) if size.size() > 0 else 0
	match shape:
		2: # circle — filled diamond, radius z[0]
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if abs(dx) + abs(dy) <= r:
						cells.append(Vector2i(center.x + dx, center.y + dy))
		3: # cross — arms up/down/left/right, per-axis lengths in z
			var up := r
			var down := r
			var left := r
			var right := r
			if size.size() >= 4:
				up = int(size[0]); down = int(size[1])
				left = int(size[2]); right = int(size[3])
			elif size.size() >= 2:
				left = int(size[1]); right = left
			cells.append(Vector2i(center.x, center.y))
			for i in range(1, up + 1):
				cells.append(Vector2i(center.x + i, center.y))
			for i in range(1, down + 1):
				cells.append(Vector2i(center.x - i, center.y))
			for i in range(1, left + 1):
				cells.append(Vector2i(center.x, center.y - i))
			for i in range(1, right + 1):
				cells.append(Vector2i(center.x, center.y + i))
		5: # ring — diamond annulus z[0]..z[1]
			var hi := int(size[1]) if size.size() > 1 else r
			var lo := mini(r, hi)
			hi = maxi(r, hi)
			for dx in range(-hi, hi + 1):
				for dy in range(-hi, hi + 1):
					var d: int = abs(dx) + abs(dy)
					if d >= lo and d <= hi:
						cells.append(Vector2i(center.x + dx, center.y + dy))
		6: # square — half-extents z[0](,z[1])
			var hh := int(size[1]) if size.size() > 1 else r
			for dx in range(-r, r + 1):
				for dy in range(-hh, hh + 1):
					cells.append(Vector2i(center.x + dx, center.y + dy))
		4, 9: # T / inverted-T — stem z[1] toward the target, bar z[0]
			var dir := _cardinal(center.x - source.x, center.y - source.y)
			if dir == Vector2i.ZERO:
				cells.append(Vector2i(center.x, center.y))
			else:
				var stem := int(size[1]) if size.size() > 1 else 0
				var bar_at := 0 if shape == 9 else stem
				var perp := Vector2i(-dir.y, dir.x)
				cells.append(Vector2i(center.x, center.y))
				for i in range(1, stem + 1):
					cells.append(Vector2i(center.x + dir.x * i,
						center.y + dir.y * i))
				for i in range(1, r + 1):
					for s in [-1, 1]:
						cells.append(Vector2i(center.x + dir.x * bar_at
							+ perp.x * i * s, center.y + dir.y * bar_at
							+ perp.y * i * s))
		8: # point-list — authored (dx,dy) pairs rotated onto the cast axis
			var dir := _cardinal(center.x - source.x, center.y - source.y)
			if dir == Vector2i.ZERO or size.size() < 2:
				cells.append(Vector2i(center.x, center.y))
			else:
				for i in range(0, size.size() - 1, 2):
					var ox := int(size[i])
					var oy := int(size[i + 1])
					cells.append(Vector2i(center.x + ox * dir.x - oy * dir.y,
						center.y + ox * dir.y + oy * dir.x))
		_: # point (1), empty (32767) and unknown — the single centre cell
			cells.append(Vector2i(center.x, center.y))
	return cells


## Cardinal step toward (dx,dy) — dominant axis wins (server cardinalStep).
static func _cardinal(dx: int, dy: int) -> Vector2i:
	if dx == 0 and dy == 0:
		return Vector2i.ZERO
	if absi(dx) >= absi(dy):
		return Vector2i(1 if dx > 0 else -1, 0)
	return Vector2i(0, 1 if dy > 0 else -1)
