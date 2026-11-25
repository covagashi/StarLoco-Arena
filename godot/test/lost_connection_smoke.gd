extends "res://test/world_smoke.gd"

## S53: the socket drops after login (Safari cuts it when the page goes to
## the background) — every screen says so and «Reconectar» goes back in.
##
##   godot/tools/seeded_smoke.sh lost_connection_smoke "[--shot-dir=D]"
##
## 1. In the lobby, the socket dies under the client (not a logout): the
##    "Se perdió la conexión" plate shows over everything, with Reconectar.
## 2. A logout (disconnect_from) shows nothing.
## 3. Reconectar (desktop: the login screen again) clears it.


func _audit() -> void:
	root.get_node("I18n").set_locale("es")
	_close_all()
	await create_timer(0.5).timeout
	_record(1, "logged in", State.my_coach_id > 0, "coach %d" % State.my_coach_id)
	# the socket dies under the client: the peer goes, _connected stays true
	var c = _sess.client
	if c._ws != null:
		c._ws.close()
	else:
		c._peer.disconnect_from_host()
	await _wait(func(): return root.has_node("LostConnection"), 5.0)
	await create_timer(0.6).timeout
	var lost = root.get_node_or_null("LostConnection")
	var btn: Button = lost.find_child("Reconnect", true, false) if lost != null else null
	_record(1, "says so", lost != null and btn != null and btn.visible,
		"the plate is up, with '%s'" % (btn.text if btn != null else "—"))
	await _shot("lost-connection")
	if btn == null:
		return
	btn.pressed.emit()
	await create_timer(1.5).timeout
	_record(3, "reconnect", not root.has_node("LostConnection")
		and current_scene != null and current_scene.scene_file_path == "res://src/main.tscn",
		"the plate is gone, main is back at the login")
	# 2. a logout says nothing
	State.my_coach_id = 7
	_sess.client._connected = true
	_sess.client.disconnect_from()
	await create_timer(1.0).timeout
	_record(2, "logout", not root.has_node("LostConnection"), "disconnect_from shows no plate")
	State.my_coach_id = -1
