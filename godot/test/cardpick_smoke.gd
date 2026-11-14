extends "res://test/world_smoke.gd"

## S40: the leagues and the "pick one card of three" against a live server.
##
##   godot --path godot -s test/cardpick_smoke.gd [-- --shot-dir=D]
##
## Seed the `test` coach with a pending offer first (card_picks.offer, e.g.
## "543,900,861"): the smoke checks that
##  1. 60045 and 60046 come with the lobby's 60001 (league bronze, 4000);
##  2. the Elite team screen shows "Liga Bronce · presupuesto … / 4000";
##  3. the Ranking shows the league line;
##  4. the fight report shows the three cards; a click keeps one: the server
##     answers 60045 with no offer and the card lands in the inventory (5200).

var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	var model = _main._gui.gui.model
	var got: bool = await _wait(func():
		return model.get_value("league") is Dictionary and model.get_value("cardPicks") is Dictionary, 6.0)
	var lg: Dictionary = model.get_value("league") if got else {}
	var picks: Dictionary = model.get_value("cardPicks") if got else {}
	_record(60046, "league", got and int(lg.get("tier", -1)) == 0 and int(lg.get("budget", 0)) == 4000,
		"60001 → 60045 + 60046: %s, picks %s" % [lg, picks])
	var offer: Array = picks.get("offer", [])
	_record(60045, "offer", offer.size() == 3, "pending offer %s" % [offer])

	# the Elite team screen: the league's budget against the team's
	model.set_value("gamePreferences", 1, "lastSelectedGameModeId")
	_main._gui.open("teamManagementDialog")
	await create_timer(0.8).timeout
	var team = _main._gui.dialogs.get("teamManagementDialog")
	var line: Label = team.find_child("LeagueBudget", true, false) if team != null else null
	_record(60046, "team", line != null and "Bronce" in line.text and "4000" in line.text,
		line.text if line != null else "no LeagueBudget label")
	await _shot("team-league")
	_main._gui.close("teamManagementDialog")
	await create_timer(0.4).timeout

	# the Ranking: the league line over the 1v1 board
	_main._gui.open("ladderInformationDialog")
	await create_timer(0.8).timeout
	var ladder = _main._gui.dialogs.get("ladderInformationDialog")
	var ll: Label = ladder.find_child("League", true, false) if ladder != null else null
	_record(60046, "ranking", ll != null and "Bronce" in ll.text,
		ll.text if ll != null else "no League label")
	await _shot("ranking-league")
	_main._gui.close("ladderInformationDialog")
	await create_timer(0.4).timeout

	# the fight report: the offer as tiles; a click keeps one
	model.set_value("fightReport", {"outcome": "victory", "summary": [], "coaches": [],
		"fighters": [], "cards": []})
	_main._gui.open("fightReportDialog")
	await create_timer(0.8).timeout
	var report = _main._gui.dialogs.get("fightReportDialog")
	var tiles: Node = report.find_child("PickOffer", true, false) if report != null else null
	_record(60045, "report", tiles != null and tiles.get_child_count() == 3,
		"%d tile(s)" % (tiles.get_child_count() if tiles != null else 0))
	await _shot("report-pick")
	if tiles == null or tiles.get_child_count() == 0:
		i18n.set_locale(_lang_before)
		return
	var pick := int(offer[0].get("id", 0))
	_seen.clear()
	(tiles.get_child(0) as Button).pressed.emit()
	var answered: bool = await _wait(func(): return _seen.has(60045) and _seen.has(5200), 5.0)
	await create_timer(0.6).timeout
	var after: Dictionary = model.get_value("cardPicks")
	var gone: bool = report.find_child("PickOffer", true, false) == null \
		and report.find_child("PickProgress", true, false) != null
	_record(60044, "pick", answered and after.get("offer", [1]).is_empty() and gone
		and int(State.inventory.get(pick, 0)) > 0,
		"kept %d → 60045 %s, inventory ×%d, report shows the progress: %s" % [
			pick, after, int(State.inventory.get(pick, 0)), gone])
	await _shot("report-picked")
	i18n.set_locale(_lang_before)
