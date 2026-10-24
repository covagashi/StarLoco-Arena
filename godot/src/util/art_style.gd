extends RefCounted
## ArtStyle — client-only fight look options (sprints/S17), stored in
## user://settings.cfg [arena], next to the locale.

const PATH := "user://settings.cfg"


## How the fight HUD's cards show life (sprints/S17): "ring" round the
## portrait (default, the owner's pick on 2026-10-17) or "bar" under it.
## [arena] hud_life, or the ARENA_HUD_LIFE environment variable.
const HUD_LIFE := ["bar", "ring"]

static func hud_life() -> String:
	var env := OS.get_environment("ARENA_HUD_LIFE")
	if env in HUD_LIFE:
		return env
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var v := str(cfg.get_value("arena", "hud_life", "ring"))
		if v in HUD_LIFE:
			return v
	return "ring"


static func set_hud_life(v: String) -> void:
	if not v in HUD_LIFE:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("arena", "hud_life", v)
	cfg.save(PATH)
