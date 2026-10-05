extends SceneTree
## App-skin resources are registered without replacing explicit themes.
func _initialize() -> void:
	var theme := GuiTheme.new()
	assert(theme.border("windowBorder").size() == 8)
	assert(theme.background("windowTitleBackground").pixmap.rect.size.y == 23)
	assert(theme.elem("window").states.default.border == "windowBorder")
	assert(theme.elem("window" + "titleBar".capitalize()).states.default.bg == "windowTitleBackground")
	assert(not theme.elem("window" + "closeButton".capitalize()).states.default.pixmap.is_empty())
	var custom := {"NORTH": {"rect": Rect2(0, 0, 2, 2)}}
	theme.pixmap_borders["windowBorder"] = custom
	theme._install_app_skin()
	assert(theme.border("windowBorder") == custom)
	print("[skin] PASS: border, title, close glyph, custom-theme precedence")
	quit()
