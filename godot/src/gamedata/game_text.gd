extends RefCounted
## GameText — a game-data string in the UI language (S07).
##
## The JSON tables under assets/gamedata/ were exported with English names
## (spells.json, cards.json), so a Spanish UI showed "Cloudy Attack" next to
## "Hechizos". The retail's own text tables, extracted per language by
## gui_extract.py into assets/gui/i18n_<lang>.json, key every name as
## content.<table>.<id> — spells are table 3, cards 23 (spell_names.py and
## card_names.py read the same tables from i18n.jar). This looks a name up
## there for State.locale and falls back to the English export, so a build
## without the GUI extraction still shows something.

const State := preload("res://src/state.gd")

const SPELL := 3
const CARD := 23

static var _tables := {}   # locale -> Dictionary (the whole i18n json), or {}


static func content(table: int, id: int, fallback: String) -> String:
	var lang := State.locale
	if not _tables.has(lang):
		var parsed: Variant = AssetPaths.read_json("gui/i18n_%s.json" % lang)
		_tables[lang] = parsed if parsed is Dictionary else {}
	var text := str(_tables[lang].get("content.%d.%d" % [table, id], ""))
	return text if text != "" else fallback
