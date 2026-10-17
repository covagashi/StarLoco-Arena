extends SceneTree

## Geometry fingerprint of a few retail dialogs: every GWidget's rect, in tree
## order, hashed. Used to prove a layout-engine change moves nothing.
const DIALOGS := ["cardMasterDialog", "mailboxDialog", "fusionLabDialog",
	"fireworkDialog", "logonDialog", "cardBookDialog", "zaapDialog"]

func _init() -> void:
	await process_frame
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var cards := []
	var all: Array = preload("res://src/gamedata/cards.gd").all_ids()
	for i in 40:
		cards.append({"id": int(all[i]), "qty": 9})
	main._open_shop({"mode": 0, "shop_id": 5, "cards": cards})
	await process_frame
	await process_frame
	_dump("cardMasterDialog", main._gui.dialogs["cardMasterDialog"])
	main._gui.close("cardMasterDialog")
	for d in DIALOGS.slice(1):
		var t := Time.get_ticks_msec()
		var w = main._gui.open(d)
		await process_frame
		await process_frame
		if w == null:
			print("[hash] ", d, " did not open")
			continue
		_dump(d, w, Time.get_ticks_msec() - t)
		main._gui.close(d)
	quit(0)


func _dump(name: String, w: Node, ms := -1) -> void:
	var lines := PackedStringArray()
	_walk(w, lines)
	print("[hash] %s widgets=%d hash=%s ms=%d" % [name, lines.size(),
		"\n".join(lines).md5_text(), ms])


func _walk(n: Node, out: PackedStringArray) -> void:
	if n is Control:
		out.append("%s %s %s %s" % [n.name, n.position.round(), n.size.round(), n.visible])
	for c in n.get_children():
		_walk(c, out)
