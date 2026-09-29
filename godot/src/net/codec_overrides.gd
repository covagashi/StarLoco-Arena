extends RefCounted

## Hand-written decoders for the messages the generator marks "handler".
## Dispatch is by handler name; each returns a Dictionary of decoded fields.

const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")


static func dispatch(handler: String, opcode: int, r: WireReader) -> Dictionary:
	match handler:
		"coach_info": return _coach_info(r)
		"part_table": return _part_table(r)
		"guild_record": return _guild_record(r)
		"guild_member_list": return _guild_member_list(r)
		"mail_list": return _mail_list(r)
		"mail_send_result": return _mail_send_result(r)
		"mail_cards_taken": return _mail_cards_taken(r)
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
		"element_spawn": return _element_spawn(r)
		"element_despawn": return _element_despawn(r)
		"shop_catalog": return _shop_catalog(r)
		"shop_result": return _shop_result(r)
		"friend_added": return _friend_added(r)
		"friend_online": return _friend_online(r)
		"ignore_online": return _ignore_online(r)
		"name_note": return _name_note(r)
		"name_only": return _name_only(r)
		"demon_ladder": return _demon_ladder(r)
		"ladder_1v1": return _ladder_1v1(r)
		"ladder_guild": return _ladder_guild(r)
		"ladder_2v2": return _ladder_2v2(r)
		"ladder_tournament": return _ladder_tournament(r)
		"ladder_coach_rep": return _ladder_coach_rep(r)
		"ladder_demons": return _ladder_demons(r)
		"ladder_pro": return _ladder_pro(r)
		"guild_member_report": return _guild_member_report(r)
		"tournament_calendar": return _tournament_calendar(r)
		"tournament_list": return _tournament_list(r)
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
	var guild_blob := r.get_bytes(r.get_u16())
	out.guild_blob = guild_blob
	# The login guild blob is the same ca_0 part-table 552 carries — part 2
	# holds my membership (server handshake/coach.go → guildMembership).
	if not guild_blob.is_empty():
		var parts: Dictionary = _part_table(
			WireReader.new(guild_blob)).parts
		if parts.has(2):
			var pr := WireReader.new(parts[2])
			var g := {"guild_id": pr.get_i64(), "rights": pr.get_i32(),
				"rank_level": pr.get_u16(), "rank_name": pr.get_str("u8")}
			pr.get_u16()
			g["guild"] = pr.get_str("u8")
			pr.get_u16(); pr.get_i32(); pr.get_i32()
			g["demon_id"] = pr.get_u16()
			out.guild = g
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
		var end: int = index[i + 1].off if i + 1 < index.size() else buf.size()
		parts[index[i].id] = buf.slice(start, end)
	return {"parts": parts}


## Opcode 510 — GuildRecord (server guild_packets.go buildGuildRecord):
## [u16 len]{i64 guildId, str8 name, u16,u16, i32,i32, u16 demonId, i32,
## u8 nRanks, nRanks x [u16 len]{u16 level,i32 rights,str8 name}}
static func _guild_record(r: WireReader) -> Dictionary:
	var body := r.get_bytes(r.get_u16())
	var br := WireReader.new(body)
	var out := {"guild_id": br.get_i64(), "name": br.get_str("u8")}
	br.get_u16(); br.get_u16(); br.get_i32(); br.get_i32()
	out.demon_id = br.get_u16()
	br.get_i32()
	var ranks := []
	var n := br.get_u8()
	for i in n:
		var inner := WireReader.new(br.get_bytes(br.get_u16()))
		ranks.append({"level": inner.get_u16(), "rights": inner.get_i32(),
			"name": inner.get_str("u8")})
	out.ranks = ranks
	return out


## Opcodes 512 / 552 / 554 — the kf_1 member-list container:
## [i32 n] n x { [i32 len][ca_0 part-table blob] }. The part index inside
## each blob selects the row shape:
##   0 (512): i64 id, i32 rights, u16 rankLevel, str8 rank, str8 name, u8 online
##   1 (554): str8 guild, i64 player, u16,u16, i32,i32, u16 demon   (clan tag)
##   2 (552): i64 guild, i32 rights, u16 rankLevel, str8 rank, u16,
##            str8 guild, u16, i32, i32, u16 demon                  (membership)
static func _guild_member_list(r: WireReader) -> Dictionary:
	var rows := []
	var n := r.get_i32()
	for i in n:
		var blob := r.get_bytes(r.get_i32())
		var br := WireReader.new(blob)
		var parts: Dictionary = _part_table(br).parts
		for idx in parts:
			var pr := WireReader.new(parts[idx])
			match int(idx):
				0:
					rows.append({"part": 0, "coach_id": pr.get_i64(),
						"rights": pr.get_i32(), "rank_level": pr.get_u16(),
						"rank_name": pr.get_str("u8"),
						"name": pr.get_str("u8"),
						"online": pr.get_u8() != 0})
				1:
					rows.append({"part": 1, "guild": pr.get_str("u8"),
						"coach_id": pr.get_i64()})
				2:
					rows.append({"part": 2, "guild_id": pr.get_i64(),
						"rights": pr.get_i32(), "rank_level": pr.get_u16(),
						"rank_name": pr.get_str("u8")})
					pr.get_u16()
					rows.back()["guild"] = pr.get_str("u8")
					pr.get_u16(); pr.get_i32(); pr.get_i32()
					rows.back()["demon_id"] = pr.get_u16()
	return {"rows": rows}


## Opcode 2601 — GuildMemberReport (server buildGuildMemberReport):
## [i64 coachId][str16 name][u16 len][PlayerStatistics blob — the same
## model 2400 carries].
static func _guild_member_report(r: WireReader) -> Dictionary:
	var out := {"coach": r.get_i64(), "name": r.get_str("u16")}
	out.stats = _stat_map(r).stats
	return out


## --- mailbox (server mail_packets.go) ----------------------------------------
## Mail record: [i64 id][i64 senderId][str8 senderName][i32 senderGame]
## [i64 receiverId][str8 receiverName][i32 extraLen][extra][i64 dateMs]
## [u8 read][u8 delSender][u8 delReceiver][i32 state]. The extra blob is TLV:
## tag 1 title [i32 len]bytes, tag 2 body [i32 len]bytes,
## tag 3 cards [u16 n]{i32}, tag 4 systemMsgId [i32] (system mails).
static func _mail_record(r: WireReader) -> Dictionary:
	var m := {
		"id": r.get_i64(), "sender_id": r.get_i64(),
		"sender": r.get_str("u8", "utf8"), "sender_game": r.get_i32(),
		"receiver_id": r.get_i64(), "receiver": r.get_str("u8", "utf8"),
		"title": "", "body": "", "cards": [], "system_id": 0}
	var extra := WireReader.new(r.get_bytes(r.get_i32()))
	while extra.remaining() > 0:
		var tag := extra.get_u16()
		match tag:
			1: m.title = extra.get_str("i32", "utf8")
			2: m.body = extra.get_str("i32", "utf8")
			3:
				var n := extra.get_u16()
				for i in n:
					m.cards.append(extra.get_i32())
			4: m.system_id = extra.get_i32()
			_: break        # unknown tag — can't know its length, stop cleanly
	m.date_ms = r.get_i64()
	m.read = r.get_u8() != 0
	m.deleted_sender = r.get_u8() != 0
	m.deleted_receiver = r.get_u8() != 0
	m.state = r.get_i32()
	return m


## Opcode 15001 — MAIL_LIST: [i16 n]{mail record}.
static func _mail_list(r: WireReader) -> Dictionary:
	var mails := []
	var n := r.get_i16()
	for i in n:
		mails.append(_mail_record(r))
	return {"mails": mails}


## Opcode 15003 — MAIL_SEND_RESULT: [i64 result][mail record].
static func _mail_send_result(r: WireReader) -> Dictionary:
	return {"result": r.get_i64(), "mail": _mail_record(r)}


## Opcode 15007 — MAIL_CARDS_TAKEN: [i64 mailId][i64 coachId][u8 n]{i32}.
static func _mail_cards_taken(r: WireReader) -> Dictionary:
	var out := {"mail_id": r.get_i64(), "coach_id": r.get_i64(), "cards": []}
	var n := r.get_u8()
	for i in n:
		out.cards.append(r.get_i32())
	return out


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


## Opcode 3144 — [u8 n]{u16 len, friend blob}. Blob layout (server
## buildFriendList, client qm.b):
##   [u8 name][u8 charName][u8 note][u8 notify][i64 coachId=-1 offline]
##   [i16 adQ][u8 adR][i16 adS]
static func _friend_list(r: WireReader) -> Dictionary:
	var out := {"friends": []}
	for i in r.get_u8():
		var br := WireReader.new(r.get_bytes(r.get_u16()))
		var f := {"name": br.get_str("u8"), "char_name": br.get_str("u8"),
			"note": br.get_str("u8")}
		if br.remaining() >= 1:
			f.notify = br.get_u8()
		if br.remaining() >= 8:
			f.id = br.get_i64()
			f.online = int(f.id) != -1
		if br.remaining() >= 5:
			br.get_i16()
			br.get_u8()
			br.get_i16()
		out.friends.append(f)
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


## Opcode 200 — INTERACTIVE_ELEMENT_SPAWN (server elements.go
## buildInteractiveElementSpawn): [i16 count]{[i64 instanceId][u16 len]
## [part-table payload]}. The payload is a BIG-endian part table (aJj.ad) —
## position + descriptor live in the RU part (id 1, client RU.f):
##   [i16 world][i32 x][i32 y][i16 z][i16 state][u8 visible][u8][u8 dir]
##   [i16 flags][i16 nPaths]{i32 x, i32 y, i16 z}[u16 nameLen][name][u8 props]
## The server rewrites z to the GROUND altitude before sending — wire z is
## authoritative (envmaps.go calls the stored one the decoration height).
static func _element_spawn(r: WireReader) -> Dictionary:
	var out := {"elements": []}
	for i in r.get_i16():
		var e := {"id": r.get_i64()}
		_element_ru(e, r.get_bytes(r.get_u16()))
		out.elements.append(e)
	return out


static func _element_ru(e: Dictionary, blob: PackedByteArray) -> void:
	var pr := WireReader.new(blob)
	var n := pr.get_u8()
	var ids := []
	var offs := []
	for i in n:
		ids.append(pr.get_u8())
		offs.append(pr.get_i32())
	for i in ids.size():
		if ids[i] != 1:
			continue
		var start: int = offs[i] + 1
		var end: int = offs[i + 1] if i + 1 < ids.size() else blob.size()
		if start < 0 or end > blob.size() or start >= end:
			return
		var ru := WireReader.new(blob.slice(start, end))
		ru.get_i16()                       # world id
		e.x = ru.get_i32()
		e.y = ru.get_i32()
		e.z = ru.get_i16()
		ru.get_i16()                       # element state
		ru.get_u8()                        # visible
		ru.get_u8()                        # agj
		e.dir = ru.get_u8()
		e.flags = ru.get_i16()
		for j in ru.get_i16():
			ru.get_i32()
			ru.get_i32()
			ru.get_i16()
		if ru.remaining() >= 2:
			e.desc = ru.get_str("u16")
		return


## Opcode 206 — INTERACTIVE_ELEMENT_DESPAWN (acc_2): [i16 count]{[i64 id]}.
static func _element_despawn(r: WireReader) -> Dictionary:
	var out := {"ids": []}
	for i in r.get_i16():
		out.ids.append(r.get_i64())
	return out


## Opcode 5401 — ShopCatalog (server buildShopCatalog):
## [u8 mode][i32 shopId] then per offered card [i32 cardId][u16 qty] to the end.
## mode 0 = kardmaster buy tab, 1 = "démone II" exchanger variant.
static func _shop_catalog(r: WireReader) -> Dictionary:
	var out := {"mode": r.get_u8(), "shop_id": r.get_i32(), "cards": []}
	while r.remaining() >= 6:
		out.cards.append({"id": r.get_i32(), "qty": r.get_u16()})
	return out


## Opcode 5403 — ShopResult: [u8 result][u8 n]{u8 currencyType, i32 amount}.
## result: 0 ok (wallet snapshot follows), 1 insufficient tokens, 2 error.
static func _shop_result(r: WireReader) -> Dictionary:
	var out := {"result": r.get_u8(), "currencies": []}
	for i in r.get_u8():
		out.currencies.append({"type": r.get_u8(), "amount": r.get_i32()})
	return out


## --- social (server handlers_social.go / packets.go) -----------------------

## Opcode 3156 — FriendAdded: [u8 name][u8 note][i64 id][i16][i8 sex][i16].
static func _friend_added(r: WireReader) -> Dictionary:
	var out := {"name": r.get_str("u8"), "note": r.get_str("u8")}
	if r.remaining() >= 8:
		out.id = r.get_i64()
	if r.remaining() >= 3:
		r.get_i16()
		out.sex = r.get_i8()
	return out


## Opcode 3148 — FriendOnline: [u8 name][u8 s2][u8 s3][i64 id][i16][i8 sex][i64].
static func _friend_online(r: WireReader) -> Dictionary:
	var out := {"name": r.get_str("u8"), "s2": r.get_str("u8"),
		"s3": r.get_str("u8")}
	if r.remaining() >= 8:
		out.id = r.get_i64()
	return out


## Opcode 3164 — IgnoreOnline: [u8 name][i64 id].
static func _ignore_online(r: WireReader) -> Dictionary:
	var out := {"name": r.get_str("u8")}
	if r.remaining() >= 8:
		out.id = r.get_i64()
	return out


## Opcodes 3158 IgnoreAdded / 3150 FriendOffline: [u8 name][u8 note].
static func _name_note(r: WireReader) -> Dictionary:
	return {"name": r.get_str("u8"), "note": r.get_str("u8")}


## Opcodes 3160 FriendRemoved / 3162 IgnoreRemoved / 3166 IgnoreOffline:
## [u8 name].
static func _name_only(r: WireReader) -> Dictionary:
	return {"name": r.get_str("u8")}


## Opcode 27511 — DemonLadder (server buildDemonLadder):
## [i16 demonId][i16 flag][i32 start][i32 n]{[i32 nameLen][name][i64 quarterly]
## [i64 quarterlyCumul][i64 monthly]}[i64 viewerAffiliation].
static func _demon_ladder(r: WireReader) -> Dictionary:
	var out := {"demon": r.get_i16(), "flag": r.get_i16(),
		"start": r.get_i32(), "rows": []}
	for i in r.get_i32():
		out.rows.append({"name": r.get_str("i32"),
			"quarterly": r.get_i64(), "q_cumul": r.get_i64(),
			"monthly": r.get_i64()})
	if r.remaining() >= 8:
		out.affiliation = r.get_i64()
	return out


## Opcode 27501 — Ladder1v1 (server buildLadderResponse):
## [i32 total][i32 start][i32 end][i32 myRank](end-start)x{str32 name,
## str32 guild, u16 rating, i32_, i32_, i32 streak, i32_, i32 wins,
## i32 losses}[u8 search]. end MUST equal start+rows (client loop bound).
static func _ladder_1v1(r: WireReader) -> Dictionary:
	var out := {"total": r.get_i32(), "start": r.get_i32(),
		"end": r.get_i32(), "my_rank": r.get_i32(), "rows": []}
	for i in out.end - out.start:
		out.rows.append({"name": r.get_str("i32"),
			"guild": r.get_str("i32"), "rating": r.get_u16(),
			"streak": _skip3(r), "wins": r.get_i32(),
			"losses": r.get_i32()})
	if r.remaining() >= 1:
		out.search = r.get_u8()
	return out


## shared tail for the strength boards (1v1/2v2): after the rating the
## wire is [i32 _][i32 _][i32 streak][i32 _] — skip two, read streak,
## skip one (server buildLadderResponse/build2v2Ladder).
static func _skip3(r: WireReader) -> int:
	r.get_i32()
	r.get_i32()
	var streak := r.get_i32()
	r.get_i32()
	return streak


## Opcode 27503 — LadderGuild: [i16 board][i32 start][i32 n]
## {str32 guild, str32 leader, i32 score}.
static func _ladder_guild(r: WireReader) -> Dictionary:
	var out := {"board": r.get_i16(), "start": r.get_i32(), "rows": []}
	for i in r.get_i32():
		out.rows.append({"guild": r.get_str("i32"),
			"leader": r.get_str("i32"), "score": r.get_i32()})
	return out


## Opcode 27505 — Ladder2v2: [i32 total][i32 start][i32 end]
## [i32 nIcons]{i32}(end-start)x{str32 coaches, str32 team, str32 guild,
## u16 rating, streak tail}[i32 search].
static func _ladder_2v2(r: WireReader) -> Dictionary:
	var out := {"total": r.get_i32(), "start": r.get_i32(),
		"end": r.get_i32(), "icons": [], "rows": []}
	for i in r.get_i32():
		out.icons.append(r.get_i32())
	for i in out.end - out.start:
		out.rows.append({"coaches": r.get_str("i32"),
			"team": r.get_str("i32"), "guild": r.get_str("i32"),
			"rating": r.get_u16(), "streak": _skip3(r),
			"wins": r.get_i32(), "losses": r.get_i32()})
	if r.remaining() >= 4:
		out.search = r.get_i32()
	return out


## Opcode 27507 — LadderTournament: [u8 month][u8 trim][u16 year]
## [i32 myMonth][i32 myTrim][i32 myYear] then 3 windows, each
## {i32 total, i32 start, i32 end, i32 myRank, (end-start)x{str32 name,
## i32 pts}, u8 search}.
static func _ladder_tournament(r: WireReader) -> Dictionary:
	var out := {"month": r.get_u8(), "trimester": r.get_u8(),
		"year": r.get_u16(), "my_points": [
			r.get_i32(), r.get_i32(), r.get_i32()], "windows": []}
	for w in 3:
		var win := {"total": r.get_i32(), "start": r.get_i32(),
			"end": r.get_i32(), "my_rank": r.get_i32(), "rows": []}
		for i in win.end - win.start:
			win.rows.append({"name": r.get_str("i32"),
				"points": r.get_i32()})
		if r.remaining() >= 1:
			win.search = r.get_u8()
		out.windows.append(win)
	return out


## Opcode 27509 — LadderCoachRep: [i32 total][i32 start][i32 end]
## [i32 localIdx](end-start)x{i32 rep, str32 coach, str32 team, i32 wins,
## i32 losses, str32 guild, u16 demon}[u8 search].
static func _ladder_coach_rep(r: WireReader) -> Dictionary:
	var out := {"total": r.get_i32(), "start": r.get_i32(),
		"end": r.get_i32(), "local_idx": r.get_i32(), "rows": []}
	for i in out.end - out.start:
		out.rows.append({"rep": r.get_i32(),
			"coach": r.get_str("i32"), "team": r.get_str("i32"),
			"wins": r.get_i32(), "losses": r.get_i32(),
			"guild": r.get_str("i32"), "demon": r.get_u16()})
	if r.remaining() >= 1:
		out.search = r.get_u8()
	return out


## Opcode 27513 — LadderDemons: [u16 flag][i32 start][i32 n]
## {u16 demon, i64 rep, str32 guild}.
static func _ladder_demons(r: WireReader) -> Dictionary:
	var out := {"flag": r.get_i16(), "start": r.get_i32(), "rows": []}
	for i in r.get_i32():
		out.rows.append({"demon": r.get_u16(), "rep": r.get_i64(),
			"guild": r.get_str("i32")})
	return out


## Opcode 27515 — LadderPro: [i32 total][i32 start][i32 end][i32 myRank]
## [i32 league](end-start)x{str32 name, str32 guild, u16 rating}[u8 search].
static func _ladder_pro(r: WireReader) -> Dictionary:
	var out := {"total": r.get_i32(), "start": r.get_i32(),
		"end": r.get_i32(), "my_rank": r.get_i32(),
		"league": r.get_i32(), "rows": []}
	for i in out.end - out.start:
		out.rows.append({"name": r.get_str("i32"),
			"guild": r.get_str("i32"), "rating": r.get_u16()})
	if r.remaining() >= 1:
		out.search = r.get_u8()
	return out


## Opcode 17003 — TournamentCalendar (server writeTournamentEvent):
## [i16 n]{[i32 typeId=4][i64 eventId][i64 start][i64 end][i64 recur]
## [i32 label][i64 extra][i64 tid][u8 name][u16 desc][u8 short]
## [u8 nPhases]{i64,i64}[u8 nReg]{i64,i64}}.
static func _tournament_calendar(r: WireReader) -> Dictionary:
	var out := {"events": []}
	for i in r.get_i16():
		r.get_i32()   # content type id (4 = qr_0)
		var e := {"id": r.get_i64(), "runs_until": r.get_i64()}
		r.get_i64()   # endDate mirror
		r.get_i64()   # recurrence
		r.get_i32()   # label index
		r.get_i64()   # extraDate (started bound)
		e.tid = r.get_i64()
		e.name = r.get_str("u8")
		e.desc = r.get_str("u16")
		e.short = r.get_str("u8")
		for j in r.get_u8():
			r.get_i64()
			r.get_i64()
		for j in r.get_u8():
			r.get_i64()
			r.get_i64()
		out.events.append(e)
	return out


## Opcode 28602 — TournamentList (server buildTournamentList):
## [i32 n]{i64 id, u8 opened, i8 status, u16 defId, u8 regOpen, i32 nParams,
## str32 name, str32 desc, str32 organizer, u8 kind}.
static func _tournament_list(r: WireReader) -> Dictionary:
	var out := {"tournaments": []}
	for i in r.get_i32():
		var t := {"id": r.get_i64(), "opened": r.get_u8(),
			"status": r.get_i8(), "def_id": r.get_u16(),
			"reg_open": r.get_u8()}
		r.get_i32()   # fightParamCount (0)
		t.name = r.get_str("u32")
		t.desc = r.get_str("u32")
		t.organizer = r.get_str("u32")
		t.kind = r.get_u8()
		out.tournaments.append(t)
	return out
