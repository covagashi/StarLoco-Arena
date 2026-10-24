extends "res://src/ui/card_panel.gd"   # lobby_panel + the card tile helpers
## The native coach equipment (S18; tiles since S22). Opened from Inventario
## → "Equipo del coach". The twelve wearable slots on top as tiles with the
## card each holds; pick one and your cards for that slot show below — a
## click puts one on, "Quitar" takes the slot's card off. Changes are a draft
## until "Llevar puesto" sends the layout (5201); set bonuses (resurrection,
## XP, morale…) count what the coach wears.
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
	var slots: Array = d.get("slots", [])
	var pick := int(draft.get("slot", int(slots[0].slot) if not slots.is_empty() else 0))
	label(body, I18n.t("ce.worn"), 20)
	var top := HFlowContainer.new()
	top.name = "Slots"
	top.add_theme_constant_override("h_separation", 8)
	top.add_theme_constant_override("v_separation", 8)
	body.add_child(top)
	for sl in slots:
		var has := int(sl.card) != 0
		var b := _tile(top, {"id": int(sl.card), "name": str(sl.name) if has else I18n.t("ce.empty")},
			int(sl.slot) == pick, "", str(sl.label))
		b.name = "Slot%d" % int(sl.slot)
		var slot_id := int(sl.slot)
		b.pressed.connect(func(): draft["slot"] = slot_id; schedule_refresh())
	var worn: Dictionary = {}
	for sl in slots:
		if int(sl.slot) == pick:
			worn = sl
	var line := row(body)
	label(line, I18n.t("ce.slot_x", {"slot": str(worn.get("label", "")),
		"name": str(worn.get("name", "")) if int(worn.get("card", 0)) != 0 else I18n.t("ce.empty")}), 18)
	var take := button(line, I18n.t("ce.take_tip"), func(): send("nativeEquipTake", [pick]),
		int(worn.get("card", 0)) != 0)
	take.name = "Take"
	var owned: Array = d.get("owned", []).filter(func(c): return int(c.get("slot", -1)) == pick)
	var grid := HFlowContainer.new()
	grid.name = "Owned"
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	if owned.is_empty():
		_muted(grid, I18n.t("ce.none_for_slot"))
	for c in owned:
		var t := _tile(grid, c, int(c.id) == int(worn.get("card", 0)), "×%d" % int(c.get("qty", 1)))
		t.name = "Own%d" % int(c.id)
		var cid := int(c.id)
		t.pressed.connect(func(): send("nativeEquipPut", [cid]))
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
