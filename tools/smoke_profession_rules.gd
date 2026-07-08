extends SceneTree

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _init() -> void:
	var rules = RulesScript.new()
	rules.load_core_data()

	# Table P2: Resistance Modifiers. Source: Player's Handbook p. 32.
	var expected_rm := {
		1: -2, 4: -2,
		5: -1, 6: -1,
		7: 0, 10: 0,
		11: 1, 12: 1,
		13: 2, 14: 2,
		15: 3, 16: 3,
		17: 4, 18: 4,
		19: 5, 24: 5,
	}
	for score in expected_rm.keys():
		if rules.resistance_modifier(score) != expected_rm[score]:
			_fail("Table P2 mismatch: score %d should be %+d, got %+d." % [score, expected_rm[score], rules.resistance_modifier(score)])

	# Free Agent resistance bonus applies to PER (any ability except CON qualifies).
	var free_agent := rules.default_character()
	rules.ensure_character_shape(free_agent)
	free_agent["profession_id"] = 4
	free_agent["free_agent_rm_bonus"] = "PER"
	free_agent["abilities"]["PER"] = 12
	if rules.character_resistance_modifier(free_agent, "PER") != 2:
		_fail("Free Agent PER 12 with resistance bonus should have RM +2, got %+d." % rules.character_resistance_modifier(free_agent, "PER"))

	# Combat Spec situation bonus: chosen specialty improves from +d0 to -d4,
	# and the same bonus must appear in the attack-form combat score.
	var combat_spec := rules.default_character()
	rules.ensure_character_shape(combat_spec)
	combat_spec["profession_id"] = 0
	combat_spec["abilities"]["STR"] = 11
	combat_spec["combat_spec_bonus_specialty"] = 31 # Modern Ranged Weapons-Pistol
	rules.set_skill_rank(combat_spec, 30, 1)
	rules.set_skill_rank(combat_spec, 31, 1)
	var pistol := rules.get_skill_by_id(31)
	var score := rules.skill_score(combat_spec, pistol)
	if String(score.get("die", "")) != "-d4":
		_fail("Combat Spec chosen specialty die should be -d4 in the skills table, got '%s'." % score.get("die", ""))
	var combat_score: Dictionary = rules.equipment._combat_skill_score(combat_spec, 31)
	if rules._as_int(combat_score.get("step", 0)) != -1:
		_fail("Combat Spec chosen specialty should be -1 step in attack forms, got %d." % combat_score.get("step", 0))

	# Armor Operation specialties are valid Combat Spec bonus targets (PHB p. 30).
	combat_spec["combat_spec_bonus_specialty"] = 1 # Armor Operation-Combat armor
	rules.set_skill_rank(combat_spec, 0, 1)
	rules.set_skill_rank(combat_spec, 1, 1)
	var combat_armor := rules.get_skill_by_id(1)
	if String(rules.skill_score(combat_spec, combat_armor).get("die", "")) != "-d4":
		_fail("Armor Operation-Combat armor should be eligible for the Combat Spec bonus.")

	# A non-chosen specialty gets no bonus.
	var untouched_score: Dictionary = rules.equipment._combat_skill_score(combat_spec, 31)
	if rules._as_int(untouched_score.get("step", 0)) != 0:
		_fail("Non-chosen specialty should have step 0, got %d." % untouched_score.get("step", 0))

	print("Profession rules smoke tests passed.")
	quit(0)
