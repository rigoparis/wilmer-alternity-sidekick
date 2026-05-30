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
		"optional_rules", "species_id", "profession_id", "notes",
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

	print("ensure_character_shape tests passed!")
	quit(0)
