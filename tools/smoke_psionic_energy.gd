extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")


func _init() -> void:
	begin("psionic energy")

	var rules = RulesScript.new()
	rules.load_core_data()

	var character := rules.default_character()
	rules.ensure_character_shape(character)
	character["abilities"]["WIL"] = 11

	# Human Combat Spec: no psionic potential at all.
	character["species_id"] = 0
	character["profession_id"] = 0
	check_false(rules.is_psionic_character(character), "Human Combat Spec is not psionic")
	check_eq(rules.psionic_energy_points(character), 0, "non-psionic hero has 0 energy points")

	# Human Mindwalker: full WIL.
	character["profession_id"] = 6
	check_true(rules.is_psionic_character(character), "Human Mindwalker is psionic")
	check_eq(rules.psionic_energy_points(character), 11, "Human Mindwalker energy equals WIL")

	# Diplomat (Mindwalker): full WIL, not one-half WIL.
	character["profession_id"] = 7
	check_true(rules.is_psionic_character(character), "Diplomat (Mindwalker) is psionic")
	check_eq(rules.psionic_energy_points(character), 11, "Diplomat (Mindwalker) energy equals WIL")

	# Fraal talent without the Mindwalker profession: full WIL.
	character["species_id"] = 1
	character["profession_id"] = 0
	check_true(rules.is_psionic_character(character), "Fraal hero is psionic")
	check_eq(rules.psionic_energy_points(character), 11, "Fraal talent energy equals WIL")

	# Fraal Mindwalker: WIL x 1.5, rounded down.
	character["profession_id"] = 6
	check_eq(rules.psionic_energy_points(character), 16, "Fraal Mindwalker energy is WIL x 1.5")

	# Diplomat (Mindwalker) profession definition.
	var diplomat_mindwalker := rules.get_profession_by_id(7)
	check_eq(
		String(diplomat_mindwalker.get("name", "")), "Diplomat (Mindwalker)",
		"profession id 7 name"
	)
	check_eq(rules.profession_codes({"profession_id": 7}), ["D", "M"], "Diplomat (Mindwalker) codes")
	check_eq(
		rules.achievements.achievement_profile_key({"profession_id": 7}), "diplomat",
		"Diplomat (Mindwalker) uses the diplomat achievement profile"
	)

	# The Mindwalker code grants a -1 SP discount on psionic skills.
	var biokinesis := rules.get_skill_by_id(900)
	if check_false(biokinesis.is_empty(), "psionic broad skill 900 (Biokinesis) exists"):
		var base_price: int = rules._as_int(biokinesis.get("base_price", 0))
		var expected: int = max(1, base_price - 1)
		check_eq(
			rules.skill_cost({"profession_id": 6}, biokinesis), expected,
			"Mindwalker psionic skill discount (base %d)" % base_price
		)
		check_eq(
			rules.skill_cost({"profession_id": 7}, biokinesis), expected,
			"Diplomat (Mindwalker) psionic skill discount (base %d)" % base_price
		)

	finish()
