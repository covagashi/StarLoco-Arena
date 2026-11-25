extends RefCounted
## S52: Nilo's guided practice, the step machine (src/fight/practice_guide.gd)
## and the overlay's pure parts (which fights get it, the lesson's spell, the
## pages with this fight's names). The live run is test/practice_smoke.gd.

const PracticeGuide := preload("res://src/fight/practice_guide.gd")
const PracticeOverlay := preload("res://src/fight/practice_overlay.gd")
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const S := PracticeGuide.Step


func run(t) -> void:
	t.suite("practice_guide")
	_in_order(t)
	_out_of_order(t)
	_misses_and_wrong_cells(t)
	_ends(t)
	_overlay_parts(t)
	_texts(t)


## The table, played as written.
func _in_order(t) -> void:
	var g := PracticeGuide.new()
	t.ok(not g.active() and g.target() == "", "off before placement")
	g.on_turn(false, false)
	t.eq(g.step, S.OBSERVE, "a turn with no placement seen jumps to step 3")
	g = PracticeGuide.new()
	var hits := [0]
	g.changed.connect(func(): hits[0] += 1)
	g.on_placement()
	t.eq([g.step, g.pages, g.target()], [S.PLACE, [282, 283, 284], "cell_place"], "1: placement, three pages, a cell")
	t.ok(g.has_next(), "1: Siguiente on page 1")
	g.next()
	g.next()
	t.eq([g.page, g.current_page(), g.has_next()], [2, 284, false], "1: last page, no Siguiente: it waits for the move")
	g.next()
	t.eq(g.step, S.PLACE, "1: Siguiente on the last page does nothing")
	g.on_placed()
	t.eq([g.step, g.pages, g.target()], [S.READY, [285], "ready"], "2: moved → Listo blinks")
	g.on_placed()
	t.eq(g.step, S.READY, "2: moving again stays on Listo")
	g.on_ready()
	t.eq([g.step, g.pages, g.target()], [S.OBSERVE, [286, 287], "timeline"], "3: the turn bar")
	g.on_turn(true, false)
	t.eq(g.step, S.OBSERVE, "3: our turn starting does not skip the observation pages")
	g.next()
	t.ok(g.has_next(), "3: its last page still offers Continuar")
	g.next(true, false)
	t.eq([g.step, g.pages, g.target()], [S.MOVE, [288, 289], "timeline"], "4: 288 shows the turn bar")
	g.next()
	t.eq(g.target(), "cell_move", "4: 289 shows the cell")
	g.on_moved(true, true)
	t.eq([g.step, g.pages, g.target()], [S.CAST, [291], "spell"], "5: in reach → the spell")
	g.on_cast(true)
	t.eq([g.step, g.pages, g.target()], [S.FINISH, [293, 294], "ap"], "6: hit → the AP globe")
	g.next()
	t.eq(g.target(), "spell_or_end", "6: then the spell or End turn")
	g.on_turn_end(false)
	t.ok(g.active(), "6: the foe's turn ending does not close it")
	g.on_turn_end(true)
	t.eq([g.step, g.active(), g.skipped], [S.DONE, false, false], "end turn → done")
	t.ok(hits[0] >= 8, "each change is signalled (%d)" % hits[0])


func _out_of_order(t) -> void:
	var g := PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	t.eq(g.step, S.OBSERVE, "Listo while placing skips step 2")
	g = PracticeGuide.new()
	g.on_placement()
	g.on_moved(true, true)
	g.on_cast(true)
	t.eq(g.step, S.PLACE, "a move or cast before the fight starts is ignored")
	# Continue while the foe plays: step 4, the cell comes with our turn
	g.on_ready()
	g.next()
	g.next(false, false)
	t.eq([g.step, g.pages], [S.MOVE, [288, 289]], "Continuar on the foe's turn → step 4")
	g.on_turn(true, true)
	t.eq(g.step, S.CAST, "our turn starting in reach → step 5")
	# moving while step 3 still talks
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.on_moved(false, false)
	t.eq([g.step, g.pages], [S.MOVE, [290]], "a move on step 3 that misses the cell → 290")
	# a hit straight from step 3 / 4
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.on_cast(true)
	t.eq(g.step, S.FINISH, "a hit from step 3 → step 6")
	g.on_cast(true)
	t.eq(g.step, S.FINISH, "another hit stays on step 6")
	g.on_moved(false, false)
	t.eq(g.step, S.FINISH, "a move on step 6 stays")
	g.on_foe_died()
	t.eq(g.step, S.DONE, "the foe down → done")
	# Continue on our turn, already in reach → straight to 5
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.next()
	g.next(true, true)
	t.eq(g.step, S.CAST, "Continuar on our turn in reach → step 5")
	# a later turn of step 4 says only 289
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.next()
	g.next(true, false)
	g.on_turn(true, false)
	t.eq(g.pages, [289], "a later turn on step 4: 289 alone")
	g.on_moved(false, true)
	t.eq([g.step, g.pages], [S.MOVE, [289]], "on the cell but not in reach yet (MP short): keep going")
	g.on_foe_died()
	t.eq(g.step, S.MOVE, "an ally's kill on step 4 does not end it")


func _misses_and_wrong_cells(t) -> void:
	var g := PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.next()
	g.next(true, false)
	g.on_moved(false, false)
	t.eq([g.step, g.pages, g.target()], [S.MOVE, [290], "cell_move"], "another cell → 290, the cell again")
	g.on_moved(true, true)
	t.eq(g.step, S.CAST, "then onto it → 5")
	g.on_cast(false)
	t.eq([g.step, g.pages, g.target()], [S.CAST, [292], "spell"], "a miss → 292, the spell again")
	g.on_moved(false, false)
	t.eq([g.step, g.pages], [S.MOVE, [290]], "walking out of reach on step 5 → back to 4")
	g.on_turn(true, true)
	g.on_cast(true)
	t.eq(g.step, S.FINISH, "then a hit → 6")
	g.on_turn(true, false)
	t.eq(g.step, S.FINISH, "step 6 lasts its turn")


func _ends(t) -> void:
	var g := PracticeGuide.new()
	g.on_placement()
	g.skip()
	t.eq([g.step, g.skipped, g.active(), g.has_next(), g.target()], [S.DONE, true, false, false, ""], "Saltar práctica hides it")
	for ev in [func(): g.on_placement(), func(): g.on_placed(), func(): g.on_ready(),
			func(): g.on_turn(true, true), func(): g.on_moved(true, true), func(): g.on_cast(true),
			func(): g.next(true, true)]:
		ev.call()
	t.eq(g.step, S.DONE, "nothing brings it back after Saltar")
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.on_fight_end()
	t.eq([g.step, g.skipped], [S.DONE, false], "the fight ending closes it")
	g = PracticeGuide.new()
	g.on_placement()
	g.on_ready()
	g.next()
	g.next(true, true)
	g.on_foe_died()
	t.eq(g.step, S.DONE, "a kill on step 5 (one blow) closes it")


func _overlay_parts(t) -> void:
	t.ok(PracticeOverlay.wanted({"fight_type": 5, "fight_id": 46}, false, false), "challenge 46 gets the practice")
	t.ok(not PracticeOverlay.wanted({"fight_type": 5, "fight_id": 34}, false, false), "another challenge does not")
	t.ok(not PracticeOverlay.wanted({"fight_type": 0, "fight_id": 46}, false, false), "a non-challenge fight does not")
	t.ok(not PracticeOverlay.wanted({"fight_type": 5, "fight_id": 46}, true, false), "a spectator does not")
	t.ok(not PracticeOverlay.wanted({"fight_type": 5, "fight_id": 46}, false, true), "a replay does not")
	# the lesson's spell: a strike that reaches the next cell, cheapest first
	t.eq(PracticeOverlay.lesson_spell({"spells": [5, 4, 6, 7]}), 4, "breed 8: the 3-AP strike (4) over the bolt (5)")
	t.eq(PracticeOverlay.lesson_spell({"spells": [3, 16, 17]}), 17, "breed 9: the bolt that reaches 1 (17), not 3 or 16 (min 5, 2)")
	t.eq(PracticeOverlay.lesson_spell({"spells": [21, 22, 24]}), 24, "breed 7: its area strike (24), no heal")
	t.eq(PracticeOverlay.lesson_spell({"spells": [32, 33]}), -2, "nothing that strikes → the weapon")
	t.eq(PracticeOverlay.lesson_spell({}), -2, "no spells → the weapon")
	t.eq(PracticeOverlay.spell_ap(4), 3, "its AP cost")
	t.eq(PracticeOverlay.spell_ap(-2), 5, "the weapon's (server closeCombatAP)")
	# the bubble's place: what it would hide, by weight
	var avoid := [[Rect2(100, 100, 50, 50), 100], [Rect2(400, 100, 50, 50), 10], [Rect2(0, 400, 50, 50), 1]]
	t.eq(PracticeOverlay.cover_cost(Rect2(0, 0, 90, 90), avoid), 0, "clear of everything: 0")
	t.eq(PracticeOverlay.cover_cost(Rect2(120, 120, 300, 30), avoid), 110, "the blink and the foe: 110")
	t.eq(PracticeOverlay.cover_cost(Rect2(0, 380, 30, 30), avoid), 1, "only our fighter: 1")
	# every breed has one
	var Spells = load("res://src/gamedata/spells.gd")
	var none := []
	for b in range(1, 13):
		var ids: Array = Spells.for_breed(b).map(func(s): return int(s.id))
		if PracticeOverlay.lesson_spell({"spells": ids}) < 0:
			none.append(b)
	t.ok(none.is_empty(), "every class has a lesson spell (none for %s)" % [none])
	# the server's dummy: our name for it, the stuffed sack's figure
	var AiNames = load("res://src/gamedata/ai_names.gd")
	var fight := {"teams": [{"id": 1, "fighters": [
		{"id": 9, "coach": AiNames.CHALLENGE_COACH, "breed": 1, "name": "Mannequin", "hp_lost": 60},
		{"id": 8, "coach": 7, "breed": 1, "name": "Mannequin"}]}]}
	AiNames.localize(fight)
	var dummy: Dictionary = fight.teams[0].fighters[0]
	var player: Dictionary = fight.teams[0].fighters[1]
	t.eq([dummy.name, dummy.get("look"), dummy.get("dummy")],
		[NpcDialogs.npc_name(316), 8003, true], "the server's dummy: npc.316 and look 8003")
	t.eq([player.name, player.get("look")], ["Mannequin", null], "a player's fighter of that name is left alone")
	var base: int = load("res://src/gamedata/breeds.gd").stats(1, [0, 0, 0])[0]
	t.eq([dummy.get("hp"), dummy.get("hp_lost")], [base - 60, 0], "its life: breed life − hpLost, nothing lost")


## Nilo's pages read in the three languages, with this fight's names in.
func _texts(t) -> void:
	var was: String = I18n.lang
	var vars := {"foe": "Bastión", "spell": "Golpe", "ap": 3, "ap_max": 6, "mp": 3}
	for lang in ["es", "en", "fr"]:
		I18n.set_locale(lang)
		var bad := []
		for id in [282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294]:
			var s := NpcDialogs.npc_name(id).format(vars)
			if s == "" or "{" in s or "}" in s:
				bad.append(id)
		t.ok(bad.is_empty(), "%s: Nilo's 13 pages fill in (bad %s)" % [lang, bad])
		var page := NpcDialogs.npc_name(291).format(vars)
		t.ok("Golpe" in page, "%s: 291 names the spell" % lang)
		t.ok(NpcDialogs.npc_name(316) != "", "%s: the dummy has a name (npc.316)" % lang)
		var retail := ["Presión", "Pressure", "Pression", "Lanudo", "Woolly", "Laineux", "espadachín", "Swordsman", "Bretteur"]
		var left := []
		for id in range(282, 295):
			for w in retail:
				if w in NpcDialogs.npc_name(id):
					left.append("%d:%s" % [id, w])
		t.ok(left.is_empty(), "%s: no retail spell, foe or class left in them %s" % [lang, left])
	if was != "":
		I18n.set_locale(was)
