extends RefCounted
## S07: spell and card names follow the UI language through the retail's
## own text tables (assets/gui/i18n_<lang>.json, git-ignored). Without them
## — a fresh checkout, the CI lane — the English export must still show.

func run(t) -> void:
	t.suite("game_text")
	var gt = load("res://src/gamedata/game_text.gd")
	var assets = load("res://src/util/asset_paths.gd")
	var state = load("res://src/state.gd")
	var lang_before: String = state.locale
	assets.set_roots([])
	gt._tables.clear()
	state.locale = "es"
	t.eq(gt.content(gt.SPELL, 31, "Cloudy Attack"), "Cloudy Attack",
		"no text tables: the English fallback")
	t.eq(gt.content(gt.CARD, 999999, "Card 999999"), "Card 999999",
		"unknown id: the fallback")
	assets.reset_roots()
	gt._tables.clear()
	state.locale = lang_before
