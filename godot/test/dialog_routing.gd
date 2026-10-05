extends SceneTree
## Regression for retail uppercase close names, aliases and bare unloadDialog.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var layer := GuiLayer.new()
	root.add_child(layer)
	var first := layer.open("MenuDialog")
	assert(first != null and layer.is_open("menuDialog"))
	assert(layer.open("menuDialog") == first)
	layer._on_event("dofusarena", "closeMenuDialog", [], first)
	assert(not layer.is_open("MenuDialog"))
	await process_frame
	var inventory := layer.open("CoachInventoryDialog")
	assert(inventory != null and layer.is_open("cardBookDialog"))
	layer.gui._dispatch_one("unloadDialog", inventory)
	assert(not layer.is_open("coachInventoryDialog"))
	await process_frame
	var flags := {"custom_closed": false}
	layer.on("closeFighterEditionDialog", func(_args, _widget): flags.custom_closed = true)
	layer._on_event("dofusarena", "closeFighterEditionDialog", [], null)
	assert(flags.custom_closed)
	root.size = Vector2i(1024, 768)
	await process_frame
	print("[routing] PASS: canonical close, alias, duplicate open, unload, resize after close")
	quit()
