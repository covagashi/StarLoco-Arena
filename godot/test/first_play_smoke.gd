extends "res://test/world_smoke.gd"

## S53: the tutorial as a new player plays it (owner, 2026-11-25: boss →
## recruit → the dummy fight → done; everything else dark and dead).
##
##   godot/tools/seeded_smoke.sh first_play_smoke "--as=novatoNNN [--lang=en] [--shot-dir=D]"
##
## 1. After the boss's intro the lobby is dark but for the Historia tile:
##    the recruit text, a click outside the hole is eaten, one inside not.
## 2. The tile opens Reclutar in tutorial mode: the note says what the
##    fighter is for and what the two coins are, Élite is shut.
## 3. Recruiting comes back to the lobby (not Equipo: the tutorial goes on)
##    and the tile now says the first fight.
## 4. The tile starts Nilo's practice (challenge 46) at once; surrendering it
##    ends it, and back in the lobby a centred bubble says it is done.
## 5. Its button ends the tutorial for good (gamePreferences.tutorialDone).
## 6. Ayuda → «Repetir el tutorial» brings it back, and «Saltar tutorial» →
##    «Sí, saltar» ends it as skipped.
## 7. Out of the tutorial, recruiting lands in Equipo (A12).

var _lang := "es"


func _audit() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
	var i18n = root.get_node("I18n")
	i18n.set_locale(_lang)
	# the boss's intro first
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 5.0)
	for i in 40:
		if not _main._gui.is_open("npcTalkDialog"):
			break
		_main._talk_choice(0)
		await create_timer(0.1).timeout
	await create_timer(1.0).timeout
	var lobby = _main._lobby_screen
	# 1. recruit
	if not await _spot_says(1, lobby, "tutorial.recruit"):
		return
	var spot: Control = lobby.find_child("Spotlight", true, false)
	var tile: Control = lobby.find_child("Play_story", true, false)
	var hole: Rect2 = spot.hole()
	var tile_r := tile.get_global_rect()
	tile_r.position -= spot.get_global_rect().position
	_record(1, "hole", hole.encloses(tile_r), "hole %s round the tile %s" % [hole, tile_r])
	_record(1, "blocks", spot._has_point(Vector2(8, 8)) and spot._has_point(spot.size - Vector2(8, 8))
		and not spot._has_point(hole.get_center()),
		"a click outside is eaten, inside it reaches the tile")
	await _shot("1-recruit")
	# 2. Reclutar in tutorial mode
	(tile as Button).pressed.emit()
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 4.0)
	await create_timer(0.8).timeout
	var rec = _main._gui.dialogs.get("fighterCreationDialog")
	var note: Control = rec.find_child("TutorialNote", true, false) if rec != null else null
	var elite: Button = rec.find_child("ModeElite", true, false) if rec != null else null
	var ef = _main._gui.model.get_value("teamManagement", "editableFighter")
	_record(2, "recruit screen", note != null and note.visible and elite != null and elite.disabled
		and int(ef.get("version", 0)) == 2,
		"note %s, Élite shut %s, Historia %s" % [note != null and note.visible,
			elite != null and elite.disabled, int(ef.get("version", 0)) == 2])
	await _shot("2-recruit-screen")
	var name_edit: LineEdit = rec.find_child("FighterName", true, false)
	name_edit.text = "Primero"
	name_edit.text_changed.emit("Primero")
	(rec.find_child("Recruit", true, false) as Button).pressed.emit()
	# 3. back in the lobby, the fight next
	await _wait(func(): return not _main._gui.is_open("fighterCreationDialog") and not State.roster.is_empty(), 8.0)
	await create_timer(1.0).timeout
	_record(3, "recruited", not State.roster.is_empty() and not _main._gui.is_open("teamManagementDialog"),
		"%d fighters; the lobby, not Equipo" % State.roster.size())
	if not await _spot_says(3, lobby, "tutorial.fight"):
		return
	await _shot("3-fight")
	# 4. the practice at once, then done
	_seen.clear()
	(tile as Button).pressed.emit()
	if not await _wait(func(): return _seen.has(8000), 10.0):
		_record(4, "fight", false, "no 8000")
		return
	_record(4, "fight", not _main_open("storyDialog"), "the tile started the practice, no Historia panel")
	await _wait(func(): return current_scene != null and current_scene.has_signal("turn_began"), 8.0)
	# the game changes scene for the fight: free this harness's lobby as the
	# game does, so the main that comes back is the only one
	_old_main = _main
	if _sess.message.is_connected(_main._on_message):
		_sess.message.disconnect(_main._on_message)
	_main.queue_free()
	await create_timer(3.0).timeout
	await _shot("4-in-fight")
	_sess.send(8151, PackedByteArray(), 3)   # surrender
	await _wait(func(): return _seen.has(8300), 10.0)
	var fv = current_scene
	await create_timer(1.0).timeout
	if is_instance_valid(fv) and fv.has_method("_end_fight_ack"):
		fv._end_fight_ack()
	if not await _wait(_lobby_back, 20.0):
		_record(4, "back", false, "no lobby after the fight")
		return
	_main = current_scene
	lobby = _main._lobby_screen
	await create_timer(2.0).timeout
	if not await _spot_says(4, lobby, "tutorial.done"):
		return
	spot = lobby.find_child("Spotlight", true, false)
	_record(4, "centred", not spot.hole().has_area(), "no hole: the bubble in the middle")
	await _shot("4-done")
	# 5. its button ends it
	(spot.find_child("BubbleButton", true, false) as Button).pressed.emit()
	await create_timer(0.6).timeout
	_record(5, "ended", not spot.active() and _pref("tutorialDone") == true,
		"spotlight off, tutorialDone %s" % _pref("tutorialDone"))
	# 6. again from Ayuda, then skipped
	_main._on_native_lobby_action("nativeGuideShow", [], null, -1)
	await create_timer(0.8).timeout
	if await _spot_says(6, lobby, "tutorial.fight"):
		(spot.find_child("Skip", true, false) as Button).pressed.emit()
		await create_timer(0.3).timeout
		await _shot("6-skip-ask")
		(spot.find_child("SkipYes", true, false) as Button).pressed.emit()
		await create_timer(0.6).timeout
		_record(6, "skipped", not spot.active() and _pref("tutorialSkipped") == true,
			"spotlight off, tutorialSkipped %s" % _pref("tutorialSkipped"))
	# 7. out of the tutorial, recruiting lands in Equipo
	_main._on_new_fighter_dialog([], null, false)
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 4.0)
	await create_timer(0.6).timeout
	rec = _main._gui.dialogs.get("fighterCreationDialog")
	note = rec.find_child("TutorialNote", true, false)
	_record(7, "no note", not note.visible, "no tutorial note out of the tutorial")
	name_edit = rec.find_child("FighterName", true, false)
	name_edit.text = "Segundo"
	name_edit.text_changed.emit("Segundo")
	var before := State.roster.size()
	(rec.find_child("Recruit", true, false) as Button).pressed.emit()
	await _wait(func(): return State.roster.size() > before and not _main._gui.is_open("fighterCreationDialog"), 8.0)
	await create_timer(0.8).timeout
	_record(7, "to Equipo", _main._gui.is_open("teamManagementDialog"), "after recruiting: Equipo")
	await _shot("7-equipo")


var _old_main: Node = null


## A new main (the fight's end changes scene) with its lobby up.
func _lobby_back() -> bool:
	return current_scene != null and current_scene != _old_main \
		and current_scene.get("_lobby_screen") != null and is_instance_valid(current_scene._lobby_screen)


func _main_open(n: String) -> bool:
	return is_instance_valid(_main) and _main._gui.is_open(n)


func _pref(k: String) -> Variant:
	var p = _main._gui.model.get_value("gamePreferences")
	return p.get(k) if p is Dictionary else null


## The spotlight is on and says `key`'s text.
func _spot_says(kind: int, lobby, key: String) -> bool:
	var want: String = root.get_node("I18n").t(key)
	await _wait(func(): return lobby.tutorial_state().get("text", "") == want, 6.0)
	var st: Dictionary = lobby.tutorial_state()
	var ok: bool = st.get("text", "") == want
	_record(kind, key, ok, "'%s'" % str(st.get("text", "—")).left(60))
	return ok
