extends RefCounted
## S37: the effect library draws every shape × element without errors,
## frees what it spawns, and the zone helper matches the fight's cells.

const Vfx := preload("res://src/fx/vfx.gd")


func run(t) -> void:
	t.suite("vfx")
	var tree := Engine.get_main_loop() as SceneTree
	var stage := Node2D.new()
	# the root is busy adding the runner while suites run: hang off the runner
	tree.root.get_child(tree.root.get_child_count() - 1).add_child(stage)
	for s in Vfx.SHAPES:
		for e in Vfx.ELEMS:
			var before := stage.get_child_count()
			var land := Vfx.play(stage, {"s": s, "e": e, "k": 3, "z": 1},
				Vector2(-86, 0), Vector2.ZERO)
			t.ok(stage.get_child_count() == before + 1, "%s/%s spawns one root" % [s, e])
			t.ok(land >= 0.0 and land < 2.0, "%s/%s lands within 2 s" % [s, e])
	var bolt := Vfx.play(stage, {"s": "bolt", "e": "fire", "k": 1},
		Vector2(-430, 0), Vector2.ZERO)
	t.ok(bolt > 0.3, "a long bolt takes longer to land (%.2f s)" % bolt)
	# unknown shapes and elements fall back instead of failing
	Vfx.play(stage, {"s": "nope", "e": "plasma"}, Vector2.ZERO, Vector2.ZERO)
	t.eq(Vfx.zone_cells(Vector2.ZERO, 0).size(), 1, "zone 0 = one cell")
	t.eq(Vfx.zone_cells(Vector2.ZERO, 1).size(), 5, "zone 1 = a cross of 5")
	t.eq(Vfx.zone_cells(Vector2.ZERO, 2).size(), 13, "zone 2 = 13 cells")
	t.ok(Vector2(43, 21.5) in Vfx.zone_cells(Vector2.ZERO, 1), "dx=1 is one cell SE on screen")
	for name in ["dot", "spark", "chunk", "plus"]:
		t.ok(Vfx.tex(name) != null, "texture %s" % name)
	stage.queue_free()
