extends RefCounted
const OwnText := preload("res://src/gamedata/own_text.gd")

## Spell tables built from server/content by server/cmd/exportclient into
## assets/content/spells.json — {breed: [{id,ap,min,max,value,…,fx}]};
## "fx" is the S37 effect recipe (server/internal/clientdata/vfx.go, drawn
## by src/fx/vfx.gd). Names are ours (S41, OwnText spell.<id>).

const PATH := "content/spells.json"

static var _by_breed := {}    # breed int -> Array[Dictionary]
static var _by_id := {}       # spell id -> Dictionary
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = AssetPaths.read_json(PATH)
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


## Our name for the spell (S41, OwnText spell.<id>) in the UI language.
static func name_of(id: int) -> String:
	return OwnText.get_text("spell", id, "#%d" % id)


## French display name that keyed the retail AnimSort-<name> cast actions.
## Our tables carry no retail names (S43), so it is always "" and the cast
## plays the generic action; it goes with the retail animations.
static func fr_name(id: int) -> String:
	_ensure()
	var s: Variant = _by_id.get(id)
	return str(s.get("nfr", "")) if s != null else ""


static func meta(id: int) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})
