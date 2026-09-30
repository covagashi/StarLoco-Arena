extends SceneTree

## Displacement smoke — the 8120 displacement actions (push/pull/teleport/
## swap/carry/throw) move a fighter mid-fight; the sprite must track the cell
## the effect carries (part-0 for teleport/swap/carry/throw, part-3
## displacementPart for the shoves).
##   6001 ×3: breed-6 + spell 12 (teleport 39, range 1-1, no-LoS, free cell),
##            breed-4 + spell 67 (push 37, range 1-1, any target),
##            breed-11 + spell 135 (swap 64, range 1-3, ally-only)
##   6021 preset with the three, 26330 [12][teamId] practice
##   placement: arrange them inside the team spawn zone so each cast is legal
##   on each of their turns: teleport self, push an ally, swap with an ally —
##   asserting _actor_cells actually moved (sprite follows the wire effect).
##   Then surrender + delete the preset and the three fighters.
##   godot --headless --path godot -s test/displace_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const TP_BREED := 6
const TP_SPELL := 12         # breed 6 teleport (39) range 1-1, no LoS, free cell
const PUSH_BREED := 4
const PUSH_SPELL := 67       # breed 4 push (37) range 1-1 — hits any fighter
const SWAP_BREED := 11
const SWAP_SPELL := 135      # breed 11 swap (64) range 1-3 — allies only
const TEAM_TEST_TYPE := 12
var TEAM_NAME := "zzdisp%d" % (Time.get_unix_time_from_system() as int % 100000)
var FIGHTER_NAME := "zzdsp%d" % (Time.get_unix_time_from_system() as int % 100000)

var client: ArenaClient
var finished := false
var fight_scene: Node2D = null
var _created := {}            # breed -> fighter id (6000 results)
var _preset_id := -1
var _wire_fids := {}          # breed -> in-fight wire id
var _combat_seen := false
var _placed := false
var _tp_ok := false
var _push_ok := false
var _swap_ok := false


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(func():
		_finish(0 if (_tp_ok and _push_ok and _swap_ok) else 1,
			"disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(120.0).timeout.connect(_finish.bind(1, "timeout"))


func _send_login() -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)
	version.put_u16(70)
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	client.send_message(7, version.raw(), 0)
	var auth := WireWriter.new()
	var l := CP1252.encode("test")
	var p := CP1252.encode("test123")
	auth.put_u8(l.size())
	auth.put_bytes(l)
	auth.put_u8(p.size())
	auth.put_bytes(p)
	client.send_message(1025, auth.raw(), 1)
	print("[smoke] sent login")


func _send_coach() -> void:
	var n := CP1252.encode("test")
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	client.send_message(2049, w.raw(), 2)


## 6001 ×3 — one fighter per breed, each carrying its displacement spell.
func _create_fighters() -> void:
	var i := 0
	for breed in [TP_BREED, PUSH_BREED, SWAP_BREED]:
		var spell: int = {TP_BREED: TP_SPELL, PUSH_BREED: PUSH_SPELL,
			SWAP_BREED: SWAP_SPELL}[breed]
		var blob := Overrides.encode_fighter_blob(
			breed, "%s%d" % [FIGHTER_NAME, breed], 0, [spell])
		var w := WireWriter.new()
		w.put_u8(0)
		w.put_u16(0)
		w.put_u16(blob.size())
		w.put_bytes(blob)
		client.send_message(6001, w.raw(), 2)
		i += 1
	print("[smoke] fighter creates sent (breeds 8/9/11)")


## 6021 — preset holding all three created fighters. sw_1 wire layout
## (team_codec.go): [i16 type][i16 teamId][i16 gameMode][u8 nameLen][name]
## then [u8 n]{i64 fighterId, i64 owningCoachId} then [u8 n]{i64 coachId}.
func _save_preset() -> void:
	var w := WireWriter.new()
	w.put_i16(0)
	w.put_i16(0)
	w.put_i16(1)
	var nb := CP1252.encode(TEAM_NAME)
	w.put_u8(nb.size())
	w.put_bytes(nb)
	w.put_u8(_created.size())
	for breed in _created:
		w.put_i64(int(_created[breed]))
		w.put_i64(State.my_coach_id)
	w.put_u8(0)                       # coach list — solo preset
	w.put_u8(0)                       # trailing pad byte
	client.send_message(6021, w.raw(), 2)
	print("[smoke] preset save sent (%d fighters)" % _created.size())


func _launch_practice() -> void:
	var w := WireWriter.new()
	w.put_i32(TEAM_TEST_TYPE)
	w.put_u16(_preset_id)
	client.send_message(26330, w.raw(), 2)
	print("[smoke] practice launch sent (team %d)" % _preset_id)


func _show_fight() -> void:
	State.net = client
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	fight_scene.turn_began.connect(_on_fight_turn)
	fight_scene.placement_began.connect(_on_placement)
	root.add_child(fight_scene)
	_combat_seen = false
	var deadline := 0.0
	while not _combat_seen and deadline < 15.0:
		await create_timer(0.25).timeout
		deadline += 0.25
	if not _combat_seen:
		_finish(1, "combat never started")
		return
	var wait := 0.0
	while not (_tp_ok and _push_ok and _swap_ok) and wait < 60.0:
		await create_timer(1.0).timeout
		wait += 1.0
	print("[smoke] displacement results tp=%s push=%s swap=%s" % [
		_tp_ok, _push_ok, _swap_ok])
	client.send_message(8151, PackedByteArray(), 3)


func _my_team() -> int:
	for fid in State.fighters:
		var f: Dictionary = State.fighters[fid]
		if int(f.get("coach", -1)) == State.my_coach_id:
			return int(f.get("team", -1))
	return -1


func _cell_dist(a: Vector3i, b: Vector3i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Placement: put the pusher, the teleporter and the swapper on team spawn
## cells such that — relative to the teleporter A — the pusher B is ADJACENT
## (spell 67 is range 1-1) and the swapper C is within 1-3 (spell 135).
func _on_placement() -> void:
	if finished or fight_scene == null or _placed:
		return
	_placed = true
	var team := _my_team()
	var cells: Array = fight_scene._fmd.get("team%d" % team, [])
	var ours := {}   # breed -> wire fid
	for fid in State.fighters:
		var f: Dictionary = State.fighters[fid]
		if int(f.get("coach", -1)) == State.my_coach_id:
			ours[int(f.get("breed", -1))] = int(fid)
	_wire_fids = ours
	print("[smoke] placement: our fighters=%s team=%d spawns=%d" % [
		ours, team, cells.size()])
	# pick cA/cB/cC from the spawn list: dist(cB,cA)==1, dist(cC,cA)∈[1,3]
	var va: Variant = null
	var vb: Variant = null
	var vc: Variant = null
	for ca in cells:
		var pa := Vector3i(int(ca.x), int(ca.y), 0)
		for cb in cells:
			if cb == ca:
				continue
			var pb := Vector3i(int(cb.x), int(cb.y), 0)
			if _cell_dist(pa, pb) != 1:
				continue
			for cc in cells:
				if cc == ca or cc == cb:
					continue
				var pc := Vector3i(int(cc.x), int(cc.y), 0)
				if _cell_dist(pa, pc) < 1 or _cell_dist(pa, pc) > 3:
					continue
				va = ca
				vb = cb
				vc = cc
				break
			if vb != null:
				break
		if vb != null:
			break
	if vb == null:
		push_error("no usable spawn-cell triple")
		fight_scene.confirm_placement()
		return
	# place A, B, C — sequential with a beat each so the 8022 acks land
	var order := [[int(ours.get(TP_BREED, -1)), va],
		[int(ours.get(PUSH_BREED, -1)), vb],
		[int(ours.get(SWAP_BREED, -1)), vc]]
	var k := 0
	for pair in order:
		var fid: int = pair[0]
		var cell = pair[1]
		if fid < 0:
			continue
		k += 1
		create_timer(0.4 * k).timeout.connect(func():
			if fight_scene != null and not finished:
				fight_scene._selected = fid
				var ok: bool = fight_scene.request_place_at(
					Vector2i(int(cell.x), int(cell.y)))
				print("[smoke] place fid=%d -> (%d,%d) ok=%s" % [
					fid, int(cell.x), int(cell.y), ok]))
	create_timer(2.0).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.confirm_placement())


## Turn policy keyed by breed: teleport self, push an ally in range 2-5,
## swap with an ally in range 1-3. Each verifies via _actor_cells.
func _on_fight_turn(fid: int, ours: bool) -> void:
	if finished or fight_scene == null or not ours:
		return
	var f: Dictionary = State.fighters.get(fid, {})
	var breed := int(f.get("breed", -1))
	var me: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	match breed:
		TP_BREED:
			if _tp_ok:
				fight_scene.request_end_turn()
				return
			# spell 12 is range 1-1, free-cell, no LoS — an adjacent floor cell
			for dxy in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				var cell := Vector2i(me.x + dxy.x, me.y + dxy.y)
				if not fight_scene._cells.has(cell) or _occupied(cell, fid):
					continue
				if not fight_scene._cells[cell].get("ground", false):
					continue   # teleport must land on a walkable cell
				_tp_ok = true   # asserted by the effect landing — see timer
				fight_scene.request_cast_at(TP_SPELL, cell)
				var want := cell
				create_timer(1.0).timeout.connect(func():
					if fight_scene == null:
						return
					var now: Vector3i = fight_scene._actor_cells.get(
						fid, Vector3i.ZERO)
					print("[smoke] TP: fid=%d (%d,%d)->(%d,%d) want=(%d,%d) %s" % [
						fid, me.x, me.y, now.x, now.y, want.x, want.y,
						"OK" if now.x == want.x and now.y == want.y else "FAIL"])
					if now.x != want.x or now.y != want.y:
						_tp_ok = false
						push_error("teleport did not land on the target cell"))
				create_timer(1.6).timeout.connect(func():
					if fight_scene != null and not finished:
						fight_scene.request_end_turn())
				return
			fight_scene.request_end_turn()
		PUSH_BREED:
			if _push_ok:
				fight_scene.request_end_turn()
				return
			# push anyone adjacent — spell 67's mask is permissive; the Sparring
			# AI walks in to melee us, so an enemy target is just as good
			var ally := _fighter_in_range(me, 1, 1, fid)
			if ally < 0:
				fight_scene.request_end_turn()
				return
			var before: Vector3i = fight_scene._actor_cells.get(
				ally, Vector3i.ZERO)
			_push_ok = true
			fight_scene.request_cast_at(PUSH_SPELL,
				Vector2i(before.x, before.y))
			create_timer(1.0).timeout.connect(func():
				if fight_scene == null:
					return
				var now: Vector3i = fight_scene._actor_cells.get(
					ally, Vector3i.ZERO)
				print("[smoke] PUSH: ally=%d (%d,%d)->(%d,%d) %s" % [
					ally, before.x, before.y, now.x, now.y,
					"OK" if now != before else "FAIL"])
				if now == before:
					_push_ok = false
					push_error("pushed ally did not move"))
			create_timer(1.6).timeout.connect(func():
				if fight_scene != null and not finished:
					fight_scene.request_end_turn())
		SWAP_BREED:
			if _swap_ok:
				fight_scene.request_end_turn()
				return
			# Sacrifice needs LoS (los:true) — filter the pick through the
			# fight view's own gate so a covered ally isn't cast at.
			var ally2 := _ally_in_range(me, 1, 3, fid, true)
			if ally2 < 0:
				print("[smoke] SWAP: no ally in range — ending turn")
				fight_scene.request_end_turn()
				return
			var c0: Vector3i = fight_scene._actor_cells.get(
				ally2, Vector3i.ZERO)
			_swap_ok = true
			fight_scene.request_cast_at(SWAP_SPELL, Vector2i(c0.x, c0.y))
			var me0 := me
			create_timer(1.0).timeout.connect(func():
				if fight_scene == null:
					return
				var me_now: Vector3i = fight_scene._actor_cells.get(
					fid, Vector3i.ZERO)
				var al_now: Vector3i = fight_scene._actor_cells.get(
					ally2, Vector3i.ZERO)
				var ok := (me_now == c0 and al_now == me0)
				print("[smoke] SWAP: me (%d,%d)->(%d,%d) ally (%d,%d)->(%d,%d) %s" % [
					me0.x, me0.y, me_now.x, me_now.y,
					c0.x, c0.y, al_now.x, al_now.y,
					"OK" if ok else "FAIL"])
				if not ok:
					_swap_ok = false
					push_error("swap did not exchange cells"))
			create_timer(1.6).timeout.connect(func():
				if fight_scene != null and not finished:
					fight_scene.request_end_turn())
		_:
			fight_scene.request_end_turn()


func _occupied(cell: Vector2i, except_fid: int) -> bool:
	for id in fight_scene._actor_cells:
		if int(id) == except_fid:
			continue
		var p: Vector3i = fight_scene._actor_cells[id]
		if p.x == cell.x and p.y == cell.y:
			return true
	return false


## A living teammate's fighter at Manhattan range [rmin,rmax] from `me`.
## `los` additionally requires the fight view's own LoS gate to pass.
func _ally_in_range(me: Vector3i, rmin: int, rmax: int, except_fid: int,
		los := false) -> int:
	for id in fight_scene._actor_cells:
		var iid := int(id)
		if iid == except_fid or fight_scene._dead.get(iid, false):
			continue
		var f: Dictionary = State.fighters.get(iid, {})
		if int(f.get("coach", -1)) != State.my_coach_id:
			continue            # only our own preset fighters — AI pushes us off a cliff
		var p: Vector3i = fight_scene._actor_cells[id]
		var dd := _cell_dist(me, p)
		if dd >= rmin and dd <= rmax \
				and (not los or fight_scene._los_clear(
					Vector2i(me.x, me.y), Vector2i(p.x, p.y))):
			return iid
	return -1


## Any living fighter (ally OR enemy) at Manhattan range [rmin,rmax].
func _fighter_in_range(me: Vector3i, rmin: int, rmax: int, except_fid: int) -> int:
	for id in fight_scene._actor_cells:
		var iid := int(id)
		if iid == except_fid or fight_scene._dead.get(iid, false):
			continue
		var p: Vector3i = fight_scene._actor_cells[id]
		var dd := _cell_dist(me, p)
		if dd >= rmin and dd <= rmax:
			return iid
	return -1


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	match opcode:
		1024:
			if decoded.get("result") == 0:
				print("[smoke] auth OK")
			else:
				_finish(1, "auth refused %s" % decoded.get("result"))
		2048:
			_send_coach()
		2052:
			State.my_coach_id = int(decoded.get("id", -1))
			print("[smoke] coach id=%s name='%s'" % [
				decoded.get("id"), decoded.get("name")])
		4600:
			State.current_world = int(decoded.get("world_id", -1))
		4516:
			_create_fighters()
		6000:
			if int(decoded.get("result", 1)) != 0:
				_finish(1, "fighter create refused %s" % decoded.get("result"))
				return
			var fid := int(decoded.get("fighter_id", -1))
			var breed := int(decoded.get("fighter", {}).get("breed", -1))
			_created[breed] = fid
			print("[smoke] fighter created id=%d breed=%d" % [fid, breed])
			if _created.size() == 3:
				_save_preset()
		6030:
			var best := -1
			for p in decoded.get("presets", []):
				if str(p.get("name", "")) != TEAM_NAME:
					continue
				best = maxi(best, int(p.get("id", -1)))
			if best != _preset_id:
				_preset_id = best
				print("[smoke] preset id=%d" % _preset_id)
				if _preset_id > 0:
					_launch_practice()
		8000:
			State.fight_world = State.current_world
			State.fight_data = decoded
			State.index_fighters(decoded)
			for t in decoded.get("teams", []):
				for f in t.get("fighters", []):
					print("[smoke]   fighter '%s' breed=%d team=%d id=%d"
						% [f.name, f.get("breed", -1), t.id, f.id])
			_show_fight()
		8040:
			_combat_seen = true
			print("[smoke] combat started")
		8300:
			print("[smoke] END FIGHT")
			_cleanup()
		26310:
			_finish(1, "fight refused")


func _cleanup() -> void:
	var w := WireWriter.new()
	w.put_i64(_preset_id)
	w.put_i16(0)
	w.put_i16(0)
	client.send_message(6023, w.raw(), 2)
	for breed in _created:
		var w2 := WireWriter.new()
		w2.put_i64(int(_created[breed]))
		w2.put_i16(0)
		client.send_message(6003, w2.raw(), 2)
	print("[smoke] cleanup: preset %d + %d fighters deleted" % [
		_preset_id, _created.size()])
	var code := 0 if (_tp_ok and _push_ok and _swap_ok) else 1
	_finish(code, "displace smoke complete")


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
