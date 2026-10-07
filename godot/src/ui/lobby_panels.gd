extends "res://src/ui/lobby_panel.gd"

const Direction8 := preload("res://src/util/direction8.gd")
## Native presentations over the existing GuiModel and action handlers.
## No XML layout or protocol serialization lives in these panels.

const TITLES := {
	"menuDialog": "panel.menu", "teamManagementDialog": "panel.team",
	"evolutionDialog": "panel.team", "coachStatisticsDialog": "panel.stats",
	"cardBookDialog": "panel.inventory", "ladderInformationDialog": "panel.ladder",
	"calendarDialog": "panel.calendar", "achievementDialog": "panel.achievements",
	"socialDialog": "panel.social", "tooltipDialog": "panel.help",
	"optionsDialog": "panel.options",
	"fighterCreationDialog": "panel.new_fighter",
	"fighterEquipmentDialog": "panel.fighter_equip",
	"teamNameDialog": "panel.new_team", "team2vs2NameDialog": "panel.new_team2v2",
	"newTeamTournamentDialog": "panel.new_team_tournament",
	"guildDialog": "panel.guild", "guildCreationDialog": "panel.guild_create",
	"guildManagementDialog": "panel.guild_ranks",
	"guildCoachStatsDialog": "panel.guild_member",
}
var _preview
var _preview_look := ""
var _preview_dir := Direction8.FRONT

const FORMS := ["fighterCreationDialog", "teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog", "optionsDialog"]
const BOARDS := ["list1vs1", "listReputation", "list2vs2", "listGuild", "listTournamentInTheMonth", "listGlickoRating", "listDemon"]
const EQ_FIELDS := ["weaponEquipment", "petEquipment", "cloakEquipment", "hatEquipment", "dofusEquipment"]
const BREEDS := ["Feca", "Osamodas", "Anutrof", "Sram", "Xelor", "Zurcarák", "Aniripsa", "Yopuka", "Ocra", "Sadida", "Sacrógrito", "Pandawa"]
const LOCALES := ["es", "en", "fr"]


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if panel_name in FORMS:
		if panel_name == "fighterCreationDialog" and model_name == "teamManagement":
			_sync_preview()
		return
	var watched := {
		"teamManagementDialog": ["teamManagement", "evolutionTeam"],
		"evolutionDialog": ["teamManagement", "evolutionTeam"],
		"fighterEquipmentDialog": ["teamManagement"],
		"coachStatisticsDialog": ["localCoach"], "cardBookDialog": ["localCoach", "tomeManager"],
		"ladderInformationDialog": ["ladderManager"], "calendarDialog": ["calendar"],
		"achievementDialog": ["achievementManager"], "socialDialog": ["friends", "ignore", "guild"],
		"guildDialog": ["friends", "ignore", "guild"],
		"guildManagementDialog": ["guild", "guildSelectedRank"],
		"guildCoachStatsDialog": ["guildCoachStats"],
	}
	if model_name.split(".")[0] in watched.get(panel_name, []):
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var key: String = TITLES.get(panel_name, "")
	title.text = I18n.t(key) if key != "" else panel_name
	match panel_name:
		"menuDialog": _menu()
		"teamManagementDialog", "evolutionDialog": _team()
		"coachStatisticsDialog": _statistics()
		"cardBookDialog": _inventory()
		"ladderInformationDialog": _ladder()
		"calendarDialog": _calendar()
		"achievementDialog": _achievements()
		"socialDialog": _social()
		"guildDialog":
			tab = 2
			_social()
		"guildCreationDialog": _guild_creation()
		"guildManagementDialog": _guild_management()
		"guildCoachStatsDialog": _guild_member()
		"tooltipDialog": _help()
		"optionsDialog": _options()
		"fighterCreationDialog": _fighter_creation()
		"fighterEquipmentDialog": _equipment()
		"teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog": _team_name()


func _menu() -> void:
	label(body, I18n.t("menu.subtitle"), 22)
	var actions := column(body)
	for entry in [["menu.options", "optionsDialog"], ["menu.help", "tooltipDialog"], ["menu.team", "teamManagementDialog"]]:
		button(actions, I18n.t(entry[0]), func():
			closed.emit()
			send("nativeOpen", [entry[1]]))
	button(actions, I18n.t("menu.bug_report"), func(): send("openBugReport"))
	button(actions, I18n.t("menu.disconnect"), func(): confirm_action(I18n.t("menu.disconnect_confirm"), func(): send("nativeDisconnect")))
	button(actions, I18n.t("menu.quit"), func(): confirm_action(I18n.t("menu.quit_confirm"), func(): send("quit")))


func _team() -> void:
	tab = clampi(int(data("gamePreferences.lastSelectedGameModeId", tab)), 0, 4)
	tabs(body, [I18n.t("team.tab_evolution"), I18n.t("team.tab_elite"),
		I18n.t("team.tab_duo"), I18n.t("team.tab_tournaments"),
		I18n.t("team.tab_legends")], func(i): send("changeTeamTab", [], null, i))
	var classic := tab in [1, 2, 3]
	var toolbar := row(body)
	if classic:
		var presets: Array = data("teamManagement.teamManager.teamPreset1vs1List", []) + data("teamManagement.teamManager.teamPreset2vs2List", [])
		var names: Array = [I18n.t("team.pick_preset")]
		var picked := 0
		for p in presets:
			names.append(str(p.get("name", "Equipo")))
			if int(p.get("id", -1)) == int(draft.get("preset_id", -2)):
				picked = names.size() - 1
		choices(toolbar, names, picked, func(i):
			if i > 0:
				draft["preset_id"] = presets[i - 1].id
				send("selectTeamPreset", [], presets[i - 1])
				send("changeTeamTab", [], null, tab))
		button(toolbar, I18n.t("team.new"), func(): send("nativeOpen", [["teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog"][tab - 1]]))
		button(toolbar, I18n.t("team.save"), func(): send("saveTeam"), picked > 0)
		button(toolbar, I18n.t("team.delete"), func(): confirm_action(I18n.t("team.delete_confirm"), func(): send("deleteEditableTeamPreset")), picked > 0)
	else:
		label(toolbar, I18n.t("team.titulars") if tab == 0 else I18n.t("team.legends"), 20)
	button(toolbar, I18n.t("team.create_fighter"), func(): send("createNewFighter" if classic else "createNewEvolutionFighter"))
	var fighters: Array = data("teamManagement.editableTeamPreset.fighters", [])
	if tab == 0:
		fighters = fighters + data("evolutionTeam.fightersOnBench", [])
	elif tab == 4:
		fighters = data("teamManagement.editableTeamPreset.legendaryFighters", []) + data("evolutionTeam.legendaryFightersOnBench", [])
	var rows: Array = []
	for fighter in fighters:
		if not fighter is Dictionary:
			continue
		var item: Dictionary = fighter.duplicate()
		item["breed_name"] = BREEDS[clampi(int(item.get("breedId", 1)) - 1, 0, 11)]
		item["placement"] = (I18n.t("team.in_team") if item.get("teamMember", false) else I18n.t("team.reserve")) if classic else (I18n.t("team.bench") if int(item.get("state", 0)) in [1, 5] else I18n.t("team.starter"))
		rows.append(item)
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster := column(split)
	label(roster, I18n.t("team.count", {"n": rows.size()}), 20)
	table(roster, [I18n.t("team.col_name"), I18n.t("team.col_class"), I18n.t("team.col_pos")], ["name", "breed_name", "placement"], rows, func(_item): schedule_refresh())
	var detail := column(split, false)
	detail.custom_minimum_size.x = 260
	if selected.is_empty():
		label(detail, I18n.t("team.select_hint"))
		label(detail, I18n.t("team.empty_hint"))
	else:
		label(detail, str(selected.get("name", "")), 23)
		label(detail, "%s · %s" % [selected.get("breed_name", ""), selected.get("placement", "")])
		button(detail, I18n.t("team.equip_spells"), func(): send("editFighter", [selected], selected))
		if classic:
			button(detail, I18n.t("team.remove_member") if selected.get("teamMember", false) else I18n.t("team.add_member"), func(): send("addRemoveFighterFromEditableTeamPreset", [], selected), int(draft.get("preset_id", -1)) > 0)
		else:
			button(detail, I18n.t("team.toggle_status"), func(): send("changeFighterStatus", [], selected), int(selected.get("state", 0)) != 3)
		if not classic:
			button(detail, I18n.t("team.make_legend"), func(): confirm_action(I18n.t("team.make_legend_confirm"), func(): send("becomeALegend", [selected], selected)))
		button(detail, I18n.t("team.delete_fighter"), func(): confirm_action(I18n.t("team.delete_fighter_confirm", {"name": selected.get("name", "")}), func(): send("deleteFighter", [selected], selected)))
	pinned_actions.show()
	var footer := pinned_actions
	var hint := label(footer, I18n.t("team.synced"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button(footer, I18n.t("team.practice"), func(): send("launchTeamTest"))
	button(footer, I18n.t("team.find_fight"), func(): send("launchEvolutionFight" if tab == 0 else "setClassicReadyForFight"), tab in [0, 1, 2])
	if tab in [3, 4]:
		label(body, I18n.t("team.not_available",
			{"mode": I18n.t("team.mode_tourn") if tab == 3 else I18n.t("team.mode_legends")}))


func _statistics() -> void:
	var coach: Dictionary = data("localCoach", {})
	label(body, str(coach.get("name", "")), 24)
	var rows: Array = []
	for entry in [["stats.fights", "statisticsTotalFights"], ["stats.wins", "statisticsTotalFightsWon"], ["stats.losses", "statisticsTotalFightsLost"], ["stats.win_streak", "statisticsConsecutiveWins"], ["stats.time_played", "statisticsTotalPlayTime"], ["stats.time_fights", "statisticsTotalFightsTime"], ["stats.tourn_pts", "statisticsTournamentPoints"], ["stats.reputation", "standing"]]:
		var value: Variant = coach.get(entry[1], 0)
		# the wire reports the two time counters in seconds — minutes read better
		if entry[1] in ["statisticsTotalPlayTime", "statisticsTotalFightsTime"]:
			value = "%d min" % (int(value) / 60)
		rows.append({"name": I18n.t(entry[0]), "value": value})
	table(body, [I18n.t("stats.col_name"), I18n.t("stats.col_value")], ["name", "value"], rows)


func _inventory() -> void:
	tabs(body, [I18n.t("inv.all"), I18n.t("inv.equipment"),
		I18n.t("inv.special"), I18n.t("inv.sets")])
	var paths := ["cardInventory", "filtredEquipmentCardInventory", "specialCardInventory", "cardSets"]
	var items: Array = data("localCoach." + paths[tab], [])
	var toolbar := row(body)
	var search := field(toolbar, "search", I18n.t("inv.search_ph"))
	button(toolbar, I18n.t("inv.search"), schedule_refresh)
	search.text_submitted.connect(func(_text): schedule_refresh())
	button(toolbar, I18n.t("inv.clear"), func(): draft["search"] = ""; schedule_refresh())
	items = items.filter(func(item): return str(item.get("name", "")).to_lower().contains(str(draft.get("search", "")).to_lower()))
	table(body, [I18n.t("inv.col_set"), I18n.t("inv.col_owned"), I18n.t("inv.col_total")] if tab == 3 else [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("inv.col_value")], ["name", "completion", "size"] if tab == 3 else ["name", "quantity", "value"], items, func(_item): schedule_refresh())
	if not selected.is_empty():
		label(body, str(selected.get("name", "")), 20)
		if tab == 3:
			table(body, [I18n.t("inv.col_card"), I18n.t("inv.col_qty")], ["name", "quantity"], selected.get("collection", []))
		else:
			label(body, I18n.t("inv.collection") + " " + str(selected.get("cardSetName", "—")))


func _ladder() -> void:
	choices(body, [I18n.t("ladder.tab_1v1"), I18n.t("ladder.tab_boss"), I18n.t("ladder.tab_2v2"), I18n.t("ladder.tab_clans"), I18n.t("ladder.tab_tourn"), I18n.t("ladder.tab_pro"), I18n.t("ladder.tab_demon")], tab, func(i): tab = i; selected = {}; send("nativeLadderTab", [i]); schedule_refresh())
	var fields := [["position", "coachName", "totalVictories", "totalDefeats"], ["position", "creatorCoachName", "reputation", "totalVictories"], ["position", "teamName", "totalVictories", "totalDefeats"], ["position", "name", "bossName", "strength"], ["position", "name", "points"], ["position", "coachName", "guildName", "rating"], ["position", "demonName", "guildName", "quarterlyReputationPoints"]]
	var headings := [
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_player"), I18n.t("ladder.col_wins"), I18n.t("ladder.col_losses")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_boss"), I18n.t("ladder.col_rep"), I18n.t("ladder.col_wins")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_team"), I18n.t("ladder.col_wins"), I18n.t("ladder.col_losses")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_boss"), I18n.t("ladder.col_strength")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_name"), I18n.t("ladder.col_points")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_player"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_score")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_demon"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_rep")]]
	table(body, headings[tab], fields[tab], data("ladderManager." + BOARDS[tab], []))
	var footer := row(body)
	for entry in [["ladder.first", "firstPlayerLadderInformationDialog"], ["ladder.prev", "backwardTenLadderInformationDialog"], ["ladder.next", "forwardTenLadderInformationDialog"], ["ladder.me", "coachSearchLadderInformationDialog"], ["ladder.last", "lastPlayerLadderInformationDialog"]]:
		button(footer, I18n.t(entry[0]), func(): send(entry[1]))


func _calendar() -> void:
	var toolbar := row(body)
	button(toolbar, I18n.t("cal.prev"), func(): selected = {}; send("showPreviousMonth"))
	label(toolbar, str(data("calendar.currentMonth", I18n.t("panel.calendar"))), 22)
	button(toolbar, I18n.t("cal.next"), func(): selected = {}; send("showNextMonth"))
	var split := row(body)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	split.add_child(grid)
	for i in 7:
		label(grid, I18n.t("cal.d%d" % i))
	for cell in data("calendar.calendar", []):
		var events: Array = cell.get("events", [])
		var text := str(cell.get("day", ""))
		var b := button(grid, text + (" · %d" % events.size() if not events.is_empty() else ""), func(): selected = cell; schedule_refresh(), not text.is_empty())
		b.custom_minimum_size = Vector2(85, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := column(split)
	label(details, I18n.t("cal.day", {"d": str(selected.get("day", "—"))}), 22)
	var events: Array = selected.get("events", [])
	if events.is_empty():
		label(details, I18n.t("cal.empty"))
	for event in events:
		label(details, str(event.get("title", "")), 20)
		label(details, str(event.get("description", "")))
		button(details, I18n.t("cal.register"), func(): confirm_action(I18n.t("cal.register_confirm"), func(): send("registerTournament", [event], event)))


func _achievements() -> void:
	var toolbar := row(body)
	label(toolbar, I18n.t("ach.points", {"n": data("achievementManager.achievementsTotalPoints", 0)}), 22)
	var types: Array = [{"name": I18n.t("ach.all_types"), "cat": -1}] + data("achievementManager.achievementTypesList", [])
	choices(toolbar, types.map(func(t): return str(t.name)), int(draft.get("category", 0)), func(i): draft["category"] = i; selected = {}; send("selectAchievementType", [], types[i]))
	var category := int(draft.get("category", 0))
	if category > 0 and category < types.size():
		var subs: Array = [{"name": I18n.t("ach.all_subs"), "cat": types[category].cat, "sub": -1}] + types[category].get("subtypes", [])
		choices(toolbar, subs.map(func(t): return str(t.name)), int(draft.get("subcategory", 0)), func(i): draft["subcategory"] = i; send("selectAchievementSubtype", [], subs[i]))
	var items: Array = data("achievementManager.achievementsList", [])
	table(body, [I18n.t("ach.col_name"), I18n.t("ach.col_progress"), I18n.t("ach.col_points")], ["name", "completion", "points"], items, func(_item): schedule_refresh())
	if not selected.is_empty():
		label(body, str(selected.get("descriptionDone", selected.get("name", ""))))


func _social() -> void:
	tabs(body, [I18n.t("social.friends"), I18n.t("social.ignored"), I18n.t("social.clan")])
	var paths := ["friends.list", "ignore.list", "guild.members"]
	var items: Array = []
	for source in data(paths[tab], []):
		var item: Dictionary = source.duplicate()
		item["status"] = I18n.t("social.online") if item.get("connected", item.get("online", false)) else I18n.t("social.offline")
		items.append(item)
	if tab == 2:
		label(body, str(data("guild.name", I18n.t("social.no_clan"))), 22)
	table(body, [I18n.t("social.col_name")] if tab == 1 else [I18n.t("social.col_name"), I18n.t("social.col_status")], ["name"] if tab == 1 else ["name", "status"], items, func(_item): schedule_refresh())
	var toolbar := row(body)
	var edit := field(toolbar, "social_name", I18n.t("social.name_ph"))
	var add: String = ["addToFriendList", "addToIgnoreList", "inviteToGuild"][tab]
	button(toolbar, I18n.t("social.invite") if tab == 2 else I18n.t("social.add"), func():
		if not edit.text.strip_edges().is_empty():
			send(add, [edit.text.strip_edges()]))
	edit.text_submitted.connect(func(text):
		if not text.strip_edges().is_empty(): send(add, [text.strip_edges()]))
	if tab < 2:
		button(toolbar, I18n.t("social.remove_sel"), func(): send("removeFromFriendList" if tab == 0 else "removeFromIgnoreList", [selected]), not selected.is_empty())
	else:
		toolbar = row(body)
		if str(data("guild.name", "")).is_empty():
			button(toolbar, I18n.t("social.create_clan"), func(): send("nativeOpen", ["guildCreationDialog"]))
		else:
			button(toolbar, I18n.t("social.view_member"), func(): send("getMemberStats", [], selected), not selected.is_empty())
			button(toolbar, I18n.t("social.ranks"), func(): send("nativeOpen", ["guildManagementDialog"]), bool(data("guild.canManage", false)))
		button(toolbar, I18n.t("social.leave"), func(): confirm_action(I18n.t("social.leave_confirm"), func(): send("quitGuild")), not str(data("guild.name", "")).is_empty())


func _help() -> void:
	for i in 4:
		label(body, I18n.t("help.h%d" % i), 22)
		label(body, I18n.t("help.b%d" % i))


func _options() -> void:
	label(body, I18n.t("opt.language"), 22)
	var lang_bar := row(body)
	var lang_names := ["Español", "English", "Français"]
	choices(lang_bar, lang_names, maxi(0, LOCALES.find(I18n.lang)),
		func(i): I18n.set_locale(LOCALES[i]))
	label(body, I18n.t("opt.screen"), 22)
	for entry in [["opt.fullscreen", "fullScreen", "setFullScreen"], ["opt.vsync", "vsyncActivated", "activateVSync"]]:
		var check := CheckButton.new()
		check.text = I18n.t(entry[0])
		check.button_pressed = bool(data("gamePreferences." + entry[1], false))
		check.toggled.connect(func(value): model.set_value("gamePreferences", value, entry[1]); send(entry[2]))
		body.add_child(check)
	var bar := row(body)
	var sizes := _supported_resolutions()
	var current := str(data("gamePreferences.screenResolution", "1280x720"))
	choices(bar, sizes, maxi(0, sizes.find(current)), func(i): model.set_value("gamePreferences", sizes[i], "screenResolution"))
	button(bar, I18n.t("opt.apply_res"), func(): send("applyResolution"))
	label(body, I18n.t("opt.sound"), 22)
	var mute := CheckButton.new()
	mute.text = I18n.t("opt.mute")
	mute.button_pressed = bool(data("gamePreferences.musicMute", false))
	mute.toggled.connect(func(value): model.set_value("gamePreferences", value, "musicMute"); send("setMusicMute"))
	body.add_child(mute)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(data("gamePreferences.musicVolume", 0.5))
	volume.custom_minimum_size.y = 38
	volume.value_changed.connect(func(value): model.set_value("gamePreferences", value, "musicVolume"); send("setMusicVolume"))
	body.add_child(volume)
	label(body, I18n.t("opt.account"), 22)
	button(body, I18n.t("opt.destroy_coach"), func(): confirm_action(I18n.t("coach.destroy_confirm"), func(): send("destroyCoach")))


## Windowed resolutions that fit the current screen — no upscaled fake modes.
func _supported_resolutions() -> Array:
	var screen := DisplayServer.screen_get_size()
	var out: Array = []
	for r in [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
			Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		if r.x <= screen.x and r.y <= screen.y:
			out.append("%dx%d" % [r.x, r.y])
	if out.is_empty():
		out.append("1280x720")
	var native := "%dx%d" % [screen.x, screen.y]
	if native not in out:
		out.append(native)
	return out


func _fighter_creation() -> void:
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	var split := row(body)
	var form := column(split)
	label(form, I18n.t("fc.subtitle"), 22)
	var name_field := field(form, "fighter_name", I18n.t("fc.name_ph"), str(fighter.get("name", "")))
	name_field.max_length = 20
	var bar := row(form)
	choices(bar, BREEDS, int(fighter.get("breedId", 1)) - 1, func(i): send("setFighterBreedId", [i + 1]))
	choices(bar, [I18n.t("fc.sex_m"), I18n.t("fc.sex_f")], int(fighter.get("sex", 0)), func(i): send("setFighterSex", [i]))
	# the original Wakfu/Dofus pick: version 2 recruits to the evolution
	# roster, version 1 to a classic preset
	choices(bar, [I18n.t("fc.v_classic"), I18n.t("fc.v_evo")],
		clampi(int(fighter.get("version", 1)) - 1, 0, 1),
		func(i): send("setFighterVersion", [i + 1]))
	for entry in [["fc.skin", "skin", "setFighterSkinColorIndex"], ["fc.hair", "hair", "setFighterHairColorIndex"], ["fc.eyes", "eye", "setFighterEyeColorIndex"]]:
		var line := row(form)
		label(line, I18n.t(entry[0]))
		var options: Array = []
		for i in Palettes.NATURAL.size(): options.append(I18n.t("fc.color", {"n": i + 1}))
		var choice := choices(line, options, int(fighter.get(entry[1], 0)), func(i): send(entry[2], [i]))
		for i in Palettes.NATURAL.size():
			var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			var color: Vector3 = Palettes.NATURAL[i]
			image.fill(Color(color.x, color.y, color.z))
			choice.set_item_icon(i, ImageTexture.create_from_image(image))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(320, 330)
	split.add_child(stage)
	_preview = preload("res://src/anims/anm_sprite.gd").new()
	_preview.foot_pivot = true
	_preview.position = Vector2(160, 300)
	_preview.scale = Vector2(2.5, 2.5)
	stage.add_child(_preview)
	var spin := row(form)
	button(spin, "◀", func(): _preview_dir = (_preview_dir - 1) & 7; _preview_look = ""; _sync_preview())
	button(spin, "▶", func(): _preview_dir = (_preview_dir + 1) & 7; _preview_look = ""; _sync_preview())
	_preview_look = ""
	_sync_preview()
	var error := label(body, "")
	var submit := func():
		if name_field.text.strip_edges().is_empty():
			error.text = I18n.t("fc.err_name")
			return
		model.set_value("teamManagement", name_field.text.strip_edges(), "editableFighter.name")
		send("createFighter")
	button(body, I18n.t("fc.create"), submit)
	name_field.text_submitted.connect(func(_text): submit.call())


func _sync_preview() -> void:
	if not is_instance_valid(_preview):
		return
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	var lib := str(fighter.get("actorDescriptorLibrary", ""))
	if lib.is_empty():
		return
	_preview.tints = fighter.get("actorMaterial", {})
	var look := "%s/%s/%s/%s/%d" % [lib, fighter.get("skin", 0), fighter.get("hair", 0), fighter.get("eye", 0), _preview_dir]
	if look == _preview_look:
		return
	_preview_look = look
	if not Direction8.load_idle(_preview,
			"res://assets/anims/" + lib, _preview_dir):
		Direction8.load_idle_any(_preview, "res://assets/anims/" + lib)


func _team_name() -> void:
	label(body, I18n.t("tn.subtitle"), 22)
	var name_field := field(body, "team_name", I18n.t("tn.name_ph"))
	name_field.max_length = 20
	var teammate: LineEdit
	if panel_name == "team2vs2NameDialog":
		teammate = field(body, "teammate", I18n.t("tn.mate_ph"))
	var error := label(body, "")
	button(body, I18n.t("tn.create"), func():
		if name_field.text.strip_edges().is_empty():
			error.text = I18n.t("tn.err_name")
			return
		model.set_value("teamManagement", name_field.text.strip_edges(), "teamName")
		if teammate != null:
			model.set_value("teamManagement", teammate.text.strip_edges(), "teammateName")
		send("addNewTeamXvsX" if panel_name == "team2vs2NameDialog" else ("addNewTournamentTeam" if panel_name == "newTeamTournamentDialog" else "addNewTeam")))


func _equipment() -> void:
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	label(body, str(fighter.get("name", "")), 23)
	tabs(body, [I18n.t("fe.spells"), I18n.t("fe.equip")])
	if tab == 0:
		var spells: Array = data("teamManagement.editableFighter.breedSpells", [])
		var rows: Array = []
		for spell in spells:
			var item: Dictionary = spell.duplicate()
			item["status"] = I18n.t("fe.equipped") if item.get("equipped", false) else I18n.t("fe.available")
			rows.append(item)
		table(body, [I18n.t("fe.col_spell"), I18n.t("fe.col_ap"), I18n.t("fe.col_range"), I18n.t("fe.col_status")], ["name", "actionPoints", "range", "status"], rows, func(_item): schedule_refresh())
		button(body, I18n.t("fe.remove_spell") if selected.get("equipped", false) else I18n.t("fe.equip_spell"), func(): send("removeSpell" if selected.get("equipped", false) else "addSpell", [], selected), not selected.is_empty())
		label(body, I18n.t("fe.spell_hint"))
	else:
		var slots := [I18n.t("fe.slot_weapon"), I18n.t("fe.slot_pet"), I18n.t("fe.slot_cloak"), I18n.t("fe.slot_hat"), I18n.t("fe.slot_dofus")]
		var slot := int(data("teamManagement.selectedItemCardListType", 0))
		choices(body, slots, slot, func(i): selected = {}; send("changeItemCardType", [i]))
		var equipped: Dictionary = data("teamManagement.editableFighter." + EQ_FIELDS[slot], {})
		label(body, I18n.t("fe.equipped_x", {"name": str(equipped.get("name", I18n.t("fe.none")))}))
		button(body, I18n.t("fe.unequip"), func(): send("removeEquipment", [slot]), not equipped.is_empty())
		table(body, [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("inv.col_value")], ["name", "quantity", "value"], data("teamManagement.selectedItemCardList", []), func(_item): schedule_refresh())
		var nav := row(body)
		button(nav, I18n.t("ladder.prev"), func(): send("decreaseList"))
		button(nav, I18n.t("ladder.next"), func(): send("increaseList"))
		button(nav, I18n.t("fe.equip_card"), func(): send("addEquipment", [], selected), not selected.is_empty())
	button(body, I18n.t("fe.save"), func(): send("saveEditableFighter"))


func _guild_creation() -> void:
	label(body, I18n.t("gc.subtitle"), 22)
	var edit := field(body, "guild_name", I18n.t("gc.name_ph"))
	var error := label(body, "")
	button(body, I18n.t("gc.create"), func():
		if edit.text.strip_edges().length() < 5:
			error.text = I18n.t("gc.err_name")
			return
		model.set_value("guildCreationName", edit.text.strip_edges())
		send("createGuild"))


func _guild_management() -> void:
	var ranks: Array = data("guild.editableRanks", [])
	table(body, [I18n.t("gm.col_rank"), I18n.t("gm.col_level")], ["name", "rankLevel"], ranks, func(item):
		for key in ["rank_name", "canInvite", "canRemove", "canPromote", "canDepromote"]:
			draft.erase(key)
		send("selectRank", [], item))
	var rank: Dictionary = data("guildSelectedRank", {})
	var edit := field(body, "rank_name", I18n.t("gm.name_ph"), str(rank.get("name", "")))
	var rights := row(body)
	for entry in [["gm.can_invite", "canInvite"], ["gm.can_remove", "canRemove"], ["gm.can_promote", "canPromote"], ["gm.can_demote", "canDepromote"]]:
		var check := CheckBox.new()
		check.text = I18n.t(entry[0])
		check.button_pressed = bool(rank.get(entry[1], false))
		check.toggled.connect(func(value):
			# Draft stays local until Add/Save so typing is not rebuilt.
			draft[entry[1]] = value)
		rights.add_child(check)
	var save := func(event):
		var value: Dictionary = rank.duplicate()
		value["name"] = edit.text.strip_edges()
		for key in ["canInvite", "canRemove", "canPromote", "canDepromote"]:
			value[key] = draft.get(key, rank.get(key, false))
		model.set_value("guildSelectedRank", value)
		send(event)
	var actions := row(body)
	button(actions, I18n.t("gm.add"), func(): save.call("addRankToGuild"))
	button(actions, I18n.t("gm.save"), func(): save.call("modifyRank"), not rank.is_empty())
	button(actions, I18n.t("gm.delete"), func(): confirm_action(I18n.t("gm.delete_confirm"), func(): send("removeRankToGuild")), not rank.is_empty())


func _guild_member() -> void:
	var member: Dictionary = data("guildCoachStats", {})
	label(body, str(member.get("name", "")), 24)
	var rows: Array = []
	for entry in [["stats.fights", "statisticsTotalFights"], ["stats.wins", "statisticsTotalFightsWon"], ["stats.losses", "statisticsTotalFightsLost"], ["stats.streak", "statisticsConsecutiveWins"]]:
		rows.append({"name": I18n.t(entry[0]), "value": member.get(entry[1], 0)})
	table(body, [I18n.t("stats.col_name"), I18n.t("stats.col_value")], ["name", "value"], rows)
	var actions := row(body)
	button(actions, I18n.t("gmb.promote"), func(): send("promote"), bool(data("guildCanPromote", false)))
	button(actions, I18n.t("gmb.demote"), func(): send("depromote"), bool(data("guildCanDepromote", false)))
	button(actions, I18n.t("gmb.kick"), func(): confirm_action(I18n.t("gmb.kick_confirm"), func(): send("removeGuildMember")), bool(data("guildExcluder", false)))
