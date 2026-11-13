extends Node3D
## S38: the equipment icons from our own 3D pieces (S35c, art/equipment):
## each fighter card's piece (pieces.json "fighter") is rendered in a small
## studio — three-quarter view, the game's toon shading, transparent
## background — and fitted to the frame. Writes the bare render to
## art/ui/out/equip/<card>.png (built, not in git); tools/icons/equip_icons.py
## then sets it on its style B plate in assets/ui/equip/. Coach cards
## ("coach") with --coach, into equip_coach/.
##   xvfb-run godot --path godot --resolution 512x512 tools/icons/equip_icons.tscn [-- --coach]

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const Toon := preload("res://src/anims/toon.gd")
const SIDE := 256

var _vp: SubViewport
var _cam: Camera3D
var _pivot: Node3D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIDE, SIDE)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.ambient_light_energy = 0.6
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.2
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_run.call_deferred()


func _run() -> void:
	var coach := "--coach" in OS.get_cmdline_user_args()
	var out := "res://art/ui/out/%s/" % ("equip_coach" if coach else "equip")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/equipment/pieces.json"))
	var table: Dictionary = pieces["coach" if coach else "fighter"]
	var made := 0
	for cid in table:
		var path := Fighter3D.piece_path(str(table[cid]))
		if path == "":
			print("[equip] not built: ", table[cid])
			continue
		var t := Fighter3D._template(path)
		if t == null:
			continue
		var n: Node3D = t.duplicate()
		Toon.dress(n)
		_pivot.add_child(n)
		# three-quarter view, the piece's bounds fill the frame
		_pivot.rotation_degrees = Vector3(0, 35, 0)
		var box := _bounds(n)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		_cam.size = r * 2.1
		# the outline is measured in screen pixels of this camera (2 px here)
		Toon.set_pixel(_cam.size / SIDE * 1.4)
		_cam.position = c + Vector3(0, r * 0.45, r * 3.0)
		_cam.look_at(c, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png(out + "%s.png" % str(cid))
		made += 1
		n.queue_free()
		await get_tree().process_frame
	print("[equip] made ", made, " of ", table.size())
	get_tree().quit()


## World bounds of every mesh under `n` (after the pivot's turn).
func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
