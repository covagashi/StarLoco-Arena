extends RefCounted
## S35: every retail anim set of a fighter, a coach or a summon has its 3D
## figure, so the .anm reader is never asked for one (AnmSprite swaps the
## frames for the figure). Only tracked code: the GLBs under
## art/characters/out/ are git-ignored, so their presence is checked only
## when they are built.

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const FightView := preload("res://src/fight/fight_view.gd")


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
	# the retail channel tints come back as the creation screen's swatches
	for skin in [0, 3, 10]:
		for hair in [0, 5, 13]:
			var back := Fighter3D.from_channels(Palettes.coach_tints(skin, hair))
			var want := Fighter3D.coach_tints(skin, hair)
			t.ok((back.skin as Color).is_equal_approx(want.skin) and (back.hair as Color).is_equal_approx(want.hair),
				"skin %d hair %d round-trips" % [skin, hair])
