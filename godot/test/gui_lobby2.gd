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
	_gui.model.set_value("calendar", {
		"currentMonth": "January 2012",
		"calendar": [{"day": "1", "events": [
			{"title": "T", "typeIcon": "", "description": "d",
				"registrationButton": true, "style": "", "id": 1}],
			"hasMoreEventsToShow": false, "style": ""}],
		"fullEventList": {"events": [], "style": ""},
		"eventFilter": {"showAllEvent": true,
			"tournamentEventFilter": true,
			"maintenanceEventFilter": true,
			"broadcastEventFilter": true}})
	_gui.model.set_value("itemOver", {})
	_gui.model.set_value("itemSelected", {})
	var cd := _gui.open_dialog("calendarDialog")
	print("[smoke] calendar:", "ok" if cd != null else "FAIL")
	_gui.model.set_value("achievementManager", {
		"achievementsList": [{"id": 1, "name": "First",
			"points": 10, "grade": 0, "iconUrl": "", "keyIconUrl": "",
			"completion": 100, "descriptionDone": "done",
			"isSelected": false, "style": "done", "subtypes": []}],
		"achievementTypesList": [{"name": "Type 0", "cat": 0,
			"isSelected": true,
			"subtypes": [{"name": "Type 0", "sub": 0, "cat": 0,
				"isSelected": true}]}],
		"achievementsTotalPoints": 10})
	_gui.model.set_value("selectedAchievementType", {"name": "Type 0",
		"cat": 0, "isSelected": true,
		"subtypes": [{"name": "Type 0", "sub": 0, "cat": 0,
			"isSelected": true}]})
	var ad := _gui.open_dialog("achievementDialog")
	print("[smoke] achievement:", "ok" if ad != null else "FAIL")
	var od := _gui.open_dialog("optionsDialog")
	print("[smoke] options:", "ok" if od != null else "FAIL")
	_gui.model.set_value("localCoach", {
		"filtredEquipmentCardInventory": [
			{"id": 1, "name": "Cape", "iconUrl": "1", "quantity": 2,
				"cardType": 8}],
		"zaapInventory": [], "specialCardInventory": [],
		"filtredSetCardInventory": [], "cardSets": [],
		"cardCostFilterList": [], "selectedCostFilter": ""})
	_gui.model.set_value("coachManagement", {"selectedCard": null,
		"currentSet": null})
	_gui.model.set_value("tomeManager", {"cheapSets": [],
		"expensiveSets": [], "specialSets": [], "fightSets": [],
		"evolutionSets": [], "zaapSets": []})
	var cb := _gui.open_dialog("cardBookDialog")
	print("[smoke] cardBook:", "ok" if cb != null else "FAIL")
	for r in [sd, cs, ld, cd, ad, od, cb]:
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
