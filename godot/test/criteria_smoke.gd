extends "res://test/world_smoke.gd"

## S20B: the login's criteria blob is read id-then-value. GDScript evaluates
## the right side of `d[a()] = b()` first, so every pair came back swapped:
## the client never saw criterion 229 ("coach created") and Aldebrán's intro
## played on every login.
##
##   godot --path godot -s test/criteria_smoke.gd
##
## Needs `test` to have criterion 229 in coach_stats (every coach that has
## been through the intro does).


func _audit() -> void:
	await create_timer(0.5).timeout
	var crit: Dictionary = State.criteria
	# a swapped read keys pairs by their value (1 → …); a straight one has no
	# criterion 1 and carries 229 = 1
	_record(2052, "criteria", int(crit.get(229, 0)) == 1 and not crit.has(1),
		"criteria read as %s" % str(crit))
	_record(2052, "no intro", not _main._gui.is_open("npcTalkDialog"),
		"Aldebrán's intro does not play for a coach that has seen it")
