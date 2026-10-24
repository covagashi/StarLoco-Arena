extends "res://src/ui/lobby_panel.gd"
## The native card trade between two coaches (S18): replaces the retail XML
## exchangeDialog and the debug ElementDlg pane. Your tradable cards on the
## left; what you offer and what they offer side by side, each with its
## value and whether that side is ready. Any change to either offer
## un-readies both (the server does the same), so neither side can swap a
## card in after the other agreed. Closing the window cancels the trade.
##
## Reads `exchangeNative` (main.gd _push_exchange_model) and answers with
## nativeExAdd / nativeExRemove / nativeExReady / nativeExCancel.


func _ready() -> void:
	panel_name = "exchangeDialog"
	super._ready()
	# the header's Cerrar (and Esc) cancel the trade, like retail's close
	closed.connect(func(): send("nativeExCancel"))


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "exchangeNative":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var d: Dictionary = data("exchangeNative", {})
	var other := str(d.get("other", "?"))
	title.text = I18n.t("ex.title", {"name": other})
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# --- your cards ---
	var left := column(split)
	label(left, I18n.t("ex.yours"), 20)
	var owned: Array = d.get("owned", [])
	var t1 := table(left, [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("inv.col_value")],
		["name", "qty", "value"], owned, func(item): draft["add"] = int(item.id))
	t1.name = "Owned"
	var add_id := int(draft.get("add", -1))
	if not owned.any(func(c): return int(c.id) == add_id):
		add_id = -1
	button(left, I18n.t("ex.offer"), func(): send("nativeExAdd", [add_id]),
		add_id > 0 and bool(d.get("accepted", false)) and not bool(d.get("full", false))).name = "Add"
	if bool(d.get("full", false)):
		label(left, I18n.t("ex.full"))
	# --- the two offers ---
	var right := column(split)
	_offer(right, I18n.t("ex.you_give"), d.get("mine", []), int(d.get("myValue", 0)),
		bool(d.get("myReady", false)), "Mine", true)
	_offer(right, I18n.t("ex.they_give", {"name": other}), d.get("theirs", []), int(d.get("theirValue", 0)),
		bool(d.get("theirReady", false)), "Theirs", false)
	var status := str(d.get("status", ""))
	if status != "":
		var line := label(right, status)
		line.name = "Status"
		line.add_theme_color_override("font_color", UiStyle.MUTED)
	pinned_actions.show()
	var hint := label(pinned_actions, I18n.t("ex.hint") if bool(d.get("accepted", false)) else I18n.t("ex.waiting", {"name": other}))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cancel := button(pinned_actions, I18n.t("ex.cancel"), func(): closed.emit())
	cancel.name = "Cancel"
	var my_ready := bool(d.get("myReady", false))
	var ready := button(pinned_actions, I18n.t("ex.ready_done") if my_ready else I18n.t("ex.ready"),
		func(): send("nativeExReady"), bool(d.get("accepted", false)) and not my_ready)
	ready.name = "Ready"
	ready.custom_minimum_size.x = 170
	UiStyle.primary(ready, 20)


func _offer(parent: Node, heading: String, cards: Array, value: int, ready: bool, key: String, mine: bool) -> void:
	var head := row(parent)
	label(head, heading, 20)
	var flag := UiStyle.caption(I18n.t("ex.is_ready") if ready else I18n.t("ex.not_ready"))
	flag.name = key + "Ready"
	head.add_child(flag)
	var t := table(parent, [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("inv.col_value")],
		["name", "qty", "value"], cards, (func(item): draft["remove"] = int(item.id)) if mine else Callable())
	t.name = key
	t.custom_minimum_size.y = 120
	var bar := row(parent)
	if mine:
		var rm_id := int(draft.get("remove", -1))
		if not cards.any(func(c): return int(c.id) == rm_id):
			rm_id = -1
		button(bar, I18n.t("ex.remove"), func(): send("nativeExRemove", [rm_id]), rm_id > 0).name = "Remove"
	label(bar, I18n.t("ex.value", {"n": value})).name = key + "Value"
