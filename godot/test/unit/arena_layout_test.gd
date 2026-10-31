extends RefCounted
## S36 phase C: the arena layout the map editor writes and fight_view will
## read. Only tracked data: the kits' kit.json and the fight topology in
## server/data-dist/maps/ (the GLBs under art/*/out/ are not needed).

const Layout := preload("res://src/maps/arena_layout.gd")


func run(t) -> void:
	t.suite("arena_layout")
	# every arena of the 1.0 has a shape, start cells and pieces to place
	for n in range(1, Layout.WORLDS.size() + 1):
		var w := Layout.world_of(n)
		var shape := Layout.shape(w)
		var roles := {}
		for c: Dictionary in shape.cells.values():
			roles[c.role] = roles.get(c.role, 0) + 1
		t.ok(shape.cells.size() > 50, "arena %d (world %d) has a shape" % [n, w])
		t.ok(roles.get("team0", 0) > 0 and roles.get("team1", 0) > 0,
			"arena %d has start cells for both teams" % n)
		t.ok(not Layout.palette(w).is_empty(), "arena %d has a palette" % n)
	t.eq(Layout.world_of(0), -1, "no arena 0")
	t.eq(Layout.world_of(13), -1, "no arena 13 in the 1.0")
	# an obstacle stands on the nearest walkable floor, even two rings away
	# (the back rows of an arena are obstacles next to obstacles)
	var ob := {"alt": 30, "ground": false}
	var row := {Vector2i(0, 0): ob, Vector2i(1, 0): ob, Vector2i(2, 0): {"alt": 4, "ground": true},
		Vector2i(0, 1): {"alt": 6, "ground": true}, Vector2i(3, 0): {"alt": 1, "ground": true}}
	t.eq(Layout._floor_near(row, Vector2i(0, 0), 30), 6, "next to a floor: that floor")
	var far := {Vector2i(0, 0): ob, Vector2i(1, 0): ob, Vector2i(2, 0): {"alt": 4, "ground": true},
		Vector2i(3, 0): {"alt": 1, "ground": true}}
	t.eq(Layout._floor_near(far, Vector2i(0, 0), 30), 4, "two away: the nearest ring's floor, not a farther lower one")
	t.eq(Layout._floor_near({Vector2i(0, 0): ob}, Vector2i(0, 0), 30), 30, "no floor at all: its own altitude")
	# the owner's role changes: only the changes are written, they read back,
	# a change back to the fight data's role disappears, a pedestal stays
	var sh5 := Layout.shape(Layout.world_of(1))
	var floor_cell := Vector2i(-99, -99)
	var coach_cell := Vector2i(-99, -99)
	var start_cell := Vector2i(-99, -99)
	for p: Vector2i in sh5.cells:
		match String(sh5.cells[p].role):
			"floor": floor_cell = p
			"coach": coach_cell = p
			"team1": start_cell = p
	var before := Layout.start_counts(sh5)
	var rl := Layout.empty_layout(1)
	rl.roles[floor_cell] = "obstacle"
	rl.roles[start_cell] = "floor"
	rl.roles[coach_cell] = "obstacle"
	Layout.apply_roles(sh5, rl.roles)
	t.eq(sh5.cells[floor_cell].role, "obstacle", "a floor cell turned into an obstacle")
	t.eq(sh5.cells[start_cell].role, "floor", "a team 2 start turned into floor")
	t.eq(sh5.cells[coach_cell].role, "coach", "a coach pedestal stays one")
	t.eq(Layout.start_counts(sh5).team1, before.team1 - 1, "team 2 has one start fewer")
	var rtext := Layout.to_json(rl)
	t.ok(rtext.contains("\"roles\""), "the role changes are written")
	var rback := Layout.parse(rtext, 1)
	t.eq(rback.roles.size(), 3, "and read back")
	t.eq(rback.roles.get(floor_cell, ""), "obstacle", "with their role")
	t.eq(Layout.to_json(rback), rtext, "the file round-trips")
	t.ok(not Layout.to_json(Layout.empty_layout(1)).contains("roles"), "no changes: no roles key")
	t.eq(Layout.parse('{"arena": 1, "cells": {}, "roles": {"1,1": "lava"}}', 1).roles.size(), 0,
		"an unknown role is ignored")
	Layout.apply_roles(sh5, {})
	t.eq(sh5.cells[floor_cell].role, "floor", "no changes: the fight data's roles come back")
	for n in range(1, Layout.WORLDS.size() + 1):
		var sh := Layout.shape(Layout.world_of(n))
		var high := 0
		for c: Dictionary in sh.cells.values():
			if c.role == "obstacle" and c.surface > sh.alt_min + 40:
				high += 1
		t.eq(high, 0, "arena %d: no obstacle floats far above its floor" % n)

	# a block and a cap: the cap's top is the walk surface, the block under it
	var block := Layout.new_item("arena5", "grass_block")
	var cap := Layout.new_item("arena5", "grass_cap")
	var tree := Layout.new_item("arena1", "tree", "c")
	var items := Layout.add_item(Layout.add_item(Layout.add_item([], block), cap), tree)
	t.eq(items.size(), 3, "block, cap and tree on one cell")
	t.ok(is_equal_approx(Layout.item_y(items, 1), -0.18), "cap sinks by its own top")
	t.ok(is_equal_approx(Layout.item_y(items, 0), -0.18 - 0.93), "block goes under the cap")
	t.ok(is_zero_approx(Layout.item_y(items, 2)), "a decoration stands on the surface")
	cap.off = [0.0, 0.1, 0.0]
	t.ok(is_equal_approx(Layout.item_y(items, 0), 0.1 - 0.18 - 0.93), "a raised cap lifts the block")
	# a second block replaces the first; decorations pile up
	var ice := Layout.new_item("arena1", "ice_block", "b")
	items = Layout.add_item(items, ice)
	t.eq(items.size(), 3, "one block per cell")
	t.eq(items[2].piece, "ice_block", "the new block is in")
	t.eq(Layout.top_index(items), 1, "remove takes the tree first")
	items = Layout.add_item(items, Layout.new_item("arena1", "pebbles"))
	t.eq(Layout.top_index(items), 3, "then the newest decoration")

	# the file round-trips, defaults left out, one line per cell
	tree.rot = 450.0
	tree.flip = true
	tree.tint = "e8e0ff"
	tree.scale = 1.1
	tree.off = [0.25, 0.0, -0.1]
	var lay := Layout.empty_layout(1)
	lay.cells[Vector2i(3, 4)] = [Layout.new_item("arena1", "ice_block"), Layout.full_item(tree)]
	lay.cells[Vector2i(2, 4)] = [Layout.new_item("arena1", "bridge", "b")]
	var text := Layout.to_json(lay)
	t.ok(text.contains("\"2,4\": [{\"kit\":\"arena1\",\"piece\":\"bridge\",\"loom\":\"b\"}]"),
		"defaults are left out of the file")
	t.ok(text.find("\"2,4\"") < text.find("\"3,4\""), "cells in row order")
	var back := Layout.parse(text)
	t.eq(back.arena, 1, "arena survives")
	t.eq(back.world, 5, "world survives")
	t.eq(back.cells.size(), 2, "both cells survive")
	var tb: Dictionary = back.cells[Vector2i(3, 4)][1]
	t.ok(is_equal_approx(tb.rot, 90.0), "rotation is kept modulo 360")
	t.eq(tb.flip, true, "flip survives")
	t.eq(tb.tint, "e8e0ff", "tint survives")
	t.ok(is_equal_approx(tb.scale, 1.1), "scale survives")
	t.ok(is_equal_approx(tb.off[0], 0.25) and is_equal_approx(tb.off[2], -0.1), "offset survives")
	t.eq(Layout.to_json(back), text, "writing it again changes nothing")
	t.eq(Layout.parse("not json", 3).cells.size(), 0, "a broken file reads as empty")
