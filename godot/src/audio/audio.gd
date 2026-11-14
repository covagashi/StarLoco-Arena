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
## The oggs come from the player's own client (the old importer's musics.py,
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
##
## S39: the interface's own sounds (Kenney's CC0 packs, assets/audio/ui/):
## ui(kind) on the SFX bus. Every button that enters the tree clicks when
## pressed (a node can opt out with the meta "silent"); panels sound as they
## open and close; toasts, confirmations and errors have theirs. One sound
## per frame — the most important of those asked for — so a click that
## opens a panel is heard once ("feedback on every action, no duplicates").

const BUSES := ["Music", "SFX"]
const TRACKS := ["island", "fight"]
const FADE_S := 1.5

## The track playing (or fading in): "" while silent.
var track := ""

var _players: Array[AudioStreamPlayer] = []
var _tweens: Array = [null, null]
var _active := 0
var _streams := {}

## ui kind → priority (the frame's highest one plays)
const UI_KINDS := {"click": 1, "tab": 1, "back": 1, "card": 2, "open": 2, "close": 2,
	"toast": 3, "coins": 4, "confirm": 4, "error": 5}
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _ui_pending := ""
## the last interface sounds played, newest last (the smokes read it)
var ui_played: Array[String] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var sfx_played: Array[String] = []   # the same for sfx()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_players.append(p)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "SFX"
		add_child(u)
		_ui_players.append(u)
	get_tree().node_added.connect(_on_node_added)


## Every button clicks; a tab bar and a drop-down "switch" when they change.
func _on_node_added(n: Node) -> void:
	if n.has_meta("silent"):
		return
	if n is OptionButton:
		(n as OptionButton).item_selected.connect(func(_i): ui("tab"))
	elif n is BaseButton:
		(n as BaseButton).pressed.connect(func(): ui("click"))
	elif n is TabBar:
		(n as TabBar).tab_changed.connect(func(_i): ui("tab"))


## Ask for an interface sound; the frame's most important one plays at its end.
func ui(kind: String) -> void:
	if not UI_KINDS.has(kind):
		return
	if _ui_pending == "":
		_flush_ui.call_deferred()
	if _ui_pending == "" or int(UI_KINDS[kind]) > int(UI_KINDS[_ui_pending]):
		_ui_pending = kind


func _flush_ui() -> void:
	var kind := _ui_pending
	_ui_pending = ""
	var st := _ui_stream(kind)
	if st == null:
		return
	ui_played.append(kind)
	if ui_played.size() > 16:
		ui_played.pop_front()
	var p := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = st
	p.play()


## A one-shot game sound (S39: a spell's, assets/audio/...) on the SFX bus;
## unlike ui(), several can sound at once. Silent without the file.
func sfx(rel: String, volume_db := 0.0) -> void:
	if not _streams.has(rel):
		_streams[rel] = AudioStreamOggVorbis.load_from_file(AssetPaths.resolve(rel)) if AssetPaths.exists(rel) else null
	var st: AudioStream = _streams[rel]
	if st == null:
		return
	var p: AudioStreamPlayer = null
	for q in _sfx_players:
		if not q.playing:
			p = q
			break
	if p == null:
		if _sfx_players.size() >= 8:
			p = _sfx_players[0]
		else:
			p = AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			_sfx_players.append(p)
	p.stream = st
	p.volume_db = volume_db
	p.play()
	sfx_played.append(rel)
	if sfx_played.size() > 16:
		sfx_played.pop_front()


## A combat sound of `kind` (S39, assets/audio/fight/<kind>_<n>.ogg, Kenney
## CC0): one of its variations at random, so a walk or a flurry of hits
## doesn't repeat the same sample.
const FIGHT_VARIANTS := {"step": 5, "hurt": 5, "death": 5, "tackle": 5, "swing": 3, "jump": 2}


func fight(kind: String, volume_db := 0.0) -> void:
	var n := int(FIGHT_VARIANTS.get(kind, 0))
	if n > 0:
		sfx("audio/fight/%s_%d.ogg" % [kind, randi() % n], volume_db)


## The sound of an interface kind, or null without the file.
func _ui_stream(kind: String) -> AudioStream:
	var key := "ui/" + kind
	if not _streams.has(key):
		var rel := "audio/ui/%s.ogg" % kind
		_streams[key] = AudioStreamOggVorbis.load_from_file(AssetPaths.resolve(rel)) if AssetPaths.exists(rel) else null
	return _streams[key]


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
