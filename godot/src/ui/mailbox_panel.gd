extends "res://src/ui/lobby_panel.gd"
## The native mailbox (S18, tanda 2): replaces the retail XML mailboxDialog
## and newMailDialog. Received / sent lists on the left, the open message on
## the right; writing a message (with up to 10 attached cards) happens in
## the same window. Reads mailManager.* and mailbox.* (main.gd
## _push_mail_model) and asks main.gd for every change through nativeMail*
## events — the wire stays in main.gd.
## Words: a mail is a "mensaje", a game card is a "carta".

const MAX_CARDS := 10   # domain.MailMaxAttachments, the client's own limit

var _confirm_delete := -1   # mail id whose "Borrar" asks for a second click
var _last_mode := ""


func _ready() -> void:
	panel_name = "mailboxDialog"
	super._ready()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] in ["mailManager", "mailbox"]:
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	var keep_focus := remember_focus()
	clear_body()
	title.text = I18n.t("mb.title")
	var mode := str(data("mailbox.native.mode", "list"))
	if mode == "compose":
		if _last_mode != "compose":
			# a fresh draft: the recipient comes from "Responder", if any
			draft = {"to": str(data("mailbox.newMail.receiver", "")),
				"title": "", "message": ""}
		_compose()
	else:
		_list()
	_last_mode = mode
	var foot := Control.new()   # room for the primary button's hard shadow
	foot.custom_minimum_size.y = 6
	body.add_child(foot)
	_restore.call_deferred(keep_focus)


func _restore(focus_name: String) -> void:
	restore_focus(focus_name)


# --- reading -------------------------------------------------------------------

func _list() -> void:
	var received: Array = data("mailManager.receivedMails", [])
	var sent: Array = data("mailManager.sentMails", [])
	var unread := received.filter(func(m): return not bool(m.get("read", false))).size()
	var top := row(body)
	var recv_label := I18n.t("mb.received")
	if unread > 0:
		recv_label += " (%d)" % unread
	tabs(top, [recv_label, I18n.t("mb.sent")], func(_i): _confirm_delete = -1)
	var new_btn := button(top, I18n.t("mb.new"), func(): send("nativeMailCompose", [""]))
	new_btn.name = "New"
	new_btn.custom_minimum_size.x = 190
	var split := row(body)
	split.add_theme_constant_override("separation", 28)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(540, 380)
	split.add_child(left)
	var right := column(split)
	var mails: Array = sent if tab == 1 else received
	var status := str(data("mailbox.native.status", ""))
	if bool(data("mailbox.native.loading", false)) and mails.is_empty():
		label(left, I18n.t("mb.loading"))
	elif mails.is_empty():
		label(left, I18n.t("mb.empty"))
	else:
		_mail_table(left, mails)
	_reading(right, mails, status)


func _mail_table(parent: Node, mails: Array) -> void:
	var rows: Array = []
	for m in mails:
		rows.append({"id": int(m.get("mailId", 0)),
			"mark": "" if bool(m.get("read", false)) or tab == 1 else "●",
			"who": str(m.get("receiver" if tab == 1 else "sender", "")),
			"title": _title_of(m),
			"cards": str(m.get("cards", []).size()) if bool(m.get("hasItems", false)) else ""})
	var open: Variant = data("mailbox.mail")
	selected = {"id": int(open.get("mailId", -1))} if open is Dictionary else {}
	var tree := table(parent, ["", I18n.t("mb.col_to" if tab == 1 else "mb.col_from"),
		I18n.t("mb.col_title"), I18n.t("mb.col_cards")],
		["mark", "who", "title", "cards"], rows, func(item):
			_confirm_delete = -1
			send("nativeMailRead", [int(item.get("id", 0))]))
	tree.name = "Mails"
	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 26)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 150)
	tree.set_column_expand(3, false)
	tree.set_column_custom_minimum_width(3, 70)


func _reading(side: VBoxContainer, mails: Array, status: String) -> void:
	var open: Variant = data("mailbox.mail")
	var mid := int(open.get("mailId", -1)) if open is Dictionary else -1
	var shown := mails.any(func(m): return int(m.get("mailId", 0)) == mid)
	if not shown:
		if not mails.is_empty():
			label(side, I18n.t("mb.pick"))
		_status(side, status)
		return
	var head := label(side, _title_of(open), 22)
	head.add_theme_font_override("font", OneBit.title_font())
	var who := I18n.t("mb.to", {"name": open.get("receiver", ""), "date": open.get("date", "")}) \
		if tab == 1 else I18n.t("mb.from", {"name": open.get("sender", ""), "date": open.get("date", "")})
	var meta := label(side, who, 15)
	meta.add_theme_color_override("font_color", OneBit.MUTED)
	side.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 90
	side.add_child(scroll)
	var text := label(scroll, str(open.get("message", "")), 17)
	text.name = "Message"
	var cards: Array = open.get("cards", [])
	if not cards.is_empty():
		side.add_child(OneBit.caption(I18n.t("mb.attached")))
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 10)
		side.add_child(strip)
		for c in cards:
			strip.add_child(_mini_card(int(c.get("id", 0)), str(c.get("name", ""))))
	_status(side, status)
	var actions := row(side)
	actions.add_theme_constant_override("separation", 16)
	if tab == 0 and not cards.is_empty():
		var take := Button.new()
		take.name = "Take"
		take.text = I18n.t("mb.take")
		take.custom_minimum_size = Vector2(220, 54)
		OneBit.primary(take, 20)
		take.pressed.connect(func(): send("nativeMailTake"))
		actions.add_child(take)
	if tab == 0:
		var reply := button(actions, I18n.t("mb.reply"),
			func(): send("nativeMailCompose", [str(open.get("sender", ""))]))
		reply.name = "Reply"
		reply.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var asking := _confirm_delete == mid
	var del := button(actions, I18n.t("mb.delete_sure" if asking else "mb.delete"), func():
		if _confirm_delete == mid:
			_confirm_delete = -1
			send("nativeMailDelete", [mid])
		else:
			_confirm_delete = mid
			schedule_refresh())
	del.name = "Delete"
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- writing -------------------------------------------------------------------

func _compose() -> void:
	var split := row(body)
	split.add_theme_constant_override("separation", 28)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := column(split)
	left.add_theme_constant_override("separation", 8)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 380)
	right.add_theme_constant_override("separation", 8)
	split.add_child(right)

	left.add_child(OneBit.caption(I18n.t("mb.to_label")))
	var to_row := row(left)
	var to := field(to_row, "to", I18n.t("mb.to_ph"))
	to.name = "To"
	to.max_length = 40
	var check := button(to_row, I18n.t("mb.check"), func():
		send("nativeMailCheck", [str(draft.get("to", ""))]))
	check.name = "Check"
	to.text_submitted.connect(func(_t): check.pressed.emit())
	var checked := str(data("mailbox.newMail.receiver", ""))
	var rid := int(data("mailbox.newMail.receiverId", 0))
	if rid != 0 and checked.to_lower() == str(draft.get("to", "")).strip_edges().to_lower():
		var ok := label(left, I18n.t("mb.found" if rid > 0 else "mb.not_found"), 15)
		ok.name = "Found"
		if rid < 0:
			ok.add_theme_color_override("font_color", OneBit.MUTED)
	left.add_child(OneBit.caption(I18n.t("mb.subject")))
	var subject := field(left, "title", "")
	subject.name = "Subject"
	left.add_child(OneBit.caption(I18n.t("mb.message")))
	var msg := TextEdit.new()
	msg.name = "Body"
	msg.text = str(draft.get("message", ""))
	msg.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	msg.custom_minimum_size.y = 150
	msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msg.text_changed.connect(func(): draft["message"] = msg.text)
	left.add_child(msg)

	var staged: Array = data("mailbox.newMail.cards", [])
	right.add_child(OneBit.caption(I18n.t("mb.attach", {"n": staged.size(), "max": MAX_CARDS})))
	if staged.is_empty():
		var hint := label(right, I18n.t("mb.attach_hint"), 15)
		hint.add_theme_color_override("font_color", OneBit.MUTED)
	var strip := HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 8)
	strip.add_theme_constant_override("v_separation", 8)
	right.add_child(strip)
	for i in staged.size():
		var c: Dictionary = staged[i]
		var b := _mini_card(int(c.get("id", 0)), str(c.get("name", "")), true)
		b.name = "Attached%d" % i
		b.tooltip_text = I18n.t("mb.detach")
		var idx := i
		b.pressed.connect(func(): send("nativeMailDetach", [idx]))
		strip.add_child(b)
	right.add_child(OneBit.caption(I18n.t("mb.your_cards")))
	var offer: Array = data("mailbox.native.offer", [])
	if offer.is_empty():
		label(right, I18n.t("mb.no_cards"), 15)
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 6)
		scroll.add_child(list)
		for o in offer:
			var cid := int(o.get("id", 0))
			var left_n := int(o.get("owned", 0)) - int(o.get("staged", 0))
			var b := Button.new()
			b.name = "Offer%d" % cid
			b.text = "%s  ×%d" % [str(o.get("name", "")), left_n]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.disabled = left_n <= 0 or staged.size() >= MAX_CARDS
			b.pressed.connect(func(): send("nativeMailAttach", [cid]))
			list.add_child(b)

	_status(body, str(data("mailbox.native.status", "")))
	var actions := row(body)
	actions.add_theme_constant_override("separation", 16)
	var go := Button.new()
	go.name = "Send"
	go.text = I18n.t("mb.send")
	go.custom_minimum_size = Vector2(180, 54)
	OneBit.primary(go, 20)
	go.pressed.connect(func():
		send("nativeMailSend", [str(draft.get("to", "")),
			str(draft.get("title", "")), str(draft.get("message", ""))]))
	actions.add_child(go)
	var cancel := button(actions, I18n.t("mb.cancel"), func(): send("nativeMailCancel"))
	cancel.name = "Cancel"
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- small pieces ----------------------------------------------------------------

func _title_of(m: Dictionary) -> String:
	var t := str(m.get("title", "")).strip_edges()
	return t if t != "" else I18n.t("mb.no_title")


func _status(parent: Node, text: String) -> void:
	if text == "":
		return
	var l := label(parent, text, 15)
	l.name = "Status"
	if not bool(data("mailbox.native.statusOk", false)):
		l.add_theme_color_override("font_color", OneBit.MUTED)


## A small card: dithered art over its name. A button when `clickable`.
func _mini_card(cid: int, card_name: String, clickable := false) -> Control:
	var root: Control
	if clickable:
		var b := Button.new()
		b.add_theme_stylebox_override("normal", OneBit.box(OneBit.PAPER, OneBit.INK, 2, 4))
		b.add_theme_stylebox_override("hover", OneBit.box(OneBit.PAPER, OneBit.INK, 4, 4))
		b.add_theme_stylebox_override("pressed", OneBit.box(OneBit.PAPER, OneBit.INK, 4, 4))
		root = b
	else:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", OneBit.box(OneBit.PAPER, OneBit.INK, 2, 4))
		root = p
	root.custom_minimum_size = Vector2(88, 96)
	root.tooltip_text = card_name
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if clickable:
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 4
		col.offset_top = 4
		col.offset_right = -4
		col.offset_bottom = -4
	root.add_child(col)
	var art := TextureRect.new()
	art.texture = OneBit.card_art(cid)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(80, 60)
	art.material = OneBit.art_material()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(art)
	var n := Label.new()
	n.text = card_name
	n.add_theme_font_size_override("font_size", 11)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size.x = 80
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(n)
	return root
