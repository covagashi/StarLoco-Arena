extends "res://src/ui/card_panel.gd"   # lobby_panel + the card tile helpers

const Direction8 := preload("res://src/util/direction8.gd")
const ArtStyle := preload("res://src/util/art_style.gd")
const TournamentDefs := preload("res://src/gamedata/tournament_defs.gd")
const State := preload("res://src/state.gd")
const Scenarios := preload("res://src/gamedata/scenarios.gd")
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const ReplayFile := preload("res://src/net/replay_file.gd")
const GambitEditor := preload("res://src/ui/gambit_editor.gd")
const Features := preload("res://src/features.gd")
const Story := preload("res://src/gamedata/story.gd")
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
	"cityDialog": "panel.city",
	"replayDialog": "panel.replays",
	"ghostDialog": "panel.ghosts",
	"storyDialog": "panel.story",
}
var _preview
var _preview_look := ""
var _preview_dir := Direction8.FRONT

const FORMS := ["fighterCreationDialog", "teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog", "optionsDialog"]
const BOARDS := ["list1vs1", "listReputation", "list2vs2", "listGuild", "listTournamentInTheMonth", "listGlickoRating", "listDemon"]
const EQ_FIELDS := ["weaponEquipment", "petEquipment", "cloakEquipment", "hatEquipment", "dofusEquipment"]
const LOCALES := ["es", "en", "fr"]


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if panel_name in FORMS:
		if panel_name == "fighterCreationDialog" and model_name == "teamManagement":
			_sync_preview()
		return
	var watched := {
		"teamManagementDialog": ["teamManagement", "evolutionTeam", "tournamentSearch"],
		"evolutionDialog": ["teamManagement", "evolutionTeam", "tournamentSearch"],
		"fighterEquipmentDialog": ["teamManagement"],
		"coachStatisticsDialog": ["localCoach"], "cardBookDialog": ["localCoach", "tomeManager"],
		"ladderInformationDialog": ["ladderManager"], "calendarDialog": ["calendar"],
		"achievementDialog": ["achievementManager"], "socialDialog": ["friends", "ignore", "guild"],
		"guildDialog": ["friends", "ignore", "guild"],
		"guildManagementDialog": ["guild", "guildSelectedRank"],
		"guildCoachStatsDialog": ["guildCoachStats"],
		"cityDialog": ["city"],
		"ghostDialog": ["ghosts"],
		"storyDialog": ["story", "evolutionTeam", "teamManagement"],
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
		"cityDialog": _city()
		"replayDialog": _replays()
		"ghostDialog": _ghosts()
		"storyDialog": _story()


## Historia (S21): the campaign's chapters and their challenges, what is at
## stake in each, and Jugar. Reads `story` {won:[ids], titulars}; answers
## nativeStoryPlay [id] and nativeOpen ["teamManagementDialog"].
func _story() -> void:
	var st: Dictionary = data("story", {})
	var won: Array = st.get("won", [])
	var titulars := int(st.get("titulars", 0))
	if not draft.has("pick"):
		draft["pick"] = Story.next_challenge(won)
	var pick := int(draft.get("pick", -1))
	label(body, I18n.t("story.intro"), 17)
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := column(split)
	for i in Story.CHAPTERS.size():
		var ch: Dictionary = Story.CHAPTERS[i]
		var head := label(left, "%s  ·  %d/%d" % [I18n.t(str(ch.key)), Story.chapter_done(i, won),
			ch.challenges.size()], 20)
		head.add_theme_color_override("font_color", UiStyle.GOLD)
		for c in ch.challenges:
			var id := int(c)
			var state := Story.status(id, won)
			var mark: String = {"won": "✓", "next": "▶", "locked": "·"}[state]
			var b := button(left, "%s  %s" % [mark, NpcDialogs.challenge_name(id)], func():
				draft["pick"] = id
				schedule_refresh(), state != "locked")
			b.name = "Story%d" % id
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.button_pressed = id == pick
			if state == "locked":
				b.tooltip_text = I18n.t("story.locked_tip")
	var detail := column(split, false)
	detail.custom_minimum_size.x = 380
	if pick < 0:
		label(detail, I18n.t("story.all_done"), 20)
		return
	var state := Story.status(pick, won)
	label(detail, NpcDialogs.challenge_name(pick), 23).name = "StoryPick"
	var stake := label(detail, I18n.t("story.stake_first") if state != "won" else I18n.t("story.stake_replay"))
	stake.name = "Stake"
	if state != "won":
		stake.add_theme_color_override("font_color", UiStyle.GOLD)
	label(detail, I18n.t("story.team", {"n": titulars}) if titulars > 0 else I18n.t("story.no_team"))
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	button(pinned_actions, I18n.t("story.team_btn"), func(): send("nativeOpen", ["teamManagementDialog"]))
	var play := button(pinned_actions, I18n.t("story.replay") if state == "won" else I18n.t("hub.play"),
		func(): send("nativeStoryPlay", [pick]), titulars > 0 and state != "locked")
	play.name = "StoryPlay"
	play.custom_minimum_size.x = 190
	UiStyle.primary(play, 20)


func _menu() -> void:
	label(body, I18n.t("menu.subtitle"), 22)
	var actions := column(body)
	for entry in [["menu.options", "optionsDialog"], ["menu.help", "tooltipDialog"], ["menu.team", "teamManagementDialog"], ["menu.replays", "replayDialog"], ["menu.ghosts", "ghostDialog"]]:
		button(actions, I18n.t(entry[0]), func():
			closed.emit()
			send("nativeOpen", [entry[1]]))
	button(actions, I18n.t("menu.bug_report"), func(): send("openBugReport"))
	button(actions, I18n.t("menu.disconnect"), func(): confirm_action(I18n.t("menu.disconnect_confirm"), func(): send("nativeDisconnect")))
	button(actions, I18n.t("menu.quit"), func(): confirm_action(I18n.t("menu.quit_confirm"), func(): send("quit")))


func _team() -> void:
	var modes: Array = Features.team_modes()
	tab = clampi(int(data("gamePreferences.lastSelectedGameModeId", tab)), 0, 4)
	if not tab in modes:
		tab = int(modes[0])   # a saved tab the owner has since hidden
	var mode_names := [I18n.t("team.tab_evolution"), I18n.t("team.tab_elite"),
		I18n.t("team.tab_duo"), I18n.t("team.tab_tournaments"),
		I18n.t("team.tab_legends")]
	tabs(body, modes.map(func(m): return mode_names[m]),
		func(i): send("changeTeamTab", [], null, i), modes)
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
	var tourn := _tournament_picker() if tab in [3, 4] else -1
	var fighters: Array = data("teamManagement.editableTeamPreset.fighters", [])
	if tab == 0:
		fighters = fighters + data("evolutionTeam.fightersOnBench", [])
	elif tab == 4:
		fighters = data("teamManagement.editableTeamPreset.legendaryFighters", []) + data("evolutionTeam.legendaryFightersOnBench", [])
	var rows: Array = []
	for fighter in fighters:
		if not fighter is Dictionary:
			continue
		# the fallen get their own section below (S18: no graveyard place)
		if tab == 0 and int(fighter.get("state", 0)) in [2, 3]:
			continue
		var item: Dictionary = fighter.duplicate()
		item["breed_name"] = I18n.t("breed.%d" % clampi(int(item.get("breedId", 1)), 1, 12))
		item["placement"] = (I18n.t("team.in_team") if item.get("teamMember", false) else I18n.t("team.reserve")) if classic else (I18n.t("team.bench") if int(item.get("state", 0)) in [1, 5] else I18n.t("team.starter"))
		rows.append(item)
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster := column(split)
	label(roster, I18n.t("team.count", {"n": rows.size()}), 20)
	var living := table(roster, [I18n.t("team.col_name"), I18n.t("team.col_class"), I18n.t("team.col_pos")], ["name", "breed_name", "placement"], rows, func(_item): schedule_refresh())
	if tab == 0 and _fallen_section(roster):
		living.custom_minimum_size.y = 76   # the fallen table sits below it
	var detail := column(split, false)
	detail.custom_minimum_size.x = 320
	if selected.is_empty():
		label(detail, I18n.t("team.select_hint"))
		label(detail, I18n.t("team.empty_hint"))
	elif not classic and int(selected.get("state", 0)) in [2, 3]:
		_fallen_detail(detail)
	else:
		label(detail, str(selected.get("name", "")), 23)
		label(detail, "%s · %s" % [selected.get("breed_name", ""), selected.get("placement", "")])
		button(detail, I18n.t("team.equip_spells"), func(): send("editFighter", [selected], selected))
		if classic:
			button(detail, I18n.t("team.remove_member") if selected.get("teamMember", false) else I18n.t("team.add_member"), func(): send("addRemoveFighterFromEditableTeamPreset", [], selected), int(draft.get("preset_id", -1)) > 0)
		else:
			button(detail, I18n.t("team.toggle_status"), func(): send("changeFighterStatus", [], selected), int(selected.get("state", 0)) != 3)
		if not classic:
			# one row: the column must fit 720p without scrolling
			var evo_row := row(detail)
			var sph := button(evo_row, I18n.t("team.spheres"), func(): send("nativeKanodo", [int(selected.get("id", -1))]))
			sph.name = "Spheres"
			sph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if Features.LEGENDS:
				var leg := button(evo_row, I18n.t("team.make_legend"), func(): confirm_action(I18n.t("team.make_legend_confirm"), func(): send("becomeALegend", [selected], selected)))
				leg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button(detail, I18n.t("team.delete_fighter"), func(): confirm_action(I18n.t("team.delete_fighter_confirm", {"name": selected.get("name", "")}), func(): send("deleteFighter", [selected], selected)))
	pinned_actions.show()
	var footer := pinned_actions
	var hint := label(footer, I18n.t("team.synced"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_revive_status_line(hint)
	button(footer, I18n.t("team.practice"), func(): send("launchTeamTest"))
	if tab in [3, 4]:
		# S09: the search of the tournament picked above (28611 with the
		# preset its kind sends); the lobby bar shows it and cancels it
		var fb := button(footer, I18n.t("team.find_tourn"), func(): send("nativeTournSearch", [tourn]), tourn >= 0)
		fb.name = "FindTournament"
	elif tab == 0:
		# Historia (S21): the campaign, not the evolution PvP queue
		if Features.EVO_PVP:
			button(footer, I18n.t("team.find_fight"), func(): send("launchEvolutionFight"), true)
		else:
			button(footer, I18n.t("story.open"), func(): send("nativeStory")).name = "OpenStory"
	else:
		button(footer, I18n.t("team.find_fight"), func(): send("setClassicReadyForFight"), true)


## The Tournaments / Legends tabs' tournament: the editions we are entered in
## that are searched from this tab, the open ones first. Returns the picked
## tournament id while its search period is open, else -1. Retail selected it
## by clicking the alert row (agz_1 → vk_1.ad); the native panel lists them.
func _tournament_picker() -> int:
	var rows: Array = []
	for r in data("tournamentSearch.rows", []):
		if int(r.get("tab", 3)) == tab or (tab == 3 and int(r.get("tab", 3)) == 0):
			rows.append(r)
	var bar := row(body)
	var head := label(bar, I18n.t("team.tournament"), 20)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if rows.is_empty():
		label(bar, I18n.t("team.no_tournament")).name = "NoTournament"
		return -1
	rows.sort_custom(func(a, b): return bool(a.open) and not bool(b.open))
	var names: Array = []
	var picked := 0
	for i in rows.size():
		var r: Dictionary = rows[i]
		names.append("%s · %s" % [r.name, I18n.t("team.search_open") if bool(r.open) else I18n.t("team.search_shut")])
		if int(r.id) == int(draft.get("tournament", -1)):
			picked = i
	var pick := choices(bar, names, picked, func(i):
		draft["tournament"] = int(rows[i].id)
		schedule_refresh())
	pick.name = "TournamentPick"
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var r0: Dictionary = rows[picked]
	draft["tournament"] = int(r0.id)
	if int(r0.get("kind", 1)) != TournamentDefs.CLASSIC and tab == 3:
		# evolution and graveyard tournaments field the titular line-up
		label(body, I18n.t("team.tourn_titulars"))
	return int(r0.id) if bool(r0.open) else -1


## The fallen fighters (dead: still holding a titular slot; retired: out of
## the team), listed under the living ones. Pick one to resurrect it.
func _fallen_section(parent: Node) -> bool:
	var fallen: Array = data("evolutionTeam.fallen", [])
	if fallen.is_empty():
		return false
	var rows: Array = []
	for fighter in fallen:
		var item: Dictionary = fighter.duplicate()
		item["breed_name"] = I18n.t("breed.%d" % clampi(int(item.get("breedId", 1)), 1, 12))
		item["placement"] = I18n.t("team.state_dead" if int(item.get("state", 0)) == 2 else "team.state_retired")
		rows.append(item)
	label(parent, I18n.t("team.fallen", {"n": rows.size()}), 20)
	var fallen_table := table(parent, [I18n.t("team.col_name"), I18n.t("team.col_class"), I18n.t("team.col_pos")], ["name", "breed_name", "placement"], rows, func(_item): schedule_refresh())
	fallen_table.name = "Fallen"
	# header + up to two rows; the living table takes the rest
	fallen_table.custom_minimum_size.y = 34 + 38 * mini(rows.size(), 2)
	fallen_table.size_flags_vertical = Control.SIZE_FILL
	return true


func _fallen_detail(detail: Node) -> void:
	var state := int(selected.get("state", 0))
	label(detail, str(selected.get("name", "")), 23)
	label(detail, "%s · %s" % [selected.get("breed_name", ""), I18n.t("team.state_dead" if state == 2 else "team.state_retired")])
	var hint := label(detail, I18n.t("team.dead_hint" if state == 2 else "team.retired_hint"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cards: Array = data("evolutionTeam.reviveCards", [])
	if cards.is_empty():
		label(detail, I18n.t("team.no_revive"))
	else:
		var pick := clampi(int(draft.get("revive_card", 0)), 0, cards.size() - 1)
		if cards.size() > 1:
			var names: Array = []
			for c in cards:
				names.append(I18n.t("team.revive_card", {"name": c.name, "qty": c.qty, "pct": c.pct}))
			choices(detail, names, pick, func(i): draft["revive_card"] = i; schedule_refresh())
		var bench_full: bool = state == 3 and bool(data("evolutionTeam.benchFull", false))
		var fid := int(selected.get("id", -1))
		var revive := button(detail, I18n.t("team.revive", {"pct": cards[pick].pct, "qty": cards[pick].qty}), func():
			var c: Dictionary = cards[clampi(int(draft.get("revive_card", 0)), 0, cards.size() - 1)]
			send("nativeRevive", [fid, int(c.id)]), not bench_full)
		revive.name = "Revive"
		if bench_full:
			label(detail, I18n.t("team.revive_bench_full")).name = "BenchFull"
	if state == 2:
		button(detail, I18n.t("team.retire"), func(): send("changeFighterStatus", [], selected)).name = "Retire"
	button(detail, I18n.t("team.delete_fighter"), func(): confirm_action(I18n.t("team.delete_fighter_confirm", {"name": selected.get("name", "")}), func(): send("deleteFighter", [selected], selected)))


## The last resurrection's outcome takes the footer's hint line while its
## fighter is selected (it follows the fighter from the Fallen table to the
## living one). In the footer, not the detail column, so nothing scrolls.
func _revive_status_line(hint: Label) -> void:
	var status: Dictionary = data("evolutionTeam.reviveStatus", {})
	if status.is_empty() or int(status.get("fid", -1)) != int(selected.get("id", -2)):
		return
	hint.text = str(status.get("text", ""))
	hint.name = "ReviveStatus"
	if not bool(status.get("ok", true)):
		hint.add_theme_color_override("font_color", UiStyle.MUTED)


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


## Inventario (S22): "está bien pero es denso". Two tabs (cards, sets); the
## cards filtered by what they are FOR (coach gear, consumables, cosmetics,
## combat rules, fusion, DOFUS items), sorted by name / value / quantity, a
## search that filters as you type, and a detail that says what the card is
## and where it is used.
const INV_KINDS := {
	"coach": [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
	"consumable": [24], "cosmetic": [1, 25, 28, 29], "combat": [26],
	"fusion": [27], "dofus": [30],
}


static func _inv_kind(card_type: int) -> String:
	for k in INV_KINDS:
		if card_type in INV_KINDS[k]:
			return k
	return "other"


func _inventory() -> void:
	tabs(body, [I18n.t("inv.cards"), I18n.t("inv.sets")])
	var toolbar := row(body)
	var search := field(toolbar, "search", I18n.t("inv.search_ph"))
	search.text_changed.connect(func(_t): schedule_refresh())
	button(toolbar, I18n.t("inv.coach_equip"), func(): send("nativeEquipOpen")).name = "CoachEquip"
	var needle := str(draft.get("search", "")).strip_edges().to_lower()
	if tab == 1:
		var sets: Array = data("localCoach.cardSets", [])
		if needle != "":
			sets = sets.filter(func(item): return str(item.get("name", "")).to_lower().contains(needle))
		table(body, [I18n.t("inv.col_set"), I18n.t("inv.col_owned"), I18n.t("inv.col_total")], ["name", "completion", "size"], sets, func(_item): schedule_refresh())
		if not selected.is_empty():
			label(body, str(selected.get("name", "")), 20)
			table(body, [I18n.t("inv.col_card"), I18n.t("inv.col_qty")], ["name", "quantity"], selected.get("collection", []))
		return
	var items: Array = data("localCoach.cardInventory", [])
	var kinds: Array = ["all"] + INV_KINDS.keys() + ["other"]
	var kind_pick := clampi(int(draft.get("kind", 0)), 0, kinds.size() - 1)
	var filters := row(body)
	choices(filters, kinds.map(func(k): return I18n.t("inv.kind_%s" % k)), kind_pick,
		func(i): draft["kind"] = i; selected = {}; schedule_refresh()).name = "KindPick"
	var sorts := ["name", "value", "qty"]
	var sort_pick := clampi(int(draft.get("sort", 0)), 0, sorts.size() - 1)
	choices(filters, sorts.map(func(k): return I18n.t("inv.sort_%s" % k)), sort_pick,
		func(i): draft["sort"] = i; schedule_refresh()).name = "SortPick"
	if kind_pick > 0:
		items = items.filter(func(it): return _inv_kind(int(it.get("cardType", 0))) == kinds[kind_pick])
	if needle != "":
		items = items.filter(func(item): return str(item.get("name", "")).to_lower().contains(needle))
	match sorts[sort_pick]:
		"name": items.sort_custom(func(a, b): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
		"value": items.sort_custom(func(a, b): return int(a.get("value", 0)) > int(b.get("value", 0)))
		"qty": items.sort_custom(func(a, b): return int(a.get("quantity", 0)) > int(b.get("quantity", 0)))
	_muted(filters, I18n.t("inv.count", {"n": items.size()})).name = "InvCount"
	# the cards themselves: tiles with their art, the picked one large
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := HFlowContainer.new()
	grid.name = "CardGrid"
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(grid)
	if items.is_empty():
		_muted(grid, I18n.t("common.empty"))
	var pick := int(selected.get("id", -1))
	for item in items:
		var t := _tile(grid, item, int(item.get("id", -2)) == pick, "×%d" % int(item.get("quantity", 0)),
			I18n.t("inv.value_n", {"n": int(item.get("value", 0))}))
		t.name = "Card%d" % int(item.get("id", 0))
		t.pressed.connect(func():
			selected = item
			schedule_refresh())
	var detail := column(split, false)
	detail.custom_minimum_size.x = 300
	if selected.is_empty() or not items.any(func(i): return int(i.get("id", -2)) == pick):
		_muted(detail, I18n.t("inv.pick_hint"))
		return
	detail.add_child(_framed_art(pick, Vector2(260, 200)))
	label(detail, str(selected.get("name", "")), 20).name = "CardName"
	var kind := _inv_kind(int(selected.get("cardType", 0)))
	var what := label(detail, I18n.t("inv.kind_%s" % kind), 16)
	what.add_theme_color_override("font_color", UiStyle.GOLD)
	var use := label(detail, I18n.t("inv.use_%s" % kind))
	use.name = "CardUse"
	use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(detail, I18n.t("inv.collection", {"name": str(selected.get("cardSetName", "—"))}))
	label(detail, "%s ×%d · %s" % [I18n.t("inv.col_qty"), int(selected.get("quantity", 0)),
		I18n.t("inv.value_n", {"n": int(selected.get("value", 0))})])


## S25: "Temporada N · termina en D días · el top 50 gana pesetas".
func _season_line() -> void:
	var s: Dictionary = data("season", {})
	if int(s.get("number", 0)) <= 0:
		return
	var days := maxi(0, ceili((int(s.get("ends", 0)) - Time.get_unix_time_from_system()) / 86400.0))
	label(body, I18n.t("season.line", {"n": int(s.number), "days": days})).name = "Season"


func _ladder() -> void:
	# tabs as buttons, your row marked, "Mi puesto" first among the pager
	# (the S18 sketch, tools/mock_screens.py ranking)
	if tab == 0:
		_season_line()
	tabs(body, [I18n.t("ladder.tab_1v1"), I18n.t("ladder.tab_boss"), I18n.t("ladder.tab_2v2"), I18n.t("ladder.tab_clans"), I18n.t("ladder.tab_tourn"), I18n.t("ladder.tab_pro"), I18n.t("ladder.tab_demon")], func(i): send("nativeLadderTab", [i]))
	var fields := [["position", "coachName", "totalVictories", "totalDefeats"], ["position", "creatorCoachName", "reputation", "totalVictories"], ["position", "teamName", "totalVictories", "totalDefeats"], ["position", "name", "bossName", "strength"], ["position", "name", "points"], ["position", "coachName", "guildName", "rating"], ["position", "demonName", "guildName", "quarterlyReputationPoints"]]
	var headings := [
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_player"), I18n.t("ladder.col_wins"), I18n.t("ladder.col_losses")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_boss"), I18n.t("ladder.col_rep"), I18n.t("ladder.col_wins")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_team"), I18n.t("ladder.col_wins"), I18n.t("ladder.col_losses")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_boss"), I18n.t("ladder.col_strength")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_name"), I18n.t("ladder.col_points")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_player"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_score")],
		[I18n.t("ladder.col_rank"), I18n.t("ladder.col_demon"), I18n.t("ladder.col_clan"), I18n.t("ladder.col_rep")]]
	var board := table(body, headings[tab], fields[tab], data("ladderManager." + BOARDS[tab], []))
	board.name = "Board"
	var mine := [str(data("localCoach.name", "")), str(data("guild.name", ""))]
	for it in board.get_root().get_children():
		var m: Variant = it.get_metadata(0)
		if not m is Dictionary:
			continue
		for f in fields[tab].slice(1):
			var v := str(m.get(f, ""))
			if v != "" and v in mine:
				it.set_text(0, "▶ " + it.get_text(0))
				it.select(0)   # inverted, like a picked row
				break
	var footer := row(body)
	for entry in [["ladder.first", "firstPlayerLadderInformationDialog"], ["ladder.prev", "backwardTenLadderInformationDialog"], ["ladder.me", "coachSearchLadderInformationDialog"], ["ladder.next", "forwardTenLadderInformationDialog"], ["ladder.last", "lastPlayerLadderInformationDialog"]]:
		var b := button(footer, I18n.t(entry[0]), func(): send(entry[1]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if entry[0] == "ladder.me":
			UiStyle.primary(b, 18)


func _calendar() -> void:
	var toolbar := row(body)
	button(toolbar, I18n.t("cal.prev"), func(): selected = {}; send("showPreviousMonth"))
	label(toolbar, str(data("calendar.currentMonth", I18n.t("panel.calendar"))), 22)
	button(toolbar, I18n.t("cal.next"), func(): selected = {}; send("showNextMonth"))
	# S09: a player tournament, for the "Création de Tournoi" card (807)
	var cards := int(data("calendar.creationCards", 0))
	var create := button(toolbar, I18n.t("cal.create", {"n": cards}), func():
		draft["creating"] = not bool(draft.get("creating", false))
		schedule_refresh(), cards > 0)
	create.name = "CreateTournament"
	create.tooltip_text = I18n.t("cal.create_hint")
	if bool(draft.get("creating", false)):
		_tournament_form()
		return
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
	# the picked day, re-read from the fresh model (registration, search and
	# bracket state change under it)
	for cell in data("calendar.calendar", []):
		if not selected.is_empty() and str(cell.get("day", "")) == str(selected.get("day", "")):
			selected = cell
	label(details, I18n.t("cal.day", {"d": str(selected.get("day", "—"))}), 22)
	var events: Array = selected.get("events", [])
	if events.is_empty():
		label(details, I18n.t("cal.empty"))
	var status: Dictionary = data("calendar.status", {})
	var bracket: Dictionary = data("calendar.bracket", {})
	for event in events:
		_tournament_event(details, event, status, bracket)


## One tournament on the day's detail: the tournament totem's actions (S18)
## and what retail's calendarTournamentDetailsDialog told (S09).
func _tournament_event(parent: Node, event: Dictionary, status: Dictionary, bracket: Dictionary) -> void:
	var tid := int(event.get("id", -1))
	label(parent, str(event.get("title", "")), 20)
	label(parent, str(event.get("description", "")))
	var facts: Array = [I18n.t("cal.kind_%d" % clampi(int(event.get("kind", 1)), 1, 4))]
	if int(event.get("rules", 0)) > 0:
		facts.append(I18n.t("cal.rules", {"n": int(event.rules)}))
	if str(event.get("organizer", "")) != "":
		facts.append(I18n.t("cal.organizer", {"name": event.organizer}))
	parent.add_child(UiStyle.caption(" · ".join(facts)))
	var periods: Array = event.get("periods", [])
	if not periods.is_empty():
		label(parent, I18n.t("cal.periods", {"list": ", ".join(periods)})).name = "Periods%d" % tid
	if str(event.get("regUntil", "")) != "":
		label(parent, I18n.t("cal.reg_until", {"at": event.regUntil}))
	if str(event.get("entryName", "")) != "":
		label(parent, I18n.t("cal.entry", {"card": event.entryName, "n": int(event.get("entryOwned", 0))})).name = "Entry%d" % tid
	if str(event.get("rewardName", "")) != "":
		label(parent, I18n.t("cal.reward", {"card": event.rewardName}))
	var registered := bool(event.get("registered", false))
	var state := I18n.t("cal.registered") if registered else (
		I18n.t("cal.reg_open") if bool(event.get("regOpen", true)) else I18n.t("cal.reg_closed"))
	if bool(event.get("searching", false)):
		state = I18n.t("cal.searching")
	parent.add_child(UiStyle.caption(state))
	var bar := row(parent)
	if not registered:
		var ticketed := int(event.get("entryCard", 0)) != 0
		var ask := I18n.t("cal.register_ticket", {"card": event.get("entryName", "")}) if ticketed \
			else I18n.t("cal.register_confirm")
		button(bar, I18n.t("cal.register"), func(): confirm_action(ask, func(): send("registerTournament", [event], event)),
			bool(event.get("regOpen", true)) and (not ticketed or int(event.get("entryOwned", 0)) > 0)).name = "Register%d" % tid
	else:
		button(bar, I18n.t("cal.bracket"), func(): send("nativeTournTree", [tid])).name = "Bracket%d" % tid
		var searching := bool(event.get("searching", false))
		if searching or bool(event.get("searchOpen", false)):
			button(bar, I18n.t("cal.search_cancel") if searching else I18n.t("cal.search"),
				func(): send("nativeTournSearch", [tid])).name = "Search%d" % tid
		else:
			label(bar, I18n.t("cal.search_closed"))
	if int(status.get("tid", -2)) == tid:
		var line := label(parent, str(status.get("text", "")))
		line.name = "TournStatus%d" % tid
		if not bool(status.get("ok", true)):
			line.add_theme_color_override("font_color", UiStyle.MUTED)
	if int(bracket.get("tid", -2)) == tid:
		var slots: Dictionary = bracket.get("slots", {})
		if slots.is_empty():
			label(parent, I18n.t("cal.bracket_empty")).name = "BracketEmpty%d" % tid
		else:
			_bracket(parent, slots).name = "Draw%d" % tid


## The draw by rounds, as retail's tournamentTreeDialog (the heap slices of
## ah_1): first round 16-31, quarters 8-15, semis 4-7, final 2-3, winner 1.
## Only the rounds anyone has reached are drawn; our own name is marked.
func _bracket(parent: Node, slots: Dictionary) -> Control:
	var me := State.my_coach_name
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	parent.add_child(box)
	var rounds := [["cal.round_first", 16, 31], ["cal.round_quarter", 8, 15],
		["cal.round_semi", 4, 7], ["cal.round_final", 2, 3], ["cal.round_winner", 1, 1]]
	for r in rounds:
		var names: Array = []
		for sl in range(int(r[1]), int(r[2]) + 1):
			if slots.has(sl):
				names.append(slots[sl])
		if names.is_empty() and int(r[1]) != 16:
			continue
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(col)
		col.add_child(UiStyle.caption(I18n.t(r[0])))
		for n in names:
			var l := label(col, ("▶ %s" % n) if n == me else str(n))
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.clip_text = true
	return box


## The player tournament form (S09, retail's tournamentCreationDialog): name,
## description, the day of the calendar on show, an hour, how long each search
## period lasts and on how many days in a row. Costs one "Création de Tournoi".
func _tournament_form() -> void:
	label(body, I18n.t("cal.create_title"), 22)
	label(body, I18n.t("cal.create_hint"))
	var form := column(body, false)
	field(form, "t_name", I18n.t("cal.create_name")).max_length = 60
	field(form, "t_desc", I18n.t("cal.create_desc")).max_length = 200
	var year := int(data("calendar.year", 2026))
	var month := int(data("calendar.month", 1))
	var days: Array = []
	for cell in data("calendar.calendar", []):
		if str(cell.get("day", "")) != "":
			days.append(str(cell.day))
	var line := row(form)
	label(line, I18n.t("cal.create_day"))
	var day_pick := choices(line, days, days.find(str(draft.get("t_day", selected.get("day", "1")))), func(i): draft["t_day"] = days[i])
	day_pick.name = "CreateDay"
	if day_pick.selected < 0:
		day_pick.select(0)
		draft["t_day"] = days[0] if not days.is_empty() else "1"
	var hours: Array = []
	for h in 24:
		hours.append("%02d:00" % h)
	label(line, I18n.t("cal.create_hour"))
	choices(line, hours, int(draft.get("t_hour", 20)), func(i): draft["t_hour"] = i)
	var line2 := row(form)
	var lengths := [30, 60, 120, 240]
	label(line2, I18n.t("cal.create_length"))
	choices(line2, lengths.map(func(m): return I18n.t("cal.minutes", {"n": m})),
		lengths.find(int(draft.get("t_len", 60))), func(i): draft["t_len"] = lengths[i])
	label(line2, I18n.t("cal.create_periods"))
	choices(line2, ["1", "2", "3", "4"], int(draft.get("t_periods", 1)) - 1, func(i): draft["t_periods"] = i + 1)
	var actions := row(form)
	button(actions, I18n.t("cal.create_send"), func():
		var name := str(draft.get("t_name", "")).strip_edges()
		if name.is_empty():
			return
		confirm_action(I18n.t("cal.create_confirm"), func():
			send("nativeTournCreate", [{"name": name,
				"desc": str(draft.get("t_desc", "")).strip_edges(),
				"year": year, "month": month, "day": int(draft.get("t_day", "1")),
				"hour": int(draft.get("t_hour", 20)), "minutes": int(draft.get("t_len", 60)),
				"periods": int(draft.get("t_periods", 1))}])
			draft["creating"] = false
			schedule_refresh())).name = "CreateSend"
	button(actions, I18n.t("common.cancel"), func():
		draft["creating"] = false
		schedule_refresh())


## Logros (S22): tiles with retail's icons (the grade by points, dimmed
## until done), a progress bar each, Pendientes / Hechos / Todos, and the
## selected one's detail: what it asks and how far you are.
static var _icon_cache := {}


func _ach_icon(path: String) -> Texture2D:
	if not _icon_cache.has(path):
		var img: Image = AssetPaths.load_image(path) if path != "" else null
		_icon_cache[path] = ImageTexture.create_from_image(img) if img != null else null
	return _icon_cache[path]


func _achievements() -> void:
	var toolbar := row(body)
	label(toolbar, I18n.t("ach.points", {"n": data("achievementManager.achievementsTotalPoints", 0)}), 22)
	var types: Array = [{"name": I18n.t("ach.all_types"), "cat": -1}] + data("achievementManager.achievementTypesList", [])
	choices(toolbar, types.map(func(t): return str(t.name)), int(draft.get("category", 0)), func(i): draft["category"] = i; selected = {}; send("selectAchievementType", [], types[i]))
	var category := int(draft.get("category", 0))
	if category > 0 and category < types.size():
		var subs: Array = [{"name": I18n.t("ach.all_subs"), "cat": types[category].cat, "sub": -1}] + types[category].get("subtypes", [])
		choices(toolbar, subs.map(func(t): return str(t.name)), int(draft.get("subcategory", 0)), func(i): draft["subcategory"] = i; send("selectAchievementSubtype", [], subs[i]))
	var show := int(draft.get("show", 0))
	choices(toolbar, [I18n.t("ach.show_pending"), I18n.t("ach.show_done"), I18n.t("ach.show_all")], show,
		func(i): draft["show"] = i; selected = {}; schedule_refresh()).name = "AchShow"
	var items: Array = data("achievementManager.achievementsList", []).filter(func(it):
		return show == 2 or bool(it.get("done", false)) == (show == 1))
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.name = "AchGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(grid)
	if items.is_empty():
		_muted(grid, I18n.t("ach.none"))
	for it in items:
		var b := Button.new()
		b.name = "Ach%d" % int(it.get("id", 0))
		b.custom_minimum_size = Vector2(228, 74)
		b.toggle_mode = true
		b.button_pressed = int(selected.get("id", -1)) == int(it.get("id", 0))
		b.pressed.connect(func(): selected = it; schedule_refresh())
		grid.add_child(b)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 8
		h.offset_right = -8
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var icon := TextureRect.new()
		icon.texture = _ach_icon(str(it.get("iconUrl", "")))
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)
		var nm := _small(col, str(it.get("name", "")), 14)
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var bar := ProgressBar.new()
		bar.value = float(it.get("completion", 0))
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar)
		var pts := _small(col, I18n.t("ach.pts", {"n": int(it.get("points", 0))}), 12)
		pts.add_theme_color_override("font_color", UiStyle.GOLD if bool(it.get("done", false)) else UiStyle.MUTED)
	var detail := column(split, false)
	detail.custom_minimum_size.x = 300
	if selected.is_empty():
		_muted(detail, I18n.t("ach.pick"))
		return
	var big := TextureRect.new()
	big.texture = _ach_icon(str(selected.get("iconUrl", "")))
	big.custom_minimum_size = Vector2(96, 96)
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(big)
	label(detail, str(selected.get("name", "")), 22).name = "AchName"
	var desc := label(detail, str(selected.get("desc", "")))
	desc.name = "AchDesc"
	var state := I18n.t("ach.done") if bool(selected.get("done", false)) \
		else I18n.t("ach.progress", {"n": int(selected.get("completion", 0))})
	label(detail, "%s · %s" % [state, I18n.t("ach.pts", {"n": int(selected.get("points", 0))})], 16)


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
		if not str(data("guild.name", "")).is_empty():
			_clan_demon()
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
	if tab == 0:
		# S11: watch a friend's fight (2260 → 26331), as /watch does
		var online := bool(selected.get("connected", selected.get("online", false)))
		button(toolbar, I18n.t("social.watch"), func():
			closed.emit()
			send("nativeWatch", [str(selected.get("name", ""))]),
			online).name = "WatchBtn"
	else:
		toolbar = row(body)
		if str(data("guild.name", "")).is_empty():
			button(toolbar, I18n.t("social.create_clan"), func(): send("nativeOpen", ["guildCreationDialog"]))
		else:
			button(toolbar, I18n.t("social.view_member"), func(): send("getMemberStats", [], selected), not selected.is_empty())
			button(toolbar, I18n.t("social.ranks"), func(): send("nativeOpen", ["guildManagementDialog"]), bool(data("guild.canManage", false)))
		button(toolbar, I18n.t("social.leave"), func(): confirm_action(I18n.t("social.leave_confirm"), func(): send("quitGuild")), not str(data("guild.name", "")).is_empty())


## The clan's demon (S18: the demon totem's job). The leader opens the
## offering panel; the first accepted offering affiliates the clan.
func _clan_demon() -> void:
	body.add_child(UiStyle.caption(I18n.t("clan.demon")))
	var bar := row(body)
	var demon := int(data("guild.demon", 0))
	label(bar, I18n.t("clan.demon_is", {"demon": str(data("guild.demonName", ""))})
		if demon > 0 else I18n.t("clan.demon_none")).name = "ClanDemon"
	if bool(data("guild.canOffer", false)):
		button(bar, I18n.t("clan.demon_offer"), func(): send("nativeDemonOpen")).name = "DemonOffer"
	else:
		label(bar, I18n.t("clan.demon_leader"))


## Async PvP ghosts (S13, server ghost.go): fight someone else's saved team,
## manage your own, or save your titular line-up with gambit rules per fighter.
## main pushes `ghosts` = {list: [{id, name, owner, fighters, elo, mine}],
## status}; the draft (name, rules by fighter id) lives in `draft` so the
## rebuild on every push does not lose it.
func _ghosts() -> void:
	if not draft.has("ghost_asked"):
		draft["ghost_asked"] = true
		send("nativeGhostList")
	tabs(body, [I18n.t("ghost.tab_fight"), I18n.t("ghost.tab_mine"), I18n.t("ghost.tab_new"),
		I18n.t("ghost.tab_ladder")], func(i):
			if i == 3:
				send("nativeGhostLadder"))
	var status := str(data("ghosts.status", ""))
	if status != "":
		label(body, status).name = "GhostStatus"
	var all: Array = data("ghosts.list", [])
	match tab:
		0, 1:
			var items := []
			for g in all:
				if (tab == 1) == bool(g.get("mine", false)):
					var it: Dictionary = g.duplicate()
					it["size"] = str(g.get("fighters", 0))
					if str(g.get("owner", "")) == "":
						it["owner"] = I18n.t("ghost.filler_owner")   # S14 filler
					items.append(it)
			label(body, I18n.t("ghost.fight_hint") if tab == 0 else I18n.t("ghost.mine_hint",
				{"n": items.size()}))
			table(body, [I18n.t("ghost.col_name"), I18n.t("ghost.col_owner"),
				I18n.t("ghost.col_size"), I18n.t("ghost.col_elo")],
				["name", "owner", "size", "elo"], items, func(_i): schedule_refresh())
			var bar := row(body)
			var picked := not selected.is_empty() and selected.has("id")
			if tab == 0:
				button(bar, I18n.t("ghost.fight"), func():
					closed.emit()
					send("nativeGhostFight", [int(selected.id)]), picked).name = "GhostFight"
				# S14: the server picks the ghost nearest our rating
				button(bar, I18n.t("ghost.auto"), func():
					closed.emit()
					send("nativeGhostFight", [0])).name = "GhostAuto"
			else:
				button(bar, I18n.t("ghost.delete"), func():
					confirm_action(I18n.t("ghost.delete_confirm"), func():
						send("nativeGhostDelete", [int(selected.id)])), picked).name = "GhostDelete"
			button(bar, I18n.t("ghost.refresh"), func(): send("nativeGhostList"))
		2:
			_ghost_new()
		3:
			_ghost_ladder()


## S14: the ghost ladder — our rating, place and record, then the top 50.
## main pushes `ghosts.ladder` = {elo, rank, fights, wins, rows: [...]}.
func _ghost_ladder() -> void:
	var l: Dictionary = data("ghosts.ladder", {})
	if l.is_empty():
		label(body, I18n.t("ghost.loading"))
		return
	_season_line()
	var rank := int(l.get("rank", 0))
	label(body, I18n.t("ghost.my_rating", {"elo": l.get("elo", 1000),
		"rank": rank if rank > 0 else "—", "fights": l.get("fights", 0),
		"wins": l.get("wins", 0)}), 18).name = "GhostMine"
	label(body, I18n.t("ghost.ladder_hint"))
	var rows := []
	var pos := 0
	for r in l.get("rows", []):
		pos += 1
		var it: Dictionary = r.duplicate()
		it["pos"] = str(pos)
		it["record"] = "%d / %d" % [int(r.wins), int(r.fights)]
		rows.append(it)
	table(body, ["#", I18n.t("ghost.col_owner"), I18n.t("ghost.col_elo"),
		I18n.t("ghost.col_record")], ["pos", "name", "elo", "record"], rows)


func _ghost_new() -> void:
	label(body, I18n.t("ghost.new_hint"))
	var top := row(body)
	var name_edit := field(top, "ghost_name", I18n.t("ghost.name_ph"))
	name_edit.name = "GhostName"
	name_edit.max_length = 32
	var rules: Dictionary = draft.get("ghost_rules", {})
	draft["ghost_rules"] = rules
	var fighters := _ghost_lineup()
	if fighters.is_empty():
		label(body, I18n.t("ghost.no_lineup"))
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 260
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	body.add_child(scroll)
	for f in fighters:
		var fid := int(f.get("id", 0))
		if not rules.has(fid):
			rules[fid] = []
		var cap: Label = UiStyle.caption(_rules_caption(f, rules[fid]))
		list.add_child(cap)
		var ed := GambitEditor.new(rules[fid], f.get("spells", []))
		ed.name = "Rules%d" % fid
		ed.changed.connect(func(): cap.text = _rules_caption(f, rules[fid]).to_upper())
		list.add_child(ed)
	var bar := row(body)
	button(bar, I18n.t("ghost.save"), func():
		var nm := str(draft.get("ghost_name", "")).strip_edges()
		if nm == "":
			model.set_value("ghosts", I18n.t("ghost.err.7"), "status")
			return
		var out := {}
		for fid in rules:
			var rs := GambitEditor.ruleset(rules[fid])
			if not rs.is_empty():
				out[fid] = rs
		send("nativeGhostSave", [nm, out, fighters.map(func(f): return int(f.get("id", 0)))])).name = "GhostSave"


func _rules_caption(f: Dictionary, list: Array) -> String:
	return "%s · %s" % [str(f.get("name", "?")), I18n.t("ghost.rules_n", {"n": list.size()})]


## The fighters the ghost is made of (S22): the Elite team picked on the
## hub's Ranking card — ghosts fight in the Ranking, so no Historia fighter
## (spheres, conditions). Without one, the Elite titulars, at most two of a
## breed and six in all, as the server's fallback picks them.
func _ghost_lineup() -> Array:
	var by_id := {}
	for f in State.roster:
		by_id[int(f.get("id", 0))] = f
	var picked: Array = []
	var sel := int(data("hub.ranked.selected", -1))
	for p in State.presets:
		if int(p.get("id", -1)) == sel:
			for pf in p.get("fighters", []):
				picked.append(int(pf.get("id", 0)))
	var out := []
	var per_breed := {}
	var source: Array = picked if not picked.is_empty() else State.roster.map(func(f): return int(f.get("id", 0)))
	for fid in source:
		var f: Variant = by_id.get(fid)
		if f == null or int(f.get("type", 2)) != 1 or out.size() >= 6:
			continue
		if picked.is_empty() and int(f.get("state", 0)) != 0:
			continue
		var b := int(f.get("breed", 0))
		if int(per_breed.get(b, 0)) >= 2:
			continue
		per_breed[b] = int(per_breed.get(b, 0)) + 1
		out.append(f)
	return out


## The replays this client recorded (S11, user://replays): newest first,
## watch or delete. Retail's replayDialog listed its game/replays folder.
func _replays() -> void:
	var all := ReplayFile.list()
	var items := []
	for r in all:
		var h: Dictionary = r.header
		var when := Time.get_datetime_dict_from_unix_time(int(h.get("recorded_at", 0)))
		var res := str(h.get("result", "none"))
		var item := {
			"id": r.path, "path": r.path,
			"date": "%02d/%02d %02d:%02d" % [when.day, when.month, when.hour, when.minute],
			"vs": "%s — %s" % [h.get("left", "?"), h.get("right", "?")],
			"result": I18n.t("replay.result." + res) if res in ["win", "loss"] \
				else I18n.t("replay.result.watched" if h.get("spectating", false) else "replay.result.none"),
			"length": _mmss(int(h.get("duration_ms", 0))) + ("" if h.get("complete", false) else " *"),
		}
		items.append(item)
	label(body, I18n.t("replay.subtitle", {"n": items.size(), "keep": ReplayFile.KEEP}))
	table(body, [I18n.t("replay.col_date"), I18n.t("replay.col_vs"),
		I18n.t("replay.col_result"), I18n.t("replay.col_length")],
		["date", "vs", "result", "length"], items, func(_item): schedule_refresh())
	var toolbar := row(body)
	var picked := not selected.is_empty() and selected.has("path")
	button(toolbar, I18n.t("replay.watch"), func():
		closed.emit()
		send("nativePlayReplay", [str(selected.path)]), picked).name = "PlayReplay"
	button(toolbar, I18n.t("replay.delete"), func():
		confirm_action(I18n.t("replay.delete_confirm"), func():
			DirAccess.remove_absolute(str(selected.path))
			selected = {}
			schedule_refresh()), picked).name = "DeleteReplay"
	if not bool(data("gamePreferences.saveReplays", true)):
		label(body, I18n.t("replay.off"))


static func _mmss(ms: int) -> String:
	var sec := maxi(ms, 0) / 1000
	return "%d:%02d" % [sec / 60, sec % 60]


## The services the walkable hall used to reach, from every island at once
## (the game has a lobby, not worlds): one button per service, grouped by
## kind. main pushes `city` from the client's env table.
## Servicios (S22): what was one dense grid is two columns — the groups on
## the left (each with what it offers), the picked group's services on the
## right as tiles, with a face where there is one.
func _city() -> void:
	var groups: Array = data("city.groups", [])
	if groups.is_empty():
		label(body, I18n.t("city.none"))
		return
	var pick := clampi(int(draft.get("group", 0)), 0, groups.size() - 1)
	var split := row(body)
	split.add_theme_constant_override("separation", 18)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := column(split, false)
	left.custom_minimum_size.x = 300
	for i in groups.size():
		var g: Dictionary = groups[i]
		var b := button(left, "%s  ·  %d" % [str(g.get("name", "")), g.get("services", []).size()],
			func(): draft["group"] = i; schedule_refresh())
		b.name = "Group%d" % i
		b.toggle_mode = true
		b.button_pressed = i == pick
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 48
	var right := column(split)
	var g: Dictionary = groups[pick]
	var h := label(right, str(g.get("name", "")), 24)
	h.add_theme_color_override("font_color", UiStyle.GOLD)
	if str(g.get("desc", "")) != "":
		var desc := _muted(right, str(g.desc))
		desc.name = "GroupDesc"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 200   # wrap instead of widening the window
	var grid := HFlowContainer.new()
	grid.name = "Services"
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	right.add_child(grid)
	for sv in g.get("services", []):
		var b := Button.new()
		b.custom_minimum_size = Vector2(240, 60)
		b.name = "Service%d" % int(sv.get("id", -1))
		b.text = str(sv.get("label", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if sv.has("portrait"):
			b.icon = _ach_icon(str(sv.portrait))
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 44)
		var sid := int(sv.get("id", -1))
		b.pressed.connect(func():
			closed.emit()
			send("nativeUseElement", [sid]))
		grid.add_child(b)


## Ayuda (S21): four tabs instead of one vague page — how to start, the three
## modes, the fight's rules, and what each lobby panel is for. Every panel
## also explains itself with its "?" (lobby_panel.gd).
func _help() -> void:
	tabs(body, [I18n.t("help.tab_start"), I18n.t("help.tab_modes"), I18n.t("help.tab_fight"),
		I18n.t("help.tab_panels")])
	match tab:
		0:
			_first_steps()
			label(body, I18n.t("help.controls"), 22)
			label(body, I18n.t("help.controls_b"))
		1:
			for m in ["story", "ranked", "tourn"]:
				var h := label(body, I18n.t("hub." + m), 24)
				h.add_theme_color_override("font_color", UiStyle.GOLD)
				label(body, I18n.t("help.mode_%s" % m))
		2:
			for i in 6:
				label(body, "· " + I18n.t("help.fight%d" % i))
		3:
			for key in ["nav.team", "nav.inventory", "nav.ladder", "nav.calendar", "nav.achievements",
					"nav.city", "nav.stats", "nav.social"]:
				var h := label(body, I18n.t(key), 20)
				h.add_theme_color_override("font_color", UiStyle.GOLD)
				label(body, I18n.t("help.panel_%s" % key.trim_prefix("nav.")))


## "Primeros pasos" (S10): the tutorial achievements in the order retail's
## help (tooltipTutoDialog) offered them, the first one still open marked as
## the next step, with how to do it here (the lobby, not the island).
func _first_steps() -> void:
	label(body, I18n.t("help.steps"), 22).name = "FirstSteps"
	var next := -1
	for aid in Scenarios.TUTORIAL_STEPS:
		var done := NpcDialogs.achievement_done(aid, State.criteria, State.inventory)
		if not done and next < 0:
			next = aid
		var line := label(body, "%s %s — %s" % ["✓" if done else ("▶" if aid == next else "·"),
			NpcDialogs.achievement_name(aid), I18n.t("help.step_%d" % aid)])
		line.name = "Step%d" % aid
		if done:
			line.add_theme_color_override("font_color", UiStyle.MUTED)
	if next < 0:
		label(body, I18n.t("help.steps_done"))


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
	# music and effects (src/audio/audio.gd), under the retail
	# optionsDialog keys — its "sounds" pair is ambianceSounds*
	label(body, I18n.t("opt.sound"), 22)
	for entry in [["opt.music", "musicMute", "setMusicMute", "musicVolume", "setMusicVolume"],
			["opt.effects", "ambianceSoundsMute", "setSoundsMute", "ambianceSoundsVolume", "setSoundsVolume"]]:
		var line := row(body)
		var name_label := label(line, I18n.t(entry[0]))
		name_label.size_flags_horizontal = Control.SIZE_FILL
		name_label.custom_minimum_size.x = 110
		var volume := HSlider.new()
		volume.name = entry[3]
		volume.min_value = 0
		volume.max_value = 1
		volume.step = 0.05
		volume.value = float(data("gamePreferences." + entry[3], 0.5))
		volume.custom_minimum_size = Vector2(220, 38)
		volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		volume.value_changed.connect(func(value): model.set_value("gamePreferences", value, entry[3]); send(entry[4]))
		line.add_child(volume)
		var mute := CheckButton.new()
		mute.name = entry[1]
		mute.text = I18n.t("opt.mute")
		mute.button_pressed = bool(data("gamePreferences." + entry[1], false))
		mute.toggled.connect(func(value): model.set_value("gamePreferences", value, entry[1]); send(entry[2]))
		line.add_child(mute)
	# client-only fight look (sprints/S04, S17) — user://settings.cfg, read
	# when the next fight opens
	label(body, I18n.t("opt.fight"), 22)
	var life_bar := row(body)
	label(life_bar, I18n.t("opt.hud_life"))
	choices(life_bar, [I18n.t("opt.life.bar"), I18n.t("opt.life.ring")],
		maxi(0, ArtStyle.HUD_LIFE.find(ArtStyle.hud_life())),
		func(i): ArtStyle.set_hud_life(ArtStyle.HUD_LIFE[i]))
	# retail's gamePreferences.saveReplays (S11): the recorder reads it at
	# each fight's start
	var save := CheckButton.new()
	save.name = "saveReplays"
	save.text = I18n.t("opt.save_replays")
	save.button_pressed = bool(data("gamePreferences.saveReplays", true))
	save.toggled.connect(func(value): model.set_value("gamePreferences", value, "saveReplays"); send("setSaveReplay"))
	body.add_child(save)
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
	var breeds: Array = range(1, 13).map(func(b): return I18n.t("breed.%d" % b))
	choices(bar, breeds, int(fighter.get("breedId", 1)) - 1, func(i): send("setFighterBreedId", [i + 1]))
	choices(bar, [I18n.t("fc.sex_m"), I18n.t("fc.sex_f")], int(fighter.get("sex", 0)), func(i): send("setFighterSex", [i]))
	# the original Wakfu/Dofus pick: version 2 recruits to the evolution
	# roster, version 1 to a classic preset
	choices(bar, [I18n.t("fc.v_classic"), I18n.t("fc.v_evo")],
		clampi(int(fighter.get("version", 1)) - 1, 0, 1),
		func(i): send("setFighterVersion", [i + 1]))
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
	# actorDescriptorLibrary is normally a bare set name ("fighter_-110"),
	# but tolerate an already-qualified or legacy res:// one.
	var set_dir := AssetPaths.normalize(lib)
	if not set_dir.begins_with("anims/"):
		set_dir = "anims/" + set_dir
	if not Direction8.load_idle(_preview, set_dir, _preview_dir):
		Direction8.load_idle_any(_preview, set_dir)


func _team_name() -> void:
	label(body, I18n.t("tn.subtitle"), 22)
	var name_field := field(body, "team_name", I18n.t("tn.name_ph"))
	name_field.max_length = 20
	# 2v2: the partner is an online friend (the server invites by coach id)
	var mates: Array = []
	if panel_name == "team2vs2NameDialog":
		for fr in data("friends.list", []):
			if int(fr.get("id", -1)) > 0 and bool(fr.get("online", false)):
				mates.append(fr)
		if mates.is_empty():
			label(body, I18n.t("tn.no_mates")).name = "NoMates"
		else:
			var bar := row(body)
			label(bar, I18n.t("tn.mate"))
			choices(bar, mates.map(func(f): return str(f.name)), clampi(int(draft.get("mate", 0)), 0, mates.size() - 1),
				func(i): draft["mate"] = i).name = "Mate"
	var error := label(body, "")
	var create := button(body, I18n.t("tn.create"), func():
		if name_field.text.strip_edges().is_empty():
			error.text = I18n.t("tn.err_name")
			return
		model.set_value("teamManagement", name_field.text.strip_edges(), "teamName")
		if panel_name == "team2vs2NameDialog":
			var m: Dictionary = mates[clampi(int(draft.get("mate", 0)), 0, mates.size() - 1)]
			model.set_value("teamManagement", {"id": int(m.id), "name": str(m.name)}, "teammateName")
		send("addNewTeamXvsX" if panel_name == "team2vs2NameDialog" else ("addNewTournamentTeam" if panel_name == "newTeamTournamentDialog" else "addNewTeam")),
		panel_name != "team2vs2NameDialog" or not mates.is_empty())
	create.name = "Create"


## Equipo del luchador (S22): what the owner found dense, as tiles. Spells:
## the equipped ones on top (up to 6), the rest below — a click equips or
## takes one off. Equipment: the five slots with the card's art; the cards
## for the picked slot below, a click puts one on. "Guardar" sends it all.
func _equipment() -> void:
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	var head := row(body)
	label(head, str(fighter.get("name", "")), 24)
	var budget := label(head, I18n.t("fe.budget", {"n": int(fighter.get("value", 0))}), 16)
	budget.add_theme_color_override("font_color", UiStyle.MUTED)
	tabs(body, [I18n.t("fe.spells"), I18n.t("fe.equip")])
	if tab == 0:
		var spells: Array = data("teamManagement.editableFighter.breedSpells", [])
		var on: Array = spells.filter(func(sp): return bool(sp.get("equipped", false)))
		var off: Array = spells.filter(func(sp): return not bool(sp.get("equipped", false)))
		label(body, I18n.t("fe.equipped_n", {"n": on.size()}), 18)
		var top := HFlowContainer.new()
		top.name = "SpellsOn"
		body.add_child(top)
		if on.is_empty():
			_muted(top, I18n.t("fe.no_spells"))
		for sp in on:
			_spell_tile(top, sp, true, false)
		label(body, I18n.t("fe.available"), 18)
		var rest := HFlowContainer.new()
		rest.name = "SpellsOff"
		body.add_child(rest)
		for sp in off:
			_spell_tile(rest, sp, false, on.size() >= 6)
		_muted(body, I18n.t("fe.spell_hint"))
	else:
		var slots := [I18n.t("fe.slot_weapon"), I18n.t("fe.slot_pet"), I18n.t("fe.slot_cloak"), I18n.t("fe.slot_hat"), I18n.t("fe.slot_dofus")]
		var slot := int(data("teamManagement.selectedItemCardListType", 0))
		var bar := HBoxContainer.new()
		bar.name = "Slots"
		bar.add_theme_constant_override("separation", 8)
		body.add_child(bar)
		for i in slots.size():
			var worn: Dictionary = data("teamManagement.editableFighter." + EQ_FIELDS[i], {})
			var b := _tile(bar, {"id": int(worn.get("id", 0)), "fighter": true,
				"name": str(worn.get("name", I18n.t("fe.none")))}, i == slot, "", str(slots[i]))
			b.name = "Slot%d" % i
			b.custom_minimum_size = Vector2(150, 180)
			var idx := i
			b.pressed.connect(func(): selected = {}; send("changeItemCardType", [idx]))
		var equipped: Dictionary = data("teamManagement.editableFighter." + EQ_FIELDS[slot], {})
		var line := row(body)
		label(line, I18n.t("fe.equipped_x", {"name": str(equipped.get("name", I18n.t("fe.none")))}), 17)
		button(line, I18n.t("fe.unequip"), func(): send("removeEquipment", [slot]), not equipped.is_empty()).name = "Unequip"
		var pool: Array = data("teamManagement.selectedItemCardList", [])
		var grid := HFlowContainer.new()
		grid.name = "Pool"
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		body.add_child(grid)
		if pool.is_empty():
			_muted(grid, I18n.t("fe.no_cards"))
		for it in pool:
			var t := _tile(grid, it, int(it.get("id", 0)) == int(equipped.get("id", -1)), "",
				I18n.t("fe.value", {"n": int(it.get("value", 0))}))
			t.name = "Card%d" % int(it.get("id", 0))
			var item: Dictionary = it
			t.pressed.connect(func(): send("addEquipment", [], item))
		var nav := row(body)
		button(nav, I18n.t("ladder.prev"), func(): send("decreaseList"))
		button(nav, I18n.t("ladder.next"), func(): send("increaseList"))
	# The save says what happened (S20): enabled only with changes, then
	# "Guardando…", then "✓ Guardado" until the next edit.
	var dirty := bool(fighter.get("dirty", false))
	var state := str(fighter.get("saveState", ""))
	var save_text := I18n.t("fe.save")
	if state == "saving":
		save_text = I18n.t("fe.saving")
	elif state == "saved" and not dirty:
		save_text = I18n.t("fe.saved")
	pinned_actions.show()
	if state == "error":
		label(pinned_actions, I18n.t("fe.save_failed")).add_theme_color_override(
			"font_color", Color("e07a5f"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var save := button(pinned_actions, save_text, func(): send("saveEditableFighter"),
		dirty and state != "saving")
	save.name = "Save"
	save.custom_minimum_size.x = 220
	UiStyle.primary(save, 20)


## One spell as a tile: its icon, name and AP; a click equips it or takes it
## off (full = six equipped, so the rest are offered but disabled).
func _spell_tile(parent: Node, sp: Dictionary, equipped: bool, full: bool) -> void:
	var b := Button.new()
	b.name = "Spell%d" % int(sp.get("id", 0))
	b.custom_minimum_size = Vector2(176, 64)
	b.disabled = full and not equipped
	b.tooltip_text = I18n.t("fe.spell_tip", {"ap": int(sp.get("actionPoints", 0)), "range": str(sp.get("range", ""))})
	parent.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var icon := TextureRect.new()
	icon.texture = _ach_icon("gui/images/spells/icons/%d.png" % int(sp.get("id", 0)))
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not equipped:
		icon.modulate = Color(1, 1, 1, 0.55)
	h.add_child(icon)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(col)
	var nm := _small(col, str(sp.get("name", "")), 14)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var ap := _small(col, I18n.t("fe.ap", {"n": int(sp.get("actionPoints", 0))}), 12)
	ap.add_theme_color_override("font_color", UiStyle.GOLD if equipped else UiStyle.MUTED)
	var item := sp
	b.pressed.connect(func(): send("removeSpell" if equipped else "addSpell", [], item))


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
