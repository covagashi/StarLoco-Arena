extends RefCounted
## S35: every retail anim set of a fighter, a coach or a summon has its 3D
## figure, so the .anm reader is never asked for one (AnmSprite swaps the
## frames for the figure). Only tracked code: the GLBs under
## art/characters/out/ are git-ignored, so their presence is checked only
## when they are built.

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const FightView := preload("res://src/fight/fight_view.gd")
const ArenaLayout := preload("res://src/maps/arena_layout.gd")


func run(t) -> void:
	t.suite("fighter3d")
	var built := DirAccess.dir_exists_absolute("res://art/characters/out")
	for i in FightView.FIGHTER_FILES.size():
		var set_dir := FightView.FIGHTER_SET % FightView.FIGHTER_FILES[i]
		var fig := Fighter3D.figure_of(set_dir)
		t.ok(not fig.is_empty(), "%s has a 3D figure" % set_dir)
		if i < 24:
			t.eq(fig.get("model"), Fighter3D.MODELS[i / 2 + 1][i % 2],
				"%s is breed %d sex %d" % [set_dir, i / 2 + 1, i % 2])
		else:
			t.ok(fig.get("coach", false), "%s is a coach" % set_dir)
		if built:
			t.ok(not Fighter3D.for_set(set_dir).is_empty(), "%s is built" % set_dir)
	for sex in [0, 1]:
		var fig := Fighter3D.figure_of("anims/coach_700%d" % sex)
		t.eq(fig.get("model"), Fighter3D.COACHES[sex], "coach sex %d" % sex)
		t.ok(fig.get("coach", false), "coach sex %d tints" % sex)
	for look in Fighter3D.SUMMONS:
		var fig := Fighter3D.figure_of("anims/npc_%d" % look)
		t.eq(fig.get("model"), Fighter3D.SUMMONS[look][0], "summon %d" % look)
		t.ok(float(fig.get("scale", 1.0)) < 1.0, "summon %d is smaller than a fighter" % look)
	t.ok(Fighter3D.figure_of("anims/portrait_nilo").is_empty(), "a portrait stays retail")
	_art_root(t)
	_equipment(t)
	# the retail channel tints come back as the creation screen's swatches
	for skin in [0, 3, 10]:
		for hair in [0, 5, 13]:
			var back := Fighter3D.from_channels(Palettes.coach_tints(skin, hair))
			var want := Fighter3D.coach_tints(skin, hair)
			t.ok((back.skin as Color).is_equal_approx(want.skin) and (back.hair as Color).is_equal_approx(want.hair),
				"skin %d hair %d round-trips" % [skin, hair])


## S34: the figures are read under the art root (an exported game's art/
## beside the executable), and --old-art / PIPPOP_OLD_ART=1 turns them off.
func _art_root(t) -> void:
	var dir := OS.get_user_data_dir().path_join("fighter3d_test_art")
	DirAccess.make_dir_recursive_absolute(dir.path_join("characters/out"))
	var glb := dir.path_join("characters/out/feca_f.glb")
	var f := FileAccess.open(glb, FileAccess.WRITE)
	f.store_string("glTF")
	f.close()
	ArenaLayout.set_root(dir)
	t.eq(Fighter3D.model_for(1, 1), glb, "a figure is read under the art root")
	t.eq(Fighter3D.model_for(1, 0), "", "a figure missing there is not built")
	t.eq(Fighter3D.for_set("anims/fighter_-111").get("path", ""), glb, "for_set follows the art root")
	OS.set_environment("PIPPOP_OLD_ART", "1")
	t.eq(Fighter3D.model_for(1, 1), "", "PIPPOP_OLD_ART=1 plays the retail sprites")
	t.ok(Fighter3D.for_set("anims/fighter_-111").is_empty(), "and AnmSprite keeps the frames")
	OS.unset_environment("PIPPOP_OLD_ART")
	ArenaLayout.set_root("")
	DirAccess.remove_absolute(glb)


## S35c: equipment cards → pieces on the figure's slots.
func _equipment(t) -> void:
	var w := Fighter3D.fighter_pieces([{"slot": 0, "id": 108}, {"slot": 1, "id": 118}])
	t.eq(w.get("hat"), "hat_straw", "card 108 (hat) shows the straw hat")
	t.eq(w.get("dofus"), "dofus_emerald", "card 118 (dofus) shows the Esmeralda dofus")
	t.eq(Fighter3D.fighter_pieces([{"slot": 0, "id": 1}]).get("weapon"), "sword_raciela", "card 1 (weapon) shows the Raciela sword")
	t.ok(Fighter3D.fighter_pieces([{"slot": 0, "id": 99999}]).is_empty(), "an unknown card shows nothing")
	var fc := preload("res://src/gamedata/fightercards.gd")
	# every card in the pieces table is a real fighter card, and its piece is
	# modelled in art/equipment (kit.kx.js and its includes)
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/equipment/pieces.json"))
	var src := ""
	for f in ["kit", "hats", "weapons", "capes", "pets", "dofus", "coach_hats", "coach_capes", "coach_staffs", "coach_pets"]:
		src += FileAccess.get_file_as_string("res://art/equipment/%s.kx.js" % f)
	# S35c: the coach table — real coach cards, the piece modelled and of
	# the card's slot (Fighter3D.COACH_SLOT through 5201's slot of its type)
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gamedata/cards.json"))
	const COACH_TYPE := {11: "hat", 12: "weapon", 8: "cape", 13: "pet"}
	for cid in pieces.coach:
		var ctype := int(cards.get(cid, {}).get("type", -1))
		t.ok(COACH_TYPE.has(ctype), "coach card %s is a hat, staff, cape or pet card" % cid)
		t.ok(src.contains('model("%s"' % pieces.coach[cid]), "coach card %s: %s is modelled" % [cid, pieces.coach[cid]])
		var want: Array = {"hat": ["hat_"], "weapon": ["staff_", "banner_"], "cape": ["cape_"], "pet": ["pet_"]}.get(COACH_TYPE.get(ctype, ""), [])
		t.ok(want.any(func(w): return String(pieces.coach[cid]).begins_with(w)), "coach card %s shows a %s piece" % [cid, want])
	t.eq(Fighter3D.coach_pieces([{"slot": 0, "id": 8}, {"slot": 8, "id": 18}, {"slot": 3, "id": 10}]),
		{"hat": "hat_horned", "cape": "cape_jalatranki"}, "coach slots 0 and 8 show a hat and a cape; 3 (shoulders) nothing yet")
	for cid in pieces.fighter:
		t.ok(Fighter3D.FIGHTER_SLOT.has(fc.slot_type(int(cid))), "card %s has a fighter slot" % cid)
		t.ok(src.contains('model("%s"' % pieces.fighter[cid]), "card %s: %s is modelled" % [cid, pieces.fighter[cid]])
		var slot: String = Fighter3D.FIGHTER_SLOT.get(fc.slot_type(int(cid)), "")
		if slot in ["hat", "cape", "pet", "dofus"]:
			t.ok(String(pieces.fighter[cid]).begins_with(slot + "_"), "card %s (%s) shows a %s piece" % [cid, slot, slot])
