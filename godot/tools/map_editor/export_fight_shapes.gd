extends SceneTree

## Writes the fight shapes of the prototype's arenas (1..RELEASE) for the
## server: server/internal/gamedata/arenas/<world>.json, from each layout's
## roles and heights (arena_layout.gd fight_shape). The map editor does the
## same on every save.
##   godot --headless --path godot -s tools/map_editor/export_fight_shapes.gd

const Layout := preload("res://src/maps/arena_layout.gd")


func _initialize() -> void:
	for p in Layout.export_fight_shapes():
		print("[fight shape] ", p)
	quit(0)
