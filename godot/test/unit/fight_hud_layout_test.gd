extends RefCounted
## S45 fight HUD: the turn order across the top must hold a crowded fight
## between the arena label and the round buttons. Pure layout math
## (FightHud.fit_timeline) — no scene tree, no assets, so it runs in the
## headless CI lane.

const FightHud := preload("res://src/fight/fight_hud.gd")


func run(t) -> void:
	t.suite("fight_hud_layout")
	for res in [Vector2(1280, 720), Vector2(800, 600)]:
		var room: float = res.x - 2.0 * 285.0
		for n in [1, 4, 8, 12, 16]:
			# the acting fighter, then half of the rest summons
			var sides := [FightHud.ACTIVE_SIDE]
			for i in n - 1:
				sides.append(FightHud.SUMMON_SIDE if i % 2 == 0 else FightHud.SIDE)
			var fit: Vector2 = FightHud.fit_timeline(sides, true, room)
			var k := fit.x
			var shown := int(fit.y)
			var w: float = FightHud._strip_width(sides.slice(0, shown), true) * k
			t.ok(w <= room + 0.5 or shown == 1, "%dx%d, %d fighters: the strip (%d px) fits in %d" % [
				res.x, res.y, n, w, room])
			t.ok(FightHud.SUMMON_SIDE * k >= 22.0, "%dx%d, %d fighters: portraits stay >= 22 px (%d)" % [
				res.x, res.y, n, FightHud.SUMMON_SIDE * k])
			t.ok(shown >= mini(n, 4), "%dx%d, %d fighters: at least the next %d show (%d)" % [
				res.x, res.y, n, mini(n, 4), shown])
		var eight := [FightHud.ACTIVE_SIDE]
		for i in 7:
			eight.append(FightHud.SIDE)
		t.eq(int(FightHud.fit_timeline(eight, true, 1280.0 - 570.0).y), 8,
			"1280x720: a 4-vs-4 shows everyone")
