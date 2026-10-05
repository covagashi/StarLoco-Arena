extends "res://src/ui/lobby_panel.gd"
## Native presentations over the existing GuiModel and action handlers.
## No XML layout or protocol serialization lives in these panels.

const TITLES := {
	"menuDialog": "Menú", "teamManagementDialog": "Equipo y arena",
	"evolutionDialog": "Equipo y arena", "coachStatisticsDialog": "Estadísticas del jefe",
	"cardBookDialog": "Inventario", "ladderInformationDialog": "Clasificación",
	"calendarDialog": "Calendario", "achievementDialog": "Logros",
	"socialDialog": "Social", "tooltipDialog": "Ayuda", "optionsDialog": "Opciones",
	"fighterCreationDialog": "Nuevo luchador", "fighterEquipmentDialog": "Equipo del luchador",
	"teamNameDialog": "Nuevo equipo", "team2vs2NameDialog": "Nuevo equipo 2v2",
	"newTeamTournamentDialog": "Equipo de torneo",
	"guildDialog": "Clan", "guildCreationDialog": "Crear clan",
	"guildManagementDialog": "Rangos del clan", "guildCoachStatsDialog": "Miembro del clan",
}
var _preview
var _preview_look := ""

const FORMS := ["fighterCreationDialog", "teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog", "optionsDialog"]
const BOARDS := ["list1vs1", "listReputation", "list2vs2", "listGuild", "listTournamentInTheMonth", "listGlickoRating", "listDemon"]
const EQ_FIELDS := ["weaponEquipment", "petEquipment", "cloakEquipment", "hatEquipment", "dofusEquipment"]
const BREEDS := ["Feca", "Osamodas", "Anutrof", "Sram", "Xelor", "Zurcarák", "Aniripsa", "Yopuka", "Ocra", "Sadida", "Sacrógrito", "Pandawa"]


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
	title.text = TITLES.get(panel_name, panel_name)
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
	label(body, "Prepara tu próxima partida o ajusta el juego.", 22)
	var actions := column(body)
	for entry in [["Opciones", "optionsDialog"], ["Ayuda", "tooltipDialog"], ["Equipo y arena", "teamManagementDialog"]]:
		button(actions, entry[0], func():
			closed.emit()
			send("nativeOpen", [entry[1]]))
	button(actions, "Volver al lobby", func(): closed.emit())
	button(actions, "Desconectar", func(): confirm_action("¿Cerrar la sesión actual?", func(): send("nativeDisconnect")))
	button(actions, "Salir del juego", func(): confirm_action("¿Salir del juego?", func(): send("quit")))


func _team() -> void:
	tab = clampi(int(data("gamePreferences.lastSelectedGameModeId", tab)), 0, 4)
	tabs(body, ["Evolución", "Élite", "2v2", "Torneos", "Leyendas"], func(i): send("changeTeamTab", [], null, i))
	var classic := tab in [1, 2, 3]
	var toolbar := row(body)
	if classic:
		var presets: Array = data("teamManagement.teamManager.teamPreset1vs1List", []) + data("teamManagement.teamManager.teamPreset2vs2List", [])
		var names: Array = ["Selecciona un equipo"]
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
		button(toolbar, "Nuevo equipo", func(): send("nativeOpen", [["teamNameDialog", "team2vs2NameDialog", "newTeamTournamentDialog"][tab - 1]]))
		button(toolbar, "Guardar", func(): send("saveTeam"), picked > 0)
		button(toolbar, "Eliminar equipo", func(): confirm_action("¿Eliminar este equipo?", func(): send("deleteEditableTeamPreset")), picked > 0)
	else:
		label(toolbar, "Titulares y suplentes" if tab == 0 else "Luchadores legendarios", 20)
	button(toolbar, "Crear luchador", func(): send("createNewFighter" if classic else "createNewEvolutionFighter"))
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
		item["placement"] = ("En equipo" if item.get("teamMember", false) else "Reserva") if classic else ("Suplente" if int(item.get("state", 0)) in [1, 5] else "Titular")
		rows.append(item)
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var roster := column(split)
	label(roster, "Luchadores · %d" % rows.size(), 20)
	table(roster, ["Nombre", "Clase", "Posición"], ["name", "breed_name", "placement"], rows, func(_item): schedule_refresh())
	var detail := column(split, false)
	detail.custom_minimum_size.x = 260
	if selected.is_empty():
		label(detail, "Selecciona un luchador para ver sus acciones.")
		label(detail, "Si la lista está vacía, crea tu primer luchador.")
	else:
		label(detail, str(selected.get("name", "")), 23)
		label(detail, "%s · %s" % [selected.get("breed_name", ""), selected.get("placement", "")])
		button(detail, "Equipamiento y hechizos", func(): send("editFighter", [selected], selected))
		if classic:
			button(detail, "Quitar del equipo" if selected.get("teamMember", false) else "Añadir al equipo", func(): send("addRemoveFighterFromEditableTeamPreset", [], selected), int(draft.get("preset_id", -1)) > 0)
		else:
			button(detail, "Cambiar titular / suplente", func(): send("changeFighterStatus", [], selected), int(selected.get("state", 0)) != 3)
		if not classic:
			button(detail, "Convertir en leyenda", func(): confirm_action("¿Convertir este luchador en leyenda?", func(): send("becomeALegend", [selected], selected)))
		button(detail, "Eliminar luchador", func(): confirm_action("¿Eliminar a %s?" % selected.get("name", ""), func(): send("deleteFighter", [selected], selected)))
	pinned_actions.show()
	var footer := pinned_actions
	var hint := label(footer, "Cambios de equipo sincronizados con el servidor")
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button(footer, "Entrenamiento", func(): send("launchTeamTest"))
	button(footer, "Buscar combate", func(): send("launchEvolutionFight" if tab == 0 else "setClassicReadyForFight"), tab in [0, 1, 2])
	if tab in [3, 4]:
		label(body, "La búsqueda de %s todavía no está disponible." % ("torneos" if tab == 3 else "leyendas"))


func _statistics() -> void:
	var coach: Dictionary = data("localCoach", {})
	label(body, str(coach.get("name", "")), 24)
	var rows: Array = []
	for entry in [["Combates", "statisticsTotalFights"], ["Victorias", "statisticsTotalFightsWon"], ["Derrotas", "statisticsTotalFightsLost"], ["Victorias consecutivas", "statisticsConsecutiveWins"], ["Tiempo jugado (s)", "statisticsTotalPlayTime"], ["Tiempo en combate (s)", "statisticsTotalFightsTime"], ["Puntos de torneo", "statisticsTournamentPoints"], ["Reputación", "standing"]]:
		rows.append({"name": entry[0], "value": coach.get(entry[1], 0)})
	table(body, ["Estadística", "Valor"], ["name", "value"], rows)


func _inventory() -> void:
	tabs(body, ["Todas", "Equipamiento", "Zaaps", "Especiales", "Colecciones"])
	var paths := ["cardInventory", "filtredEquipmentCardInventory", "zaapInventory", "specialCardInventory", "cardSets"]
	var items: Array = data("localCoach." + paths[tab], [])
	var toolbar := row(body)
	var search := field(toolbar, "search", "Buscar por nombre")
	button(toolbar, "Buscar", schedule_refresh)
	search.text_submitted.connect(func(_text): schedule_refresh())
	button(toolbar, "Limpiar", func(): draft["search"] = ""; schedule_refresh())
	items = items.filter(func(item): return str(item.get("name", "")).to_lower().contains(str(draft.get("search", "")).to_lower()))
	table(body, ["Colección", "En posesión", "Total"] if tab == 4 else ["Carta", "Cantidad", "Valor"], ["name", "completion", "size"] if tab == 4 else ["name", "quantity", "value"], items, func(_item): schedule_refresh())
	if not selected.is_empty():
		label(body, str(selected.get("name", "")), 20)
		if tab == 4:
			table(body, ["Carta", "Cantidad"], ["name", "quantity"], selected.get("collection", []))
		else:
			label(body, "Colección: " + str(selected.get("cardSetName", "—")))
			if int(selected.get("cardType", 0)) == 20:
				button(body, "Viajar con esta carta", func(): send("useSpecialCard", [], selected), int(selected.get("quantity", 0)) > 0)


func _ladder() -> void:
	choices(body, ["1 contra 1", "Jefes", "2 contra 2", "Clanes", "Torneos", "Liga Pro", "Demonios"], tab, func(i): tab = i; selected = {}; send("nativeLadderTab", [i]); schedule_refresh())
	var fields := [["position", "coachName", "totalVictories", "totalDefeats"], ["position", "creatorCoachName", "reputation", "totalVictories"], ["position", "teamName", "totalVictories", "totalDefeats"], ["position", "name", "bossName", "strength"], ["position", "name", "points"], ["position", "coachName", "guildName", "rating"], ["position", "demonName", "guildName", "quarterlyReputationPoints"]]
	var headings := [["Puesto", "Jugador", "Victorias", "Derrotas"], ["Puesto", "Jefe", "Reputación", "Victorias"], ["Puesto", "Equipo", "Victorias", "Derrotas"], ["Puesto", "Clan", "Jefe", "Fuerza"], ["Puesto", "Nombre", "Puntos"], ["Puesto", "Jugador", "Clan", "Puntuación"], ["Puesto", "Demonio", "Clan", "Reputación"]]
	table(body, headings[tab], fields[tab], data("ladderManager." + BOARDS[tab], []))
	var footer := row(body)
	for entry in [["Inicio", "firstPlayerLadderInformationDialog"], ["Anterior", "backwardTenLadderInformationDialog"], ["Siguiente", "forwardTenLadderInformationDialog"], ["Mi posición", "coachSearchLadderInformationDialog"], ["Última página", "lastPlayerLadderInformationDialog"]]:
		button(footer, entry[0], func(): send(entry[1]))


func _calendar() -> void:
	var toolbar := row(body)
	button(toolbar, "Mes anterior", func(): selected = {}; send("showPreviousMonth"))
	label(toolbar, str(data("calendar.currentMonth", "Calendario")), 22)
	button(toolbar, "Mes siguiente", func(): selected = {}; send("showNextMonth"))
	var split := row(body)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	split.add_child(grid)
	for day in ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]:
		label(grid, day)
	for cell in data("calendar.calendar", []):
		var events: Array = cell.get("events", [])
		var text := str(cell.get("day", ""))
		var b := button(grid, text + (" · %d" % events.size() if not events.is_empty() else ""), func(): selected = cell; schedule_refresh(), not text.is_empty())
		b.custom_minimum_size = Vector2(85, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := column(split)
	label(details, "Día " + str(selected.get("day", "—")), 22)
	var events: Array = selected.get("events", [])
	if events.is_empty():
		label(details, "No hay eventos para este día.")
	for event in events:
		label(details, str(event.get("title", "")), 20)
		label(details, str(event.get("description", "")))
		button(details, "Inscribirme", func(): confirm_action("¿Inscribirte en este torneo?", func(): send("registerTournament", [event], event)))


func _achievements() -> void:
	var toolbar := row(body)
	label(toolbar, "%s puntos" % data("achievementManager.achievementsTotalPoints", 0), 22)
	var types: Array = [{"name": "Todas las categorías", "cat": -1}] + data("achievementManager.achievementTypesList", [])
	choices(toolbar, types.map(func(t): return str(t.name)), int(draft.get("category", 0)), func(i): draft["category"] = i; selected = {}; send("selectAchievementType", [], types[i]))
	var category := int(draft.get("category", 0))
	if category > 0 and category < types.size():
		var subs: Array = [{"name": "Todos los tipos", "cat": types[category].cat, "sub": -1}] + types[category].get("subtypes", [])
		choices(toolbar, subs.map(func(t): return str(t.name)), int(draft.get("subcategory", 0)), func(i): draft["subcategory"] = i; send("selectAchievementSubtype", [], subs[i]))
	var items: Array = data("achievementManager.achievementsList", [])
	table(body, ["Logro", "Progreso (%)", "Puntos"], ["name", "completion", "points"], items, func(_item): schedule_refresh())
	if not selected.is_empty():
		label(body, str(selected.get("descriptionDone", selected.get("name", ""))))


func _social() -> void:
	tabs(body, ["Amigos", "Ignorados", "Clan"])
	var paths := ["friends.list", "ignore.list", "guild.members"]
	var items: Array = []
	for source in data(paths[tab], []):
		var item: Dictionary = source.duplicate()
		item["status"] = "Conectado" if item.get("connected", item.get("online", false)) else "Desconectado"
		items.append(item)
	if tab == 2:
		label(body, str(data("guild.name", "Sin clan")), 22)
	table(body, ["Nombre"] if tab == 1 else ["Nombre", "Estado"], ["name"] if tab == 1 else ["name", "status"], items, func(_item): schedule_refresh())
	var toolbar := row(body)
	var edit := field(toolbar, "social_name", "Nombre del jefe")
	var add: String = ["addToFriendList", "addToIgnoreList", "inviteToGuild"][tab]
	button(toolbar, "Invitar al clan" if tab == 2 else "Añadir", func():
		if not edit.text.strip_edges().is_empty():
			send(add, [edit.text.strip_edges()]))
	edit.text_submitted.connect(func(text):
		if not text.strip_edges().is_empty(): send(add, [text.strip_edges()]))
	if tab < 2:
		button(toolbar, "Eliminar seleccionado", func(): send("removeFromFriendList" if tab == 0 else "removeFromIgnoreList", [selected]), not selected.is_empty())
	else:
		toolbar = row(body)
		if str(data("guild.name", "")).is_empty():
			button(toolbar, "Crear clan", func(): send("nativeOpen", ["guildCreationDialog"]))
		else:
			button(toolbar, "Ver miembro", func(): send("getMemberStats", [], selected), not selected.is_empty())
			button(toolbar, "Rangos", func(): send("nativeOpen", ["guildManagementDialog"]), bool(data("guild.canManage", false)))
		button(toolbar, "Abandonar clan", func(): confirm_action("¿Abandonar el clan?", func(): send("quitGuild")), not str(data("guild.name", "")).is_empty())


func _help() -> void:
	for heading in ["Prepara tu equipo", "Elige un combate", "Habla con otros jugadores", "Navega por los paneles"]:
		label(body, heading, 22)
		match heading:
			"Prepara tu equipo": label(body, "En Equipo puedes crear luchadores, elegir una composición y ajustar equipamiento y hechizos. Evolución y Élite utilizan listas distintas.")
			"Elige un combate": label(body, "Entrenamiento inicia un desafío contra la IA. Combate busca un rival clasificado. Aleatorio y Evolución usan sus respectivas colas; 2v2 permite gestionar un dúo.")
			"Habla con otros jugadores": label(body, "Enter enfoca el chat del lobby. Usa /w nombre mensaje para un privado, /t para comercio, /p para grupo y /c para clan.")
			"Navega por los paneles": label(body, "Cerrar o Escape vuelve al panel anterior. Tab recorre los controles y Enter activa el control enfocado. Las listas permiten desplazamiento cuando contienen muchos elementos.")


func _options() -> void:
	label(body, "Pantalla", 22)
	for entry in [["Pantalla completa", "fullScreen", "setFullScreen"], ["Sincronización vertical", "vsyncActivated", "activateVSync"]]:
		var check := CheckButton.new()
		check.text = entry[0]
		check.button_pressed = bool(data("gamePreferences." + entry[1], false))
		check.toggled.connect(func(value): model.set_value("gamePreferences", value, entry[1]); send(entry[2]))
		body.add_child(check)
	var bar := row(body)
	var sizes := ["1024x768", "1280x720", "1280x832", "1440x900", "1920x1080"]
	var current := str(data("gamePreferences.screenResolution", "1280x720"))
	choices(bar, sizes, maxi(0, sizes.find(current)), func(i): model.set_value("gamePreferences", sizes[i], "screenResolution"))
	button(bar, "Aplicar resolución", func(): send("applyResolution"))
	label(body, "Sonido", 22)
	var mute := CheckButton.new()
	mute.text = "Silenciar música"
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
	label(body, "Cuenta", 22)
	button(body, "Eliminar jefe…", func(): send("destroyCoach"))


func _fighter_creation() -> void:
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	var split := row(body)
	var form := column(split)
	label(form, "Elige su clase y apariencia", 22)
	var name_field := field(form, "fighter_name", "Nombre del luchador", str(fighter.get("name", "")))
	name_field.max_length = 20
	var bar := row(form)
	choices(bar, BREEDS, int(fighter.get("breedId", 1)) - 1, func(i): send("setFighterBreedId", [i + 1]))
	choices(bar, ["Masculino", "Femenino"], int(fighter.get("sex", 0)), func(i): send("setFighterSex", [i]))
	for entry in [["Piel", "skin", "setFighterSkinColorIndex"], ["Pelo", "hair", "setFighterHairColorIndex"], ["Ojos", "eye", "setFighterEyeColorIndex"]]:
		var line := row(form)
		label(line, entry[0])
		var options: Array = []
		for i in Palettes.NATURAL.size(): options.append("Color %d" % (i + 1))
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
	_preview.scale = Vector2(-2.5, 2.5)
	stage.add_child(_preview)
	_preview_look = ""
	_sync_preview()
	var error := label(body, "")
	var submit := func():
		if name_field.text.strip_edges().is_empty():
			error.text = "Escribe un nombre para tu luchador."
			return
		model.set_value("teamManagement", name_field.text.strip_edges(), "editableFighter.name")
		send("createFighter")
	button(body, "Crear luchador", submit)
	name_field.text_submitted.connect(func(_text): submit.call())


func _sync_preview() -> void:
	if not is_instance_valid(_preview):
		return
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	var lib := str(fighter.get("actorDescriptorLibrary", ""))
	if lib.is_empty():
		return
	_preview.tints = fighter.get("actorMaterial", {})
	var look := "%s/%s/%s/%s" % [lib, fighter.get("skin", 0), fighter.get("hair", 0), fighter.get("eye", 0)]
	if look == _preview_look:
		return
	_preview_look = look
	for dir in [3, 5, 2, 0, 6, 1, 7, 4]:
		if _preview.load_action("res://assets/anims/" + lib, "%d_AnimStatique" % dir):
			_preview.scale.x = -2.5 if dir in [1, 2, 3] else 2.5
			break


func _team_name() -> void:
	label(body, "Pon nombre a tu composición", 22)
	var name_field := field(body, "team_name", "Nombre del equipo")
	name_field.max_length = 20
	var teammate: LineEdit
	if panel_name == "team2vs2NameDialog":
		teammate = field(body, "teammate", "Nombre de un amigo para invitar")
	var error := label(body, "")
	button(body, "Crear equipo", func():
		if name_field.text.strip_edges().is_empty():
			error.text = "Escribe un nombre para el equipo."
			return
		model.set_value("teamManagement", name_field.text.strip_edges(), "teamName")
		if teammate != null:
			model.set_value("teamManagement", teammate.text.strip_edges(), "teammateName")
		send("addNewTeamXvsX" if panel_name == "team2vs2NameDialog" else ("addNewTournamentTeam" if panel_name == "newTeamTournamentDialog" else "addNewTeam")))


func _equipment() -> void:
	var fighter: Dictionary = data("teamManagement.editableFighter", {})
	label(body, str(fighter.get("name", "")), 23)
	tabs(body, ["Hechizos", "Equipamiento"])
	if tab == 0:
		var spells: Array = data("teamManagement.editableFighter.breedSpells", [])
		var rows: Array = []
		for spell in spells:
			var item: Dictionary = spell.duplicate()
			item["status"] = "Equipado" if item.get("equipped", false) else "Disponible"
			rows.append(item)
		table(body, ["Hechizo", "PA", "Alcance", "Estado"], ["name", "actionPoints", "range", "status"], rows, func(_item): schedule_refresh())
		button(body, "Quitar hechizo" if selected.get("equipped", false) else "Equipar hechizo", func(): send("removeSpell" if selected.get("equipped", false) else "addSpell", [], selected), not selected.is_empty())
		label(body, "Puedes equipar hasta 6 hechizos.")
	else:
		var slots := ["Arma", "Mascota", "Capa", "Sombrero", "Dofus"]
		var slot := int(data("teamManagement.selectedItemCardListType", 0))
		choices(body, slots, slot, func(i): selected = {}; send("changeItemCardType", [i]))
		var equipped: Dictionary = data("teamManagement.editableFighter." + EQ_FIELDS[slot], {})
		label(body, "Equipado: " + str(equipped.get("name", "Ninguno")))
		button(body, "Quitar equipamiento", func(): send("removeEquipment", [slot]), not equipped.is_empty())
		table(body, ["Carta", "Cantidad", "Valor"], ["name", "quantity", "value"], data("teamManagement.selectedItemCardList", []), func(_item): schedule_refresh())
		var nav := row(body)
		button(nav, "Anterior", func(): send("decreaseList"))
		button(nav, "Siguiente", func(): send("increaseList"))
		button(nav, "Equipar carta", func(): send("addEquipment", [], selected), not selected.is_empty())
	button(body, "Guardar cambios", func(): send("saveEditableFighter"))


func _guild_creation() -> void:
	label(body, "Reúne a otros jefes en tu clan", 22)
	var edit := field(body, "guild_name", "Nombre del clan")
	var error := label(body, "")
	button(body, "Crear clan", func():
		if edit.text.strip_edges().length() < 5:
			error.text = "El nombre debe tener al menos 5 caracteres."
			return
		model.set_value("guildCreationName", edit.text.strip_edges())
		send("createGuild"))


func _guild_management() -> void:
	var ranks: Array = data("guild.editableRanks", [])
	table(body, ["Rango", "Nivel"], ["name", "rankLevel"], ranks, func(item):
		for key in ["rank_name", "canInvite", "canRemove", "canPromote", "canDepromote"]:
			draft.erase(key)
		send("selectRank", [], item))
	var rank: Dictionary = data("guildSelectedRank", {})
	var edit := field(body, "rank_name", "Nombre del rango", str(rank.get("name", "")))
	var rights := row(body)
	for entry in [["Invitar", "canInvite"], ["Expulsar", "canRemove"], ["Ascender", "canPromote"], ["Descender", "canDepromote"]]:
		var check := CheckBox.new()
		check.text = entry[0]
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
	button(actions, "Añadir rango", func(): save.call("addRankToGuild"))
	button(actions, "Guardar rango", func(): save.call("modifyRank"), not rank.is_empty())
	button(actions, "Eliminar rango", func(): confirm_action("¿Eliminar el rango seleccionado?", func(): send("removeRankToGuild")), not rank.is_empty())


func _guild_member() -> void:
	var member: Dictionary = data("guildCoachStats", {})
	label(body, str(member.get("name", "")), 24)
	var rows: Array = []
	for entry in [["Combates", "statisticsTotalFights"], ["Victorias", "statisticsTotalFightsWon"], ["Derrotas", "statisticsTotalFightsLost"], ["Racha", "statisticsConsecutiveWins"]]:
		rows.append({"name": entry[0], "value": member.get(entry[1], 0)})
	table(body, ["Estadística", "Valor"], ["name", "value"], rows)
	var actions := row(body)
	button(actions, "Ascender", func(): send("promote"), bool(data("guildCanPromote", false)))
	button(actions, "Descender", func(): send("depromote"), bool(data("guildCanDepromote", false)))
	button(actions, "Expulsar", func(): confirm_action("¿Expulsar al miembro del clan?", func(): send("removeGuildMember")), bool(data("guildExcluder", false)))
