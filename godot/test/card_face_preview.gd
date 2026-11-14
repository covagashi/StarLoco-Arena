extends Node2D
## S38b: the card template (src/ui/card_face.gd) on real cards, offline: one
## of each family and rarity at the inventory tile's size (150 x 180), and a
## few at the detail's size. Writes a PNG to look at.
##   xvfb-run godot --path godot --resolution 1280x720 test/card_face_preview.tscn -- out.png

const CardFace := preload("res://src/ui/card_face.gd")
# coach gear (gold, copper), hair (coach, no piece), a consumable (silver), a
# combat rule, an arena (black), fusion, a DOFUS item, a cosmetic, a fighter weapon
const CARDS := [[185, false], [111, false], [130, false], [305, false], [1008, false],
	[202, false], [943, false], [1000, false], [950, false], [1, true]]


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
		f.position = Vector2(16 + (i % 7) * 176, 16 + (i / 7) * 200)
		f.size = Vector2(150, 180)
		add_child(f)
	for i in 3:
		var f := CardFace.make(int(CARDS[i * 3][0]), Vector2(250, 300), bool(CARDS[i * 3][1]))
		f.position = Vector2(560 + i * 240, 410)
		f.size = Vector2(250, 300)
		add_child(f)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("[card_face_preview] ", out)
	get_tree().quit()
