extends "res://tools/test_harness.gd"
##
## Harness self-test fixture -- run by tools/run_tests.sh, which asserts this
## file's exit code. Not a project test; it is not matched by tools/smoke_*.gd.
##
## A passing suite must exit 0.
##
func _init() -> void:
	begin("selftest pass")
	check_eq(2 + 2, 4, "arithmetic")
	finish()
