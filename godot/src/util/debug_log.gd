class_name DebugLog
extends RefCounted
## DebugLog — ring buffer for wire/internal diagnostics that must NOT reach
## the chat panel. Everything here also goes to stdout (the retail client's
## own log does the same) and is attached to bug reports as the `log` field.
##
## User-facing status lines still go to the chat via ChatBox._line; anything
## a player should not have to parse ("S2C opcode 23108", "combattre sent —",
## packet dumps) belongs here.

const MAX := 400
static var _lines: PackedStringArray = []


static func add(s: String) -> void:
	var stamp := "%02d:%02d:%02d" % [
		Time.get_time_dict_from_system().hour,
		Time.get_time_dict_from_system().minute,
		Time.get_time_dict_from_system().second]
	_lines.append("%s %s" % [stamp, s])
	if _lines.size() > MAX:
		_lines.remove_at(0)
	print("[arena] %s" % s)


## Last `n` lines, oldest first — what a bug report attaches.
static func tail(n := 120) -> String:
	var from := maxi(0, _lines.size() - n)
	return "\n".join(_lines.slice(from))
