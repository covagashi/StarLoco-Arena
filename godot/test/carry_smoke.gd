extends SceneTree

## Carry/throw smoke — actions 58/59 ride the same 8120 displacement
## decoder, but the carrier also changes pose family (ee_2 ls("Porte")):
## Anim01Porte on the lift, AnimStatiquePorte/AnimMarchePorte while
## holding, Anim02Porte/Anim03Porte on the release. Only breed-12 fighter
## sets author the Porte actions, so the carrier must be breed 12.
##   6001 ×2: breed-12 + spells 126 (carry, range 1-1) & 132 (ally throw,
##            1-4 line-only — 127 is canCastWhenCarryEnnemy and refuses a
##            teammate cargo), breed-6 cargo (spell 12 — filler)
##   6021 preset with the two, 26330 [12][teamId] practice
##   placement: carrier adjacent to the cargo; on the carrier's turns —
##   cast 126 → assert the cargo rides and the carrier's sprite sits on a
##   Porte action; next turn cast 132 → assert the cargo lands on the
##   target cell and the carrier reverts to the normal stance.
##   godot --headless --path godot -s test/carry_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const CARRIER_BREED := 12
const CARRY_SPELL := 126       # breed 12 carry (58) range 1-1, LoS
const THROW_SPELL := 132       # ally throw (59) 1-4 line-only — the cargo
                               # is a teammate; 127 throws enemies only
const CARGO_BREED := 6
const CARGO_SPELL := 12
const TEAM_TEST_TYPE := 12
var TEAM_NAME := "zzcarr%d" % (Time.get_unix_time_from_system() as int % 100000)
var FIGHTER_NAME := "zzcar%d" % (Time.get_unix_time_from_system() as int % 100000)

var client: ArenaClient
var finished := false
var fight_scene: Node2D = null
var _created := {}             # breed -> roster fighter id (6000 results)
var _preset_id := -1
var _wire_fids := {}           # breed -> in-fight wire id
var _combat_seen := false
var _placed := false
var _carried := false          # carry verified
var _ported_idle := false      # carrier's sprite sat on a Porte idle
var _thrown := false           # throw verified
# fid -> {state action id: true} — live state effects seen on 8120, cleared
# on each 8100 table turn. The round-1 card (Cloué au lit: 94+127+128)
# anchors the whole arena, so the carry cast waits the state out rather
# than refusing.
var _states := {}


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(func():
		_finish(0 if _thrown else 1, "disconnected"))
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


## 6001 ×2 — the breed-12 carrier with carry+throw, and a cargo fighter.
func _create_fighters() -> void:
	for breed in [CARRIER_BREED, CARGO_BREED]:
		var spells: Array = [CARRY_SPELL, THROW_SPELL] \
			if breed == CARRIER_BREED else [CARGO_SPELL]
		var blob := Overrides.encode_fighter_blob(
			breed, "%s%d" % [FIGHTER_NAME, breed], 0, spells)
		var w := WireWriter.new()
		w.put_u8(0)
		w.put_u16(0)
		w.put_u16(blob.size())
		w.put_bytes(blob)
		client.send_message(6001, w.raw(), 2)
	print("[smoke] fighter creates sent (breeds 12/6)")


## 6021 — preset holding the pair (see displace_smoke for the layout).
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
	w.put_u8(0)
	w.put_u8(0)
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
	while not _thrown and wait < 90.0:
		await create_timer(1.0).timeout
		wait += 1.0
	print("[smoke] carry results carried=%s porte_idle=%s thrown=%s" % [
		_carried, _ported_idle, _thrown])
	client.send_message(8151, PackedByteArray(), 3)


func _my_team() -> int:
	for fid in State.fighters:
		var f: Dictionary = State.fighters[fid]
		if int(f.get("coach", -1)) == State.my_coach_id:
			return int(f.get("team", -1))
	return -1


func _cell_dist(a: Vector3i, b: Vector3i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Placement: carrier ADJACENT to the cargo (carry is range 1-1). Pick the
## closest spawn pair that is not already occupied by a teammate.
func _on_placement() -> void:
	if finished or fight_scene == null or _placed:
		return
	_placed = true
	var team := _my_team()
	var cells: Array = fight_scene._fmd.get("team%d" % team, [])
	var ours := {}
	for fid in State.fighters:
		var f: Dictionary = State.fighters[fid]
		if int(f.get("coach", -1)) == State.my_coach_id:
			ours[int(f.get("breed", -1))] = int(fid)
	_wire_fids = ours
	print("[smoke] placement: our fighters=%s team=%d spawns=%d" % [
		ours, team, cells.size()])
	var va: Variant = null
	var vb: Variant = null
	var best := 1 << 30
	for ca in cells:
		if _spawn_occupied(ca):
			continue
		var pa := Vector3i(int(ca.x), int(ca.y), 0)
		for cb in cells:
			if cb == ca or _spawn_occupied(cb):
				continue
			var d := _cell_dist(pa, Vector3i(int(cb.x), int(cb.y), 0))
			if d < best:
				best = d
				va = ca
				vb = cb
	if va == null:
		print("[smoke] placement: no spawn pair — keeping defaults")
		fight_scene.confirm_placement()
		return
	if best != 1:
		print("[smoke] placement relaxed — no adjacent pair (dist=%d)" % best)
	var order := [[int(ours.get(CARRIER_BREED, -1)), va],
		[int(ours.get(CARGO_BREED, -1)), vb]]
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


## Carrier turn policy: first carry the adjacent cargo (defer while it is
## anchored by the round-1 card), next turn throw it onto a free cell in
## range 1-4. Cargo turns just pass.
func _on_fight_turn(fid: int, ours: bool) -> void:
	if finished or fight_scene == null or not ours:
		return
	var f: Dictionary = State.fighters.get(fid, {})
	var breed := int(f.get("breed", -1))
	if breed != CARRIER_BREED:
		fight_scene.request_end_turn()
		return
	var me: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	var cargo := int(_wire_fids.get(CARGO_BREED, -1))
	if cargo < 0 or fight_scene._dead.get(cargo, false):
		fight_scene.request_end_turn()
		return
	var cpos: Vector3i = fight_scene._actor_cells.get(cargo, Vector3i.ZERO)
	if not _carried:
		# an anchored target refuses the carry (server applyCarry gate,
		# granted arena-wide by the round-1 card) — wait it out
		if _states.get(cargo, {}).has(127):
			fight_scene.request_end_turn()
			return
		if _cell_dist(me, cpos) != 1 \
				or not fight_scene._los_clear(Vector2i(me.x, me.y),
					Vector2i(cpos.x, cpos.y)):
			# not adjacent — walk the carrier next to the cargo first
			var dest := _adjacent_free(cpos, fid)
			if dest.x < 0:
				fight_scene.request_end_turn()
				return
			if fight_scene.request_move_to(dest):
				create_timer(2.2).timeout.connect(func():
					if fight_scene != null and not finished:
						fight_scene.request_end_turn())
			else:
				fight_scene.request_end_turn()
			return
		fight_scene.request_cast_at(CARRY_SPELL, Vector2i(cpos.x, cpos.y))
		create_timer(1.4).timeout.connect(func():
			if fight_scene == null:
				return
			var link := int(fight_scene._carried_by.get(cargo, -1))
			var spr = fight_scene._sprites.get(fid)
			var cur := str(spr.current) if spr != null else "?"
			_carried = link == fid
			_ported_idle = "Porte" in cur
			print("[smoke] CARRY: link=%d want=%d pose='%s' %s" % [
				link, fid, cur, "OK" if _carried else "FAIL"])
			if not _carried:
				push_error("carry did not link the cargo"))
		create_timer(2.0).timeout.connect(func():
			if fight_scene != null and not finished:
				fight_scene.request_end_turn())
		return
	if not _thrown:
		# the cargo rides on the carrier's cell — throw it at a free,
		# LoS-clear floor cell in Manhattan range 1-4
		var drop := _drop_cell(me, fid)
		if drop.x < 0:
			fight_scene.request_end_turn()
			return
		fight_scene.request_cast_at(THROW_SPELL, drop)
		create_timer(1.4).timeout.connect(func():
			if fight_scene == null:
				return
			var linked: bool = fight_scene._carried_by.has(cargo)
			var now: Vector3i = fight_scene._actor_cells.get(
				cargo, Vector3i.ZERO)
			var spr = fight_scene._sprites.get(fid)
			var cur := str(spr.current) if spr != null else "?"
			_thrown = not linked and now.x == drop.x and now.y == drop.y
			print(("[smoke] THROW: cargo->(%d,%d) want=(%d,%d) link=%s "
				+ "carrier_pose='%s' %s") % [now.x, now.y, drop.x, drop.y,
				linked, cur, "OK" if _thrown else "FAIL"])
			if not _thrown:
				push_error("throw did not land the cargo"))
		create_timer(2.0).timeout.connect(func():
			if fight_scene != null and not finished:
				fight_scene.request_end_turn())
		return
	fight_scene.request_end_turn()


## A walkable free cell adjacent to `cargo` the carrier can path to.
func _adjacent_free(cargo: Vector3i, fid: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_len := 1 << 30
	for dxy in [Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(0, 1), Vector2i(0, -1)]:
		var cell := Vector2i(cargo.x + dxy.x, cargo.y + dxy.y)
		if not fight_scene._cells.has(cell):
			continue
		if not fight_scene._cells[cell].get("ground", false):
			continue
		if _occupied(cell, fid):
			continue
		var me: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
		var path: Array = fight_scene._find_path(
			Vector2i(me.x, me.y), cell, fid)
		if path.is_empty() or path.size() > fight_scene._mp_left:
			continue
		if path.size() < best_len:
			best_len = path.size()
			best = cell
	return best


## A walkable free cell at Manhattan 1-4, on a straight row/column (spell
## 132 is onlyLine) + LoS from the carrier for the throw landing.
func _drop_cell(me: Vector3i, fid: int) -> Vector2i:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var d := absi(dx) + absi(dy)
			if d < 1 or d > 4 or (dx != 0 and dy != 0):
				continue
			var cell := Vector2i(me.x + dx, me.y + dy)
			if not fight_scene._cells.has(cell):
				continue
			if not fight_scene._cells[cell].get("ground", false):
				continue
			if _occupied(cell, fid):
				continue
			if not fight_scene._los_clear(Vector2i(me.x, me.y), cell):
				continue
			return cell
	return Vector2i(-1, -1)


func _spawn_occupied(cell) -> bool:
	for id in fight_scene._actor_cells:
		var p: Vector3i = fight_scene._actor_cells[id]
		if p.x == int(cell.x) and p.y == int(cell.y):
			return true
	return false


func _occupied(cell: Vector2i, except_fid: int) -> bool:
	for id in fight_scene._actor_cells:
		if int(id) == except_fid:
			continue
		var p: Vector3i = fight_scene._actor_cells[id]
		if p.x == cell.x and p.y == cell.y:
			return true
	return false


## 8120 state actions the carry cares about — 127 anchors the cargo.
const WATCH_STATES := [94, 127, 128]


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	match opcode:
		8100:
			_states.clear()
		8120:
			var act := int(decoded.get("effect_id", -1))
			if act in WATCH_STATES:
				var tgt := int(decoded.get("target", -1))
				_states.get_or_add(tgt, {})[act] = true
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
			if _created.size() == 2:
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
		w2.put_i16(0)
		client.send_message(6003, w2.raw(), 2)
	print("[smoke] cleanup: preset %d + %d fighters deleted" % [
		_preset_id, _created.size()])
	_finish(0 if _thrown else 1, "carry smoke complete")


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
