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

static var _names := {}       # nameId int -> String (content.29: names + texts)
static var _chal_names := {}  # challenge id int -> String (content.30)
static var _groups := {}      # groupId int -> {text, replies:[…]}
static var _modes := {}       # challenge id int -> i16 mode
static var _ach := {}         # achievement id int -> {stats, cards, prev, super, cat, sub, pts, hid}
static var _ach_names := {}   # achievement id int -> String (content.37)
static var _ach_descs := {}   # achievement id int -> String (content.49)
static var _crit_names := {}  # criterion id int -> String (content.48)
static var _summons := {}     # summon template id int -> {hp, ap, mp, look}
static var _summon_names := {} # summon id int -> String (content.10)
static var _event_names := {}  # event card id int -> String (content.8)
static var _loaded := false


## JSON null-safe casts — the exporter serializes empty Go maps/slices as
## null, and GDScript `or` returns a bool (not the operand), so these are
## the safe way to iterate optional maps/lists.
static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _arr(v: Variant) -> Array:
	return v if v is Array else []


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return
	for nid in _dict(data.get("names")):
		_names[int(nid)] = data.names[nid]
	for cid in _dict(data.get("challengeNames")):
		_chal_names[int(cid)] = data.challengeNames[cid]
	for gid in _dict(data.get("groups")):
		_groups[int(gid)] = data.groups[gid]
	for cid in _dict(data.get("challengeModes")):
		_modes[int(cid)] = int(data.challengeModes[cid])
	for aid in _dict(data.get("achievements")):
		_ach[int(aid)] = data.achievements[aid]
	for aid in _dict(data.get("achievementNames")):
		_ach_names[int(aid)] = data.achievementNames[aid]
	for aid in _dict(data.get("achievementDescs")):
		_ach_descs[int(aid)] = data.achievementDescs[aid]
	for cid in _dict(data.get("criterionNames")):
		_crit_names[int(cid)] = data.criterionNames[cid]
	for sid in _dict(data.get("summons")):
		_summons[int(sid)] = data.summons[sid]
	for sid in _dict(data.get("summonNames")):
		_summon_names[int(sid)] = data.summonNames[sid]
	for eid in _dict(data.get("eventNames")):
		_event_names[int(eid)] = data.eventNames[eid]


## content.29 text — used for NPC names AND the demon/Challenge speech bodies.
static func npc_name(id: int) -> String:
	_ensure()
	return str(_names.get(id, ""))


## content.30 challenge display name (the défi picker rows).
static func challenge_name(id: int) -> String:
	_ensure()
	return str(_chal_names.get(id, "Challenge %d" % id))


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


## Summon template (type-300 jz_2 -> aJt): {hp, ap, mp, look} or {} when the
## id is unknown. A summon running-effect (action 67/75/97) carries only the
## template id — the client builds the fighter's stat sheet locally.
static func summon(id: int) -> Dictionary:
	_ensure()
	var s: Variant = _summons.get(id)
	return s if s != null else {}


## Summon display name (content.10 — aJt.getName). Empty for unknown ids.
static func summon_name(id: int) -> String:
	_ensure()
	return str(_summon_names.get(id, ""))


## Per-round event-card title (content.8 — tO). The 8100 tail carries the
## drawn id; 0 means no card this round. Empty for unknown ids.
static func event_name(id: int) -> String:
	_ensure()
	return str(_event_names.get(id, ""))


## Client `aau_1.a` / `sj_1.c`: an achievement is complete when EVERY stat
## condition meets its threshold AND every required card is in the tome.
## `criteria` is State.criteria {statId: value}, `inventory` State.inventory
## {cardId: qty}. Unknown ids read as not-done (the client returns null the
## same way — avq_0.ce(absent) never satisfies).
static func achievement_done(id: int, criteria: Dictionary,
		inventory: Dictionary) -> bool:
	_ensure()
	var a: Variant = _ach.get(id)
	if a == null:
		return false
	for sid in _dict(a.get("stats")):
		if int(criteria.get(int(sid), 0)) < int(a.stats[sid]):
			return false
	for cid in _arr(a.get("cards")):
		if int(inventory.get(int(cid), 0)) <= 0:
			return false
	return true


## Achievement display name (content.37) / description (content.49) /
## criterion label (content.48) — the aea_1 "name"/"description" fields and
## the ako condition row label.
static func achievement_name(id: int) -> String:
	_ensure()
	return str(_ach_names.get(id, "Achievement %d" % id))


static func achievement_desc(id: int) -> String:
	_ensure()
	return str(_ach_descs.get(id, ""))


static func criterion_name(id: int) -> String:
	_ensure()
	return str(_crit_names.get(id, "criterion %d" % id))


## The achievementsList filter (qy_2): drop hidden rows, drop a row whose
## SUPERSEDING achievement is already done (a finished upper tier hides the
## chain below it), and drop a row whose PREVIOUS chain link isn't done yet.
## Retail then sorts completed first — we keep that ordering.
static func achievement_rows(criteria: Dictionary,
		inventory: Dictionary) -> Array:
	_ensure()
	var done_first := []
	var pending := []
	for aid in _ach:
		var a: Dictionary = _ach[aid]
		if a.get("hid", false):
			continue
		var sup := int(a.get("super", 0))
		if sup != 0 and achievement_done(sup, criteria, inventory):
			continue
		var prev := int(a.get("prev", 0))
		if prev != 0 and not achievement_done(prev, criteria, inventory):
			continue
		var row := {"id": int(aid),
			"done": achievement_done(int(aid), criteria, inventory)}
		if row.done:
			done_first.append(row)
		else:
			pending.append(row)
	var by_id := func(x: Dictionary, y: Dictionary): return int(x.id) < int(y.id)
	done_first.sort_custom(by_id)
	pending.sort_custom(by_id)
	return done_first + pending


## Retail "completion" field (aea_1.aVf): mean of each condition's progress,
## stat conditions as min(cur*100/thr, 100) and card conditions as 0/100.
static func achievement_progress(id: int, criteria: Dictionary,
		inventory: Dictionary) -> int:
	_ensure()
	var a: Variant = _ach.get(id)
	if a == null:
		return 0
	var n := 0
	var sum := 0
	for sid in _dict(a.get("stats")):
		n += 1
		var thr := int(a.stats[sid])
		if thr > 0:
			sum += mini(int(criteria.get(int(sid), 0)) * 100 / thr, 100)
	for cid in _arr(a.get("cards")):
		n += 1
		if int(inventory.get(int(cid), 0)) > 0:
			sum += 100
	return sum / n if n > 0 else 0


## Achievement record access for the pane's detail line — conditions with
## display names resolved, plus points/category.
static func achievement_info(id: int) -> Dictionary:
	_ensure()
	var a: Variant = _ach.get(id)
	if a == null:
		return {}
	var conds := []
	for sid in _dict(a.get("stats")):
		conds.append({"kind": "stat", "id": int(sid),
			"thr": int(a.stats[sid])})
	for cid in _arr(a.get("cards")):
		conds.append({"kind": "card", "id": int(cid), "thr": 1})
	return {"id": id, "pts": int(a.get("pts", 0)),
		"cat": int(a.get("cat", 0)), "sub": int(a.get("sub", 0)),
		"conds": conds}
