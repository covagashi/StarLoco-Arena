extends "res://test/world_smoke.gd"

## S18: the native mailbox end to end, against a live server.
##
##   godot --path godot -s test/mailbox_smoke.gd [-- --shot-dir=D]
##
## Opens the mailbox from the City panel, checks the native panel, writes a
## message to the `test` coach itself with one card attached (typing into
## the real fields, checking the name), sends it, finds it in the inbox,
## takes the card back and deletes the message: the inventory ends where it
## started. Needs a tradable card on `test` (see cardmaster_smoke.gd).
## Reuses world_smoke's login, City and report helpers.

# load()ed at run time: the panel names the I18n autoload (see native_panels.gd).
var MailboxPanel: GDScript


func _audit() -> void:
	MailboxPanel = load("res://src/ui/mailbox_panel.gd")
	var city_panel = await _open_city()
	var sid := -1
	if city_panel != null:
		var city: Dictionary = _main._gui.gui.model.get_value("city")
		for g in city.get("groups", []):
			if int(g.kind) == 2 and not g.services.is_empty():
				sid = int(g.services[0].id)
				break
	var b: Button = await _service_button(sid) if sid > 0 else null
	if b == null:
		_record(2, "Mailbox", false, "no mailbox in the City panel")
		return
	_seen.clear()
	b.pressed.emit()
	var ok: bool = await _wait(func(): return _seen.has(15001) \
		and _main._gui.is_open("mailboxDialog"), 3.0)
	var panel = _main._gui.dialogs.get("mailboxDialog")
	_record(2, "opens", ok and is_instance_of(panel, MailboxPanel)
		and not _debug_pane_shown(),
		"native panel, no debug pane" if is_instance_of(panel, MailboxPanel) \
			else "not native: %s" % panel)
	if not is_instance_of(panel, MailboxPanel):
		return
	await create_timer(0.3).timeout
	await _shot("mb-inbox")
	await _round_trip(panel)


func _round_trip(panel) -> void:
	var offer: Array = _main._gui.gui.model.get_value("mailbox.native").offer
	if offer.is_empty():
		_record(2, "attach", false, "the test coach has no tradable card")
		return
	var cid := int(offer[0].id)
	var before := int(State.inventory.get(cid, 0))
	var subject := "smoke %d" % Time.get_ticks_msec()
	panel.find_child("New", true, false).pressed.emit()
	await create_timer(0.3).timeout
	var to: LineEdit = panel.find_child("To", true, false)
	_record(2, "compose", to != null, "compose view")
	if to == null:
		return
	to.grab_focus()
	_type(to, "test")
	panel.find_child("Check", true, false).pressed.emit()
	var found: bool = await _wait(func(): return panel.find_child("Found", true, false) != null \
		and int(_main._gui.gui.model.get_value("mailbox.newMail", "receiverId")) > 0, 3.0)
	_record(2, "check name", found, "15506 → 15507")
	var subj: LineEdit = panel.find_child("Subject", true, false)
	_type(subj, subject)
	var body: TextEdit = panel.find_child("Body", true, false)
	body.insert_text_at_caret("Native mailbox smoke.")
	panel.find_child("Offer%d" % cid, true, false).pressed.emit()
	await create_timer(0.3).timeout
	var cards: Array = _main._gui.gui.model.get_value("mailbox.newMail", "cards")
	_record(2, "attach", cards.size() == 1 and panel.find_child("Attached0", true, false) != null
		and str(panel.draft.get("message", "")) == "Native mailbox smoke.",
		"%s, typed text kept across the rebuild" % _card_name(cid))
	await _shot("mb-compose")
	_seen.clear()
	panel.find_child("Send", true, false).pressed.emit()
	var sent: bool = await _wait(func(): return _seen.has(15003) and _seen.has(15001) \
		and _main._gui.gui.model.get_value("mailbox.native").mode == "list", 4.0)
	_record(2, "send", sent and int(State.inventory.get(cid, 0)) == before - 1,
		"15003 + list refresh, %s %d → %d, status '%s'" % [_card_name(cid), before,
			int(State.inventory.get(cid, 0)),
			_main._gui.gui.model.get_value("mailbox.native").status])
	await create_timer(0.4).timeout
	# The message to yourself lands in the inbox: open it by its row.
	var mid := -1
	for m in _main._gui.gui.model.get_value("mailManager").receivedMails:
		if str(m.get("title", "")) == subject:
			mid = int(m.mailId)
	var tree: Tree = panel.find_child("Mails", true, false)
	var row_item: TreeItem = null
	if tree != null:
		for it in tree.get_root().get_children():
			var md: Variant = it.get_metadata(0)
			if md is Dictionary and int(md.get("id", 0)) == mid:
				row_item = it
	if row_item != null:
		row_item.select(0)
	await create_timer(0.3).timeout
	var open: Variant = _main._gui.gui.model.get_value("mailbox.mail")
	_record(2, "read", mid > 0 and open is Dictionary and int(open.get("mailId", 0)) == mid
		and panel.find_child("Take", true, false) != null,
		"inbox row %d opened" % mid)
	await _shot("mb-read")
	var take: Button = panel.find_child("Take", true, false)
	if take == null:
		return
	_seen.clear()
	take.pressed.emit()
	var back: bool = await _wait(func(): return _seen.has(15007) \
		and int(State.inventory.get(cid, 0)) == before, 3.0)
	await create_timer(0.3).timeout
	_record(2, "take", back and panel.find_child("Take", true, false) == null,
		"15007, %s back to %d" % [_card_name(cid), int(State.inventory.get(cid, 0))])
	var del: Button = panel.find_child("Delete", true, false)
	del.pressed.emit()
	await create_timer(0.3).timeout
	var asked: bool = _main._mails.any(func(m): return int(m.get("id", 0)) == mid)
	panel.find_child("Delete", true, false).pressed.emit()
	await create_timer(0.3).timeout
	_record(2, "delete", asked and not _main._mails.any(
		func(m): return int(m.get("id", 0)) == mid),
		"first click asks, second deletes")


## Type into a LineEdit like the keyboard does: insert_text_at_caret()
## alone does not emit text_changed, real key input does.
func _type(edit: LineEdit, text: String) -> void:
	edit.insert_text_at_caret(text)
	edit.text_changed.emit(edit.text)


func _card_name(cid: int) -> String:
	return str(load("res://src/gamedata/cards.gd").name_of(cid))
