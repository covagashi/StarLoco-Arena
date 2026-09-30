extends RefCounted

## NPC dialog table: record 1500 (client `atF` reply rows) exported by
## server/cmd/dumpnpcdialogs and resolved against i18n tables 29/59/60 by
## tools/asset-import/npc_dialogs.py into assets/gamedata/npcdialogs.json:
##
##   {"names":  {"<nameId>": "Baan"},
##    "groups": {"<groupId>": {"text": "…",   # content.59 speech
##                            "replies": [{"label", "next", "act", "params"}]}},
##    "challengeModes": {"<challengeId>": mode}}
##
## Retail model (ni_0/ao_2): an NPC element's desc is
## "nameId;criterionId;defaultGroup;altGroup;style" — the dialog opens on
## altGroup when criterionId != -1 and its value is > 0, else defaultGroup.
## Clicking a reply runs `act` (1 = 26330 challenge launch
## [challengeId][challengeModes[id]], 2 = 22003 criterion) then navigates to
## `next` — 0 closes the dialog.

const PATH := "res://assets/gamedata/npcdialogs.json"

static var _names := {}       # nameId int -> String
static var _groups := {}      # groupId int -> {text, replies:[…]}
static var _modes := {}       # challenge id int -> i16 mode
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
	for nid in data.get("names", {}):
		_names[int(nid)] = data.names[nid]
	for gid in data.get("groups", {}):
		_groups[int(gid)] = data.groups[gid]
	for cid in data.get("challengeModes", {}):
		_modes[int(cid)] = int(data.challengeModes[cid])


static func npc_name(id: int) -> String:
	_ensure()
	return str(_names.get(id, ""))


## The dialog node: {"text", "replies":[{label, next, act?, params?}]}.
static func group(id: int) -> Dictionary:
	_ensure()
	var g: Variant = _groups.get(id)
	return g if g != null else {}


## The i16 second field of a 26330 NPC-dialog challenge launch —
## afz_0.Qu() (challenge record Fields[1]), NOT the breedmaster's literal 99.
static func challenge_mode(challenge_id: int) -> int:
	_ensure()
	return int(_modes.get(challenge_id, 99))
