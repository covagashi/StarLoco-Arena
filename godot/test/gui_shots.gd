extends SceneTree
## Render retail dialogs to PNGs for visual review — run WINDOWED
## (headless hangs on SubViewport readback):
##   godot --path godot -s test/gui_shots.gd

var _gui: GuiLib
var _vp: SubViewport
var _out := "user://gui_shots"
var _names: Array = []
var _i := 0
var _wait := 0
var _pending: GWidget = null
var _pending_name := ""


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1024, 768)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_gui = GuiLib.new("es")
	_seed_model()
	_names = ["teamManagementDialog", "teamNameDialog",
		"fighterEquipmentDialog", "cardBookDialog", "socialDialog",
		"mapDialog", "evolutionDialog", "menuDialog"]
	print("[shots] out: %s" % ProjectSettings.globalize_path(_out))


func _process(_dt: float) -> bool:
	if _pending != null:
		if _wait > 0:
			_wait -= 1
			return false
		var img := _vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [_out, _pending_name])
		print("[shots] %s.png saved" % _pending_name)
		_pending.queue_free()
		_pending = null
		_wait = 2
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if _i >= _names.size():
		quit(0)
		return true
	var name: String = _names[_i]
	_i += 1
	var dlg := _gui.open_dialog(name)
	if dlg == null:
		print("[shots] %s: FAIL (null)" % name)
		return false
	_vp.add_child(dlg)
	_place_root(dlg, Vector2(_vp.size))
	GuiLayouts.apply(dlg)
	dlg.queue_redraw()
	_pending = dlg
	_pending_name = name
	_wait = 8
	return false


func _seed_model() -> void:
	var m := _gui.model
	m.set_value("localCoach", {
		"name": "test", "sex": 0, "skin": 1, "hair": 1,
		"actorDescriptorLibrary": "coach_7000",
		"actorAnimation": "AnimStatique", "actorDirection": 3,
		"actorMaterial": {}, "standing": 1200,
		"standingForProgressBar": 1200,
		"standingNeededForNextLevel": 2000, "strenght": 42,
		"strengthForProgressBar": 42, "strengthNeededForNextLevel": 100,
		"tournamentToken": 7, "level": 3,
		"statisticsTotalFights": 10, "statisticsTotalFightsWon": 6,
		"statisticsTotalFightsLost": 4})
	m.set_value("friends", {"list": [
		{"name": "ami1", "online": true, "connected": true, "notify": 1},
		{"name": "ami2", "online": false, "connected": false, "notify": 0}]})
	m.set_value("ignore", {"list": [{"name": "mechant"}]})
	m.set_value("guild", {"name": "StarLoco", "canManage": false,
		"members": [{"name": "boss", "connected": true}],
		"guildInfos": ""})
	var fitem := {
		"id": 7, "fighterId": 7, "name": "Iopette", "breedId": 1,
		"sex": 1, "level": 12, "budget": 300, "value": 250,
		"maxHealthPoints": 400, "maxActionPoints": 6,
		"maxMovePoints": 3, "initiativePoints": 120,
		"criticalHitBonus": 0, "rangeBonus": 0, "healBonus": 0,
		"damagesRebound": 0, "dodgePercent": 0, "tacklePercent": 0,
		"resEarthPercent": 0, "resFirePercent": 0,
		"resWaterPercent": 0, "resWindPercent": 0,
		"dmgEarthPercent": 0, "dmgFirePercent": 0,
		"dmgWaterPercent": 0, "dmgWindPercent": 0,
		"tiredness": 30, "morale": 80, "state": 0,
		"conditions": [], "teamMember": false,
		"actorDescriptorLibrary": "fighter_-110",
		"actorAnimation": "AnimStatique", "actorDirection": 3,
		"actorMaterial": [],
		"weaponEquipment": null, "petEquipment": null,
		"cloakEquipment": null, "hatEquipment": null,
		"dofusEquipment": null,
		"spells": [null],
		"breedSpells": [{"id": 31, "name": "Cloudy Attack",
			"iconUrl": "31", "actionPoints": 4, "range": "1-4",
			"value": 250, "cardType": "spell"}]}
	m.set_value("teamManagement", {
		"editableFighter": fitem,
		"editableTeamPreset": {
			"name": "Mi equipo", "value": 900,
			"fighters": [fitem, fitem, null, null, null, null],
			"selectedFighters": [fitem, fitem],
			"legendaryFighters": [fitem]},
		"teamManager": {
			"teamPreset1vs1List": [{"id": 4, "teamId": 4,
				"name": "Alpha", "isEditable": true, "level": 2,
				"strength": 800, "totalVictories": 5,
				"totalDefeats": 1, "consecutiveVictories": 3,
				"fighters": [fitem], "selectedFighters": [fitem],
				"isBestTeam": false}],
			"teamPreset2vs2List": [], "tournamentsList": [],
			"teamsIconsList": [], "teamsBackgroundsList": []},
		"teamName": "", "teammateName": ""})
	m.set_value("evolutionTeam", {
		"fightersOnBench": [fitem],
		"legendaryFightersOnBench": [fitem],
		"legendaryValue": 250})
	m.set_value("tomeManager", {"evolutionSets": [
		{"name": "Wabbits", "description": "", "collection": []}]})
	m.set_value("coachManagement", {
		"selectedCard": {"id": 1, "name": "Carta", "iconUrl": "31"},
		"currentSet": {"name": "Set", "collection": []}})
	m.set_value("miniMap", {"mapId": 0, "points": [], "zoom": 1.0})
	m.set_value("onlyTabEnabledId", -1)
	m.set_value("itemOver", {})
	m.set_value("itemSelected", {})


## same placement GuiLayer uses — resolves the root's <sld> against vp
func _place_root(root: GWidget, vp: Vector2) -> void:
	var ld: Dictionary = root.layout_data
	var want := root.get_minimum_size()
	var size := want
	if ld.has("size"):
		var sv: Array = ld["size"]
		size = Vector2(_ld_axis(sv[0], want.x, vp.x),
			_ld_axis(sv[1], want.y, vp.y))
	elif root.layout.get("adaptToContentSize") in [true, "true"]:
		size = want
	elif want == Vector2.ZERO:
		size = vp
	var a: Vector2 = GuiLayouts.ALIGN.get(
		String(ld.get("align", "center")).to_lower(), Vector2(0.5, 0.5))
	root.position = a * (vp - size) + Vector2(
		float(ld.get("xOff", 0)), float(ld.get("yOff", 0)))
	root.size = size


static func _ld_axis(spec: Variant, want: float, avail: float) -> float:
	if spec is String and String(spec).ends_with("%"):
		return avail * float(String(spec).rstrip("%")) / 100.0
	var f := float(spec)
	if f <= 0:
		return want
	return f
