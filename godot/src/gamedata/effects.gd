extends RefCounted

## Type-200 effect records exported by server/cmd/dumpeffects into
## assets/gamedata/effects.json — {"<effectId>": {"a": actionId,
## "d": table-turns, "i": infinite, "p": params}}. Only timed or infinite
## effects are listed (the ones that attach a buff client-side — an instant
## hit/heal never produces a chip). Params matter for dispel: action 62's
## params[0] is the effectId it strips (server removeEffectByID).

const PATH := "res://assets/gamedata/effects.json"

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
		_by_id[int(k)] = data[k]


## {"a","d","i","p"} for a timed/infinite effect, {} for instant/unknown.
static func meta(effect_id: int) -> Dictionary:
	_ensure()
	return _by_id.get(effect_id, {})


## Table-turns a fresh attach lasts; 0 for instant/unknown effects.
static func duration(effect_id: int) -> int:
	return int(meta(effect_id).get("d", 0))


static func is_infinite(effect_id: int) -> bool:
	return bool(meta(effect_id).get("i", false))
