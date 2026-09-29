extends SceneTree

## Live overworld check: login -> EnterInstance -> world view + a scripted
## click-move. Run: godot --path godot -s test/world_smoke.gd
## Uses the real Session autoload (it IS instantiated under -s; only the
## global identifier doesn't resolve, so we grab the node by name).

const Codec := preload("res://src/net/codec.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

var _sess: Node
var _main
var _entered := false


func _init() -> void:
	# autoloads are already instanced when a -s script's deferred work runs;
	# give them a frame then drive through the real Session node.
	await process_frame
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_sess.message.connect(_on_msg)
	_sess.connect_to("127.0.0.1", 5555)
	await create_timer(0.5).timeout
	_send_login()


func _send_login() -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	_sess.send(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode("test")
	var p := CP1252.encode("test123")
	a.put_u8(l.size())
	a.put_bytes(l)
	a.put_u8(p.size())
	a.put_bytes(p)
	_sess.send(1025, a.raw(), 1)


func _on_msg(op: int, raw: PackedByteArray) -> void:
	var payload := WireReader.new(raw)
	match op:
		2048:
			var w := WireWriter.new()
			w.put_u8(4)
			w.put_bytes("test".to_ascii_buffer())
			w.put_u8(1)
			w.put_u8(1)
			w.put_u8(0)
			_sess.send(2049, w.raw(), 2)
		2052:
			var d := Codec.decode(op, payload)
			State.my_coach_id = int(d.get("id", -1))
			State.guild = d.get("guild", {})
			print("[smoke] coach id=", State.my_coach_id,
				" guild=", State.guild)
		4600:
			var d := Codec.decode(op, payload)
			print("[smoke] enter world=", d.get("world_id"), " pos=",
				d.get("x"), ",", d.get("y"), " alt=", d.get("alt"))
		4516:
			if not _entered:
				_entered = true
				print("[smoke] instance ready — world shown")
				_move_and_shoot()
		6006:
			var d := Codec.decode(op, payload)
			print("[smoke] roster:", d.fighters.map(func(f): return "%s breed=%d spells=%d cards=%d" % [
				f.get("name", "?"), int(f.get("breed", 0)),
				f.get("spells", []).size(), f.get("cards", []).size()]))
		6030:
			var d := Codec.decode(op, payload)
			print("[smoke] presets:", d.presets.map(func(p): return "type=%d '%s' f=%d c=%d" % [
				int(p.type), p.name, p.fighters.size(), p.coaches.size()]))
		4096:
			var d := Codec.decode(op, payload)
			var body := WireReader.new(d.get("actors_raw", PackedByteArray()))
			var n := body.get_i32()
			print("[smoke] actor spawn n=", n)
		3152:
			print("[smoke] CHAT vicinity arrived")
		3204:
			print("[smoke] CHAT user-not-found reply")
		3214:
			print("[smoke] CHAT target-is-yourself reply")
		6000:
			var d := Codec.decode(op, payload)
			print("[smoke] CREATE result=", d.result, " fid=", d.get("fighter_id"),
				" name=", d.get("fighter", {}).get("name"))
		6010:
			print("[smoke] LOADOUT result byte=", raw[8])
		23104:
			print("[smoke] SEARCH accepted — queue live")
		23102:
			print("[smoke] SEARCH cancel result=", raw[0])
		6020:
			print("[smoke] PRESET save status=", raw[0])
		6022:
			print("[smoke] PRESET deleted ack")
		4700:
			var p := WireReader.new(raw)
			print("[smoke] EMOTE played actor=", p.get_i64(), " anim=", p.get_str("u8"))
		200:
			var d := Codec.decode(op, payload)
			print("[smoke] ELEMENT spawn n=", d.elements.size(),
				" first=", d.elements[0] if not d.elements.is_empty() else {})
		206:
			var d := Codec.decode(op, payload)
			print("[smoke] ELEMENT despawn n=", d.ids.size())
		4001:
			var d := Codec.decode(op, payload)
			print("[smoke] WALLET:", d.currencies)
		5200:
			var d := Codec.decode(op, payload)
			print("[smoke] INVENTORY stacks=", d.cards.size())
		5401:
			var d := Codec.decode(op, payload)
			print("[smoke] SHOP catalog shop=", d.shop_id, " cards=", d.cards.size())
		5403:
			var d := Codec.decode(op, payload)
			print("[smoke] SHOP result=", d.result, " wallet=", d.currencies)
		3144:
			var d := Codec.decode(op, payload)
			print("[smoke] FRIENDS:", d.friends.map(
				func(f): return "%s(online=%s)" % [f.name, f.get("online", false)]))
		3146:
			var d := Codec.decode(op, payload)
			print("[smoke] IGNORED:", d.names)
		3156:
			var d := Codec.decode(op, payload)
			print("[smoke] FRIEND added:", d.name)
		3158:
			var d := Codec.decode(op, payload)
			print("[smoke] IGNORE added:", d.name)
		3160:
			var d := Codec.decode(op, payload)
			print("[smoke] FRIEND removed:", d.name)
		3162:
			var d := Codec.decode(op, payload)
			print("[smoke] IGNORE removed:", d.name)
		3148:
			var d := Codec.decode(op, payload)
			print("[smoke] FRIEND online:", d.name)
		3150:
			var d := Codec.decode(op, payload)
			print("[smoke] FRIEND offline:", d.name)
		27511:
			var d := Codec.decode(op, payload)
			print("[smoke] DEMON LADDER demon=", d.get("demon"),
				" rows=", d.get("rows", []).size(),
				" affiliation=", d.get("affiliation"))
		17003:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT CALENDAR events=", d.get("events", []).size(),
				" first=", d.events[0].name if not d.events.is_empty() else "-")
		28602:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT LIST n=", d.get("tournaments", []).size(),
				" first=", d.tournaments[0].name
					if not d.tournaments.is_empty() else "-")
		22094:
			var d := Codec.decode(op, payload)
			print("[smoke] FIREWORK show card=", d.get("card"),
				" at=", d.get("x"), ",", d.get("y"))
		27501, 27503, 27505, 27507, 27509, 27513, 27515:
			var d := Codec.decode(op, payload)
			var rows: Array = d.get("rows", d.get("windows", []))
			print("[smoke] LADDER ", op, " total=", d.get("total", "-"),
				" rows=", rows.size(),
				" myRank=", d.get("my_rank", "-"))
		5491:
			var d := Codec.decode(op, payload)
			print("[smoke] FUSION result=", d.get("result"),
				" obtained=", d.get("obtained"),
				" missed=", d.get("not_obtained"),
				" recovered=", d.get("recovered"))
		504:
			var d := Codec.decode(op, payload)
			print("[smoke] GUILD result type=", d.get("type"),
				" code=", d.get("code"))
		558:
			var d := Codec.decode(op, payload)
			print("[smoke] GUILD feed:", d.get("coach"),
				"founded", d.get("guild"))
		510, 552, 512:
			var d := Codec.decode(op, payload)
			print("[smoke] GUILD push ", op, ": ", d)
		554, 556, 560:
			var d := Codec.decode(op, payload)
			print("[smoke] GUILD push ", op, ": ", d)
		15001:
			var d := Codec.decode(op, payload)
			print("[smoke] MAIL list n=", d.mails.size(),
				" first=", d.mails[0] if not d.mails.is_empty() else "-")
		15003:
			var d := Codec.decode(op, payload)
			print("[smoke] MAIL send result=", d.result,
				" echo=", d.mail.get("title", "?"))
		15005:
			var d := Codec.decode(op, payload)
			print("[smoke] MAIL notice new=", d.new_count)
		15007:
			var d := Codec.decode(op, payload)
			print("[smoke] MAIL taken mail=", d.mail_id,
				" coach=", d.coach_id, " cards=", d.cards)
		28608:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT register tid=", d.get("tournament_id"),
				" code=", d.get("code"))
		28630:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT search period tid=",
				d.get("tournament_id"), " open=", d.get("open"))
		28612:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT search result tid=",
				d.get("tournament_id"), " accepted=", d.get("accepted"))
		28616:
			var d := Codec.decode(op, payload)
			print("[smoke] TOURNAMENT search error ", d)


func _move_and_shoot() -> void:
	await create_timer(2.0).timeout
	var w = _main.get_node("World")
	if w._pos.has(State.my_coach_id):
		var p: Vector3i = w._pos[State.my_coach_id]
		w.click_to(Vector2i(p.x + 4, p.y + 2))
		print("[smoke] scripted world move -> ", p.x + 4, ",", p.y + 2)
	# chat exercise: real ChatBox submit path — vicinity (local echo + bubble),
	# whisper-to-self (server -> 3214), whisper to a ghost (-> 3204), trade send.
	var chat = _main.get_node("UI/Chat")
	chat._on_submit("hola isla")
	chat._on_submit("/w test mensaje para mi")
	chat._on_submit("/w coach_fantasma_zz hola")
	chat._on_submit("/t vendo cartas")
	print("[smoke] chat lines sent (vicinity + /w self + /w ghost + /t)")
	# fighter creation: drive the real dialog path
	_main.get_node("UI/CreateDlg/VBox/Name").text = "Humo"
	_main.get_node("UI/CreateDlg/VBox/Breed").select(7)   # Iop
	_main._on_create_fighter()
	print("[smoke] fighter create sent — expecting 6000 + 6006 push")
	await create_timer(1.5).timeout
	# loadout: pick the new fighter, tick 3 spells, save via 6011
	var roster_list: ItemList = _main.get_node("UI/VBox/RosterBox/Roster")
	for i in roster_list.item_count:
		if roster_list.get_item_text(i).begins_with("Humo"):
			roster_list.select(i)
			break
	_main._open_loadout()
	var sp_box = _main.get_node("UI/LoadoutDlg/VBox/Scroll/Spells")
	var ticked := 0
	for cb in sp_box.get_children():
		cb.button_pressed = ticked < 3
		ticked += 1
	_main._on_save_loadout()
	print("[smoke] loadout sent — expecting 6010")
	await create_timer(1.5).timeout
	# kanodo: fighter 1 is the seeded evolution fighter (5000 xp, board 20
	# root (29,4)). Its only lit frontier node is 14739 (bonus, 2 xp) —
	# buy through the real pick path and verify in SQLite afterwards.
	for i in roster_list.item_count:
		if int(roster_list.get_item_metadata(i)) == 1:
			roster_list.select(i)
			break
	_main._open_kanodo()
	if _main._kanodo_fid > 0:
		var n = _main.Kanodo.nodes.get(14739, {})
		if not n.is_empty() and _main.get_node(
				"UI/KanodoDlg/VBox/Scroll/Board")._lit.has(14739):
			_main._on_sphere_pick(n)
			_main._on_sphere_buy()
			print("[smoke] kanodo buy sent — 23009 for sphere 14739 "
				+ "(silent; check fighter_spheres in DB)")
		else:
			print("[smoke] kanodo: sphere 14739 not lit (already bought?)")
		_main.get_node("UI/KanodoDlg").visible = false
	else:
		print("[smoke] kanodo skipped — no evolution fighter selected")
	# team preset: save the whole roster as "Escuadra" → 6021 → 6030 re-push
	_main._open_save_team()
	_main.get_node("UI/SaveTeamDlg/VBox/Name").text = "Escuadra"
	_main._on_save_team()
	print("[smoke] preset save sent — expecting 6030 refresh")
	await create_timer(1.0).timeout
	# assign: move the selected fighter into the new preset via 6013
	var preset_opt: OptionButton = _main.get_node("UI/VBox/TeamRow/Preset")
	for i in preset_opt.item_count:
		if preset_opt.get_item_text(i).begins_with("Escuadra"):
			preset_opt.select(i)
			break
	_main._on_assign(true)
	await create_timer(0.8).timeout
	# emote → server relays 4700 back to us
	chat._on_submit("/laugh")
	print("[smoke] emote sent — expecting 4700")
	# combattre queue: 23103 → expect 23104 searching, then 23101 → 23102
	_main._on_fight_pressed()
	await create_timer(1.0).timeout
	_main._on_cancel_search()
	print("[smoke] combattre + cancel sent — expecting 23104/23102")
	await create_timer(1.0).timeout
	# interactive elements: the 200 burst arrives on entry + after our move.
	# The lobby island's Card Masters sit far from spawn — walk toward one and
	# let the AoI refresh (server sends 200s as it enters range).
	print("[smoke] elements in view:", State.elements.size())
	var w2 = _main.get_node("World")
	var card_master := -1
	for id in State.elements:
		if int(State.elements[id].get("kind", -1)) == 1:
			card_master = int(id)
			break
	if card_master < 0:
		var table := preload("res://src/gamedata/elements.gd").for_world(
			State.current_world)
		var cm_pos := Vector2i.ZERO
		for id in table:
			if int(table[id].type) == 1:
				cm_pos = Vector2i(int(table[id].x), int(table[id].y))
				card_master = int(id)
				break
		if card_master >= 0:
			# step inside the master's chunk AoI (range ~2 chunks of 18 cells)
			var target := cm_pos + Vector2i(-6, 0)
			w2.click_to(target)
			print("[smoke] walking toward card master at ", cm_pos,
				" (via ", target, ")")
			await create_timer(2.5).timeout
			print("[smoke] elements in view now:", State.elements.size())
	if card_master >= 0 and State.elements.has(card_master):
		_main._use_element(card_master)   # same path as a marker click (201)
		print("[smoke] card master clicked (id ", card_master, ") — expecting 5401")
		await create_timer(1.0).timeout
		var shop_list: ItemList = _main.get_node("UI/ShopDlg/VBox/Scroll/Cards")
		if shop_list.item_count > 0:
			shop_list.select(0)
			_main._on_shop_pick(0)
			_main._on_shop_buy()   # island Card Masters are barter-only → 5403
			print("[smoke] shop buy sent — expecting 5403")
	elif card_master >= 0:
		print("[smoke] card master %d still out of AoI — skipping shop" %
			card_master)
	else:
		print("[smoke] no card master in view — skipping shop exercise")
	await create_timer(1.0).timeout
	# social: friend/ignore a real coach (3156/3158), ghost → 3204, list echoes
	chat._on_submit("/friend test2")
	chat._on_submit("/friend coach_fantasma_zz")
	chat._on_submit("/ignore test2")
	chat._on_submit("/friends")
	chat._on_submit("/ignored")
	print("[smoke] social commands sent — expecting 3156 + 3204 + 3158")
	await create_timer(1.0).timeout
	chat._on_submit("/unfriend test2")
	chat._on_submit("/unignore test2")
	print("[smoke] unfriend/unignore sent — expecting 3160 + 3162")
	await create_timer(1.0).timeout
	# delete the preset → 6022 + 6030 refresh
	_main._on_del_team()
	await create_timer(1.0).timeout
	# guild creation → 504 (403) + 510/552/512 pushes + 558 feed; needs a
	# unique name across runs.
	chat._on_submit("/guild Hermandad%d" % (randi() % 9000 + 1000))
	print("[smoke] guild create sent — expecting 504 "
		+ "(403 first run, 11 once 'test' already leads a guild)")
	await create_timer(1.5).timeout
	# --- element dialogs -----------------------------------------------------
	# Island 25: mailbox(2) @33,36 — graveyard(10) @4,45 — fusion(14) @-45,-25.
	# Dialogs are client-local; just check they open with the right title.
	await _click_elem(2, Vector2i(33, 36), "Mailbox")
	await create_timer(1.2).timeout
	# Read the seeded letter → take its attachments (15006) → delete (15004).
	# Pick the row with cards — sent letters list too and carry none.
	var mlist: ItemList = _main.get_node("UI/ElementDlg/VBox/Scroll/List")
	var midx := -1
	for i in _main._mails.size():
		if not _main._mails[i].get("cards", []).is_empty():
			midx = i
			break
	if midx >= 0:
		mlist.select(midx)
		mlist.item_selected.emit(midx)
		_main._on_element_act()
		print("[smoke] mail take sent — expecting 15007")
		await create_timer(1.0).timeout
		if mlist.item_count > 0:
			mlist.select(0)
			mlist.item_selected.emit(0)
			_main._on_element_alt()
			print("[smoke] mail delete sent")
			await create_timer(0.5).timeout
	else:
		print("[smoke] mailbox empty — SKIP take/delete")
	# Compose one to test2 → 539 → 15003 echo.
	chat._on_submit("/mail test2 Re:Objet|Bien recu, merci !")
	print("[smoke] mail send — expecting 15003")
	await create_timer(1.0).timeout
	# Graveyard: with a dead fighter + a resurrection card seeded, selecting
	# the fighter sends 22099 (card 305 is 100% — the roster refresh that
	# follows is the confirmation).
	await _click_elem(10, Vector2i(4, 45), "Graveyard")
	var glist: ItemList = _main.get_node("UI/ElementDlg/VBox/Scroll/List")
	var gact: Button = _main.get_node("UI/ElementDlg/VBox/Btns/ActBtn")
	if glist.item_count > 0 and gact.visible:
		glist.select(0)
		glist.item_selected.emit(0)
		_main._on_element_act()
		print("[smoke] resurrect 22099 sent — expecting 6006 refresh")
		await create_timer(1.0).timeout
	else:
		print("[smoke] no dead fighter/revive card — graveyard flow skipped")
	# Fusion altar: pick two same-set inputs + a target, then 5490 → 5491.
	await _click_elem(14, Vector2i(-45, -25), "Fusion altar")
	var fus_list: ItemList = _main.get_node("UI/ElementDlg/VBox/Scroll/List")
	var by_set := {}
	for i in fus_list.item_count:
		var cid := int(fus_list.get_item_metadata(i))
		var s := int(preload("res://src/gamedata/cards.gd")
			.meta(cid).get("set", 0))
		by_set[s] = by_set.get(s, []) + [i]
	var fused := false
	for s in by_set:
		var idxs: Array = by_set[s]
		if idxs.size() >= 2:
			fus_list.select(idxs[0], false)
			fus_list.select(idxs[1], false)
			_main._on_fusion_inputs()
			var list2: ItemList = _main.get_node(
				"UI/ElementDlg/VBox/Scroll2/List2")
			if list2.item_count > 0:
				list2.select(0)
				_main._on_element_act()
				print("[smoke] fusion 5490 sent (set ", s, ") — expecting 5491")
				fused = true
				await create_timer(1.0).timeout
			break
	if not fused:
		print("[smoke] no same-set tradable pair — fusion send skipped")
	# Zaap (at spawn 40,-20): open the teleport list, card 255 → world 37's
	# route totémique zaap (134,45) — the main landmass, where the demon
	# totems/challenges live (the tournament islet is zaap-only on purpose).
	var zid := await _goto_elem(4, Vector2i(40, -20))
	if zid >= 0:
		_main._use_element(zid)
		await create_timer(0.3).timeout
		var zlist: ItemList = _main.get_node("UI/ShopDlg/VBox/Scroll/Cards")
		for i in zlist.item_count:
			if int(zlist.get_item_metadata(i)) == 255:
				zlist.select(i)
				break
		_main._on_shop_buy()
		print("[smoke] zaap teleport sent (card 255 → world 37)")
		var t := 0
		while int(State.current_world) != 37 and t < 20:
			await create_timer(0.5).timeout
			t += 1
		print("[smoke] now in world=", State.current_world)
		await create_timer(1.5).timeout
		# Demon totem 76 (108,64) is in the landing AoI → 27510 → 27511.
		await _click_elem(11, Vector2i(108, 64), "Demon totem")
		await create_timer(0.8).timeout
		# "Offer cards" → affiliate basket → 5470 → 5403 (guild leader gate —
		# the /guild call above makes 'test' a leader of an unaffiliated clan).
		_main._on_element_alt()
		var offer_list: ItemList = _main.get_node(
			"UI/ElementDlg/VBox/Scroll/List")
		var offered := 0
		for i in offer_list.item_count:
			if offered < 2:
				offer_list.select(i, false)
				offered += 1
		if offered > 0:
			_main._on_element_act()
			print("[smoke] demon offering sent — expecting 5403")
			await create_timer(1.0).timeout
		else:
			print("[smoke] no tradable cards to offer — SKIP")
		# World 37 is an archipelago of zaap-linked islets — hop again:
		# zaap 138 → card 254 → Demon-I islet (zaap 70 at 132,126), where the
		# challenge element 55 spawns right away.
		var z2 := _elem_in_view(4)
		if z2 >= 0:
			_main._use_element(z2)
			await create_timer(0.3).timeout
			var zlist2: ItemList = _main.get_node("UI/ShopDlg/VBox/Scroll/Cards")
			for i in zlist2.item_count:
				if int(zlist2.get_item_metadata(i)) == 254:
					zlist2.select(i)
					break
			_main._on_shop_buy()
			print("[smoke] zaap hop sent (card 254 → demon islet)")
			await create_timer(2.0).timeout
			var cid := _elem_in_view(7)
			if cid >= 0:
				_main._use_element(cid)
				await create_timer(0.3).timeout
				print("[smoke] challenge bubble: kind=", _main._elem_kind,
					" challenge=", _main._bubble_challenge)
				_main.get_node("UI/ElementDlg").visible = false
			else:
				print("[smoke] no demon challenge in AoI — SKIP")
		# Third hop: zaap → card 256 → tournament islet (totem 119 in AoI).
		var z3 := _elem_in_view(4)
		if z3 >= 0:
			_main._use_element(z3)
			await create_timer(0.3).timeout
			var zlist3: ItemList = _main.get_node("UI/ShopDlg/VBox/Scroll/Cards")
			for i in zlist3.item_count:
				if int(zlist3.get_item_metadata(i)) == 256:
					zlist3.select(i)
					break
			_main._on_shop_buy()
			print("[smoke] zaap hop sent (card 256 → tournament islet)")
			await create_timer(2.0).timeout
			await _click_elem(13, Vector2i(121, 190), "Tournament totem")
			await create_timer(0.8).timeout
			# Register for the first listed tournament → 4607 → 28608.
			var tlist: ItemList = _main.get_node(
				"UI/ElementDlg/VBox/Scroll/List")
			if tlist.item_count > 0:
				tlist.select(0)
				tlist.item_selected.emit(0)
				_main._on_element_act()
				print("[smoke] tournament register sent — expecting 28608")
				await create_timer(1.0).timeout
				# "Find opponent" — only armed when registered + period open.
				if not _main.get_node(
						"UI/ElementDlg/VBox/Btns/AltBtn").visible:
					print("[smoke] AltBtn hidden — re-selecting row")
					tlist.item_selected.emit(0)
				_main._on_element_alt()
				print("[smoke] tournament search sent — expecting 28612")
				await create_timer(1.0).timeout
		# Fourth hop: zaap → card 208 → world 26 → firework launcher → 22095.
		var z4 := _elem_in_view(4)
		if z4 >= 0:
			_main._use_element(z4)
			await create_timer(0.3).timeout
			var zlist4: ItemList = _main.get_node("UI/ShopDlg/VBox/Scroll/Cards")
			for i in zlist4.item_count:
				if int(zlist4.get_item_metadata(i)) == 208:
					zlist4.select(i)
					break
			_main._on_shop_buy()
			print("[smoke] zaap hop sent (card 208 → world 26)")
			var t26 := 0
			while int(State.current_world) != 26 and t26 < 20:
				await create_timer(0.5).timeout
				t26 += 1
			var fid := await _goto_elem(12, Vector2i(39, 2))
			if fid >= 0:
				_main._use_element(fid)
				await create_timer(0.3).timeout
				var flist: ItemList = _main.get_node(
					"UI/ElementDlg/VBox/Scroll/List")
				if flist.item_count > 0:
					flist.select(0)
					_main._on_element_act()   # Launch → 22095 → 22094 echo
					print("[smoke] firework launch sent — expecting 22094")
					await create_timer(1.0).timeout
	# Rankings window: open it and page through all seven tabs (each sends
	# its 2750x request on arch 2; replies fill the list — logged above).
	_main._open_ladder()
	await create_timer(0.3).timeout
	var tabs: OptionButton = _main.get_node("UI/LadderDlg/VBox/Tabs")
	for i in tabs.item_count:
		tabs.select(i)
		_main._on_ladder_tab(i)
		await create_timer(0.6).timeout
	var more: Button = _main.get_node("UI/LadderDlg/VBox/Btns/MoreBtn")
	if not more.disabled:
		_main._on_ladder_more()      # demons page 2 (start 12 → demons 13-24)
		await create_timer(0.6).timeout
	_main.get_node("UI/LadderDlg").hide()
	# The dummy/headless renderer has no viewport texture — skip the capture.
	if DisplayServer.get_name() != "headless":
		var tex := root.get_texture()
		var img = tex.get_image() if tex != null else null
		if img != null:
			img.save_png("/tmp/world_live.png")
			print("[smoke] shot -> /tmp/world_live.png")
	quit()


## First spawned element id of `kind`, or -1 while it's still out of the AoI.
func _elem_in_view(kind: int) -> int:
	for id in State.elements:
		if int(State.elements[id].get("kind", -1)) == kind:
			return int(id)
	return -1


## Walk toward `target` until an element of `kind` enters the AoI (the server
## pushes 200 spawns as chunks refresh). Returns the element id or -1.
func _goto_elem(kind: int, target: Vector2i) -> int:
	var w = _main.get_node("World")
	var eid := _elem_in_view(kind)
	var tries := 0
	while eid < 0 and tries < 8:
		var cp: Vector3i = w._pos.get(State.my_coach_id, Vector3i.ZERO)
		var path: Array = w._find_path(Vector2i(cp.x, cp.y), target) \
			if w._pos.has(State.my_coach_id) else []
		print("[smoke] goto kind=", kind, " try=", tries,
			" coach=", cp, " path=", path.size(),
			" loaded=", w._loaded, " cells=", w._cells.size())
		w.click_to(target)
		await create_timer(2.5).timeout
		eid = _elem_in_view(kind)
		tries += 1
	return eid


## Walk to the element if needed, click it (201 + local dialog), and report the
## dialog title so the log shows which pane opened.
func _click_elem(kind: int, target: Vector2i, want_title: String) -> void:
	var eid := await _goto_elem(kind, target)
	if eid < 0:
		print("[smoke] element kind=", kind, " never entered AoI — SKIP")
		return
	_main._use_element(eid)
	await create_timer(0.4).timeout
	var dlg = _main.get_node("UI/ElementDlg")
	var shop = _main.get_node("UI/ShopDlg")
	if dlg.visible:
		print("[smoke] ELEM kind=", kind, " id=", eid,
			" dialog='", dlg.get_node("VBox/Title").text, "'")
	elif shop.visible:
		print("[smoke] ELEM kind=", kind, " id=", eid, " → shop/zaap pane")
	else:
		print("[smoke] ELEM kind=", kind, " id=", eid, " — no dialog!")
