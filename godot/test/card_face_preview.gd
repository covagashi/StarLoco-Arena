extends Node2D
## S38b: the card template (src/ui/card_face.gd) on real cards, offline:
## every family and every rarity at the inventory tile's size (150 x 180),
## and four at the detail's size (250 x 300). Writes a PNG to look at.
##   xvfb-run godot --path godot --resolution 1280x720 test/card_face_preview.tscn -- out.png

const CardFace := preload("res://src/ui/card_face.gd")
# [card, is_fighter] — row 1: coach gear gold and copper, a haircut (coach,
# no piece → hair), a consumable (silver), a combat rule (copper), an arena
# (black), fusion (copper); row 2: a DOFUS item (copper) and the champion set
# (gold), a long one-word title (copper), a hair colour (gold), a title (gold), an "other"
# (silver), a fighter weapon (silver)
const CARDS := [[185, false], [111, false], [105, false], [305, false], [1008, false], [202, false], [943, false],
	[1000, false], [831, false], [1004, false], [878, false], [1003, false], [100, false], [1, true]]
const BIG := [[185, false], [105, false], [1000, false], [202, false]]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/card_face_preview.png"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	var bg := ColorRect.new()
	bg.color = Color("e9ecf1")
	bg.size = Vector2(1280, 720)
	add_child(bg)
	for i in CARDS.size():
		var f := CardFace.make(int(CARDS[i][0]), Vector2(150, 180), bool(CARDS[i][1]), "", "Valor 79")
		f.position = Vector2(16 + (i % 7) * 176, 12 + (i / 7) * 192)
		f.size = Vector2(150, 180)
		add_child(f)
	for i in BIG.size():
		var f := CardFace.make(int(BIG[i][0]), Vector2(250, 300), bool(BIG[i][1]))
		f.position = Vector2(16 + i * 262, 404)
		f.size = Vector2(250, 300)
		add_child(f)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("[card_face_preview] ", out)
	get_tree().quit()
