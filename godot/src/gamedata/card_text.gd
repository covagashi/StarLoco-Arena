extends RefCounted
## What a coach card or a card set does, in our own words (S41).
##
## The retail descriptions never reached the native UI (the inventory showed
## no effect at all), and after S40's caps they would have lied anyway. These
## lines are built from the effects themselves — cards.json "fx" and
## cardsetfx.json, both written by server/cmd/dumpcards from server/content/
## — through the cardfx.* keys of assets/i18n/ui_<lang>.json, so a card says
## exactly what the server applies:
##   - worn (coach equipment): the post-fight META bonuses, which since S41
##     count the card's own effects as well as its set's
##     (server coachBonusFor);
##   - used (consumables, HasUsableAction): the same action ids mean
##     something else there — 11 heals light wounds, 15 applies a condition
##     (server useConsumableOnFighter) — so they have their own cardfx.use.*.
## An action with no text is left out rather than shown raw.

const Cards := preload("res://src/gamedata/cards.gd")
const GameText := preload("res://src/gamedata/game_text.gd")

const SETS_PATH := "gamedata/cardsetfx.json"
const CONDITION := 40   # content.40: condition names (retail, until S41 replaces them)
const RESURRECT := 13
const APPLY_CONDITION := 15
## Worn effects that only touch fighters after a Historia fight (S21: Elite
## fighters are all at one level); reputation (14) and drops (18–21) count
## in every fight.
const FIGHTER_ONLY := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 16, 17]

static var _sets := {}
static var _sets_loaded := false


## "+4" / "-2" / "0".
static func signed(n: int) -> String:
	return "+%d" % n if n > 0 else str(n)


## One effect row ([action, params...]) as a line, "" when it has no text.
## `used`: the card is a consumable, whose action ids read differently.
static func effect_line(row: Array, used: bool) -> String:
	if row.is_empty():
		return ""
	var a := int(row[0])
	var p0 := int(row[1]) if row.size() > 1 else 0
	var p1 := int(row[2]) if row.size() > 2 else 0
	if used and a == APPLY_CONDITION:
		var cond := GameText.content(CONDITION, p0, "#%d" % p0)
		if p1 > 0:
			return I18n.t("cardfx.use.15", {"cond": cond, "n": p1})
		return I18n.t("cardfx.use.15_always", {"cond": cond})
	var key := ("cardfx.use.%d" if used else "cardfx.%d") % a
	if not I18n.has(key):
		return ""
	return I18n.t(key, {"n": signed(p0), "abs": absi(p0)})


## The lines of a list of effect rows, in order, without the empty ones.
static func effect_lines(rows: Array, used: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for row in rows:
		var l := effect_line(row, used)
		if l != "":
			out.append(l)
	return out


## Whether the card is used (a consumable) rather than worn.
static func is_used(id: int) -> bool:
	return Cards.family_of(id) == "consumable"


## What the card does, one line per effect, then when it applies.
static func card_lines(id: int) -> PackedStringArray:
	var m := Cards.meta(id)
	var rows: Array = m.get("fx", [])
	var used := is_used(id)
	var out := effect_lines(rows, used)
	if out.is_empty():
		return out
	if not used:
		var fighters := rows.any(func(r): return int(r[0]) in FIGHTER_ONLY)
		out.append(I18n.t("cardfx.when_worn_story" if fighters else "cardfx.when_worn"))
		var lvl := int(m.get("reqLevel", 0))
		if lvl > 0:
			out.append(I18n.t("cardfx.req_level", {"n": lvl}))
	return out


## A set's bonuses: [{need: cards worn, text: line}], by need.
static func set_bonuses(set_id: int) -> Array:
	if not _sets_loaded:
		_sets_loaded = true
		var data: Variant = AssetPaths.read_json(SETS_PATH)
		if data is Dictionary:
			for k in data:
				_sets[int(k)] = data[k]
	var out: Array = []
	for row in _sets.get(set_id, []):
		var l := effect_line(row.slice(1), false)
		if l != "":
			out.append({"need": int(row[0]), "text": l})
	out.sort_custom(func(a, b): return a.need < b.need)
	return out


## A set's bonuses as lines: "With 5 worn: +1 % XP for your fighters".
static func set_lines(set_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	for b in set_bonuses(set_id):
		out.append(I18n.t("cardfx.set_need", {"n": b.need, "text": b.text}))
	return out
