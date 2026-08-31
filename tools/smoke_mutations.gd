extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _has_attack_form(equipment: Dictionary, form_name: String) -> bool:
	for form in equipment.get("attack_forms", []):
		if typeof(form) == TYPE_DICTIONARY and String(form.get("name", "")) == form_name:
			return true
	return false


func _init() -> void:
	begin("mutations")

	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)
	character["species_id"] = rules.mutations.mutant_species_id()
	character["abilities"]["STR"] = 11
	character["abilities"]["DEX"] = 9
	rules.mutations.set_mutation_points(character, 4, 2)
	rules.mutations.set_mutation_distribution(character, "advantage", "Ordinary:2|Good:1|Amazing:0")
	rules.mutations.set_mutation_distribution(character, "drawback", "Slight:0|Moderate:1|Extreme:0")

	check_true(rules.mutation_advantages.size() >= 60, "mutation advantages loaded (>=60)")
	check_true(rules.mutation_drawbacks.size() >= 24, "mutation drawbacks loaded (>=24)")
	check_true(rules.mutations.mutations_enabled(character), "mutations enabled for Mutant species")
	check_eq(
		rules.mutations.mutation_distribution_label(character, "advantage"),
		"1 Good + 2 Ordinary", "advantage point distribution label"
	)
	check_eq(
		rules.mutations.mutation_distribution_label(character, "drawback"),
		"1 Moderate", "drawback point distribution label"
	)

	# Improved STR feeds through to effective abilities.
	var str_before := rules._as_int(rules.effective_abilities(character).get("STR", 0))
	var result = rules.mutations.add_mutation_advantage(character, "improved_str")
	check_true(bool(result.get("ok", false)), "Improved STR can be added")
	check_eq(
		rules._as_int(rules.effective_abilities(character).get("STR", 0)), str_before + 1,
		"Improved STR raises effective STR by 1"
	)

	# Natural armor from a mutation shows up in the equipment summary.
	result = rules.mutations.add_mutation_advantage(character, "dermal_reinforcement")
	check_true(bool(result.get("ok", false)), "Dermal Reinforcement can be added")
	var equipment: Dictionary = rules.equipment.equipment_summary(character)
	check_false(
		equipment.get("combat_armor", []).is_empty(),
		"mutation natural armor reaches the equipment summary"
	)

	# equipment_summary returns a snapshot, not a live view: a mutation added
	# after the call must not appear until the summary is recomputed.
	result = rules.mutations.add_mutation_advantage(character, "natural_attack")
	check_true(bool(result.get("ok", false)), "Natural Attack can be added")
	check_false(
		_has_attack_form(equipment, "Natural Attack"),
		"stale summary does not yet contain Natural Attack"
	)
	equipment = rules.equipment.equipment_summary(character)
	check_true(
		_has_attack_form(equipment, "Natural Attack"),
		"recomputed summary exposes Natural Attack"
	)

	# Slow Reflexes shifts the action check die.
	var base_action: Dictionary = rules.action_check(character)
	result = rules.mutations.add_mutation_drawback(character, "slow_reflexes")
	check_true(bool(result.get("ok", false)), "Slow Reflexes can be added")
	check_ne(
		String(rules.action_check(character).get("die", "")),
		String(base_action.get("die", "")),
		"Slow Reflexes changes the action check die"
	)

	# Point totals and validation.
	var summary: Dictionary = rules.summary(character)
	var mutation_summary: Dictionary = summary.get("mutations", {})
	check_eq(
		rules._as_int(mutation_summary.get("advantage_points_used", 0)), 4,
		"advantage mutation points total"
	)
	check_eq(
		rules._as_int(mutation_summary.get("drawback_points_used", 0)), 2,
		"drawback mutation points total"
	)
	check_true(
		rules.validate(character).is_empty(),
		"character validates once advantages and drawbacks are spent"
	)

	# Random generation path populates origin, points, distribution and picks.
	var random_character := rules.default_character()
	rules.ensure_character_shape(random_character)
	random_character["species_id"] = rules.mutations.mutant_species_id()
	var origin_roll: Dictionary = rules.mutations.roll_mutation_origin_and_points(random_character)
	check_false(origin_roll.is_empty(), "roll origin and points returns a result")
	check_true(
		rules._as_int(random_character.get("mutations", {}).get("advantage_points", 0)) > 0,
		"roll assigns a positive advantage point total"
	)
	rules.mutations.roll_mutation_distribution(random_character, "advantage")
	rules.mutations.roll_mutation_distribution(random_character, "drawback")
	rules.mutations.roll_mutations_for_distribution(random_character, "advantage")
	rules.mutations.roll_mutations_for_distribution(random_character, "drawback")
	check_false(
		rules.mutations.selected_mutation_advantages(random_character).is_empty(),
		"random rolling selects advantages"
	)
	check_false(
		rules.mutations.selected_mutation_drawbacks(random_character).is_empty(),
		"random rolling selects drawbacks"
	)

	finish()
