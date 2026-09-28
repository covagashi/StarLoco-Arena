extends SceneTree

## Headless map-decode check — mirrors server/internal/gamedata/fightmaps_test.go:
## every team start cell and special cell must sit on walkable ground at exactly
## its authored altitude. Coach pedestals are elevated scenery (non-ground by
## design) and are NOT asserted.
##
##   godot --headless --path godot -s test/map_smoke.gd [map_id|all]

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = [10]
	var dump := false
	if args.size() > 0 and args[0] == "all":
		ids = _all_arena_ids()
	elif args.size() > 0 and args[0] == "dump":
		ids = [int(args[1]) if args.size() > 1 else 5]
		dump = true
	elif args.size() > 0:
		ids = [int(args[0])]

	var total_bad := 0
	for map_id in ids:
		total_bad += _check_map(map_id, dump)
	print("[map] done — %d violation(s) across %d map(s)" % [total_bad, ids.size()])
	quit(0 if total_bad == 0 else 1)


func _all_arena_ids() -> Array:
	var dir := DirAccess.open(ProjectSettings.globalize_path(
		"res://../server/data-dist/maps/fight"))
	var ids: Array = []
	if dir == null:
		return ids
	for f in dir.get_files():
		if f.ends_with(".jar"):
			ids.append(int(f.get_basename()))
	ids.sort()
	return ids


func _check_map(map_id: int, dump := false) -> int:
	var fmd := FightMap.load(map_id)
	if fmd.is_empty():
		print("[map] %d: no .fmd (not an arena) — skip" % map_id)
		return 0
	var topo := Topology.load_world(map_id, Topology.SCOPE_ARENA)
	var cells: Dictionary = topo.get("cells", {})
	if cells.is_empty():
		print("[map] %d: fmd present but NO topology — skip" % map_id)
		return 0
	var n_ground := 0
	for c in cells.values():
		if c.ground:
			n_ground += 1
	if dump:
		_dump_ascii(map_id, cells, topo.bounds, fmd)

	var bad := 0
	for side in ["team0", "team1"]:
		for c in fmd[side]:
			var cell = cells.get(Vector2i(c.x, c.y))
			if cell == null or not cell.ground:
				bad += 1
				print("[map] %d: %s spawn (%d,%d) z=%d has no ground" % [map_id, side, c.x, c.y, c.z])
			elif cell.alt != c.z:
				bad += 1
				print("[map] %d: %s spawn (%d,%d) z=%d but alt=%d" % [map_id, side, c.x, c.y, c.z, cell.alt])
	var unreachable_specials := 0
	for s in fmd.get("specials", []):
		var p: Dictionary = s.pos
		var cell = cells.get(Vector2i(p.x, p.y))
		if cell == null or not cell.ground or cell.alt != p.z:
			unreachable_specials += 1
			print("[map] %d: special (%d,%d) z=%d off-floor" % [map_id, p.x, p.y, p.z])
	# Go documents exactly 2 unreachable specials in the shipped data — map 42's
	# content quirk (server drops them at load). Anything else is a decode bug.
	var expected_dead := 2 if map_id == 42 else 0
	if unreachable_specials != expected_dead:
		bad += 1
		print("[map] %d: unreachable specials %d, want %d" % [map_id, unreachable_specials, expected_dead])
	print("[map] %d: %d cells (%d floor), t0=%d t1=%d coach=%d specials=%d — %d violations" % [
		map_id, cells.size(), n_ground, fmd.team0.size(), fmd.team1.size(),
		fmd.coach.size(), fmd.get("specials", []).size(), bad])
	return bad


## ASCII map: '#' solid scenery, '.' floor, ' ' void, 'A'/'B' team spawns,
## 'C' coach pedestal, '*' special. Altitude shown as digits shading isn't
## needed for a sanity check — floor pattern is what matters.
func _dump_ascii(map_id: int, cells: Dictionary, b: Rect2i, fmd: Dictionary) -> void:
	var marks := {}
	for c in fmd.get("team0", []):
		marks[Vector2i(c.x, c.y)] = "A"
	for c in fmd.get("team1", []):
		marks[Vector2i(c.x, c.y)] = "B"
	for c in fmd.get("coach", []):
		marks[Vector2i(c.x, c.y)] = "C"
	for s in fmd.get("specials", []):
		marks[Vector2i(s.pos.x, s.pos.y)] = "*"
	print("[map] %d ascii (bounds %s):" % [map_id, b])
	for y in range(b.position.y, b.end.y + 1):
		var line := ""
		for x in range(b.position.x, b.end.x + 1):
			var p := Vector2i(x, y)
			if marks.has(p):
				line += marks[p]
			else:
				var c = cells.get(p)
				line += " " if c == null else ("." if c.ground else "#")
		print("  |" + line + "|")
