extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("default character shape")

	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()

	var expected_keys := [
		"hero_name", "player_name", "career", "notes", "setting",
		"achievement_level", "achievement_points", "achievement_points_available",
		"achievement_points_spent_other", "species_id", "profession_id",
		"abilities", "selected_skills", "selected_perks", "selected_flaws",
		"selected_achievements", "mutations", "optional_rules",
		"damage", "last_resorts_used", "equipment",
	]
	for key in expected_keys:
		check_true(character.has(key), "default character has key %s" % key)

	# Scalar defaults.
	check_eq(character["hero_name"], "New Hero", "hero_name default")
	check_eq(character["player_name"], "", "player_name default")
	check_eq(character["career"], "", "career default")
	check_eq(character["notes"], "", "notes default")
	check_eq(character["setting"], rules.data.get("setting", "Core"), "setting default")
	check_eq(character["achievement_level"], 1, "achievement_level default")
	check_eq(character["achievement_points"], 0, "achievement_points default")
	check_eq(character["achievement_points_available"], 0, "achievement_points_available default")
	check_eq(character["achievement_points_spent_other"], 0, "achievement_points_spent_other default")
	check_eq(character["species_id"], 0, "species_id default")
	check_eq(character["profession_id"], 0, "profession_id default")
	check_eq(character["last_resorts_used"], 0, "last_resorts_used default")

	# All six abilities start at 10.
	for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
		if check_true(character["abilities"].has(ability), "abilities has %s" % ability):
			check_eq(character["abilities"][ability], 10, "ability %s starts at 10" % ability)

	# Empty collections, with the container type pinned.
	for key in ["selected_skills", "selected_perks", "selected_flaws"]:
		check_eq(typeof(character[key]), TYPE_DICTIONARY, "%s is a Dictionary" % key)
		check_true(character[key].is_empty(), "%s starts empty" % key)
	check_eq(typeof(character["selected_achievements"]), TYPE_ARRAY, "selected_achievements is an Array")
	check_true(character["selected_achievements"].is_empty(), "selected_achievements starts empty")

	# Mutations block.
	var mutations: Dictionary = character["mutations"]
	check_eq(mutations["generation_mode"], "random", "mutations.generation_mode default")
	check_eq(mutations["origin"], "engineered", "mutations.origin default")
	check_eq(mutations["uniqueness"], "engineered_community", "mutations.uniqueness default")
	check_eq(mutations["advantage_points"], 0, "mutations.advantage_points default")
	check_eq(mutations["drawback_points"], 0, "mutations.drawback_points default")
	for key in ["advantage_distribution", "drawback_distribution"]:
		check_eq(typeof(mutations[key]), TYPE_DICTIONARY, "mutations.%s is a Dictionary" % key)
		check_true(mutations[key].is_empty(), "mutations.%s starts empty" % key)
	for key in ["advantages", "drawbacks"]:
		check_eq(typeof(mutations[key]), TYPE_ARRAY, "mutations.%s is an Array" % key)
		check_true(mutations[key].is_empty(), "mutations.%s starts empty" % key)

	# Optional rules all start disabled.
	var optional_rules: Dictionary = character["optional_rules"]
	for rule_id in ["2a", "2b", "2c"]:
		if check_true(optional_rules.has(rule_id), "optional_rules has %s" % rule_id):
			check_eq(optional_rules[rule_id], false, "optional rule %s starts disabled" % rule_id)

	# Damage tracks all start clear.
	var damage: Dictionary = character["damage"]
	for track in ["stun", "wound", "mortal", "fatigue"]:
		check_eq(damage[track], 0, "damage.%s starts at 0" % track)

	# Equipment block.
	var equipment: Dictionary = character["equipment"]
	for key in ["carried", "custom_items"]:
		check_eq(typeof(equipment[key]), TYPE_ARRAY, "equipment.%s is an Array" % key)
		check_true(equipment[key].is_empty(), "equipment.%s starts empty" % key)

	finish()
