class_name GuiLib
extends RefCounted
## Facade for the XULOR2 runtime: theme + i18n + model + dialog loading.
## `dofusarena:*` widget events are forwarded to `event_sink` callable
## (main.gd / session code registers it).

const GUI_ROOT := "res://assets/gui/"

var theme: GuiTheme
var model := GuiModel.new()
var i18n := {}
var loader: GuiLoader
var event_sink := Callable()   # func(method: String, args: Array, widget: GWidget)


func _init(lang := "es") -> void:
	theme = GuiTheme.new()
	loader = GuiLoader.new(theme, {}, model)
	loader.dialog_cb = _dispatch
	load_i18n(lang)


func load_i18n(lang: String) -> void:
	var p := GUI_ROOT + "i18n_%s.json" % lang
	if not FileAccess.file_exists(p):
		p = GUI_ROOT + "i18n_en.json"
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		push_error("[guilib] missing " + p)
		return
	i18n = JSON.parse_string(f.get_as_text())
	if i18n == null:
		i18n = {}
	loader.i18n = i18n


## Load a dialog XML -> GWidget tree. `model_values` seeds the property store.
func open_dialog(name: String, model_values := {}) -> GWidget:
	for k in model_values:
		model.values[k] = model_values[k]
	var path := GUI_ROOT + "xml/dialogs/%s.xml" % name
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		path = GUI_ROOT + "xml/%s.xml" % name
	var root := loader.load_file(path)
	return root


func _dispatch(action: String, w: GWidget, _loader: GuiLoader) -> void:
	# "dofusarena:logon(loginForm)" / "xulor:unloadDialog(name)"
	var m := RegEx.new()
	m.compile("^(\\w+):(\\w+)(?:\\((.*)\\))?$")
	var r := m.search(action)
	if r == null:
		return
	var ns := r.get_string(1)
	var method := r.get_string(2)
	var raw := r.get_string(3)
	var args: Array = []
	if raw != null and raw != "":
		for part in raw.split(","):
			var arg := part.strip_edges()
			# literal quoted string -> strip; widget id -> resolve
			if arg.begins_with("'") or arg.begins_with('"'):
				args.append(arg.trim_prefix("'").trim_prefix('"').trim_suffix("'").trim_suffix('"'))
			elif arg.is_valid_int() or arg.is_valid_float():
				args.append(float(arg) if arg.contains(".") else int(arg))
			elif loader.by_id.has(arg):
				args.append(loader.by_id[arg])
			else:
				args.append(arg)
	match ns:
		"dofusarena":
			if event_sink.is_valid():
				event_sink.call(method, args, w)
		"xulor":
			pass  # engine-internal actions (dialog unload etc.) — later
		_:
			if event_sink.is_valid():
				event_sink.call(method, args, w)


## Dump the widget tree for smoke tests.
static func dump(w: GWidget, indent := 0) -> String:
	var s := "  ".repeat(indent) + "%s(%s) id=%s pos=%s size=%s text=%s\n" % [
		w.kind, w.type_style, w.widget_id, w.position, w.size, w.text.left(24)]
	for ch in w.get_children():
		if ch is GWidget:
			s += dump(ch, indent + 1)
	return s
