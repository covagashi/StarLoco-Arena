extends Node2D

## The node every screen places a coach, a fighter or a summon with: it
## hosts the 3D figure (fighter3d.gd, `model3d`) and hands it the actions
## the game asks for ("<dir>_AnimStatique"): Fighter3D.take turns them into
## the model's own clip and facing. S43: it only ever shows our figures;
## a key with no built figure shows nothing (load_action returns false and
## the caller's fallback chain goes on).
##
## A figure key is the figure's own name (Fighter3D.figure_of): "coach_7000"
## / "coach_7001" for a coach, a breed's model ("feca_m") for a fighter,
## "summon_<look>" for a summon.

const Fighter3D := preload("res://src/anims/fighter3d.gd")

var playing := true
## One-shot mode (cast/hit/death gestures): plays once, stops, emits
## action_finished. `hold_last` keeps the last pose (death).
var once := false
var hold_last := false
var current := ""       # "<key>/<action>" of the action playing — tests hook
signal action_finished
## Kept for the menus that set it: a figure's origin is always its feet.
var foot_pivot := false

## Colour channels picked for a coach: {1: skin, 2: hair} (Palettes
## .coach_tints); a coach figure wears them as Toon tints.
var tints := {}

var model3d: Node2D = null:
	set(m):
		if model3d != null:
			model3d.queue_free()
		model3d = m
		if m != null:
			add_child(m)
			m.finished.connect(func():
				playing = false
				action_finished.emit())

## A key with a built figure attaches it on the first load_action; a node
## that got its model from elsewhere (fight_view, sized per summon) keeps it.
var auto_model := true
var _model_set := ""
var _model_tints := {}


## Play `action` looping on the figure for `key`. The explicit `tints`
## override `self.tints` when non-empty. False when there is no figure or
## it has no clip for the action (the previous one keeps playing).
func load_action(key: String, action: String, tints := {}) -> bool:
	_auto_model(key, tints if not tints.is_empty() else self.tints)
	if model3d == null or not model3d.take(action, false, false):
		return false
	current = "%s/%s" % [key, action]
	once = false
	hold_last = false
	playing = true
	return true


## Play a gesture once (cast/hit/death); `hold` keeps its last pose.
func play_once(key: String, action: String, hold := false) -> bool:
	_auto_model(key, self.tints)
	if model3d == null or not model3d.take(action, true, hold):
		return false
	current = "%s/%s" % [key, action]
	once = true
	hold_last = hold
	playing = true
	return true


## Attach (or retint, or swap) the figure for `key`.
func _auto_model(key: String, eff: Dictionary) -> void:
	if not auto_model or (model3d != null and _model_set == ""):
		return
	var fig := Fighter3D.for_set(key)
	if fig.is_empty():
		if _model_set != "":
			_model_set = ""
			model3d = null
		return
	var t: Dictionary = Fighter3D.from_channels(eff) if fig.coach else {}
	if _model_set == fig.path and model3d != null:
		if t != _model_tints:
			_model_tints = t
			model3d.retint(t, fig.path)
		return
	# one viewport pixel per screen pixel at the node's scale (a menu draws
	# the coach 2.5× big), never under the fight's 2×
	var res := maxf(Fighter3D.RES, absf(scale.x))
	var m := Fighter3D.create(fig.path, t, fig.scale, res)
	if m == null:
		return
	_model_tints = t
	model3d = m
	_model_set = fig.path
