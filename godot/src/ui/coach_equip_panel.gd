extends "res://src/ui/hero_panel.gd"   # a screen of its own, with the card tile helpers
## The coach equipment as a hero screen (S45 mockup, "Equipo del coach";
## tiles since S22, opened from Inventario → "Equipo del coach"): the coach
## on its pedestal wearing the draft (S54: its picture, CoachPortrait, whole,
## front on, so the boots show), the twelve wearable slots as diamonds
## around it with the card each holds; pick one and, on the paper at the
## right, what it wears (with "Quitar") and your cards for that slot — a
## click puts one on. Changes are a draft until "Llevar puesto" sends the
## layout (5201); set bonuses (resurrection, XP, morale…) count what the
## coach wears.
##
## Reads `coachEquip` {slots:[{slot, label, card, name}], owned:[{id, name,
## qty, slot, slotName}], dirty, hairFx, hairOwned:[{id, name}]} and
## `localCoach` (its look); answers nativeEquipPut [card] / nativeEquipTake
## [slot] / nativeEquipReset / nativeEquipWear, and nativeHairFx [id] (S37: a
## hair effect cosmetic it owns, 0 = none; put on at once, not part of the
## draft).

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const HAIR_SLOT := 2   # 5201's 0-based hair slot (main.COACH_SLOT_NAMES)
const R_PED := Rect2(300, 594, 400, 86)
const FOOT := Vector2(500, 632)
const COACH_PX := 352.0   # px per metre: the 1.45 m coach as tall as the 3D one was
## Where the slot diamonds sit (centres), in slot order: six at the left of
## the coach, six at its right.
const SLOT_AT := [Vector2(249, 163), Vector2(203, 255), Vector2(295, 255),
	Vector2(249, 347), Vector2(203, 439), Vector2(295, 439),
	Vector2(705, 170), Vector2(760, 252), Vector2(705, 334),
	Vector2(760, 416), Vector2(705, 498), Vector2(760, 580)]

var _spr
var _slot_buttons := {}    # slot -> diamond Button
var _slot_cards := {}      # slot -> card id the diamond shows
var _built := false
var _look := ""


func _ready() -> void:
	panel_name = "coachEquipDialog"
	super._ready()
	var ped := Control.new()
	ped.size = HREF
	ped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ped.draw.connect(func():
		# style B: a soft shadow and a thin ring under the coach
		ped.draw_set_transform(FOOT + Vector2(0, -4), 0.0, Vector2(1.0, 0.22))
		ped.draw_circle(Vector2.ZERO, 150, Color(UiStyle.B_INK, 0.12))
		ped.draw_arc(Vector2.ZERO, 175, 0, TAU, 64, Color(UiStyle.B_INK, 0.35), 3.0, true)
		ped.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	stage.add_child(ped)
	stage.move_child(ped, pinned_actions.get_index())
	_spr = preload("res://src/anims/coach_portrait.gd").new()
	_spr.position = FOOT
	stage.add_child(_spr)
	stage.move_child(_spr, pinned_actions.get_index())
	_built = true
	refresh()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	var root := model_name.split(".")[0]
	if root == "coachEquip" or root == "localCoach":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null or not _built:
		return
	var focus := remember_focus()
	clear_body()
	title.text = I18n.t("ce.title")
	var d: Dictionary = data("coachEquip", {})
	var slots: Array = d.get("slots", [])
	var pick := int(draft.get("slot", int(slots[0].slot) if not slots.is_empty() else 0))
	_slots(slots, pick)
	_dress(slots)
	var worn: Dictionary = {}
	for sl in slots:
		if int(sl.slot) == pick:
			worn = sl
	sheet_title.text = str(worn.get("label", I18n.t("ce.title")))
	var line := row(body)
	var now := label(line, I18n.t("ce.slot_x", {"slot": str(worn.get("label", "")),
		"name": str(worn.get("name", "")) if int(worn.get("card", 0)) != 0 else I18n.t("ce.empty")}), 16)
	now.add_theme_font_override("font", UiStyle.bold(900))
	var take := button(line, I18n.t("ce.take_tip"), func(): send("nativeEquipTake", [pick]),
		int(worn.get("card", 0)) != 0)
	take.name = "Take"
	if pick == HAIR_SLOT:
		_hair_row(d)
	var owned: Array = d.get("owned", []).filter(func(c): return int(c.get("slot", -1)) == pick)
	body.add_child(UiStyle.caption(I18n.t("ce.yours")))
	var grid := HFlowContainer.new()
	grid.name = "Owned"
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	if owned.is_empty():
		_muted(grid, I18n.t("ce.none_for_slot"))
	for c in owned:
		var t := _tile(grid, c, int(c.id) == int(worn.get("card", 0)), "×%d" % int(c.get("qty", 1)))
		t.name = "Own%d" % int(c.id)
		var cid := int(c.id)
		t.pressed.connect(func(): send("nativeEquipPut", [cid]))
	var dirty := bool(d.get("dirty", false))
	var hint := label(body, I18n.t("ce.hint_dirty") if dirty else I18n.t("ce.hint"), 14)
	hint.name = "Hint"
	hint.add_theme_color_override("font_color", UiStyle.ACCENT_INK if dirty else UiStyle.BROWN)
	hero_button(I18n.t("ce.reset"), func(): send("nativeEquipReset"), dirty).name = "Reset"
	hero_button(I18n.t("ce.wear").to_upper(), func(): send("nativeEquipWear"), dirty, true).name = "Wear"
	restore_focus(focus)


## The twelve diamonds: made once, then each refresh updates what they show.
func _slots(slots: Array, pick: int) -> void:
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var sid := int(sl.slot)
		var b: Button = _slot_buttons.get(sid)
		if b == null:
			b = UiStyle.diamond_button(56, Color.WHITE, _draw_slot.bind(sid), false)
			b.name = "Slot%d" % sid
			b.toggle_mode = true
			b.position = SLOT_AT[mini(i, SLOT_AT.size() - 1)] - b.size / 2.0
			b.pressed.connect(func(): draft["slot"] = sid; schedule_refresh())
			stage.add_child(b)
			# under the diamond: the card it holds, or the slot's name
			var cap := Label.new()
			cap.name = "SlotName"
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.position = Vector2(-30, b.size.y - 12)
			cap.size = Vector2(b.size.x + 60, 18)
			cap.clip_text = true
			cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cap.add_theme_font_override("font", UiStyle.display_font())
			cap.add_theme_font_size_override("font_size", 14)
			cap.add_theme_constant_override("outline_size", 0)
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cap)
			_slot_buttons[sid] = b
		_slot_cards[sid] = int(sl.card)
		var cap: Label = b.get_node("SlotName")
		cap.text = str(sl.name) if int(sl.card) != 0 else str(sl.label)
		cap.add_theme_color_override("font_color", UiStyle.B_INK if int(sl.card) != 0 else UiStyle.B_FAINT)
		b.tooltip_text = "%s: %s" % [str(sl.label), str(sl.name) if int(sl.card) != 0 else I18n.t("ce.empty")]
		b.set_pressed_no_signal(sid == pick)
		b.queue_redraw()


## A slot's face: the card it holds, or a "+" on the dashed empty slot.
func _draw_slot(b: Button, c: Vector2, sid: int) -> void:
	var cid := int(_slot_cards.get(sid, 0))
	if cid == 0:
		b.draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), UiStyle.B_FAINT, 3.0, true)
		b.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), UiStyle.B_FAINT, 3.0, true)
		return
	var art: Texture2D = UiStyle.card_art(cid)
	if art != null:
		var k := 44.0 / maxf(art.get_width(), art.get_height())
		var sz := Vector2(art.get_width(), art.get_height()) * k
		b.draw_texture_rect(art, Rect2(c - sz / 2.0, sz), false)


## The coach on the pedestal, wearing the draft (what "Llevar puesto" sends).
func _dress(slots: Array) -> void:
	var lc: Variant = data("localCoach", {})
	if not (lc is Dictionary):
		return
	var look := "%s/%s/%s" % [lc.get("sex", 0), lc.get("skin", 0), lc.get("hair", 0)]
	if look != _look:
		_look = look
		if _spr.show_coach(Fighter3D.coach_key(int(lc.get("sex", 0))), "whole"):
			_spr.scale = Vector2.ONE * (COACH_PX / float(_spr.index.px))
		var t := Fighter3D.coach_tints(int(lc.get("skin", 0)), int(lc.get("hair", 0)))
		_spr.tint(t.skin, t.hair)
	var worn: Array = []
	for sl in slots:
		if int(sl.card) != 0:
			worn.append({"slot": int(sl.slot), "id": int(sl.card)})
	_spr.wear_coach_cards(worn)
	_spr.set_hair_fx(int(data("coachEquip", {}).get("hairFx", 0)))


## S37: the hair effects the coach owns, on the Pelo slot above its hair
## cards; shown only when it owns one.
func _hair_row(d: Dictionary) -> void:
	var owned: Array = d.get("hairOwned", [])
	if owned.is_empty():
		return
	var on := int(d.get("hairFx", 0))
	body.add_child(UiStyle.caption(I18n.t("ce.hair_fx")))
	_muted(body, I18n.t("ce.hair_fx_tip"))
	var line := HFlowContainer.new()
	line.name = "HairFx"
	line.add_theme_constant_override("h_separation", 8)
	line.add_theme_constant_override("v_separation", 8)
	body.add_child(line)
	for o in [{"id": 0, "name": I18n.t("ce.hair_none")}] + owned:
		var id := int(o.id)
		var b := button(line, str(o.name), func(): send("nativeHairFx", [id]), id != on)
		b.name = "Hair%d" % id
		if id == on:
			UiStyle.raised(b, "pop", 16, 8)
