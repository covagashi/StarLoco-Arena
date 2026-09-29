extends RefCounted

## Spell tables exported by tools/asset-import/spell_names.py into
## assets/gamedata/spells.json — {breed: [{id,name,ap,min,max,value}]}.
## Names are the client's own content.3.<id> strings.

const PATH := "res://assets/gamedata/spells.json"

static var _by_breed := {}    # breed int -> Array[Dictionary]
static var _by_id := {}       # spell id -> Dictionary
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
	for breed in data:
		var arr: Array = data[breed]
		_by_breed[int(breed)] = arr
		for s in arr:
			_by_id[int(s.id)] = s


static func for_breed(breed: int) -> Array:
	_ensure()
	return _by_breed.get(breed, [])


static func name_of(id: int) -> String:
	_ensure()
	var s: Variant = _by_id.get(id)
	return str(s.get("name", "Spell %d" % id)) if s != null else "Spell %d" % id


static func meta(id: int) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})
