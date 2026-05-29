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
	character["species_id"] = rules.mutant_species_id()
	character["profession_id"] = 5
	rules.set_optional_rule(character, "2a", true)
	rules.set_optional_rule(character, "2c", true)
	character["abilities"] = {
		"STR": 7,
		"DEX": 10,
		"CON": 9,
		"INT": 11,
		"WIL": 10,
		"PER": 8,
	}
	rules.set_mutation_points(character, 2, 0)
	rules.set_mutation_distribution(character, "advantage", "Ordinary:0|Good:1|Amazing:0")
	var result := rules.add_mutation_advantage(character, "enhanced_wil")
	if not bool(result.get("ok", false)):
		_fail("Enhanced WIL mutation could not be added for the profession ability smoke test.")

	var dex_limits := rules.ability_limits(character, "DEX")
	var int_limits := rules.ability_limits(character, "INT")
	var wil_limits := rules.effective_ability_limits(character, "WIL")
	if rules._as_int(dex_limits[0]) != 9 or rules._as_int(dex_limits[1]) != 14:
		_fail("Tech Op DEX limits should be 9/14.")
	if rules._as_int(int_limits[0]) != 11 or rules._as_int(int_limits[1]) != 14:
		_fail("Tech Op INT limits should be 11/14.")
	if rules._as_int(wil_limits[0]) != 4 or rules._as_int(wil_limits[1]) != 16:
		_fail("Enhanced WIL should expose an effective WIL range of 4/16.")
	if rules.ability_total(character) != 55:
		_fail("Purchased ability cost should be 55 after excluding the Enhanced WIL mutation bonus.")
	if rules._as_int(rules.effective_abilities(character).get("WIL", 0)) != 12:
		_fail("Effective WIL should be 12 from purchased WIL 10 plus Enhanced WIL 2.")

	character["abilities"]["DEX"] = 4
	character["abilities"]["INT"] = 4
	rules.clamp_abilities_to_species(character)
	if rules._as_int(character["abilities"].get("DEX", 0)) != 9:
		_fail("Profession clamp should raise Tech Op DEX to 9.")
	if rules._as_int(character["abilities"].get("INT", 0)) != 11:
		_fail("Profession clamp should raise Tech Op INT to 11.")

	quit()
