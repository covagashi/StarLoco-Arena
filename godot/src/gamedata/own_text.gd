extends RefCounted
## OwnText — game-data names in our own words (S41).
##
## assets/i18n/content_<lang>.json (tracked, like ui_<lang>.json) holds a
## flat {"<kind>.<id>": text} map: card.<id> (coach cards), fcard.<id>
## (fighter equipment, which shares ids with coach cards but names other
## items), set.<id> (collections) and cond.<id> (fighter conditions). They
## replace the retail content.* tables GameText read; a name missing in the
## UI language falls back to English, then to the caller's fallback.
##
## A value "@spell:<id>", "@breed:<n>" or "@fcard:<id>" names a combat rule
## card after what it rules on: 212 of them ban or re-price one spell, class
## or fighter item, so they follow that name (spells and classes get theirs
## in S46) instead of carrying a copy of it.

# State.locale mirrors I18n.lang; the autoload does not resolve when a -s
# test script compiles this file first (see cards.gd).
const State := preload("res://src/state.gd")

const PATH := "i18n/content_%s.json"
const UI_PATH := "i18n/ui_%s.json"
const Spells := preload("res://src/gamedata/spells.gd")

static var _tables := {}   # lang -> Dictionary


static func _table(lang: String) -> Dictionary:
	if not _tables.has(lang):
		var d: Variant = AssetPaths.read_json(PATH % lang)
		_tables[lang] = d if d is Dictionary else {}
	return _tables[lang]


## The `kind`.`id` text in the UI language, else English, else `fallback`.
static func get_text(kind: String, id: int, fallback: String) -> String:
	var key := "%s.%d" % [kind, id]
	var t := str(_table(State.locale).get(key, ""))
	if t == "":
		t = str(_table("en").get(key, ""))
	if t.begins_with("@"):
		return _resolve(t, fallback)
	return t if t != "" else fallback


## "@spell:12" -> the spell's name, "@breed:3" -> the class's (ui_<lang>
## breed.3), "@fcard:7" -> the fighter item's.
static func _resolve(ref: String, fallback: String) -> String:
	var kind := ref.substr(1).get_slice(":", 0)
	var id := int(ref.get_slice(":", 1))
	match kind:
		"spell":
			return Spells.name_of(id)
		"breed":
			var ui: Variant = AssetPaths.read_json(UI_PATH % State.locale)
			var n := str(ui.get("breed.%d" % id, "")) if ui is Dictionary else ""
			return n if n != "" else fallback
		"fcard":
			return get_text("fcard", id, fallback)
	return fallback


static func has_text(kind: String, id: int) -> bool:
	return _table("en").has("%s.%d" % [kind, id])
