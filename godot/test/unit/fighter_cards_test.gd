extends RefCounted
## S22: fighter equipment is its own table. Card 1 is the sword "Raciela"
## (content.1, a weapon: slot type 1); the coach card with the same id is the
## "Capa Arlan Txin" cape (content.23). The loadout editor read the coach one.

const FighterCards := preload("res://src/gamedata/fightercards.gd")
const Cards := preload("res://src/gamedata/cards.gd")
const State := preload("res://src/state.gd")


func run(t) -> void:
	t.suite("fighter_cards")
	if FighterCards.ability(1).is_empty() or not FighterCards.ability(1).has("type"):
		t.ok(true, "no fightercards.json with slot types in this checkout: skipped")
		return
	var before := State.locale
	State.locale = "es"
	t.eq(FighterCards.slot_type(1), 1, "card 1 is a weapon")
	t.eq(FighterCards.label(1), "Raciela", "its fighter name")
	t.ok(FighterCards.label(1) != Cards.name_of(1), "not the coach card's name")
	t.ok(FighterCards.value_of(1) > 0, "it costs budget")
	var slots := {}
	for id in FighterCards.all_ids():
		slots[FighterCards.slot_type(int(id))] = true
	t.eq(slots.keys().filter(func(k): return k >= 1 and k <= 5).size(), 5, "all five slot types present")
	State.locale = before
