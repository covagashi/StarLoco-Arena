extends RefCounted
## S46: the class base stats come from assets/content/breeds.json (built by
## server/cmd/exportclient), not a table copied into fight_view.gd.

const Breeds := preload("res://src/gamedata/breeds.gd")


func run(t) -> void:
	t.suite("breeds")
	var iop := Breeds.stats(8, [])
	t.eq(iop.size(), 3, "a class reads [hp, ap, mp]")
	t.ok(int(iop[0]) > 0 and int(iop[1]) > 0 and int(iop[2]) > 0, "Iop has HP, AP and MP")
	for b in range(1, 13):
		t.eq(Breeds.stats(b, []).size(), 3, "class %d is in the table" % b)
	t.eq(Breeds.stats(99, [60, 6, 3]), [60, 6, 3], "an unknown class falls back")
