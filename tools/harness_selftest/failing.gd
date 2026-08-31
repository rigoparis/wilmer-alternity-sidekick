extends "res://tools/test_harness.gd"
##
## Harness self-test fixture -- run by tools/run_tests.sh, which asserts this
## file's exit code. Not a project test; it is not matched by tools/smoke_*.gd.
##
## A failed assertion must exit 1 -- and must NOT stop later checks
## from running, so the suite reports every problem in one go.
##
func _init() -> void:
	begin("selftest fail")
	check_eq(2 + 2, 5, "deliberately wrong")
	check_eq(1, 1, "this still runs")
	finish()
