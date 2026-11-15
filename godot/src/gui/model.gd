class_name GuiModel
extends RefCounted
## Property store the native panels read (GuiLayer.model). Names are
## dotted paths ("fight.timeline.currentFighter"); `field` selects a sub-key
## of the stored object. Panels listen to `changed` and refresh.

signal changed(name: String, field: String, value)

var values := {}


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
	for p in _field_parts(name, field):
		if not (v is Dictionary):
			return null
		v = v.get(p)
	return v


## Fields can be property paths that restate the model root or the
## name's last segment — field="guild.name" on name="guild" means guild.name
## flat, and field="teamManagement.teamPreset1vs1List" on
## name="teamManagement.teamManager" means a direct child of teamManager.
## Drop the redundant head and walk the rest.
func _field_parts(name: String, field: String) -> PackedStringArray:
	if field == "":
		return PackedStringArray()
	var parts := field.split(".")
	if parts.size() <= 1:
		return parts
	var segs := name.split(".")
	if parts[0] == segs[-1] or parts[0] == segs[0]:
		return parts.slice(1)
	return parts


func set_value(name: String, value, field: String = "") -> void:
	var w = _walk(name, true)
	if w == null:
		return
	if field != "":
		var d = w["parent"]
		var key: String = w["key"]
		var parts := _field_parts(name, field)
		for i in parts.size() - 1:
			if not (d.get(key) is Dictionary):
				d[key] = {}
			d = d[key]
			key = parts[i]
		if not (d.get(key) is Dictionary):
			d[key] = {}
		d[key][parts[-1]] = value
	else:
		w["parent"][w["key"]] = value
	changed.emit(name, field, value)
