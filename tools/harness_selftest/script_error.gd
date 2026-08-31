extends "res://tools/test_harness.gd"
##
## Harness self-test fixture -- run by tools/run_tests.sh, which asserts this
## file's behaviour. Not a project test; it is not matched by tools/smoke_*.gd.
##
## A GDScript runtime error does not always abort the whole call stack. An
## invalid call aborts only the enclosing function, so _init() carries on and
## reaches finish(), which reports success -- the exit code cannot see that the
## suite was broken. This fixture reproduces that exact shape (it was hit for
## real by tools/make_fixtures.gd calling equipment_has_combat_role with the
## wrong arity), so run_tests.sh must fail it on the SCRIPT ERROR in its output
## rather than on its exit code, which is 0.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("selftest script error")
	check_eq(1, 1, "a check that passes before the bad call")
	_bad_call()
	finish()


func _bad_call() -> void:
	# Typed as Variant so the parser cannot check the call and the arity error
	# surfaces at runtime instead. This mirrors the real case, where the rules
	# handle was an untyped var and the sub-module call dispatched dynamically.
	var rules: Variant = RulesScript.new()
	rules.ensure_character_shape()
