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


## Footprint cells (x,y dicts) around `center` Vector3i per AreaShape/AreaSize —
## a port of server pointInArea (area.go): 1 point, 2 filled Manhattan diamond,
## 3 cross arms, 5 diamond annulus, 6 square; T/point-list degrade to the
## centre cell (directional shapes need a cast axis we don't carry).
static func footprint(template_id: int, center: Vector3i) -> Array:
	var m := meta(template_id)
	var cells: Array = []
	var shape := int(m.get("s", 1))
	var size: Array = m.get("z", [])
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
		_: # point (1) and unknown shapes — the single centre cell
			cells.append(Vector2i(center.x, center.y))
	return cells
