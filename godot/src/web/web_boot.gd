extends Control

## The web demo's first scene (S44; project.godot run/main_scene.web):
## downloads the boot bundle (WebAssets) behind a progress bar, then hands
## over to main.tscn, which then finds every table, image, sound and figure
## where a desktop build has them. Nothing here may read an asset: none is
## here yet, so its few words are its own (WORDS).

const MAIN := "res://src/main.tscn"
## Its few words in the browser's language: the translations come with the
## boot bundle, after this screen.
const WORDS := {
	"es": {"loading": "Cargando…", "retry": "Reintentar", "failed": "No se pudo descargar el juego. Revisa la conexión."},
	"en": {"loading": "Loading…", "retry": "Retry", "failed": "Couldn't download the game. Check your connection."},
	"fr": {"loading": "Chargement…", "retry": "Réessayer", "failed": "Impossible de télécharger le jeu. Vérifie ta connexion."},
}
## The splash (vex, S44): an imported texture, so it ships inside the .pck
## and is here before any bundle. Without it the screen is plain.
const SPLASH := "res://src/web/splash.png"

var _bar := ProgressBar.new()
var _label := Label.new()
var _retry := Button.new()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var splash := ResourceLoader.exists(SPLASH)
	if splash:
		bg.color = Color("e9eaf1")
		var art := TextureRect.new()
		art.texture = load(SPLASH)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(art)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(420, 0)
	if splash:   # the splash leaves its bottom band for the bar
		box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		box.position = Vector2(-210, -92)
	else:
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.position = Vector2(-210, -60)
	add_child(box)
	if not splash:
		var title := Label.new()
		title.text = "Pippop Arena"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 40)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		box.add_child(title)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.45)
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if splash:   # ink and coral on the light splash
		_label.add_theme_color_override("font_color", Color("1c2033"))
		back.bg_color = Color(0.11, 0.13, 0.2, 0.18)
		fill.bg_color = Color("ff4d6d")
	box.add_child(_label)
	_retry.text = _w("retry")
	_retry.visible = false
	_retry.pressed.connect(_load)
	box.add_child(_retry)
	_load.call_deferred()


func _process(_dt: float) -> void:
	if WebAssets.downloading() != "":
		_bar.value = WebAssets.progress()
		_label.text = "%s %d %%" % [_w("loading"), int(WebAssets.progress() * 100.0)]


func _load() -> void:
	_retry.visible = false
	_label.text = _w("loading")
	if not await WebAssets.ensure(["boot"]):
		_label.text = _w("failed")
		_retry.visible = true
		return
	_bar.value = 1.0
	I18n.reload()   # its autoload ran before the tables were here
	WebAssets.fetch_later()   # the fighters and summons, while the player logs in
	get_tree().change_scene_to_file.call_deferred(MAIN)


func _w(key: String) -> String:
	return WORDS.get(OS.get_locale_language(), WORDS.en)[key]
