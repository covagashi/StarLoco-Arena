class_name GuiLayer
extends CanvasLayer
## Hosts XULOR2 dialogs on a CanvasLayer and routes dofusarena:* widget
## events to a handler map. One GuiLib per layer (theme + model shared).

signal dialog_opened(name: String)

var gui: GuiLib
var handlers := {}          # method -> Callable(args, widget)
var dialogs := {}           # name -> GWidget root
var settings_path := "user://gui_settings.cfg"

## event-name → xml file when they differ (retail registers screens under
## logical names, not file names)
const DIALOG_ALIASES := {
	"coachInventoryDialog": "cardBookDialog",
	# the generic toggle names the old drag-only lab; the tray UI is the
	# functional one we wired
	"fusionLaboratoryDialog": "fusionLabDialog",
	# openCloseTeamXvsXNameDialog names the 2v2 name screen logically
	"teamXvsXNameDialog": "team2vs2NameDialog",
}


func _file_for(name: String) -> String:
	return DIALOG_ALIASES.get(name, name)


func _init() -> void:
	layer = 10
	gui = GuiLib.new(_saved_lang())
	gui.event_sink = _on_event


func _ready() -> void:
	_load_settings()


func open(name: String, model_values := {}) -> GWidget:
	var fname := _file_for(name)
	var root := gui.open_dialog(fname, model_values)
	if root == null:
		return null
	var vp := get_viewport().get_visible_rect().size
	add_child(root)
	_place_root(root, vp)
	dialogs[fname] = root
	GuiLayouts.apply(root)
	root.resized.connect(func(): GuiLayouts.apply(root))
	get_viewport().size_changed.connect(func(): _relayout(root))
	dialog_opened.emit(fname)
	return root


func close(name: String) -> void:
	var fname := _file_for(name)
	if dialogs.has(fname):
		dialogs[fname].queue_free()
		dialogs.erase(fname)


func is_open(name: String) -> bool:
	return dialogs.has(_file_for(name))


## openClose<XxxDialog> toggles; close<XxxDialog> always closes.
func toggle(name: String, model_values := {}) -> GWidget:
	if is_open(name):
		close(name)
		return null
	return open(name, model_values)


func on(method: String, cb: Callable) -> void:
	handlers[method] = cb


func _relayout(root: GWidget) -> void:
	_place_root(root, get_viewport().get_visible_rect().size)
	GuiLayouts.apply(root)


## Places a dialog root inside the viewport like the retail layer does:
## the root's own <sld> (align/size/xOff/yOff) resolves against the
## viewport; roots that specify nothing get their preferred size centered,
## and only truly sizeless roots stretch to the screen.
func _place_root(root: GWidget, vp: Vector2) -> void:
	var ld: Dictionary = root.layout_data
	var want := root.get_minimum_size()
	var size := want
	if ld.has("size"):
		var sv: Array = ld["size"]
		size = Vector2(_ld_axis(sv[0], want.x, vp.x),
			_ld_axis(sv[1], want.y, vp.y))
	elif root.layout.get("adaptToContentSize") in [true, "true"]:
		size = want
	elif want == Vector2.ZERO:
		size = vp
	var a: Vector2 = GuiLayouts.ALIGN.get(
		String(ld.get("align", "center")).to_lower(), Vector2(0.5, 0.5))
	root.position = a * (vp - size) + Vector2(
		float(ld.get("xOff", 0)), float(ld.get("yOff", 0)))
	root.size = size


static func _ld_axis(spec: Variant, want: float, avail: float) -> float:
	if spec is String and String(spec).ends_with("%"):
		return avail * float(String(spec).rstrip("%")) / 100.0
	var f := float(spec)
	if f <= 0:  # -1 min / -2 pref / 0 — resolve to the preferred extent
		return want
	return f


func _on_event(ns: String, method: String, args: Array, widget: GWidget) -> void:
	match method:
		"setLanguage":
			var lang := str(args[0]) if args.size() > 0 else "en"
			gui.model.set_value("gamePreferences", lang, "language")
			gui.load_i18n(lang)
			_save_settings()
			_rebuild_open_dialogs()
		"showUrl":
			pass
		"quit":
			get_tree().quit()
		_:
			# dofusarena:openCloseXxxDialog / closeXxxDialog are generic
			# dialog toggles — the name is already the file name
			if method.begins_with("openClose") and \
					method.ends_with("Dialog"):
				toggle(method.trim_prefix("openClose"))
				return
			if method.begins_with("close") and \
					method.ends_with("Dialog"):
				close(method.trim_prefix("close"))
				return
			var h: Callable = handlers.get(method, Callable())
			if h.is_valid():
				h.call(args, widget)
				_save_settings()


func _rebuild_open_dialogs() -> void:
	var open_names := dialogs.keys()
	for n in open_names:
		close(n)
	for n in open_names:
		open(n)


func _saved_lang() -> String:
	var c := ConfigFile.new()
	if c.load(settings_path) == OK:
		return str(c.get_value("gui", "language", "es"))
	return "es"


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(settings_path) != OK:
		return
	gui.model.values["account.name"] = c.get_value("account", "name", "")
	gui.model.values["account.remember"] = c.get_value("account", "remember", false)
	if gui.model.values["account.remember"]:
		gui.model.values["account.password"] = c.get_value("account", "password", "")
	var hosts: Array = c.get_value("proxy", "list", ["140.238.172.196:3000", "127.0.0.1:5555"])
	gui.model.values["proxy"] = {
		"list": hosts.map(func(h): return {"text": h}),
		"selected": c.get_value("proxy", "selected", hosts[0]),
	}
	gui.model.values["gamePreferences"] = {
		"language": c.get_value("gui", "language", "es"),
		"inverseMouseControl": c.get_value("prefs", "inverseMouseControl", false),
		"showFighterMoveRange": c.get_value("prefs", "showFighterMoveRange", true),
		"saveReplays": c.get_value("prefs", "saveReplays", true),
		"alphaMaskActivated": c.get_value("prefs", "alphaMaskActivated", true),
		"gridActivated": c.get_value("prefs", "gridActivated", false),
		"musicMute": c.get_value("prefs", "musicMute", false),
		"musicVolume": c.get_value("prefs", "musicVolume", 0.5),
		"ambianceSoundsMute": c.get_value("prefs", "ambianceSoundsMute", false),
		"ambianceSoundsVolume": c.get_value("prefs", "ambianceSoundsVolume", 0.5),
		"activateParticles": c.get_value("prefs", "activateParticles", true),
		"vsyncActivated": c.get_value("prefs", "vsyncActivated", true),
		"shadersActivated": c.get_value("prefs", "shadersActivated", true),
		"shadersEnabled": c.get_value("prefs", "shadersEnabled", true),
		"fullScreen": c.get_value("prefs", "fullScreen", false),
		"screenResolution": c.get_value("prefs", "screenResolution", ""),
		"screenResolutions": [],
	}
	gui.model.values["buildVersion"] = "2.70 (72909)"


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.load(settings_path)
	var gp: Dictionary = gui.model.values.get("gamePreferences", {})
	c.set_value("gui", "language", gp.get("language", "es"))
	c.set_value("account", "name", gui.model.values.get("account.name", ""))
	var rem: bool = gui.model.values.get("account.remember", false)
	c.set_value("account", "remember", rem)
	c.set_value("account", "password",
		gui.model.values.get("account.password", "") if rem else "")
	c.set_value("proxy", "selected",
		gui.model.values.get("proxy", {}).get("selected", ""))
	for k in gp:
		if k == "language" or k == "screenResolutions":
			continue
		c.set_value("prefs", k, gp[k])
	c.save(settings_path)
