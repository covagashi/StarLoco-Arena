extends RefCounted

## Card template table exported by server/cmd/dumpcards + merged with retail
## names by tools/asset-import/card_names.py into assets/gamedata/cards.json —
## {"<id>": {name, type, set, value, price: {"<ctype>": amt}, unique, tradable}}.
## Names are the client's own content.23.<id> strings.

const PATH := "gamedata/cards.json"
# State.locale mirrors I18n.lang; the autoload itself does not resolve when a
# -s test script compiles this file first (fight_smoke: "name_of" missing).
const State := preload("res://src/state.gd")

static var _by_id := {}       # card id int -> Dictionary
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var data: Variant = AssetPaths.read_json(PATH)
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
const LABS_PATH := "gamedata/fusionlabs.json"

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
	if not _labs.is_empty():
		return
	var data: Variant = AssetPaths.read_json(LABS_PATH)
	if data is Dictionary:
		# JSON keys are strings; every caller asks with the int lab id. Until
		# S05 lab() and lab_default() always came back empty, so the fusion
		# altar never knew its tier and used the 3-slot default.
		for k in data:
			_labs[int(k)] = data[k]


## --- card set names (content.25, tools/asset-import/card_names.py) ----------
const SETS_PATH := "gamedata/cardsets.json"

static var _sets := {}   # lang -> {set id int: name}


## The set's retail name in the UI language (falls back to English), or "".
static func card_set_name(id: int) -> String:
	if _sets.is_empty():
		var data: Variant = AssetPaths.read_json(SETS_PATH)
		if data is Dictionary:
			for lang in data:
				var by_id := {}
				for k in data[lang]:
					by_id[int(k)] = str(data[lang][k])
				_sets[lang] = by_id
	var n: Variant = _sets.get(State.locale, {}).get(id)
	if n == null:
		n = _sets.get("en", {}).get(id)
	return str(n) if n != null else ""
