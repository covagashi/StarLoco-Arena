extends "res://test/world_smoke.gd"

## S21: Historia, live. In Spanish.
##
##   godot --path godot -s test/story_smoke.gd [-- --shot-dir=D]
##
## 1. The hub's Historia "Jugar" opens the campaign (60020 → 60021): three
##    chapters, the won challenges ticked, the next one picked, the rest
##    locked; the detail says what the first win is worth.
## 2. A won challenge reads "Repetir" and says it is practice.
## 3. "Jugar" on the next one plays its lesson / intro, then the fight
##    (26330 → 8000); surrendered at once (8151 → 8300). The server logs it
##    as a story fight (story=true) — check /tmp/claude-1000/arena-server.log.
## 4. The Team panel's Historia tab offers the campaign, not "Buscar combate".
## Costs `test`'s Historia starter one lost fight (XP, fatigue; TotalXP 0
## means no wound or death roll can land).

const Story := preload("res://src/gamedata/story.gd")


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.6).timeout
	_close_all()
	var lobby = _main._lobby_screen
	_seen.erase(60021)
	lobby._cards.story.play.pressed.emit()
	await _wait(func(): return _seen.has(60021) and _main._gui.is_open("storyDialog"), 4.0)
	await create_timer(0.5).timeout
	var p = _main._gui.dialogs.get("storyDialog")
	if p == null:
		_record(60021, "open", false, "Historia did not open the campaign")
		return
	await _shot("story")
	var won: Array = _main._story_won
	var next := Story.next_challenge(won)
	var rows := 0
	var locked := 0
	var total := 0
	for ch in Story.CHAPTERS:
		total += ch.challenges.size()
		for c in ch.challenges:
			var b: Button = p.find_child("Story%d" % int(c), true, false)
			if b != null:
				rows += 1
				if b.disabled:
					locked += 1
	var pick: Label = p.find_child("StoryPick", true, false)
	var stake: Label = p.find_child("Stake", true, false)
	_record(60021, "campaign", rows == total and pick != null and pick.text == NpcDialogs_name(next)
		and stake.text == i18n.t("story.stake_first") and locked > 0,
		"won %s, %d/%d rows (%d locked), next '%s'" % [str(won), rows, total, locked, pick.text if pick != null else "—"])
	# 2. a won one, if any
	if not won.is_empty():
		p.find_child("Story%d" % int(won[0]), true, false).pressed.emit()
		await create_timer(0.4).timeout
		var play: Button = p.find_child("StoryPlay", true, false)
		stake = p.find_child("Stake", true, false)
		_record(60021, "replay", play.text == i18n.t("story.replay") and stake.text == i18n.t("story.stake_replay"),
			"won %d → '%s' / '%s'" % [int(won[0]), play.text, stake.text.left(30)])
		p.find_child("Story%d" % next, true, false).pressed.emit()
		await create_timer(0.4).timeout
	# 3. play the next one
	_seen.erase(8000)
	p.find_child("StoryPlay", true, false).pressed.emit()
	# lesson / intro pages first
	for i in 30:
		await create_timer(0.3).timeout
		if _seen.has(8000):
			break
		var talk = _main._gui.dialogs.get("npcTalkDialog")
		if talk != null and _main._gui.is_open("npcTalkDialog"):
			var buttons: Array = talk.find_children("Choice*", "Button", true, false)
			if not buttons.is_empty():
				buttons[buttons.size() - 1].pressed.emit()   # the primary (Siguiente / Aceptar) is last
	var started: bool = await _wait(func(): return _seen.has(8000), 6.0)
	_record(8000, "fight", started, "Jugar on %d → 26330 → 8000" % next)
	if started:
		await create_timer(2.0).timeout
		_sess.send(8151, PackedByteArray(), 3)
		await _wait(func(): return _seen.has(8300), 8.0)
		await create_timer(1.0).timeout
		_close_all()
	# 4. the Team panel's Historia tab
	_main._gui.gui.model.set_value("gamePreferences", 0, "lastSelectedGameModeId")
	_main._gui.open("teamManagementDialog")
	await create_timer(0.6).timeout
	var team = _main._gui.dialogs.get("teamManagementDialog")
	var open_story: Button = team.find_child("OpenStory", true, false) if team != null else null
	var finds: Array = []
	if team != null:
		_collect_buttons(team, i18n.t("team.find_fight"), finds)
	_record(0, "team tab", open_story != null and finds.is_empty(),
		"Historia tab: campaign button %s, Buscar combate %d" % [str(open_story != null), finds.size()])
	_close_all()
	i18n.set_locale(lang_before)


func NpcDialogs_name(id: int) -> String:
	return load("res://src/gamedata/npcdialogs.gd").challenge_name(id)
