extends RefCounted

## Interactive-element tables exported by server/cmd/dumpelements into
## assets/gamedata/elements.json — {"<worldId>": [{id,type,x,y,z,dir,flags,desc}]}.
## The wire payload (opcode 200) carries position again; this table supplies
## the element KIND (type) and descriptor, which never travel on the wire.

const PATH := "res://assets/gamedata/elements.json"

## env type (asi factory) -> display label. Same numbering as server
## internal/gamedata/envmaps.go EnvType* constants.
const KIND_NAMES := {
	1: "Card Master", 2: "Mailbox", 3: "Challenge", 4: "Zaap",
	5: "Breed Master", 6: "Demon", 7: "Demon challenge", 8: "Trigger",
	9: "Demon", 10: "Graveyard", 11: "Demon totem", 12: "Fireworks",
	13: "Tournament totem", 14: "Fusion altar", 15: "NPC",
}

static var _by_world := {}    # world int -> {instanceId int -> Dictionary}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PATH))
	if data == null:
		return
	for w in data:
		var by_id := {}
		for e in data[w]:
			by_id[int(e.id)] = e
		_by_world[int(w)] = by_id


## {instanceId: {id,type,x,y,z,desc}} for one world (empty if world unknown).
static func for_world(world_id: int) -> Dictionary:
	_ensure()
	return _by_world.get(world_id, {})


static func kind_of(world_id: int, instance_id: int) -> int:
	var e: Variant = for_world(world_id).get(instance_id)
	return int(e.type) if e != null else -1


static func kind_name(kind: int) -> String:
	return KIND_NAMES.get(kind, "Element %d" % kind)
