extends "res://src/ui/lobby_panel.gd"
## The native coach equipment (S18): replaces the debug EquipDlg, which only
## the hidden debug row could open. Opened from Inventario → "Equipo del
## coach". The twelve wearable slots on the left (hat, tattoo, hair, …) with
## what each holds; your wearable cards on the right, each naming its slot.
## Changes are a draft until "Llevar puesto" sends the layout (5201); set
## bonuses (resurrection, XP, morale…) count what the coach wears.
##
## Reads `coachEquip` {slots:[{slot, label, card, name}], owned:[{id, name,
## qty, slot, slotName}], dirty}; answers nativeEquipPut [card] /
## nativeEquipTake [slot] / nativeEquipReset / nativeEquipWear.


func _ready() -> void:
	panel_name = "coachEquipDialog"
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "coachEquip":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	title.text = I18n.t("ce.title")
	var d: Dictionary = data("coachEquip", {})
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := column(split)
	label(left, I18n.t("ce.worn"), 20)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(grid)
	for sl in d.get("slots", []):
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
		cell.add_child(UiStyle.caption(str(sl.label)))
		var has := int(sl.card) != 0
		var b := button(cell, str(sl.name) if has else I18n.t("ce.empty"),
			func(): send("nativeEquipTake", [int(sl.slot)]), has)
		b.name = "Slot%d" % int(sl.slot)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = I18n.t("ce.take_tip") if has else ""
	var right := column(split)
	label(right, I18n.t("ce.yours"), 20)
	var owned: Array = d.get("owned", [])
	var t := table(right, [I18n.t("inv.col_card"), I18n.t("ce.col_slot"), I18n.t("inv.col_qty")],
		["name", "slotName", "qty"], owned, func(item): draft["put"] = int(item.id))
	t.name = "Owned"
	var put_id := int(draft.get("put", -1))
	if not owned.any(func(c): return int(c.id) == put_id):
		put_id = -1
	button(right, I18n.t("ce.put"), func(): send("nativeEquipPut", [put_id]), put_id > 0).name = "Put"
	pinned_actions.show()
	var hint := label(pinned_actions, I18n.t("ce.hint_dirty") if bool(d.get("dirty", false)) else I18n.t("ce.hint"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button(pinned_actions, I18n.t("ce.reset"), func(): send("nativeEquipReset"), bool(d.get("dirty", false))).name = "Reset"
	var wear := button(pinned_actions, I18n.t("ce.wear"), func(): send("nativeEquipWear"), bool(d.get("dirty", false)))
	wear.name = "Wear"
	wear.custom_minimum_size.x = 190
	UiStyle.primary(wear, 20)
