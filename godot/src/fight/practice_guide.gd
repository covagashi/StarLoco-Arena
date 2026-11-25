extends RefCounted
## S52: Nilo's guided practice (challenge 46, "Tutorial de Baan"), the step
## machine. No scene, no wire: fight_view tells it what happened (the
## practice overlay, practice_overlay.gd, forwards the real game events) and
## it answers which step the player is on, which of Nilo's pages to show and
## what to make blink. The owner chose "paso a paso" (2026-11-25):
##
##   step  moment                Nilo says        blinks              moves on when
##   1     placement             282 283 284      a free start cell   our fighter moves (or Ready)
##   2     placement             285              Ready               Ready (or placement ends)
##   3     observation / start   286 287          the turn bar        the bubble's Continue
##   4     our turn              288 289          the cell to walk to we move; elsewhere → 290
##   5     in reach of the foe   291              the spell, the foe  we cast; a miss → 292
##   6     we hit it             293 294          AP globe, then the  the foe dies or we end
##                                                spell or End turn   the turn
##
## Out of order is fine: Ready while placing skips step 2, a cast that lands
## from step 4 goes to 6, a turn that starts in reach goes to 5, the fight
## ending closes it. skip() ("Saltar práctica") closes it for the fight.

signal changed

enum Step { OFF, PLACE, READY, OBSERVE, MOVE, CAST, FINISH, DONE }

const TOTAL := 6   # the steps the player sees ("paso n de 6")
const PAGES := {
	Step.PLACE: [282, 283, 284],
	Step.READY: [285],
	Step.OBSERVE: [286, 287],
	Step.MOVE: [288, 289],
	Step.CAST: [291],
	Step.FINISH: [293, 294],
}
const WRONG_CELL := 290   # moved, but not where it blinked
const NEXT_TURN := 289    # a later turn of step 4: only the "go" page
const MISSED := 292       # cast, and missed the foe

var step: int = Step.OFF
var pages: Array = []
var page := 0
var skipped := false
var _intro_done := false   # 288 plays once; later step-4 turns say 289 alone


## The bubble shows something.
func active() -> bool:
	return step != Step.OFF and step != Step.DONE


func current_page() -> int:
	return int(pages[page]) if page < pages.size() else -1


## A "Siguiente" (another page), or step 3's "Continuar" on its last one.
func has_next() -> bool:
	return active() and (page < pages.size() - 1 or step == Step.OBSERVE)


## What blinks: "cell_place", "ready", "timeline", "cell_move", "spell" (the
## overlay turns it into the foe once the spell is armed), "ap",
## "spell_or_end", or "" for nothing.
func target() -> String:
	match step:
		Step.PLACE:
			return "cell_place"
		Step.READY:
			return "ready"
		Step.OBSERVE:
			return "timeline"
		Step.MOVE:
			return "timeline" if current_page() == 288 else "cell_move"
		Step.CAST:
			return "spell"
		Step.FINISH:
			return "ap" if page == 0 else "spell_or_end"
	return ""


## --- what happened ----------------------------------------------------------

## Placement opened (8020): the practice starts.
func on_placement() -> void:
	if step == Step.OFF:
		_go(Step.PLACE)


## One of our fighters moved during placement (8022).
func on_placed() -> void:
	if step == Step.OFF or step == Step.PLACE:
		_go(Step.READY)


## Ready pressed, or placement over (8028) — the server may end it.
func on_ready() -> void:
	if step >= Step.OFF and step < Step.OBSERVE:
		_go(Step.OBSERVE)


## A turn began. `ours`: one of our fighters plays it; `in_reach`: it can hit
## the foe from where it stands.
func on_turn(ours: bool, in_reach: bool) -> void:
	if not active() and step != Step.OFF:
		return
	if step < Step.OBSERVE:
		_go(Step.OBSERVE)   # the placement went by without us
		return
	if not ours or step == Step.OBSERVE:
		return              # step 3 waits for its Continue
	if step == Step.FINISH:
		return              # the same turn's lesson; it ends with the turn
	_aim(in_reach)


## Our fighter walked (4524). `in_reach` from where it stopped, `on_target`:
## it stopped on the cell that blinked.
func on_moved(in_reach: bool, on_target: bool) -> void:
	if step < Step.OBSERVE or not active():
		return
	if step == Step.FINISH:
		return
	if in_reach:
		if step != Step.CAST:
			_go(Step.CAST)
	elif on_target:
		_go(Step.MOVE, [NEXT_TURN])   # closer; the rest next turn
	else:
		_go(Step.MOVE, [WRONG_CELL])


## Our fighter cast a spell / struck (8110, 8112, 8108). `hit`: it landed on
## a foe.
func on_cast(hit: bool) -> void:
	if step < Step.OBSERVE or not active():
		return
	if hit:
		if step != Step.FINISH:
			_go(Step.FINISH)
	elif step != Step.FINISH:
		_go(Step.CAST, [MISSED])


## A foe went down (4520). After the lesson's hit (or from step 5 on), that is
## the end of the practice.
func on_foe_died() -> void:
	if step == Step.CAST or step == Step.FINISH:
		_go(Step.DONE)


## A turn ended (8106).
func on_turn_end(ours: bool) -> void:
	if ours and step == Step.FINISH:
		_go(Step.DONE)


## The fight is over (8300).
func on_fight_end() -> void:
	if step != Step.DONE:
		_go(Step.DONE)


## "Siguiente" / "Continuar". `ours` / `in_reach` say where the turn stands,
## for step 3's Continue.
func next(ours := false, in_reach := false) -> void:
	if not active():
		return
	if page < pages.size() - 1:
		page += 1
		changed.emit()
	elif step == Step.OBSERVE:
		if ours:
			_aim(in_reach)
		else:
			_go(Step.MOVE)


## "Saltar práctica": hidden for the rest of the fight.
func skip() -> void:
	skipped = true
	_go(Step.DONE)


## Step 4 or 5 for a turn of ours that is starting (or going on).
func _aim(in_reach: bool) -> void:
	if in_reach:
		_go(Step.CAST)
	elif _intro_done:
		_go(Step.MOVE, [NEXT_TURN])
	else:
		_go(Step.MOVE)


func _go(s: int, custom: Array = []) -> void:
	step = s
	pages = custom if not custom.is_empty() else PAGES.get(s, [])
	page = 0
	if s == Step.MOVE and custom.is_empty():
		_intro_done = true
	changed.emit()
