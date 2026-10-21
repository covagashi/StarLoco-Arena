extends RefCounted
## S07: fighters are created without a colour pick. An index outside tn_0
## must leave its channel untinted (the retail's tn_0.hT -> null), so a new
## fighter keeps its breed's own colours; older fighters keep theirs.

func run(t) -> void:
	t.suite("palettes")
	var p = load("res://src/gamedata/palettes.gd")
	var old: Dictionary = p.fighter_tints(0, 1, 2)
	t.eq(old.keys(), [1, 2, 8], "an old fighter's three channels stay tinted")
	t.eq(old[2], p.NATURAL[1] * 1.25, "hair from tn_0, x1.25 like the retail")
	t.eq(p.fighter_tints(p.NO_TINT, p.NO_TINT, p.NO_TINT), {}, "a new fighter: no tint at all")
	t.eq(p.fighter_tints(-1, 3, p.NATURAL.size()).keys(), [2],
		"only the in-range channel tints (-1 and size are outside)")
