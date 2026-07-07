extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")

func _fail(message: String) -> void:
	push_error(message)
	quit(1)

func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()
	var character := rules.default_character()

	var expected_keys = [
		"hero_name", "player_name", "career", "notes", "setting",
		"achievement_level", "achievement_points", "achievement_points_available",
		"achievement_points_spent_other", "species_id", "profession_id",
		"abilities", "selected_skills", "selected_perks", "selected_flaws",
		"selected_achievements", "mutations", "optional_rules",
		"damage", "last_resorts_used", "equipment"
	]

	for key in expected_keys:
		if not character.has(key):
			_fail("Character missing expected key: " + key)

	if character["hero_name"] != "New Hero":
		_fail("hero_name should be 'New Hero', got " + str(character["hero_name"]))
	if character["player_name"] != "":
		_fail("player_name should be empty, got " + str(character["player_name"]))
	if character["career"] != "":
		_fail("career should be empty, got " + str(character["career"]))
	if character["notes"] != "":
		_fail("notes should be empty, got " + str(character["notes"]))
	if character["setting"] != rules.data.get("setting", "Core"):
		_fail("setting should be '" + rules.data.get("setting", "Core") + "', got " + str(character["setting"]))
	if character["achievement_level"] != 1:
		_fail("achievement_level should be 1, got " + str(character["achievement_level"]))
	if character["achievement_points"] != 0:
		_fail("achievement_points should be 0, got " + str(character["achievement_points"]))
	if character["achievement_points_available"] != 0:
		_fail("achievement_points_available should be 0, got " + str(character["achievement_points_available"]))
	if character["achievement_points_spent_other"] != 0:
		_fail("achievement_points_spent_other should be 0, got " + str(character["achievement_points_spent_other"]))
	if character["species_id"] != 0:
		_fail("species_id should be 0, got " + str(character["species_id"]))
	if character["profession_id"] != 0:
		_fail("profession_id should be 0, got " + str(character["profession_id"]))

	var expected_abilities = ["STR", "DEX", "CON", "INT", "WIL", "PER"]
	for ability in expected_abilities:
		if not character["abilities"].has(ability):
			_fail("Missing ability: " + ability)
		if character["abilities"][ability] != 10:
			_fail("Ability " + ability + " should be 10, got " + str(character["abilities"][ability]))

	if typeof(character["selected_skills"]) != TYPE_DICTIONARY or not character["selected_skills"].is_empty():
		_fail("selected_skills should be an empty dictionary")
	if typeof(character["selected_perks"]) != TYPE_DICTIONARY or not character["selected_perks"].is_empty():
		_fail("selected_perks should be an empty dictionary")
	if typeof(character["selected_flaws"]) != TYPE_DICTIONARY or not character["selected_flaws"].is_empty():
		_fail("selected_flaws should be an empty dictionary")
	if typeof(character["selected_achievements"]) != TYPE_ARRAY or not character["selected_achievements"].is_empty():
		_fail("selected_achievements should be an empty array")

	var mutations = character["mutations"]
	if mutations["generation_mode"] != "random":
		_fail("mutations.generation_mode should be 'random', got " + str(mutations["generation_mode"]))
	if mutations["origin"] != "engineered":
		_fail("mutations.origin should be 'engineered', got " + str(mutations["origin"]))
	if mutations["uniqueness"] != "engineered_community":
		_fail("mutations.uniqueness should be 'engineered_community', got " + str(mutations["uniqueness"]))
	if mutations["advantage_points"] != 0:
		_fail("mutations.advantage_points should be 0, got " + str(mutations["advantage_points"]))
	if mutations["drawback_points"] != 0:
		_fail("mutations.drawback_points should be 0, got " + str(mutations["drawback_points"]))
	if typeof(mutations["advantage_distribution"]) != TYPE_DICTIONARY or not mutations["advantage_distribution"].is_empty():
		_fail("mutations.advantage_distribution should be an empty dictionary")
	if typeof(mutations["drawback_distribution"]) != TYPE_DICTIONARY or not mutations["drawback_distribution"].is_empty():
		_fail("mutations.drawback_distribution should be an empty dictionary")
	if typeof(mutations["advantages"]) != TYPE_ARRAY or not mutations["advantages"].is_empty():
		_fail("mutations.advantages should be an empty array")
	if typeof(mutations["drawbacks"]) != TYPE_ARRAY or not mutations["drawbacks"].is_empty():
		_fail("mutations.drawbacks should be an empty array")

	var optional_rules = character["optional_rules"]
	if not optional_rules.has("2a") or optional_rules["2a"] != false:
		_fail("optional_rules.2a should be false")
	if not optional_rules.has("2b") or optional_rules["2b"] != false:
		_fail("optional_rules.2b should be false")
	if not optional_rules.has("2c") or optional_rules["2c"] != false:
		_fail("optional_rules.2c should be false")

	var damage = character["damage"]
	if damage["stun"] != 0:
		_fail("damage.stun should be 0")
	if damage["wound"] != 0:
		_fail("damage.wound should be 0")
	if damage["mortal"] != 0:
		_fail("damage.mortal should be 0")
	if damage["fatigue"] != 0:
		_fail("damage.fatigue should be 0")

	if character["last_resorts_used"] != 0:
		_fail("last_resorts_used should be 0")

	var equipment = character["equipment"]
	if typeof(equipment["carried"]) != TYPE_ARRAY or not equipment["carried"].is_empty():
		_fail("equipment.carried should be an empty array")
	if typeof(equipment["custom_items"]) != TYPE_ARRAY or not equipment["custom_items"].is_empty():
		_fail("equipment.custom_items should be an empty array")

	print("Success!")
	quit()
