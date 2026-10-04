extends RefCounted

## Card template table exported by server/cmd/dumpcards + merged with retail
## names by tools/asset-import/card_names.py into assets/gamedata/cards.json —
## {"<id>": {name, type, set, value, price: {"<ctype>": amt}, unique, tradable}}.
## Names are the client's own content.23.<id> strings.

const PATH := "res://assets/gamedata/cards.json"

static var _by_id := {}       # card id int -> Dictionary
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
	for cid in data:
		_by_id[int(cid)] = data[cid]


static func meta(id: int) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})


static func name_of(id: int) -> String:
	var c: Variant = _by_id.get(id)
	return str(c.get("name", "Card %d" % id)) if c != null else "Card %d" % id


## Token price as a displayable string ("1200 tok, 40 cred") — empty when the
## card has no positive price (barter-only / not purchasable).
static func price_text(id: int) -> String:
	var c: Dictionary = meta(id)
	var parts := []
	for t in c.get("price", {}):
		var amt := int(c.price[t])
		if amt > 0:
			parts.append("%d t%d" % [amt, int(t)])
	return ", ".join(parts)


static func value_of(id: int) -> int:
	return int(meta(id).get("value", 0))


## Every known card template id (sorted) — fusion target pickers iterate it.
static func all_ids() -> Array:
	_ensure()
	var ids := _by_id.keys()
	ids.sort()
	return ids


## --- fusion altars (type-1100 records, server/cmd/dumpcards arg 3) ----------
const LABS_PATH := "res://assets/gamedata/fusionlabs.json"

static var _labs := {}


static func lab(id: int) -> Dictionary:
	_lab_ensure()
	return _labs.get(id, {})


## The server falls back to the lowest lab id when the request names no altar.
static func lab_default() -> Dictionary:
	_lab_ensure()
	var best := 0
	for k in _labs:
		var i := int(k)
		if best == 0 or i < best:
			best = i
	return _labs.get(best, {})


static func _lab_ensure() -> void:
	if not _labs.is_empty() or not FileAccess.file_exists(LABS_PATH):
		return
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(LABS_PATH))
	if data is Dictionary:
		_labs = data
