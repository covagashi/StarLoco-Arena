extends SceneTree

## Offline timing of the retail cardMasterDialog: open, close, reopen.
##
##   N=845 godot --headless --path godot -s test/shop_perf.gd
##
## N = catalogue size (default 845: what the server sends for a Card Master
## whose card set is unknown — every priced card). S05 found a reopen took
## 66 s and a first open showed an empty catalogue; see sprints/S05.
func _init() -> void:
	await process_frame
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var n := int(OS.get_environment("N")) if OS.get_environment("N") != "" else 845
	var all: Array = preload("res://src/gamedata/cards.gd").all_ids()
	var cards := []
	for i in mini(n, all.size()):
		cards.append({"id": int(all[i]), "qty": 99})
	var t := Time.get_ticks_msec()
	main._open_shop({"mode": 0, "shop_id": 17, "cards": cards})
	print("[perf] open %d ms, cards=%d" % [Time.get_ticks_msec() - t, cards.size()])
	t = Time.get_ticks_msec()
	await process_frame
	print("[perf] first frame %d ms, rows=%d" % [Time.get_ticks_msec() - t,
		_rows(main._gui.dialogs["cardMasterDialog"])])
	main._gui.close("cardMasterDialog")
	await process_frame
	t = Time.get_ticks_msec()
	main._open_shop({"mode": 0, "shop_id": 18, "cards": cards})
	print("[perf] reopen %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	await process_frame
	print("[perf] reopen frame %d ms, rows=%d" % [Time.get_ticks_msec() - t,
		_rows(main._gui.dialogs["cardMasterDialog"])])
	quit(0)


func _rows(n: Node) -> int:
	var c := 0
	for ch in n.get_children():
		if ch.get_meta("list_row", false):
			c += 1
		c += _rows(ch)
	return c
