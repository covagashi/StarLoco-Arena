extends RefCounted
## S47 W6: what a held finger reads — the topmost control under it, or its
## nearest parent with a tooltip; nothing hidden, scrolled away or under a
## higher layer.

const TouchTips := preload("res://src/ui/touch_tips.gd")


func run(t) -> void:
	t.suite("touch_tips")
	var root: Window = Engine.get_main_loop().root
	# the root is busy while the runner sets up: hang the test tree off an
	# autoload that is already in (a plain Node, so canvas layer 0)
	var host: Node = root.get_node("I18n")
	var base := Control.new()
	base.size = Vector2(1280, 720)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(base)

	var tile := Button.new()
	tile.position = Vector2(100, 100)
	tile.size = Vector2(200, 100)
	tile.tooltip_text = "lo que paga"
	base.add_child(tile)
	var icon := TextureRect.new()   # a child without a tooltip of its own
	icon.position = Vector2(10, 10)
	icon.size = Vector2(40, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	tile.add_child(icon)
	t.eq(TouchTips.tip_at(root, Vector2(150, 150)), "lo que paga", "a tile's tooltip")
	t.eq(TouchTips.tip_at(root, Vector2(120, 120)), "lo que paga", "a child reads its parent's tooltip")
	t.eq(TouchTips.tip_at(root, Vector2(600, 600)), "", "nothing under the finger")

	# scaled screens (lobby_screen scales its box to the window)
	var box := Control.new()
	box.position = Vector2(400, 0)
	box.scale = Vector2(0.5, 0.5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(box)
	var spell := Button.new()
	spell.position = Vector2(200, 200)
	spell.size = Vector2(64, 64)
	spell.tooltip_text = "4 PA · 1–3"
	box.add_child(spell)
	t.eq(TouchTips.tip_at(root, Vector2(400 + 116, 116)), "4 PA · 1–3", "inside a scaled box")
	t.eq(TouchTips.tip_at(root, Vector2(400 + 200, 200)), "", "the unscaled spot is empty")

	# a modal on top hides the tile under it, even with no tooltip of its own
	var modal := Panel.new()
	modal.position = Vector2(80, 80)
	modal.size = Vector2(300, 200)
	base.add_child(modal)
	t.eq(TouchTips.tip_at(root, Vector2(150, 150)), "", "a modal covers the tile")
	modal.visible = false
	t.eq(TouchTips.tip_at(root, Vector2(150, 150)), "lo que paga", "a hidden modal does not")

	# a list scrolled past its window: the row is not under the finger
	var clip := Control.new()
	clip.position = Vector2(800, 100)
	clip.size = Vector2(200, 100)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(clip)
	var row := Button.new()
	row.position = Vector2(0, 150)
	row.size = Vector2(200, 40)
	row.tooltip_text = "fila"
	clip.add_child(row)
	t.eq(TouchTips.tip_at(root, Vector2(850, 260)), "", "a row clipped out of its list")
	row.position = Vector2(0, 20)
	t.eq(TouchTips.tip_at(root, Vector2(850, 130)), "fila", "the same row scrolled in")

	# a higher canvas layer wins over tree order
	var layer := CanvasLayer.new()
	layer.layer = 5
	host.add_child(layer)
	var top := Button.new()
	top.position = Vector2(140, 140)
	top.size = Vector2(40, 40)
	top.tooltip_text = "encima"
	layer.add_child(top)
	host.move_child(layer, 0)   # earlier in the tree, still drawn above
	t.eq(TouchTips.tip_at(root, Vector2(150, 150)), "encima", "a higher layer is on top")

	layer.free()
	base.free()
	_wrap(t)


func _wrap(t) -> void:
	var f := ThemeDB.fallback_font
	var long := "Recluta luchadores y hazlos crecer combate a combate contra los demonios del Gran Reloj."
	var lines := TouchTips.wrap_text(long, f, 16, 200.0).split("\n")
	t.ok(lines.size() > 1, "a long tooltip is broken into lines")
	var widest := 0.0
	for l in lines:
		widest = maxf(widest, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	t.ok(widest <= 200.0, "no line wider than the bubble (%d)" % widest)
	t.eq(" ".join(lines), long, "no word lost")
	t.eq(TouchTips.wrap_text("a\nb", f, 16, 200.0), "a\nb", "its own line breaks kept")
