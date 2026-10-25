extends "res://test/world_smoke.gd"

## S06: music, the two volumes and their persistence, against a live server.
##
##   godot --path godot -s test/audio_smoke.gd
##
## Needs assets/musics/ (the old importer's musics.py). Under xvfb or
## --headless Godot still runs its audio mixer (dummy driver), so a player
## reports .playing like it would with speakers.
##  1. The lobby plays "island" (retail: track 1 outside a fight).
##  2. Options: the effects slider and the music mute land on the SFX and
##     Music buses and are written to user://gui_settings.cfg [prefs]; the
##     previous values are put back afterwards (slider and file).
##  3. A challenge fight cross-fades to "fight" (track 2) — the old player
##     stops once the fade ends — and back to "island" after the fight.
## The fight is surrendered, so the `test` coach takes one defeat.

const CHALLENGE := 3
const CFG := "user://gui_settings.cfg"

var _audio: Node


func _audit() -> void:
	_audio = root.get_node("Audio")
	_boot_volumes()
	await create_timer(2.0).timeout
	_check_track("lobby", "island")
	await _options()
	await _fight()


## The saved volumes are on the buses from the start (a bus Godot creates
## sits at 0 dB = 1.0, so a missed apply shows).
func _boot_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	var music := 0.0 if bool(cfg.get_value("prefs", "musicMute", false)) \
		else float(cfg.get_value("prefs", "musicVolume", 0.5))
	var fx := 0.0 if bool(cfg.get_value("prefs", "ambianceSoundsMute", false)) \
		else float(cfg.get_value("prefs", "ambianceSoundsVolume", 0.5))
	_record(0, "saved volumes at boot", absf(_audio.bus_volume("Music") - music) < 0.001
		and absf(_audio.bus_volume("SFX") - fx) < 0.001,
		"Music %.2f (saved %.2f), SFX %.2f (saved %.2f)" % [
			_audio.bus_volume("Music"), music, _audio.bus_volume("SFX"), fx])


func _check_track(where: String, want: String) -> void:
	var p: AudioStreamPlayer = _audio.music_player()
	var playing := 0
	for c in _audio.get_children():
		if c is AudioStreamPlayer and c.playing:
			playing += 1
	_record(0, "music in " + where, _audio.track == want and p.playing
		and p.stream != null and playing == 1,
		"track '%s' (want '%s'), playing %s, %d player(s) sounding" % [
			_audio.track, want, p.playing, playing])


func _options() -> void:
	_close_all()
	_main._gui.open("optionsDialog")
	await create_timer(0.5).timeout
	var panel = _main._gui.dialogs.get("optionsDialog")
	var fx: HSlider = panel.find_child("ambianceSoundsVolume", true, false) if panel else null
	var mute: CheckButton = panel.find_child("musicMute", true, false) if panel else null
	if fx == null or mute == null:
		_record(0, "options", false, "no effects slider / music mute in the panel")
		return
	var fx_before := fx.value
	var mute_before := mute.button_pressed
	fx.value = 0.2 if absf(fx_before - 0.2) > 0.01 else 0.3
	var want := fx.value
	mute.button_pressed = not mute_before
	await create_timer(0.3).timeout
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	var saved_fx := float(cfg.get_value("prefs", "ambianceSoundsVolume", -1.0))
	var saved_mute := bool(cfg.get_value("prefs", "musicMute", mute_before))
	var bus_fx: float = _audio.bus_volume("SFX")
	var music_silent: bool = _audio.bus_volume("Music") == 0.0
	_record(0, "effects volume", absf(bus_fx - want) < 0.001 and absf(saved_fx - want) < 0.001,
		"slider %.2f → SFX bus %.2f, saved %.2f" % [want, bus_fx, saved_fx])
	_record(0, "music mute", music_silent == (not mute_before) and saved_mute == (not mute_before),
		"mute %s → Music bus silent %s, saved %s" % [not mute_before, music_silent, saved_mute])
	# put the owner's settings back, through the same controls
	fx.value = fx_before
	mute.button_pressed = mute_before
	await create_timer(0.3).timeout
	cfg.load(CFG)
	_record(0, "restored", absf(float(cfg.get_value("prefs", "ambianceSoundsVolume", -1.0)) - fx_before) < 0.001
		and bool(cfg.get_value("prefs", "musicMute", false)) == mute_before,
		"effects %.2f, music mute %s again" % [fx_before, mute_before])
	_close_all()


func _fight() -> void:
	_seen.clear()
	_main._launch_challenge(CHALLENGE, 99)
	if not await _wait(func(): return _seen.has(8000), 6.0):
		_record(8000, "fight", false, "no 8000")
		return
	await _wait(func(): return current_scene != null and current_scene.has_method("_end_fight_ack"), 6.0)
	await create_timer(_audio.FADE_S + 0.5).timeout
	_check_track("fight", "fight")
	_sess.send(8151, PackedByteArray(), 3)
	await _wait(func(): return _seen.has(8300), 8.0)
	await create_timer(1.0).timeout
	var fight = current_scene
	if fight != null and fight.has_method("_end_fight_ack"):
		fight._end_fight_ack()
	await _wait(func(): return _audio.track == "island", 10.0)
	await create_timer(_audio.FADE_S + 0.5).timeout
	_check_track("lobby after the fight", "island")
