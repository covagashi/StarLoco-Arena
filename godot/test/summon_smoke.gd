extends SceneTree

## Summon smoke — full wire path for a mid-fight summon:
##   6001 create a breed-2 fighter whose loadout carries summon spell 51
##       (action 67, template 3 "Tofu", range 1-1)
##   6021 save a one-fighter team preset, 6030 push gives its id
##   26330 [12][teamId] practice fight vs the sparring dummy
##   on our fighter's turn, cast 51 onto a free adjacent cell
##   → the 8120 summon running-effect must spawn a fighter client-side:
##     sprite on the cell, "Tofu (<name>)" nameplate, a timeline chip right
##     after the caster, and the summon turn flagged NOT ours (server AI).
##   Then surrender + delete the preset and the fighter (fixtures clean).
##   godot --headless --path godot -s test/summon_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const SUMMON_BREED := 2
const SUMMON_SPELL := 51      # "Invocation of tofu" — action 67, tpl 3
const SUMMON_TPL := 3
const TEAM_TEST_TYPE := 12    # 26330 first field for a practice fight
## Unique per run — a crashed smoke leaves a preset/fighter behind and the
## server refuses a duplicate team name on the next run.
var TEAM_NAME := "zzsummon%d" % (Time.get_unix_time_from_system() as int % 100000)
var FIGHTER_NAME := "zzsmn%d" % (Time.get_unix_time_from_system() as int % 100000)

var client: ArenaClient
var finished := false
var _done_ok := false
var fight_scene: Node2D = null
var _created_fid := -1        # real fighter id from the 6000 result
var _preset_id := -1
var _caster_fid := -1         # wire id of our breed-2 fighter in the fight
var _summon_fid := -1
var _refused := {}            # cast cells the server already refused
var _pending_cell := Vector2i(-9999, -9999)
var _summon_turn_seen := false
var _combat_seen := false


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(func():
		_finish(0 if _done_ok else 1, "disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(90.0).timeout.connect(_finish.bind(1, "timeout"))


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


## 6001 create the breed-2 fighter carrying summon spell 51.
func _create_fighter() -> void:
	var blob := Overrides.encode_fighter_blob(
		SUMMON_BREED, FIGHTER_NAME, 0, [SUMMON_SPELL])
	var w := WireWriter.new()
	w.put_u8(0)
	w.put_u16(0)
	w.put_u16(blob.size())
	w.put_bytes(blob)
	client.send_message(6001, w.raw(), 2)
	print("[smoke] fighter create sent (breed %d, spell %d)" % [
		SUMMON_BREED, SUMMON_SPELL])


## 6021 save a preset holding exactly that fighter. sw_1 wire layout
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
	w.put_u8(1)
	w.put_i64(_created_fid)
	w.put_i64(State.my_coach_id)
	w.put_u8(0)                       # coach list — solo preset
	w.put_u8(0)                       # trailing pad byte
	client.send_message(6021, w.raw(), 2)
	print("[smoke] preset save sent (fighter %d)" % _created_fid)


## 26330 [i32 12][u16 teamId] — practice launch for the saved preset.
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
	# The cast fires from _on_fight_turn; the summon turn flag is checked
	# there too — surrender once both landed, or the script stalls.
	var wait := 0.0
	while not _summon_turn_seen and wait < 30.0:
		await create_timer(1.0).timeout
		wait += 1.0
	if not _summon_turn_seen:
		_finish(1, "summon turn never ran")
		return
	client.send_message(8151, PackedByteArray(), 3)


## Placement phase: keep the default start cell and confirm ready (8023) so
## combat begins.
func _on_placement() -> void:
	if finished or fight_scene == null:
		return
	create_timer(0.5).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.confirm_placement())


## Fight-turn policy: cast the summon spell on our fighter's first turn at
## a free adjacent cell; watch the 8120 spawn land; on the summon fid's own
## turn verify the client treated it as not-ours (server AI plays it).
func _on_fight_turn(fid: int, ours: bool) -> void:
	if finished or fight_scene == null:
		return
	if fid == _summon_fid:
		_summon_turn_seen = true
		print("[smoke] SUMMON TURN fid=%d ours=%s end_turn_disabled=%s" % [
			fid, ours, fight_scene._end_turn.disabled])
		if ours or not fight_scene._end_turn.disabled:
			push_error("summon turn must not be ours")
		return
	if not ours or _summon_fid >= 0:
		return
	var f: Dictionary = State.fighters.get(fid, {})
	if int(f.get("breed", -1)) != SUMMON_BREED:
		return   # a teammate's turn — not our caster
	_caster_fid = fid
	var cur: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	# spell 51 is range 1-1 + needs a WALKABLE free cell + LoS — pick an
	# adjacent ground cell nobody stands on and nobody refused yet.
	var free := Vector2i(-9999, -9999)
	for dxy in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cell := Vector2i(cur.x + dxy.x, cur.y + dxy.y)
		if _refused.has(cell):
			continue
		if not fight_scene._cells.has(cell):
			continue
		if not fight_scene._cells[cell].get("ground", false):
			continue
		var occupied := false
		for p in fight_scene._actor_cells.values():
			if p.x == cell.x and p.y == cell.y:
				occupied = true
				break
		if not occupied:
			free = cell
			break
	if free.x == -9999:
		print("[smoke] no free adjacent cell for the summon")
		fight_scene.request_end_turn()
		return
	_pending_cell = free
	if not fight_scene.request_cast_at(SUMMON_SPELL, free):
		push_error("summon cast request refused")
	print("[smoke] summon cast %d -> %s — awaiting 8120" % [SUMMON_SPELL, free])
	# give the summon broadcast + spawn a beat; on a refused cast mark the
	# cell tried and let the next turn pick another one.
	create_timer(1.2).timeout.connect(_check_summon_spawned)
	create_timer(1.8).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.request_end_turn())


func _check_summon_spawned() -> void:
	if fight_scene == null or finished:
		return
	for id in State.fighters:
		var f: Dictionary = State.fighters[id]
		if not f.get("summon", false):
			continue
		_summon_fid = int(id)
		break
	if _summon_fid < 0:
		# cast refused server-side (cell not summonable / no LoS) — mark it
		# tried; the next turn picks another adjacent ground cell.
		_refused[_pending_cell] = true
		print("[smoke] summon cast at %s refused — will retry" % _pending_cell)
		return
	var spr = fight_scene._sprites.get(_summon_fid)
	var tl: Array = State.fight_data.get("timeline", [])
	var ci := tl.find(_caster_fid)
	var si := tl.find(_summon_fid)
	var f: Dictionary = State.fighters[_summon_fid]
	print("[smoke] SUMMON fid=%d name='%s' sprite=%s tl[caster=%d,summon=%d]" % [
		_summon_fid, f.get("name"), spr != null, ci, si])
	if spr == null:
		push_error("summon sprite missing")
	if si != ci + 1:
		push_error("summon not inserted right after caster in timeline")


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	match opcode:
		1024:
			if decoded.get("result") == 0:
				print("[smoke] auth OK")
			else:
				_finish(1, "auth refused %s" % decoded.get("result"))
		2048:
			_send_coach("test")   # refused harmlessly — account has a coach
		2052:
			State.my_coach_id = int(decoded.get("id", -1))
			print("[smoke] coach id=%s name='%s'" % [
				decoded.get("id"), decoded.get("name")])
		4600:
			State.current_world = int(decoded.get("world_id", -1))
		4516:
			_create_fighter()
		6000:
			if int(decoded.get("result", 1)) != 0:
				_finish(1, "fighter create refused %s" % decoded.get("result"))
				return
			_created_fid = int(decoded.get("fighter_id", -1))
			var sp: Array = decoded.get("fighter", {}).get("spells", [])
			print("[smoke] fighter created id=%d spells=%s" % [_created_fid, sp])
			if SUMMON_SPELL not in sp:
				_finish(1, "summon spell not in created loadout")
				return
			_save_preset()
		6020:
			print("[smoke] preset save ack status=%s" % payload.hex_encode())
		6030:
			var best := -1
			for p in decoded.get("presets", []):
				if str(p.get("name", "")) != TEAM_NAME:
					continue
				for m in p.get("fighters", []):
					if int(m.get("id", -1)) == _created_fid:
						best = maxi(best, int(p.get("id", -1)))
			if best != _preset_id:
				_preset_id = best
				print("[smoke] preset id=%d for fighter %d" % [
					_preset_id, _created_fid])
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


## Leave the roster clean: delete the preset (6023) then the fighter (6003).
func _cleanup() -> void:
	var w := WireWriter.new()
	w.put_i64(_preset_id)
	w.put_i16(0)
	w.put_i16(0)
	client.send_message(6023, w.raw(), 2)
	var w2 := WireWriter.new()
	w2.put_i64(_created_fid)
	w2.put_i16(0)
	client.send_message(6003, w2.raw(), 2)
	print("[smoke] cleanup: preset %d + fighter %d deleted" % [
		_preset_id, _created_fid])
	_done_ok = true
	_finish(0, "summon smoke complete")


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
