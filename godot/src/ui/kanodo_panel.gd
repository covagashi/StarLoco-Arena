extends "res://src/ui/lobby_panel.gd"
## The native Kanodo — an evolution fighter's sphere board (S18): replaces
## the debug KanodoDlg, which only the hidden debug row could open. Opened
## from Team → Evolución → a fighter → "Esferas". The board (kanodo_board.gd,
## drawn, ~1800 nodes) on the left, scrolled to where the fighter stands;
## the picked sphere's details and "Comprar" on the right.
##
## Reads `kanodo` {name, xp, total, board, owned, cursor, pick, lines,
## canBuy, status}; answers nativeKanodoPick [node, reachable] /
## nativeKanodoBuy.

const Board := preload("res://src/ui/kanodo_board.gd")
const Kanodo := preload("res://src/gamedata/kanodo.gd")

var _scroll: ScrollContainer
var _board
var _centred := false


func _ready() -> void:
	panel_name = "kanodoDialog"
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "kanodo":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	# keep the board (and its scroll) across refreshes
	if _scroll != null and _scroll.get_parent() != null:
		_scroll.get_parent().remove_child(_scroll)
	clear_body()
	var k: Dictionary = data("kanodo", {})
	title.text = I18n.t("kanodo.title", {"name": str(k.get("name", ""))})
	var split := row(body)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _scroll == null:
		_scroll = ScrollContainer.new()
		_scroll.name = "BoardScroll"
		_board = Board.new()
		_board.name = "Board"
		_board.sphere_clicked.connect(func(n):
			send("nativeKanodoPick", [n, _board._lit.has(int(n.id)) and Kanodo.has_payload(n)]))
		_scroll.add_child(_board)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(620, 420)
	split.add_child(_scroll)
	var cur: Array = k.get("cursor", [0, 0])
	_board.set_state(int(k.get("board", 0)), k.get("owned", []), Vector2i(int(cur[0]), int(cur[1])))
	if not _centred:
		_centred = true
		_centre.call_deferred(Vector2i(int(cur[0]), int(cur[1])))
	var side := column(split, false)
	side.custom_minimum_size.x = 340
	label(side, I18n.t("kanodo.xp", {"cur": int(k.get("xp", 0)), "total": int(k.get("total", 0))}), 18).name = "XP"
	var lines: Array = k.get("lines", [])
	var info := label(side, "\n".join(lines) if not lines.is_empty() else I18n.t("kanodo.hint"))
	info.name = "Info"
	var status := str(k.get("status", ""))
	if status != "":
		var s := label(side, status)
		s.name = "Status"
		s.add_theme_color_override("font_color", UiStyle.MUTED)
	pinned_actions.show()
	var hint := label(pinned_actions, I18n.t("kanodo.legend"))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.clip_text = true
	hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var buy := button(pinned_actions, I18n.t("kanodo.buy"), func(): send("nativeKanodoBuy"), bool(k.get("canBuy", false)))
	buy.name = "Buy"
	buy.custom_minimum_size.x = 170
	UiStyle.primary(buy, 20)


func _centre(cell: Vector2i) -> void:
	await get_tree().process_frame
	if _scroll == null:
		return
	_scroll.scroll_horizontal = int(cell.x * Board.CELL - _scroll.size.x / 2)
	_scroll.scroll_vertical = int(cell.y * Board.CELL - _scroll.size.y / 2)
