extends RefCounted
## Nilo's groups the retail left in French (npc_text_fix.gd, S20): the fix
## replaces the text and the reply labels it names, keeps everything else.

const NpcTextFix := preload("res://src/gamedata/npc_text_fix.gd")


func run(t) -> void:
	t.suite("npc_text_fix")
	var g := {"text": "Oui, effectivement", "replies": [
		{"label": "Merci", "next": 8}, {"label": "Au revoir", "next": 0}]}
	var es := NpcTextFix.apply("es", 69, g)
	t.ok(str(es.text).begins_with("Sí:"), "es 69 text replaced")
	t.eq(es.replies[0].label, "Merci", "a label the fix does not name stays")
	t.eq(es.replies[1].next, 0, "targets stay")
	t.eq(g.text, "Oui, effectivement", "the data node is not modified")
	t.eq(NpcTextFix.apply("fr", 69, g).text, "Oui, effectivement", "French keeps its own text")
	var eight := {"text": "Muy bien.", "replies": []}
	for i in 12:
		eight.replies.append({"label": "r%d" % i, "next": 69 if i == 4 else i})
	var e8 := NpcTextFix.apply("es", 8, eight)
	t.eq(e8.replies[4].label, "¿Importa hacia dónde mira mi luchador?",
		"the reply that led to 69 now asks what 69 answers")
	t.eq(e8.replies[4].next, 69, "and still leads there")
	# no French markers left in any Spanish or English fix
	var french := RegEx.create_from_string("\\b(j'ai|merci|kards?|tu peux|ça|n'oublie)\\b")
	for loc in ["es", "en"]:
		for id in NpcTextFix.FIX[loc]:
			var fix: Dictionary = NpcTextFix.FIX[loc][id]
			var texts: Array = [str(fix.get("text", ""))] + fix.get("labels", {}).values()
			for s in texts:
				t.ok(french.search(str(s).to_lower()) == null, "%s %d: no French in '%s'" % [loc, id, str(s).left(40)])
