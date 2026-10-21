extends RefCounted
## S08: accented names. The retail client shows "LoovÃ©" for the server's
## correct cp1252 "Loové" because its coach object re-decodes the name
## (aez_0.setName: new String(name.getBytes("UTF-8")) with the platform
## charset). Godot must read the same bytes straight. These are the exact
## frames the server writes (BUGS.md B-068).

const WireReader := preload("res://src/net/wire_reader.gd")
const CP1252 := preload("res://src/net/cp1252.gd")


func run(t) -> void:
	t.suite("cp1252_names")
	var cases := [
		["Loové", PackedByteArray([0x05, 0x4C, 0x6F, 0x6F, 0x76, 0xE9])],
		["Défi", PackedByteArray([0x04, 0x44, 0xE9, 0x66, 0x69])],
		["Maître d'élevage", PackedByteArray([0x10]) + "Ma".to_ascii_buffer()
			+ PackedByteArray([0xEE]) + "tre d'".to_ascii_buffer()
			+ PackedByteArray([0xE9]) + "levage".to_ascii_buffer()],
		["5€", PackedByteArray([0x02, 0x35, 0x80])],
	]
	for c in cases:
		var r := WireReader.new(c[1])
		t.eq(r.get_str("u8"), c[0], "u8 name decodes to %s" % c[0])
		t.eq(CP1252.encode(c[0]), c[1].slice(1), "%s encodes back to the same bytes" % c[0])
	# what the retail client would show: the same bytes, one UTF-8 hop too many
	t.ok(WireReader.new(cases[0][1]).get_str("u8") != "LoovÃ©",
		"no extra UTF-8 -> cp1252 hop")
