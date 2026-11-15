extends RefCounted

## Fighter-equipment active-ability table exported by
## server/cmd/exportclient into assets/content/fightercards.json —
## {"<id>": {ap, min, max, usable, type, value}}. Names are ours (S41,
## OwnText fcard.<id>), NOT the coach-card names that share the ids.

const PATH := "content/fightercards.json"
const OwnText := preload("res://src/gamedata/own_text.gd")

static var _by_id := {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = AssetPaths.read_json(PATH)
	if data is Dictionary:
		for k in data.keys():
			_by_id[int(k)] = data[k]


static func ability(card_id: int) -> Dictionary:
	_ensure()
	return _by_id.get(card_id, {})


## True when the card carries a playable active (server UseEffects non-empty).
static func usable(card_id: int) -> bool:
	return bool(ability(card_id).get("usable", false))


## The fighter card's own name (OwnText fcard.<id>, in the UI language). The coach-
## card table shares the id but names a different item: card 1 is the sword
## "Raciela" here and the "Capa Arlan Txin" cape there (S22).
static func label(card_id: int) -> String:
	return OwnText.get_text("fcard", card_id, "#%d" % card_id)


## The FIGHTER slot type of a card (1 weapon, 2 pet, 3 cloak, 4 hat, 5
## dofus — vi_1), 0 when unknown. The coach-card table shares the id, but its
## type is the COACH slot (S22: the loadout editor used it and offered coach
## cards in the wrong slots).
static func slot_type(card_id: int) -> int:
	return int(ability(card_id).get("type", 0))


## What the card adds to the fighter's budget.
static func value_of(card_id: int) -> int:
	return int(ability(card_id).get("value", 0))


## S38b: the card template's rarity tier (0..3) for a fighter card: these
## have no rank, so their value cuts it (50, 100–150, 200–250, 300+).
static func tier_of(card_id: int) -> int:
	var v := value_of(card_id)
	return 0 if v <= 50 else 1 if v <= 150 else 2 if v <= 250 else 3


static func all_ids() -> Array:
	_ensure()
	var ids := _by_id.keys()
	ids.sort()
	return ids
