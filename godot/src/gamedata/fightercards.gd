extends RefCounted

## Fighter-equipment active-ability table exported by
## server/cmd/dumpfightercards into assets/gamedata/fightercards.json —
## {"<id>": {ap, min, max, usable}}. Display names come from the shared card
## table (cards.gd — same id space); this file only carries what the fight UI
## needs to offer the weapon attack (server jb_2.isUsable mirror).

const PATH := "res://assets/gamedata/fightercards.json"
const Cards := preload("res://src/gamedata/cards.gd")

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
	if data is Dictionary:
		for k in data.keys():
			_by_id[int(k)] = data[k]


static func ability(card_id: int) -> Dictionary:
	_ensure()
	return _by_id.get(card_id, {})


## True when the card carries a playable active (server UseEffects non-empty).
static func usable(card_id: int) -> bool:
	return bool(ability(card_id).get("usable", false))


static func label(card_id: int) -> String:
	var nm: String = Cards.name_of(card_id)
	return nm if nm != "" else "Eq %d" % card_id
