extends "res://tools/test_harness.gd"
##
## AlternityNum is reached from roughly 480 call sites and is the only thing
## standing between stored-JSON type drift and the rules maths, so its edges are
## worth pinning directly rather than only through the golden snapshots.
##

const Num := preload("res://scripts/core/num.gd")


func _init() -> void:
	begin("numeric coercion")

	# Passthrough.
	check_eq(Num.as_int(7), 7, "as_int(int)")
	check_eq(Num.as_int(0), 0, "as_int(0)")
	check_eq(Num.as_int(-3), -3, "as_int(negative int)")

	# Floats truncate toward zero. Real saves store ints as floats (5.0), which
	# is the case that matters most here.
	check_eq(Num.as_int(5.0), 5, "as_int(integral float) - the stored-JSON case")
	check_eq(Num.as_int(5.9), 5, "as_int(float) truncates, not rounds")
	check_eq(Num.as_int(-5.9), -5, "as_int(negative float) truncates toward zero")

	# Numeric strings, in both integer and decimal form.
	check_eq(Num.as_int("42"), 42, "as_int(int string)")
	check_eq(Num.as_int("-42"), -42, "as_int(negative int string)")
	check_eq(Num.as_int("5.9"), 5, "as_int(float string) truncates")

	# Anything uncoercible yields the default.
	check_eq(Num.as_int(null), 0, "as_int(null) -> default")
	check_eq(Num.as_int("twenty"), 0, "as_int(non-numeric string) -> default")
	check_eq(Num.as_int(""), 0, "as_int(empty string) -> default")
	check_eq(Num.as_int({}), 0, "as_int(Dictionary) -> default")
	check_eq(Num.as_int([]), 0, "as_int(Array) -> default")

	# Custom defaults are honoured on every failure path.
	check_eq(Num.as_int(null, 10), 10, "as_int(null, 10) -> 10")
	check_eq(Num.as_int("nope", -1), -1, "as_int(bad string, -1) -> -1")
	check_eq(Num.as_int(3, 10), 3, "custom default is ignored when coercion works")

	# as_float mirrors as_int, without truncating.
	check_approx(Num.as_float(7), 7.0, "as_float(int)")
	check_approx(Num.as_float(5.9), 5.9, "as_float(float) keeps precision")
	check_approx(Num.as_float("5.9"), 5.9, "as_float(float string)")
	check_approx(Num.as_float("42"), 42.0, "as_float(int string)")
	check_approx(Num.as_float(null), 0.0, "as_float(null) -> default")
	check_approx(Num.as_float("twenty"), 0.0, "as_float(non-numeric string) -> default")
	check_approx(Num.as_float({}), 0.0, "as_float(Dictionary) -> default")
	check_approx(Num.as_float(null, 2.5), 2.5, "as_float(null, 2.5) -> 2.5")

	finish()
