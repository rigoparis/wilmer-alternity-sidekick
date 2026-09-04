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
	_test_actions_run_out()
	_test_the_gm_controls_the_actions()
	_test_dodging()
	_test_being_dropped_costs_later_phases()
	_test_phases_advance_once()
	_test_next_round()
	_test_round_trip()
	_test_situation_steps()
	_test_range_bands()
	_test_promotion()
	_test_firepower_upgrade()
	_test_knockout_check()

	finish()


## Three combatants with enough actions to reach every phase, so a test that is
## not about the action limit is not silently constrained by it.
func _new_round() -> ActionRound:
	var combat := Round.new()
	combat.add_combatant("alice", "Alice", 4)
	combat.add_combatant("bob", "Bob", 4)
	combat.add_combatant("cy", "Cy", 4)
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

	check_true(combat.record_check("alice", "Amazing", 14, 3), "an action check is recorded")
	check_eq(String(combat.combatant("alice").get("degree", "")), "amazing", "unlocking the Amazing phase")
	check_eq(combat.awaiting_checks().size(), 2, "two still owed")

	combat.record_check("bob", "Ordinary", 12, 14)
	# A failure is not a missing result -- it puts you in Marginal, which is
	# where most of a bad round happens.
	combat.record_check("cy", "Failure", 11, 19)
	check_eq(String(combat.combatant("cy").get("degree", "")), "marginal", "a failure lands in the Marginal phase")
	check_true(combat.has_all_checks(), "everyone has rolled")

	combat.record_check("bob", "Critical Failure", 12, 20)
	check_eq(String(combat.combatant("bob").get("degree", "")), "marginal", "so does a critical failure")
	check_true(bool(combat.combatant("bob").get("critical", false)), "and is remembered as critical")
	check_false(combat.record_check("nobody", "Amazing", 1), "recording for a stranger fails")

	# The score and the roll are different things and only one of them orders a
	# phase. Storing one in place of the other is how ordering ends up backwards.
	check_eq(AlternityNum.as_int(combat.combatant("alice").get("check_score", 0)), 14, "the character's score is kept")
	check_eq(AlternityNum.as_int(combat.combatant("alice").get("roll", 0)), 3, "and what they rolled, separately")


## The rule that makes rolling well worth something.
func _test_acting_in_every_later_phase() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 14, 3)
	combat.record_check("bob", "Good", 12, 7)
	combat.record_check("cy", "Marginal", 11, 18)
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


## Order inside a phase is by the character's own action check score, not by
## what they rolled.
##
## This was implemented backwards to begin with. Alternity is roll-under, so
## sorting by the die put the worst rollers first; Player's Handbook p. 50 orders
## ties "in order of their action check scores -- highest score first".
func _test_order_within_a_phase() -> void:
	var combat := _new_round()
	# All three in Marginal. Scores and rolls deliberately run opposite ways, so
	# sorting by the wrong one gives the wrong answer rather than the same one.
	combat.record_check("alice", "Marginal", 9, 18)
	combat.record_check("bob", "Marginal", 15, 12)
	combat.record_check("cy", "Marginal", 12, 15)
	combat.start()

	var order: Array = []
	for entry in combat.acting_in("marginal"):
		order.append(String(entry["id"]))
	check_eq(order, ["bob", "cy", "alice"], "the highest action check score acts first")

	# A critical failure goes last in Marginal however good their score is.
	var fumbled := _new_round()
	fumbled.record_check("alice", "Marginal", 9, 18)
	fumbled.record_check("bob", "Critical Failure", 20, 20)
	fumbled.record_check("cy", "Marginal", 12, 15)
	fumbled.start()
	var fumbled_order: Array = []
	for entry in fumbled.acting_in("marginal"):
		fumbled_order.append(String(entry["id"]))
	check_eq(
		fumbled_order, ["cy", "alice", "bob"],
		"a critical failure goes last, behind even a lower score"
	)


## One action per phase, and only as many as the character has.
##
## A character with three actions who rolled Amazing acts in Amazing, Good and
## Ordinary, and is finished before Marginal. Without this every combatant would
## act in every phase from theirs down, and actions per round would mean nothing.
func _test_actions_run_out() -> void:
	var combat := Round.new()
	combat.add_combatant("swift", "Swift", 3)
	combat.add_combatant("slow", "Slow", 1)
	combat.record_check("swift", "Amazing", 14, 3)
	combat.record_check("slow", "Amazing", 12, 4)
	combat.start()

	for phase_id in ["amazing", "good", "ordinary"]:
		var ids: Array = []
		for entry in combat.acting_in(phase_id):
			ids.append(String(entry["id"]))
		check_true(ids.has("swift"), "three actions reach the %s phase" % phase_id)

	var marginal: Array = []
	for entry in combat.acting_in("marginal"):
		marginal.append(String(entry["id"]))
	check_false(marginal.has("swift"), "but not the Marginal phase, having spent all three")

	# One action means one phase, however well they rolled.
	check_eq(combat.acting_in("amazing").size(), 2, "both act in the phase they earned")
	var good: Array = []
	for entry in combat.acting_in("good"):
		good.append(String(entry["id"]))
	check_false(good.has("slow"), "a single action is spent in the first phase and gone")

	# Actions are counted from the phase earned, not from the top of the round:
	# a one-action combatant who rolled Marginal still gets their action there.
	var late := Round.new()
	late.add_combatant("last", "Last", 1)
	late.record_check("last", "Marginal", 10, 17)
	late.start()
	check_eq(late.acting_in("amazing").size(), 0, "they do not act early")
	check_eq(late.acting_in("marginal").size(), 1, "but they do act in their own phase")


## The GM's dial on how many actions somebody gets.
##
## No model can know everything that costs an action, so the number is editable
## rather than derived once and defended. What it must not do is drift: an action
## taken away for being stunned is a one-round thing, and the next round starts
## from what the character's own numbers allow.
func _test_the_gm_controls_the_actions() -> void:
	var combat := Round.new()
	combat.add_combatant("hero", "Hero", 3)
	combat.record_check("hero", "Amazing", 14, 3)
	combat.start()
	check_eq(combat.actions_of("hero"), 3, "a combatant starts with what their sheet allows")
	check_eq(combat.acting_in("ordinary").size(), 1, "which reaches the Ordinary phase")

	check_true(combat.adjust_actions("hero", -1), "the GM can take one away")
	check_eq(combat.actions_of("hero"), 2, "leaving two")
	check_eq(combat.acting_in("good").size(), 1, "they still act in Good")
	check_eq(combat.acting_in("ordinary").size(), 0, "but no longer in Ordinary")

	check_true(combat.adjust_actions("hero", 1), "and can give it back")
	check_eq(combat.acting_in("ordinary").size(), 1, "which returns the phase")

	check_true(combat.set_actions("hero", 5), "and can hand out more than the sheet allows")
	check_eq(combat.acting_in("marginal").size(), 1, "reaching every phase")

	# Zero is a real answer: somebody who does nothing this round.
	check_true(combat.set_actions("hero", 0), "the GM can take them all")
	for phase_id in Round.PHASES:
		check_eq(combat.acting_in(phase_id).size(), 0, "which leaves them acting in no phase (%s)" % phase_id)
	check_eq(combat.set_actions("hero", -4), true, "and cannot go below nothing")
	check_eq(combat.actions_of("hero"), 0, "so it stops at zero")

	check_false(combat.set_actions("nobody", 2), "a combatant who is not there cannot be adjusted")
	check_false(combat.adjust_actions("nobody", 1), "in either direction")

	# The next round starts from the character's own numbers, not from what the
	# GM did to this one.
	var following := combat.next_round()
	check_eq(following.actions_of("hero"), 3, "the next round starts from what the sheet allows")


## The dodge: one action, one round, every attack.
func _test_dodging() -> void:
	var combat := Round.new()
	combat.add_combatant("hero", "Hero", 2)
	combat.add_combatant("other", "Other", 2)
	combat.record_check("hero", "Good", 12, 6)
	combat.record_check("other", "Good", 11, 7)
	combat.start()

	check_false(combat.is_dodging("hero"), "nobody is dodging to begin with")
	check_eq(combat.dodge_of("hero"), "", "and there is no degree to read")

	check_true(combat.declare_dodge("hero", "Good"), "a dodge is declared")
	check_true(combat.is_dodging("hero"), "and stands")
	check_eq(combat.dodge_of("hero"), "Good", "with the degree it was rolled at")
	check_false(combat.is_dodging("other"), "and covers only the one who declared it")

	# The dodge is their action for the phase, and the phase window already
	# charges them for it -- so declaring one does not also cost an action.
	check_eq(combat.actions_of("hero"), 2, "declaring a dodge does not spend a second action")

	# It survives the trip to the players, because it is what makes the next
	# attack harder and the GM is the one who applies it.
	var copy := Round.from_dict(JSON.parse_string(JSON.stringify(combat.to_dict())))
	check_eq(copy.dodge_of("hero"), "Good", "and travels with the round")

	# Somebody out of the fight is not dodging anything.
	combat.knock_out("other", "unconscious")
	combat.advance_phase()
	check_false(combat.declare_dodge("other", "Amazing"), "somebody out of the fight cannot dodge")

	# A new round is a new dodge.
	var following := combat.next_round()
	check_false(following.is_dodging("hero"), "a dodge does not carry into the next round")


## Being dropped costs every action scheduled after it.
func _test_being_dropped_costs_later_phases() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 14, 3)
	combat.record_check("bob", "Amazing", 13, 4)
	combat.record_check("cy", "Ordinary", 11, 11)
	combat.start()

	check_eq(combat.acting_in("marginal").size(), 3, "everyone is scheduled for Marginal to begin with")

	check_true(combat.knock_out("bob", "Amazing hit, failed the endurance check"), "Bob is taken out")
	check_false(combat.knock_out("bob"), "dropping him twice does nothing")

	# A phase resolves as a unit. Shot during the Amazing phase, he still finishes
	# what he declared in it -- two combatants who drop each other both connect.
	check_true(combat.is_falling("bob"), "he is going down")
	check_false(combat.is_out("bob"), "but is not out until the phase closes")
	var still: Array = []
	for entry in combat.acting_in("amazing"):
		still.append(String(entry["id"]))
	check_true(still.has("bob"), "so he completes his action in the phase he was hit in")
	check_eq(combat.standing().size(), 3, "and still counts as standing until it ends")

	combat.advance_phase()
	check_true(combat.is_out("bob"), "when the phase closes, he is out")
	check_false(combat.is_falling("bob"), "and no longer falling")

	# Everything he had scheduled after that is gone.
	for phase_id in ["good", "ordinary", "marginal"]:
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


func _test_phases_advance_once() -> void:
	var combat := _new_round()
	for id in ["alice", "bob", "cy"]:
		combat.record_check(id, "Ordinary", 12, 10)
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
	combat.record_check("alice", "Amazing", 14, 3)
	combat.record_check("bob", "Good", 12, 8)
	combat.record_check("cy", "Marginal", 11, 17)
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
		AlternityNum.as_int(following.combatant("alice").get("actions", 0)), 4,
		"but how many actions they get does"
	)
	# Coming back is something that happens to a character, and the GM says when.
	check_true(following.is_out("cy"), "whoever was down stays down")


func _test_round_trip() -> void:
	var combat := _new_round()
	combat.record_check("alice", "Amazing", 14, 3)
	combat.record_check("bob", "Good", 12, 8)
	combat.record_check("cy", "Ordinary", 11, 12)
	combat.start()
	combat.advance_phase()
	combat.knock_out("cy", "down")
	combat.advance_phase()

	# Through JSON, the way it reaches the players' devices.
	var restored := Round.from_dict(JSON.parse_string(JSON.stringify(combat.to_dict())))
	check_eq(restored.round_id, combat.round_id, "the id survives")
	check_eq(restored.number, combat.number, "the number survives")
	check_eq(restored.state, Round.STATE_ACTIVE, "the state survives")
	check_eq(restored.phase(), "ordinary", "and the phase it is in")
	check_eq(restored.combatants.size(), 3, "every combatant survives")
	check_eq(String(restored.combatant("alice").get("degree", "")), "amazing", "with their phase")
	check_true(restored.is_out("cy"), "and who is down")
	check_eq(restored.acting_now().size(), 2, "so a player device works out the same schedule")
	check_eq(
		AlternityNum.as_int(restored.combatant("alice").get("check_score", 0)), 14,
		"including the scores that order a phase"
	)

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

	# Combat has its own tables rather than reusing the general scale. Three
	# cover grades, not two, and moonlight is +2 -- an earlier version of this
	# file had it at +1 by treating it as an instance of "Slight".
	check_eq(_rules.situation_step_for("cover_light"), 1, "light cover is +1")
	check_eq(_rules.situation_step_for("cover_medium"), 2, "medium cover is +2")
	check_eq(_rules.situation_step_for("cover_heavy"), 3, "heavy cover is +3")
	check_eq(_rules.situation_step_for("light_twilight"), 1, "twilight is +1")
	check_eq(_rules.situation_step_for("light_moonlight"), 2, "moonlight is +2")
	check_eq(_rules.situation_step_for("light_none"), 3, "total darkness is +3")
	check_eq(_rules.situation_step_for("attacker_rear"), -2, "attacking from the rear is a -2 bonus")
	check_eq(_rules.situation_step_for("called_shot"), 4, "a called shot is +4")

	# Figuring the odds is addition.
	check_eq(
		_rules.net_situation_steps(["cover_light", "light_moonlight"]), 3,
		"modifiers net together"
	)
	check_eq(
		_rules.net_situation_steps(["attacker_rear", "cover_medium"]), 0,
		"and a bonus can cancel a penalty"
	)
	check_eq(_rules.net_situation_steps([]), 0, "nothing nets to nothing")

	# A category this build does not know is worth nothing rather than guessed.
	check_eq(_rules.situation_step_for("what_even_is_this"), 0, "an unknown situation adds nothing")

	# The netted total has to be a step the die chain can express.
	check_eq(_rules.action_step_die(_rules.net_situation_steps(["cover_heavy"])), "+d8", "+3 steps is +d8")
	check_eq(_rules.action_step_die(_rules.net_situation_steps(["attacker_flank"])), "-d4", "-1 step is -d4")

	# A prone target is harder to shoot and easier to club. Offering one list for
	# both would make lying down a universal defence.
	check_eq(_rules.situation_step_for("target_prone_ranged"), 2, "a prone target is +2 to shoot")
	check_eq(_rules.situation_step_for("target_prone_melee"), -2, "and -2 to hit with a club")

	var ranged_ids: Array = []
	for row in _rules.attack_modifiers_for("ranged"):
		ranged_ids.append(String(row["id"]))
	check_true(ranged_ids.has("cover_heavy"), "cover is offered for a ranged attack")
	check_true(ranged_ids.has("target_prone_ranged"), "with the ranged prone row")
	check_false(ranged_ids.has("target_prone_melee"), "and not the melee one")
	check_true(ranged_ids.has("attacker_rear"), "rows common to both tables are offered too")

	var melee_ids: Array = []
	for row in _rules.attack_modifiers_for("melee"):
		melee_ids.append(String(row["id"]))
	check_false(melee_ids.has("cover_heavy"), "cover is not offered for a melee attack")
	check_true(melee_ids.has("target_prone_melee"), "which uses the melee prone row")
	check_true(melee_ids.has("charging"), "and can charge")


## Range modifiers depend on the weapon, not just the distance.
##
## An earlier version applied one scale to everything -- short -1, medium 0,
## long +1 -- which is right for a rifle and wrong for every other weapon. A
## pistol at long range is +3.
func _test_range_bands() -> void:
	check_eq(_rules.range_step_for("rifle", "long"), 1, "a rifle at long range is +1")
	check_eq(_rules.range_step_for("pistol", "long"), 3, "a pistol at long range is +3")
	check_eq(_rules.range_step_for("smg", "medium"), 1, "an SMG at medium range is +1")
	check_eq(_rules.range_step_for("rifle", "medium"), 0, "a rifle at medium range is unmodified")
	check_eq(_rules.range_step_for("primitive", "long"), 2, "a bow at long range is +2")
	for weapon in ["rifle", "pistol", "smg", "primitive"]:
		check_eq(_rules.range_step_for(weapon, "short"), -1, "%s at short range is a -1 bonus" % weapon)

	# Indirect fire inverts: hopeless up close, designed for distance.
	check_eq(_rules.range_step_for("heavy_indirect", "short"), 2, "indirect fire is +2 up close")
	check_eq(_rules.range_step_for("heavy_indirect", "medium"), -2, "and a -2 bonus at medium range")

	check_eq(_rules.range_step_for("trebuchet", "short"), 0, "an unknown weapon type adds nothing")

	# Which band a distance falls in, from the weapon's own stat line.
	check_eq(_rules.range_band_for(8.0, 10.0, 20.0, 40.0), "short", "inside short range")
	check_eq(_rules.range_band_for(10.0, 10.0, 20.0, 40.0), "short", "the boundary is inclusive")
	check_eq(_rules.range_band_for(15.0, 10.0, 20.0, 40.0), "medium", "inside medium range")
	check_eq(_rules.range_band_for(35.0, 10.0, 20.0, 40.0), "long", "inside long range")
	# There is no band past long, and no shot can be fired there.
	check_eq(_rules.range_band_for(41.0, 10.0, 20.0, 40.0), "", "and beyond it, out of range entirely")


## A called shot that lands is promoted one degree.
func _test_promotion() -> void:
	check_eq(_rules.promote_degree("ordinary"), "good", "ordinary is promoted to good")
	check_eq(_rules.promote_degree("good"), "amazing", "and good to amazing")
	check_eq(_rules.promote_degree("amazing"), "amazing", "amazing is the ceiling")
	check_eq(_rules.promote_degree("failure"), "failure", "a miss is not promoted into a hit")


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

	# Gated where degradation is not, which looks inconsistent and is not: the
	# Gamemaster Guide gives degradation as a standard rule and then says on the
	# same page that "no standard rule exists" for upgrading, offering one as a
	# guideline. One is the game; the other is a suggestion a table opts into.
	var plain := {}
	_rules.ensure_character_shape(plain)
	check_eq(
		_rules.character_upgraded_damage_degree(plain, "ordinary", "A", "O"), "ordinary",
		"with Upgrading Damage off, nothing is promoted"
	)
	check_eq(
		_rules.character_degraded_damage_grade(plain, "mortal", "O", "A"), "stun",
		"while degradation applies with no toggle at all"
	)
	_rules.set_optional_rule(plain, "damage_upgrading", true)
	check_eq(
		_rules.character_upgraded_damage_degree(plain, "ordinary", "A", "O"), "amazing",
		"and with the guideline turned on, a hit is promoted"
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
