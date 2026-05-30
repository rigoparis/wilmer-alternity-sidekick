extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	# Test getting a valid species
	var valid_species = rules.get_species_by_id(1)
	if rules._as_int(valid_species.get("id", -1)) != 1:
		_fail("Could not find species with ID 1.")

	# Test getting an invalid species
	var invalid_species = rules.get_species_by_id(9999)
	if rules._as_int(invalid_species.get("id", -1)) != rules._as_int(rules.species[0].get("id", -1)):
		_fail("Invalid species ID did not return the first species.")

	# Test getting from empty species list
	rules.species = []
	rules.species_by_id = {}
	var empty_species = rules.get_species_by_id(1)
	if not empty_species.is_empty():
		_fail("Empty species list did not return empty dictionary.")

	print("Species lookup smoke test passed.")
	quit()
