extends "res://tools/test_harness.gd"
##
## Harness self-test fixture -- run by tools/run_tests.sh, which asserts this
## file's exit code. Not a project test; it is not matched by tools/smoke_*.gd.
##
## A hard crash after begin() must exit 1. begin() sets the exit code
## pessimistically so an aborted _init() cannot report success.
##
func _init() -> void:
	begin("selftest crash")
	check_eq(1, 1, "ok before crash")
	var d: Dictionary = {}
	var n: Node = d.get("missing")
	n.get_name()          # null deref -> aborts _init before finish()
	finish()
