extends RefCounted
## ArtStyle — which look the fights use (sprints/S04).
##
##   "retail" — the original colour art (default)
##   "onebit" — 1-bit map art converted per texture (assets/mapgfx_1bit,
##              tools/asset-import/onebit.py), actors as line art, team auras
##
## Stored in user://settings.cfg [arena] art_style, next to the locale. The
## ARENA_ART_STYLE environment variable overrides it, for tests and renders.
## Only fight_view reads it: lobby and coach creation keep the retail art.

const PATH := "user://settings.cfg"
const STYLES := ["retail", "onebit"]

static var _cached = null


static func current() -> String:
	var env := OS.get_environment("ARENA_ART_STYLE")
	if env in STYLES:
		return env
	if _cached == null:
		var cfg := ConfigFile.new()
		var v := "retail"
		if cfg.load(PATH) == OK:
			v = str(cfg.get_value("arena", "art_style", "retail"))
		_cached = v if v in STYLES else "retail"
	return _cached


static func onebit() -> bool:
	return current() == "onebit"


static func set_style(style: String) -> void:
	if not style in STYLES:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # keep the other keys (locale)
	cfg.set_value("arena", "art_style", style)
	cfg.save(PATH)
	_cached = style
