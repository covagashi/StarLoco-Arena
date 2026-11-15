class_name GuiLib
extends RefCounted
## Facade for the XULOR2 runtime: theme + i18n + model + dialog loading.
## `dofusarena:*` widget events are forwarded to `event_sink` callable
## (main.gd / session code registers it).

## Logical prefix — AssetPaths.resolve() turns it into a real path, so the
## retail XML tree can ship beside the executable instead of in the .pck.
const GUI_ROOT := "gui/"

## The theme and the loader read the retail XML tree, so they are built on
## the first XML dialog only (S43): a session that opens nothing but native
## panels never touches gui/. null until then.
var theme: GuiTheme
var model := GuiModel.new()
var i18n := {}
var loader: GuiLoader
var event_sink := Callable()   # func(method: String, args: Array, widget: GWidget)


func _init(lang := "es") -> void:
	load_i18n(lang)


func _ensure_loader() -> void:
	if loader != null:
		return
	theme = GuiTheme.new()
	loader = GuiLoader.new(theme, i18n, model)
	loader.dialog_cb = _dispatch


## S41: no retail text any more. Every screen is native and reads our own
## tables (I18n, OwnText); the XML layer only routes events, so its %key%
## lookups get an empty table and show nothing retail. `lang` is kept for
## the callers.
func load_i18n(_lang: String) -> void:
	i18n = {}
	if loader != null:
		loader.i18n = i18n


## Load a dialog XML -> GWidget tree. `model_values` seeds the property store.
func open_dialog(name: String, model_values := {}) -> GWidget:
	for k in model_values:
		model.values[k] = model_values[k]
	_ensure_loader()
	var rel := GUI_ROOT + "xml/dialogs/%s.xml" % name
	if not AssetPaths.exists(rel):
		rel = GUI_ROOT + "xml/%s.xml" % name
	# The loader resolves <include>/<template> siblings against this path's
	# base dir, so hand it the RESOLVED one — the whole tree then comes out
	# of the root that actually holds the dialog.
	var root := loader.load_file(AssetPaths.resolve(rel))
	return root


func _dispatch(action: String, w: GWidget, _loader: GuiLoader) -> void:
	# "dofusarena:logon(loginForm)" / "dofusarena.fight:fighterEndsTurn(fighter)"
	# onClick="a;b;c" fires each action in sequence
	for act in action.split(";", false):
		_dispatch_one(act.strip_edges(), w)


func _dispatch_one(action: String, w: GWidget) -> void:
	if action == "unloadDialog" and event_sink.is_valid():
		event_sink.call("", action, [], w)
		return
	var m := RegEx.new()
	m.compile("^([\\w.]+):(\\w+)(?:\\((.*)\\))?$")
	var r := m.search(action)
	if r == null:
		return
	var ns := r.get_string(1)
	var method := r.get_string(2)
	var raw := r.get_string(3)
	var args: Array = []
	if raw != null and raw != "":
		for part in raw.split(","):
			args.append(_resolve_arg(part.strip_edges(), w))
	if event_sink.is_valid():
		event_sink.call(ns, method, args, w)


func _resolve_arg(arg: String, src: GWidget) -> Variant:
	if arg == "":
		return arg
	if arg.begins_with("'") or arg.begins_with('"'):
		return arg.trim_prefix("'").trim_prefix('"').trim_suffix("'").trim_suffix('"')
	if arg.is_valid_int() or arg.is_valid_float():
		return arg.to_float() if arg.contains(".") else arg.to_int()
	if loader != null and loader.by_id.has(arg):
		return loader.by_id[arg]
	# <data id> aliases — nearest ancestor binding first (list rows)
	var n: Node = src
	while n != null:
		if n is GWidget and n.data_id == arg:
			return n.data_value
		n = n.get_parent()
	if loader != null and loader.data_ids.has(arg):
		return loader.data_ids[arg].data_value
	return arg


## Dump the widget tree for smoke tests.
static func dump(w: GWidget, indent := 0) -> String:
	var s := "  ".repeat(indent) + "%s(%s) id=%s pos=%s size=%s text=%s\n" % [
		w.kind, w.type_style, w.widget_id, w.position, w.size, w.text.left(24)]
	for ch in w.get_children():
		if ch is GWidget:
			s += dump(ch, indent + 1)
	return s
