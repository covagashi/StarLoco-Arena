extends RefCounted

## NPC dialog table: record 1500 (client `atF` reply rows) exported by
## server/cmd/dumpnpcdialogs and resolved against i18n tables 29/59/60 by
## the old importer's npc_dialogs.py into assets/gamedata/npcdialogs.json:
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
##
## Texts are ours since S41 (OwnText, assets/i18n/content_<lang>.json):
## npc.<nameId>, chal.<id>, dlg.<groupId> and dlgr.<groupId>.<reply>,
## ach.<id>, achd.<id>, crit.<id>, summon.<id>, event.<id>, eventd.<id> and
## eventl.<id>. This table only brings the behaviour (next/act/params, modes,
## achievements, summons); its retail texts are no longer read.

const OwnText := preload("res://src/gamedata/own_text.gd")
const PATH := "gamedata/npcdialogs.json"

static var _groups := {}      # groupId int -> {text, replies:[…]}
static var _modes := {}       # challenge id int -> i16 mode
static var _ach := {}         # achievement id int -> {stats, cards, prev, super, cat, sub, pts, hid}
static var _summons := {}     # summon template id int -> {hp, ap, mp, look}
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
	var data: Variant = AssetPaths.read_json(PATH)
	if not data is Dictionary:
		return
	for gid in _dict(data.get("groups")):
		_groups[int(gid)] = data.groups[gid]
	for cid in _dict(data.get("challengeModes")):
		_modes[int(cid)] = int(data.challengeModes[cid])
	for aid in _dict(data.get("achievements")):
		_ach[int(aid)] = data.achievements[aid]
	for sid in _dict(data.get("summons")):
		_summons[int(sid)] = data.summons[sid]


## npc.<id>: NPC names AND the demon/Challenge speech bodies.
static func npc_name(id: int) -> String:
	return OwnText.get_text("npc", id, "")


## content.30 challenge display name (the défi picker rows).
static func challenge_name(id: int) -> String:
	return OwnText.get_text("chal", id, "#%d" % id)


## The dialog node: {"text", "replies":[{label, next, act?, params?}]}, the
## data's behaviour with our texts (dlg.<id>, dlgr.<id>.<reply>).
static func group(id: int) -> Dictionary:
	_ensure()
	var g: Variant = _groups.get(id)
	if not g is Dictionary:
		return {}
	var out: Dictionary = (g as Dictionary).duplicate(true)
	out["text"] = OwnText.get_text("dlg", id, "")
	var replies: Array = out.get("replies", [])
	for i in replies.size():
		replies[i]["label"] = OwnText.get_key("dlgr.%d.%d" % [id, i], "…")
	return out


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
	return OwnText.get_text("summon", id, "")


## Per-round event-card title (content.8 — tO). The 8100 tail carries the
## drawn id; 0 means no card this round. Empty for unknown ids.
static func event_name(id: int) -> String:
	return OwnText.get_text("event", id, "")


## The event card's hover text: what it does and for how long. The exporter
## writes it the retail's way (tO.getDescription -> asf_0): the effect list
## from the event's effects for 36 of the 51, the hand-written content.27 for
## the rest. A table exported before S07 has none, so the card's flavour text
## (content.9) stands in; "" before that.
static func event_desc(id: int) -> String:
	var d := OwnText.get_text("eventd", id, "")
	return d if d != "" else OwnText.get_text("eventl", id, "")


## What an event card does, on one line (S24): the description without its
## "Efecto(s):" lead, its "Duración: 1 turno" line and the "(1 turno)" tags —
## every round card lasts its round, the banner says so once.
static func event_effect(id: int) -> String:
	var d := event_desc(id).replace("\\n", "\n")
	var parts := PackedStringArray()
	for line in d.split("\n"):
		var l := line.strip_edges()
		var low := l.to_lower()
		if l == "" or low.begins_with("duraci") or low.begins_with("duaci") \
				or low.begins_with("duration") or low.begins_with("durée"):
			continue
		for lead in ["Efectos:", "Efecto:", "Effects:", "Effect:", "Effets :", "Effet :", "Effets:", "Effet:"]:
			if l.begins_with(lead):
				l = l.substr(lead.length()).strip_edges()
		parts.append(l)
	var out := ", ".join(parts)
	for tag in [" (1 turno)", " (1 turn)", " (1 tour)"]:
		out = out.replace(tag, "")
	return out.trim_suffix(".")


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


## The statistic thresholds an achievement needs ({statId: threshold}).
static func achievement_stats(id: int) -> Dictionary:
	_ensure()
	var a: Variant = _ach.get(id)
	if a == null:
		return {}
	var out := {}
	for sid in _dict(a.get("stats")):
		out[int(sid)] = int(a.stats[sid])
	return out


## Achievement display name (content.37) / description (content.49) /
## criterion label (content.48) — the aea_1 "name"/"description" fields and
## the ako condition row label.
static func achievement_name(id: int) -> String:
	return OwnText.get_text("ach", id, "#%d" % id)


static func achievement_desc(id: int) -> String:
	return OwnText.get_text("achd", id, "")


static func criterion_name(id: int) -> String:
	return OwnText.get_text("crit", id, "#%d" % id)


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
