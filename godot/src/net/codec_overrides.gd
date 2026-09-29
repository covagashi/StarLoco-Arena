extends RefCounted

## Hand-written decoders for the messages the generator marks "handler".
## Dispatch is by handler name; each returns a Dictionary of decoded fields.

const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")


static func dispatch(handler: String, opcode: int, r: WireReader) -> Dictionary:
	match handler:
		"coach_info": return _coach_info(r)
		"part_table": return _part_table(r)
		"actor_spawn": return _actor_spawn(r)
		"fighter_list": return _fighter_list(r)
		"fighter_create_result": return _fighter_create_result(r)
		"friend_list": return _friend_list(r)
		"ignore_list": return _ignore_list(r)
		"wallet": return _wallet(r)
		"inventory": return _inventory(r)
		"stat_map": return _stat_map(r)
		"preset_list": return _preset_list(r)
		"fight_creation": return _fight_creation(r)
		"actor_appear": return _actor_appear(r)
		"placement_move": return _placement_move(r)
		"running_effect": return _running_effect(r)
		_:
			return {"_opcode": opcode, "_raw": r.get_rest(),
					"_handler": handler}


## Opcode 2052 — LocalCoach at flags=4014, source order, mirrors
## server/internal/handshake/coach.go:238-291. Blobs are length-prefixed and
## captured raw; their internals decode on demand.
static func _coach_info(r: WireReader) -> Dictionary:
	var out := {}
	out.id = r.get_i64()
	out.name = r.get_str("u8")
	out.skin = r.get_u8()
	out.hair = r.get_u8()
	out.sex = r.get_u8()
	out.look = r.get_u16()
	out.tournament_points = r.get_i32()
	out.ladder_blob = r.get_bytes(r.get_u16())
	out.standing = r.get_i32()
	out.guild_blob = r.get_bytes(r.get_u16())
	out.tome_blob = r.get_bytes(r.get_u16())
	out.card_inv_blob = r.get_bytes(r.get_u16())
	out.equip_blob = r.get_bytes(r.get_u16())
	out.criteria_blob = r.get_bytes(r.get_u16())
	out.ladder_count = r.get_u8()
	out.admin_right = r.get_i32()
	return out


## Generic part-table container (aJj.ad — PROTOCOL-parttable.md §1):
##   [u8 partCount] partCount × {u8 partId, i32 offset}
##   part bytes = buffer[offset+1 .. nextOffset-1]; last ends at limit-1.
## Returns {"parts": {partId: PackedByteArray}} — per-part decoders layer on top.
static func _part_table(r: WireReader) -> Dictionary:
	var buf: PackedByteArray = r.buffer()
	var count := r.get_u8()
	var index := []
	for i in count:
		index.append({"id": r.get_u8(), "off": r.get_i32()})
	var parts := {}
	for i in index.size():
		var start: int = index[i].off + 1
		var end: int = (index[i + 1].off - 1) if i + 1 < index.size() else buf.size() - 1
		parts[index[i].id] = buf.slice(start, end)
	return {"parts": parts}


## Opcode 4096 — i32 prefix: negative = that many raw bytes follow;
## positive = zlib-inflated length (wa_1.java:75-102).
static func _actor_spawn(r: WireReader) -> Dictionary:
	var n := r.get_i32()
	if n < 0:
		return {"actors_raw": r.get_bytes(-n), "compressed": false}
	var raw := r.get_bytes(r.remaining())
	var data := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	return {"actors_raw": data, "compressed": not data.is_empty()}


## Opcode 6006 — [i64 leadId][u8 count]{i64 id, u16 len, et_2 blob}.
## et_2 layout (server fighter_codec.go, decodeFighterBlob):
##   [u8 type][i16 budget][u8 breed](i32 custom if breed==0)[str8 name]
##   [u8 sex][i8 ey](u8 hair,skin,eye only if ey<0)
##   [i16 len]{i32 spells}[i16 len]{i16 slot, i32 cardId}
##   if type==2 evolution tail:
##   [i32 board][i32 xp][i32 totalXp][u8 tired][u8 morale][u8 state]
##   [i16 sx][i16 sy][i16 n]{i32 sphere}[u8 n]{i16 cond,u8 lvl}
##   [i16 n]{i32 passive}[i16 n]{i32 passiveSet}
static func _fighter_list(r: WireReader) -> Dictionary:
	var out := {"lead_id": r.get_i64(), "fighters": []}
	var count := r.get_u8()
	for i in count:
		var fid := r.get_i64()
		var blob := r.get_bytes(r.get_u16())
		var f := _et2_fighter(blob)
		f["id"] = fid
		out.fighters.append(f)
	return out


static func _et2_fighter(blob: PackedByteArray) -> Dictionary:
	var br := WireReader.new(blob)
	var f := {"type": br.get_u8(), "budget": br.get_i16(),
		"breed": br.get_u8(), "spells": [], "cards": []}
	if f.breed == 0:
		br.get_i32()
	f.name = br.get_str("u8")
	f.sex = br.get_u8()
	if br.get_i8() < 0:      # ey<0 → appearance colors present
		f.hair = br.get_u8()
		f.skin = br.get_u8()
		f.eye = br.get_u8()
	var spell_bytes := br.get_i16()
	for i in spell_bytes / 4:
		f.spells.append(br.get_i32())
	var card_bytes := br.get_i16()
	for i in card_bytes / 6:
		f.cards.append({"slot": br.get_i16(), "id": br.get_i32()})
	if f.type == 2 and br.remaining() >= 18:
		f.board = br.get_i32()
		f.xp = br.get_i32()
		f.total_xp = br.get_i32()
		f.tiredness = br.get_u8()
		f.morale = br.get_u8()
		f.state = br.get_u8()
		f.sphere_x = br.get_i16()
		f.sphere_y = br.get_i16()
		f.spheres = []
		for i in br.get_i16():
			f.spheres.append(br.get_i32())
		f.conditions = []
		for i in br.get_u8():
			f.conditions.append({"id": br.get_i16(), "level": br.get_u8()})
		f.passives = []
		for i in br.get_i16():
			f.passives.append(br.get_i32())
		f.passive_sets = []
		for i in br.get_i16():
			f.passive_sets.append(br.get_i32())
	return f


## Opcode 6000 — [u8 result]; on success (0): [i64 coachId][i64 fighterId]
## [u16 len][et_2 blob][u8 flag][i16 slot]. Failure results carry only the
## status byte (1 generic, 20 roster full, …).
static func _fighter_create_result(r: WireReader) -> Dictionary:
	var out := {"result": r.get_u8()}
	if out.result != 0 or r.remaining() < 8:
		return out
	out.coach_id = r.get_i64()
	out.fighter_id = r.get_i64()
	out.fighter = _et2_fighter(r.get_bytes(r.get_u16()))
	if r.remaining() >= 3:
		out.flag = r.get_u8()
		out.slot = r.get_i16()
	return out


## Encode the et_2 blob for a fighter-create request (aNb.java → 6001):
## minimal classic fighter — type 1, no spells/cards, default colors.
static func encode_fighter_blob(breed: int, fname: String, sex: int) -> PackedByteArray:
	var w := WireWriter.new()
	w.put_u8(1)                # classic (2 = evolution roster)
	w.put_i16(400)             # budget — server recomputes from loadout anyway
	w.put_u8(breed)
	w.put_str(fname, "u8")
	w.put_u8(sex & 1)
	w.put_i8(-1)               # ey < 0 → color triple follows
	w.put_u8(0)                # hair
	w.put_u8(0)                # skin
	w.put_u8(0)                # eye
	w.put_i16(0)               # spell blob: empty (creation without purchases)
	w.put_i16(0)               # card blob: empty
	return w.raw()


## Opcode 3144 — [u8 n]{u16 len, friend blob}. Blob internals (presence,
## status, guild) decode later.
static func _friend_list(r: WireReader) -> Dictionary:
	var out := {"friends": []}
	for i in r.get_u8():
		out.friends.append(r.get_bytes(r.get_u16()))
	return out


## Opcode 3146 — [u8 n]{str:u8 name}.
static func _ignore_list(r: WireReader) -> Dictionary:
	var out := {"names": []}
	for i in r.get_u8():
		out.names.append(r.get_str("u8"))
	return out


## Opcode 4001 — [u8 n]{u8 currencyType, i32 amount}.
static func _wallet(r: WireReader) -> Dictionary:
	var out := {"currencies": []}
	for i in r.get_u8():
		out.currencies.append({"type": r.get_u8(), "amount": r.get_i32()})
	return out


## Opcode 5200 — [u16][u16][u16 n]{i32 cardId, u16 qty}[u16]
## (handlers_inventory.go:43). Leading/trailing u16s captured verbatim.
static func _inventory(r: WireReader) -> Dictionary:
	var out := {"head0": r.get_u16(), "head1": r.get_u16(), "cards": []}
	for i in r.get_u16():
		out.cards.append({"card_id": r.get_i32(), "qty": r.get_u16()})
	out.tail = r.get_u16() if r.remaining() >= 2 else 0
	return out


## Opcodes 2400/2401 — rs_2 typed stat-map:
## [u16 blobLen][u16 modelId][i64 owner][u16 n]{u16 statId, u8 type, value}
## value: type 1 = i32, 2 = i64, 3 = f32 (OPCODE-INVENTORY.md:216).
static func _stat_map(r: WireReader) -> Dictionary:
	var blob := r.get_bytes(r.get_u16())
	var br := WireReader.new(blob)
	var out := {"model_id": br.get_u16(), "owner": br.get_i64(), "stats": []}
	for i in br.get_u16():
		var entry := {"id": br.get_u16(), "type": br.get_u8()}
		match entry.type:
			1: entry.value = br.get_i32()
			2: entry.value = br.get_i64()
			3: entry.value = br.get_f32()
		out.stats.append(entry)
	return out


## Opcode 6030 — [u8 n]{u16 len, sw_1 preset blob}[u8 n]{coaches}.
## sw_1 (server team_codec.go, encodeTeamPreset):
##   [i16 type][i16 teamId][i16 gameMode][str8 name]
##   [u8 app×4 only if type in -5,-6,-7]
##   [u8 n]{i64 fighterId, i64 ownerCoachId}
##   [u8 n]{i64 coachId}
static func _preset_list(r: WireReader) -> Dictionary:
	var out := {"presets": []}
	for i in r.get_u8():
		# presets are RAW sw_1 blobs back-to-back (no length prefix) —
		# each self-delimits via its u8 counts
		var p := {"type": r.get_i16(), "id": r.get_i16(),
			"game_mode": r.get_i16(), "name": r.get_str("u8")}
		if p.type in [-5, -6, -7]:
			p.appearance = [r.get_u8(), r.get_u8(), r.get_u8(), r.get_u8()]
		p.fighters = []
		for j in r.get_u8():
			p.fighters.append({"id": r.get_i64(), "owner": r.get_i64()})
		p.coaches = []
		for j in r.get_u8():
			p.coaches.append(r.get_i64())
		out.presets.append(p)
	out.coaches = []
	if r.remaining() > 0:
		# trailing coach block (ar_0): [u8 n]{i64 id, u8 len, blob}
		for i in r.get_u8():
			out.coaches.append({"id": r.get_i64(),
				"blob": r.get_bytes(r.get_u8())})
	return out


## Opcode 8000 — FightCreation. Mirrors aat_2.ac() in the decompiled client,
## cross-checked byte-for-byte against server/internal/game/fight_packets.go.
##
##   i8 aV | i16 len + keyBlob | i32 fightType | i64 fightId | i8 |
##   i64 + i32 | u8 nCoaches × coach{ i64 id, str8 name, u8×3, i16,
##   i16-blob, i16-blob } + u16 len + reportBlob |
##   u8 nTeams × team{ i8 id, str8 name, u8 nPlacements ×
##     {i64 fid, i64 aj, i16 cell, u8 nd}, u8 nFighters ×
##     u8 type + fighter + i64 coachLink } |
##   u8 n × i64 timeline | u8 n × i32 specialCells |
##   u8 n × {i64,i64,i32,i32,i16} specialDetail | i16 aI |
##   i32 teamStats (0 → skip per-coach stats) | u8 dd | tail: fight params
##
## fighter type 0 (ee_2 player), order per fight_packets.go writeCombatFighterBlob:
##   i64 wireId, u8 breed, str8 name, u8 sex, u8 ey, u8 hair, u8 skin,
##   u8 eye, u8 summoned, i32 xp,
##   i16 len + spellBlob(i32 ids), i16 len + cardBlob({i16 slot,i32 id}),
##   i16 len + sphereBlob(u8 n), i16 n×i32 effects, i16 n×i16 conditions,
##   i32 hpLost, i32 mpUsed, i32 apUsed
## fighter type 1 (ta_0 monster):  i64 id, u8, i32 typeId, str8 name, u8, i32,i32
## fighter else  (wo_1 summon):    i64 id, str8 name, u8 xq, u8, u8, i32, i32
static func _fight_creation(r: WireReader) -> Dictionary:
	var out := {"aV": r.get_i8()}
	var key := r.get_bytes(r.get_u16())
	out.key = key
	out.fight_type = r.get_i32()
	out.fight_id = r.get_i64()
	out.unk8 = r.get_i8()
	out.ca = r.get_i64()
	out.f = r.get_i32()
	out.coaches = []
	for i in r.get_u8():
		var c := {"id": r.get_i64(), "name": r.get_str("u8")}
		c.look = [r.get_u8(), r.get_u8(), r.get_u8()]
		c.levelish = r.get_i16()
		c.w_blob = r.get_bytes(maxi(r.get_i16(), 0))
		c.s_blob = r.get_bytes(maxi(r.get_i16(), 0))
		c.report = r.get_bytes(r.get_u16())
		out.coaches.append(c)
	out.teams = []
	for i in r.get_u8():
		var t := {"id": r.get_i8(), "name": r.get_str("u8"),
				"placements": [], "fighters": []}
		for j in r.get_u8():
			t.placements.append({"fighter": r.get_i64(), "aj": r.get_i64(),
					"cell": r.get_i16(), "nd": r.get_u8()})
		for j in r.get_u8():
			var ft := r.get_u8()
			var f := _fighter(r, ft)
			f.coach = r.get_i64()
			f.team = t.id
			t.fighters.append(f)
		out.teams.append(t)
	out.timeline = []
	for i in r.get_u8():
		out.timeline.append(r.get_i64())
	out.specials = []
	for i in r.get_u8():
		out.specials.append(r.get_i32())
	out.special_detail = []
	for i in r.get_u8():
		out.special_detail.append({"a": r.get_i64(), "b": r.get_i64(),
				"x": r.get_i32(), "y": r.get_i32(), "s": r.get_i16()})
	out.ai = r.get_i16()
	out.team_stats_n = r.get_i32()
	if out.team_stats_n != 0:
		for i in out.coaches.size():
			out.coaches[i].stats = {"id": r.get_i64(),
					"v": [r.get_i32(), r.get_i32(), r.get_i32(),
							r.get_i32(), r.get_i32()]}
	out.dd = r.get_u8()
	out.tail = r.get_rest()
	return out


static func _fighter(r: WireReader, ft: int) -> Dictionary:
	if ft == 0:
		var f := {"type": "player", "id": r.get_i64(), "breed": r.get_u8(),
				"name": r.get_str("u8"), "sex": r.get_u8(), "ey": r.get_u8(),
				"hair": r.get_u8(), "skin": r.get_u8(), "eye": r.get_u8(),
				"summoned": r.get_u8(), "xp": r.get_i32()}
		var spells := r.get_bytes(maxi(r.get_i16(), 0))
		var sr := WireReader.new(spells)
		f.spells = []
		while sr.remaining() >= 4:
			f.spells.append(sr.get_i32())
		var cards := r.get_bytes(maxi(r.get_i16(), 0))
		var cr := WireReader.new(cards)
		f.cards = []
		while cr.remaining() >= 6:
			f.cards.append({"slot": cr.get_i16(), "id": cr.get_i32()})
		f.sphere_blob = r.get_bytes(maxi(r.get_i16(), 0))
		f.effects = []
		for j in maxi(r.get_i16(), 0):
			f.effects.append(r.get_i32())
		f.conditions = []
		for j in maxi(r.get_i16(), 0):
			f.conditions.append(r.get_i16())
		f.hp_lost = r.get_i32()
		f.mp_used = r.get_i32()
		f.ap_used = r.get_i32()
		return f
	if ft == 1:
		return {"type": "monster", "id": r.get_i64(), "unk0": r.get_u8(),
				"type_id": r.get_i32(), "name": r.get_str("u8"),
				"unk1": r.get_u8(), "p1": r.get_i32(), "p2": r.get_i32()}
	return {"type": "summon", "id": r.get_i64(), "name": r.get_str("u8"),
			"xq": r.get_u8(), "a": r.get_u8(), "b": r.get_u8(),
			"p1": r.get_i32(), "p2": r.get_i32()}


## Opcode 4102 — ACTOR_APPEAR: inserts fight actors into the render list.
## [u8 n]{i64 id, i32 x, i32 y, i16 z, u8 dir} — fighter wire ids and coach
## real ids share the same space (fight_packets.go buildActorAppear).
static func _actor_appear(r: WireReader) -> Dictionary:
	var out := {"actors": []}
	for i in r.get_u8():
		out.actors.append({"id": r.get_i64(), "x": r.get_i32(),
				"y": r.get_i32(), "z": r.get_i16(), "dir": r.get_u8()})
	return out


## Opcode 8022 — MOVE_TO_FREE_PLACEMENT broadcast:
## [i64 fighterId][i32 x][i32 y][i16 z].
static func _placement_move(r: WireReader) -> Dictionary:
	return {"id": r.get_i64(), "x": r.get_i32(), "y": r.get_i32(),
			"z": r.get_i16()}


## Opcode 8120 — RUNNING_EFFECT (fight_combat_packets.go buildRunningEffect):
##   [i32 uid][i32 -1][i8 now][i8 triggered][i32 elapsedTurns]
##   [i32 runningEffectId][u16 blobLen][BinarSerial blob]
## BinarSerial = part table (protocol/parttable.go):
##   [u8 count]{u8 partIdx, i32 absOffset}* then {u8 partIdx, payload}*
##   — absOffset points AT the part's own idx byte inside the blob.
##   part 0 (34B): [i64 caster][i64 target][i32 genEffect][i32 x][i32 y][u16 z][i32 value]
##   part 2: [i64 target]   part 4: [i32 sourceType(13=spell)][i64 spellId]
## Effect ids (mh_2): 1=HP loss, 91=AP use (silent), 92=MP use (silent).
static func _running_effect(r: WireReader) -> Dictionary:
	var out := {}
	out.uid = r.get_i32()
	r.get_i32()                    # triggering id (-1)
	out.now = r.get_i8()
	out.triggered = r.get_i8()
	out.elapsed = r.get_i32()
	out.effect_id = r.get_i32()
	var blob := r.get_bytes(maxi(r.get_u16(), 0))
	var br := WireReader.new(blob)
	var offsets := {}
	var order := []
	for i in br.get_u8():
		var idx := br.get_u8()
		offsets[idx] = br.get_i32()
		order.append(idx)
	for i in order.size():
		var idx: int = order[i]
		var start: int = offsets.get(idx, blob.size())
		var end: int = offsets.get(order[i + 1], blob.size()) if i + 1 < order.size() else blob.size()
		var pr := WireReader.new(blob.slice(mini(start, blob.size()), mini(end, blob.size())))
		if pr.remaining() <= 0 or pr.get_u8() != idx:
			continue
		match idx:
			0:
				out.caster = pr.get_i64()
				out.target = pr.get_i64()
				out.gen_effect = pr.get_i32()
				out.x = pr.get_i32()
				out.y = pr.get_i32()
				out.z = pr.get_u16()
				out.value = pr.get_i32()
			2:
				out.target = pr.get_i64()
			4:
				pr.get_i32()   # source type — 13 = spell
				out.spell_id = pr.get_i64()
	return out
