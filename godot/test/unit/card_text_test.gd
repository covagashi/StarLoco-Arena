extends RefCounted
## S41: card texts are built from the effects, not the retail descriptions.
## CI-safe: it feeds effect rows directly (no assets/content needed) and
## reads only the tracked assets/i18n tables, in Spanish and English.

const CardText := preload("res://src/gamedata/card_text.gd")


func run(t) -> void:
	t.suite("card_text")
	var was := I18n.lang
	I18n.set_locale("es")
	# worn: the capped values read as they are, signed
	t.eq(CardText.effect_line([1, 10], false), "+10 % de XP para tus luchadores", "XP % worn")
	t.eq(CardText.effect_line([7, -2], false), "-2 % de probabilidad de muerte para tus luchadores", "death worn")
	t.eq(CardText.effect_line([11, 6], false), "6 % de probabilidad de librarse de las heridas", "cancel wounds has no sign")
	t.ok(CardText.effect_line([13, 25], false).begins_with("+25 % a tus cartas de resurrección"), "resurrection worn: a bonus, not a sure 100 %")
	# used: the same ids mean something else on a consumable
	t.eq(CardText.effect_line([11, 100], true), "Cura las heridas leves (100 % cada una)", "11 on a consumable heals")
	t.eq(CardText.effect_line([13, 25], true), "Resucita a un luchador muerto: 25 % de probabilidad", "resurrection card")
	t.eq(CardText.effect_line([16, -50], true), "-50 de fatiga", "rest balm")
	t.ok(CardText.effect_line([15, 74, 3], true).ends_with(" durante 3 combates"), "condition with a duration")
	# an action with no text is left out, never shown raw
	t.eq(CardText.effect_line([12], false), "", "action 12 has no text")
	t.eq(CardText.effect_line([15, 74, 3], false), "", "15 is only a consumable's")
	t.eq(CardText.effect_lines([[12], [9, 3], [99, 1]], false), PackedStringArray(["+3 de moral para tus luchadores"]), "lines skip the unknown")
	I18n.set_locale("en")
	t.eq(CardText.effect_line([3, -8], false), "-8 % XP for the rival fighters", "English")
	# every worn and used action the content carries has a text in each language
	for lang in ["es", "en", "fr"]:
		I18n.set_locale(lang)
		for a in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 16, 17, 18, 19, 20, 21]:
			t.ok(CardText.effect_line([a, 1], false) != "", "%s: worn action %d has a text" % [lang, a])
		for a in [2, 5, 9, 11, 13, 16]:
			t.ok(CardText.effect_line([a, 1], true) != "", "%s: used action %d has a text" % [lang, a])
	if was != "":
		I18n.set_locale(was)
