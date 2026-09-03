extends "res://tools/test_harness.gd"
##
## The check document, both directions, with no network and no physics.
##
## The interesting part is the step total: the character contributes their own
## accumulated modifiers and the GM contributes difficulty, and the two are kept
## apart the whole way so the log can say what the GM added. A single merged
## number would be indistinguishable from a hero who happened to be encumbered.
##

const Check := preload("res://scripts/core/session/skill_check.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

var _rules


func _init() -> void:
	begin("skill check")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_skill_score_exposes_its_step()
	_test_player_request_flow()
	_test_gm_call_flow()
	_test_step_totals_pick_the_situation_die()
	_test_rulings_cannot_be_replayed()
	_test_unrollable_checks()
	_test_round_trip()
	_test_description()

	finish()


func _skill(skill_id: int) -> Dictionary:
	return _rules.get_skill_by_id(skill_id)


func _hero() -> Dictionary:
	var character := {}
	_rules.ensure_character_shape(character)
	return character


## The GM's steps have to be added to something, and the notation cannot be
## turned back into a number: action_step_die() caps below -5 and collapses
## everything past +7 into a count of d20s.
func _test_skill_score_exposes_its_step() -> void:
	var hero := _hero()
	var skill := _skill(1)
	var score: Dictionary = _rules.skill_score(hero, skill)

	check_true(score.has("step"), "skill_score reports the raw step total")
	check_eq(
		String(score.get("die", "")), _rules.action_step_die(AlternityNum.as_int(score.get("step", 0))),
		"and the die it reports is that step's die"
	)


# --- Player asks -----------------------------------------------------------

func _test_player_request_flow() -> void:
	var hero := _hero()
	var skill := _skill(1)
	var score: Dictionary = _rules.skill_score(hero, skill)
	var label: String = _rules.skill_label(skill)

	var check := Check.request("player-1", skill, score, label)
	check_eq(check.origin, Check.ORIGIN_PLAYER, "a player's check is player-originated")
	check_eq(check.state, Check.STATE_PENDING, "and starts waiting on the GM")
	check_false(check.check_id.is_empty(), "it has an id to answer against")
	check_eq(check.skill_label, label, "it carries the label, since the GM cannot resolve an id")
	check_eq(check.ordinary, AlternityNum.as_int(score.get("ordinary", 0)), "and the score to roll against")
	check_eq(check.player_step, AlternityNum.as_int(score.get("step", 0)), "and the character's own steps")
	check_eq(check.gm_step, 0, "with nothing from the GM yet")
	check_false(check.is_rollable(), "a pending check is not rollable")

	check_true(check.rule(2, "the ledge is wet"), "the GM rules on it")
	check_eq(check.state, Check.STATE_READY, "which makes it ready")
	check_eq(check.gm_step, 2, "the GM's steps are recorded")
	check_eq(check.reason, "the ledge is wet", "and so is why")
	check_eq(
		check.player_step, AlternityNum.as_int(score.get("step", 0)),
		"the GM's ruling does not disturb the character's own steps"
	)
	check_true(check.is_rollable(), "and now it can be rolled")

	# The two halves stay apart. Merged, a GM's +2 would be indistinguishable
	# from a hero who was encumbered, and the log could not say who made it hard.
	check_eq(check.total_step(), AlternityNum.as_int(score.get("step", 0)) + 2, "the total is both halves")

	var graded: Dictionary = _rules.resolve_check(7, 3, check.ordinary, _rules.action_step_die(check.total_step()))
	check.resolve(graded)
	check_eq(check.state, Check.STATE_RESOLVED, "resolving settles it")
	check_eq(check.degree(), String(graded.get("degree", "")), "and it reports the degree the rules gave")
	check_eq(check.is_success(), bool(graded.get("is_success", false)), "and whether that succeeded")


# --- GM asks ---------------------------------------------------------------

func _test_gm_call_flow() -> void:
	var called := Check.call_for("Awareness - Perception", 1, "the corridor is dark", 12)
	check_eq(called.origin, Check.ORIGIN_GM, "a called check is GM-originated")
	# Nothing to wait for: the GM set the step when they asked.
	check_eq(called.state, Check.STATE_READY, "and needs no ruling")
	check_eq(called.gm_step, 1, "carrying the GM's step")
	check_eq(called.skill_label, "Awareness - Perception", "and what to roll")
	check_eq(called.ordinary, 0, "but not a score, which the GM's device does not have")
	check_false(called.is_rollable(), "so it cannot be rolled until a device fills that in")

	# The player's device is the only one that can supply it -- it owns the
	# character. Same ownership rule as AP awards, seen from the other end.
	var hero := _hero()
	var score: Dictionary = _rules.skill_score(hero, _skill(1))
	check_true(called.accept(score), "the player's device supplies the score")
	check_eq(called.ordinary, AlternityNum.as_int(score.get("ordinary", 0)), "which lands on the check")
	check_eq(called.player_step, AlternityNum.as_int(score.get("step", 0)), "along with their own steps")
	check_true(called.is_rollable(), "and now it can be rolled")
	check_eq(called.total_step(), AlternityNum.as_int(score.get("step", 0)) + 1, "both halves again")

	# Declining is a real answer, and must not be rollable afterwards.
	var declined := Check.call_for("Athletics", 3)
	declined.cancel("busy elsewhere")
	check_eq(declined.state, Check.STATE_CANCELLED, "a player can decline")
	check_false(declined.is_rollable(), "and a declined check cannot be rolled")

	# A player's request cannot be answered by accept() -- that is the GM-called
	# path only, and mixing them would let a device set its own difficulty.
	var asked := Check.request("player-1", _skill(1), score, "Athletics")
	check_false(asked.accept(score), "accept() refuses a player-initiated check")


# --- The situation die -----------------------------------------------------

## The whole point of the round trip: the two step contributions decide which
## die gets thrown alongside the control d20.
func _test_step_totals_pick_the_situation_die() -> void:
	var cases := [
		[0, 0, "+d0"],
		[0, 1, "+d4"],
		[0, 2, "+d6"],
		[0, 3, "+d8"],
		[0, 4, "+d12"],
		[0, 5, "+d20"],
		[1, 1, "+d6"],
		[-1, 1, "+d0"],
		[-1, 0, "-d4"],
		[0, -2, "-d6"],
		[2, -2, "+d0"],
		[0, 6, "+2d20"],
	]
	for spec in cases:
		var check := Check.new("p", Check.ORIGIN_GM)
		check.player_step = spec[0]
		check.gm_step = spec[1]
		check_eq(
			_rules.action_step_die(check.total_step()), String(spec[2]),
			"player %+d and GM %+d throw %s" % [spec[0], spec[1], spec[2]]
		)

	# A GM cannot dial past what the ladder means. Beyond these the notation
	# stops describing a single die and the dial would be lying about the roll.
	var clamped := Check.request("p", {}, {}, "x")
	clamped.rule(99)
	check_eq(clamped.gm_step, Check.MAX_STEP, "a ruling above the ladder is clamped")
	var floored := Check.request("p", {}, {}, "x")
	floored.rule(-99)
	check_eq(floored.gm_step, Check.MIN_STEP, "and below it too")


func _test_rulings_cannot_be_replayed() -> void:
	var check := Check.request("p", _skill(1), _rules.skill_score(_hero(), _skill(1)), "Athletics")
	check_true(check.rule(2), "the first ruling lands")
	# A reliable transport can still deliver twice across a reconnect, and a
	# second ruling must not move a check that has already been rolled.
	check_false(check.rule(5), "a second ruling is refused")
	check_eq(check.gm_step, 2, "and the first one stands")

	check.resolve({"degree": "Ordinary", "is_success": true})
	check_false(check.rule(1), "a resolved check cannot be ruled on")
	check.cancel()
	check_eq(check.state, Check.STATE_RESOLVED, "and cannot be cancelled after the fact")


## A skill the hero cannot attempt has an ordinary score of zero. Rolling
## against zero is not a check -- it is a guaranteed failure dressed up as one.
func _test_unrollable_checks() -> void:
	var check := Check.request("p", {}, {"ordinary": 0, "step": 0}, "Something untrained")
	check.rule(0)
	check_eq(check.state, Check.STATE_READY, "it can still be ruled on")
	check_false(check.is_rollable(), "but a zero score is not rollable")

	var real := Check.request("p", {}, {"ordinary": 12, "step": 0}, "Athletics")
	real.rule(0)
	check_true(real.is_rollable(), "a real score is")


func _test_round_trip() -> void:
	var hero := _hero()
	var score: Dictionary = _rules.skill_score(hero, _skill(1))
	var check := Check.request("player-9", _skill(1), score, "Athletics - Climb")
	check.rule(2, "the ledge is wet")
	check.resolve(_rules.resolve_check(7, 3, check.ordinary, "+d6"))

	# Through JSON, the way it crosses the wire and lands in the log.
	var restored := Check.from_dict(JSON.parse_string(JSON.stringify(check.to_dict())))
	check_eq(restored.check_id, check.check_id, "the id survives")
	check_eq(restored.player_id, "player-9", "the roller survives")
	check_eq(restored.skill_label, "Athletics - Climb", "the label survives")
	check_eq(restored.ordinary, check.ordinary, "the score survives")
	check_eq(restored.player_step, check.player_step, "the character's steps survive")
	check_eq(restored.gm_step, 2, "the GM's steps survive separately")
	check_eq(restored.reason, "the ledge is wet", "the reason survives")
	check_eq(restored.state, Check.STATE_RESOLVED, "the state survives")
	check_eq(restored.degree(), check.degree(), "and so does the graded result")
	check_eq(restored.total_step(), check.total_step(), "the total is recomputed from both halves")

	var empty := Check.from_dict({})
	check_false(empty.check_id.is_empty(), "a malformed check still gets an id")
	check_eq(empty.ordinary, 0, "and no score")
	var junk := Check.from_dict({"result": "not a dictionary", "skill_id": "x"})
	check_eq(junk.result.size(), 0, "a malformed result is ignored")
	check_eq(junk.skill_id, -1, "and a malformed skill id falls back")


## Both feeds want the same sentence, so it is built once.
func _test_description() -> void:
	var harder := Check.call_for("Athletics - Climb", 2, "the ledge is wet")
	check_true(harder.describe().contains("Athletics - Climb"), "the description names the skill")
	check_true(harder.describe().contains("harder"), "and says the GM made it harder")
	check_true(harder.describe().contains("the ledge is wet"), "and gives the reason")

	var easier := Check.call_for("Athletics", -1, "")
	check_true(easier.describe().contains("easier"), "an easier check says so")
	check_true(easier.describe().contains("1 step"), "in steps, singular")

	var plain := Check.call_for("Awareness", 0)
	check_false(plain.describe().contains("step"), "an unmodified check mentions no steps")
	check_eq(plain.describe(), "Awareness", "and is just the skill")
