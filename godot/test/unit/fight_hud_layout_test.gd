extends RefCounted
## S17 fight HUD: the side columns must hold a crowded fight. Pure layout
## math (FightHud._column_fit + FighterCard.card_size) — no scene tree, no
## assets, so it runs in the headless CI lane.

const FightHud := preload("res://src/fight/fight_hud.gd")
const FighterCard := preload("res://src/fight/fighter_card.gd")


func run(t) -> void:
	t.suite("fight_hud_layout")
	var hud = FightHud.new()
	for res in [Vector2(1280, 720), Vector2(800, 600)]:
		# the left column stops above the medallion (~140 px at 800x600)
		var bottom: float = res.y - 150.0
		for n in [1, 4, 8, 12, 16]:
			var col := _cards(n, n / 2)   # half of them summons
			var fit: Vector2 = hud._column_fit(col, FightHud.TOP, bottom, res)
			var p := fit.x
			var cols := int(fit.y)
			# lay the column out for real and measure it
			hud._layout_column(col, true, FightHud.TOP, p, cols, res)
			var low := 0.0
			for c in col:
				low = maxf(low, c.position.y + c.size.y)
			t.ok(p >= 24.0, "%dx%d, %d cards: portrait %d px >= 24" % [
				res.x, res.y, n, p])
			t.ok(low <= bottom + 1.0 or p <= 24.0,
				"%dx%d, %d cards end above the medallion (y %d <= %d)" % [
				res.x, res.y, n, low, bottom])
			t.ok(cols <= 2, "%d cards: at most two columns" % n)
		var one: Vector2 = hud._column_fit(_cards(8, 4), FightHud.TOP, bottom, res)
		t.eq(int(one.y), 1, "%dx%d: 8 cards (4 summons) keep one column" % [
			res.x, res.y])
	for c in _made:
		c.free()
	hud.free()


var _made: Array = []

func _cards(n: int, summons: int) -> Array:
	var out := []
	for i in n:
		var c = FighterCard.new()
		c.summon = i < summons
		out.append(c)
		_made.append(c)
	return out
