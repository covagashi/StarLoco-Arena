extends RefCounted
const GameText := preload("res://src/gamedata/game_text.gd")

## Spell tables exported by tools/asset-import/spell_names.py into
## assets/gamedata/spells.json — {breed: [{id,name,ap,min,max,value}]}.
## Names are the client's own content.3.<id> strings.

const PATH := "gamedata/spells.json"

static var _by_breed := {}    # breed int -> Array[Dictionary]
static var _by_id := {}       # spell id -> Dictionary
static var _sfx := {}         # spell id -> [[t_ms, soundId], …]
static var _fx := {}          # spell id -> [[t_ms, xpsId, anchor], …]
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
	# script-driven cast/impact sfx (tools/asset-import/spell_sounds.py):
	# the Lua cast script's Sound.playSound ids with their invoke() delays.
	var sfx: Variant = AssetPaths.read_json("gamedata/spell_sfx.json")
	if sfx is Dictionary:
		for k in sfx.keys():
			_sfx[int(k)] = sfx[k]
	var fx: Variant = AssetPaths.read_json("gamedata/spell_fx.json")
	if fx is Dictionary:
		for k in fx.keys():
			_fx[int(k)] = fx[k]


## Timed sound events for the cast — [[t_ms, soundId], …] from the spell's
## retail Lua script (cast sound at 0, impact sounds at their invoke delay).
static func sfx_events(id: int) -> Array:
	_ensure()
	return _sfx.get(id, [])


## Timed .xps spawns from the cast script — rows of
##   [t_ms, xpsId, "caster"|"target"]              burst
##   [t_ms, xpsId, "tw", angleDeg, timeCoef]       avw_0 projectile
##   ["tw#i+k", xpsId, anchor]                     after tween i lands
## xpsId may be {"1":…,"3":…,"5":…,"7":…,"_":def} — direction-keyed pick.
static func fx_events(id: int) -> Array:
	_ensure()
	return _fx.get(id, [])


static func for_breed(breed: int) -> Array:
	_ensure()
	return _by_breed.get(breed, [])


## In the UI language (GameText, content.3), else the English export.
static func name_of(id: int) -> String:
	_ensure()
	var s: Variant = _by_id.get(id)
	var english := str(s.get("name", "Spell %d" % id)) if s != null else "Spell %d" % id
	return GameText.content(GameText.SPELL, id, english)


## French display name (content.3 texts_fr) — the retail AnimSort-<name>
## cast actions are keyed on it; empty when the export lacks the column.
static func fr_name(id: int) -> String:
	_ensure()
	var s: Variant = _by_id.get(id)
	return str(s.get("nfr", "")) if s != null else ""


static func meta(id: int) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})
