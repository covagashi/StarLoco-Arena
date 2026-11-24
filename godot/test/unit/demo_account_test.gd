extends RefCounted
## S51 «Guardar mi progreso»: the browser's account file (demo, then saved
## with email + device key), the client-side checks, the wording of the
## server's codes, and the save sheet's three steps.

const DemoAccount := preload("res://src/web/demo_account.gd")


func run(t) -> void:
	t.suite("demo_account")
	var backup := FileAccess.get_file_as_bytes(DemoAccount.PATH) if FileAccess.file_exists(DemoAccount.PATH) else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DemoAccount.PATH))

	var a := DemoAccount.load_or_create()
	t.ok(str(a.login).begins_with("demo-") and str(a.login).length() == 25, "a demo login is made")
	t.eq(str(a.password).length(), 32, "with a 128-bit key")
	t.eq(bool(a.claimed), false, "not saved yet")
	t.eq(DemoAccount.load_or_create().login, a.login, "the same browser keeps it")
	DemoAccount.save_claimed(" Ana@Example.com ", str(a.password))
	var b := DemoAccount.load_or_create()
	t.eq(b.login, "ana@example.com", "saved: the login is the lower-cased email")
	t.eq(b.password, a.password, "and the demo key stays as the device key")
	t.eq(bool(b.claimed), true, "flagged saved")
	t.ok(DemoAccount.is_claimed(), "is_claimed")
	# a saved file whose login is no email is not used
	var cfg := ConfigFile.new()
	cfg.set_value("demo", "login", "plainname")
	cfg.set_value("demo", "password", "x")
	cfg.set_value("demo", "claimed", true)
	cfg.save(DemoAccount.PATH)
	t.eq(DemoAccount.load_saved(), {}, "a broken saved file is ignored")

	t.eq(DemoAccount.check_email("ana@example.com"), "", "a good email")
	for bad in ["", "ana", "ana@x", "@x.com", "a b@x.com", "a@@x.com", "ana@x.com."]:
		t.eq(DemoAccount.check_email(bad), "save.err.email", "bad email '%s'" % bad)
	t.eq(DemoAccount.check_password("secret12", "secret12"), "", "a good password")
	t.eq(DemoAccount.check_password("short", "short"), "save.err.weak", "under 8")
	t.eq(DemoAccount.check_password("secret12", "secret13"), "save.err.mismatch", "the repeat differs")
	t.eq(DemoAccount.check_password("secret12😀", "secret12😀"), "save.err.chars", "outside the wire charset")
	t.eq(DemoAccount.check_password("contraseña", "contraseña"), "", "ñ travels in cp1252")
	for code in [1, 2, 3, 4, 5, 6, 7, 8, 99]:
		var key := DemoAccount.code_key(code)
		for lang in ["es", "en", "fr"]:
			var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/i18n/ui_%s.json" % lang))
			t.ok(table.has(key), "code %d worded in %s (%s)" % [code, lang, key])

	_panel(t)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(DemoAccount.PATH))
	if not backup.is_empty():
		var f := FileAccess.open(DemoAccount.PATH, FileAccess.WRITE)
		f.store_buffer(backup)


## The sheet builds each step with its controls, and the form answers
## "nativeSaveSubmit" with what was typed.
func _panel(t) -> void:
	var host: Node = Engine.get_main_loop().root.get_node("I18n")
	var model := GuiModel.new()
	model.set_value("saveAccount", {"demo": true, "stage": "ask", "error": "", "busy": false})
	var panel = preload("res://src/ui/save_account_panel.gd").new()
	panel.model = model
	var got := []
	panel.requested.connect(func(ev, args, _i, _n): got.append([ev, args]))
	host.add_child(panel)
	panel.refresh()
	t.ok(panel.find_child("Now", true, false) != null and panel.find_child("Later", true, false) != null,
		"ask: Ahora / Más tarde")
	(panel.find_child("Later", true, false) as Button).pressed.emit()
	t.eq(got.back()[0] if not got.is_empty() else "", "nativeSaveLater", "Más tarde answers")
	model.set_value("saveAccount", "form", "stage")
	panel.refresh()
	var email: LineEdit = panel.find_child("Email", true, false)
	t.ok(email != null and panel.find_child("Password", true, false) != null
		and panel.find_child("Again", true, false) != null, "form: three fields")
	if email != null:
		email.text = "ana@example.com"
		email.text_changed.emit(email.text)
		var pw: LineEdit = panel.find_child("Password", true, false)
		pw.text = "secret12"
		pw.text_changed.emit(pw.text)
		t.ok(pw.secret, "the password is hidden")
		(panel.find_child("Save", true, false) as Button).pressed.emit()
		t.eq(got.back(), ["nativeSaveSubmit", ["ana@example.com", "secret12", ""]], "Guardar sends what was typed")
	model.set_value("saveAccount", "save.err.taken", "error")
	panel.refresh()
	var err: Label = panel.find_child("Error", true, false)
	t.ok(err != null and err.text == host.t("save.err.taken"), "the server's error is shown")
	model.set_value("saveAccount", {"demo": false, "stage": "done", "email": "ana@example.com"})
	panel.refresh()
	var who: Label = panel.find_child("Email", true, false)
	t.ok(who != null and who.text == "ana@example.com" and panel.find_child("Ok", true, false) != null,
		"done: the email and Vale")
	panel.queue_free()
