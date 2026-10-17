extends Node2D

const Login := preload("res://src/ui/login_screen.gd")
const Creation := preload("res://src/ui/creation_screen.gd")
const Lobby := preload("res://src/ui/lobby_screen.gd")
const Panels := preload("res://src/ui/lobby_panels.gd")
const Chat := preload("res://src/ui/chat_box.tscn")

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		push_error("[ui review] " + what)


func _shot(name: String) -> void:
	# No renderer to draw a frame for (or a viewport texture to grab) under
	# --headless — skip the screenshot so the assertions can still run
	# windowless instead of hanging forever on frame_post_draw.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	get_viewport().get_texture().get_image().save_png(
		"/tmp/ui-review-%s-%dx%d.png" % [name, int(vp.x), int(vp.y)])


func _run() -> void:
	var model := GuiModel.new()
	model.set_value("localCoach", {"name": "Arel", "level": 8, "sex": 0,
		"skin": 0, "hair": 0, "actorDirection": 5,
		"actorDescriptorLibrary": "coach_7000",
		"actorMaterial": Palettes.coach_tints(0, 0)})
	var login := Login.new()
	add_child(login)
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() == login.name_edit,
		"login initial focus")
	_check(login.name_edit.focus_next != NodePath(""), "login tab order")
	await _shot("login")
	login.queue_free()
	await get_tree().process_frame
	var creation := Creation.new()
	add_child(creation)
	creation.bind_model(model)
	await get_tree().process_frame
	_check(get_viewport().gui_get_focus_owner() == creation.name_edit,
		"creation initial focus")
	for control in creation.get_child(0).get_children():
		if control is Button:
			_check(control.focus_mode != Control.FOCUS_NONE,
				"creation button outside keyboard traversal")
	await _shot("creation")
	creation.queue_free()
	await get_tree().process_frame
	var chat := Chat.instantiate()
	add_child(chat)
	var lobby := Lobby.new()
	add_child(lobby)
	lobby.bind_model(model, chat)
	await get_tree().process_frame
	await _shot("lobby")
	var vp := get_viewport().get_visible_rect().size
	for name in Panels.TITLES:
		var panel := Panels.new()
		panel.panel_name = name
		panel.model = model
		add_child(panel)
		await get_tree().process_frame
		_check(panel.frame.get_global_rect().position.x >= -1
			and panel.frame.get_global_rect().position.y >= -1
			and panel.frame.get_global_rect().end.x <= vp.x + 1
			and panel.frame.get_global_rect().end.y <= vp.y + 1,
			"panel outside viewport: " + name)
		# UI_REVIEW_ALL=1 shoots every panel (screen inventory, S05).
		if OS.get_environment("UI_REVIEW_ALL") != "" or name in [
				"teamManagementDialog", "socialDialog", "cardBookDialog",
				"fighterCreationDialog", "optionsDialog"]:
			await _shot(name)
		panel.queue_free()
		await get_tree().process_frame
	await _card_master(model, vp)
	await _mailbox(model, vp)
	var bug := preload("res://src/ui/bug_report.gd").new("")
	add_child(bug)
	bug.popup_centered()
	await get_tree().process_frame
	var bug_rect := Rect2(bug.position, bug.size)
	_check(bug_rect.position.y >= 0 and bug_rect.end.y <= vp.y,
		"bug report outside viewport")
	await _shot("bug-report")
	bug.queue_free()
	await get_tree().process_frame
	# Options' fight section (S04/S17) sits below the fold: reopen, scroll,
	# shoot. Last on purpose — scrolling before the bug-report window
	# opened made Godot's accesskit (AT-SPI) adapter abort the run.
	var opts := Panels.new()
	opts.panel_name = "optionsDialog"
	opts.model = model
	add_child(opts)
	await get_tree().process_frame
	for sc in opts.find_children("*", "ScrollContainer", true, false):
		sc.scroll_vertical = 100000
	await get_tree().process_frame
	await _shot("optionsDialog-end")
	opts.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


## The native Card Master (S18) on sample data: the Jalatranki set of the
## sketch, one priced card, a wallet, and a few cards staged for barter.
func _card_master(model: GuiModel, vp: Vector2) -> void:
	var names := ["Jalatranki Boots", "Jalatranki Armbands", "The Purty",
		"Jalatranki Headgear", "Jalatranki Haircut", "Jalatranki Shoulderpads",
		"Jalatranki Skirt", "Jalatranki Mark"]
	var catalog: Array = []
	for i in names.size():
		catalog.append({"id": 16 + i, "name": names[i], "value": 60 + 15 * i,
			"owned": 2 if i == 3 else 0, "uniqueOwned": false,
			"price": [{"type": 1, "amount": 300}] if i == 1 else [],
			"canBuyTokens": i == 1})
	var offer: Array = []
	for cid in [128, 131, 137, 130, 134, 129]:
		offer.append({"id": cid, "name": "Weerdtrot %d" % cid, "value": 40,
			"owned": 2, "staged": 1 if cid in [128, 131] else 0})
	var trade := {"setName": "Jalatranki", "catalog": catalog,
		"selectedId": 17, "offer": offer,
		"staged": [{"id": 128, "name": "Weerdtrot Boots", "count": 1},
			{"id": 131, "name": "Weerdtrot Hat", "count": 1}],
		"offered": 156, "wanted": 75, "canBuyCards": true,
		"wallet": [{"type": 1, "amount": 1250}, {"type": 2, "amount": 40}],
		"status": "", "statusOk": false}
	model.set_value("cardMasterTrade", trade)
	var cm := preload("res://src/ui/card_master_panel.gd").new()
	cm.model = model
	add_child(cm)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(cm.frame.get_global_rect().end.x <= vp.x + 1
		and cm.frame.get_global_rect().end.y <= vp.y + 1,
		"panel outside viewport: cardMasterDialog")
	_check(cm.find_child("Buy", true, false) != null, "card master: Buy button")
	_check(cm.find_child("Card23", true, false) != null, "card master: whole set")
	await _shot("cardMaster")
	trade = trade.duplicate()
	trade["selectedId"] = 18   # barter-only: barter becomes the primary action
	model.set_value("cardMasterTrade", trade)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(cm.find_child("Buy", true, false) == null, "card master: no Buy when unpriced")
	await _shot("cardMaster-barteronly")
	cm.bartering = true
	cm.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(cm.find_child("Trade", true, false) != null, "card master: Trade button")
	await _shot("cardMaster-barter")
	cm.queue_free()
	await get_tree().process_frame


## The native mailbox (S18) on sample data: an inbox with a letter that
## carries cards, then the compose view with two cards attached.
func _mailbox(model: GuiModel, vp: Vector2) -> void:
	var cards := [{"id": 17, "name": "Jalatranki Armbands"},
		{"id": 131, "name": "Weerdtrot Hat"}]
	var recv := [
		{"mailId": 7, "sender": "Kerubim", "receiver": "Arel",
			"title": "Para tu equipo", "date": "17/10/2026 18:40", "read": true,
			"hasItems": true, "cards": cards,
			"message": "Te dejo dos cartas que me sobraban. Mañana jugamos la liga 2v2?"},
		{"mailId": 6, "sender": "Lou", "receiver": "Arel", "title": "",
			"date": "16/10/2026 21:05", "read": false, "hasItems": false,
			"cards": [], "message": "gg"},
		{"mailId": 5, "sender": "Torneo", "receiver": "Arel",
			"title": "Inscripción confirmada", "date": "15/10/2026 10:00",
			"read": true, "hasItems": false, "cards": [], "message": "Suerte."}]
	model.set_value("mailManager", {"receivedMails": recv, "sentMails": []})
	model.set_value("mailbox.mail", recv[0])
	var offer: Array = []
	for cid in [128, 129, 130, 131, 132, 133, 134]:
		offer.append({"id": cid, "name": "Weerdtrot %d" % cid, "owned": 3,
			"staged": 1 if cid == 131 else 0})
	model.set_value("mailbox.native", {"mode": "list", "loading": false,
		"offer": offer, "status": "", "statusOk": false})
	var mb := preload("res://src/ui/mailbox_panel.gd").new()
	mb.model = model
	add_child(mb)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(mb.frame.get_global_rect().end.x <= vp.x + 1
		and mb.frame.get_global_rect().end.y <= vp.y + 1,
		"panel outside viewport: mailboxDialog")
	_check(mb.find_child("Take", true, false) != null, "mailbox: Take button")
	await _shot("mailbox")
	model.set_value("mailbox.newMail", {"receiver": "Kerubim", "receiverId": 3,
		"title": "", "message": "", "cards": cards})
	model.set_value("mailbox.native", {"mode": "compose", "loading": false,
		"offer": offer, "status": "", "statusOk": false})
	await get_tree().process_frame
	await get_tree().process_frame
	_check(mb.find_child("Send", true, false) != null, "mailbox: Send button")
	_check(mb.find_child("Found", true, false) != null, "mailbox: recipient checked")
	await _shot("mailbox-compose")
	mb.queue_free()
	await get_tree().process_frame
