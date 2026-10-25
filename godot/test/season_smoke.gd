extends "res://test/world_smoke.gd"

## S25: ladder seasons, live. In Spanish.
##
##   godot --path godot -s test/season_smoke.gd [-- --expect-season=N --expect-pesetas=P]
##
## 1. On arrival the client asks 60030 and gets 60031: the season is in the
##    model with its number and end.
## 2. The Ranking panel (1v1 tab) says "Temporada N · termina en D días".
## With --expect-pesetas (after forcing a close: set seasons.ends_at in the
## past, restart the server):
## 3. the result was shown (log line + toast) with those pesetas, and the
##    wallet holds them (type 10).
## 4. Asked again, the results do not come back (they are marked seen).

var _toasts: Array = []
var _want_season := 0
var _want_pesetas := -1


func _audit() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--expect-season="):
			_want_season = int(a.get_slice("=", 1))
		elif a.begins_with("--expect-pesetas="):
			_want_pesetas = int(a.get_slice("=", 1))
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	# 1. the arrival 60031 (it was sent before this audit started)
	await _wait(func(): return not (_main._gui.gui.model.get_value("season") as Variant == null), 4.0)
	var season: Variant = _main._gui.gui.model.get_value("season")
	var n := int(season.get("number", 0)) if season is Dictionary else 0
	_record(60031, "season", n > 0 and (_want_season == 0 or n == _want_season),
		"season %d, ends %s" % [n, Time.get_datetime_string_from_unix_time(int(season.get("ends", 0)) if season is Dictionary else 0)])
	# 2. the Ranking panel's line
	_close_all()
	_main._gui.open("ladderInformationDialog")
	await create_timer(0.8).timeout
	var p = _main._gui.dialogs.get("ladderInformationDialog")
	var line: Label = p.find_child("Season", true, false) if p != null else null
	_record(0, "ranking line", line != null and line.text.begins_with("Temporada %d" % n),
		line.text if line != null else "no season line in the Ranking panel")
	_close_all()
	if _want_pesetas >= 0:
		# 3. the result shown on arrival, and the wallet
		var box: Node = _main.get_node("Toasts/ToastBox")
		var shown := ""
		for c in box.get_children():
			for l in c.find_children("*", "Label", true, false):
				shown += (l as Label).text + " | "
		var pes := int(State.wallet.get(10, 0))
		_record(60031, "result", shown.contains("+%d pesetas" % _want_pesetas) and pes >= _want_pesetas,
			"toast '%s', wallet %d pesetas" % [shown, pes])
		# 4. asked again: no results
		_seen.erase(60031)
		var before: int = box.get_child_count()
		_sess.send(60030, PackedByteArray(), 2)
		await _wait(func(): return _seen.has(60031), 4.0)
		await create_timer(0.3).timeout
		_record(60031, "seen", _seen.has(60031) and box.get_child_count() <= before,
			"toasts %d → %d" % [before, box.get_child_count()])
	i18n.set_locale(lang_before)
