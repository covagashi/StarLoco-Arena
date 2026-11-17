extends RefCounted
## S41: our own game-data names (assets/i18n/content_<lang>.json, tracked).
## The three tables parse, carry the same keys, no blank or overlong name,
## and none of the retail world's proper nouns.

const OwnText := preload("res://src/gamedata/own_text.gd")
const PATH := "res://assets/i18n/content_%s.json"
## Every kind and how many there are: coach cards, fighter equipment,
## collections, fighter conditions, spells, and the NpcDialogs texts (NPC
## names and lines, challenges, dialog nodes and their replies, achievements
## and their descriptions, achievement criteria, summons, event cards).
const COUNTS := {"card": 907, "fcard": 75, "set": 138, "cond": 111, "spell": 139,
	"npc": 224, "chal": 39, "dlg": 61, "dlgr": 148, "ach": 332, "achd": 173,
	"crit": 102, "summon": 53, "event": 51, "eventd": 51, "eventl": 51}
## (crit: 99 from retail plus the three the achievements used without a
## name, 147, 167 and 222 — S47.)
## Names fit a ribbon or a row; long texts (npc, dlg, achd, eventd, eventl)
## have no limit.
const MAX_LEN := {"card": 30, "fcard": 30, "set": 24, "cond": 30, "spell": 30,
	"chal": 40, "dlgr": 70, "ach": 40, "crit": 160, "summon": 30, "event": 40}
## Kinds whose text may be empty (an achievement its name already explains).
const MAY_BE_EMPTY := ["achd"]
## Retail proper nouns that must not come back (lower case, whole words).
const BANNED := ["dofus", "ankama", "wabbit", "zaap", "zaaps", "bonta", "brakmar", "amakna",
	"krosmoz", "kama", "kamas", "tofu", "tofus", "bouftou", "iop", "iops", "sedforme", "krono",
	"kepika", "zanahowia", "arakne", "potaras", "horamundo", "wakfu", "kanodo", "feca",
	"fecas", "osamodas", "anutrof", "enutrof", "sram", "srams", "xelor", "xelors", "ecaflip",
	"eniripsa", "aniripsa", "yopuka", "yopukas", "ocra", "ocras", "sadida", "sadidas", "sacrier",
	"sacrógrito", "pandawa", "pandawas", "cra", "cras", "jalató", "gobball", "bwak", "adamai",
	"adamaï", "baan", "maknala", "ogrines", "féca", "xélor", "crâ", "sacrieur", "shushu",
	"kwak", "prespic", "gostofo"]


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
			if (v.strip_edges() == "" and not kind in MAY_BE_EMPTY) or v.length() > int(MAX_LEN.get(kind, 100000)):
				bad.append("%s=%s" % [k, v])
			for m in re.search_all(v.to_lower()):
				if m.get_string() in BANNED:
					bad.append("%s=%s" % [k, v])
		t.ok(bad.is_empty(), "%s: blank, overlong or retail names %s" % [lang, bad.slice(0, 8)])
	# the UI tables (ui_<lang>.json) carry no retail word either
	for lang in ["es", "en", "fr"]:
		var f := FileAccess.open("res://assets/i18n/ui_%s.json" % lang, FileAccess.READ)
		var ui: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		var hits: Array = []
		if ui is Dictionary:
			for k in ui:
				for m in re.search_all(str(ui[k]).to_lower()):
					if m.get_string() in BANNED:
						hits.append("%s=%s" % [k, ui[k]])
		t.ok(ui is Dictionary and hits.is_empty(), "ui_%s: no retail words %s" % [lang, hits.slice(0, 5)])
	var was := I18n.lang
	I18n.set_locale("es")
	t.ok(OwnText.get_text("cond", 1, "") != "", "a condition name reads in Spanish")
	t.eq(OwnText.get_text("card", 999999, "fb"), "fb", "an unknown id falls back")
	if was != "":
		I18n.set_locale(was)
