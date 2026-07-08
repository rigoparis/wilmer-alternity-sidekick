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
	character["abilities"]["WIL"] = 11

	# Human non-Mindwalker: no psionic potential.
	character["species_id"] = 0
	character["profession_id"] = 0
	if rules.is_psionic_character(character):
		_fail("Human Combat Spec should not be psionic.")
	if rules.psionic_energy_points(character) != 0:
		_fail("Non-psionic hero should have 0 psionic energy points.")

	# Human Mindwalker: full WIL.
	character["profession_id"] = 6
	if not rules.is_psionic_character(character):
		_fail("Human Mindwalker should be psionic.")
	if rules.psionic_energy_points(character) != 11:
		_fail("Human Mindwalker energy should equal WIL (11), got %d." % rules.psionic_energy_points(character))

	# Human Diplomat (Mindwalker): full WIL instead of one-half WIL.
	character["profession_id"] = 7
	if not rules.is_psionic_character(character):
		_fail("Diplomat (Mindwalker) should be psionic.")
	if rules.psionic_energy_points(character) != 11:
		_fail("Diplomat (Mindwalker) energy should equal WIL (11), got %d." % rules.psionic_energy_points(character))

	# Fraal talent (non-Mindwalker): full WIL.
	character["species_id"] = 1
	character["profession_id"] = 0
	if not rules.is_psionic_character(character):
		_fail("Fraal hero should be psionic.")
	if rules.psionic_energy_points(character) != 11:
		_fail("Fraal talent energy should equal WIL (11), got %d." % rules.psionic_energy_points(character))

	# Fraal Mindwalker: WIL x 1.5 rounded down.
	character["profession_id"] = 6
	if rules.psionic_energy_points(character) != 16:
		_fail("Fraal Mindwalker energy should be WIL x 1.5 (16), got %d." % rules.psionic_energy_points(character))

	# Diplomat (Mindwalker) profession definition sanity.
	var diplomat_mindwalker := rules.get_profession_by_id(7)
	if String(diplomat_mindwalker.get("name", "")) != "Diplomat (Mindwalker)":
		_fail("Profession id 7 should be Diplomat (Mindwalker).")
	if rules.profession_codes({"profession_id": 7}) != ["D", "M"]:
		_fail("Diplomat (Mindwalker) profession codes should be [D, M].")
	if rules.achievements.achievement_profile_key({"profession_id": 7}) != "diplomat":
		_fail("Diplomat (Mindwalker) should use the diplomat achievement profile.")

	# Mindwalker profession code gives the psionic skill cost discount.
	var biokinesis := rules.get_skill_by_id(900)
	if biokinesis.is_empty():
		_fail("Psionic broad skill 900 (Biokinesis) should exist.")
	var base_price: int = rules._as_int(biokinesis.get("base_price", 0))
	var mindwalker_cost: int = rules.skill_cost({"profession_id": 6}, biokinesis)
	if mindwalker_cost != max(1, base_price - 1):
		_fail("Mindwalker should get the -1 SP discount on psionic skills (base %d, got %d)." % [base_price, mindwalker_cost])
	var secondary_cost: int = rules.skill_cost({"profession_id": 7}, biokinesis)
	if secondary_cost != max(1, base_price - 1):
		_fail("Diplomat (Mindwalker) should get the -1 SP discount on psionic skills (base %d, got %d)." % [base_price, secondary_cost])

	print("Psionic energy smoke tests passed.")
	quit(0)
