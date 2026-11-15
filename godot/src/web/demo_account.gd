extends RefCounted
## The web demo's account (S44): a login and key this browser generates on
## its first JUGAR and keeps in user:// (the browser's storage), so a
## visitor comes back to the same coach. The server makes a demo account of
## any unknown "demo-" + 20 letters/digits login (limits.demo_accounts).
## Clearing the browser loses it; it is a demo.

const PATH := "user://demo_account.cfg"
const ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"


## {"login", "password"}, created and saved on first use.
static func load_or_create() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var login := str(cfg.get_value("demo", "login", ""))
		var password := str(cfg.get_value("demo", "password", ""))
		if login.length() == 25 and password != "":
			return {"login": login, "password": password}
	var c := Crypto.new()
	var login := "demo-"
	for b in c.generate_random_bytes(20):
		login += ALPHABET[b % ALPHABET.length()]
	var password := c.generate_random_bytes(16).hex_encode()
	cfg.set_value("demo", "login", login)
	cfg.set_value("demo", "password", password)
	cfg.save(PATH)
	return {"login": login, "password": password}


## A coach name to start the demo's creation screen with (the login is no
## name): three syllables and two digits, "Kozelra42". The player can change
## it; a taken one gets the usual "name taken" answer.
static func coach_name() -> String:
	const SYL := ["ba", "ko", "mi", "ra", "tu", "zel", "pip", "lo", "ne", "vo", "ri", "sa", "fen", "du"]
	var s := ""
	for i in 3:
		s += SYL[randi() % SYL.size()]
	return s.capitalize() + str(randi_range(10, 99))
