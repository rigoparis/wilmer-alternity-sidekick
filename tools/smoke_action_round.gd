extends "res://tools/test_harness.gd"
##
## The action round: phases, ordering, and what being dropped costs you.
##
## Alternity's round is four passes down the table rather than one lap around it,
## and the two rules that make it work are easy to implement wrongly in ways that
## look fine:
##
##   * A combatant acts in the phase they rolled *and every phase after it*. Read
##     as "acts in their phase" instead, an Amazing roller would act once and a
##     Marginal roller would act once, and rolling well would buy nothing.
##   * Being taken out costs every action scheduled after that point. Without
##     that, dropping someone in the Amazing phase would still let them shoot
##     back in Ordinary.
##
## Also covers the rules-engine gaps this system needed: the firepower upgrade,
## the Amazing-damage knockout check, and the situation-die step table.
##

const Round := preload("res://scripts/core/session/action_round.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

var _rules


func _init() -> void:
	begin("action round")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_combatants()
	_test_checks_decide_the_phase()
	_test_acting_in_every_later_phase()
	_test_order_within_a_phase()
	_test_being_dropped_costs_later_phases()
	_test_phases_advance_once()
	_test_next_round()
	_test_round_trip()
	_test_situation_steps()
	_test_firepower_upgrade()
	_test_knockout_check()

	finish()


func _new_round() -> ActionRound:
	var combat := Round.new()
	combat.add_combatant("alice", "Alice", 2)
	combat.add_combatant("bob", "Bob", 1)
	combat.add_combatant("cy", "Cy", 3)
	return combat


# --- Combatants ------------------------------------------------------------

func _test_combatants() -> void:
	var combat := Round.new()
	check_true(combat.add_combatant("alice", "Alice", 2), "a combatant joins")
	check_false(combat.add_combatant("alice", "Alice again", 2), "and cannot join twice")
	check_true(combat.has_combatant("alice"), "they are in the round")
	check_eq(AlternityNum.as_int(combat.combatant("alice").get("actions", 0)), 2, "with their actions per round")
	check_eq(String(combat.combatant("alice").get("kind", "")), Round.KIND_PLAYER, "as a player by default")

	# The seam for GM-run combatants. Nothing builds them yet, but the round must
	# not have to change when something does.
	check_true(combat.add_combatant("thug", "Thug", 1, Round.KIND_NPC), "a GM-run combatant can join")
	check_eq(String(combat.combatant("thug").get("kind", "")), Round.KIND_NPC, "marked as one")

	check_true(combat.remove_combatant("thug"), "and can leave")
	check_false(combat.has_combatant("thug"), "leaving takes them out")
	check_false(combat.remove_combatant("nobody"), "removing a stranger fails")
	check_false(combat.add_combatant("", "Nameless"), "an id is required")


# --- Action checks ---------------------------------------------------------

func _test_checks_decide_the_phase() -> void:
	var combat := _new_round()
	check_false(combat.has_all_checks(), "nobody has rolled yet")
	check_eq(combat.awaiting_checks().size(), 3, "and all three are owed")
	check_false(combat.start(), "the round cannot start without them")

	check_true(combat.record_check("alice", "Amazing", 3), "an action check is recorded")
	check_eq(String(combat.combatant("alice").get("degree", "")), "amazing", "unlocking the Amazing phase")
	check_eq(combat.awaiting_checks().size(), 2, "two still owed")

	combat.record_check("bob", "Ordinary", 14)
	# A failure is not a missing result -- it puts you in Marginal, which is
	# where most of a bad round happens.
	combat.record_check("cy", "Failure", 19)
	check_eq(String(combat.combatant("cy").get("degree", "")), "marginal", "a failure lands in the Marginal phase")
	check_true(combat.has_all_checks(), "everyone has rolled")

	combat.record_check("bob", "Critical Failure", 20)
	check_eq(String(combat.combatant("bob").get("degree", "")), "marginal", "so does a critical failure")
	check_false(combat.record_check("nobody", "Amazing", 1), "recording for a stranger fails")


## The rule that makes rolling well worth something.
func _test_acting_in_every_later_phase() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 3)
	combat.record_check("bob", "Good", 7)
	combat.record_check("cy", "Marginal", 18)
	check_true(combat.start(), "the round starts")
	check_eq(combat.phase(), "amazing", "at the Amazing phase")

	var amazing := combat.acting_now()
	check_eq(amazing.size(), 1, "only the Amazing roller acts in the Amazing phase")
	check_eq(String(amazing[0]["id"]), "alice", "and it is Alice")

	# She does not act once. She acts in every phase from hers down, which is the
	# whole point of the structure.
	check_eq(combat.acting_in("good").size(), 2, "the Good phase holds Alice and Bob")
	check_eq(combat.acting_in("ordinary").size(), 2, "and so does Ordinary")
	check_eq(combat.acting_in("marginal").size(), 3, "Marginal holds everybody still standing")

	var ids: Array = []
	for entry in combat.acting_in("marginal"):
		ids.append(String(entry["id"]))
	check_true(ids.has("alice") and ids.has("bob") and ids.has("cy"), "all three of them")

	check_eq(combat.acting_in("nonsense").size(), 0, "an unknown phase holds nobody")


func _test_order_within_a_phase() -> void:
	var combat := _new_round()
	# All three in Marginal, with different totals.
	combat.record_check("alice", "Marginal", 12)
	combat.record_check("bob", "Marginal", 19)
	combat.record_check("cy", "Marginal", 15)
	combat.start()

	var order: Array = []
	for entry in combat.acting_in("marginal"):
		order.append(String(entry["id"]))
	# Higher action check first. The results still land together at the end of
	# the phase; this decides who declares against whom.
	check_eq(order, ["bob", "cy", "alice"], "the highest action check acts first inside a phase")


## Being dropped costs every action scheduled after it.
func _test_being_dropped_costs_later_phases() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 3)
	combat.record_check("bob", "Amazing", 4)
	combat.record_check("cy", "Ordinary", 11)
	combat.start()

	check_eq(combat.acting_in("marginal").size(), 3, "everyone is scheduled for Marginal to begin with")

	check_true(combat.knock_out("bob", "Amazing hit, failed the endurance check"), "Bob is taken out")
	check_true(combat.is_out("bob"), "and is out")
	check_false(combat.knock_out("bob"), "knocking out a downed combatant again does nothing")

	# The phases after the one he was dropped in are simply gone for him.
	for phase_id in ["amazing", "good", "ordinary", "marginal"]:
		var ids: Array = []
		for entry in combat.acting_in(phase_id):
			ids.append(String(entry["id"]))
		check_false(ids.has("bob"), "Bob does not act in the %s phase" % phase_id)

	check_eq(combat.standing().size(), 2, "two are still standing")
	check_eq(
		String(combat.combatant("bob").get("out_reason", "")),
		"Amazing hit, failed the endurance check",
		"and the round remembers why he is not"
	)

	check_true(combat.revive("bob"), "he can be brought back")
	check_false(combat.is_out("bob"), "and is standing again")
	check_eq(combat.acting_in("marginal").size(), 3, "back on the schedule")


func _test_phases_advance_once() -> void:
	var combat := _new_round()
	for id in ["alice", "bob", "cy"]:
		combat.record_check(id, "Ordinary", 10)
	combat.start()

	check_eq(combat.phase(), "amazing", "a round opens at Amazing")
	check_eq(combat.phase_name(), "Amazing", "and says so")
	check_eq(combat.acting_now().size(), 0, "with nobody in it, since nobody rolled that well")

	check_eq(combat.advance_phase(), "good", "then Good")
	check_eq(combat.advance_phase(), "ordinary", "then Ordinary")
	check_eq(combat.acting_now().size(), 3, "where all three act")
	check_eq(combat.advance_phase(), "marginal", "then Marginal")
	check_false(combat.is_finished(), "still running")

	check_eq(combat.advance_phase(), "", "and then the round is over")
	check_true(combat.is_finished(), "which it says")
	check_eq(combat.advance_phase(), "", "advancing past the end does nothing")


func _test_next_round() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 3)
	combat.record_check("bob", "Good", 8)
	combat.record_check("cy", "Marginal", 17)
	combat.start()
	combat.knock_out("cy", "unconscious")

	var following := combat.next_round()
	check_eq(following.number, 2, "the next round is numbered after this one")
	check_eq(following.combatants.size(), 3, "carrying everyone forward")
	check_eq(following.state, Round.STATE_ROLLING, "and starting over on action checks")
	check_false(following.has_all_checks(), "which nobody has rolled yet")
	check_eq(
		String(following.combatant("alice").get("degree", "")), "",
		"an Amazing roll does not carry over -- every round is rolled fresh"
	)
	check_eq(
		AlternityNum.as_int(following.combatant("alice").get("actions", 0)), 2,
		"but how many actions they get does"
	)
	# Coming back is something that happens to a character, and the GM says when.
	check_true(following.is_out("cy"), "whoever was down stays down")


func _test_round_trip() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 3)
	combat.record_check("bob", "Good", 8)
	combat.record_check("cy", "Ordinary", 12)
	combat.start()
	combat.advance_phase()
	combat.knock_out("cy", "down")

	# Through JSON, the way it reaches the players' devices.
	var restored := Round.from_dict(JSON.parse_string(JSON.stringify(combat.to_dict())))
	check_eq(restored.round_id, combat.round_id, "the id survives")
	check_eq(restored.number, combat.number, "the number survives")
	check_eq(restored.state, Round.STATE_ACTIVE, "the state survives")
	check_eq(restored.phase(), "good", "and the phase it is in")
	check_eq(restored.combatants.size(), 3, "every combatant survives")
	check_eq(String(restored.combatant("alice").get("degree", "")), "amazing", "with their phase")
	check_true(restored.is_out("cy"), "and who is down")
	check_eq(restored.acting_now().size(), 2, "so a player device works out the same schedule")

	var empty := Round.from_dict({})
	check_eq(empty.combatants.size(), 0, "a malformed round has no combatants")
	check_eq(empty.state, Round.STATE_ROLLING, "and has not started")


# --- The rules-engine gaps this needed -------------------------------------

## The step table from Player's Handbook p. 246.
func _test_situation_steps() -> void:
	check_eq(_rules.situation_step_for("extreme"), 3, "an Extreme situation is +3 steps")
	check_eq(_rules.situation_step_for("moderate"), 2, "Moderate is +2")
	check_eq(_rules.situation_step_for("slight"), 1, "Slight is +1")
	check_eq(_rules.situation_step_for("marginal"), 0, "Marginal is none")
	check_eq(_rules.situation_step_for("ordinary"), -1, "Ordinary is a -1 bonus")
	check_eq(_rules.situation_step_for("good"), -2, "Good is -2")
	check_eq(_rules.situation_step_for("amazing"), -3, "Amazing is -3")

	# The familiar combat rows are instances of those categories, not a second
	# rule: light cover is Slight, heavy cover is Extreme.
	check_eq(_rules.situation_step_for("cover_light"), 1, "light cover is +1")
	check_eq(_rules.situation_step_for("cover_heavy"), 3, "heavy cover is +3")
	check_eq(_rules.situation_step_for("light_none"), 3, "total darkness is +3")
	check_eq(_rules.situation_step_for("range_short"), -1, "short range is a -1 bonus")
	check_eq(_rules.situation_step_for("range_long"), 1, "long range is +1")

	# Figuring the odds is addition.
	check_eq(
		_rules.net_situation_steps(["range_long", "cover_light", "light_dim"]), 3,
		"modifiers net together"
	)
	check_eq(
		_rules.net_situation_steps(["range_short", "cover_light"]), 0,
		"and a bonus can cancel a penalty"
	)
	check_eq(_rules.net_situation_steps([]), 0, "nothing nets to nothing")

	# A category this build does not know is worth nothing rather than guessed.
	check_eq(_rules.situation_step_for("what_even_is_this"), 0, "an unknown situation adds nothing")

	# The netted total has to be a step the die chain can express.
	check_eq(_rules.action_step_die(_rules.net_situation_steps(["cover_heavy"])), "+d8", "+3 steps is +d8")
	check_eq(_rules.action_step_die(_rules.net_situation_steps(["range_short"])), "-d4", "-1 step is -d4")


## The half of the firepower rule that was never built.
func _test_firepower_upgrade() -> void:
	# One grade above: ordinary becomes good, good becomes amazing.
	check_eq(_rules.upgrade_damage_degree("ordinary", "G", "O"), "good", "one grade up promotes ordinary to good")
	check_eq(_rules.upgrade_damage_degree("good", "G", "O"), "amazing", "and good to amazing")
	check_eq(_rules.upgrade_damage_degree("amazing", "G", "O"), "amazing", "amazing is the ceiling")

	# Two grades above: everything is amazing.
	check_eq(_rules.upgrade_damage_degree("ordinary", "A", "O"), "amazing", "two grades up makes ordinary amazing")
	check_eq(_rules.upgrade_damage_degree("good", "A", "O"), "amazing", "and good amazing")

	# Equal or worse firepower changes nothing here -- that is the degradation
	# half's job, and it works on the damage track rather than the hit quality.
	check_eq(_rules.upgrade_damage_degree("ordinary", "O", "O"), "ordinary", "matched firepower promotes nothing")
	check_eq(_rules.upgrade_damage_degree("ordinary", "O", "A"), "ordinary", "and weaker firepower promotes nothing")
	check_eq(_rules.upgrade_damage_degree("nonsense", "A", "O"), "nonsense", "an unknown degree is left alone")

	# Gated on the same optional rule as degradation: a table not tracking
	# toughness should see neither effect.
	var plain := {}
	_rules.ensure_character_shape(plain)
	check_eq(
		_rules.character_upgraded_damage_degree(plain, "ordinary", "A", "O"), "ordinary",
		"with Firepower Scaling off, nothing is promoted"
	)
	_rules.set_optional_rule(plain, "firepower_scaling", true)
	check_eq(
		_rules.character_upgraded_damage_degree(plain, "ordinary", "A", "O"), "amazing",
		"and with it on, it is"
	)
	check_eq(
		_rules.character_upgraded_damage_degree(plain, "ordinary", "", ""), "ordinary",
		"an unrated weapon or target promotes nothing"
	)


func _test_knockout_check() -> void:
	var hero := {}
	_rules.ensure_character_shape(hero)

	var forced: Dictionary = _rules.amazing_damage_knockout(hero, "amazing")
	check_true(bool(forced.get("required", false)), "an Amazing hit forces an endurance check")
	check_eq(AlternityNum.as_int(forced.get("skill_id", -1)), 53, "against Stamina - Endurance")
	check_false(String(forced.get("reason", "")).is_empty(), "and says what is at stake")
	var score: Dictionary = forced.get("score", {})
	check_true(score.has("ordinary"), "carrying the hero's own score for it")
	check_eq(
		AlternityNum.as_int(score.get("ordinary", -1)),
		AlternityNum.as_int(_rules.skill_score(hero, _rules.get_skill_by_id(53)).get("ordinary", -2)),
		"which is the same score the sheet shows"
	)

	# Anything less than Amazing does not force it.
	for degree in ["ordinary", "good", "marginal", "failure"]:
		check_false(
			bool(_rules.amazing_damage_knockout(hero, degree).get("required", false)),
			"a %s hit forces no check" % degree
		)

	# Two exemptions.
	check_false(
		bool(_rules.amazing_damage_knockout(hero, "amazing", true).get("required", false)),
		"damage already degraded by firepower forces no check"
	)
	check_false(
		bool(_rules.amazing_damage_knockout(hero, "amazing", false, true).get("required", false)),
		"and heavy armor is immune"
	)
	check_true(
		String(_rules.amazing_damage_knockout(hero, "amazing", false, true).get("reason", "")).to_lower().contains("armor"),
		"which it says, since the GM is the one who told it so"
	)
