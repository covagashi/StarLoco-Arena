extends SceneTree

## Fight-entry smoke: login, launch overworld challenge 34 (single-client
## fight), decode 8000 into State, then instantiate fight_view — which
## consumes State.net.message_received itself: 4102 placements, phase
## acks (8011/8023), everything after.
##   godot --headless --path godot -s test/fight_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const Spells := preload("res://src/gamedata/spells.gd")
const FighterCards := preload("res://src/gamedata/fightercards.gd")
const Areas := preload("res://src/gamedata/areas.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

var client: ArenaClient
var finished := false
var fight_scene: Node2D = null
var _combat_seen := false
var _card_landed := false
var _timeline_checked := false
var _faced := false
var _range_seen := false
var _path_seen := false
var _buff_seen := false
var _area_seen := false
var _cd_seen := false


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	# NOTE: the Session autoload still gets instantiated under -s (only the
	# global identifier fails to resolve) and its _ready overwrites State.net
	# with its own idle client — so we re-assign before opening fight_view.
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(_finish.bind(1, "disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(75.0).timeout.connect(_finish.bind(1, "timeout"))


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


func _send_coach(coach_name: String) -> void:
	var n := CP1252.encode(coach_name)
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	client.send_message(2049, w.raw(), 2)


func _launch_challenge() -> void:
	var w := WireWriter.new()
	w.put_i32(34)      # challenge id 34 — "Démon de la 58ème minute"
	w.put_u16(99)      # 99 = overworld challenge (not team preset)
	client.send_message(26330, w.raw(), 2)
	print("[smoke] challenge 34 sent")


func _show_fight() -> void:
	# fight_view._ready drains client.pending itself, then hooks
	# message_received — same path the real scene-change flow takes.
	State.net = client
	# We're root.add_child-ing, not change_scene_to_file — the previous
	# instance survives a "scene change", so drop it ourselves (remove_child
	# fires _exit_tree synchronously → its net subscription is released).
	if fight_scene != null:
		root.remove_child(fight_scene)
		fight_scene.queue_free()
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	# Scripted policy: on our turns try a short move (exercises the real
	# 4503 path + 4524 walk animation), then end the turn.
	fight_scene.turn_began.connect(_on_fight_turn)
	fight_scene.placement_began.connect(_on_placement)
	root.add_child(fight_scene)
	# Capture mid-combat: first turn means actors placed + phases done.
	_combat_seen = false
	var deadline := 0.0
	while not _combat_seen and deadline < 12.0:
		await create_timer(0.25).timeout
		deadline += 0.25
	await create_timer(1.5).timeout   # let a couple of turns land
	# The dummy/headless renderer has no viewport texture — skip the capture
	# rather than error on root.get_texture().
	if DisplayServer.get_name() != "headless":
		var tex := root.get_texture()
		var img := tex.get_image() if tex != null else null
		if img != null:
			img.save_png("/tmp/fight_live.png")
			print("[smoke] combat shot -> /tmp/fight_live.png %dx%d"
				% [img.get_width(), img.get_height()])
	# Surrender fires inside _try_surrender once the card lands (≤ ~36s).
	var wait := 0.0
	while not _card_landed and wait < 40.0:
		await create_timer(1.0).timeout
		wait += 1.0
	await create_timer(3.0).timeout
	_finish(0, "fight rendered")


## placement_began policy: hop the selected fighter to another of our own
## start cells (exercises 8021 -> 8022), then confirm ready (8023).
func _on_placement() -> void:
	if finished or fight_scene == null:
		return
	await create_timer(0.4).timeout
	if finished or fight_scene == null:
		return
	var t: int = fight_scene._my_team()
	var cur: Vector3i = fight_scene._actor_cells.get(
		fight_scene._selected, Vector3i.ZERO)
	for c in fight_scene._fmd.get("team%d" % t, []):
		var cell := Vector2i(int(c.x), int(c.y))
		if cur.x == cell.x and cur.y == cell.y:
			continue
		if fight_scene.request_place_at(cell):
			print("[smoke] scripted placement -> %s" % cell)
			break
	create_timer(0.6).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.confirm_placement())


## turn_began policy for the harness: one short move request, then pass.
func _on_fight_turn(fid: int, ours: bool) -> void:
	# Timeline check (runs on every 8104): chips = 8000 timeline size and
	# exactly the acting fighter's chip pressed.
	if not _timeline_checked and fight_scene != null:
		_timeline_checked = true
		var tl: HBoxContainer = fight_scene.get_node("UI/TopBar/Timeline")
		var want: Array = State.fight_data.get("timeline", [])
		var pressed := 0
		for i in tl.get_child_count():
			if tl.get_child(i).button_pressed:
				pressed += 1
		print("[smoke] TIMELINE chips=%d expected=%d pressed=%d cur=%d" % [
			tl.get_child_count(), want.size(), pressed, fid])
		if tl.get_child_count() != want.size() or want.size() == 0:
			push_error("timeline chips missing")
		if pressed != 1:
			push_error("timeline: acting chip not highlighted")
	# Turn clock — every 8104 (re)starts the 30s countdown (server turnClock);
	# the label itself paints next frame so we only check the counter here.
	if fight_scene != null and fight_scene._turn_left <= 0.0:
		push_error("turn timer not started on turn begin")
	if not ours or finished:
		return
	var cur: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	# Walk preview — hovering a free ground cell on our turn produces the BFS
	# step list the click would send; hovering our own cell stays empty.
	if not _path_seen:
		_path_seen = true
		var occupied := {}
		for id in fight_scene._actor_cells:
			var ap: Vector3i = fight_scene._actor_cells[id]
			occupied[Vector2i(ap.x, ap.y)] = true
		var dest := Vector2i(-9999, -9999)
		# Manhattan ≤3 does not imply reachable (ground pockets, walls) —
		# keep the first candidate the BFS itself can path to.
		for pos in fight_scene._cells:
			var c: Dictionary = fight_scene._cells[pos]
			var dd := absi(pos.x - cur.x) + absi(pos.y - cur.y)
			if not c.ground or dd < 1 or dd > 3 or occupied.has(pos):
				continue
			if not fight_scene._find_path(Vector2i(cur.x, cur.y), pos, fid).is_empty():
				dest = pos
				break
		fight_scene._hover = dest
		var pv: Array = fight_scene._preview_path()
		print("[smoke] PATH PREVIEW hover=%s steps=%d mp=%d" % [
			dest, pv.size(), fight_scene._mp_left])
		if dest.x != -9999 and pv.is_empty():
			push_error("path preview empty for a reachable cell")
		if pv.size() > 0 and Vector2i(pv[-1].x, pv[-1].y) != dest:
			push_error("path preview does not land on the hovered cell")
		fight_scene._hover = Vector2i(cur.x, cur.y)
		if not fight_scene._preview_path().is_empty():
			push_error("path preview on own cell should be empty")
		fight_scene._hover = Vector2i(-9999, -9999)
	# Buff strip — fabricate the exact 8121 wire bytes the resync path emits
	# (i32 actionId + u16 blobLen + BinarSerial blob + i64 fid + i16 expiry
	# + i8) for a finite +AP buff and an infinite Invisible, then age them
	# through a synthetic table turn: finite expires, infinite persists.
	if not _buff_seen:
		_buff_seen = true
		var mk_blob := func(gen: int, val: int) -> PackedByteArray:
			var b := WireWriter.new()
			b.put_u8(1)          # one part
			b.put_u8(0)          # part 0
			b.put_i32(6)         # abs offset of part 0's idx byte
			b.put_u8(0)          # part 0 idx
			b.put_i64(fid)       # caster
			b.put_i64(fid)       # target
			b.put_i32(gen)       # genEffect (effectId)
			b.put_i32(0)         # x
			b.put_i32(0)         # y
			b.put_u16(0)         # z
			b.put_i32(val)       # value
			return b.raw()
		var t0: int = fight_scene._turns_taken.get(fid, 0)
		# [action, effectId, value, expiry] — expiry is absolute against
		# the fighter's own turn counter; -1 encodes infinite
		for fx in [[99, 1418, 3, t0 + 1], [57, 1485, 0, -1]]:
			var blob: PackedByteArray = mk_blob.call(fx[1], fx[2])
			var w := WireWriter.new()
			w.put_i32(fx[0])
			w.put_u16(blob.size())
			w.put_bytes(blob)
			w.put_i64(fid)
			w.put_i16(fx[3])
			w.put_u8(0)
			fight_scene._on_net_message(8121, w.raw())
		var bl: Array = fight_scene._buffs.get(fid, [])
		print("[smoke] BUFFS chips=%s" % [bl])
		if bl.size() != 2:
			push_error("buff strip: expected 2 chips, got %d" % bl.size())
		elif bl[0].label != "+3 AP" or bl[1].label != "Invisible":
			push_error("buff strip: wrong labels %s / %s" % [
				bl[0].label, bl[1].label])
		var t := WireWriter.new()
		t.put_i32(0)
		t.put_i32(0)
		t.put_u8(9)
		t.put_i32(0)
		fight_scene._on_net_message(8100, t.raw())
		var bl2: Array = fight_scene._buffs.get(fid, [])
		print("[smoke] BUFFS after 8100 chips=%s" % [bl2])
		if bl2.size() != 1 or not bool(bl2[0].inf):
			push_error("buff strip: finite chip did not expire / infinite aged")
	# Effect areas — fabricate the 8120 creation broadcasts (action 66): a
	# one-shot trap (tpl 1, maxExec 1) on the caster's cell and a r2 glyph
	# (tpl 1015, unlimited). The trap's inner-effect 8120 (gen 9670, same
	# caster, victim inside the footprint) must count the fire and erase it;
	# the unlimited glyph stays.
	if not _area_seen:
		_area_seen = true
		var mk8120 := func(action: int, gen: int, val: int, tx: int,
				ty: int, tgt: int) -> PackedByteArray:
			var b := WireWriter.new()
			b.put_u8(1)
			b.put_u8(0)
			b.put_i32(6)
			b.put_u8(0)
			b.put_i64(fid)      # caster
			b.put_i64(tgt)      # target
			b.put_i32(gen)      # genEffect
			b.put_i32(tx)
			b.put_i32(ty)
			b.put_u16(0)
			b.put_i32(val)      # value = template id for action 66
			var blob: PackedByteArray = b.raw()
			var w := WireWriter.new()
			w.put_i32(0)
			w.put_i32(-1)
			w.put_u8(0)
			w.put_u8(0)
			w.put_i32(0)
			w.put_i32(action)
			w.put_u16(blob.size())
			w.put_bytes(blob)
			return w.raw()
		var cc: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
		fight_scene._on_net_message(8120, mk8120.call(66, 0, 1, cc.x, cc.y, fid))
		fight_scene._on_net_message(8120, mk8120.call(66, 0, 1015,
			cc.x, cc.y, fid))
		print("[smoke] AREAS placed=%d r2footprint=%d" % [
			fight_scene._areas.size(),
			Areas.footprint(1015, cc).size()])
		if fight_scene._areas.size() != 2:
			push_error("effect areas: expected 2 placed, got %d"
				% fight_scene._areas.size())
		elif Areas.footprint(1015, cc).size() != 13:
			push_error("effect areas: r2 diamond should cover 13 cells")
		fight_scene._on_net_message(8120, mk8120.call(0, 9670, 0,
			cc.x, cc.y, fid))
		print("[smoke] AREAS after fire=%d" % fight_scene._areas.size())
		if fight_scene._areas.size() != 1:
			push_error("effect areas: one-shot trap should die after firing")
	# Cast-frequency locks — fabricate an 8110 for spell 32 (cd=5): the button
	# must lock immediately and unlock only once _table_turn advances 5.
	if not _cd_seen:
		_cd_seen = true
		var cc: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
		var w := WireWriter.new()
		w.put_i32(0); w.put_i32(-1)
		w.put_i64(fid)
		w.put_i32(32)
		w.put_u8(0); w.put_u8(0)
		w.put_i32(cc.x); w.put_i32(cc.y); w.put_u16(0)
		var t0: int = fight_scene._table_turn
		fight_scene._on_net_message(8110, w.raw())
		var locked: bool = fight_scene._spell_locked(32)
		fight_scene._table_turn = t0 + 4
		var still: bool = fight_scene._spell_locked(32)
		fight_scene._table_turn = t0 + 5
		var open: bool = not fight_scene._spell_locked(32)
		fight_scene._table_turn = t0
		print("[smoke] COOLDOWN locked=%s @+4=%s @+5open=%s" % [
			locked, still, open])
		if not (locked and still and open):
			push_error("spell cooldown: expected lock→+4 held→+5 open")
	# Exercise the cast path first (from the CURRENT cell — the 4503 below is
	# still in flight). Weapon (8111) needs an orthogonally adjacent enemy;
	# a known spell goes at the closest enemy cell. Server validates
	# range/LoS — silence means refused, which is fine for the harness.
	var f: Dictionary = State.fighters.get(fid, {})
	# Fire the equipped card's ACTIVE ability (8107) at an enemy inside its
	# range band — mirrors the equipment button on the spell bar. Retried on
	# every own turn until the broadcast (8108) lands.
	if not _card_landed:
		for ec in f.get("cards", []):
			var cid := int(ec.get("id", -1))
			if not FighterCards.usable(cid):
				continue
			var ab: Dictionary = FighterCards.ability(cid)
			var rmin := int(ab.get("min", 0))
			var rmax := int(ab.get("max", 0))
			var target := Vector2i(-9999, -9999)
			for id in fight_scene._actor_cells:
				var e: Dictionary = State.fighters.get(id, {})
				if e.is_empty() or int(e.get("coach", -1)) == State.my_coach_id:
					continue
				var p: Vector3i = fight_scene._actor_cells[id]
				var dist := absi(p.x - cur.x) + absi(p.y - cur.y)
				if dist >= rmin and dist <= rmax:
					target = Vector2i(p.x, p.y)
					break
			if target.x == -9999:
				# The effects resolve at the cell — an empty in-band cell still
				# fires the 8107 -> 8108 round-trip (nothing to hit is fine).
				for dx in range(rmin, rmax + 1):
					target = Vector2i(cur.x + dx, cur.y)
					break
			if target.x != -9999 and fight_scene.request_card_at(cid, target):
				print("[smoke] scripted card %d -> %s" % [cid, target])
	# facing (4521) — free action, once per fight
	if not _faced:
		_faced = true
		fight_scene._on_face_pressed()
		print("[smoke] face-change sent — expecting 4522")
	var spells: Array = f.get("spells", [])
	# prefer the longest-range spell we can afford — melee spells whiff silently
	var sid := -2
	var best_range := 0
	for s in spells:
		var sm := Spells.meta(int(s))
		var rng := int(sm.get("max", 0))
		var ap := int(sm.get("ap", 99))
		if rng > best_range and ap <= fight_scene._ap_left:
			best_range = rng
			sid = int(s)
	var target := Vector2i(-9999, -9999)
	for id in fight_scene._actor_cells:
		var e: Dictionary = State.fighters.get(id, {})
		if e.is_empty() or int(e.get("coach", -1)) == State.my_coach_id:
			continue
		var p: Vector3i = fight_scene._actor_cells[id]
		var dd := absi(p.x - cur.x) + absi(p.y - cur.y)
		if sid >= 0:
			# any enemy in sight — the server decides legality
			if target.x == -9999 or dd < absi(target.x - cur.x) + absi(target.y - cur.y):
				target = Vector2i(p.x, p.y)
		elif dd == 1:
			target = Vector2i(p.x, p.y)
			break
	# arming a spell must light the range overlay (zone de portée) — the
	# request_cast_at below disarms and clears it again.
	if sid >= 0 and not _range_seen:
		_range_seen = true
		fight_scene._on_spell_button(sid)
		var legal := 0
		for k in fight_scene._range_overlay:
			if fight_scene._range_overlay[k] == 2:
				legal += 1
		print("[smoke] RANGE OVERLAY sid=%d cells=%d legal=%d" % [
			sid, fight_scene._range_overlay.size(), legal])
		if fight_scene._range_overlay.is_empty():
			push_error("armed spell produced no range overlay")
	if target.x != -9999 and fight_scene.request_cast_at(sid, target):
		print("[smoke] scripted cast %s -> %s" % [
			"spell %d" % sid if sid >= 0 else "weapon", target])
	# move toward the closest enemy — reaches weapon adjacency in a few rounds
	var enemy := Vector2i(-9999, -9999)
	var ebest := 1 << 30
	for id in fight_scene._actor_cells:
		var e: Dictionary = State.fighters.get(id, {})
		if e.is_empty() or int(e.get("coach", -1)) == State.my_coach_id:
			continue
		var p: Vector3i = fight_scene._actor_cells[id]
		var dd := absi(p.x - cur.x) + absi(p.y - cur.y)
		if dd < ebest:
			ebest = dd
			enemy = Vector2i(p.x, p.y)
	var moved := false
	if enemy.x != -9999:
		# step order: whichever axis closes distance first
		var sx := int(sign(enemy.x - cur.x))
		var sy := int(sign(enemy.y - cur.y))
		var opts: Array = []
		if sx != 0:
			opts.append(Vector2i(sx, 0))
		if sy != 0:
			opts.append(Vector2i(0, sy))
		opts.append_array([Vector2i(1, 0), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(0, -1)])
		for d in opts:
			if fight_scene.request_move_to(Vector2i(cur.x, cur.y) + d):
				print("[smoke] scripted move fid=%d -> %s" % [fid, Vector2i(cur.x, cur.y) + d])
				moved = true
				break
	if not moved:
		print("[smoke] no move target for fid=%d at %s" % [fid, cur])
	# give the 4524 broadcast a beat to land, then pass the turn
	create_timer(1.0).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.request_end_turn())


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	match opcode:
		1024:
			if decoded.get("result") == 0:
				print("[smoke] 1024 auth OK")
			else:
				_finish(1, "auth refused %s" % decoded.get("result"))
		2048:
			_send_coach("fightone")
		2052:
			State.my_coach_id = int(decoded.get("id", -1))
			print("[smoke] coach id=%s name='%s'" % [
				decoded.get("id"), decoded.get("name")])
		4600:
			State.current_world = int(decoded.get("world_id", -1))
			print("[smoke] enter instance world=%s pos=(%s,%s)" % [
				State.current_world, decoded.get("x"), decoded.get("y")])
			# Post-fight return: world != arena → drop the fight view (the
			# scene also self-transitions via change_scene_to_file, which only
			# frees the tracked current_scene — none under -s).
			if fight_scene != null and State.current_world != State.fight_world:
				root.remove_child(fight_scene)
				fight_scene.queue_free()
				fight_scene = null
				# Late combat ops (8104s still in flight at 8300) sit in
				# pending — flush so the NEXT fight's _ready doesn't drain
				# stale turn_begins and fire bogus scripted moves.
				client.drain()
		4516:
			_launch_challenge()
		8000:
			var raw: PackedByteArray = payload
			print("[smoke] FIGHT CREATION — %d bytes" % raw.size())
			var fh := FileAccess.open("/tmp/fight8000.bin", FileAccess.WRITE)
			fh.store_buffer(raw)
			fh.close()
			State.fight_world = State.current_world
			State.fight_data = decoded
			State.index_fighters(decoded)
			for t in decoded.get("teams", []):
				for f in t.get("fighters", []):
					print("[smoke]   fighter '%s' breed=%d team=%d id=%d"
						% [f.name, f.get("breed", -1), t.id, f.id])
			_show_fight()
		4102:
			print("[smoke] ACTOR_APPEAR: %s" % str(decoded.get("actors", [])))
		8040:
			_combat_seen = true
			print("[smoke] COMBAT STARTED — surrender once the card lands")
			_try_surrender(0)
		8300:
			print("[smoke] END FIGHT (8300)")
		4522:
			print("[smoke]   4522 facing hex=%s" % payload.hex_encode())
		8108:
			_card_landed = true
			print("[smoke]   8108 card ability raw=%dB hex=%s" % [
				payload.size(), payload.hex_encode()])
		8100, 8104, 8106:
			print("[smoke]   op %d raw=%dB hex=%s" % [
				opcode, payload.size(), payload.hex_encode()])
		26310:
			_finish(1, "challenge refused")
		_:
			print("[smoke]   op %d" % opcode)


## Surrenders once the equipment ability has landed (or after ~32s, so the
## smoke cannot hang if the card never reaches range).
func _try_surrender(elapsed: float) -> void:
	create_timer(4.0).timeout.connect(func():
		if finished or fight_scene == null:
			return
		if not _card_landed and elapsed < 32.0:
			_try_surrender(elapsed + 4.0)
			return
		client.send_message(8151, PackedByteArray(), 3))


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
