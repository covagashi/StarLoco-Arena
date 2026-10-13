extends Node
## Headless unit-test runner — the CI lane.
##
## Discovers every res://test/unit/*_test.gd by scanning the directory (no
## hardcoded preload list: suite files land independently of this runner),
## instantiates each with load(path).new(), and calls run(t) with one shared
## UnitAssert. No RenderingServer waits, no scene/viewport dependencies — the
## whole lane is safe under `--headless` on a machine that has never run the
## asset importer (assets/anims, assets/gamedata, assets/gui, ... stay
## untouched; only assets/i18n and assets/ui are tracked in git).

const AssertScript := preload("res://test/unit/assert.gd")

const SUITE_DIR := "res://test/unit/"
const SUITE_SUFFIX := "_test.gd"


func _ready() -> void:
	var t := AssertScript.new()
	var suite_paths := _discover_suites()
	for path in suite_paths:
		var suite_file := path.get_file()
		# A suite with a parse error used to reach .new() on a broken script,
		# which aborts _ready() BEFORE the quit() below — so the lane hung
		# forever instead of failing, and in CI that is a job timeout rather
		# than a red X. Validate before instantiating.
		var suite_script := load(path) as GDScript
		if suite_script == null or not suite_script.can_instantiate():
			t.checks += 1
			t.failures.append(
				"%s: script did not load (parse error?)" % suite_file)
			continue
		var instance: Object = suite_script.new()
		if instance == null:
			t.checks += 1
			t.failures.append("%s: could not instantiate" % suite_file)
		elif instance.has_method("run"):
			instance.run(t)
		else:
			t.checks += 1
			t.failures.append("%s: suite has no run(t) entry point" % suite_file)
	print("[unit] suites=%d checks=%d failures=%d" % [
		suite_paths.size(), t.checks, t.failures.size()])
	for f in t.failures:
		print("[unit] FAIL " + f)
	get_tree().quit(1 if t.failures.size() > 0 else 0)


## Scan res://test/unit/ for *_test.gd. Sorted so output order is stable
## across runs/machines regardless of filesystem directory order.
func _discover_suites() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(SUITE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(SUITE_SUFFIX):
			out.append(SUITE_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out
