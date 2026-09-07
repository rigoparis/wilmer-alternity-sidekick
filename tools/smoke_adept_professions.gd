extends "res://tools/test_harness.gd"
## Adept profession integration from Beyond Science p. 6, including the
## explicit Dark*Matter crossover choices requested by the GM.

const RulesScript := preload("res://scripts/alternity_rules.gd")

var _rules: AlternityRules


func _init() -> void:
	begin("adept professions")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_complete_profession_catalog()
	_test_universal_profession_availability()
	_test_universal_species_availability()
	_test_adept_benefits()
	_test_diplomat_adept_pool()
	_test_secondary_profession_mechanics()
	_test_dark_matter_crossover()
	_test_talent_limits()

	finish()


func _hero(setting: String = "Core", profession_id: int = 0) -> Dictionary:
	var hero: Dictionary = _rules.default_character()
	hero["setting"] = setting
	hero["profession_id"] = profession_id
	_rules.ensure_character_shape(hero)
	return hero


func _ids(entries: Array) -> Array:
	var result: Array = []
	for entry in entries:
		result.append(AlternityNum.as_int(entry.get("id", -1), -1))
	return result


func _test_complete_profession_catalog() -> void:
	var expected := [
		"Combat Spec", "Diplomat (Combat Spec)", "Diplomat (Free Agent)",
		"Diplomat (Tech Op)", "Free Agent", "Tech Op", "Mindwalker",
		"Diplomat (Mindwalker)", "Diplomat (Adept)", "Adept (Combat Spec)",
		"Adept (Diplomat)", "Adept (Free Agent)", "Adept (Tech Op)",
		"Adept (Mindwalker)", "Non-Professional",
	]
	var actual: Array = []
	for profession in _rules.available_professions(_hero()):
		actual.append(String(profession.get("name", "")))
	check_eq(actual, expected, "all heroic professions, mixes and Non-Professional are listed in legacy order")


func _test_universal_profession_availability() -> void:
	var expected_ids := range(15)
	for setting in ["Core", "Dark*Matter", "Star*Drive"]:
		for beyond_science in [false, true]:
			var hero := _hero(String(setting))
			_rules.set_supplement(hero, "beyond_science", beyond_science)
			check_eq(
				_ids(_rules.available_professions(hero)), expected_ids,
				"%s offers every profession with Beyond Science %s" % [setting, "on" if beyond_science else "off"]
			)

	var dark_mindwalker := _hero("Dark*Matter", 13)
	check_false(
		_rules.validate(dark_mindwalker).any(func(message) -> bool:
			return String(message).contains("no Mindwalker career")),
		"the sheet leaves Dark*Matter profession fit to the GM"
	)


func _test_universal_species_availability() -> void:
	var expected_ids: Array = []
	for entry in _rules.species:
		expected_ids.append(AlternityNum.as_int(entry.get("id", -1), -1))
	for setting in ["Core", "Dark*Matter", "Star*Drive"]:
		for beyond_science in [false, true]:
			var hero := _hero(String(setting))
			_rules.set_supplement(hero, "beyond_science", beyond_science)
			var actual_ids: Array = []
			for entry in _rules.available_species(hero):
				actual_ids.append(AlternityNum.as_int(entry.get("id", -1), -1))
			check_eq(
				actual_ids, expected_ids,
				"%s offers every species with Beyond Science %s" % [setting, "on" if beyond_science else "off"]
			)


func _test_adept_benefits() -> void:
	var adept := _hero("Core", 9)
	check_true(_rules.fx.is_fx_active(adept), "an Adept profession grants FX access")
	check_true(_rules.fx.is_fx_adept(adept), "an Adept profession is a full practitioner")
	check_false(_rules.fx.is_fx_talent(adept), "an Adept profession is not an FX Talent")
	check_eq(_rules.fx.energy_pool(adept), 10, "a heroic-campaign primary Adept starts with 10 FX energy")
	check_eq(AlternityNum.as_int(_rules.action_check(adept).get("ordinary", 0)), 11, "an Adept adds 1 to the base action check")

	var school := "Hermeticism"
	_rules.fx.add_fx_skill(adept, school)
	_rules.fx.set_primary_broad_group(adept, school)
	var broad: Dictionary = _rules.fx.get_broad_skill(school)
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(adept, school, 1),
		maxi(1, AlternityNum.as_int(broad.get("cost", 0)) - 1),
		"the chosen FX broad skill receives the Adept L - 1 discount"
	)
	var specialty: Dictionary = _rules.fx.get_specialty_skills_for_broad(school)[0]
	var specialty_name := String(specialty.get("name", ""))
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(adept, specialty_name, 1),
		maxi(1, AlternityNum.as_int(specialty.get("cost", 0)) - 1),
		"a chosen-school specialty receives the Adept L - 1 discount"
	)

	var other: Dictionary = _rules.fx.get_broad_skill("Pyromancy")
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(adept, "Pyromancy", 1),
		AlternityNum.as_int(other.get("cost", 0)),
		"an Adept's other FX broad skills remain at list price"
	)


func _test_diplomat_adept_pool() -> void:
	var diplomat_adept := _hero("Core", 8)
	check_true(_rules.fx.is_fx_adept(diplomat_adept), "Diplomat (Adept) receives Adept training")
	check_eq(_rules.fx.energy_pool(diplomat_adept), 5, "Diplomat (Adept) keeps the Talent-sized heroic pool")
	check_eq(_rules.achievements.achievement_profile_key(diplomat_adept), "diplomat", "Diplomat (Adept) uses Diplomat benefit costs")
	check_eq(_rules.starting_funds_dice(diplomat_adept), "5d12", "Diplomat (Adept) uses Diplomat starting funds")


func _test_secondary_profession_mechanics() -> void:
	var profiles := {9: "combat_spec", 10: "diplomat", 11: "free_agent", 12: "tech_op", 13: "mindwalker"}
	for profession_id in profiles:
		var adept := _hero("Core", AlternityNum.as_int(profession_id))
		check_eq(
			_rules.achievements.achievement_profile_key(adept), String(profiles[profession_id]),
			"Adept profession %d uses its secondary profession's benefit-cost column" % profession_id
		)

	var combat_adept := _hero("Core", 9)
	var combat_skill: Dictionary = _rules.get_skill_by_id(31) # Modern Ranged Weapons-pistol
	check_eq(
		_rules.skill_cost(combat_adept, combat_skill),
		maxi(1, AlternityNum.as_int(combat_skill.get("base_price", 0)) - 1),
		"Adept (Combat Spec) receives Combat Spec skill prices"
	)
	combat_adept["combat_spec_bonus_specialty"] = 31
	check_eq(
		AlternityNum.as_int(_rules.skill_score(combat_adept, combat_skill).get("step", 0)), 0,
		"a secondary Combat Spec does not receive the primary Combat Spec situation bonus"
	)

	var free_agent_adept := _hero("Core", 11)
	check_eq(AlternityNum.as_int(_rules.last_resorts(free_agent_adept).get("profession_bonus", -1)), 0, "a secondary Free Agent does not receive its primary-profession Last Resort bonus")

	var mindwalker_adept := _hero("Core", 13)
	mindwalker_adept["abilities"]["WIL"] = 12
	check_eq(_rules.psionic_energy_points(mindwalker_adept), 6, "Adept (Mindwalker) tracks a separate secondary-profession PEP pool")
	check_eq(_rules.fx.energy_pool(mindwalker_adept), 10, "Adept (Mindwalker) separately keeps the full FX pool")

	var non_professional := _hero("Core", 14)
	check_eq(AlternityNum.as_int(_rules.action_check(non_professional).get("ordinary", 0)), 10, "Non-Professional receives no action-check increase")
	check_eq(_rules.skill_cost(non_professional, combat_skill), AlternityNum.as_int(combat_skill.get("base_price", 0)), "Non-Professional receives no skill discount")


func _test_dark_matter_crossover() -> void:
	var adept := _hero("Dark*Matter", 9)
	var primary := "Hermeticism"
	var secondary := "Pyromancy"
	_rules.fx.add_fx_skill(adept, primary)
	_rules.fx.set_primary_broad_group(adept, primary)

	var primary_entry: Dictionary = _rules.fx.get_broad_skill(primary)
	var secondary_entry: Dictionary = _rules.fx.get_broad_skill(secondary)
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(adept, primary, 1),
		_rules.fx._listed_cost(adept, primary_entry),
		"Dark*Matter surcharge and Adept discount net to list price in the chosen school"
	)
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(adept, secondary, 1),
		_rules.fx._listed_cost(adept, secondary_entry) + 1,
		"other Dark*Matter FX schools cost list price + 1"
	)
	check_eq(_rules.fx.energy_pool(adept), 10, "a GM-enabled primary Adept in Dark*Matter starts with 10 FX energy")

	var primary_specialty := String(_rules.fx.get_specialty_skills_for_broad(primary)[0].get("name", ""))
	var other_specialty := String(_rules.fx.get_specialty_skills_for_broad(secondary)[0].get("name", ""))
	adept["achievement_level"] = 10
	check_eq(_rules.fx.max_rank_for_fx_skill(adept, primary_specialty), 6, "default crossover caps any chosen-school specialty at Rank 6")
	check_eq(_rules.fx.max_rank_for_fx_skill(adept, other_specialty), 3, "default crossover caps other-school specialties at Rank 3")

	_rules.set_optional_rule(adept, "dm_adept_unrestricted_ranks", true)
	check_eq(_rules.fx.max_rank_for_fx_skill(adept, primary_specialty), 12, "the optional full-rank rule restores the Rank 12 Adept ceiling")
	check_eq(_rules.fx.max_rank_for_fx_skill(adept, other_specialty), 12, "the full-rank rule applies to other Adept specialties too")


func _test_talent_limits() -> void:
	var talent := _hero()
	_rules.fx.set_fx_talent(talent, true)
	check_eq(_rules.fx.energy_pool(talent), 5, "a heroic-campaign FX Talent starts with half the normal pool")
	_rules.fx.add_fx_skill(talent, "Hermeticism")
	_rules.fx.add_fx_skill(talent, "Pyromancy")
	var found := false
	for message in _rules.validate(talent):
		if String(message).contains("only one FX broad skill"):
			found = true
			break
	check_true(found, "an FX Talent cannot take a second FX broad skill")
