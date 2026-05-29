extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")

func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()
	rules.ensure_character_shape(character)
	character["species_id"] = rules.mutant_species_id()
	rules.set_mutation_points(character, 4, 2)
	rules.set_mutation_distribution(character, "advantage", "Ordinary:2|Good:1|Amazing:0")
	rules.set_mutation_distribution(character, "drawback", "Slight:0|Moderate:1|Extreme:0")

	rules.add_mutation_advantage(character, "improved_str")
	rules.add_mutation_advantage(character, "dermal_reinforcement")
	rules.add_mutation_advantage(character, "natural_attack")
	rules.add_mutation_drawback(character, "slow_reflexes")

	var messages := rules.validate(character)
	if messages.is_empty():
		print("Validation PASSED")
	else:
		print("Validation FAILED with messages:")
		for msg in messages:
			print("- ", msg)
	
	quit()
