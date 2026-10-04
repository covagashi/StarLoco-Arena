class_name GuiLayer
extends CanvasLayer
## Hosts XULOR2 dialogs on a CanvasLayer and routes dofusarena:* widget
## events to a handler map. One GuiLib per layer (theme + model shared).

signal dialog_opened(name: String)

var gui: GuiLib
var handlers := {}          # method -> Callable(args, widget)
var dialogs := {}           # name -> GWidget root
var settings_path := "user://gui_settings.cfg"


func _init() -> void:
	layer = 10
	gui = GuiLib.new(_saved_lang())
	gui.event_sink = _on_event


func _ready() -> void:
	_load_settings()


func open(name: String, model_values := {}) -> GWidget:
	var root := gui.open_dialog(name, model_values)
	if root == null:
		return null
	root.size = get_viewport().get_visible_rect().size
	add_child(root)
	dialogs[name] = root
	GuiLayouts.apply(root)
	root.resized.connect(func(): GuiLayouts.apply(root))
	get_viewport().size_changed.connect(func(): _relayout(root))
	dialog_opened.emit(name)
	return root


func close(name: String) -> void:
	if dialogs.has(name):
		dialogs[name].queue_free()
		dialogs.erase(name)


func is_open(name: String) -> bool:
	return dialogs.has(name)


## openClose<XxxDialog> toggles; close<XxxDialog> always closes.
func toggle(name: String, model_values := {}) -> GWidget:
	if is_open(name):
		close(name)
		return null
	return open(name, model_values)


func on(method: String, cb: Callable) -> void:
	handlers[method] = cb


func _relayout(root: GWidget) -> void:
	root.size = get_viewport().get_visible_rect().size
	GuiLayouts.apply(root)


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
	c.save(settings_path)
