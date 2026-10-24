extends "res://src/ui/lobby_panel.gd"
## The native firework launcher (S18, tanda 2): replaces the retail XML
## fireworkDialog. Your firework cards on the left; the show on the right, up
## to eight in a row, each with the wait before it. "Lanzar" closes the window
## and the show plays on the lobby sky (firework_fx.gd), for everyone the
## server sends it to.
##
## Reads `fireworkNative` (main.gd _push_firework_model) and answers with
## nativeFwAdd / nativeFwRemove / nativeFwDelay / nativeFwLaunch.

const SIZE := Vector2(980, 560)
const DELAYS := [0, 5, 10, 20]   # deciseconds, the retail field's unit


func _ready() -> void:
	panel_name = "fireworkDialog"
	frame_size = SIZE
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "fireworkNative":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	title.text = I18n.t("fw.title")
	var d: Dictionary = data("fireworkNative", {})
	var slots: Array = d.get("slots", [])
	var full: bool = slots.size() >= int(d.get("max", 8))
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := column(split)
	label(left, I18n.t("fw.yours"), 20)
	var owned: Array = d.get("owned", [])
	if owned.is_empty():
		label(left, I18n.t("fw.none"))
	for c in owned:
		var b := button(left, I18n.t("fw.card", {"name": c.name, "kind": I18n.t("fw.kind%d" % clampi(int(c.kind), 0, 2)), "qty": int(c.qty)}),
			func(): send("nativeFwAdd", [int(c.id)]), int(c.qty) > 0 and not full)
		b.name = "Add%d" % int(c.id)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var right := column(split)
	label(right, I18n.t("fw.show", {"n": slots.size(), "max": int(d.get("max", 8))}), 20)
	if slots.is_empty():
		label(right, I18n.t("fw.empty"))
	var delay_names: Array = DELAYS.map(func(ds): return I18n.t("fw.now") if ds == 0 else I18n.t("fw.wait", {"s": "%.1f" % (ds / 10.0)}))
	for n in slots.size():
		var sl: Dictionary = slots[n]
		var line := row(right)
		label(line, "%d. %s" % [n + 1, sl.name])
		var pick := maxi(0, DELAYS.find(int(sl.delay)))
		choices(line, delay_names, pick, func(i): send("nativeFwDelay", [int(sl.i), DELAYS[i]])).name = "Delay%d" % n
		button(line, I18n.t("fw.remove"), func(): send("nativeFwRemove", [int(sl.i)])).name = "Remove%d" % n
	pinned_actions.show()
	var hint := label(pinned_actions, I18n.t("fw.hint"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var go := button(pinned_actions, I18n.t("fw.launch"), func(): send("nativeFwLaunch"), not slots.is_empty())
	go.name = "Launch"
	go.custom_minimum_size.x = 170
	UiStyle.primary(go, 20)
