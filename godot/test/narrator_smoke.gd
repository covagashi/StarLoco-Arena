extends "res://test/world_smoke.gd"

## S26: Demon I as chapter 2's narrator, live. In Spanish.
##
##   godot --path godot -s test/narrator_smoke.gd
##
## 1. "Jugar" on Imix (34) the first time: Demon I's three lines before it.
##    Closed with ✕, so no fight starts.
## 2. A 60021 that newly shows Chikchan (33) won: his congratulation (254),
##    and criterion 218 ("spoke to Demon I") reported.
## 3. The same list again: no second talk.
## 4. Back in the lobby after a Historia fight, the list is asked again
##    (60020 → 60021), which is what plays 2 for real.
## 5. Demon I is no longer a service in the City panel.
## Sets criterion 218 on `test`.

const Story := preload("res://src/gamedata/story.gd")


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.6).timeout
	_close_all()
	var speaker: String = load("res://src/gamedata/npcdialogs.gd").npc_name(Story.NARRATOR)
	# 1. the intro
	var won_before: Array = _main._story_won.duplicate()
	_main._story_won.erase(34)
	_main._story_intro_seen.erase(34)
	_main._story_play(34)
	await create_timer(0.5).timeout
	var npc: Dictionary = _main._npc
	_record(34, "intro", _main._gui.is_open("npcTalkDialog") and str(npc.get("speaker", "")) == speaker
		and npc.get("pages", []) == [251, 252, 253],
		"'%s' pages %s" % [str(npc.get("speaker", "")), str(npc.get("pages", []))])
	_main._talk_close()
	await create_timer(0.3).timeout
	_main._story_won = won_before
	# 2. the closing line
	State.criteria.erase(Story.TALK_AFTER_CRITERION)
	_main._story_loaded = true
	var was: Array = _main._story_won.duplicate()
	was.erase(33)
	_main._story_won = was + [33]
	_main._story_after_talk(was)
	await create_timer(0.5).timeout
	npc = _main._npc
	_record(33, "outro", _main._gui.is_open("npcTalkDialog") and npc.get("pages", []) == [254]
		and int(State.criteria.get(Story.TALK_AFTER_CRITERION, 0)) == 1,
		"pages %s, criterion 218 = %s" % [str(npc.get("pages", [])),
			str(State.criteria.get(Story.TALK_AFTER_CRITERION, 0))])
	_main._talk_close()
	await create_timer(0.3).timeout
	# 3. no repeat
	_main._npc = {}
	_main._story_after_talk(_main._story_won.duplicate())
	await create_timer(0.3).timeout
	_record(33, "once", not _main._gui.is_open("npcTalkDialog") and _main._npc.is_empty(),
		"talk open: %s" % str(_main._gui.is_open("npcTalkDialog")))
	_main._story_won = won_before
	# 4. back from a Historia fight
	_seen.erase(60021)
	_main._story_launched = 34
	_main._show_lobby_screen()
	var asked: bool = await _wait(func(): return _seen.has(60021), 4.0)
	_record(60021, "refresh", asked and _main._story_launched == 0,
		"lobby after a Historia fight asks 60020: %s" % str(asked))
	# 5. not a City service
	var services := 0
	_main._push_city_model()
	for g in (_main._gui.gui.model.get_value("city") as Dictionary).get("groups", []):
		for sv in g.get("services", []):
			if int(sv.get("kind", -1)) == 9:
				services += 1
	_record(9, "city", services == 0, "Demon I buttons in the City panel: %d" % services)
	_close_all()
	i18n.set_locale(lang_before)
