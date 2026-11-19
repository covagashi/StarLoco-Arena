extends RefCounted

## Class base stats built from server/content by server/cmd/exportclient into
## assets/content/breeds.json (S46) — {breed: {hp, ap, mp, init}}: what a
## fighter starts with before its cards. Names are ours (S41, OwnText breed.N).

const PATH := "content/breeds.json"

static var _by_breed := {}   # breed int -> Dictionary
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = AssetPaths.read_json(PATH)
	if data == null:
		return
	for breed in data:
		_by_breed[int(breed)] = data[breed]


## [hp, ap, mp] of a class; `fallback` for an unknown one.
static func stats(breed: int, fallback: Array) -> Array:
	_ensure()
	var b: Dictionary = _by_breed.get(breed, {})
	if b.is_empty():
		return fallback
	return [int(b.hp), int(b.ap), int(b.mp)]
