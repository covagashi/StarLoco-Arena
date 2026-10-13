extends RefCounted
## Guards a real, documented hazard: src/util/direction8.gd's own doc comment
## says "fight_view.gd keeps its own copies as DIR_MAP/DIR_FLIP — keep both
## tables in sync if one ever changes." This suite fails the moment someone
## edits one table and forgets the other.
##
## fight_view.gd is 3208 lines and scene/autoload-heavy (do not touch it, do
## not instantiate it) — but its DIR_MAP/DIR_FLIP are plain top-level consts,
## so load("res://src/fight/fight_view.gd").DIR_MAP reads them straight off
## the compiled script with no scene tree required.

const WIRE_DIRS := [0, 1, 2, 3, 4, 5, 6, 7]

## The anm sets only ship dirs {0,1,2,5,6}; 3/4/7 are mirrors (see
## direction8.gd's own doc comment).
const AUTHORED_ANM_DIRS := [0, 1, 2, 5, 6]


func run(t) -> void:
	t.suite("direction8")
	var d8 = load("res://src/util/direction8.gd")
	var fv = load("res://src/fight/fight_view.gd")

	# The hazard itself: the two duplicated tables must stay identical.
	t.eq(d8.MAP, fv.DIR_MAP, "Direction8.MAP == FightView.DIR_MAP")
	t.eq(d8.FLIP, fv.DIR_FLIP, "Direction8.FLIP == FightView.DIR_FLIP")

	var map_keys: Array = d8.MAP.keys()
	map_keys.sort()
	t.eq(map_keys, WIRE_DIRS, "MAP covers keys 0..7 exactly")
	var flip_keys: Array = d8.FLIP.keys()
	flip_keys.sort()
	t.eq(flip_keys, WIRE_DIRS, "FLIP covers keys 0..7 exactly")

	var bad_anm_dir := []
	for wire in WIRE_DIRS:
		var dir: int = d8.anm_dir(wire)
		if not AUTHORED_ANM_DIRS.has(dir):
			bad_anm_dir.append("%d->%d" % [wire, dir])
	t.ok(bad_anm_dir.is_empty(),
		("anm_dir() lands in authored set {0,1,2,5,6} for all 8 wire dirs " +
			"(bad=%s)") % [bad_anm_dir])

	var mismatched_mirror := []
	for wire in WIRE_DIRS:
		var expected: bool = d8.FLIP[wire]
		var actual: bool = d8.mirrored(wire)
		if actual != expected:
			mismatched_mirror.append("%d: mirrored=%s FLIP=%s" % [wire, actual, expected])
	t.ok(mismatched_mirror.is_empty(),
		"mirrored() agrees with FLIP for 0..7 (mismatches=%s)" % [mismatched_mirror])

	# Both helpers mask with `& 7`, so out-of-range input wraps: 8 behaves
	# as 0, -1 behaves as 7.
	t.eq(d8.anm_dir(8), d8.anm_dir(0), "anm_dir() masks 8 as 0")
	t.eq(d8.mirrored(8), d8.mirrored(0), "mirrored() masks 8 as 0")
	t.eq(d8.anm_dir(-1), d8.anm_dir(7), "anm_dir() masks -1 as 7")
	t.eq(d8.mirrored(-1), d8.mirrored(7), "mirrored() masks -1 as 7")
