extends VBoxContainer

## Gambit rule editor for one fighter (S13, async PvP phase 4): an ordered
## list of "IF condition THEN action" rows, evaluated top-down by the server
## on the ghost's turn (server/internal/game/gambit*.go). The vocabulary is the
## engine's closed v1 set — the same kinds, value ranges and cast targets its
## strict parser accepts — so whatever this saves, the server takes.
##
## `rules` is the caller's Array, edited in place (a lobby panel rebuilds its
## body on every model change, so the draft must outlive this node). Each rule
## is the wire shape: {"if": {"kind", "value"?}, "do": {"kind", "spell"?, "target"?}}.

signal changed

const Spells := preload("res://src/gamedata/spells.gd")

## The engine's caps (gambit.go): 32 rules; the editor stops at 8, which is a
## page and plenty for a v1 strategy.
const MAX_RULES := 8

## condition kind → [value min, value max, default] ([] = takes no value)
const CONDITIONS := {
	"always": [],
	"self_hp_pct_below": [1, 100, 30],
	"enemy_hp_pct_below": [1, 100, 30],
	"ally_hp_pct_below": [1, 100, 40],
	"nearest_enemy_distance_le": [0, 64, 1],
	"turn_ge": [1, 1000, 3],
	"ally_count_le": [0, 16, 1],
}
const ACTIONS := ["cast", "close_combat", "move_toward", "move_away", "pass"]
const TARGETS := ["nearest_enemy", "weakest_enemy", "weakest_ally", "self"]

var rules: Array = []
var spells: Array = []        # the fighter's spell ids, for "cast"


func _init(rule_list: Array, spell_ids: Array) -> void:
	rules = rule_list
	spells = spell_ids
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	_rebuild()


## The rule set as the server stores it, or {} when there are no rules (the
## fighter then plays the archetype AI).
static func ruleset(list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	return {"version": 1, "rules": list.duplicate(true)}


static func new_rule() -> Dictionary:
	return {"if": {"kind": "always"}, "do": {"kind": "close_combat"}}


func _rebuild() -> void:
	for c in get_children():
		# out of the tree now: a row still pending deletion would make the new
		# one's name collide (and get renamed)
		remove_child(c)
		c.queue_free()
	for i in rules.size():
		add_child(_row(i))
	var bottom := HBoxContainer.new()
	var add := Button.new()
	add.name = "AddRule"
	add.text = I18n.t("gambit.add")
	add.disabled = rules.size() >= MAX_RULES
	add.pressed.connect(func():
		rules.append(new_rule())
		_changed())
	bottom.add_child(add)
	var hint := Label.new()
	hint.text = I18n.t("gambit.fallback") if not rules.is_empty() else I18n.t("gambit.none")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 13)
	bottom.add_child(hint)
	add_child(bottom)


func _changed() -> void:
	_rebuild()
	changed.emit()


func _row(i: int) -> Control:
	var rule: Dictionary = rules[i]
	var cond: Dictionary = rule["if"]
	var act: Dictionary = rule["do"]
	var row := HBoxContainer.new()
	row.name = "Rule%d" % i
	row.add_theme_constant_override("separation", 6)
	var num := Label.new()
	num.text = "%d. %s" % [i + 1, I18n.t("gambit.if")]
	row.add_child(num)
	# condition + its value
	var ckeys: Array = CONDITIONS.keys()
	var cpick := _pick(row, "Cond", ckeys.map(func(k): return I18n.t("gambit.cond." + k)),
		ckeys.find(str(cond.kind)))
	cpick.item_selected.connect(func(idx):
		var k: String = ckeys[idx]
		var spec: Array = CONDITIONS[k]
		rule["if"] = {"kind": k} if spec.is_empty() else {"kind": k, "value": spec[2]}
		_changed())
	var spec: Array = CONDITIONS.get(str(cond.kind), [])
	if not spec.is_empty():
		var v := SpinBox.new()
		v.name = "Value"
		v.min_value = spec[0]
		v.max_value = spec[1]
		v.value = int(cond.get("value", spec[2]))
		v.custom_minimum_size.x = 76
		v.value_changed.connect(func(x):
			cond["value"] = int(x)
			changed.emit())
		row.add_child(v)
	var then := Label.new()
	then.text = "→"
	row.add_child(then)
	# action, and for a cast its spell and target — no "cast" for a fighter
	# with no spell: the server would refuse a cast rule without one
	var acts: Array = ACTIONS if not spells.is_empty() else ACTIONS.slice(1)
	var apick := _pick(row, "Act", acts.map(func(k): return I18n.t("gambit.act." + k)),
		acts.find(str(act.kind)))
	apick.item_selected.connect(func(idx):
		var k: String = acts[idx]
		if k == "cast":
			rule["do"] = {"kind": k, "spell": int(spells[0]) if not spells.is_empty() else 0,
				"target": "nearest_enemy"}
		else:
			rule["do"] = {"kind": k}
		_changed())
	if str(act.kind) == "cast":
		var names: Array = spells.map(func(s): return Spells.name_of(int(s)))
		var spick := _pick(row, "Spell", names, spells.find(int(act.get("spell", 0))))
		spick.disabled = spells.is_empty()
		spick.item_selected.connect(func(idx):
			act["spell"] = int(spells[idx])
			changed.emit())
		var tpick := _pick(row, "Target", TARGETS.map(func(k): return I18n.t("gambit.target." + k)),
			TARGETS.find(str(act.get("target", "nearest_enemy"))))
		tpick.item_selected.connect(func(idx):
			act["target"] = TARGETS[idx]
			changed.emit())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_small(row, "Up", "▲", i > 0, func():
		rules.insert(i - 1, rules.pop_at(i))
		_changed())
	_small(row, "Down", "▼", i < rules.size() - 1, func():
		rules.insert(i + 1, rules.pop_at(i))
		_changed())
	_small(row, "Remove", "✕", true, func():
		rules.remove_at(i)
		_changed())
	return row


func _pick(parent: Node, id: String, labels: Array, index: int) -> OptionButton:
	var o := OptionButton.new()
	o.name = id
	for l in labels:
		o.add_item(str(l))
	o.select(index if index >= 0 and index < labels.size() else 0)
	parent.add_child(o)
	return o


func _small(parent: Node, id: String, text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.name = id
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(34, 34)
	b.pressed.connect(cb)
	parent.add_child(b)
