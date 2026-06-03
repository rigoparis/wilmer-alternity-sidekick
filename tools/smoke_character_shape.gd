extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	# Test case 1: Completely empty dictionary
	var empty_char = {}
	var result_char = rules.ensure_character_shape(empty_char)

	# Verify abilities
	if not result_char.has("abilities"):
		_fail("Did not create 'abilities' key.")
	for ability in rules.ABILITIES:
		if not result_char["abilities"].has(ability):
			_fail("Did not create '" + ability + "' in 'abilities'.")
		if result_char["abilities"][ability] != 10:
			_fail("'" + ability + "' should default to 10.")

	# Verify other keys are created
	var expected_keys = [
		"selected_skills", "selected_perks", "selected_flaws",
		"achievements.selected_achievements", "mutations", "cybertech",
		"fx", "optional_rules", "species_id", "profession_id", "notes",
		"achievement_level", "achievement_points",
		"achievements.achievement_points_available",
		"achievement_points_spent_other", "damage", "last_resorts_used",
		"equipment"
	]

	for key in expected_keys:
		if not result_char.has(key):
			_fail("Did not create expected key: " + key)

	# Verify specific sub-structures
	if not result_char["damage"].has("stun"):
		_fail("Did not initialize damage tracking keys.")
	if typeof(result_char["equipment"]) != TYPE_DICTIONARY or not result_char["equipment"].has("carried"):
		_fail("Did not initialize equipment shape.")
	for rule in rules.OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if not result_char["optional_rules"].has(rule_id):
			_fail("Did not initialize optional rule " + rule_id)
		if result_char["optional_rules"][rule_id] != false:
			_fail("Optional rule " + rule_id + " should default to false")

	# Test case 2: Partially populated dictionary
	var partial_char = {
		"abilities": {
			"STR": 12,
			"DEX": 14
		},
		"selected_skills": {
			"1": 2
		},
		"achievement_points": "5",
		"notes": "Test notes"
	}

	var result_partial = rules.ensure_character_shape(partial_char)

	if result_partial["abilities"]["STR"] != 12:
		_fail("Overwrote existing STR ability.")
	if result_partial["abilities"]["DEX"] != 14:
		_fail("Overwrote existing DEX ability.")

	if not result_partial["abilities"].has("CON"):
		_fail("Did not create missing 'CON' in 'abilities'.")
	if result_partial["abilities"]["CON"] != 10:
		_fail("Missing 'CON' should default to 10.")

	if result_partial["selected_skills"]["1"] != 2:
		_fail("Overwrote existing selected_skills.")

	if result_partial["notes"] != "Test notes":
		_fail("Overwrote existing notes.")

	if result_partial["achievement_points"] != 5:
		_fail("Did not cast achievement_points to int.")

	if result_partial["achievement_level"] != rules.achievements.achievement_level_for_points(5):
		_fail("Did not correctly calculate achievement_level based on points.")

	# Test case 3: Malformed data types and dictionary handling
	var malformed_char = {
		"abilities": "invalid",
		"selected_skills": "invalid",
		"selected_perks": [],
		"selected_flaws": 42,
		"achievements.selected_achievements": {},
		"achievement_points": "twenty",
		"damage": "none",
		"equipment": "string",
		"mutations": "mutant",
		"cybertech": ["list"],
		"fx": 100,
		"optional_rules": "none"
	}
	var result_malformed = rules.ensure_character_shape(malformed_char)

	if typeof(result_malformed["abilities"]) != TYPE_DICTIONARY:
		_fail("Did not fix malformed 'abilities' data type.")
	if typeof(result_malformed["selected_skills"]) != TYPE_DICTIONARY:
		_fail("Did not fix malformed 'selected_skills' data type.")
	if typeof(result_malformed["selected_perks"]) != TYPE_DICTIONARY:
		_fail("Did not fix malformed 'selected_perks' data type.")
	if typeof(result_malformed["selected_flaws"]) != TYPE_DICTIONARY:
		_fail("Did not fix malformed 'selected_flaws' data type.")
	if typeof(result_malformed["achievements.selected_achievements"]) != TYPE_ARRAY:
		_fail("Did not fix malformed 'achievements.selected_achievements' data type.")
	if typeof(result_malformed["mutations"]) != TYPE_DICTIONARY or not result_malformed["mutations"].has("generation_mode"):
		_fail("Did not recover from string mutations data.")
	if typeof(result_malformed["cybertech"]) != TYPE_DICTIONARY or not result_malformed["cybertech"].has("enabled"):
		_fail("Did not recover from array cybertech data.")
	if typeof(result_malformed["fx"]) != TYPE_DICTIONARY or not result_malformed["fx"].has("is_fx_talent"):
		_fail("Did not recover from integer fx data.")
	if typeof(result_malformed["equipment"]) != TYPE_DICTIONARY or not result_malformed["equipment"].has("carried"):
		_fail("Did not recover from malformed equipment data.")
	if typeof(result_malformed["damage"]) != TYPE_DICTIONARY or not result_malformed["damage"].has("stun"):
		_fail("Did not recover from malformed damage data.")
	if result_malformed["achievement_points"] != 0:
		_fail("Did not gracefully cast malformed achievement_points string.")

	# Test case 4: Missing required nested elements in valid dictionaries
	var nested_missing = {
		"optional_rules": {
			"2a": true
		},
		"damage": {},
		"mutations": {},
		"cybertech": {},
		"fx": {},
		"equipment": {}
	}
	var result_nested = rules.ensure_character_shape(nested_missing)

	if result_nested["optional_rules"]["2a"] != true:
		_fail("Overwrote existing optional rule.")

	for rule in rules.OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if not result_nested["optional_rules"].has(rule_id):
			_fail("Did not create optional rule: " + rule_id)

	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		if not result_nested["damage"].has(damage_type):
			_fail("Did not create damage tracker: " + damage_type)

	if not result_nested["mutations"].has("generation_mode"):
		_fail("Did not normalize mutations structure.")

	if not result_nested["cybertech"].has("enabled"):
		_fail("Did not normalize cybertech structure.")

	if not result_nested["fx"].has("is_fx_talent"):
		_fail("Did not normalize fx structure.")

	if not result_nested["equipment"].has("carried") or not result_nested["equipment"].has("custom_items"):
		_fail("Did not normalize equipment structure.")

	print("ensure_character_shape tests passed!")
	quit(0)
