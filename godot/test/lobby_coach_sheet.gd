extends SceneTree
## S54 (paso 4): the lobby with a coach of our choosing, for the owner's
## sheets: no server, the lobby bound to a model that only has the coach.
##
##   xvfb-run -a godot --path godot --resolution 1920x1080 -s test/lobby_coach_sheet.gd -- \
##       --out=<png> [--sex=0|1] [--skin=N] [--hair=N] [--hairfx=N] [--pieces=hat_kepika,torso_kepika]
##       [--wait=2.5]   (seconds: the entrance and its hop are over by 2)

const Fighter3D := preload("res://src/anims/fighter3d.gd")
## A card's slot index (Fighter3D.COACH_SLOT) from its piece's name.
const SLOT := {"hat": 0, "mark": 1, "shoulders": 3, "bracelets": 4, "skirt": 5, "pants": 6,
	"banner": 7, "staff": 7, "cape": 8, "pet": 9, "boots": 10, "torso": 11}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/lobby_coach.png"
	var sex := 0
	var skin := 1
	var hair := 0
	var fx := 0
	var wait := 2.5
	var pieces: Array = []
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"sex": sex = int(kv[1])
			"skin": skin = int(kv[1])
			"hair": hair = int(kv[1])
			"hairfx": fx = int(kv[1])
			"wait": wait = float(kv[1])
			"pieces": pieces = Array(kv[1].split(","))
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://art/" + Fighter3D.PIECES)).get("coach", {})
	var card_of := {}
	for card in table:
		card_of[table[card]] = int(card)
	var worn := []
	for p: String in pieces:
		if card_of.has(p):
			worn.append({"slot": SLOT[p.get_slice("_", 0)], "id": card_of[p]})
		else:
			push_warning("[lobby_coach_sheet] no card shows " + p)
	var model := GuiModel.new()
	model.set_value("localCoach", {"name": "Arel", "level": 12, "sex": sex, "skin": skin, "hair": hair,
		"hairFx": fx, "worn": worn, "actorDescriptorLibrary": Fighter3D.coach_key(sex)})
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var lobby = load("res://src/ui/lobby_screen.gd").new()
	layer.add_child(lobby)
	lobby.bind_model(model, null)
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("[lobby_coach_sheet] ", out)
	quit(0)
