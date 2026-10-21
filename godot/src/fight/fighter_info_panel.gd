extends "res://src/ui/lobby_panel.gd"
## The fighter sheet (S07): the retail fighterInformations window, which a
## click on a fighter's timeline entry toggles (avu_0, 18012). Who it is
## (breed, side), life / AP / MP as they stand, the states on it, the cards
## it wears and its spells. Unlike the lobby panels it is not modal: no
## shade, the map keeps taking clicks around it, and it sits beside the
## column of the card that opened it (`side`) instead of over the arena's
## centre. fight_view rebuilds the
## `fighterInfo` model whenever its HUD refreshes, so the numbers follow the
## fight; it closes when the fighter dies, as in the retail.
##
## Reads `fighterInfo` {fid, name, breed, team, ours, hp, hp_max, ap, mp,
## buffs[], cards[], spells[], summon}. Read-only: no events.

const SIZE := Vector2(420, 540)
const COLUMN := 96.0   # clear of the timeline cards along each edge
const TOP := 64.0      # under the corner buttons

## "left" (your side's column) or "right"
var side := "left"


func _ready() -> void:
	panel_name = "fighterInformations"
	frame_size = SIZE
	super._ready()
	_shade.hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _layout() -> void:
	super._layout()
	var vp := get_viewport_rect().size
	var w := frame_size.x * frame.scale.x
	frame.position = Vector2(COLUMN if side == "left" else vp.x - COLUMN - w,
		minf(TOP, maxf(0.0, vp.y - frame_size.y * frame.scale.y)))


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "fighterInfo":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	clear_body()
	var f: Dictionary = data("fighterInfo", {})
	title.text = str(f.get("name", ""))
	var who: String = I18n.t("fi.summon") if f.get("summon", false) \
		else str(f.get("breed", ""))
	label(body, "%s · %s" % [who, I18n.t("fi.ours") if f.get("ours", false)
		else I18n.t("fi.theirs")], 18).name = "Who"
	var stats := row(body)
	stats.name = "Stats"
	for s in [["fi.hp", "%d / %d" % [int(f.get("hp", 0)), int(f.get("hp_max", 0))]],
			["fi.ap", str(int(f.get("ap", 0)))], ["fi.mp", str(int(f.get("mp", 0)))]]:
		var box := column(stats)
		label(box, I18n.t(s[0]), 14)
		label(box, s[1], 26).name = s[0].trim_prefix("fi.").to_upper()
	_section("fi.states", f.get("buffs", []), "States")
	if not f.get("summon", false):
		_section("fi.cards", f.get("cards", []), "Cards")
		_section("fi.spells", f.get("spells", []), "Spells")


func _section(key: String, items: Array, node_name: String) -> void:
	label(body, I18n.t(key), 20)
	var text := ", ".join(items) if not items.is_empty() else I18n.t("fi.none")
	label(body, text, 16).name = node_name
