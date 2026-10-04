class_name GuiModel
extends RefCounted
## Property store for XULOR2 <property attribute="..." name="..." field="...">
## bindings. A "name" maps to either a scalar or a Dictionary of fields.
## Widgets watch names and get refreshed when values change.

signal changed(name: String, field: String, value)

var values := {}
var _watchers := {}  # "name|field" or "name" -> Array[GWidget]


func get_value(name: String, field: String = ""):
	var v = values.get(name)
	if field != "" and v is Dictionary:
		return v.get(field)
	return v


func set_value(name: String, value, field: String = "") -> void:
	if field != "":
		if not (values.get(name) is Dictionary):
			values[name] = {}
		values[name][field] = value
	else:
		values[name] = value
	changed.emit(name, field, value)
	for w in _watchers.get(_wkey(name, field), []):
		if is_instance_valid(w):
			w.apply_model(get_value(name, field))
	for w in _watchers.get(_wkey(name, ""), []):
		if is_instance_valid(w):
			w.apply_model(values.get(name))


func watch(w: GWidget, name: String, field: String = "") -> void:
	var k := _wkey(name, field)
	if not _watchers.has(k):
		_watchers[k] = []
	_watchers[k].append(w)


func _wkey(name: String, field: String) -> String:
	return name + "|" + field if field != "" else name
