extends RefCounted
## Guards the invariant every consumer of Topology.load_world() assumes:
## the returned `bounds` rect actually CONTAINS every cell it describes.
##
## It did not. Rect2i's end is exclusive, so the old
## `bounds.expand(Vector2i(x, y))` aligned the edge AT the extreme cell and
## left that cell outside the rect — has_point() returned false for the last
## row and column. The island exporter lost 26 cells on world 24 and 7 on
## world 34 to this before it stopped trusting `bounds` and measured the
## cells itself; fight_view.gd only reads get_center(), so there it showed
## up as half a tile of camera offset rather than anything visible.
##
## CI-safe: the topology comes from server/data-dist/maps/, which IS tracked
## (the maintainer-curated redistribution exception in AGENTS.md), not from
## the git-ignored assets/ tree.

## Small worlds, so the suite stays quick. 93 is a clan island (~950 cells),
## 108 another (~3400). Both were cross-checked against the exporter's counts.
const WORLDS := [93, 108]


func run(t) -> void:
	t.suite("topology_bounds")
	var topology = load("res://src/maps/topology.gd")
	for world in WORLDS:
		var topo: Dictionary = topology.load_world(world)
		t.ok(topo.has("cells") and topo.has("bounds"),
			"world %d returns cells and bounds" % world)
		if not (topo.has("cells") and topo.has("bounds")):
			continue
		var cells: Dictionary = topo.cells
		t.ok(not cells.is_empty(), "world %d has cells" % world)
		var bounds: Rect2i = topo.bounds
		# The whole point: no cell may fall outside the advertised rect.
		var outside := []
		var examined := 0
		for key in cells:
			# Keys are Vector2i. An earlier version of this suite parsed them
			# as "x,y" strings, got (0, y) out of "(5, 3)" and passed with the
			# bug still present — hence `examined`, asserted below, so a key
			# format change can never silently neuter this again.
			if not (key is Vector2i):
				continue
			examined += 1
			if not bounds.has_point(key):
				outside.append(key)
		t.eq(examined, cells.size(),
			"world %d: every cell key was actually examined" % world)
		t.ok(outside.is_empty(),
			"world %d: every cell is inside bounds (%d strays, first=%s)" % [
				world, outside.size(),
				outside[0] if not outside.is_empty() else "none"])
		t.ok(bounds.size.x > 0 and bounds.size.y > 0,
			"world %d bounds is non-degenerate (%s)" % [world, bounds])
