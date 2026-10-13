class_name UnitAssert
extends RefCounted
## Minimal assertion harness for the headless unit lane (res://test/unit/).
##
## unit_runner.gd hands ONE shared instance of this to every discovered
## suite's run(t) so all failures land in a single report at the end. Suite
## files duck-type `t` rather than preloading this script — see
## i18n_test.gd / direction8_test.gd.

var failures: PackedStringArray = []
var checks: int = 0
var _suite := ""


## Labels every failure recorded after this call as "<name>: ...". Call once
## at the top of a suite's run(t).
func suite(name: String) -> void:
	_suite = name


func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [_suite, what])


## Like ok(), but the failure message always carries both sides — a bare
## "not equal" is useless once this is three screens up in a log.
func eq(actual, expected, what: String) -> void:
	checks += 1
	if actual != expected:
		failures.append("%s: %s (actual=%s expected=%s)" % [_suite, what, actual, expected])
