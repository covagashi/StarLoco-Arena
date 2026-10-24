extends "res://test/world_smoke.gd"

## S22: Logros with retail's icons, live. In Spanish.
##
##   godot --path godot -s test/achievements_smoke.gd [-- --shot-dir=D]
##
## The panel opens on the pending ones as icon tiles (dimmed icons), "Hechos"
## lists the done ones (lit icons), and a picked one says what it asks.


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.4).timeout
	_close_all()
	_main._gui.open("achievementDialog")
	await create_timer(0.8).timeout
	var p = _main._gui.dialogs.get("achievementDialog")
	var grid: GridContainer = p.find_child("AchGrid", true, false)
	var tiles := grid.get_children().filter(func(c): return c is Button)
	var with_icon := tiles.filter(func(b):
		var t: TextureRect = b.find_children("*", "TextureRect", true, false)[0] if not b.find_children("*", "TextureRect", true, false).is_empty() else null
		return t != null and t.texture != null)
	_record(0, "pending", tiles.size() > 0 and with_icon.size() == tiles.size(),
		"%d pending tiles, %d with an icon" % [tiles.size(), with_icon.size()])
	await _shot("achievements")
	# Hechos
	var show: OptionButton = p.find_child("AchShow", true, false)
	show.select(1)
	show.item_selected.emit(1)
	await create_timer(0.6).timeout
	grid = p.find_child("AchGrid", true, false)
	var done := grid.get_children().filter(func(c): return c is Button)
	_record(0, "done", done.size() > 0, "%d done tiles" % done.size())
	# pick one: its description
	if not done.is_empty():
		done[0].pressed.emit()
		await create_timer(0.5).timeout
		var desc: Label = p.find_child("AchDesc", true, false)
		_record(0, "detail", desc != null and desc.text != "", "'%s'" % (desc.text.left(50) if desc != null else "—"))
		await _shot("achievements-detail")
	_close_all()
	i18n.set_locale(lang_before)
