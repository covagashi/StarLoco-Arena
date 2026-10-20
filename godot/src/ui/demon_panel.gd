extends "res://src/ui/lobby_panel.gd"
## The native demon offering (S18, tanda 2): replaces the retail XML
## demonAffiliationDialog and the demon totem. Opened from Social → Clan by
## the clan leader. A clan with no demon picks one first; the first accepted
## offering affiliates it, and later ones raise its reputation with that
## demon. Your tradable cards on the left, the offering on the right with
## the reputation it is worth (the cards' value), and the clans serving that
## demon below. The offered cards are destroyed, so "Ofrecer" asks first.
##
## Reads `demonNative` (main.gd _push_demon_model) and answers with
## nativeDemonPick / nativeDemonAdd / nativeDemonRemove / nativeDemonOffer.

const ACTIVE_MIN := 5   # store.GuildActiveMinMembers: smaller clans are not ranked


func _ready() -> void:
	panel_name = "demonAffiliationDialog"
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "demonNative":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var d: Dictionary = data("demonNative", {})
	var demon_name := str(d.get("demonName", ""))
	title.text = I18n.t("dm.title", {"demon": demon_name})
	var top := row(body)
	if bool(d.get("canChoose", false)):
		label(top, I18n.t("dm.choose"))
		var demons: Array = d.get("demons", [])
		var pick := 0
		for i in demons.size():
			if int(demons[i].id) == int(d.get("demon", -1)):
				pick = i
		var c := choices(top, demons.map(func(x): return str(x.name)), pick,
			func(i): send("nativeDemonPick", [int(demons[i].id)]))
		c.name = "DemonPick"
	else:
		label(top, I18n.t("dm.serving", {"demon": demon_name}))
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# --- your cards ---
	var left := column(split)
	label(left, I18n.t("dm.yours"), 20)
	var owned: Array = d.get("owned", []).filter(func(c): return int(c.qty) > 0)
	var t1 := table(left, [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("dm.col_rep")],
		["name", "qty", "value"], owned, func(item): draft["add"] = int(item.id))
	t1.name = "Owned"
	var add_id := int(draft.get("add", -1))
	if not owned.any(func(c): return int(c.id) == add_id):
		add_id = -1
	button(left, I18n.t("dm.add"), func(): send("nativeDemonAdd", [add_id]), add_id > 0).name = "Add"
	# --- the offering ---
	var right := column(split)
	label(right, I18n.t("dm.basket"), 20)
	var basket: Array = d.get("basket", [])
	var t2 := table(right, [I18n.t("inv.col_card"), I18n.t("inv.col_qty"), I18n.t("dm.col_rep")],
		["name", "qty", "value"], basket, func(item): draft["remove"] = int(item.id))
	t2.name = "Basket"
	t2.custom_minimum_size.y = 140
	var rm_id := int(draft.get("remove", -1))
	if not basket.any(func(c): return int(c.id) == rm_id):
		rm_id = -1
	var bar := row(right)
	button(bar, I18n.t("dm.remove"), func(): send("nativeDemonRemove", [rm_id]), rm_id > 0).name = "Remove"
	label(bar, I18n.t("dm.total", {"n": int(d.get("total", 0))}), 18).name = "Total"
	var status: Dictionary = d.get("status", {})
	if not status.is_empty():
		var line := label(right, str(status.get("text", "")))
		line.name = "Status"
		if not bool(status.get("ok", true)):
			line.add_theme_color_override("font_color", OneBit.MUTED)
	label(right, I18n.t("dm.ladder", {"demon": demon_name}), 18)
	var ladder: Array = d.get("ladder", [])
	var t3 := table(right, [I18n.t("ladder.col_clan"), I18n.t("ladder.col_rep")], ["name", "points"], ladder)
	t3.name = "Ladder"
	t3.custom_minimum_size.y = 110
	if ladder.is_empty():
		label(right, I18n.t("dm.ladder_empty", {"n": ACTIVE_MIN})).name = "LadderEmpty"
	pinned_actions.show()
	var hint := label(pinned_actions, I18n.t("dm.hint"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var offer := button(pinned_actions, I18n.t("demon.offer"), func():
		confirm_action(I18n.t("dm.confirm", {"n": int(d.get("total", 0)), "demon": demon_name}),
			func(): send("nativeDemonOffer")),
		not basket.is_empty() and not bool(d.get("pending", false)))
	offer.name = "Offer"
	offer.custom_minimum_size.x = 170
	OneBit.primary(offer, 20)
