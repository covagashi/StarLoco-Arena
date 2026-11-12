extends RefCounted
## S45: every script under src/ compiles. A panel that only some smoke ever
## opens (hero_panel.gd redeclaring a constant its parent class gained) broke
## main.gd for the live client while the unit lane stayed green.


func run(t) -> void:
	t.suite("scripts_compile")
	var paths: Array = []
	_collect("res://src", paths)
	t.ok(paths.size() > 50, "found %d scripts under src/" % paths.size())
	for p in paths:
		var s := load(p) as GDScript
		t.ok(s != null and s.can_instantiate(), "%s compiles" % p)


func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
