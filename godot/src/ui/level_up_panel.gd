extends "res://src/ui/lobby_panel.gd"
## The coach's level-up notice (S07): the retail coachLevelUpDialog, which
## the client pops when a fight's standing crosses a level (WE: aet_0.nJ of
## the old and the new standing). Your coach celebrating, the new level in
## big figures and the retail line "¡Has subido un nivel!". The retail doll
## dances; ours jumps (S54: its picture, CoachPortrait, whole, dressed,
## hopping).
##
## Reads `levelUp` {level} and `localCoach` (look). Read-only: no events.

const SIZE := Vector2(560, 470)
const Portrait := preload("res://src/anims/coach_portrait.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")


func _ready() -> void:
	panel_name = "coachLevelUpDialog"
	frame_size = SIZE
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "levelUp":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	title.text = I18n.t("lvl.title")
	var split := row(body)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(200, 240)
	split.add_child(stage)
	var coach: Dictionary = data("localCoach", {})
	var spr := Portrait.new()
	spr.name = "Coach"
	spr.position = Vector2(100, 225)
	stage.add_child(spr)
	if spr.show_coach(Fighter3D.coach_key(int(coach.get("sex", 0))), "whole"):
		spr.scale = Vector2.ONE * (134.0 / float(spr.index.px))   # as tall as the 3D one was
	var t := Fighter3D.coach_tints(int(coach.get("skin", 0)), int(coach.get("hair", 0)))
	spr.tint(t.skin, t.hair)
	spr.wear_coach_cards(coach.get("worn", []))
	spr.set_hair_fx(int(coach.get("hairFx", 0)))
	var tw := spr.create_tween().set_loops()
	tw.tween_callback(spr.hop.bind(30.0))
	tw.tween_interval(0.9)
	var col := column(split)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var lvl := label(col, str(int(data("levelUp.level", 1))), 96)
	lvl.name = "Level"
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line := label(col, I18n.t("lvl.text"), 22)
	line.name = "Line"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pinned_actions.show()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pinned_actions.add_child(spacer)
	var go := button(pinned_actions, I18n.t("fight.result.continue"), func(): closed.emit())
	go.name = "Continue"
	go.custom_minimum_size.x = 150
	UiStyle.primary(go, 20)
	go.grab_focus.call_deferred()
