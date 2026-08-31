extends SceneTree
##
## Shared base for the headless smoke tests in tools/.
##
## Why this exists: the previous pattern was
##
##     func _fail(message: String) -> void:
##         push_error(message)
##         quit(1)
##
## which never failed a build. SceneTree.quit() only sets a flag and an exit
## code, then returns -- GDScript has no exceptions, so _init() carried on
## running every later assertion, and the script's closing quit(0) overwrote
## the 1. Every suite exited 0 even when assertions failed, and printed its
## "passed" line on the way out.
##
## The fix is twofold:
##   * begin() sets the exit code pessimistically to 1, so aborting anywhere
##     (including a hard crash) still reports failure.
##   * finish() is the single place that may lower it back to 0.
##
## Sync usage:
##     extends "res://tools/test_harness.gd"
##     func _init() -> void:
##         begin("species lookup")
##         check_eq(rules.get_species_by_id(1).get("id"), 1, "species 1 resolves")
##         finish()
##
## Async usage (needs the main loop, e.g. instantiating a scene):
##     func _init() -> void:
##         begin_async("mutation ui")
##         _run.call_deferred()
##     func _run() -> void:
##         await process_frame
##         check(...)
##         finish()
##

var _suite: String = "test"
var _failed: bool = false
var _checks: int = 0
var _finished: bool = false
var _async: bool = false
var _frames: int = 0
var _max_frames: int = 600


## Start a synchronous suite. Sets the exit code to 1 up front so that any
## abort before finish() -- assertion failure, crash, early return -- fails.
func begin(suite_name: String) -> void:
	_suite = suite_name
	print("[%s] running..." % _suite)
	quit(1)


## Start an asynchronous suite. Cannot pre-quit (that would tear the tree down
## before deferred work runs), so a frame watchdog stands in: if finish() is
## not reached within max_frames, the suite fails instead of hanging CI.
func begin_async(suite_name: String, max_frames: int = 600) -> void:
	_suite = suite_name
	_async = true
	_max_frames = max_frames
	print("[%s] running (async, max %d frames)..." % [_suite, _max_frames])
	process_frame.connect(_on_watchdog_frame)


func _on_watchdog_frame() -> void:
	if _finished:
		return
	_frames += 1
	if _frames > _max_frames:
		fail("timed out after %d frames without reaching finish()" % _max_frames)
		finish()


## Assert `condition`. Records the failure and continues -- a suite reports
## every problem in one run rather than only the first.
func check(condition: bool, message: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failed = true
	printerr("  FAIL [%s] %s" % [_suite, message])
	return false


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(
		actual == expected,
		"%s -- expected %s, got %s" % [message, _fmt(expected), _fmt(actual)]
	)


func check_ne(actual: Variant, unexpected: Variant, message: String) -> bool:
	return check(
		actual != unexpected,
		"%s -- expected anything but %s" % [message, _fmt(unexpected)]
	)


## Float comparison with a tolerance, for rule maths that goes through floats.
func check_approx(actual: float, expected: float, message: String, epsilon: float = 0.0001) -> bool:
	return check(
		absf(actual - expected) <= epsilon,
		"%s -- expected %f (+/-%f), got %f" % [message, expected, epsilon, actual]
	)


func check_true(condition: bool, message: String) -> bool:
	return check(condition, message)


func check_false(condition: bool, message: String) -> bool:
	return check(not condition, message)


## Record an unconditional failure.
func fail(message: String) -> void:
	check(false, message)


## The only place the exit code may be lowered to 0. Call last.
func finish() -> void:
	if _finished:
		return
	_finished = true
	if _failed:
		printerr("[%s] FAILED (%d checks)" % [_suite, _checks])
		quit(1)
		return
	if _checks == 0:
		printerr("[%s] FAILED -- suite ran no checks" % _suite)
		quit(1)
		return
	print("[%s] passed (%d checks)" % [_suite, _checks])
	quit(0)


func _fmt(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % value
	return str(value)
