extends "res://test/world_smoke.gd"

## S47 (owner point 4): the lobby's guide, live. In Spanish.
##
##   godot --path godot -s test/guide_smoke.gd [-- --as=NAME] [--shot-dir=D]
##
## 1. The card shows the first "Primeros pasos" step not done (the same one
##    Ayuda marks ▶), "paso N de 6", and a ring on that step's control.
## 2. IR opens that step's screen (Servicios / Reclutar / Historia).
## 3. The cross hides the card and it stays hidden (gamePreferences);
##    Ayuda → Empezar offers to show it again, and that brings it back.
## A login nobody has used starts at step 1 (talk to Nilo, Servicios).

const Scenarios2 := preload("res://src/gamedata/scenarios.gd")
const NpcDialogs2 := preload("res://src/gamedata/npcdialogs.gd")
const State3 := preload("res://src/state.gd")


func _audit() -> void:
	var i18n = root.get_node("I18n")
	i18n.set_locale("es")
	_close_all()
	# the intro of a new coach plays first: read it away
	for i in 40:
		if not _main._gui.is_open("npcTalkDialog"):
			break
		_main._talk_choice(0)
		await create_timer(0.1).timeout
	await create_timer(1.0).timeout
	var lobby = _main._lobby_screen
	var card: Control = lobby.find_child("Guide", true, false)
	var steps: Array = Scenarios2.TUTORIAL_STEPS
	var want := -1
	for i in steps.size():
		if not NpcDialogs2.achievement_done(int(steps[i]), State3.criteria, State3.inventory):
			want = i
			break
	var tag: Label = lobby.find_child("GuideTag", true, false)
	var shown := card != null and card.visible
	_record(0, "card", (want < 0 and not shown) or (shown and tag.text.contains(str(want + 1))),
		"step %d: '%s'" % [want + 1, tag.text if tag else "—"])
	await _shot("guide-card")
	if want < 0 or not shown:
		return
	var target := String(lobby._guide_target)
	_record(0, "ring", lobby._guide_target_node() != null, "on %s" % target)
	# IR
	var expect: String = {275: "cityDialog", 276: "fighterCreationDialog"}.get(int(steps[want]), "storyDialog")
	(lobby.find_child("GuideGo", true, false) as Button).pressed.emit()
	await _wait(func(): return _main._gui.is_open(expect), 3.0)
	await create_timer(0.8).timeout
	_record(0, "go", _main._gui.is_open(expect), "IR → %s" % expect)
	await _shot("guide-go")
	_close_all()
	await create_timer(0.4).timeout
	# hide, and back from Ayuda
	(lobby.find_child("GuideHide", true, false) as Button).pressed.emit()
	await create_timer(0.5).timeout
	var hidden_pref = _main._gui.model.get_value("gamePreferences", "guideHidden")
	_record(0, "hide", not card.visible and hidden_pref == true, "card hidden, pref %s" % str(hidden_pref))
	_main._gui.open("tooltipDialog")
	await create_timer(0.6).timeout
	var help = _main._gui.dialogs.get("tooltipDialog")
	var show: Button = help.find_child("GuideShow", true, false) if help != null else null
	_record(0, "help offers it", show != null, "Ayuda → Empezar: '%s'" % (show.text if show else "—"))
	if show != null:
		show.pressed.emit()
		await create_timer(0.5).timeout
	_close_all()
	await create_timer(0.4).timeout
	_record(0, "back", card.visible, "card shown again")
