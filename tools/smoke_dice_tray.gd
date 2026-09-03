extends "res://tools/test_harness.gd"
##
## The tray, with real physics, headless.
##
## The two remaining hard parts from AGENTS.md: that a throw always settles, and
## that it always produces a result. Both are properties of the simulation rather
## than of the geometry, so they cannot be checked the way DieShape was -- these
## dice are actually thrown and actually collide.
##
## What this deliberately does not assert is any particular number. The outcome
## comes from where the dice stop, and an assertion about which face that is
## would either be vacuous or a demand for determinism that AGENTS.md says must
## never be relied on. What is asserted is that every result is a face the die
## has, that a throw terminates, and that the tray is not quietly returning the
## same number every time.
##

const Tray := preload("res://scripts/core/dice/dice_tray.gd")
const Source := preload("res://scripts/core/dice/physical_dice_source.gd")
const Notation := preload("res://scripts/core/dice/dice_notation.gd")

var _tray


func _init() -> void:
	# Generous: each throw is a second or two of real physics, and there are a
	# dozen of them. The watchdog is here to catch a hang, not to pace the suite.
	begin_async("dice tray", 20000)
	_run.call_deferred()


func _run() -> void:
	_tray = Tray.new()
	_tray.configure(ThemePalette.new())
	root.add_child(_tray)
	await process_frame

	await _test_nothing_to_throw()
	await _test_single_die_settles()
	await _test_every_shape_reads_in_range()
	await _test_a_throw_uses_the_whole_range()
	await _test_group_throw()
	await _test_source_builds_results()

	_tray.queue_free()
	finish()


## Throw and wait. Returns [faces, rerolls], or [] if the tray refused.
func _throw(sides_list: Array) -> Array:
	if not _tray.throw(sides_list):
		return []
	return await _tray.settled


# --- The empty case --------------------------------------------------------

## "+d0" is real notation in this game's data, meaning no die at all. The tray
## must refuse rather than emit a settle nobody can await.
func _test_nothing_to_throw() -> void:
	check_false(_tray.throw([]), "an empty throw is refused")
	check_false(_tray.throw([0]), "a d0 is refused")
	check_false(_tray.throw([10]), "a shape this build cannot make is refused")
	check_false(_tray.is_rolling(), "and none of that leaves the tray rolling")


# --- Settling --------------------------------------------------------------

func _test_single_die_settles() -> void:
	var outcome := await _throw([6])
	check_eq(outcome.size(), 2, "a throw reports faces and rerolls")
	if outcome.size() != 2:
		return

	var faces: Array = outcome[0]
	check_eq(faces.size(), 1, "one die was thrown")
	check_eq(AlternityNum.as_int(faces[0]["sides"]), 6, "and it was a d6")
	var number := AlternityNum.as_int(faces[0]["number"])
	check_true(number >= 1 and number <= 6, "it settled on a face a d6 has -- got %d" % number)
	check_false(_tray.is_rolling(), "and the tray is no longer rolling")

	# A cocked die voids the whole throw, up to a cap. However unlucky, the
	# count cannot exceed it -- that cap is what stops the policy recursing.
	var rerolls := AlternityNum.as_int(outcome[1])
	check_true(rerolls >= 0, "rerolls are counted")
	check_true(rerolls < Tray.MAX_ATTEMPTS, "and cannot exceed the attempt cap")

	# The die came to rest rather than being read at the timeout. This is the
	# assertion that the first version of this tray would have failed while
	# passing everything else: its dice fell through the floor and every result
	# was read off one still accelerating downwards.
	check_false(_tray.was_forced(), "the throw settled rather than running out of time")
	check_true(
		_tray.last_attempt_seconds() < Tray.ATTEMPT_TIMEOUT,
		"and did so inside the timeout -- took %.1fs" % _tray.last_attempt_seconds()
	)


## Every shape, including the d4 -- the one with no up-face, read by its apex.
func _test_every_shape_reads_in_range() -> void:
	for sides in [4, 6, 8, 12, 20]:
		var outcome := await _throw([sides])
		if not check(outcome.size() == 2, "a d%d throw settles" % sides):
			continue
		var faces: Array = outcome[0]
		var number := AlternityNum.as_int(faces[0]["number"])
		check_true(
			number >= 1 and number <= sides,
			"a d%d settled on a face it has -- got %d" % [sides, number]
		)
		# Whatever it landed on, the tray had to be able to read it. A result
		# still flagged cocked means the forced path produced it, which is
		# legitimate but should not be the common case for a single die.
		check_true(faces[0].has("cocked"), "and the reading says whether it was clean")
		check_false(_tray.was_forced(), "a d%d settles rather than timing out" % sides)
		# A die at rest on the tray floor, not one still falling.
		check_true(
			_tray._bodies[0].position.y > 0.0 and _tray._bodies[0].position.y < Tray.WALL_HEIGHT,
			"and it came to rest inside the tray"
		)


## The tray must not be quietly returning one number.
##
## Not a statistical test -- that would be flaky by construction. This asks only
## that several throws of the same die are not all identical, which a stuck
## reading or a die that never really tumbles would fail.
func _test_a_throw_uses_the_whole_range() -> void:
	var seen := {}
	for _i in 6:
		var outcome := await _throw([20])
		if outcome.size() == 2:
			seen[AlternityNum.as_int(outcome[0][0]["number"])] = true
	check_true(seen.size() > 1, "six d20 throws produced more than one number -- got %d distinct" % seen.size())


# --- Several dice at once --------------------------------------------------

## An action check is one throw with two dice in it, not two throws. They
## collide with each other on the way down, and that is part of the outcome.
func _test_group_throw() -> void:
	var outcome := await _throw([20, 6])
	if not check(outcome.size() == 2, "a two-die throw settles"):
		return
	var faces: Array = outcome[0]
	check_eq(faces.size(), 2, "both dice reported")
	check_eq(AlternityNum.as_int(faces[0]["sides"]), 20, "the control die is first")
	check_eq(AlternityNum.as_int(faces[1]["sides"]), 6, "the situation die second")
	check_true(AlternityNum.as_int(faces[0]["number"]) <= 20, "the d20 is in range")
	check_true(AlternityNum.as_int(faces[1]["number"]) <= 6, "and so is the d6")


# --- Through the RandomSource seam -----------------------------------------

func _test_source_builds_results() -> void:
	var source = Source.new(_tray)

	var damage: RollResult = await source.roll(Notation.parse("d6+2w"), "Pistol")
	check_eq(damage.notation, "d6+2w", "the notation is preserved")
	check_eq(damage.damage_type, "w", "and the damage type")
	check_eq(damage.label, "Pistol", "and the label")
	check_eq(damage.source, RollResult.SOURCE_PHYSICAL, "the result knows it came off the tray")
	# Never reproducible, and saying so is the point: a seed here would invite
	# somebody to try replaying a roll that collisions decided.
	check_eq(damage.seed_used, -1, "and records no seed")
	check_eq(damage.dice.size(), 1, "one die was thrown")
	check_eq(damage.total, damage.dice[0] + 2, "the modifier is applied to what the die showed")

	# An action check: control d20 and the situation die, thrown together.
	var group: Array = await source.roll_group([Notation.parse("d20"), Notation.parse("+d6")], "Athletics")
	check_eq(group.size(), 2, "a group throw returns one result per term")
	if group.size() != 2:
		return
	var control: RollResult = group[0]
	var situation: RollResult = group[1]
	check_eq(control.dice.size(), 1, "the control die is one d20")
	check_true(control.total >= 1 and control.total <= 20, "in range")
	check_eq(situation.dice.size(), 1, "the situation die is one d6")
	check_eq(situation.sign, 1, "added rather than subtracted")
	check_eq(control.rerolls, situation.rerolls, "both share the throw's reroll count")

	# A subtracted situation die is a real case -- a step bonus makes a check
	# easier by taking the die away from the total.
	var easier: Array = await source.roll_group([Notation.parse("d20"), Notation.parse("-d4")], "Easy")
	if check_eq(easier.size(), 2, "a negative situation die resolves"):
		var minus: RollResult = easier[1]
		check_eq(minus.sign, -1, "and is signed negative")
		check_true(minus.total <= 0, "so it subtracts from the check -- got %d" % minus.total)

	# "+d0" throws nothing at all and still has to resolve.
	var nothing: Array = await source.roll_group([Notation.parse("+d0")], "None")
	check_eq(nothing.size(), 1, "a d0 term still returns a result")
	check_eq(nothing[0].dice.size(), 0, "with no dice")
	check_eq(nothing[0].total, 0, "and no contribution")
