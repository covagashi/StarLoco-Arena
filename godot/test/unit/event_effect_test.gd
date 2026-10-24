extends RefCounted
## S24: an event card's effect on one line — no "Efecto:" lead, no
## "Duración" line, no "(1 turno)" tags (every round card lasts its round).

const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const State := preload("res://src/state.gd")


func run(t) -> void:
	t.suite("event_effect")
	if NpcDialogs.event_name(19) == "" or NpcDialogs.event_desc(19) == "":
		t.ok(true, "no npcdialogs.json in this checkout: skipped")
		return
	var before := State.locale
	State.locale = "es"
	t.eq(NpcDialogs.event_effect(19), "+15% de daño", "Ira Guerrera")
	t.eq(NpcDialogs.event_effect(12), "+1 PA", "Es la hora de la acción")
	var sram := NpcDialogs.event_effect(2)
	t.ok(sram.begins_with("+10% de daño") and "(Srams)" in sram and not "Duraci" in sram,
		"Dios Sram keeps its class, drops its Duración line: '%s'" % sram)
	t.ok(not "Dua" in NpcDialogs.event_effect(3), "the data's 'Duación' typo is dropped too")
	State.locale = before
