extends RefCounted
## S47 W7: the browser's Back closes the window on top, and windows closed
## from the game (×, Esc, one window swapped for another) give their history
## entry back, so Back never lands on a window that is already gone.


## The browser's history as an index into a list of entries; back/go are
## async in a browser, so they queue a popstate that flush() delivers.
class FakeHistory extends RefCounted:
	var at := 0          # 0 = the page itself
	var size := 1
	var pending := []    # index changes not yet delivered
	var on_pop: Callable

	func push() -> void:
		at += 1
		size = at + 1

	func back() -> void:
		pending.append(-1)

	func go(n: int) -> void:
		pending.append(n)

	func detach() -> void:
		on_pop = Callable()

	## the user presses the browser's Back
	func user_back() -> void:
		pending.append(-1)
		flush()

	func flush() -> void:
		while not pending.is_empty():
			var n: int = pending.pop_front()
			var to := clampi(at + n, 0, size - 1)
			if to == at:
				continue
			at = to
			if on_pop.is_valid():
				on_pop.call([])


class Win extends Control:
	signal closed


func run(t) -> void:
	t.suite("gui_history")
	var gui := GuiLayer.new()
	var h := FakeHistory.new()
	gui.history = h
	h.on_pop = gui._on_popstate
	for n in ["socialDialog", "achievementDialog", "cardBookDialog"]:
		gui.native_factories[n] = func(_n): return Win.new()

	gui.open("socialDialog")
	gui.open("achievementDialog")
	t.eq(h.at, 2, "two windows, two entries")
	h.user_back()
	t.ok(not gui.is_open("achievementDialog") and gui.is_open("socialDialog"), "Back closes the top window only")
	t.eq(h.at, 1, "one entry left")

	# closed from the game (× / Esc): its entry goes too, and the popstate
	# that brings is not taken for a Back
	gui.close("socialDialog")
	h.flush()
	t.eq(h.at, 0, "the × gives its entry back")
	t.ok(gui.dialogs.is_empty(), "nothing open")

	# one window swapped for another in the same frame (back is async)
	gui.open("socialDialog")
	gui.close("socialDialog")
	gui.open("cardBookDialog")
	h.flush()
	t.ok(gui.is_open("cardBookDialog"), "the new window survives the old one's back()")
	h.user_back()
	t.ok(gui.dialogs.is_empty(), "and Back closes it")
	t.eq(h.at, 0, "history at the page again")

	# Back with nothing open: nothing to close, nothing breaks
	h.size = 2
	h.at = 1
	h.user_back()
	t.ok(gui.dialogs.is_empty() and h.at == 0, "Back with no window is the browser's")

	# off to a fight with windows open: the entries are handed back
	gui.open("socialDialog")
	gui.open("achievementDialog")
	gui._exit_tree()
	h.flush()
	t.eq(h.at, 0, "a scene change takes the entries back")
	t.ok(not h.on_pop.is_valid(), "and stops listening")
	for k in gui.dialogs:
		gui.dialogs[k].free()
	gui.free()
