extends SceneTree
## socialDialog + coachStatisticsDialog + ladderInformationDialog load smoke

var _gui: GuiLib


func _init() -> void:
	var vp := get_root()
	_gui = GuiLib.new("es")
	_gui.model.set_value("friends", {"list": [
		{"name": "ami1", "online": true, "connected": true, "notify": 1},
		{"name": "ami2", "online": false, "connected": false, "notify": 0}]})
	_gui.model.set_value("ignore", {"list": [{"name": "mechant"}]})
	_gui.model.set_value("guild", {"name": "StarLoco", "canManage": false,
		"members": [{"name": "boss", "connected": true}], "guildInfos": ""})
	var sd := _gui.open_dialog("socialDialog")
	print("[smoke] social:", "ok" if sd != null else "FAIL")
	_gui.model.set_value("localCoach", {
		"name": "test", "sex": 0, "skin": 1, "hair": 1,
		"actorDescriptorLibrary": "coach_7000",
		"actorAnimation": "AnimStatique", "actorDirection": 3,
		"actorMaterial": {},
		"standing": 1200, "standingForProgressBar": 1200,
		"standingNeededForNextLevel": 2000, "strenght": 42,
		"strengthForProgressBar": 42, "strengthNeededForNextLevel": 100,
		"tournamentToken": 7, "level": 3,
		"statisticsTotalFights": 10, "statisticsTotalFightsWon": 6,
		"statisticsTotalFightsLost": 4})
	var cs := _gui.open_dialog("coachStatisticsDialog")
	print("[smoke] coachStats:", "ok" if cs != null else "FAIL")
	_gui.model.set_value("ladderManager", {
		"list1vs1": [{"position": 1, "coachName": "x", "guildName": "g",
			"level": 2, "totalVictories": 5, "totalDefeats": 1,
			"consecutiveVictories": 3}],
		"listReputation": [], "list2vs2": [], "listGuild": [],
		"listTournamentInTheMonth": [], "listTournamentInTheTrimester": [],
		"listTournamentInTheYear": [], "listGlickoRating": [],
		"listDemon": []})
	var ld := _gui.open_dialog("ladderInformationDialog")
	print("[smoke] ladder:", "ok" if ld != null else "FAIL")
	for r in [sd, cs, ld]:
		if r != null:
			vp.add_child(r)
	if sd != null:
		var rows := _count_kind(sd, "list")
		print("[smoke] social lists:", rows)
	quit()


func _count_kind(w: GWidget, k: String) -> int:
	var n := 1 if w.kind == k else 0
	for ch in w.get_children():
		if ch is GWidget:
			n += _count_kind(ch, k)
	return n
