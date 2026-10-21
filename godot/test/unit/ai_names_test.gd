extends RefCounted
## S08: the server's AI opponents in the UI language. The server sends French
## strings (challenge_fights.go); State.index_fighters rewrites only its own
## two coach ids, and a fighter only when the name is its breed's French name.

const AiNames := preload("res://src/gamedata/ai_names.gd")


func run(t) -> void:
	t.suite("ai_names")
	var ai := AiNames.CHALLENGE_COACH
	var fight := {
		"coaches": [{"id": ai, "name": "Maître d'élevage"},
			{"id": 7, "name": "Démon"}],
		"teams": [{"id": 1, "fighters": [
			{"id": 1, "coach": ai, "breed": 8, "name": "Iop"},
			{"id": 2, "coach": ai, "breed": 9, "name": "Crâ"},
			{"id": 3, "coach": 7, "breed": 8, "name": "Iop"},
			{"id": 4, "coach": ai, "breed": 8, "name": "Bob"}]}]}
	AiNames.localize(fight)
	t.eq(fight.coaches[0].name, I18n.t("ai.breed_master"), "breed master in the UI language")
	t.eq(fight.coaches[1].name, "Démon", "a PLAYER called Démon is left alone")
	var f: Array = fight.teams[0].fighters
	t.eq(f[0].name, I18n.t("breed.8"), "AI Iop -> breed.8")
	t.eq(f[1].name, I18n.t("breed.9"), "AI Crâ -> breed.9")
	t.eq(f[2].name, "Iop", "a player's fighter named Iop is left alone")
	t.eq(f[3].name, "Bob", "an AI fighter with another name is left alone")
	# a demon whose name is in the retail tables; falls back to the French
	# string when the GUI extraction is absent
	var dn := AiNames.coach_name(ai, "Démon de la 58ème minute")
	t.ok(dn != "", "demon name resolves (%s)" % dn)
	t.eq(AiNames.coach_name(AiNames.SPARRING_COACH, "Sparring"), I18n.t("ai.sparring"),
		"sparring opponent")
