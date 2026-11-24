extends RefCounted
## The web demo's account (S44): a login and key this browser generates on
## its first JUGAR and keeps in user:// (the browser's storage), so a
## visitor comes back to the same coach. The server makes a demo account of
## any unknown "demo-" + 20 letters/digits login (limits.demo_accounts).
## Clearing the browser loses it; it is a demo.
##
## S51 («Guardar mi progreso»): once the player saves it with an email and a
## password, the file holds {login = the email, password = a device key,
## claimed = true}. The password itself is never stored: on itch.io every
## HTML5 game shares one origin, so another game could read it. The key is
## the demo's own key (the server keeps it as a device key on the claim) or
## one the server handed out after «Ya tengo cuenta» (60072 → 60073).

const PATH := "user://demo_account.cfg"
const ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"
const CP1252 := preload("res://src/net/cp1252.gd")


## {"login", "password", "claimed"}, created and saved on first use.
static func load_or_create() -> Dictionary:
	var acc := load_saved()
	if not acc.is_empty():
		return acc
	var c := Crypto.new()
	var login := "demo-"
	for b in c.generate_random_bytes(20):
		login += ALPHABET[b % ALPHABET.length()]
	var password := c.generate_random_bytes(16).hex_encode()
	_write(login, password, false)
	return {"login": login, "password": password, "claimed": false}


## What the file holds, or {} when there is nothing usable: a demo login is
## "demo-" + 20, a saved one an email.
static func load_saved() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {}
	var login := str(cfg.get_value("demo", "login", ""))
	var password := str(cfg.get_value("demo", "password", ""))
	var claimed := bool(cfg.get_value("demo", "claimed", false))
	if password == "":
		return {}
	if claimed and "@" in login:
		return {"login": login, "password": password, "claimed": true}
	if not claimed and login.length() == 25:
		return {"login": login, "password": password, "claimed": false}
	return {}


## After the demo account was saved under `email` (60071 ok) or the player
## logged in with «Ya tengo cuenta» and got `key` (60073): from now on JUGAR
## logs in with the email and this key.
static func save_claimed(email: String, key: String) -> void:
	_write(email.strip_edges().to_lower(), key, true)


static func is_claimed() -> bool:
	return bool(load_saved().get("claimed", false))


static func _write(login: String, password: String, claimed: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("demo", "login", login)
	cfg.set_value("demo", "password", password)
	cfg.set_value("demo", "claimed", claimed)
	cfg.save(PATH)


## The demo's screens (one JUGAR, «Ya tengo cuenta»): in the browser, or
## on the desktop with `-- --demo-ui` (the S51 smoke drives them there).
static func demo_ui() -> bool:
	return OS.has_feature("web") or OS.get_cmdline_user_args().has("--demo-ui")


## Client-side checks before sending (the server checks the same): "" when
## fine, else the i18n key of the error.
static func check_email(email: String) -> String:
	var e := email.strip_edges()
	var at := e.find("@")
	if e.length() < 6 or e.length() > 64 or at < 1 or e.count("@") != 1 or " " in e:
		return "save.err.email"
	var domain := e.substr(at + 1)
	if not "." in domain or domain.begins_with(".") or domain.ends_with("."):
		return "save.err.email"
	return ""


static func check_password(pw: String, again: String) -> String:
	if pw.to_utf8_buffer().size() < 8:
		return "save.err.weak"
	if pw.to_utf8_buffer().size() > 72:
		return "save.err.long"
	# the login (1025) sends it in the wire charset (cp1252): a character
	# that charset lacks would not survive the trip
	if CP1252.decode(CP1252.encode(pw)) != pw:
		return "save.err.chars"
	if pw != again:
		return "save.err.mismatch"
	return ""


## The wording of a server code (60071 / 60075 / 60077), an i18n key.
static func code_key(code: int) -> String:
	match code:
		1: return "save.err.not_demo"
		2: return "save.err.email"
		3: return "save.err.weak"
		4: return "save.err.taken"
		5: return "save.err.rate"
		6: return "save.err.code"
		7: return "save.err.expired"
	return "save.err.failed"


## A coach name to start the demo's creation screen with (the login is no
## name): three syllables and two digits, "Kozelra42". The player can change
## it; a taken one gets the usual "name taken" answer.
static func coach_name() -> String:
	const SYL := ["ba", "ko", "mi", "ra", "tu", "zel", "pip", "lo", "ne", "vo", "ri", "sa", "fen", "du"]
	var s := ""
	for i in 3:
		s += SYL[randi() % SYL.size()]
	return s.capitalize() + str(randi_range(10, 99))
