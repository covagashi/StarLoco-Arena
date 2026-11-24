extends SceneTree

## S51 «Guardar mi progreso», live: the demo screens against a local server
## with demo_accounts on and auto_register off, in Spanish. One phase per
## run, each on its own user:// (XDG_DATA_HOME) — godot/tools/save_account_smoke.sh
## plays them in order:
##
##   claim   JUGAR makes a demo account and a coach; a won fight's report
##           (State.fight_result + _show_fight_result, the real path, not a
##           debug hook: winning a fight here would take minutes) is followed
##           by «¿Guardas tu progreso?»; «Más tarde» closes it and a second
##           win in the session does not ask again; Opciones offers «Guardar
##           mi progreso»; the form refuses two passwords that differ, then
##           saves; demo_account.cfg now holds the email + the demo key.
##   have    a fresh browser: «Ya tengo cuenta», a wrong password is refused,
##           the right one gets in and the file keeps a new device key.
##   jugar   the same browser again: JUGAR gets in with email + key.
##   reset   a fresh browser: «¿Olvidaste la contraseña?», the code from the
##           server log (dev mode mailer), a wrong code refused, the right one
##           sets the new password and gets in.
##   refused the "have" browser after the reset: its key was forgotten, so
##           JUGAR says to use «Ya tengo cuenta».
##
##   godot --path godot -s test/save_account_smoke.gd -- --demo-ui --phase=claim
##       --email=E --password=P [--new-password=N] [--server-log=F] [--shot-dir=D]
##       [--lang=es|en|fr]  (default es; other languages suffix the shots)
##
## Prints "[audit]" lines and exits 0 only if every check passed.

const State := preload("res://src/state.gd")
const DemoAccount := preload("res://src/web/demo_account.gd")

var _sess: Node
var _main
var _results: Array = []
var _phase := ""
var _email := ""
var _password := ""
var _new_password := ""
var _server_log := ""
var _shot_dir := ""
var _lang := "es"


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			_phase = a.trim_prefix("--phase=")
		elif a.begins_with("--email="):
			_email = a.trim_prefix("--email=")
		elif a.begins_with("--password="):
			_password = a.trim_prefix("--password=")
		elif a.begins_with("--new-password="):
			_new_password = a.trim_prefix("--new-password=")
		elif a.begins_with("--server-log="):
			_server_log = a.trim_prefix("--server-log=")
		elif a.begins_with("--lang="):
			_lang = a.trim_prefix("--lang=")
		elif a.begins_with("--shot-dir="):
			_shot_dir = a.trim_prefix("--shot-dir=")
	await process_frame
	root.get_node("I18n").set_locale(_lang)
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	if not await _wait(func(): return _main._login_screen != null, 10.0):
		_record("login screen", false, "never shown")
		_report()
		return
	_main._login_screen.set_proxies(["127.0.0.1:5555"], "127.0.0.1:5555")
	await create_timer(1.2).timeout   # the entrance cascade
	match _phase:
		"claim": await _claim()
		"have": await _have()
		"jugar": await _jugar()
		"reset": await _reset()
		"refused": await _refused()
		_: _record("phase", false, "unknown phase '%s'" % _phase)
	_report()


func _login():
	return _main._login_screen


func _press(node_name: String, under: Node = null) -> bool:
	var parent: Node = under if under != null else _login()
	var b = parent.find_child(node_name, true, false) if parent != null else null
	if b is BaseButton:
		b.pressed.emit()
		return true
	return false


func _lobby() -> bool:
	return await _wait(func(): return _main._lobby_screen != null and State.my_coach_id > 0, 20.0)


func _cfg() -> Dictionary:
	return DemoAccount.load_saved()


## --- claim ----------------------------------------------------------------
func _claim() -> void:
	_record("demo screen", _login().find_child("Play", true, false) != null
		and _login().find_child("HaveAccount", true, false) != null, "JUGAR and Ya tengo cuenta")
	await _shot("1_login_demo")
	_press("Play")
	var creating: bool = await _wait(func(): return _main._create_screen != null, 10.0)
	_record("demo account", creating, "JUGAR → coach creation")
	if not creating:
		return
	var demo: Dictionary = _cfg()
	await create_timer(0.5).timeout
	_main._create_screen.submit.emit()
	_record("lobby", await _lobby(), "coach '%s'" % State.my_coach_name)
	await _wait(func(): return State.account_demo, 5.0)
	_record("demo flag", State.account_demo, "60001 account_demo=1")
	await create_timer(1.0).timeout
	_close_all()
	# a won fight's debrief, as 8300 leaves it
	_win()
	var report: bool = await _wait(func(): return _main._gui.is_open("fightReportDialog"), 4.0)
	_record("report", report, "victory report open")
	_main._gui.dialogs["fightReportDialog"].closed.emit()
	var asked: bool = await _wait(func(): return _main._gui.is_open("saveAccountDialog"), 4.0)
	_record("ask after the win", asked, "«¿Guardas tu progreso?» after the report")
	await _shot("2_save_ask")
	var sheet = _main._gui.dialogs.get("saveAccountDialog")
	_press("Later", sheet)
	await create_timer(0.4).timeout
	_record("later", not _main._gui.is_open("saveAccountDialog"), "Más tarde closes it")
	_win()
	await _wait(func(): return _main._gui.is_open("fightReportDialog"), 4.0)
	_main._gui.dialogs["fightReportDialog"].closed.emit()
	await create_timer(1.0).timeout
	_record("once per session", not _main._gui.is_open("saveAccountDialog"), "a second win does not ask again")
	_close_all()
	_main._gui.open("optionsDialog")
	await _wait(func(): return _main._gui.is_open("optionsDialog"), 3.0)
	await create_timer(0.5).timeout
	var opts = _main._gui.dialogs.get("optionsDialog")
	var entry = opts.find_child("SaveProgress", true, false) if opts != null else null
	_record("options entry", entry != null, "Opciones → Guardar mi progreso")
	if entry != null:
		for sc in opts.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).ensure_control_visible(entry)
		await create_timer(0.3).timeout
		await _shot("3_options_entry")
		entry.pressed.emit()
	var form: bool = await _wait(func(): return _main._gui.is_open("saveAccountDialog") and str(_main._gui.model.get_value("saveAccount", "stage")) == "form", 3.0)
	_record("form", form, "the save form")
	sheet = _main._gui.dialogs.get("saveAccountDialog")
	if sheet == null:
		return
	await create_timer(0.5).timeout
	await _shot("4_save_form")
	_type(sheet, "Email", _email)
	_type(sheet, "Password", _password)
	_type(sheet, "Again", _password + "x")
	_press("Save", sheet)
	await create_timer(0.4).timeout
	var err = sheet.find_child("Error", true, false)
	_record("mismatch", err != null and err.text == root.get_node("I18n").t("save.err.mismatch"),
		"'%s'" % (err.text if err != null else "—"))
	await _shot("5_save_form_error")
	sheet = _main._gui.dialogs.get("saveAccountDialog")
	_type(sheet, "Again", _password)
	_press("Save", sheet)
	var done: bool = await _wait(func():
		return str(_main._gui.model.get_value("saveAccount", "stage")) == "done", 6.0)
	var now := _cfg()
	_record("saved", done and not State.account_demo, "60071 ok, the sheet says done")
	_record("file", bool(now.get("claimed", false)) and str(now.get("login")) == _email.to_lower()
		and str(now.get("password")) == str(demo.get("password")),
		"demo_account.cfg = %s / same demo key" % str(now.get("login")))
	await create_timer(0.6).timeout
	await _shot("6_save_done")


func _win() -> void:
	var me := int(State.my_coach_id)
	State.fight_result = {"win_str": {me: 1010}, "lose_str": {},
		"winners": [{"id": me}], "losers": [], "standing": 0, "reports": [], "won_cards": []}
	_main._show_fight_result()


func _type(panel: Node, node_name: String, text: String) -> void:
	var e = panel.find_child(node_name, true, false)
	if e is LineEdit:
		e.text = text
		e.text_changed.emit(text)


## --- have / jugar / reset / refused ---------------------------------------
func _have() -> void:
	_press("HaveAccount")
	await create_timer(0.5).timeout
	_record("have form", _login().account_mode() == "login", "«Ya tengo cuenta» form")
	await _shot("7_login_have")
	_type(_login(), "AcctEmail", _email)
	_type(_login(), "AcctPassword", "wrong-password")
	_press("AccountGo")
	var err_lbl = _login().find_child("AccountError", true, false)
	var refused: bool = await _wait(func(): return err_lbl.visible, 6.0)
	_record("wrong password", refused and err_lbl.text == root.get_node("I18n").t("login.bad_credentials"),
		"'%s'" % err_lbl.text)
	await _shot("8_login_have_error")
	# the server closes a refused socket: the next try reconnects
	await create_timer(1.0).timeout
	_type(_login(), "AcctPassword", _password)
	_press("AccountGo")
	_record("in with the password", await _lobby(), "email + password")
	var key: bool = await _wait(func():
		var c := _cfg()
		return bool(c.get("claimed", false)) and str(c.get("password", "")).length() == 32, 5.0)
	_record("device key", key and str(_cfg().get("login")) == _email.to_lower()
		and not State.account_demo, "60073 key kept, never the password")
	_record("no password kept", str(_cfg().get("password")) != _password, "the file holds the key")


func _jugar() -> void:
	_record("same browser", bool(_cfg().get("claimed", false)), "the file says saved")
	_press("Play")
	_record("JUGAR with the key", await _lobby() and not State.account_demo, "email + device key")


func _reset() -> void:
	_press("HaveAccount")
	await create_timer(0.3).timeout
	_press("Forgot")
	await create_timer(0.5).timeout
	_record("forgot form", _login().account_mode() == "forgot", "¿Olvidaste la contraseña?")
	_type(_login(), "AcctEmail", _email)
	await _shot("9_login_forgot")
	_press("AccountGo")
	var sent: bool = await _wait(func(): return _login().account_mode() == "reset", 6.0)
	_record("code sent", sent, "60075 → the code form")
	await create_timer(0.5).timeout
	await _shot("10_login_reset")
	var code := ""
	for i in 30:
		code = _code_from_log()
		if code != "":
			break
		await create_timer(0.2).timeout
	_record("code in the log", code.length() == 6, "dev mode mailer logged %s" % code)
	var wrong := "000000" if code != "000000" else "111111"
	_type(_login(), "AcctCode", wrong)
	_type(_login(), "AcctPassword", _new_password)
	_type(_login(), "AcctAgain", _new_password)
	_press("AccountGo")
	var err_lbl = _login().find_child("AccountError", true, false)
	var refused: bool = await _wait(func(): return err_lbl.visible, 6.0)
	_record("wrong code", refused and err_lbl.text == root.get_node("I18n").t("save.err.code"), "'%s'" % err_lbl.text)
	await _shot("11_login_reset_error")
	_type(_login(), "AcctCode", code)
	_press("AccountGo")
	_record("reset + in", await _lobby(), "new password, logged in")
	var key: bool = await _wait(func(): return str(_cfg().get("password", "")).length() == 32, 5.0)
	_record("device key after reset", key, "the file keeps a new key")


func _refused() -> void:
	_press("Play")
	var err_lbl = _login().err_lbl
	var refused: bool = await _wait(func(): return err_lbl.visible, 8.0)
	_record("old key refused", refused and err_lbl.text == root.get_node("I18n").t("login.saved_refused"),
		"'%s'" % err_lbl.text)
	await _shot("12_login_saved_refused")


func _code_from_log() -> String:
	if _server_log == "" or not FileAccess.file_exists(_server_log):
		return ""
	var code := ""
	for line in FileAccess.get_file_as_string(_server_log).split("\n"):
		if "password reset code NOT emailed" in line and ("to=" + _email.to_lower()) in line:
			var i := line.find("code=")
			if i >= 0:
				code = line.substr(i + 5, 6)
	return code


## --- helpers --------------------------------------------------------------
func _close_all() -> void:
	for n in _main._gui.dialogs.keys():
		_main._gui.close(n)


func _wait(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _shot(shot_name: String) -> void:
	if _shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.6).timeout
	var img := root.get_texture().get_image()
	if img != null:
		var suffix := "" if _lang == "es" else "_" + _lang
		img.save_png(_shot_dir.path_join(shot_name + suffix + ".png"))
		print("[audit] shot ", shot_name)


func _record(what: String, ok: bool, detail: String) -> void:
	_results.append([what, ok, detail])
	print("[audit] %s %s %s — %s" % [_phase, "OK  " if ok else "FAIL", what, detail])


func _report() -> void:
	var failed := _results.filter(func(r): return not r[1]).size()
	print("[audit] %s: %d checks, %d failed" % [_phase, _results.size(), failed])
	quit(1 if failed > 0 or _results.is_empty() else 0)
