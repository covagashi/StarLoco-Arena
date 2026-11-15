extends RefCounted
## sprints/S06: the Music and SFX buses exist, the options' volumes land on
## them (mute and a zero slider both silence), and no imported music means
## silence, not an error.

func run(t) -> void:
	t.suite("audio")
	var audio = load("res://src/audio/audio.gd")
	audio.ensure_buses()
	for bus in ["Music", "SFX"]:
		var i := AudioServer.get_bus_index(bus)
		t.ok(i > 0, "%s bus exists" % bus)
		t.eq(AudioServer.get_bus_send(i), &"Master", "%s sends to Master" % bus)
	audio.ensure_buses()
	t.eq(AudioServer.bus_count, 3, "ensure_buses is idempotent")

	audio.apply_prefs({"musicVolume": 0.25, "ambianceSoundsVolume": 0.8})
	t.ok(absf(audio.bus_volume("Music") - 0.25) < 0.001, "music volume 0.25")
	t.ok(absf(audio.bus_volume("SFX") - 0.8) < 0.001, "effects volume 0.8")
	audio.apply_prefs({"musicMute": true, "musicVolume": 0.25,
		"ambianceSoundsVolume": 0.0})
	t.eq(audio.bus_volume("Music"), 0.0, "muted music is silent")
	t.eq(audio.bus_volume("SFX"), 0.0, "a zero slider is silent")
	audio.apply_prefs({})
	t.ok(absf(audio.bus_volume("Music") - 0.5) < 0.001, "default music 0.5")
	t.ok(absf(audio.bus_volume("SFX") - 0.5) < 0.001, "default effects 0.5")

	# no musics imported (a fresh checkout): no stream, so silence, no error
	var assets = load("res://src/util/asset_paths.gd")
	assets.set_roots([])
	var node = audio.new()
	t.eq(node._stream("island"), null, "no imported music -> no stream")
	node.free()
	assets.reset_roots()

