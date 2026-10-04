extends SceneTree
## fightResultDialog load smoke — exercises template/include/valueReplacer

var _gui: GuiLib

func _init() -> void:
	var vp := get_root()
	vp.gui_embed_subwindows = false
	_gui = GuiLib.new("es")
	var root := _gui.open_dialog("fightResultDialog", {
		"fight": {
			"localWinner": true,
			"wonCards": [], "bonusCards": [], "lostCards": [],
			"team0Fighters": [], "team1Fighters": [],
		}
	})
	print("[smoke] fightResultDialog:", "loaded" if root != null else "FAILED")
	if root != null:
		vp.add_child(root)
		var cnt := 0
		var todo := [root]
		while not todo.is_empty():
			var w = todo.pop_back()
			cnt += 1
			for ch in w.get_children():
				if ch is GWidget:
					todo.append(ch)
		print("[smoke] widgets:", cnt)
	quit()
