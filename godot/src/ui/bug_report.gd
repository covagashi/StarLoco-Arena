extends AcceptDialog

## BugReportDialog — the client's counterpart of retail's "Rapport de bug"
## (aOG.a). POSTs multipart/form-data to `<base>/<lang>/bug-report` using the
## exact field names the endpoint (and the retail client) uses:
##
##   screenshot                        JPEG, "screenBug.jpg"
##   bug[title] [type]                 what the player wrote
##   bug[seen_comportment]             what happened
##   bug[awaited_comportment]          what should have happened
##   bug[way_to_reproduce]
##   log                               DebugLog tail
##   user[character][id|name|world]    coach context (unauthenticated claims)
##   user[account][name]
##   user[lang]
##   config[client_version|screen|OS]  environment for reproducing
##
## The endpoint answers "OK" on the first line for every accepted body, so a
## send failure is the only case worth flagging to the player.

const State := preload("res://src/state.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const DebugLog := preload("res://src/util/debug_log.gd")

var base_url := ""
var _types := ["bug.type.game", "bug.type.display", "bug.type.chat",
	"bug.type.other"]
var _title: LineEdit
var _type: OptionButton
var _seen: TextEdit
var _awaited: TextEdit
var _repro: TextEdit
var _status: Label
var _send_btn: Button
var _shot := PackedByteArray()
var _scroll: ScrollContainer


func set_screenshot(bytes: PackedByteArray) -> void:
	_shot = bytes


func _init(url: String) -> void:
	base_url = url
	title = I18n.t("bug.title")
	ok_button_text = I18n.t("bug.close")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(460, 440)
	add_child(_scroll)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(440, 0)
	vb.add_theme_constant_override("separation", 8)
	_scroll.add_child(vb)

	_title = _field(vb, "bug.field.title", LineEdit.new())
	_type = OptionButton.new()
	for t in _types:
		_type.add_item(I18n.t(t))
	vb.add_child(_with_label("bug.field.type", _type))
	_seen = _field(vb, "bug.field.seen", _text_edit())
	_awaited = _field(vb, "bug.field.awaited", _text_edit())
	_repro = _field(vb, "bug.field.repro", _text_edit())

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_status)

	_send_btn = Button.new()
	_send_btn.text = I18n.t("bug.send")
	_send_btn.pressed.connect(_send)
	vb.add_child(_send_btn)
	confirmed.connect(func(): queue_free())
	canceled.connect(func(): queue_free())


func _text_edit() -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(0, 64)
	t.scroll_fit_content_height = true
	return t


func _with_label(key: String, c: Control) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = I18n.t(key)
	l.add_theme_font_size_override("font_size", 14)
	vb.add_child(l)
	vb.add_child(c)
	return vb


func _field(vb: VBoxContainer, key: String, c: Control) -> Control:
	vb.add_child(_with_label(key, c))
	return c


func _ready() -> void:
	theme = _theme()
	_scroll.custom_minimum_size.y = minf(480.0, get_viewport().get_visible_rect().size.y - 150.0)
	_title.grab_focus.call_deferred()
	if base_url == "":
		_send_btn.disabled = true
		_status.text = I18n.t("bug.unavailable")


func _theme() -> Theme:
	var result := Theme.new()
	var font := FontFile.new()
	font.load_dynamic_font("res://assets/gui/fonts/TAHOMA.TTF")
	result.default_font = font
	result.default_font_size = 16
	result.set_stylebox("panel", "AcceptDialog", _surface(Color("292c20"), Color("ad965a"), 2))
	for type in ["Label", "Button", "OptionButton", "LineEdit", "TextEdit", "PopupMenu"]:
		result.set_color("font_color", type, Color("f1e5c1"))
		result.set_color("font_disabled_color", type, Color("9b9c85"))
	for type in ["Button", "OptionButton", "LineEdit", "TextEdit", "PopupMenu"]:
		result.set_stylebox("normal", type, _surface(Color("20251d"), Color("656849")))
		result.set_stylebox("hover", type, _surface(Color("545534"), Color("c3ad69")))
		result.set_stylebox("pressed", type, _surface(Color("545534"), Color("c3ad69")))
		result.set_stylebox("focus", type, _surface(Color.TRANSPARENT, Color("f6d583"), 2))
	return result


func _surface(fill: Color, border: Color, width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	return style


## RFC-2046 multipart body in the client's own shape (the server matches the
## field names verbatim; order and boundary are free).
func _body(boundary: String, fields: Array) -> PackedByteArray:
	var b := PackedByteArray()
	var put := func(s: String) -> void: b.append_array(s.to_utf8_buffer())
	if not _shot.is_empty():
		put.call("--%s\r\nContent-Disposition: form-data; name=\"screenshot\"; " % boundary +
			"filename=\"screenBug.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
		b.append_array(_shot)
		put.call("\r\n")
	for pair in fields:
		put.call("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [
			boundary, pair[0], pair[1]])
	put.call("--%s--\r\n" % boundary)
	return b


func _send() -> void:
	_send_btn.disabled = true
	_status.text = I18n.t("bug.sending")
	var size := get_viewport().get_visible_rect().size
	var fields := [
		["bug[title]", _title.text],
		["bug[type]", _type.get_item_text(_type.selected)],
		["bug[seen_comportment]", _seen.text],
		["bug[awaited_comportment]", _awaited.text],
		["bug[way_to_reproduce]", _repro.text],
		["log", DebugLog.tail()],
		["user[character][id]", str(State.my_coach_id)],
		["user[character][name]", State.my_coach_name],
		["user[character][world][x]", "0"],
		["user[character][world][y]", "0"],
		["user[character][world][name]", str(State.current_world)],
		["user[account][name]", State.my_coach_name],
		["user[lang]", I18n.lang],
		["config[client_version]", "godot 2.70"],
		["config[screen][width]", str(int(size.x))],
		["config[screen][height]", str(int(size.y))],
		["config[screen][fullscreen]", str(DisplayServer.window_get_mode()
			== DisplayServer.WINDOW_MODE_FULLSCREEN)],
		["config[OS][name]", OS.get_name()],
		["config[OS][arch]", Engine.get_architecture_name()],
	]
	var boundary := "--==arena-bug-%x==" % Time.get_ticks_usec()
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_done.bind(http))
	var url := "%s/%s/bug-report" % [base_url, I18n.lang]
	var err := http.request_raw(url,
		["Content-Type: multipart/form-data; boundary=" + boundary],
		HTTPClient.METHOD_POST, _body(boundary, fields))
	if err != OK:
		http.queue_free()
		_send_btn.disabled = false
		_status.text = I18n.t("bug.failed")
		DebugLog.add("bug report: request failed to start (%s)" % error_string(err))
		return
	DebugLog.add("bug report: POST %s" % url)


func _on_done(result: int, code: int, _h: PackedStringArray,
		body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	# Retail contract: the endpoint's first line is exactly "OK" for any
	# accepted body — a 200 with anything else is a proxy/captive failure.
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 \
		and body.get_string_from_utf8().strip_edges().begins_with("OK")
	_status.text = I18n.t("bug.sent") if ok else I18n.t("bug.failed")
	_send_btn.disabled = ok
	if ok:
		DebugLog.add("bug report: accepted (HTTP %d)" % code)
	else:
		DebugLog.add("bug report: HTTP %d, result %d" % [code, result])
