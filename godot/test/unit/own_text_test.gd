extends RefCounted
## S41: our own game-data names (assets/i18n/content_<lang>.json, tracked).
## The three tables parse, carry the same keys, no blank or overlong name,
## and none of the retail world's proper nouns.

const OwnText := preload("res://src/gamedata/own_text.gd")
const PATH := "res://assets/i18n/content_%s.json"
## Every name kind and how many there are (coach cards, fighter equipment,
## collections, fighter conditions).
const COUNTS := {"card": 907, "fcard": 75, "set": 138, "cond": 111}
const MAX_LEN := {"card": 30, "fcard": 30, "set": 24, "cond": 30}
## Retail proper nouns that must not come back (lower case, whole words).
const BANNED := ["dofus", "ankama", "wabbit", "zaap", "bonta", "brakmar", "amakna",
	"krosmoz", "kama", "kamas", "tofu", "bouftou", "iop", "sedforme", "krono",
	"kepika", "zanahowia", "arakne", "potaras"]


func run(t) -> void:
	t.suite("own_text")
	var tables := {}
	for lang in ["es", "en", "fr"]:
		var f := FileAccess.open(PATH % lang, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		t.ok(d is Dictionary, "%s parses" % lang)
		tables[lang] = d if d is Dictionary else {}
	for kind in COUNTS:
		var n := 0
		for k in tables.en:
			if str(k).begins_with(kind + "."):
				n += 1
		t.eq(n, COUNTS[kind], "%s names" % kind)
	for lang in ["es", "fr"]:
		var missing: Array = tables.en.keys().filter(func(k): return not tables[lang].has(k))
		var extra: Array = tables[lang].keys().filter(func(k): return not tables.en.has(k))
		t.ok(missing.is_empty() and extra.is_empty(), "%s keys = en keys (missing %s, extra %s)" % [lang, missing.slice(0, 5), extra.slice(0, 5)])
	var re := RegEx.create_from_string("[\\p{L}]+")
	for lang in tables:
		var bad: Array = []
		for k in tables[lang]:
			var v := str(tables[lang][k])
			var kind := str(k).get_slice(".", 0)
			if v.strip_edges() == "" or v.length() > int(MAX_LEN.get(kind, 30)):
				bad.append("%s=%s" % [k, v])
			for m in re.search_all(v.to_lower()):
				if m.get_string() in BANNED:
					bad.append("%s=%s" % [k, v])
		t.ok(bad.is_empty(), "%s: blank, overlong or retail names %s" % [lang, bad.slice(0, 8)])
	var was := I18n.lang
	I18n.set_locale("es")
	t.ok(OwnText.get_text("cond", 1, "") != "", "a condition name reads in Spanish")
	t.eq(OwnText.get_text("card", 999999, "fb"), "fb", "an unknown id falls back")
	if was != "":
		I18n.set_locale(was)
