extends CanvasLayer
## 1-bit light beats (sprints/S04): a critical hit or a death dims the world
## for an instant around a pool of light at the impact (onebit_flash.gdshader).
## Under the HUD, over the map and the fighters. Only the 1-bit style uses it.

## darkness peak, rise, hold and fall (s) per kind of beat
const BEATS := {
	"crit": [0.55, 0.06, 0.12, 0.45],
	"death": [0.75, 0.08, 0.30, 0.70],
}

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var _world_pos := Vector2.ZERO
var _radius := 140.0


func _init() -> void:
	name = "OneBitFlash"
	layer = 1
	_rect = ColorRect.new()
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/fight/onebit_flash.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## A beat of `kind` lit at `world_pos` (the fight view's own coordinates).
func beat(kind: String, world_pos: Vector2, zoom := 1.0) -> void:
	var b: Array = BEATS.get(kind, BEATS.crit)
	_world_pos = world_pos
	_radius = 140.0 * zoom
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_rect.visible = true
	_place()
	_tween = create_tween()
	_tween.tween_method(_set_dark, 0.0, float(b[0]), float(b[1]))
	_tween.tween_interval(float(b[2]))
	_tween.tween_method(_set_dark, float(b[0]), 0.0, float(b[3]))
	_tween.tween_callback(func(): _rect.visible = false)


func darkness() -> float:
	return float(_mat.get_shader_parameter("darkness"))


func _set_dark(v: float) -> void:
	_mat.set_shader_parameter("darkness", v)


func _process(_delta: float) -> void:
	if _rect.visible:
		_place()


## Follow the camera: the light stays on the impact as the view moves.
func _place() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	_mat.set_shader_parameter("light_pos", vp.get_canvas_transform() * _world_pos)
	_mat.set_shader_parameter("light_radius", _radius)
