extends "res://test/world_smoke.gd"

## S20: Nilo's tree in Spanish, live — no French left on the way, and the
## reply that used to say goodbye and open the orientation lesson (group 69)
## now asks the question that lesson answers.
##
##   godot --path godot -s test/nilo_smoke.gd [-- --shot-dir=D]

const NILO := 143        # Aprendizaje element of Nilo (antes Baan)
var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.2).timeout
	var btn: Button = await _service_button(NILO)
	if btn == null:
		_record(0, "nilo", false, "no Nilo button in Servicios")
		return
	btn.pressed.emit()
	await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0)
	await create_timer(0.4).timeout
	var p = _main._gui.dialogs.get("npcTalkDialog")
	if not await _pick(p, "Soy nuevo"):
		return
	var tackle := _choice(p, "placaje") != null
	var orient := _choice(p, "¿Importa hacia dónde mira mi luchador?") != null
	var french := _choice(p, "kézaco") != null
	_record(0, "group 8", tackle and orient and not french,
		"placaje=%s, orientación=%s, francés=%s" % [str(tackle), str(orient), str(french)])
	await _shot("nilo-8")
	if not await _pick(p, "¿Importa hacia dónde mira"):
		return
	var speech: RichTextLabel = p.find_child("Speech", true, false)
	var text := speech.get_parsed_text() if speech != null else ""
	_record(0, "group 69", text.begins_with("Sí:") and text.find("Oui") < 0,
		"'%s…'" % text.left(60))
	await _shot("nilo-69")
	if await _pick(p, "Tengo más preguntas"):
		await _pick(p, "Háblame de las cartas")
		var cards_ok := _choice(p, "¿Para qué me sirven las cartas?") != null and _choice(p, "kards") == null
		_record(0, "group 74", cards_ok, "the card questions are in Spanish")
		if await _pick(p, "¿Cómo se consiguen las cartas?"):
			speech = p.find_child("Speech", true, false)
			text = speech.get_parsed_text() if speech != null else ""
			_record(0, "group 80", text.begins_with("Hay muchas") and text.find("ogrin") < 0,
				"'%s…', no ogrines" % text.left(40))
	_close_all()
	i18n.set_locale(_lang_before)


func _choice(p, needle: String) -> Button:
	for b in p.find_children("Choice*", "Button", true, false):
		if needle in b.text:
			return b
	return null


func _pick(p, needle: String) -> bool:
	var b := _choice(p, needle)
	if b == null:
		_record(0, "reply", false, "no reply containing '%s'" % needle)
		return false
	b.pressed.emit()
	await create_timer(0.5).timeout
	return true
