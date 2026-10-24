extends RefCounted

## Our own names for the tutorial characters (the lobby's "Aprendizaje":
## the twelve class masters, Baan, and Adamai of the intro), the owner's call
## on 2026-10-24 ("cambia los nombres por si acaso"): the retail ones are
## Ankama's. One name for every language; edit them here.
##
## NpcDialogs runs every content text through apply(), so a name changes in
## the services list, the talk title and any line that mentions it alike.

## content.29 name id -> our name
const NAMES := {
	170: "Tobías", 171: "Saeta", 172: "Rufo", 173: "Nerea", 174: "Bombín",
	175: "Teodoro", 176: "Aurelio", 177: "Lía", 178: "Fermín", 179: "Zoe",
	180: "Elvio", 181: "Mateo", 295: "Nilo",
}

## The retail names in es / en / fr, as the data spells them -> our name.
## Longest first, so "Edy Raiser" goes before any shorter overlap.
const OLD := {
	"Edy Raiser": "Elvio", "Ed Isace": "Elvio", "Ed eraser": "Elvio",
	"Scartrine": "Saeta", "Cikatrin": "Saeta", "Cicatrine": "Saeta",
	"Pepítox": "Tobías", "Pepitoo": "Tobías", "Pépitox": "Tobías",
	"Nosigar": "Bombín", "Patapuf": "Bombín", "Pataclop": "Bombín",
	"Estalad": "Teodoro", "Stalad": "Teodoro",
	"Lithian": "Lía", "Litio": "Lía",
	"Greeny": "Rufo", "Gruñy": "Rufo", "Grüny": "Rufo",
	"Gatiel": "Mateo", "Guitel": "Mateo",
	"Rutger": "Aurelio", "Roger": "Aurelio",
	"Vidow": "Nerea", "Ewon": "Nerea",
	"Dazil": "Zoe", "Dzee": "Zoe", "Zee": "Zoe",
	"Adamai": "Aldebrán", "Adamaï": "Aldebrán",
	"Baan": "Nilo",
	"Gus": "Fermín",
}

static var _re: RegEx


static func name_for(id: int, fallback: String) -> String:
	return NAMES.get(id, fallback)


## `text` with every retail name of OLD replaced by ours (whole words).
static func apply(text: String) -> String:
	if text.is_empty():
		return text
	if _re == null:
		var keys: Array = OLD.keys()
		keys.sort_custom(func(a, b): return a.length() > b.length())
		var alts := PackedStringArray()
		for k in keys:
			alts.append(_escape(k))
		_re = RegEx.create_from_string("(?<![\\p{L}\\p{N}])(" + "|".join(alts) + ")(?![\\p{L}\\p{N}])")
	var out := ""
	var at := 0
	for m in _re.search_all(text):
		out += text.substr(at, m.get_start() - at) + str(OLD[m.get_string(1)])
		at = m.get_end()
	return out + text.substr(at)


static func _escape(s: String) -> String:
	var out := ""
	for c in s:
		out += ("\\" + c) if c in ".^$*+?()[]{}|\\" else c
	return out
