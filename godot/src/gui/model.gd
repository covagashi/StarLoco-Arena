class_name GuiModel
extends RefCounted
## Property store for XULOR2 <property attribute="..." name="..." field="...">
## bindings. Names are dotted paths ("fight.timeline.currentFighter");
## `field` selects a sub-key of the bound object. Widgets watch names and
## get refreshed when values change.

signal changed(name: String, field: String, value)

var values := {}
var _watchers := {}  # "name|field" or "name" -> Array[{w, bind}]


func _walk(path: String, create := false):
	var parts := path.split(".")
	var d = values
	for i in parts.size() - 1:
		if not (d is Dictionary):
			return null
		if not d.has(parts[i]):
			if create:
				d[parts[i]] = {}
			else:
				return null
		d = d[parts[i]]
	return {"parent": d, "key": parts[-1]}


func get_value(name: String, field: String = ""):
	var w = _walk(name)
	if w == null:
		return null
	var v = w["parent"].get(w["key"])
	if field != "" and v is Dictionary:
		return v.get(field)
	return v


func set_value(name: String, value, field: String = "") -> void:
	var w = _walk(name, true)
	if w == null:
		return
	if field != "":
		if not (w["parent"].get(w["key"]) is Dictionary):
			w["parent"][w["key"]] = {}
		w["parent"][w["key"]][field] = value
	else:
		w["parent"][w["key"]] = value
	changed.emit(name, field, value)
	for e in _watchers.get(_wkey(name, field), []):
		if is_instance_valid(e["w"]):
			e["w"].apply_model(get_value(name, field), e["bind"])
	for e in _watchers.get(_wkey(name, ""), []):
		if is_instance_valid(e["w"]):
			e["w"].apply_model(get_value(name), e["bind"])


func watch(w: GWidget, name: String, field: String = "", bind: Dictionary = {}) -> void:
	var k := _wkey(name, field)
	if not _watchers.has(k):
		_watchers[k] = []
	_watchers[k].append({"w": w, "bind": bind})


func _wkey(name: String, field: String) -> String:
	return name + "|" + field if field != "" else name
