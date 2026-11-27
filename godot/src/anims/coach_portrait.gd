extends Node2D
## S54 (paso 4): a coach as the menus show it — a picture of its full Meshy
## original, front on and level, in layers (tools/art/coach_portrait.gd
## renders them, build.py runs it): the body, tinted here with the skin and
## hair mask the way toon.gdshaderinc tints the 3D, and on it each worn piece
## in its own layer. It breathes, and hops where the 3D waved.
##
## The node's origin is the ground under the feet; one unit of the figure
## (it is 1.45 high) is `index.px` pixels at scale 1. Frames (FRAMES in the
## tool): "thigh" from mid-thigh up, "whole" the lot.

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const ArenaLayout := preload("res://src/maps/arena_layout.gd")
const DIR := "characters/out/portraits/%s/%s/"
## Drawn bottom to top: a slot later in the list covers the ones before.
const ORDER := ["mark", "cape", "pants", "skirt", "boots", "torso", "shoulders", "bracelets",
	"hat", "weapon", "pet"]
const BREATH := 0.006   # of the height, every BREATH_S seconds
const BREATH_S := 3.6

const COMPOSE := """
shader_type canvas_item;
uniform sampler2D light_tex : filter_linear;
uniform sampler2D mask_tex : filter_linear;
uniform vec4 skin_tint = vec4(1.0);
uniform vec4 hair_tint = vec4(1.0);
uniform float skin_ref = 1.0;
uniform float hair_ref = 1.0;
uniform vec4 hair_glow = vec4(0.0);
uniform float hair_pulse = 0.0;
uniform float rows = 1.0;   // the picture's height, in metres

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec4 p = texture(TEXTURE, UV);
	vec2 m = texture(mask_tex, UV).rg;
	vec4 lt = texture(light_tex, UV);
	vec3 c = lin(p.rgb);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, skin_tint.rgb * min(lum / skin_ref, 1.1), m.r);
	c = mix(c, hair_tint.rgb * min(lum / hair_ref, 1.1), m.g);
	// a hair effect (Fighter3D.HAIR_FX), as toon.gdshaderinc glows it
	float k = 0.0;
	if (hair_glow.a > 0.0) {
		float pulse = 0.75 + 0.25 * sin(TIME * hair_pulse + (1.0 - UV.y) * rows * 18.0);
		k = m.g * hair_glow.a * pulse;
		c = mix(c, hair_glow.rgb * (0.6 + 0.5 * dot(c, vec3(0.333))), k);
	}
	// the light layer is drawn at half (the ink at full: it is unlit)
	c = c * mix(vec3(1.0), 2.0 * lin(lt.rgb), lt.a) + hair_glow.rgb * k * 0.35;
	COLOR = vec4(srgb(c), p.a);
}
"""

static var _shader: Shader
static var _cache := {}   # path -> Texture2D, or null when it isn't there

var index := {}           # the frame's index.json
var hair_fx := 0          # the hair effect it shows (Fighter3D.HAIR_FX id)
var _key := ""
var _frame := ""
var _body: Sprite2D
var _pieces := {}         # slot -> Sprite2D
var _worn := {}           # slot -> piece
var _root: Node2D         # what breathes and hops
var _t := 0.0
var _hop: Tween


func _init() -> void:
	_root = Node2D.new()
	add_child(_root)


## Show coach `key` (Fighter3D.COACHES) in `frame`; false when its pictures
## aren't built.
func show_coach(key: String, frame := "thigh") -> bool:
	if key == _key and frame == _frame:
		return not index.is_empty()
	_key = key
	_frame = frame
	for c in _root.get_children():
		c.queue_free()
	_pieces = {}
	_worn = {}
	_body = null
	var txt := FileAccess.get_file_as_string(_dir() + "index.json")
	var ix = JSON.parse_string(txt) if txt != "" else null
	index = ix if ix is Dictionary else {}
	if index.is_empty():
		return false
	var lit := _tex("body_lit")
	if lit == null:
		index = {}
		return false
	if _shader == null:
		_shader = Shader.new()
		_shader.code = COMPOSE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("light_tex", _tex("body_light"))
	mat.set_shader_parameter("mask_tex", _tex("body_mask"))
	mat.set_shader_parameter("skin_ref", float(index.get("skin_ref", 1.0)))
	mat.set_shader_parameter("hair_ref", float(index.get("hair_ref", 1.0)))
	mat.set_shader_parameter("rows", float(index.layers.body_lit[3]) / float(index.px))
	_body = _sprite(lit, index.layers.body_lit)
	_body.material = mat
	_root.add_child(_body)
	return true


## Skin and hair, as Fighter3D.coach_tints gives them (sRGB colours).
func tint(skin: Color, hair: Color) -> void:
	if _body == null:
		return
	_body.material.set_shader_parameter("skin_tint", skin.srgb_to_linear())
	_body.material.set_shader_parameter("hair_tint", hair.srgb_to_linear())


## A hair effect (Fighter3D.HAIR_FX id; 0 = none): the hair glows.
func set_hair_fx(id: int) -> void:
	hair_fx = id
	if _body == null:
		return
	var fx: Dictionary = Fighter3D.HAIR_FX.get(id, {})
	var glow: Color = fx.get("glow", Color(0, 0, 0, 0))
	var lin := glow.srgb_to_linear()
	_body.material.set_shader_parameter("hair_glow", Color(lin.r, lin.g, lin.b, glow.a))
	_body.material.set_shader_parameter("hair_pulse", float(fx.get("pulse", 0.0)))


## Dress it in the coach's worn cards ([{slot, id}], as Fighter3D's).
func wear_coach_cards(cards: Array) -> void:
	var want := Fighter3D.coach_pieces(cards)
	for slot: String in Fighter3D.COACH_SLOT.values():
		var piece: String = want.get(slot, "")
		if piece == _worn.get(slot, ""):
			continue
		if _pieces.has(slot):
			(_pieces[slot] as Node).queue_free()
			_pieces.erase(slot)
		_worn[slot] = piece
		var r = index.get("pieces", {}).get(piece, {}).get("rect")
		var tex := _tex(piece) if r != null else null
		if tex == null:
			continue   # nothing of it shows in this frame (boots under a thigh cut)
		var s := _sprite(tex, r)
		s.z_index = 1 + ORDER.find(slot)
		_root.add_child(s)
		_pieces[slot] = s


func worn() -> Dictionary:
	return _worn


## A little hop where the 3D greeted or struck its pose.
func hop(height := 14.0) -> void:
	if _hop != null and _hop.is_valid():
		return
	_hop = create_tween().set_trans(Tween.TRANS_QUAD)
	_hop.tween_property(_root, "position:y", -height, 0.16).set_ease(Tween.EASE_OUT)
	_hop.tween_property(_root, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN)
	_hop.tween_property(_root, "scale", Vector2(1.03, 0.97), 0.06)
	_hop.tween_property(_root, "scale", Vector2.ONE, 0.12)


func _process(dt: float) -> void:
	_t += dt
	if _hop != null and _hop.is_running():
		return
	# breathing: a touch taller and back, from the ground up
	_root.scale = Vector2(1.0, 1.0 + BREATH * sin(TAU * _t / BREATH_S))


func _dir() -> String:
	return ArenaLayout.root().path_join(DIR % [_key, _frame])


func _tex(name: String) -> Texture2D:
	var path := _dir() + name + ".webp"
	if not _cache.has(path):
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		_cache[path] = ImageTexture.create_from_image(img) if img != null else null
	return _cache[path]


## A layer at its rect, the canvas placed so the origin is the ground.
func _sprite(tex: Texture2D, rect: Array) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	var foot: Array = index.foot
	s.position = Vector2(float(rect[0]) - float(foot[0]), float(rect[1]) - float(foot[1]))
	return s
