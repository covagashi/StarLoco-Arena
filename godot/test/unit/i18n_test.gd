extends RefCounted
## CI-safe: assets/i18n/ui_{es,en,fr}.json are tracked in git (the rest of
## assets/ is gitignored, see AGENTS.md), so this suite needs no asset import
## to run headless. Guards the i18n table contract that src/i18n/i18n.gd
## relies on at runtime: all three tables parse, cover the same key set, and
## carry no blank values.
##
## Deliberately NOT asserted: that a translation differs from English. 31
## Spanish and 57 French values are legitimately identical ("OK", proper
## nouns) — flagging those would just be noise.

const PATHS := {
	"es": "res://assets/i18n/ui_es.json",
	"en": "res://assets/i18n/ui_en.json",
	"fr": "res://assets/i18n/ui_fr.json",
}

## A sanity FLOOR, not the exact count (718 as of 2026-10-13). Parity between
## the three locales is a real invariant and is asserted strictly below; the
## absolute total is not — it grows every time a UI string is added. An exact
## count here would fail on legitimate work whose "fix" is editing this
## number, which teaches people to edit numbers without reading them. The
## floor still catches what actually matters: a truncated or emptied table.
const MIN_KEY_COUNT := 600


func run(t) -> void:
	t.suite("i18n")
	var tables := {}
	for lang in PATHS:
		var f := FileAccess.open(PATHS[lang], FileAccess.READ)
		t.ok(f != null, "%s: file opens" % lang)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		t.ok(parsed is Dictionary, "%s: parses as a JSON object" % lang)
		tables[lang] = parsed if parsed is Dictionary else {}

	if tables.size() != PATHS.size():
		return   # a file failed to open/parse — key-set diffs would be noise

	var en_keys: Array = tables["en"].keys()
	en_keys.sort()
	t.ok(en_keys.size() >= MIN_KEY_COUNT,
		"en key count %d is above the sanity floor %d" % [
			en_keys.size(), MIN_KEY_COUNT])

	for lang in ["es", "fr"]:
		var keys: Array = tables[lang].keys()
		keys.sort()
		t.eq(keys.size(), en_keys.size(), "%s key count matches en" % lang)
		var missing := []
		for k in en_keys:
			if not tables[lang].has(k):
				missing.append(k)
		var extra := []
		for k in keys:
			if not tables["en"].has(k):
				extra.append(k)
		t.ok(missing.is_empty() and extra.is_empty(),
			"%s key set matches en (missing=%s extra=%s)" % [lang, missing, extra])

	for lang in tables:
		var blanks := []
		for k in tables[lang]:
			var v: Variant = tables[lang][k]
			if not (v is String) or String(v).strip_edges().is_empty():
				blanks.append(k)
		t.ok(blanks.is_empty(),
			"%s has no empty/whitespace-only values (%s)" % [lang, blanks])
