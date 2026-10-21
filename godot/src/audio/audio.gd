extends Node
## Audio — the client's buses, the music track and the two volumes
## (sprints/S06).
##
## Buses: Master ← Music, Master ← SFX. Created here at startup (the project
## ships no bus layout), so every AudioStreamPlayer that names "SFX" — the
## AnmSprite pool, which plays every fight sound — follows the effects slider.
##
## Music, as the retail plays it (nk_0.ce, sk_2): track 1 "island" outside a
## fight (aog_1 world entry, RO fight end), track 2 "fight" during one
## (aog_1 / tu_1 fight start). Track 0 "loading" ships but is never asked
## for. The retail cross-fades between them; so does this, on two players.
## The oggs come from the player's own client (tools/asset-import/musics.py,
## assets/musics/); with none imported the game is simply silent.
##
## Volumes live in gamePreferences under the retail optionsDialog keys
## (musicMute/musicVolume, ambianceSoundsMute/ambianceSoundsVolume — the
## retail "sounds" slider drives effects AND ambiences, nk_0.ai) and are
## saved by the GUI layer in user://gui_settings.cfg [prefs]. main calls
## apply_prefs at startup and whenever one changes.
##
## This node is an autoload because main.tscn and fight_view.tscn replace
## each other: the music has to outlive the scene change to fade across it.

const BUSES := ["Music", "SFX"]
const TRACKS := ["island", "fight"]
const FADE_S := 1.5

## The track playing (or fading in): "" while silent.
var track := ""

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array = [null, null]
var _active := 0
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_players.append(p)


static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")


## Linear volume 0..1 of a bus as the options set it (0 while muted).
static func bus_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i < 0 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


static func apply_prefs(gp: Dictionary) -> void:
	ensure_buses()
	_set_bus("Music", bool(gp.get("musicMute", false)),
		float(gp.get("musicVolume", 0.5)))
	_set_bus("SFX", bool(gp.get("ambianceSoundsMute", false)),
		float(gp.get("ambianceSoundsVolume", 0.5)))


static func _set_bus(bus: String, mute: bool, volume: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	volume = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(i, mute or volume <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume, 0.0001)))


## Switch to `name` ("island", "fight", or "" for silence), fading the old
## track out and the new one in. Asking for the track already playing is a
## no-op, so a lobby rebuild doesn't restart the music.
func play_music(name: String) -> void:
	if name == track:
		return
	track = name
	_fade(_active, 0.0, true)
	if name == "":
		return
	var stream := _stream(name)
	if stream == null:
		return   # not imported: silent, track still says what should play
	_active = 1 - _active
	var p := _players[_active]
	p.stream = stream
	p.volume_linear = 0.0
	p.play()
	_fade(_active, 1.0, false)


## The player currently carrying the track (tests read .playing / .stream).
func music_player() -> AudioStreamPlayer:
	return _players[_active]


func _fade(i: int, to: float, stop_after: bool) -> void:
	if _tweens[i] != null:
		_tweens[i].kill()
	var p := _players[i]
	if not p.playing:
		_tweens[i] = null
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_linear", to, FADE_S)
	if stop_after:
		tw.tween_callback(p.stop)
	_tweens[i] = tw


func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var rel := "musics/%s.ogg" % name
	var st: AudioStreamOggVorbis = null
	if AssetPaths.exists(rel):
		st = AudioStreamOggVorbis.load_from_file(AssetPaths.resolve(rel))
		if st != null:
			st.loop = true
	_streams[name] = st
	return st
