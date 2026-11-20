extends "res://test/world_smoke.gd"

## S50: the coach's fighter slots, live. In Spanish.
##
##   godot/tools/seeded_smoke.sh slots_smoke   (leaves `test` 8 fighters)
##
## With every slot taken (8/8), Equipo says "Plazas 8/8" and "Crear
## luchador" answers with a toast instead of opening the recruit screen. The
## GM grants one (/FIGHTERSLOT test, 3153): the server re-sends 60001 with
## fighter_slots 9, the panel says 8/9 and the button opens the screen.



func _audit() -> void:
	var i18n = root.get_node("I18n")
	i18n.set_locale("es")
	var panel = await _team()
	var slots: Label = panel.find_child("Slots", true, false) if panel != null else null
	var full_text: String = i18n.t("team.slots", {"used": State.roster.size(), "slots": State.fighter_slots})
	_record(6000, "slots shown", slots != null and slots.text == full_text
		and State.roster.size() == 8 and State.fighter_slots == 8,
		"'%s', %d fighters, %d slots" % [slots.text if slots != null else "—", State.roster.size(), State.fighter_slots])
	_press_create(panel)
	await create_timer(0.6).timeout
	var toast := _toast_text()
	_record(6000, "full", not _main._gui.is_open("fighterCreationDialog")
		and toast.begins_with("Tienes todas tus plazas"), "toast '%s', recruit screen %s" % [
			toast, "open" if _main._gui.is_open("fighterCreationDialog") else "closed"])
	var line := "/FIGHTERSLOT test".to_ascii_buffer()
	var w := WireWriter.new()
	w.put_u16(line.size())
	w.put_bytes(line)
	_sess.send(3153, w.raw(), 3)
	var granted: bool = await _wait(func(): return State.fighter_slots == 9, 4.0)
	panel = await _team()
	slots = panel.find_child("Slots", true, false) if panel != null else null
	_record(6000, "granted", granted and slots != null and slots.text == "Plazas 8/9",
		"60001 fighter_slots → %d, '%s'" % [State.fighter_slots, slots.text if slots != null else "—"])
	_press_create(panel)
	var opened: bool = await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 3.0)
	_record(6000, "room", opened, "with 8/9 the recruit screen opens")
	_close_all()


func _team():
	_close_all()
	_main._gui.open("teamManagementDialog")
	await _wait(func(): return _main._gui.is_open("teamManagementDialog"), 3.0)
	await create_timer(0.5).timeout
	return _main._gui.dialogs.get("teamManagementDialog")


func _press_create(panel) -> void:
	if panel == null:
		return
	for b in panel.find_children("*", "Button", true, false):
		if b.text == root.get_node("I18n").t("team.create_fighter"):
			b.pressed.emit()
			return


func _toast_text() -> String:
	var box = _main.get_node_or_null("Toasts/ToastBox")
	if box == null or box.get_child_count() == 0:
		return ""
	var lab = box.get_child(box.get_child_count() - 1).find_child("*", true, false)
	return lab.text if lab is Label else ""
