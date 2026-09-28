extends RefCounted

## Jar (zip) access via Godot's ZIPReader. The client treats its contents/*.jar
## as zip archives; so do we.

## data-dist root: repo-relative in dev (godot/ is a repo subdir).
const DATA_DIST := "res://../server/data-dist"


static func open(path: String) -> ZIPReader:
	var z := ZIPReader.new()
	if z.open(ProjectSettings.globalize_path(path)) != OK:
		return null
	return z


## Reads entry `name` from jar `jar_path`, or empty on miss.
static func read_entry(jar_path: String, entry_name: String) -> PackedByteArray:
	var z := open(jar_path)
	if z == null:
		return PackedByteArray()
	if not z.file_exists(entry_name):
		z.close()
		return PackedByteArray()
	var data := z.read_file(entry_name)
	z.close()
	return data


## Lists entry names (excluding META-INF/dirs).
static func list(jar_path: String) -> Array:
	var z := open(jar_path)
	if z == null:
		return []
	var out: Array = []
	for f in z.get_files():
		if not f.begins_with("META-INF"):
			out.append(f)
	z.close()
	return out


static func fight_jar(map_id: int) -> String:
	return "%s/maps/fight/%d.jar" % [DATA_DIST, map_id]


static func tplg_jar(world_id: int) -> String:
	return "%s/maps/tplg/%d.jar" % [DATA_DIST, world_id]
