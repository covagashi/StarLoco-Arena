extends RefCounted
## S07: the coach level the lobby shows comes from the standing with the
## retail's formula (aet_0.nJ — the server's StandingToLevel). Before, the
## client hard-coded level 0. Pins the edges: level L starts at L²·10
## standing (nr_0.ct), level 1 covers 0–39, the cap is 50.

func run(t) -> void:
	t.suite("coach_level")
	var state = load("res://src/state.gd")
	for c in [[0, 1], [-5, 1], [39, 1], [40, 2], [89, 2], [90, 3], [999, 9],
			[1000, 10], [24999, 49], [25000, 50], [999999, 50]]:
		t.eq(state.coach_level(c[0]), c[1], "standing %d -> level %d" % c)
	for lvl in range(2, 51):
		var start: int = state.standing_for_level(lvl)
		t.ok(state.coach_level(start) == lvl and state.coach_level(start - 1) == lvl - 1,
			"level %d starts at %d" % [lvl, start])
	t.eq(state.standing_for_level(1), 0, "level 1 is free")
