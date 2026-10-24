extends RefCounted
## The tutorial characters carry our own names (npc_rename.gd): whole words
## only, in every language the retail data spells them, longest name first.

const NpcRename := preload("res://src/gamedata/npc_rename.gd")


func run(t) -> void:
	t.suite("npc_rename")
	t.eq(NpcRename.apply("Habla con Baan y con Litio."), "Habla con Nilo y con Lía.", "es names")
	t.eq(NpcRename.apply("Ed Isace and Lithian"), "Elvio and Lía", "en names, two words")
	t.eq(NpcRename.apply("Adamaï parle"), "Aldebrán parle", "fr accent")
	t.eq(NpcRename.apply("un gusano gusta"), "un gusano gusta", "whole words: Gus inside a word stays")
	t.eq(NpcRename.apply("Gus!"), "Fermín!", "Gus alone")
	t.eq(NpcRename.name_for(295, "Baan"), "Nilo", "by name id")
	t.eq(NpcRename.name_for(144, "Demonio III"), "Demonio III", "the demon keeps its title")
