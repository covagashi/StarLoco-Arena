extends "res://src/ui/lobby_panel.gd"
## The coach's level-up notice (S07): the retail coachLevelUpDialog, which
## the client pops when a fight's standing crosses a level (WE: aet_0.nJ of
## the old and the new standing). Your coach celebrating, the new level in
## big figures and the retail line "¡Has subido un nivel!". The retail doll
## dances (AnimEmote-Danse); coach sets export no emotes, so it jumps.
##
## Reads `levelUp` {level} and `localCoach` (look). Read-only: no events.

const SIZE := Vector2(560, 470)
const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const Direction8 := preload("res://src/util/direction8.gd")


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
	var spr := AnmSprite.new()
	OneBit.doll(spr)
	spr.foot_pivot = true
	spr.position = Vector2(100, 225)
	spr.scale = Vector2(2.2, 2.2)
	spr.tints = Palettes.coach_tints(int(coach.get("skin", 0)), int(coach.get("hair", 0)))
	stage.add_child(spr)
	var lib := "anims/coach_700%d" % int(coach.get("sex", 0))
	if not spr.load_action(lib, "1_AnimSaut"):
		Direction8.load_idle_any(spr, lib)
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
	OneBit.primary(go, 20)
	go.grab_focus.call_deferred()
