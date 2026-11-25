extends CanvasLayer
## S53 (owner on Safari: a grey screen after «¡Crear!», "WebSocket … The
## network connection was lost"; F5 fixed it): whatever screen is up when
## the server's socket drops after login, this says so over everything and
## offers «Reconectar». On the web that reloads the page (the browser keeps
## the guest's key, so it walks straight back in); elsewhere it goes back to
## the login screen. A page the browser sent to the background — a switched
## app or a locked screen, which is when Safari cuts the socket — reconnects
## by itself as soon as it is in front again.

const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")

var _was_hidden := false
var _poll := 0.0


func _ready() -> void:
	layer = 120   # over the fight HUD, the panels and the spotlight
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.07, 0.13, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var plate := PanelContainer.new()
	plate.name = "LostConnection"
	var ps := StyleB.plate(0.98)
	ps.border_color = UiStyle.B_CORAL
	ps.border_width_left = 6
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	plate.add_theme_stylebox_override("panel", ps)
	centre.add_child(plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	plate.add_child(col)
	var title := Label.new()
	title.text = I18n.t("net.lost_title")
	UiStyle.display(title, 34, UiStyle.B_INK)
	col.add_child(title)
	var body := Label.new()
	body.text = I18n.t("net.lost_body")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 420
	body.add_theme_font_override("font", UiStyle.body_font())
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UiStyle.B_INK)
	col.add_child(body)
	var again := StyleB.button(true, 22)
	again.name = "Reconnect"
	again.text = I18n.t("net.reconnect")
	again.custom_minimum_size = Vector2(230, 54)
	again.size_flags_horizontal = Control.SIZE_SHRINK_END
	again.pressed.connect(reconnect)
	col.add_child(again)
	again.grab_focus.call_deferred()
	_was_hidden = _page_hidden()


func _process(dt: float) -> void:
	if not OS.has_feature("web"):
		return
	_poll += dt
	if _poll < 0.5:
		return
	_poll = 0.0
	if _page_hidden():
		_was_hidden = true
	elif _was_hidden:
		reconnect()   # back in front: no need to ask


func reconnect() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.reload()")
		return
	queue_free()
	get_tree().change_scene_to_file("res://src/main.tscn")


static func _page_hidden() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("document.visibilityState")) == "hidden"
