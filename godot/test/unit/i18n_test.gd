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
	check_code_keys(t, tables["en"])

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


## Every literal I18n.t("key") in src/ must exist in the English table (the
## parity check above extends it to es/fr). A missing key renders as the raw
## key in the UI: S18 found 38 of them in the chat and status lines.
## Keys built at run time ("kanodo.kind." + kind) are not literals and are
## not checked here.
func _code_keys(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			var re := RegEx.create_from_string("I18n\\.t\\(\"([a-z0-9_.]+)\"")
			for line in FileAccess.get_file_as_string(dir.path_join(f)).split("\n"):
				if line.strip_edges().begins_with("#"):
					continue   # doc examples such as I18n.t("key")
				for m in re.search_all(line):
					var k := m.get_string(1)
					if not k.ends_with("."):
						out[k] = f
	for sub in d.get_directories():
		_code_keys(dir.path_join(sub), out)


func check_code_keys(t, en: Dictionary) -> void:
	var used := {}
	_code_keys("res://src", used)
	t.ok(used.size() > 300, "code scan found the I18n keys (%d)" % used.size())
	var missing: Array = []
	for k in used:
		if not en.has(k):
			missing.append("%s (%s)" % [k, used[k]])
	t.ok(missing.is_empty(), "every I18n key used in src/ exists: missing %s" % [missing])