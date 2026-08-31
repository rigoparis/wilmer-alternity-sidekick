extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("species lookup")

	var rules = RulesScript.new()
	rules.load_core_data()

	var valid_species = rules.get_species_by_id(1)
	check_eq(rules._as_int(valid_species.get("id", -1)), 1, "species ID 1 resolves")

	# An unknown ID falls back to the first species rather than an empty dict.
	var invalid_species = rules.get_species_by_id(9999)
	check_eq(
		rules._as_int(invalid_species.get("id", -1)),
		rules._as_int(rules.species[0].get("id", -1)),
		"unknown species ID falls back to the first species"
	)

	# With no catalog loaded there is nothing to fall back to.
	rules.species = []
	rules.species_by_id = {}
	check_true(rules.get_species_by_id(1).is_empty(), "empty species list returns an empty dict")

	finish()
