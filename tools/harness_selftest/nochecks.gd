extends "res://tools/test_harness.gd"
##
## Harness self-test fixture -- run by tools/run_tests.sh, which asserts this
## file's exit code. Not a project test; it is not matched by tools/smoke_*.gd.
##
## A suite that asserts nothing must exit 1. Silence is not success;
## this is what caught smoke_equipment_catalog having zero assertions.
##
func _init() -> void:
	begin("selftest no checks")
	finish()
