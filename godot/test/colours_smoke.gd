extends "res://test/world_smoke.gd"

## S07: a fighter is created without a colour pick and keeps its breed's
## own colours, against a live server.
##
##   godot --path godot -s test/colours_smoke.gd
##
## Opens "Nuevo luchador" the way the Team panel does, checks the form has
## no skin/hair/eye pickers, creates the fighter and waits for the roster:
## the server stores and sends back the no-tint index (255), and the
## fighter's tints are empty — the art's own colours. Adds one evolution
## fighter to `test`; restore server/arena.db afterwards.

const NAME := "Tinte"


func _audit() -> void:
	_main._on_new_fighter_dialog([], null, true)
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 3.0)
	await create_timer(0.4).timeout
	var p = _main._gui.dialogs.get("fighterCreationDialog")
	if p == null:
		_record(6001, "form", false, "no creation panel")
		return
	# the old pickers were OptionButtons of 47 colours each
	var pickers: Array = p.find_children("*", "OptionButton", true, false) \
		.filter(func(o): return o.item_count > 12)
	var preview_tints: Dictionary = p._preview.tints if p._preview != null else {"?": 0}
	_record(6001, "form", pickers.is_empty() and preview_tints.is_empty(),
		"%d colour picker(s), preview tints %s" % [pickers.size(), preview_tints])
	var edit: LineEdit = p.find_children("*", "LineEdit", true, false)[0]
	edit.text = NAME
	var create: Button = null
	for b in p.find_children("*", "Button", true, false):
		if b.text == root.get_node("I18n").t("fc.create"):
			create = b
	_seen.clear()
	create.pressed.emit()
	await _wait(func(): return _seen.has(6000) and _seen.has(6006), 5.0)
	await create_timer(0.5).timeout
	var made: Dictionary = {}
	for f in State.roster:
		if str(f.get("name", "")) == NAME:
			made = f
	var tints: Dictionary = Palettes.fighter_tints(int(made.get("skin", -1)),
		int(made.get("hair", -1)), int(made.get("eye", -1))) if not made.is_empty() else {"?": 0}
	_record(6001, "created", not made.is_empty() and int(made.get("hair", 0)) == 255
		and int(made.get("skin", 0)) == 255 and int(made.get("eye", 0)) == 255 and tints.is_empty(),
		"6000 + roster: hair %s skin %s eye %s → tints %s" % [made.get("hair"), made.get("skin"),
			made.get("eye"), tints])
