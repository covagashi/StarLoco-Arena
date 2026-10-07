extends Node
## I18n — tiny string-table autoload for the native (non-retail-XML) UI.
##
## Locale resolution order:
##   1. user://settings.cfg [arena] locale (a manual pick in Options)
##   2. user://gui_settings.cfg [gui] language (a pick from an older build)
##   3. OS.get_locale() prefix — "es_ES" -> "es"
##   4. "en" fallback (the tables always carry an English row)
##
## Tables live in assets/i18n/ui_<lang>.json: flat {key: text} maps. A missing
## key falls back to English, then to the key itself so a typo is visible
## rather than silent. `I18n.t("key")` / `I18n.t("key", {fmt args})`.
##
## set_locale writes BOTH stores so the retail XML layer (gui_settings.cfg
## [gui] language) and the native panels stay on the same language. The
## "setLanguage" gui event routes here too (see gui_layer.gd).

signal locale_changed(lang: String)

const State := preload("res://src/state.gd")
const LANGS := ["es", "en", "fr"]
const NAMES := {"es": "Español", "en": "English", "fr": "Français"}
const _PATH := "res://assets/i18n/ui_%s.json"

var lang := ""
var _table := {}
var _fallback := {}


func _ready() -> void:
	set_locale(_saved() if _saved() in LANGS else detected())


func detected() -> String:
	# OS.get_locale() -> "es_ES", "en_US", "fr_FR"... take the language half.
	var l := OS.get_locale().split("_")[0].split("-")[0].to_lower()
	return l if l in LANGS else "en"


func _saved() -> String:
	for src in [["user://settings.cfg", "arena", "locale"],
			["user://gui_settings.cfg", "gui", "language"]]:
		var cfg := ConfigFile.new()
		if cfg.load(src[0]) == OK:
			var l := str(cfg.get_value(src[1], src[2], ""))
			if l in LANGS:
				return l
	return ""


func set_locale(l: String) -> void:
	if not l in LANGS or (l == lang and not _table.is_empty()):
		return
	lang = l
	_load()
	for src in [["user://settings.cfg", "arena", "locale"],
			["user://gui_settings.cfg", "gui", "language"]]:
		var cfg := ConfigFile.new()
		cfg.load(src[0])   # keep other keys
		cfg.set_value(src[1], src[2], l)
		cfg.save(src[0])
	State.locale = lang
	locale_changed.emit(l)


func _load() -> void:
	_table = _read(_PATH % lang)
	_fallback = _read(_PATH % "en")


func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## tr("key") or tr("key", {a: x}) — "{a}" placeholders expand inline.
func t(key: String, args: Dictionary = {}) -> String:
	var s: String = _table.get(key, _fallback.get(key, key))
	for k in args:
		s = s.replace("{%s}" % k, str(args[k]))
	return s


## Convenience for format-style strings ("%d", "%s"): t("key") % args.
func tf(key: String, args: Array) -> String:
	return t(key) % args
