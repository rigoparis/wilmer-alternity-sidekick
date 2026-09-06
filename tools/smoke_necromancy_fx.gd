extends "res://tools/test_harness.gd"
##
## Comprehensive test suite for Necromancy FX (Arcane Magic school).
## Tests:
## 1. Verbatim rules catalog entries, SkillDetail sections, rank benefits, and costs.
## 2. Medical Knowledge step bonus synergy on Animate Dead score.
## 3. Zombie control limit (CON) and minion durability bonus (rank 6 & 12).
## 4. Life Force Substitution (2 Fatigue per 1 missing FX).
## 5. Fortitude temporary durability box calculations (Ord, Good, Amazing, Ranks 4, 8, 12).
## 6. Primary and secondary damage absorption into temporary durability tracks.
## 7. Depletion and erasure of temporary durability.
## 8. Scene-end clearing of temporary durability.
## 9. Attack forms (Energy Drain scaling, Zombie minion slam, Mummy's Curse, Steal the Soul).
## 10. Defense forms (Fortitude Vitality Shield, Haunt, Knit Wounds rank 6 upgrade).
## 11. Table session buff propagation and single-document ownership.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const CharacterDocScript := preload("res://scripts/core/character_doc.gd")

var _rules: AlternityRules


func _init() -> void:
	begin("necromancy fx audit")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_catalog_structure()
	_test_medical_knowledge_synergy()
	_test_zombie_mechanics()
	_test_life_force_substitution()
	_test_fortitude_box_calculations()
	_test_fortitude_damage_absorption()
	_test_scene_end_clearing()
	_test_attack_and_defense_forms()
	_test_table_buff_absorption()

	finish()


func _character(con := 12, int_val := 12, wil := 14, per := 10) -> Dictionary:
	var c: Dictionary = _rules.default_character()
	c["abilities"]["CON"] = con
	c["abilities"]["INT"] = int_val
	c["abilities"]["WIL"] = wil
	c["abilities"]["PER"] = per
	_rules.ensure_character_shape(c)
	_rules.fx.set_fx_talent(c, true)
	_rules.fx.set_energy_pool(c, 10)
	return c


func _set_fx_rank(hero: Dictionary, skill_name: String, rank: int) -> void:
	_rules.fx.add_fx_skill(hero, skill_name)
	hero["fx"]["selected_skills"][skill_name] = rank


func _test_catalog_structure() -> void:
	# Broad skill
	var broad: Dictionary = _rules.fx.get_broad_skill("Necromancy")
	check_true(not broad.is_empty(), "Necromancy broad skill exists")
	check_eq(String(broad.get("category", "")), "Arcane Magic", "Necromancy belongs to Arcane Magic pillar")
	check_eq(AlternityNum.as_int(broad.get("cost", 0)), 10, "Necromancy broad costs 10 SP")

	var spells := [
		"Animate dead",
		"Energy drain",
		"Fortitude",
		"Haunt",
		"Knit wounds",
		"Mummy's curse",
		"Speak with dead",
		"Steal the soul",
	]
	var specs: Array = _rules.fx.get_specialty_skills_for_broad("Necromancy")
	check_eq(specs.size(), 8, "Necromancy has exactly 8 spells")

	for spell_name in spells:
		var found := false
		for s in specs:
			if String(s.get("name", "")) == spell_name:
				found = true
				check_true(s.has("sections"), "%s has structured sections" % spell_name)
				var sections: Array = s.get("sections", [])
				check_true(not sections.is_empty(), "%s has sections array" % spell_name)
				check_true(s.has("rank_benefits"), "%s has rank_benefits array" % spell_name)
				check_true(not bool(s.get("untrained", true)), "%s is Trained Only" % spell_name)
				check_true(s.has("ability"), "%s has governing ability" % spell_name)
				break
		check_true(found, "Spell '%s' is present in Necromancy catalog" % spell_name)


func _test_medical_knowledge_synergy() -> void:
	var hero := _character(12, 12, 14, 10)
	hero["achievement_level"] = 10
	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Animate dead", 1)

	# Base score without Medical Knowledge (skill ID 87)
	var base_score: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	var base_step: int = AlternityNum.as_int(base_score.get("step", 0))

	# Rank 1 Medical Knowledge: no bonus
	hero["selected_skills"][str(87)] = 1
	var score_r1: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	check_eq(AlternityNum.as_int(score_r1.get("step", 0)), base_step, "Med Knowledge rank 1 gives 0 step bonus")

	# Rank 2: -1 step bonus
	hero["selected_skills"][str(87)] = 2
	var score_r2: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	check_eq(AlternityNum.as_int(score_r2.get("step", 0)), base_step - 1, "Med Knowledge rank 2 gives -1 step bonus")

	# Rank 5: -2 step bonus
	hero["selected_skills"][str(87)] = 5
	var score_r5: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	check_eq(AlternityNum.as_int(score_r5.get("step", 0)), base_step - 2, "Med Knowledge rank 5 gives -2 step bonus")

	# Rank 8: -3 step bonus
	hero["selected_skills"][str(87)] = 8
	var score_r8: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	check_eq(AlternityNum.as_int(score_r8.get("step", 0)), base_step - 3, "Med Knowledge rank 8 gives -3 step bonus")

	# Rank 12: -4 step bonus
	hero["selected_skills"][str(87)] = 12
	var score_r12: Dictionary = _rules.fx.fx_skill_score(hero, "Animate dead")
	check_eq(AlternityNum.as_int(score_r12.get("step", 0)), base_step - 4, "Med Knowledge rank 12 gives -4 step bonus")


func _test_zombie_mechanics() -> void:
	var hero := _character(14, 10, 12, 10)
	check_eq(_rules.fx.zombie_control_limit(hero), 14, "Zombie control limit equals CON score (14)")

	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Animate dead", 1)
	check_eq(_rules.fx.zombie_durability_bonus(hero), 0, "Animate dead rank 1 gives +0 minion durability bonus")

	_set_fx_rank(hero, "Animate dead", 6)
	check_eq(_rules.fx.zombie_durability_bonus(hero), 1, "Animate dead rank 6 gives +1 minion durability bonus")

	_set_fx_rank(hero, "Animate dead", 12)
	check_eq(_rules.fx.zombie_durability_bonus(hero), 2, "Animate dead rank 12 gives +2 minion durability bonus")


func _test_life_force_substitution() -> void:
	var hero := _character(12, 12, 14, 10)
	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Fortitude", 1)

	# With pool 10 and activation cost 1, no substitution needed
	var sub_check_full: Dictionary = _rules.fx.can_substitute_life_force(hero, 1)
	check_true(not sub_check_full.get("allowed", false), "No life force substitution needed when pool is full")

	# Empty the FX pool
	_rules.fx.spend_energy(hero, 10)
	var sub_check_empty: Dictionary = _rules.fx.can_substitute_life_force(hero, 1)
	check_true(bool(sub_check_empty.get("allowed", false)), "Life force substitution allowed when FX pool is 0")
	check_eq(AlternityNum.as_int(sub_check_empty.get("fatigue_needed", 0)), 2, "1 missing FX point requires 2 Fatigue points")

	# If character already took max fatigue, cannot substitute
	var dur: Dictionary = _rules.durability(hero)
	var max_fat: int = AlternityNum.as_int(dur.get("fatigue", 12))
	var dmg: Dictionary = hero.get("damage", {})
	dmg["fatigue"] = max_fat
	hero["damage"] = dmg

	var sub_check_dead: Dictionary = _rules.fx.can_substitute_life_force(hero, 1)
	check_true(not sub_check_dead.get("allowed", false), "Life force substitution disallowed when fatigue track is full")


func _test_fortitude_box_calculations() -> void:
	var hero := _character(12, 12, 14, 10)
	_set_fx_rank(hero, "Necromancy", 1)

	# Base Rank 1
	_set_fx_rank(hero, "Fortitude", 1)
	var ord: Dictionary = _rules.fx.fortitude_boxes(hero, "Ordinary")
	check_eq(AlternityNum.as_int(ord.get("stun", 0)), 2, "Ordinary: +2 stun")
	check_eq(AlternityNum.as_int(ord.get("wound", 0)), 1, "Ordinary: +1 wound")
	check_eq(AlternityNum.as_int(ord.get("mortal", 0)), 0, "Ordinary: +0 mortal")
	check_eq(AlternityNum.as_int(ord.get("fatigue", 0)), 0, "Ordinary: +0 fatigue")

	var good: Dictionary = _rules.fx.fortitude_boxes(hero, "Good")
	check_eq(AlternityNum.as_int(good.get("stun", 0)), 3, "Good: +3 stun")
	check_eq(AlternityNum.as_int(good.get("wound", 0)), 2, "Good: +2 wound")
	check_eq(AlternityNum.as_int(good.get("mortal", 0)), 1, "Good: +1 mortal")
	check_eq(AlternityNum.as_int(good.get("fatigue", 0)), 0, "Good: +0 fatigue")

	var amaz: Dictionary = _rules.fx.fortitude_boxes(hero, "Amazing")
	check_eq(AlternityNum.as_int(amaz.get("stun", 0)), 4, "Amazing: +4 stun")
	check_eq(AlternityNum.as_int(amaz.get("wound", 0)), 3, "Amazing: +3 wound")
	check_eq(AlternityNum.as_int(amaz.get("mortal", 0)), 2, "Amazing: +2 mortal")
	check_eq(AlternityNum.as_int(amaz.get("fatigue", 0)), 2, "Amazing: +2 fatigue")

	# Rank 4 scaling (+1 bonus to all tracks)
	_set_fx_rank(hero, "Fortitude", 4)
	var ord_r4: Dictionary = _rules.fx.fortitude_boxes(hero, "Ordinary")
	check_eq(AlternityNum.as_int(ord_r4.get("stun", 0)), 3, "Rank 4 Ordinary: 2+1 = 3 stun")
	check_eq(AlternityNum.as_int(ord_r4.get("wound", 0)), 2, "Rank 4 Ordinary: 1+1 = 2 wound")
	check_eq(AlternityNum.as_int(ord_r4.get("mortal", 0)), 1, "Rank 4 Ordinary: 0+1 = 1 mortal")
	check_eq(AlternityNum.as_int(ord_r4.get("fatigue", 0)), 1, "Rank 4 Ordinary: 0+1 = 1 fatigue")

	# Rank 8 scaling (+2 bonus to all tracks)
	_set_fx_rank(hero, "Fortitude", 8)
	var good_r8: Dictionary = _rules.fx.fortitude_boxes(hero, "Good")
	check_eq(AlternityNum.as_int(good_r8.get("stun", 0)), 5, "Rank 8 Good: 3+2 = 5 stun")
	check_eq(AlternityNum.as_int(good_r8.get("wound", 0)), 4, "Rank 8 Good: 2+2 = 4 wound")
	check_eq(AlternityNum.as_int(good_r8.get("mortal", 0)), 3, "Rank 8 Good: 1+2 = 3 mortal")

	# Rank 12 scaling (+3 bonus to all tracks)
	_set_fx_rank(hero, "Fortitude", 12)
	var amaz_r12: Dictionary = _rules.fx.fortitude_boxes(hero, "Amazing")
	check_eq(AlternityNum.as_int(amaz_r12.get("stun", 0)), 7, "Rank 12 Amazing: 4+3 = 7 stun")
	check_eq(AlternityNum.as_int(amaz_r12.get("wound", 0)), 6, "Rank 12 Amazing: 3+3 = 6 wound")
	check_eq(AlternityNum.as_int(amaz_r12.get("mortal", 0)), 5, "Rank 12 Amazing: 2+3 = 5 mortal")
	check_eq(AlternityNum.as_int(amaz_r12.get("fatigue", 0)), 5, "Rank 12 Amazing: 2+3 = 5 fatigue")


func _test_fortitude_damage_absorption() -> void:
	var hero := _character(12, 12, 14, 10)
	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Fortitude", 1)

	# Apply Good Fortitude (3 stun, 2 wound, 1 mortal, 0 fatigue)
	var applied: Dictionary = _rules.fx.apply_fortitude(hero, "Good", 1)
	check_true(hero.has("temporary_durability"), "Character has temporary_durability field")
	check_eq(AlternityNum.as_int(applied.get("max_stun", 0)), 3, "Shield max stun = 3")
	check_eq(AlternityNum.as_int(applied.get("max_wound", 0)), 2, "Shield max wound = 2")
	check_eq(AlternityNum.as_int(applied.get("max_mortal", 0)), 1, "Shield max mortal = 1")

	# 1. Take 2 points of stun damage
	_rules.apply_damage(hero, 2, "stun")
	var t1: Dictionary = hero.get("temporary_durability", {})
	check_eq(AlternityNum.as_int(t1.get("stun", 0)), 2, "Temp durability absorbed 2 stun")
	var base_dmg1: Dictionary = hero.get("damage", {})
	check_eq(AlternityNum.as_int(base_dmg1.get("stun", 0)), 0, "Base character stun is still 0")

	# 2. Take 2 points of wound damage
	# In Alternity, taking 2 wound also does secondary stun (2 wound / 2 = 1 secondary stun).
	# Temp durability has 1 stun remaining (3 - 2 = 1) and 2 wound remaining (2 - 0 = 2).
	_rules.apply_damage(hero, 2, "wound")
	var t2: Dictionary = hero.get("temporary_durability", {})
	check_eq(AlternityNum.as_int(t2.get("wound", 0)), 2, "Temp durability absorbed 2 wound (now full)")
	check_eq(AlternityNum.as_int(t2.get("stun", 0)), 3, "Temp durability absorbed secondary stun (now full)")
	var base_dmg2: Dictionary = hero.get("damage", {})
	check_eq(AlternityNum.as_int(base_dmg2.get("wound", 0)), 0, "Base character wound is still 0")
	check_eq(AlternityNum.as_int(base_dmg2.get("stun", 0)), 0, "Base character stun is still 0")

	# 3. Take 1 more point of wound damage: temp wound is already full (2/2), so it spills over into base track!
	_rules.apply_damage(hero, 1, "wound")
	var base_dmg3: Dictionary = hero.get("damage", {})
	check_eq(AlternityNum.as_int(base_dmg3.get("wound", 0)), 1, "Overflow wound hit base character wound track")

	# 4. Take 1 mortal damage: temp mortal has 1 box (0/1 used), so it absorbs it
	_rules.apply_damage(hero, 1, "mortal")
	var base_dmg4: Dictionary = hero.get("damage", {})
	check_eq(AlternityNum.as_int(base_dmg4.get("mortal", 0)), 0, "Base mortal is still 0 (absorbed by temp mortal)")

	# Now all temp tracks (stun 3/3, wound 2/2, mortal 1/1) are depleted!
	# The temporary_durability dictionary must be erased!
	check_true(not hero.has("temporary_durability"), "Temporary durability erased once fully depleted")


func _test_scene_end_clearing() -> void:
	var hero := _character(12, 12, 14, 10)
	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Fortitude", 4)

	_rules.fx.apply_fortitude(hero, "Amazing", 4)
	check_true(hero.has("temporary_durability"), "Temporary durability present before scene end")

	# End scene
	_rules.combat.end_scene(hero)
	check_true(not hero.has("temporary_durability"), "Temporary durability cleared when scene ends")


func _test_attack_and_defense_forms() -> void:
	var hero := _character(14, 12, 14, 10)
	_set_fx_rank(hero, "Necromancy", 1)
	_set_fx_rank(hero, "Energy drain", 1)
	_set_fx_rank(hero, "Animate dead", 1)
	_set_fx_rank(hero, "Mummy's curse", 1)
	_set_fx_rank(hero, "Steal the soul", 1)
	_set_fx_rank(hero, "Fortitude", 1)
	_set_fx_rank(hero, "Haunt", 1)
	_set_fx_rank(hero, "Knit wounds", 1)

	# 1. Attack forms
	var atk_forms: Array = _rules.fx.fx_attack_forms(hero)
	check_eq(atk_forms.size(), 4, "4 attack forms generated for offensive Necromancy spells")

	# Energy Drain scaling
	_set_fx_rank(hero, "Energy drain", 1)
	var atk_r1: Array = _rules.fx.fx_attack_forms(hero)
	check_eq(String(atk_r1[0].get("damage", "")), "d4+1s/d6+2s/d4+1w", "Energy drain rank 1 damage")

	_set_fx_rank(hero, "Energy drain", 5)
	var atk_r5: Array = _rules.fx.fx_attack_forms(hero)
	check_eq(String(atk_r5[0].get("damage", "")), "d6+2s/d8+3s/d4+2f", "Energy drain rank 5 damage")

	_set_fx_rank(hero, "Energy drain", 9)
	var atk_r9: Array = _rules.fx.fx_attack_forms(hero)
	check_eq(String(atk_r9[0].get("damage", "")), "d8+2s/d12+3s/d4+3f", "Energy drain rank 9 damage")

	# Check integration with equipment.attack_forms_for_character
	var combined_attacks: Array = _rules.equipment.attack_forms_for_character(hero)
	var has_energy_drain := false
	for a in combined_attacks:
		if String(a.get("name", "")) == "Energy Drain":
			has_energy_drain = true
			break
	check_true(has_energy_drain, "Energy Drain appears in equipment attack_forms_for_character")

	# 2. Defense forms
	var def_forms: Array = _rules.fx.fx_defense_forms(hero)
	check_eq(def_forms.size(), 3, "3 defense forms generated (Fortitude, Haunt, Knit Wounds)")

	var fort_form: Dictionary = def_forms[0]
	check_eq(String(fort_form.get("name", "")), "Fortitude", "First defense form is Fortitude")
	check_true(bool(fort_form.get("can_activate", false)), "Fortitude can be activated")

	var haunt_form: Dictionary = def_forms[1]
	check_eq(String(haunt_form.get("name", "")), "Haunt", "Second defense form is Haunt")

	var knit_form: Dictionary = def_forms[2]
	check_eq(String(knit_form.get("name", "")), "Knit Wounds", "Third defense form is Knit Wounds")
	check_true(String(knit_form.get("benefit", "")).begins_with("Heals wound damage"), "Knit Wounds rank 1 heals wound")

	_set_fx_rank(hero, "Knit wounds", 6)
	var def_r6: Array = _rules.fx.fx_defense_forms(hero)
	check_true(String(def_r6[2].get("benefit", "")).begins_with("Heals mortal/wound"), "Knit Wounds rank 6 heals mortal or wound")


func _test_table_buff_absorption() -> void:
	var hero := _character(12, 12, 14, 10)
	hero["hero_name"] = "Gideon"
	var doc := CharacterDocScript.new(_rules, hero)

	var changed_sections: Array = []
	doc.changed.connect(func(sections): changed_sections.append_array(sections))

	# Simulate TableSession receiving a buff event for this character
	var buff_payload := {
		"skill_name": "Fortitude",
		"degree": "Good",
		"rank": 2,
		"caster_name": "Valerius",
		"target_player_id": "player-123",
		"temporary_durability": {
			"source": "Fortitude",
			"degree": "Good",
			"rank": 2,
			"stun": 0,
			"wound": 0,
			"mortal": 0,
			"fatigue": 0,
			"max_stun": 3,
			"max_wound": 2,
			"max_mortal": 1,
			"max_fatigue": 0,
		}
	}

	# Apply buff locally via CharacterDoc mutation (matching single document ownership)
	doc.apply([CharacterDocScript.DAMAGE], func(c: Dictionary):
		c["temporary_durability"] = buff_payload.get("temporary_durability", {}).duplicate(true)
	)

	check_true(doc.raw().has("temporary_durability"), "Target character now holds temporary durability")
	check_eq(AlternityNum.as_int(doc.raw().get("temporary_durability", {}).get("max_wound", 0)), 2, "Target character has max_wound = 2 in shield")
	check_true(changed_sections.has("damage"), "CharacterDoc announced 'damage' section change to listeners")
