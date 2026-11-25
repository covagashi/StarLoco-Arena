extends "res://test/world_smoke.gd"

## S52: Nilo's guided practice, live. Launches his challenge (46) the way
## Nilo's reply does and plays it through the steps, checking at each one
## that his bubble says the right page, that the right thing blinks and that
## the bubble covers neither it, the foe nor our fighter:
##
##   godot --path godot -s test/practice_smoke.gd -- [--lang=fr] [--skip-at=N] [--shot-dir=D]
##   godot/tools/seeded_smoke.sh practice_smoke "--shot-dir=$HOME/codigo/capturas/s52"
##
## 0. no lesson pages before the fight any more; 1. placement: a free start
## cell blinks, three pages; we place there; 2. Listo blinks; we press it;
## 3. the turn bar, two pages, Continuar on our turn; 4. 288/289, the cell to
## walk to — first a step to another cell (290), then onto it (over as many
## turns as the MP need); 5. the spell blinks, then the foe once it is armed;
## a cast at an empty cell first (292) when the AP allow two; 6. the hit:
## the AP globe (293), then the spell or End turn (294); End turn → gone.
## Since the owner's «1 contra 1 con un muñeco» the fight is our first titular
## against the training dummy: it passes its turn and the second blow fells
## it, ending the fight.
## --skip-at=N presses "Saltar práctica" on step N and checks it stays gone.
## The fight is surrendered at the end.

const PracticeGuide := preload("res://src/fight/practice_guide.gd")
const NpcDialogs3 := preload("res://src/gamedata/npcdialogs.gd")
const S := PracticeGuide.Step

var _lang := "es"
var _skip_at := -1
var _fv
var _ov
var _n := 0


func _audit() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
		if a.begins_with("--skip-at="):
			_skip_at = int(a.trim_prefix("--skip-at="))
	var i18n = root.get_node("I18n")
	var lang_before: String = i18n.lang
	i18n.set_locale(_lang)
	_close_all()
	current_scene = _main   # so the fight view replaces it
	_seen.clear()
	_main._launch_challenge(46, 9)
	# before S52 this opened ten pages and sent nothing until they were read
	_record(0, "no pages before", not _main._gui.is_open("npcTalkDialog"),
		"the lobby opens no lesson before the fight")
	if not await _wait(func(): return _seen.has(8000), 8.0):
		_record(0, "fight", false, "no 8000")
		return
	if is_instance_valid(_main) and _sess.message.is_connected(_main._on_message):
		_sess.message.disconnect(_main._on_message)
	await _wait(func():
		return current_scene != null and current_scene.has_signal("turn_began"), 8.0)
	_fv = current_scene
	if _fv == null or not _fv.has_signal("turn_began") or _fv._practice == null:
		_record(0, "practice", false, "no practice overlay in the fight view")
		return
	_ov = _fv._practice
	await _play()
	i18n.set_locale(lang_before)


func _guide():
	return _ov.guide


func _play() -> void:
	var g = _guide()
	# 1. placement
	if not await _wait(func(): return g.step == S.PLACE and _fv._placement, 20.0):
		_record(1, "placement", false, "step %d" % g.step)
		return
	await create_timer(0.8).timeout
	for i in 3:
		await _check(1, "cell")
		if await _maybe_skip(1):
			return
		if i < 2:
			_ov._next.pressed.emit()
			await create_timer(0.3).timeout
	var cell: Vector2i = _ov.blink().get("cell", Vector2i(-9999, -9999))
	_record(1, "place", _fv.request_place_at(cell), "our fighter → %s" % cell)
	# 2. Listo
	await _wait(func(): return g.step == S.READY, 5.0)
	await create_timer(0.5).timeout
	await _check(2, "rect", _fv._end_turn)
	if await _maybe_skip(2):
		return
	_fv._end_turn.pressed.emit()
	# 3. the turn bar
	await _wait(func(): return g.step == S.OBSERVE, 8.0)
	await create_timer(1.0).timeout
	await _check(3, "rect", _fv._fight_hud.get_node("Timeline"))
	if await _maybe_skip(3):
		return
	_ov._next.pressed.emit()
	await create_timer(0.3).timeout
	await _check(3, "rect", _fv._fight_hud.get_node("Timeline"))
	if not await _wait(func(): return _fv._is_my_turn(), 40.0):
		_record(3, "our turn", false, "never came")
		return
	await create_timer(0.6).timeout
	_ov._next.pressed.emit()   # Continuar
	await create_timer(0.4).timeout
	# 4. walk
	if g.step == S.MOVE:
		await _check(4, "rect", _fv._fight_hud.get_node("Timeline"))   # 288
		if await _maybe_skip(4):
			return
		_ov._next.pressed.emit()
		await create_timer(0.4).timeout
		await _check(4, "cell")   # 289
		await _wrong_cell()
		await _walk()
	else:
		_record(4, "walk", g.step == S.CAST, "began in reach: step %d (no walk to teach)" % g.step)
	# 5. cast
	if not await _wait(func(): return g.step == S.CAST and _fv._is_my_turn(), 60.0):
		_record(5, "cast", false, "step %d" % g.step)
		return
	await create_timer(0.6).timeout
	var sid: int = _ov.lesson_spell(State.fighters.get(_fv._current_fid, {}))
	var spell_btn: Button = _ov.lesson_button()
	await _check(5, "rect", spell_btn if _fv._ap_left >= _ov.spell_ap(sid) else _fv._end_turn)
	if await _maybe_skip(5):
		return
	await _cast(sid)
	# 6. the hit
	if not await _wait(func(): return g.step == S.FINISH, 6.0):
		_record(6, "hit", g.step == S.DONE, "step %d after the cast (done = one blow)" % g.step)
		await _end()
		return
	await create_timer(0.8).timeout
	await _check(6, "circle")   # 293: the AP globe
	_ov._next.pressed.emit()
	await create_timer(0.4).timeout
	spell_btn = _ov.lesson_button()
	var want_btn: Control = spell_btn if spell_btn != null and not spell_btn.disabled \
		and _fv._ap_left >= _ov.spell_ap(sid) else _fv._end_turn
	await _check(6, "rect", want_btn)   # 294
	_fv._end_turn.pressed.emit()
	await _wait(func(): return g.step == S.DONE, 6.0)
	await create_timer(0.6).timeout
	_record(6, "end turn", g.step == S.DONE and not _ov.bubble.visible, "the practice closes with the turn")
	await _shot_n("done")
	await _second_blow(sid)


## S52 (1 vs 1 with a dummy): the dummy passes its turn, and the second blow
## fells it — what 293 promises — and wins the fight.
func _second_blow(sid: int) -> void:
	var dummy: int = _ov._foe
	var cell: Vector2i = _ov._cell_of(dummy)
	var left: int = _fv._hp_max(State.fighters.get(dummy, {})) - int(_fv._hp_lost.get(dummy, 0))
	if not await _wait(func(): return _fv._is_my_turn(), 20.0):
		_record(7, "second blow", false, "our turn never came back")
		await _end()
		return
	await create_timer(0.6).timeout
	var still: bool = _ov._cell_of(dummy) == cell
	_seen.erase(4520)
	_fv._on_spell_button(sid)
	_fv.request_cast_at(sid, cell)
	# the fight view goes once the fight is over: read it before
	await _wait(func(): return _seen.has(4520), 6.0)
	var dead: bool = is_instance_valid(_fv) and _fv._dead.get(dummy, false)
	await create_timer(0.5).timeout
	if is_instance_valid(_fv):
		await _shot_n("felled")
	await _wait(func(): return _seen.has(8300), 8.0)
	_record(7, "second blow", still and left > 0 and dead and _seen.has(8300),
		"the dummy stayed on %s (%s), had %d HP after the first blow; the second fells it (dead %s, fight over %s)"
			% [cell, still, left, dead, _seen.has(8300)])


## One wrong step first: a free cell next to ours that is not the goal nor in
## reach → 290, the cell blinks again.
func _wrong_cell() -> void:
	var g = _guide()
	var goal: Vector2i = _ov._move_goal()
	var here: Vector2i = _ov._cell_of(_fv._current_fid)
	if _fv._mp_left < 2 or goal.x <= -9999:
		_record(4, "wrong cell", true, "skipped: %d MP, goal %s" % [_fv._mp_left, goal])
		return
	var to := Vector2i(-9999, -9999)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = here + d
		if n == goal or not _fv._cells.has(n) or not _fv._cells[n].get("ground", false) \
				or _fv._occupied_fighter(n) >= 0 or _ov._in_reach(n):
			continue
		to = n
		break
	if to.x <= -9999 or not _fv.request_move_to(to):
		_record(4, "wrong cell", true, "skipped: no free cell beside us")
		return
	await _wait(func(): return g.pages == [PracticeGuide.WRONG_CELL], 5.0)
	await _wait(func(): return _fv._walk.is_empty(), 4.0)
	await create_timer(0.6).timeout
	_record(4, "290", g.step == S.MOVE and g.pages == [PracticeGuide.WRONG_CELL],
		"moved to %s (goal %s): page %s" % [to, goal, g.pages])
	await _check(4, "cell_or_end")


## Onto the goal, over as many turns as it takes.
func _walk() -> void:
	var g = _guide()
	for i in 20:
		if g.step != S.MOVE:
			return
		if not await _wait(func(): return _fv._is_my_turn() and _fv._walk.is_empty(), 40.0):
			return
		await create_timer(0.5).timeout
		var goal: Vector2i = _ov._move_goal()
		print("[s52] walk %d: fid %d at %s, foe %d at %s, %d MP, goal %s, reach %s" % [i,
			_fv._current_fid, _ov._cell_of(_fv._current_fid), _ov._foe, _ov._cell_of(_ov._foe),
			_fv._mp_left, goal, _ov._in_reach(_ov._cell_of(_fv._current_fid))])
		if goal.x > -9999 and _fv.request_move_to(goal):
			var before: Array = g.pages.duplicate()
			await _wait(func(): return g.step != S.MOVE or g.pages != before or g.pages == [PracticeGuide.NEXT_TURN], 5.0)
			await _wait(func(): return _fv._walk.is_empty(), 5.0)
			await create_timer(0.6).timeout
			if g.step == S.MOVE:
				await _check(4, "cell_or_end")
		else:
			await _check(4, "cell_or_end")
			_fv._end_turn.pressed.emit()
			await _wait(func(): return not _fv._is_my_turn(), 5.0)


## Step 5: arm the spell (the foe blinks), a miss at an empty cell if the AP
## allow two casts (292), then the foe.
func _cast(sid: int) -> void:
	var g = _guide()
	var foe: Vector2i = _ov._cell_of(_ov._foe)
	_fv._on_spell_button(sid)
	await create_timer(0.6).timeout
	var b: Dictionary = _ov.blink()
	_record(5, "foe blinks", b.get("cell", Vector2i(-1, -1)) == foe, "armed → %s (foe at %s)" % [b, foe])
	await _check(5, "cell")
	var ap: int = _ov.spell_ap(sid)
	if _fv._ap_left >= ap * 2:
		var empty := _empty_in_reach(sid)
		if empty.x > -9999:
			_fv.request_cast_at(sid, empty)
			if await _wait(func(): return g.pages == [PracticeGuide.MISSED], 5.0):
				await create_timer(0.8).timeout
				_record(5, "292", true, "cast at %s, not the foe → 292" % empty)
				await _check(5, "rect", _ov.lesson_button())
			else:
				_record(5, "292", true, "skipped: the server refused a cast at %s" % empty)
			_fv._on_spell_button(sid)
			await create_timer(0.3).timeout
	_fv.request_cast_at(sid, foe)


## A free ground cell the spell reaches from here, not the foe's.
func _empty_in_reach(sid: int) -> Vector2i:
	var from: Vector2i = _ov._cell_of(_fv._current_fid)
	for pos in _fv._range_overlay:
		if int(_fv._range_overlay[pos]) == 2 and _fv._occupied_fighter(pos) < 0 and pos != from:
			return pos
	return Vector2i(-9999, -9999)


## The bubble says the page the guide is on (with this fight's names), the
## blink is what `kind` says (on `node` when given), and the bubble covers
## neither the blink, the foe nor our fighter. A screenshot of each.
func _check(step: int, kind: String, node: Control = null) -> void:
	var g = _guide()
	var want_text: String = _ov.page_text(g.current_page())
	var shown_ok: bool = _ov.bubble.visible and _ov._text.text == want_text and want_text != ""
	var b: Dictionary = _ov.blink()
	var blink_ok := false
	match kind:
		"cell":
			blink_ok = b.has("cell")
		"circle":
			blink_ok = b.has("circle")
		"cell_or_end":
			blink_ok = b.has("cell") or (b.has("rect") and (b.rect as Rect2).is_equal_approx(_fv._end_turn.get_global_rect()))
		"rect":
			blink_ok = b.has("rect") and node != null and (b.rect as Rect2).is_equal_approx(node.get_global_rect())
	# never what blinks nor the foe once it is the next click (weight 100);
	# the foe before that and our fighter only as far as there is room
	var covers := []
	var soft := []
	var mine: Array = [_ov._plate.get_global_rect(), _ov._face.get_global_rect()]
	for a in _ov._avoid():
		for r in mine:
			if (r as Rect2).intersects(a[0]):
				(covers if int(a[1]) >= 100 else soft).append(int(a[1]))
	var tag := "step %d page %d (%d)" % [g.step, g.page + 1, g.current_page()]
	_record(step, tag, shown_ok and blink_ok and covers.is_empty(),
		"text %s, blink %s %s, covers %s (soft %s) — '%s…'" % [shown_ok, kind, blink_ok,
			covers, soft, want_text.left(48)])
	await _shot_n("s%d-p%d-%d" % [g.step, g.page + 1, g.current_page()])


func _shot_n(what: String) -> void:
	_n += 1
	await _shot("%s-%02d-%s" % [_lang, _n, what])


## --skip-at=N: "Saltar práctica" on step N; nothing comes back.
func _maybe_skip(step: int) -> bool:
	if step != _skip_at:
		return false
	var g = _guide()
	_ov._skip.pressed.emit()
	await create_timer(0.4).timeout
	var gone: bool = g.step == S.DONE and g.skipped and not _ov.bubble.visible
	await _shot_n("skipped")
	# the fight goes on; the guide must not wake up again
	var stayed := true
	for i in 30:
		if _fv._placement:
			_fv.confirm_placement()
		if _fv._is_my_turn():
			_fv._end_turn.pressed.emit()
		await create_timer(0.5).timeout
		stayed = stayed and not _ov.bubble.visible and g.step == S.DONE
	_record(step, "skip", gone and stayed, "Saltar práctica: gone %s, stayed gone 15 s %s" % [gone, stayed])
	await _end()
	return true


func _end() -> void:
	_sess.send(8151, PackedByteArray(), 3)
	await _wait(func(): return _seen.has(8300), 10.0)
	await create_timer(0.8).timeout
	var gone: bool = not is_instance_valid(_ov) or not _ov.bubble.visible
	_record(9, "fight over", _seen.has(8300) and gone, "surrendered; the bubble is gone")
