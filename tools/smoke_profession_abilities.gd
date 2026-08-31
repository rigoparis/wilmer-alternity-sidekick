extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("profession ability limits")

	var rules = RulesScript.new()
	rules.load_core_data()

	var character := rules.default_character()
	rules.ensure_character_shape(character)
	character["species_id"] = rules.mutations.mutant_species_id()
	character["profession_id"] = 5  # Tech Op
	rules.set_optional_rule(character, "2a", true)
	rules.set_optional_rule(character, "2c", true)
	character["abilities"] = {"STR": 7, "DEX": 10, "CON": 9, "INT": 11, "WIL": 10, "PER": 8}

	rules.mutations.set_mutation_points(character, 2, 0)
	rules.mutations.set_mutation_distribution(character, "advantage", "Ordinary:0|Good:1|Amazing:0")
	var result = rules.mutations.add_mutation_advantage(character, "enhanced_wil")
	check_true(bool(result.get("ok", false)), "Enhanced WIL mutation can be added")

	# Tech Op imposes minimum DEX 9 and INT 11.
	var dex_limits := rules.ability_limits(character, "DEX")
	check_eq(rules._as_int(dex_limits[0]), 9, "Tech Op DEX minimum")
	check_eq(rules._as_int(dex_limits[1]), 14, "Tech Op DEX maximum")

	var int_limits := rules.ability_limits(character, "INT")
	check_eq(rules._as_int(int_limits[0]), 11, "Tech Op INT minimum")
	check_eq(rules._as_int(int_limits[1]), 14, "Tech Op INT maximum")

	# The mutation widens the *effective* range without changing purchase cost.
	var wil_limits := rules.effective_ability_limits(character, "WIL")
	check_eq(rules._as_int(wil_limits[0]), 4, "Enhanced WIL effective minimum")
	check_eq(rules._as_int(wil_limits[1]), 16, "Enhanced WIL effective maximum")
	check_eq(
		rules.ability_total(character), 55,
		"purchased ability cost excludes the Enhanced WIL mutation bonus"
	)
	check_eq(
		rules._as_int(rules.effective_abilities(character).get("WIL", 0)), 12,
		"effective WIL is purchased 10 plus Enhanced WIL 2"
	)

	# Scores below the profession minimum are raised, not rejected.
	character["abilities"]["DEX"] = 4
	character["abilities"]["INT"] = 4
	rules.clamp_abilities_to_species(character)
	check_eq(rules._as_int(character["abilities"].get("DEX", 0)), 9, "clamp raises Tech Op DEX to 9")
	check_eq(rules._as_int(character["abilities"].get("INT", 0)), 11, "clamp raises Tech Op INT to 11")

	finish()
