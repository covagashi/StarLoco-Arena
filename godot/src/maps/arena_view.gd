extends CanvasLayer

## M7 (S36, phase D): the owner's arena layout in 3D behind fight_view's 2D
## world. The arena is built once (arena_scene.gd) in its own SubViewport,
## shown full screen on a canvas layer under the world, and its orthographic
## camera follows the fight's Camera2D, so cell (x, y) at altitude a lands
## where fight_view's _iso puts it: ((x - y) * 43, (x + y) * 21.5 - a * 10)
## for the cell's centre (x + 0.5, y + 0.5).
##
## The viewport only renders when the camera or the window moves: the arena
## is static.
##
## Occlusion: a second viewport renders the same world through a full-screen
## quad that writes each pixel's depth, d = 0.612 (x + z) + 0.5 y (larger is
## nearer the camera), in three 5-bit digits. The 2D things standing in the
## arena (fighters, ground marks) get occluder(alt): a canvas shader that
## works out the depth of its own pixel and hides it where the arena is
## nearer, so a pillar in front covers a fighter and a tree hides the zone
## behind it.

## d per unit of x + z and of y: the camera looks down 30° from the +x+z
## corner, so its forward axis is (-cos30 sin45, -sin30, -cos30 cos45).
const DX := 0.6123724
const DY := 0.5
## Encoded depth range: d' = (d + D_OFF) / D_RANGE in 0..1.
const D_OFF := 16.0
const D_RANGE := 112.0
## The quad only the depth camera sees.
const DEPTH_LAYER := 1 << 19
## How much nearer the arena must be to cover a 2D pixel (depth units), so
## that a cell's own top never covers what stands on it: the blocks' caps
## (snow lumps, moss, grass) stand up to ~0.5 m over the walk surface, about
## 0.26 in depth. A neighbour's prop is 0.61 nearer and still covers.
const BIAS_UP := 0.45
const BIAS_FLAT := 0.35

const DEPTH_SHADER_CODE := """
shader_type spatial;
%s
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

void fragment() {
	float z = texture(depth_tex, SCREEN_UV).r;
	vec3 e = vec3(0.0);
	if (z < 0.9999) {
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
		vec3 w = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
		float d = clamp((DX * (w.x + w.z) + DY * w.y + D_OFF) / D_RANGE, 0.0, 0.99999);
		float q = floor(d * 32768.0);
		e = vec3(floor(q / 1024.0), mod(floor(q / 32.0), 32.0), mod(q, 32.0)) / 31.0;
	}
	// unshaded with the linear tonemap: the digits reach the texture as written
	ALBEDO = e;
}
"""

const OCCLUDE_SHADER_CODE := """
shader_type canvas_item;
%s
uniform sampler2D arena_depth : filter_nearest;
// the surface this item stands on, in altitude steps
uniform float alt = 0.0;
// fighters: their feet (the item's origin) hold one depth for the whole
// body; marks lie flat, every pixel at its own depth on the surface
uniform bool upright = false;
varying float foot_y;
varying float pix_y;

void vertex() {
	foot_y = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
	pix_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec3 e = floor(texture(arena_depth, SCREEN_UV).rgb * 31.0 + 0.5);
	float scene = (e.r * 1024.0 + e.g * 32.0 + e.b) / 32768.0 * D_RANGE - D_OFF;
	// screen y -> x + z on the surface: fight_view's _iso inverted
	float y = upright ? max(pix_y, foot_y) : pix_y;
	float d = DX * (y + 21.5 + alt * 10.0) / 21.5 + DY * alt * ALT;
	if (e != vec3(0.0) && scene > d + (upright ? BIAS_UP : BIAS_FLAT)) {
		discard;
	}
}
"""

const Layout := preload("res://src/maps/arena_layout.gd")
const ArenaScene := preload("res://src/maps/arena_scene.gd")

## The fight camera the 3D one copies.
var follow: Camera2D
var world := -1
## The shape the layout was built on (layout roles and heights applied).
var shape := {}

var _vp: SubViewport
var _depth_vp: SubViewport
var _rect: TextureRect
var _cam: Camera3D
var _depth_cam: Camera3D
var _root: Node3D
var _builder := ArenaScene.new()
var _last := Vector4(INF, INF, INF, INF)
## alt*2 + upright -> the occluder material for 2D items standing there
var _occluders := {}
static var _occlude_shader: Shader


## The arena number of a world, or 0 when it has no layout to draw.
static func arena_of(world_id: int) -> int:
	var arena: int = Layout.WORLDS.find(world_id) + 1
	if arena < 1 or not FileAccess.file_exists(Layout.layout_path(arena)):
		return 0
	return arena if not Layout.load_layout(arena).cells.is_empty() else 0


## The shaders' constants, the same numbers as here.
static func _defines() -> String:
	return "const float DX = %f; const float DY = %f; const float D_OFF = %f; " % [DX, DY, D_OFF] \
		+ "const float D_RANGE = %f; const float ALT = %f; " % [D_RANGE, Layout.ALT] \
		+ "const float BIAS_UP = %f; const float BIAS_FLAT = %f;" % [BIAS_UP, BIAS_FLAT]


func _init() -> void:
	layer = -1
	var w := World3D.new()
	_vp = _viewport(w)
	_vp.msaa_3d = Viewport.MSAA_4X
	_depth_vp = _viewport(w)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.texture = _vp.get_texture()
	add_child(_rect)


func _viewport(w: World3D) -> SubViewport:
	var vp := SubViewport.new()
	vp.world_3d = w
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	return vp


## Builds the world's layout; false (and nothing shown) without one.
func load_world(world_id: int) -> bool:
	for n in [_root, _cam, _depth_cam]:
		if n != null:
			n.free()
	_root = null
	world = world_id
	var arena := arena_of(world_id)
	visible = arena > 0
	if arena == 0:
		shape = {}
		return false
	var layout := Layout.load_layout(arena)
	shape = Layout.shape(world_id)
	Layout.apply_roles(shape, layout.roles)
	Layout.apply_alts(shape, layout.alts)
	_root = Node3D.new()
	_vp.add_child(_root)
	ArenaScene.add_lights(_root)
	var cells := Node3D.new()
	for p: Vector2i in layout.cells:
		if not shape.cells.has(p) or shape.cells[p].role == "void":
			continue
		cells.add_child(_builder.build_cell(p, shape.cells[p], layout.cells[p], shape.floor_y))
	_root.add_child(_builder.flatten(cells))
	cells.free()
	_cam = ArenaScene.game_camera(720.0, 1.0, Vector3.ZERO)
	_cam.cull_mask &= ~DEPTH_LAYER
	_vp.add_child(_cam)
	_cam.current = true
	_depth_cam = ArenaScene.game_camera(720.0, 1.0, Vector3.ZERO)
	_depth_vp.add_child(_depth_cam)
	_depth_cam.current = true
	_depth_cam.add_child(_depth_quad())
	_last = Vector4(INF, INF, INF, INF)
	_sync()
	return true


## The full-screen quad that turns the depth camera's picture into depth.
func _depth_quad() -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = DEPTH_SHADER_CODE % _defines()
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var q := QuadMesh.new()
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.layers = DEPTH_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.position = Vector3(0, 0, -1)
	return mi


## The material that hides a 2D item where the arena stands in front of it:
## items standing on a surface at `alt` steps, upright (a fighter: one depth,
## its feet's) or flat on the ground (a mark). null without an arena.
func occluder(alt: int, upright: bool) -> ShaderMaterial:
	if _root == null:
		return null
	var key := alt * 2 + int(upright)
	if not _occluders.has(key):
		if _occlude_shader == null:
			_occlude_shader = Shader.new()
			_occlude_shader.code = OCCLUDE_SHADER_CODE % _defines()
		var m := ShaderMaterial.new()
		m.shader = _occlude_shader
		m.set_shader_parameter("arena_depth", _depth_vp.get_texture())
		m.set_shader_parameter("alt", float(alt))
		m.set_shader_parameter("upright", upright)
		_occluders[key] = m
	return _occluders[key]


func _process(_dt: float) -> void:
	_sync()


func _sync() -> void:
	if _root == null or follow == null or not is_inside_tree():
		return
	var size := Vector2i(get_viewport().get_visible_rect().size)
	var c := follow.get_screen_center_position()
	var z := follow.zoom.x
	var key := Vector4(c.x, c.y, z, size.x * 100000 + size.y)
	if key == _last:
		return
	_last = key
	for vp: SubViewport in [_vp, _depth_vp]:
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for cam: Camera3D in [_cam, _depth_cam]:
		cam.size = size.y / (Layout.PX * z)
		cam.position = to_3d(c) + cam.transform.basis.z * 60.0


## The point on the y = 0 plane that fight_view draws at screen point s.
static func to_3d(s: Vector2) -> Vector3:
	var u := s.x / 43.0            # x - z
	var v := s.y / 21.5 + 1.0      # x + z
	return Vector3((u + v) * 0.5, 0.0, (v - u) * 0.5)
