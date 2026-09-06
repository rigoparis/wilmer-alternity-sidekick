extends "res://tools/test_harness.gd"
##
## Canonical audit verification for all FX and Non-FX skills against:
## 1. manuals/beyond-science-fx-guide.md
## 2. manuals/alternity-non-fx-skills-guide.md
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Constants := preload("res://scripts/alternity_rules_constants.gd")
const Detail := preload("res://scripts/core/skill_detail.gd")


func _init() -> void:
	begin("skills manual audit")

	var rules = RulesScript.new()
	rules.load_core_data()

	_test_non_fx_catalog_and_structures(rules)
	_test_non_fx_rank_benefits(rules)
	_test_fx_catalog_and_structures(rules)
	_test_fx_attack_and_defense_forms(rules)
	_test_fortitude_vitality_shield(rules)

	finish()


func _test_non_fx_catalog_and_structures(rules: AlternityRules) -> void:
	# Verify all 46 audited skills have structured sections
	var audited_ids: Array = Constants.NON_FX_STRUCTURED_SECTIONS.keys()
	check_eq(Constants.NON_FX_STRUCTURED_SECTIONS.size(), 46, "all 46 skills have structured sections")

	for sid in audited_ids:
		var skill := rules.get_skill_by_id(AlternityNum.as_int(sid))
		check_true(not skill.is_empty(), "Skill %s exists in catalog" % str(sid))
		var detail_dict := rules.skill_detail(skill)
		check_true(detail_dict.has("sections"), "Skill %s has sections" % str(sid))
		var sections: Array = detail_dict.get("sections", [])
		check_true(sections.size() >= 2, "Skill %s has at least 2 sections" % str(sid))

		# Check structured parsing via SkillDetail
		var sd := Detail.from_data(detail_dict)
		check_true(not sd.is_empty(), "SkillDetail parsed sections for skill %s" % str(sid))
		check_true(not sd.find_section("How it is rolled").is_empty(), "Skill %s has 'How it is rolled'" % str(sid))
		check_true(not sd.find_section("Description").is_empty(), "Skill %s has 'Description'" % str(sid))


func _test_non_fx_rank_benefits(rules: AlternityRules) -> void:
	# 1. Pistol Rank 5 Distance Precision
	var pistol := rules.get_skill_by_id(31)
	var pistol_benefits: Dictionary = rules.skill_detail(pistol).get("rank_benefits", {})
	check_true(pistol_benefits.has(5) or pistol_benefits.has("5"), "Pistol has Rank 5 benefit")
	check_true(String(pistol_benefits.get(5, pistol_benefits.get("5", ""))).contains("Distance Precision"), "Pistol Rank 5 is Distance Precision")

	# 2. Set Explosives Rank 4 & 6
	var set_exp := rules.get_skill_by_id(68)
	var set_exp_benefits: Dictionary = rules.skill_detail(set_exp).get("rank_benefits", {})
	check_true(set_exp_benefits.has(4) or set_exp_benefits.has("4"), "Set Explosives has Rank 4 Hidden Charges")
	check_true(set_exp_benefits.has(6) or set_exp_benefits.has("6"), "Set Explosives has Rank 6 Structural Vulnerability")

	# 3. Interrogate Rank 4, 8, 12
	var interrogate := rules.get_skill_by_id(131)
	var int_benefits: Dictionary = rules.skill_detail(interrogate).get("rank_benefits", {})
	check_true(int_benefits.has(4) or int_benefits.has("4"), "Interrogate has Rank 4")
	check_true(int_benefits.has(8) or int_benefits.has("8"), "Interrogate has Rank 8")
	check_true(int_benefits.has(12) or int_benefits.has("12"), "Interrogate has Rank 12")

	# 4. Gamble Rank 1
	var gamble := rules.get_skill_by_id(149)
	var gamble_benefits: Dictionary = rules.skill_detail(gamble).get("rank_benefits", {})
	check_true(gamble_benefits.has(1) or gamble_benefits.has("1"), "Gamble has Rank 1 cheater mechanics")

	# 5. Jump Rank Benefits (3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
	var jump := rules.get_skill_by_id(5)
	var jump_benefits: Dictionary = rules.skill_detail(jump).get("rank_benefits", {})
	for r in [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		check_true(jump_benefits.has(r) or jump_benefits.has(str(r)), "Jump has Rank %d benefit" % r)


func _test_fx_catalog_and_structures(rules: AlternityRules) -> void:
	# Verify Reciprocity
	var reciprocity := rules.fx.get_specialty_skill("Reciprocity")
	check_true(not reciprocity.is_empty(), "Reciprocity exists in fx_core.json")
	check_eq(AlternityNum.as_int(reciprocity.get("cost", 0)), 4, "Reciprocity cost is 4")
	check_eq(String(reciprocity.get("broad_skill", "")), "Hemomancy", "Reciprocity is Hemomancy")
	check_eq(String(reciprocity.get("ability", "")), "CON", "Reciprocity is CON-based")
	check_true(bool(reciprocity.get("untrained", false)), "Reciprocity can be cast untrained")
	check_eq(AlternityNum.as_int(reciprocity.get("fx_cost", 0)), 1, "Reciprocity energy cost is 1")

	# Verify Arcane Magic 24 spells untrained: true
	var arc_schools := ["Diabolism", "Hemomancy", "Hermeticism", "Pyromancy"]
	for sname in arc_schools:
		var broad := rules.fx.get_broad_skill(sname)
		check_true(not broad.is_empty(), "Broad skill %s exists" % sname)
		for sp_name in broad.get("specialties", []):
			var sp := rules.fx.get_specialty_skill(sp_name)
			check_true(bool(sp.get("untrained", false)), "Spell %s under %s is untrained: true" % [sp_name, sname])
			check_true(Detail.is_structured(sp), "Spell %s has structured sections" % sp_name)

	# Verify Monotheism & Brick Powers from beyond-science-fx-guide.md
	for sp_name in ["Aura", "Blessing", "Cure", "Demon ward", "Super Strength", "Body Armor", "Life Support"]:
		var sp := rules.fx.get_specialty_skill(sp_name)
		check_true(not sp.is_empty(), "Power %s exists" % sp_name)
		check_true(Detail.is_structured(sp), "Power %s has structured sections" % sp_name)


func _test_fx_attack_and_defense_forms(rules: AlternityRules) -> void:
	var hero: Dictionary = rules.default_character()
	rules.ensure_character_shape(hero)
	rules.set_perk_selected(hero, "arcane_magic", 3)
	rules.fx.add_fx_skill(hero, "Pyromancy")
	rules.fx.add_fx_skill(hero, "Fiery bolt")
	hero["fx"]["selected_skills"]["Fiery bolt"] = 3
	rules.fx.add_fx_skill(hero, "Cloak of the phoenix")
	hero["fx"]["selected_skills"]["Cloak of the phoenix"] = 2

	# Check attack forms
	var atk_forms := rules.fx.fx_attack_forms(hero)
	var found_bolt := false
	for f in atk_forms:
		if String(f.get("name", "")).contains("Fiery Bolt"):
			found_bolt = true
			break
	check_true(found_bolt, "Fiery Bolt generates an attack form")

	# Check defense forms
	var def_forms := rules.fx.fx_defense_forms(hero)
	var found_cloak := false
	for f in def_forms:
		if String(f.get("name", "")).contains("Cloak of the Phoenix"):
			found_cloak = true
			break
	check_true(found_cloak, "Cloak of the Phoenix generates a defense form")

	# Summary tracks fx_defense_forms
	var sum := rules.summary(hero)
	check_true(sum.has("fx_defense_forms"), "Summary includes fx_defense_forms")
	var sum_def: Array = sum.get("fx_defense_forms", [])
	check_true(sum_def.size() >= 1, "Summary lists at least 1 defense form")


func _test_fortitude_vitality_shield(rules: AlternityRules) -> void:
	var hero: Dictionary = rules.default_character()
	rules.ensure_character_shape(hero)
	# Add temporary durability (e.g. 5 temporary wound points from Fortitude)
	hero["temporary_durability"] = {
		"stun": 0, "max_stun": 0,
		"wound": 0, "max_wound": 5,
		"mortal": 0, "max_mortal": 0,
		"fatigue": 0, "max_fatigue": 0
	}

	# Take 3 wound damage
	var res := rules.apply_damage(hero, 3, "wound")
	var absorbed: Dictionary = res.get("temporary_durability_absorbed", {})
	check_eq(AlternityNum.as_int(absorbed.get("wound", 0)), 3, "Temporary durability absorbed 3 wounds")
	check_eq(AlternityNum.as_int(hero["damage"]["wound"]), 0, "Hero took 0 permanent wounds")
	check_eq(AlternityNum.as_int(hero["temporary_durability"]["wound"]), 3, "Temporary durability has 3 wounds filled")

	# Take 4 more wounds (2 absorbed, 2 hit character, temp shield expires)
	var res2 := rules.apply_damage(hero, 4, "wound")
	var absorbed2: Dictionary = res2.get("temporary_durability_absorbed", {})
	check_eq(AlternityNum.as_int(absorbed2.get("wound", 0)), 2, "Temporary durability absorbed remaining 2 wounds")
	check_eq(AlternityNum.as_int(hero["damage"]["wound"]), 2, "Hero took 2 permanent wounds")
	check_true(not hero.has("temporary_durability"), "Temporary durability expired after being depleted")
