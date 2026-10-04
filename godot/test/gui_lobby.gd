extends SceneTree
## coachCreationDialog + menuBarDialog load smoke

var _gui: GuiLib

func _init() -> void:
	var vp := get_root()
	_gui = GuiLib.new("es")
	var cc := _gui.open_dialog("coachCreationDialog", {"localCoach": {
		"sex": 0, "skin": 1, "hair": 1, "name": "test",
		"actorDescriptorLibrary": "coach_7000",
		"actorAnimation": "AnimStatique", "actorDirection": 3,
		"actorMaterial": {}}})
	print("[smoke] coachCreation:", "ok" if cc != null else "FAIL")
	var mb := _gui.open_dialog("menuBarDialog", {"localCoach":
		{"name": "test", "equipedEmotes": []}, "showToolsInMenuBar": 0,
		"menuBar": {"coachInventoryButton": true, "socialButton": true}})
	print("[smoke] menuBar:", "ok" if mb != null else "FAIL")
	var md := _gui.open_dialog("menuDialog")
	print("[smoke] menu:", "ok" if md != null else "FAIL")
	for r in [cc, mb, md]:
		if r != null:
			vp.add_child(r)
	var tm := _gui.open_dialog("teamManagementDialog")
	print("[smoke] teamMgmt:", "ok" if tm != null else "FAIL")
	quit()
