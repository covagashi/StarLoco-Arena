class_name GuiLayer
extends CanvasLayer
## Hosts the native lobby panels (src/ui/*_panel.gd) on a CanvasLayer and
## routes their actions to a handler map. Every dialog name opens the
## native panel its factory builds; the retail XML engine is gone (S43).

signal dialog_opened(name: String)

## What a native panel acted on, handed to every handler: the row's item
## and its index (-1 when the action is not about a row).
class Ctx extends RefCounted:
	var item_value: Variant = null
	var selected_index := -1


var model := GuiModel.new()  # the property store the native panels read
var handlers := {}          # method -> Callable(args: Array, ctx: Ctx)
var dialogs := {}           # canonical name -> native Control
var native_factories := {}  # canonical name -> Callable returning Control
var settings_path := "user://gui_settings.cfg"
## S47 W7: the browser's Back closes the window on top. Every window opened
## adds a history entry; Back (popstate) closes the top one; a window closed
## from the game takes its own entry back so the two never drift. `history`
## is the browser's (BrowserHistory on the web, null elsewhere; tests put a
## stand-in there).
var history: Object = null
var _entries := 0        # history entries our windows hold
var _skip_pops := 0      # popstates of our own history.back() calls
var _popping := false    # closing because of Back: its entry is gone already

## Logical names the lobby still asks for → the panel that answers them.
const DIALOG_ALIASES := {
	"coachInventoryDialog": "cardBookDialog",
	"fusionLaboratoryDialog": "fusionLabDialog",
	"teamXvsXNameDialog": "team2vs2NameDialog",
}


func _file_for(name: String) -> String:
	var canonical := name.left(1).to_lower() + name.substr(1)
	return DIALOG_ALIASES.get(canonical, canonical)


func _init() -> void:
	layer = 10


func _ready() -> void:
	_load_settings()
	if history == null and OS.has_feature("web"):
		history = BrowserHistory.new(_on_popstate)


func _exit_tree() -> void:
	# off to a fight (a scene change frees the open windows without closing
	# them): hand the browser its entries back, and stop listening
	if history != null:
		if _entries > 0:
			history.go(-_entries)
			_entries = 0
		history.detach()


## Back in the browser: the window on top closes (nothing when none is open:
## the browser then goes where it goes).
func _on_popstate(_args := []) -> void:
	if _skip_pops > 0:
		_skip_pops -= 1
		return
	_entries = maxi(0, _entries - 1)
	if dialogs.is_empty():
		return
	_popping = true
	close(str(dialogs.keys().back()))
	_popping = false
	_mark()


## window.__pippop.gui = the open windows and our entries (tools/web tests).
func _mark() -> void:
	if history != null and history.has_method("mark"):
		history.mark(dialogs.keys(), _entries)


func open(name: String, model_values := {}) -> Control:
	var fname := _file_for(name)
	if is_open(fname):
		return dialogs[fname]
	if not native_factories.has(fname):
		push_warning("GuiLayer: no native panel for %s" % fname)
		return null
	for key in model_values:
		model.set_value(key, model_values[key])
	var root: Control = native_factories[fname].call(fname)
	if root == null:
		return null
	add_child(root)
	dialogs[fname] = root
	root.closed.connect(close.bind(fname))
	if history != null:
		history.push()
		_entries += 1
		_mark()
	dialog_opened.emit(fname)
	return root


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not dialogs.is_empty():
		close(str(dialogs.keys().back()))
		get_viewport().set_input_as_handled()


func close(name: String) -> void:
	var fname := _file_for(name)
	if dialogs.has(fname):
		dialogs[fname].hide()
		dialogs[fname].queue_free()
		dialogs.erase(fname)
		if history != null and not _popping and _entries > 0:
			_entries -= 1
			_skip_pops += 1
			history.back()
			_mark()


func is_open(name: String) -> bool:
	return dialogs.has(_file_for(name))


## openClose<XxxDialog> toggles; close<XxxDialog> always closes.
func toggle(name: String, model_values := {}) -> Control:
	if is_open(name):
		close(name)
		return null
	return open(name, model_values)


func on(method: String, cb: Callable) -> void:
	handlers[method] = cb


## A native panel's action: its handler, else the generic
## openClose<Xxx>Dialog / close<Xxx>Dialog toggles. Preferences are saved
## after every handled action.
func dispatch(method: String, args: Array = [], ctx: Ctx = null) -> void:
	if method == "quit":
		get_tree().quit()
		return
	var h: Callable = handlers.get(method, Callable())
	if h.is_valid():
		h.call(args, ctx)
		_save_settings()
		return
	if method.begins_with("openClose") and method.ends_with("Dialog"):
		toggle(method.trim_prefix("openClose"))
		return
	if method.begins_with("close") and method.ends_with("Dialog"):
		close(method.trim_prefix("close"))


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(settings_path) != OK:
		return
	model.values["account.name"] = c.get_value("account", "name", "")
	model.values["account.remember"] = c.get_value("account", "remember", false)
	if model.values["account.remember"]:
		model.values["account.password"] = c.get_value("account", "password", "")
	var hosts: Array = c.get_value("proxy", "list", ["140.238.172.196:3000", "127.0.0.1:5555"])
	var sel: String = str(c.get_value("proxy", "selected", hosts[0]))
	if sel not in hosts:
		sel = str(hosts[0])
	model.values["proxy"] = {
		"list": hosts.map(func(h): return {"text": h}),
		"selected": sel,
	}
	model.values["gamePreferences"] = {
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


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.load(settings_path)
	var gp: Dictionary = model.values.get("gamePreferences", {})
	c.set_value("gui", "language", gp.get("language", "es"))
	c.set_value("account", "name", model.values.get("account.name", ""))
	var rem: bool = model.values.get("account.remember", false)
	c.set_value("account", "remember", rem)
	c.set_value("account", "password",
		model.values.get("account.password", "") if rem else "")
	c.set_value("proxy", "selected",
		model.values.get("proxy", {}).get("selected", ""))
	for k in gp:
		if k == "language" or k == "screenResolutions":
			continue
		c.set_value("prefs", k, gp[k])
	c.save(settings_path)


## The page's history, through JavaScriptBridge (web only).
class BrowserHistory extends RefCounted:
	var _cb: JavaScriptObject   # kept: the browser calls it on popstate
	var _window: JavaScriptObject

	func _init(on_pop: Callable) -> void:
		_window = JavaScriptBridge.get_interface("window")
		_cb = JavaScriptBridge.create_callback(on_pop)
		_window.addEventListener("popstate", _cb)

	func push() -> void:
		_window.history.pushState(JavaScriptBridge.create_object("Object"), "")

	func back() -> void:
		_window.history.back()

	func go(n: int) -> void:
		_window.history.go(n)

	func detach() -> void:
		_window.removeEventListener("popstate", _cb)

	func mark(open: Array, entries: int) -> void:
		JavaScriptBridge.eval("(window.__pippop = window.__pippop || {}).gui = %s"
			% JSON.stringify({"open": open, "entries": entries}))
