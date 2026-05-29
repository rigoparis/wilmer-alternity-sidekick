extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
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

	if rules.mutation_advantages.size() < 60:
		_fail("Mutation advantages did not load.")
	if rules.mutation_drawbacks.size() < 24:
		_fail("Mutation drawbacks did not load.")
	if not rules.mutations.mutations_enabled(character):
		_fail("Mutations should be enabled for Mutant species.")
	if rules.mutations.mutation_distribution_label(character, "advantage") != "1 Good + 2 Ordinary":
		_fail("Advantage point distribution was not selected correctly.")
	if rules.mutations.mutation_distribution_label(character, "drawback") != "1 Moderate":
		_fail("Drawback point distribution was not selected correctly.")

	var str_before := rules._as_int(rules.effective_abilities(character).get("STR", 0))
	var result = rules.mutations.add_mutation_advantage(character, "improved_str")
	if not bool(result.get("ok", false)):
		_fail("Improved STR mutation could not be added.")
	var str_after := rules._as_int(rules.effective_abilities(character).get("STR", 0))
	if str_after != str_before + 1:
		_fail("Improved STR did not affect effective abilities.")

	result = rules.mutations.add_mutation_advantage(character, "dermal_reinforcement")
	if not bool(result.get("ok", false)):
		_fail("Dermal Reinforcement mutation could not be added.")
	var equipment: Dictionary = rules.equipment.equipment_summary(character)
	if equipment.get("combat_armor", []).is_empty():
		_fail("Mutation natural armor was not exposed to equipment summary.")

	result = rules.mutations.add_mutation_advantage(character, "natural_attack")
	if not bool(result.get("ok", false)):
		_fail("Natural Attack mutation could not be added.")
	var found_natural_attack := false
	for form in equipment.get("attack_forms", []):
		if typeof(form) == TYPE_DICTIONARY and String(form.get("name", "")) == "Natural Attack":
			found_natural_attack = true
	if found_natural_attack:
		_fail("Natural Attack appeared before summary refresh.")
	equipment = rules.equipment.equipment_summary(character)
	for form in equipment.get("attack_forms", []):
		if typeof(form) == TYPE_DICTIONARY and String(form.get("name", "")) == "Natural Attack":
			found_natural_attack = true
	if not found_natural_attack:
		_fail("Natural Attack was not exposed to attack forms.")

	var base_action: Dictionary = rules.action_check(character)
	result = rules.mutations.add_mutation_drawback(character, "slow_reflexes")
	if not bool(result.get("ok", false)):
		_fail("Slow Reflexes drawback could not be added.")
	var slower_action: Dictionary = rules.action_check(character)
	if String(base_action.get("die", "")) == String(slower_action.get("die", "")):
		_fail("Slow Reflexes did not affect the action check die.")

	var summary: Dictionary = rules.summary(character)
	var mutations: Dictionary = summary.get("mutations", {})
	if rules._as_int(mutations.get("advantage_points_used", 0)) != 4:
		_fail("Advantage mutation points were not totaled correctly.")
	if rules._as_int(mutations.get("drawback_points_used", 0)) != 2:
		_fail("Drawback mutation points were not totaled correctly.")
	if not rules.validate(character).is_empty():
		_fail("Mutation smoke character should validate after required advantage/drawback.")

	var random_character := rules.default_character()
	rules.ensure_character_shape(random_character)
	random_character["species_id"] = rules.mutations.mutant_species_id()
	var origin_roll: Dictionary = rules.mutations.roll_mutation_origin_and_points(random_character)
	if origin_roll.is_empty() or rules._as_int(random_character.get("mutations", {}).get("advantage_points", 0)) <= 0:
		_fail("Roll Origin and Points did not set random mutation origin and point totals.")
	rules.mutations.roll_mutation_distribution(random_character, "advantage")
	rules.mutations.roll_mutation_distribution(random_character, "drawback")
	rules.mutations.roll_mutations_for_distribution(random_character, "advantage")
	rules.mutations.roll_mutations_for_distribution(random_character, "drawback")
	if rules.mutations.selected_mutation_advantages(random_character).is_empty() or rules.mutations.selected_mutation_drawbacks(random_character).is_empty():
		_fail("Random mutation rolling did not select advantages and drawbacks.")

	quit()
