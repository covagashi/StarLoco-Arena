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
	var gc := _gui.open_dialog("guildCreationDialog")
	print("[smoke] guildCreation:", "ok" if gc != null else "FAIL")
	_gui.model.set_value("guild",
		{"editableRanks": [{"name": "leader", "rankLevel": 1,
			"rankIconUrl": "", "canInvite": true, "canRemove": false,
			"canPromote": false, "canDepromote": false},
			{"name": "member", "rankLevel": 10, "rankIconUrl": "",
			"canInvite": false, "canRemove": false, "canPromote": false,
			"canDepromote": false}]})
	_gui.model.set_value("guildSelectedRank", {})
	var gm := _gui.open_dialog("guildManagementDialog")
	print("[smoke] guildMgmt:", "ok" if gm != null else "FAIL")
	_gui.model.set_value("guildCoachStats", {"name": "boss", "level": 3,
		"actorDescriptorLibrary": "coach_7000", "rankIconUrl": "",
		"guildRankIconUrl": "", "statisticsTotalFights": 10,
		"statisticsTotalFightsWon": 6, "statisticsTotalFightsLost": 4,
		"statisticsConsecutiveWins": 2, "statisticsTotalPlayTime": 100,
		"statisticsTotalFightsTime": 50})
	_gui.model.set_value("guildCanPromote", true)
	_gui.model.set_value("guildCanDepromote", true)
	_gui.model.set_value("guildExcluder", true)
	var gs := _gui.open_dialog("guildCoachStatsDialog")
	print("[smoke] guildCoachStats:", "ok" if gs != null else "FAIL")
	_gui.model.set_value("mailManager", {"receivedMails": [
		{"mailId": 1, "sender": "boss", "receiver": "me",
			"title": "hi", "date": "01/01/2012", "read": false,
			"hasItems": true, "style": "", "message": "body",
			"cards": [{"id": 1, "name": "Cape", "iconUrl": "1",
				"quantity": 1}]}],
		"sentMails": []})
	_gui.model.set_value("mailbox.mail", {})
	var mb := _gui.open_dialog("mailboxDialog")
	print("[smoke] mailbox:", "ok" if mb != null else "FAIL")
	_gui.model.set_value("mailbox.newMail", {"receiver": "", "title": "",
		"message": "", "cards": [], "receiverId": 0})
	var nm := _gui.open_dialog("newMailDialog")
	print("[smoke] newMail:", "ok" if nm != null else "FAIL")
	_gui.model.set_value("cardMasterTrade", {
		"cardMasterCardExchange": [
			{"id": 1, "name": "Cape", "iconUrl": "1",
				"illustrationUrl": "1", "value": 50,
				"requiredLevel": "", "typeIconUrl": "",
				"cardSetName": "s", "description": "d",
				"quantity": 1}],
		"localCardExchange": [null, null, null, null],
		"cardMasterCardsPrice": 50, "localCardsPrice": 0,
		"canBuyCards": false, "selectedCard": null})
	_gui.model.set_value("exchange.cardTrade", 7, "exchangeId")
	var cm := _gui.open_dialog("cardMasterDialog")
	print("[smoke] cardMaster:", "ok" if cm != null else "FAIL")
	_gui.model.set_value("exchange.remoteCoach", {"name": "peer",
		"actorDescriptorLibrary": "coach_7000"})
	_gui.model.set_value("exchange.cardTrade", {
		"exchangeId": 5,
		"localCardExchange": [{"id": 1, "name": "Cape",
			"iconUrl": "1", "illustrationUrl": "1", "value": 50,
			"quantity": 2, "requiredLevel": "", "typeIconUrl": "",
			"cardSetName": "s", "description": "d"}],
		"remoteCardExchange": [null, null, null, null],
		"localCardsValue": 100, "remoteCardsValue": 0,
		"localUserReady": false, "remoteUserReady": false,
		"readyButtonEnabled": true})
	var ex := _gui.open_dialog("exchangeDialog")
	print("[smoke] exchange:", "ok" if ex != null else "FAIL")
	_gui.model.set_value("teamManagement", {
		"fighters": [{"id": 7, "fighterId": 7, "name": "Iopette",
			"breedId": 1, "sex": 1, "state": 0, "level": 42,
			"moraleForProgressBar": 50, "tirednessForProgressBar": 10,
			"actorDescriptorLibrary": "fighter_-110",
			"actorAnimation": "AnimStatique", "actorDirection": 3,
			"actorMaterial": [], "iconUrl": "10", "typeIconUrl": ""}]},
		"editableTeamPreset")
	_gui.model.set_value("evolutionTeam",
		{"fightersOnBench": [null]})
	_gui.model.set_value("tomeManager", {"evolutionSets": [
		{"name": "Wabbits", "description": "", "collection": []}]})
	var tm := _gui.open_dialog("teamManagementDialog")
	print("[smoke] teamMgmt:", "ok" if tm != null else "FAIL")
	_gui.model.set_value("teamManagement", {
		"id": 7, "fighterId": 7, "name": "Iopette", "breedId": 1, "sex": 1,
		"maxHealthPoints": 400, "maxActionPoints": 6, "maxMovePoints": 3,
		"initiativePoints": 0, "criticalHitBonus": 0, "rangeBonus": 0,
		"healBonus": 0, "damagesRebound": 0, "dodgePercent": 0,
		"tacklePercent": 0,
		"resEarthPercent": 0, "resFirePercent": 0, "resWaterPercent": 0,
		"resWindPercent": 0,
		"dmgEarthPercent": 0, "dmgFirePercent": 0, "dmgWaterPercent": 0,
		"dmgWindPercent": 0,
		"actorDescriptorLibrary": "fighter_-110",
		"actorAnimation": "AnimStatique", "actorDirection": 3,
		"actorMaterial": [],
		"weaponEquipment": null, "petEquipment": null,
		"cloakEquipment": null, "hatEquipment": null,
		"dofusEquipment": null,
		"spells": [null], "breedSpells": [
			{"id": 31, "name": "Cloudy Attack", "iconUrl": "31",
				"actionPoints": 4, "range": "1-4", "value": 250,
				"cardType": "spell"}]},
		"editableFighter")
	_gui.model.set_value("teamManagement", [], "selectedItemCardList")
	var fe := _gui.open_dialog("fighterEquipmentDialog")
	print("[smoke] fighterEquip:", "ok" if fe != null else "FAIL")
	for r in [sd, cs, ld, cd, ad, od, cb, gc, gm, gs, mb, nm, cm, ex, tm, fe]:
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
