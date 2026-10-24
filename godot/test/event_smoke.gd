extends "res://test/world_smoke.gd"

## S24: the round's event card says what it does, live. In Spanish.
##
##   godot --path godot -s test/event_smoke.gd [-- --shot-dir=D]
##
## Challenge 14 (already won by `test`: practice, no XP) → the fight view;
## at the first 8100 the strip's newest card carries the effect and the big
## announcement shows. Surrenders.

const CHALLENGE := 14


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale("es")
	current_scene = _main   # so the fight view replaces it
	_seen.clear()
	_main._launch_challenge(CHALLENGE, 99)
	if not await _wait(func(): return _seen.has(8000), 6.0):
		_record(8100, "fight", false, "no 8000")
		return
	if is_instance_valid(_main) and _sess.message.is_connected(_main._on_message):
		_sess.message.disconnect(_main._on_message)
	await _wait(func():
		return current_scene != null and current_scene.has_signal("turn_began"), 6.0)
	var fight = current_scene
	if fight == null or not fight.has_signal("turn_began"):
		_record(8100, "fight", false, "no fight view (current scene: %s)" % (str(current_scene.scene_file_path) if current_scene != null else "null"))
		return
	var ref: WeakRef = weakref(fight)
	fight.placement_began.connect(func():
		create_timer(0.3).timeout.connect(func():
			var f = ref.get_ref()
			if f != null:
				f.confirm_placement()))
	if fight._placement:
		fight.confirm_placement()
	await _wait(func(): return _seen.has(8100), 30.0)
	await create_timer(0.6).timeout
	await _shot("event-announce")
	var announce_shown: bool = fight.get_node_or_null("UI/EventAnnounce") != null
	await create_timer(2.2).timeout   # the announcement fades; the strip stays
	await _shot("event-strip")
	var strip = fight.get_node("UI/EventCards")
	var newest: String = ""
	var card_w := 0.0
	if strip.get_child_count() > 0:
		var card = strip.get_child(strip.get_child_count() - 1)
		var t = card.get_node_or_null("Text")
		newest = t.text if t != null else ""
		card_w = card.size.x
	# the hint line is contextual ("Haz clic en una celda…" takes it over
	# once the turn starts): the strip's card is what keeps the effect
	_record(8100, "event", " · " in newest and card_w >= 200.0 and announce_shown,
		"card '%s' (%d px wide), announce %s" % [newest, int(card_w), str(announce_shown)])
	_sess.send(8151, PackedByteArray(), 3)
	await _wait(func(): return _seen.has(8300), 8.0)
	await create_timer(3.5).timeout
	i18n.set_locale(lang_before)
