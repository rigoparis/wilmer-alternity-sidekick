extends "res://tools/test_harness.gd"
##
## ensure_character_shape() is the migration layer that lets characters saved by
## older builds keep loading. These cases cover the three ways a stored file can
## disappoint it: missing keys, wrong types, and half-populated nested blocks.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("ensure_character_shape")

	var rules = RulesScript.new()
	rules.load_core_data()

	_case_empty(rules)
	_case_partial(rules)
	_case_malformed(rules)
	_case_nested_missing(rules)

	finish()


## An empty dictionary must come back fully formed.
func _case_empty(rules) -> void:
	var result = rules.ensure_character_shape({})

	if check_true(result.has("abilities"), "creates abilities"):
		for ability in rules.ABILITIES:
			if check_true(result["abilities"].has(ability), "creates ability %s" % ability):
				check_eq(result["abilities"][ability], 10, "ability %s defaults to 10" % ability)

	var expected_keys := [
		"selected_skills", "selected_perks", "selected_flaws",
		"selected_achievements", "mutations", "cybertech",
		"fx", "optional_rules", "species_id", "profession_id", "notes",
		"achievement_level", "achievement_points",
		"achievement_points_available",
		"achievement_points_spent_other", "damage", "last_resorts_used",
		"equipment",
	]
	for key in expected_keys:
		check_true(result.has(key), "creates key %s" % key)

	check_true(result["damage"].has("stun"), "initializes damage tracking")
	check_eq(typeof(result["equipment"]), TYPE_DICTIONARY, "equipment is a Dictionary")
	check_true(result["equipment"].has("carried"), "initializes equipment.carried")

	for rule in rules.OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if check_true(result["optional_rules"].has(rule_id), "creates optional rule %s" % rule_id):
			check_eq(result["optional_rules"][rule_id], false, "optional rule %s defaults to false" % rule_id)


## Existing values must survive; only gaps get filled.
func _case_partial(rules) -> void:
	var result = rules.ensure_character_shape({
		"abilities": {"STR": 12, "DEX": 14},
		"selected_skills": {"1": 2},
		"achievement_points": "5",
		"notes": "Test notes",
	})

	check_eq(result["abilities"]["STR"], 12, "preserves existing STR")
	check_eq(result["abilities"]["DEX"], 14, "preserves existing DEX")
	check_true(result["abilities"].has("CON"), "fills in missing CON")
	check_eq(result["abilities"]["CON"], 10, "missing CON defaults to 10")
	check_eq(result["selected_skills"]["1"], 2, "preserves existing selected_skills")
	check_eq(result["notes"], "Test notes", "preserves existing notes")

	# A numeric string is coerced, and the level is derived from it.
	check_eq(result["achievement_points"], 5, "coerces numeric-string achievement_points to int")
	check_eq(
		result["achievement_level"], rules.achievements.achievement_level_for_points(5),
		"derives achievement_level from points"
	)


## Every field holding the wrong type must be recovered, not propagated.
func _case_malformed(rules) -> void:
	var result = rules.ensure_character_shape({
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
		"optional_rules": "none",
	})

	for key in ["abilities", "selected_skills", "selected_perks", "selected_flaws"]:
		check_eq(typeof(result[key]), TYPE_DICTIONARY, "recovers malformed %s to a Dictionary" % key)

	check_false(
		result.has("achievements.selected_achievements"),
		"migrates away the legacy achievements.selected_achievements key"
	)
	check_eq(typeof(result["selected_achievements"]), TYPE_ARRAY, "selected_achievements recovered to an Array")

	# Each sub-block must be rebuilt far enough to carry its marker field.
	var blocks := {
		"mutations": "generation_mode",
		"cybertech": "enabled",
		"fx": "is_fx_talent",
		"equipment": "carried",
		"damage": "stun",
	}
	for block in blocks:
		if check_eq(typeof(result[block]), TYPE_DICTIONARY, "recovers malformed %s to a Dictionary" % block):
			check_true(result[block].has(blocks[block]), "rebuilt %s has %s" % [block, blocks[block]])

	# A non-numeric string cannot be coerced, so it falls back to 0.
	check_eq(result["achievement_points"], 0, "non-numeric achievement_points falls back to 0")


## Valid-but-incomplete nested dictionaries get topped up without losing data.
func _case_nested_missing(rules) -> void:
	var result = rules.ensure_character_shape({
		"optional_rules": {"2a": true},
		"damage": {},
		"mutations": {},
		"cybertech": {},
		"fx": {},
		"equipment": {},
	})

	check_eq(result["optional_rules"]["2a"], true, "preserves an already-enabled optional rule")
	for rule in rules.OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		check_true(result["optional_rules"].has(rule_id), "backfills optional rule %s" % rule_id)

	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		check_true(result["damage"].has(damage_type), "backfills damage tracker %s" % damage_type)

	check_true(result["mutations"].has("generation_mode"), "normalizes an empty mutations block")
	check_true(result["cybertech"].has("enabled"), "normalizes an empty cybertech block")
	check_true(result["fx"].has("is_fx_talent"), "normalizes an empty fx block")
	check_true(result["equipment"].has("carried"), "normalizes equipment.carried")
	check_true(result["equipment"].has("custom_items"), "normalizes equipment.custom_items")
