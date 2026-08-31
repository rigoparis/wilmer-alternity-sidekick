extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("profession rules")

	var rules = RulesScript.new()
	rules.load_core_data()

	# Table P2: Resistance Modifiers. Source: Player Handbook p. 32.
	var expected_rm := {
		1: -2, 4: -2,
		5: -1, 6: -1,
		7: 0, 10: 0,
		11: 1, 12: 1,
		13: 2, 14: 2,
		15: 3, 16: 3,
		17: 4, 18: 4,
		19: 5, 24: 5,
	}
	for score in expected_rm.keys():
		check_eq(
			rules.resistance_modifier(score), expected_rm[score],
			"Table P2 resistance modifier for score %d" % score
		)

	# Free Agent resistance bonus applies to PER (any ability except CON qualifies).
	var free_agent := rules.default_character()
	rules.ensure_character_shape(free_agent)
	free_agent["profession_id"] = 4
	free_agent["free_agent_rm_bonus"] = "PER"
	free_agent["abilities"]["PER"] = 12
	check_eq(
		rules.character_resistance_modifier(free_agent, "PER"), 2,
		"Free Agent PER 12 with resistance bonus"
	)

	# Combat Spec situation bonus: the chosen specialty improves from +d0 to -d4,
	# and the same bonus must show up in the attack-form combat score.
	var combat_spec := rules.default_character()
	rules.ensure_character_shape(combat_spec)
	combat_spec["profession_id"] = 0
	combat_spec["abilities"]["STR"] = 11
	combat_spec["combat_spec_bonus_specialty"] = 31  # Modern Ranged Weapons-Pistol
	rules.set_skill_rank(combat_spec, 30, 1)
	rules.set_skill_rank(combat_spec, 31, 1)

	var pistol := rules.get_skill_by_id(31)
	check_eq(
		String(rules.skill_score(combat_spec, pistol).get("die", "")), "-d4",
		"Combat Spec chosen specialty die in the skills table"
	)
	check_eq(
		rules._as_int(rules.equipment._combat_skill_score(combat_spec, 31).get("step", 0)), -1,
		"Combat Spec chosen specialty step in attack forms"
	)

	# Armor Operation specialties are valid Combat Spec bonus targets (PHB p. 30).
	combat_spec["combat_spec_bonus_specialty"] = 1  # Armor Operation-Combat armor
	rules.set_skill_rank(combat_spec, 0, 1)
	rules.set_skill_rank(combat_spec, 1, 1)
	check_eq(
		String(rules.skill_score(combat_spec, rules.get_skill_by_id(1)).get("die", "")), "-d4",
		"Armor Operation-Combat armor is eligible for the Combat Spec bonus"
	)

	# With the bonus moved away, the previously chosen specialty loses it.
	check_eq(
		rules._as_int(rules.equipment._combat_skill_score(combat_spec, 31).get("step", 0)), 0,
		"non-chosen specialty has no situation bonus"
	)

	finish()
