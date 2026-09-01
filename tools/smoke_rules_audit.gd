extends "res://tools/test_harness.gd"

# Exhaustive rules audit testing all Core tables (P1-P30, G1-G21), Species & Profession mechanics,
# Ability feats, Passive/Active architecture, Encumbrance, Check resolution, and Damage propagation.
#
# Reports through the shared harness (tools/test_harness.gd) so run_tests.sh sees the
# same "[suite] passed (N checks)" line as every other suite. assert_eq / assert_true
# stay as thin forwarders so the call sites below read unchanged.

func _init() -> void:
	begin("rules audit")
	var rules := AlternityRules.new()
	rules.load_core_data()

	var assert_eq = func(actual, expected, msg: String):
		check_eq(actual, expected, msg)

	var assert_true = func(cond: bool, msg: String):
		check_true(cond, msg)

	# --- 1. Check Resolution & Degrees of Success ---
	print("Testing Core Check Resolution...")
	var r1: Dictionary = rules.resolve_check(15, 0, 14, "+d0") # 15 vs 14 -> Marginal (14+1)
	assert_eq.call(r1.degree, "Marginal", "15 vs 14 allow_marginal is Marginal")
	var r2: Dictionary = rules.resolve_check(16, 0, 14, "+d0") # 16 vs 14 -> Failure
	assert_eq.call(r2.degree, "Failure", "16 vs 14 is Failure")
	var r3: Dictionary = rules.resolve_check(12, 0, 14, "+d0") # 12 vs 14 -> Ordinary
	assert_eq.call(r3.degree, "Ordinary", "12 vs 14 is Ordinary")
	var r4: Dictionary = rules.resolve_check(7, 0, 14, "+d0") # 7 vs 14 -> Good (<= 7)
	assert_eq.call(r4.degree, "Good", "7 vs 14 is Good")
	var r5: Dictionary = rules.resolve_check(3, 0, 14, "+d0") # 3 vs 14 -> Amazing (<= 3)
	assert_eq.call(r5.degree, "Amazing", "3 vs 14 is Amazing")
	var r6: Dictionary = rules.resolve_check(20, -5, 18, "-d6") # Nat 20 is always Critical Failure
	assert_eq.call(r6.degree, "Critical Failure", "Natural 20 is always Critical Failure")
	var r7: Dictionary = rules.resolve_check(1, 15, 10, "+d12") # Nat 1 with +d12 is Auto Success
	assert_eq.call(r7.degree, "Ordinary", "Nat 1 with +d12 is Automatic Ordinary Success")
	var r8: Dictionary = rules.resolve_check(1, 15, 10, "+d20") # Nat 1 with +d20 is NOT Auto Success
	assert_eq.call(r8.degree, "Failure", "Nat 1 with +d20 is not auto success when total 16 > 10")

	# --- 2. Table P1: Profession Ability Minimums ---
	print("Testing Table P1 Profession Minimums...")
	var combat_spec: Dictionary = rules.get_profession_by_id(0) # Combat Spec
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("STR", 0)), 11, "Combat Spec STR min 11")
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("DEX", 0)), 9, "Combat Spec DEX min 9")
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("CON", 0)), 9, "Combat Spec CON min 9")

	var tech_op: Dictionary = rules.get_profession_by_id(5) # Tech Op
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("INT", 0)), 11, "Tech Op INT min 11")
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("DEX", 0)), 9, "Tech Op DEX min 9")
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("CON", 0)), 9, "Tech Op CON min 9")

	var diplomat: Dictionary = rules.get_profession_by_id(2) # Diplomat
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("INT", 0)), 9, "Diplomat INT min 9")
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("WIL", 0)), 9, "Diplomat WIL min 9")
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("PER", 0)), 11, "Diplomat PER min 11")

	var free_agent: Dictionary = rules.get_profession_by_id(4) # Free Agent
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("DEX", 0)), 11, "Free Agent DEX min 11")
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("INT", 0)), 9, "Free Agent INT min 9")
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("WIL", 0)), 9, "Free Agent WIL min 9")

	var mindwalker: Dictionary = rules.get_profession_by_id(6) # Mindwalker
	assert_eq.call(rules._as_int(mindwalker.get("ability_minimums", {}).get("WIL", 0)), 11, "Mindwalker WIL min 11")
	assert_eq.call(rules._as_int(mindwalker.get("ability_minimums", {}).get("INT", 0)), 9, "Mindwalker INT min 9")
	assert_eq.call(rules._as_int(mindwalker.get("ability_minimums", {}).get("CON", 0)), 9, "Mindwalker CON min 9")

	# --- 3. Table P2: Resistance Modifiers ---
	print("Testing Table P2 Resistance Modifiers...")
	assert_eq.call(rules.resistance_modifier(4), -2, "RM for stat 4 is -2")
	assert_eq.call(rules.resistance_modifier(5), -1, "RM for stat 5 is -1")
	assert_eq.call(rules.resistance_modifier(6), -1, "RM for stat 6 is -1")
	assert_eq.call(rules.resistance_modifier(7), 0, "RM for stat 7 is 0")
	assert_eq.call(rules.resistance_modifier(10), 0, "RM for stat 10 is 0")
	assert_eq.call(rules.resistance_modifier(11), 1, "RM for stat 11 is +1")
	assert_eq.call(rules.resistance_modifier(12), 1, "RM for stat 12 is +1")
	assert_eq.call(rules.resistance_modifier(13), 2, "RM for stat 13 is +2")
	assert_eq.call(rules.resistance_modifier(14), 2, "RM for stat 14 is +2")
	assert_eq.call(rules.resistance_modifier(15), 3, "RM for stat 15 is +3")
	assert_eq.call(rules.resistance_modifier(16), 3, "RM for stat 16 is +3")
	assert_eq.call(rules.resistance_modifier(17), 4, "RM for stat 17 is +4")
	assert_eq.call(rules.resistance_modifier(18), 4, "RM for stat 18 is +4")
	assert_eq.call(rules.resistance_modifier(19), 5, "RM for stat 19 is +5")

	# --- 4. Table P5: Starting Skill Points & Broad Skills Cap ---
	print("Testing Table P5 Starting Skill Points & Broad Cap...")
	# Human INT 10: SP = 50, Broad Cap = 6 (10/2 + 1)
	var human_hero: Dictionary = rules.default_character()
	human_hero["species_id"] = 0 # Human
	human_hero["abilities"]["INT"] = 10
	rules.ensure_character_shape(human_hero)
	assert_eq.call(rules.starting_skill_budget(human_hero), 50, "Human INT 10 Starting SP = 50")
	assert_eq.call(rules.additional_broad_skill_limit(human_hero), 6, "Human INT 10 Additional Broad Allowance = 6")
	assert_eq.call(rules.max_broad_skills(human_hero), 12, "Human INT 10 Total Broad Cap = 6 racial + 6 additional = 12")

	# Alien (Fraal) INT 10: SP = 45 (10*5 - 5), Broad Cap = 5 (10/2)
	var fraal_hero: Dictionary = rules.default_character()
	fraal_hero["species_id"] = 1 # Fraal
	fraal_hero["abilities"]["INT"] = 10
	rules.ensure_character_shape(fraal_hero)
	assert_eq.call(rules.starting_skill_budget(fraal_hero), 45, "Fraal INT 10 Starting SP = 45")
	assert_eq.call(rules.additional_broad_skill_limit(fraal_hero), 5, "Fraal INT 10 Additional Broad Allowance = 5")
	assert_eq.call(rules.max_broad_skills(fraal_hero), 11, "Fraal INT 10 Total Broad Cap = 6 racial + 5 additional = 11")

	# Alien (Weren) INT 12: SP = 55 (12*5 - 5), Additional Broad = 6 (12/2)
	var weren_hero: Dictionary = rules.default_character()
	weren_hero["species_id"] = 5 # Weren
	weren_hero["abilities"]["INT"] = 12
	rules.ensure_character_shape(weren_hero)
	assert_eq.call(rules.starting_skill_budget(weren_hero), 55, "Weren INT 12 Starting SP = 55")
	assert_eq.call(rules.additional_broad_skill_limit(weren_hero), 6, "Weren INT 12 Additional Broad Allowance = 6")

	# Specialty skill rank cap: Rank 3 at creation (Level 1)
	assert_eq.call(rules.max_skill_rank_for_character(human_hero), 3, "Level 1 hero specialty skill cap is Rank 3")
	human_hero["achievement_level"] = 2
	assert_eq.call(rules.max_skill_rank_for_character(human_hero), 4, "Level 2 hero specialty skill cap is Rank 4")
	human_hero["achievement_level"] = 10
	assert_eq.call(rules.max_skill_rank_for_character(human_hero), 12, "Level 10 hero specialty skill cap is Rank 12")

	# --- 5. Table P6: Last Resort Points & Recovery Costs ---
	print("Testing Table P6 Last Resort Points & Recovery Costs...")
	var lr7: Dictionary = rules._last_resort_base(7)
	assert_eq.call(lr7.max, 0, "PER 7 max LR = 0")
	var lr10: Dictionary = rules._last_resort_base(10)
	assert_eq.call(lr10.max, 1, "PER 10 max LR = 1")
	assert_eq.call(lr10.cost, 3, "PER 10 recovery cost = 3 SP")
	var lr12: Dictionary = rules._last_resort_base(12)
	assert_eq.call(lr12.max, 2, "PER 12 max LR = 2")
	assert_eq.call(lr12.cost, 2, "PER 12 recovery cost = 2 SP")
	var lr14: Dictionary = rules._last_resort_base(14)
	assert_eq.call(lr14.max, 3, "PER 14 max LR = 3")
	assert_eq.call(lr14.cost, 1, "PER 14 recovery cost = 1 SP")
	var lr16: Dictionary = rules._last_resort_base(16)
	assert_eq.call(lr16.max, 4, "PER 16 max LR = 4")
	assert_eq.call(lr16.cost, 1, "PER 16 recovery cost = 1 SP")

	# --- 6. Table P7: Actions Per Round ---
	print("Testing Table P7 Actions Per Round...")
	var test_char: Dictionary = rules.default_character()
	test_char["species_id"] = 0 # Human (CON 4-14, WIL 4-14)
	rules.ensure_character_shape(test_char)
	test_char["abilities"]["CON"] = 7
	test_char["abilities"]["WIL"] = 8 # 15 -> 1
	assert_eq.call(rules.actions_per_round(test_char), 1, "CON+WIL 15 = 1 action")
	test_char["abilities"]["WIL"] = 9 # 16 -> 2
	assert_eq.call(rules.actions_per_round(test_char), 2, "CON+WIL 16 = 2 actions")
	test_char["abilities"]["CON"] = 11
	test_char["abilities"]["WIL"] = 12 # 23 -> 2
	assert_eq.call(rules.actions_per_round(test_char), 2, "CON+WIL 23 = 2 actions")
	test_char["abilities"]["CON"] = 12
	test_char["abilities"]["WIL"] = 12 # 24 -> 3
	assert_eq.call(rules.actions_per_round(test_char), 3, "CON+WIL 24 = 3 actions")
	test_char["abilities"]["CON"] = 14
	test_char["abilities"]["WIL"] = 14 # 28 -> 3
	assert_eq.call(rules.actions_per_round(test_char), 3, "CON+WIL 28 = 3 actions")
	
	# Test with achievement extra_action bonus (reaches 4 actions)
	test_char["selected_achievements"] = [{"achievement_id": "extra_action"}]
	assert_eq.call(rules.actions_per_round(test_char), 4, "3 actions + extra_action achievement = 4 actions")

	# --- 7. Table P8: Combat Movement Rates ---
	print("Testing Table P8 Movement Rates...")
	test_char["selected_achievements"] = []
	test_char["abilities"]["STR"] = 10
	test_char["abilities"]["DEX"] = 10 # Total 20
	var mov: Dictionary = rules.movement(test_char)
	assert_eq.call(mov.sprint, 20, "STR+DEX 20 Sprint = 20")
	assert_eq.call(mov.run, 12, "STR+DEX 20 Run = 12")
	assert_eq.call(mov.walk, 4, "STR+DEX 20 Walk = 4")
	assert_eq.call(mov.easy_swim, 2, "STR+DEX 20 Easy Swim = 2")
	assert_eq.call(mov.swim, 4, "STR+DEX 20 Swim = 4")

	# Sesheyan gliding & flying
	var sesheyan: Dictionary = rules.default_character()
	sesheyan["species_id"] = 3 # Sesheyan
	sesheyan["abilities"]["STR"] = 10
	sesheyan["abilities"]["DEX"] = 10 # Total 20
	rules.ensure_character_shape(sesheyan)
	var sesh_mov: Dictionary = rules.movement(sesheyan)
	assert_eq.call(sesh_mov.glide, "20", "Sesheyan Glide = Sprint (20)")
	assert_eq.call(sesh_mov.fly, "40", "Sesheyan Fly = 2x Sprint (40)")

	# --- 8. Table P9: Strength Damage Adjustment ---
	print("Testing Table P9 Strength Damage Adjustment...")
	assert_eq.call(rules.equipment.strength_damage_bonus(6), -1, "STR 6 dmg bonus = -1")
	assert_eq.call(rules.equipment.strength_damage_bonus(10), 0, "STR 10 dmg bonus = 0")
	assert_eq.call(rules.equipment.strength_damage_bonus(11), 1, "STR 11 dmg bonus = +1")
	assert_eq.call(rules.equipment.strength_damage_bonus(12), 1, "STR 12 dmg bonus = +1")
	assert_eq.call(rules.equipment.strength_damage_bonus(13), 2, "STR 13 dmg bonus = +2")
	assert_eq.call(rules.equipment.strength_damage_bonus(14), 2, "STR 14 dmg bonus = +2")
	assert_eq.call(rules.equipment.strength_damage_bonus(15), 3, "STR 15 dmg bonus = +3")
	assert_eq.call(rules.equipment.strength_damage_bonus(16), 3, "STR 16 dmg bonus = +3")
	assert_eq.call(rules.equipment.strength_damage_bonus(17), 4, "STR 17 dmg bonus = +4")
	assert_eq.call(rules.equipment.strength_damage_bonus(18), 4, "STR 18 dmg bonus = +4")
	assert_eq.call(rules.equipment.strength_damage_bonus(19), 5, "STR 19 dmg bonus = +5")

	# --- 9. Table P12: Encumbrance ---
	print("Testing Table P12 Encumbrance...")
	var enc_char: Dictionary = rules.default_character()
	enc_char["abilities"]["STR"] = 10 # light limit 20kg, heavy 40kg, severe 50kg, extreme 60kg
	rules.ensure_character_shape(enc_char)
	assert_eq.call(rules.encumbrance(enc_char).tier, "Normal", "0kg is Normal encumbrance")
	assert_eq.call(rules.encumbrance(enc_char).penalty, 0, "0kg penalty is 0")
	assert_eq.call(rules.encumbrance(enc_char).movement_multiplier, 1.0, "0kg movement mult is 1.0")

	# Add 30kg carried custom item (Heavy tier: <= 40kg)
	rules.equipment.add_custom_equipment_to_character(enc_char, {
		"name": "Heavy Pack",
		"type": "gear",
		"mass": 30.0,
		"cost": 100,
		"durability": "d4w",
	}, 1)
	rules.ensure_character_shape(enc_char)
	var enc30: Dictionary = rules.encumbrance(enc_char)
	assert_eq.call(enc30.tier, "Heavy", "30kg for STR 10 is Heavy")
	assert_eq.call(enc30.penalty, 1, "Heavy penalty is +1 step to STR/DEX")
	assert_eq.call(enc30.movement_multiplier, 0.75, "Heavy movement mult is 0.75")
	assert_eq.call(rules.character_resistance_modifier(enc_char, "STR"), -1, "STR RM reduced by 1 under Heavy load")
	assert_eq.call(rules.character_resistance_modifier(enc_char, "DEX"), -1, "DEX RM reduced by 1 under Heavy load")
	assert_eq.call(rules.character_resistance_modifier(enc_char, "INT"), 0, "INT RM unaffected by encumbrance")

	# --- 10. Age Modifiers ---
	print("Testing Age Modifiers...")
	var mature_char: Dictionary = rules.default_character()
	mature_char["species_id"] = 0 # Human (limits 4-14)
	mature_char["abilities"]["INT"] = 10
	mature_char["abilities"]["PER"] = 10
	mature_char["age_category"] = "mature" # +1 INT, +1 PER
	rules.ensure_character_shape(mature_char)
	var mature_eff: Dictionary = rules.effective_abilities(mature_char)
	assert_eq.call(mature_eff.INT, 11, "Mature Human INT 10 -> 11")
	assert_eq.call(mature_eff.PER, 11, "Mature Human PER 10 -> 11")
	assert_eq.call(mature_eff.STR, 10, "Mature Human STR unchanged")

	# Clamping to species max
	var max_int_char: Dictionary = rules.default_character()
	max_int_char["species_id"] = 0 # Human max INT is 14
	max_int_char["abilities"]["INT"] = 14
	max_int_char["age_category"] = "mature"
	rules.ensure_character_shape(max_int_char)
	assert_eq.call(rules.effective_abilities(max_int_char).INT, 14, "Mature age bonus cannot exceed species max (14)")

	# --- 11. Damage Propagation & Overflow ---
	print("Testing Damage Propagation & Overflow...")
	var dmg_char: Dictionary = rules.default_character()
	dmg_char["abilities"]["CON"] = 10 # Durability: Stun 10, Wound 10, Mortal 5, Fatigue 5
	rules.ensure_character_shape(dmg_char)
	var res1: Dictionary = rules.apply_damage(dmg_char, 6, "wound", 0)
	assert_eq.call(dmg_char.damage.wound, 6, "Wound damage applied: 6")
	assert_eq.call(dmg_char.damage.stun, 3, "Secondary stun from 6 wound: 3")

	rules.apply_damage(dmg_char, 8, "wound", 0)
	assert_eq.call(dmg_char.damage.wound, 10, "Wound clamped to max 10")
	assert_eq.call(dmg_char.damage.mortal, 2, "Overflow wound converted 2:1 to mortal (2)")
	assert_eq.call(dmg_char.damage.stun, 7, "Stun damage accumulated to 7")

	# --- 12. Section 1 Species Specific Features ---
	print("Testing Species Features...")
	# T'sa Natural Armor (d4+1 LI, d4 HI, d4-1 En)
	var tsa_char: Dictionary = rules.default_character()
	tsa_char["species_id"] = 4 # T'sa
	rules.ensure_character_shape(tsa_char)
	var tsa_eq: Dictionary = rules.equipment.equipment_summary(tsa_char)
	var has_tsa_armor := false
	for armor in tsa_eq.combat_armor:
		var it: Dictionary = armor.get("item", {})
		if it.get("armor_li", "") == "d4+1" and it.get("armor_hi", "") == "d4" and it.get("armor_en", "") == "d4-1":
			has_tsa_armor = true
	assert_true.call(has_tsa_armor, "T'sa has natural scaled hide armor in equipment summary")

	# Weren Natural Claws (d4w/d4+2w/d4m + STR bonus)
	var weren_char: Dictionary = rules.default_character()
	weren_char["species_id"] = 5 # Weren
	weren_char["abilities"]["STR"] = 12 # +1 STR damage bonus
	rules.ensure_character_shape(weren_char)
	var weren_attacks: Array = rules.equipment.attack_forms_for_character(weren_char)
	var has_claws := false
	for form in weren_attacks:
		if form.get("name", "") == "Natural Claws":
			has_claws = true
			assert_eq.call(form.get("damage", ""), "d4+1w/d4+3w/d4+1m", "Weren claws damage adjusted for STR +1 bonus")
	assert_true.call(has_claws, "Weren has natural claws in attack forms")

	# Mechalus Cyber Tolerance (CON + 4)
	var mechalus_char: Dictionary = rules.default_character()
	mechalus_char["species_id"] = 2 # Mechalus
	mechalus_char["abilities"]["CON"] = 10
	rules.ensure_character_shape(mechalus_char)
	assert_eq.call(rules.cybertech.cyber_tolerance_total(mechalus_char), 14, "Mechalus cyber tolerance is CON + 4 = 14")

	# Non-Mechalus Cyber Tolerance (CON)
	assert_eq.call(rules.cybertech.cyber_tolerance_total(human_hero), 10, "Human cyber tolerance is CON = 10")

	# --- 13. Section 1 Table G1: Age Thresholds & Age-For-Years ---
	print("Testing Table G1 Age Thresholds...")
	var h_pl5: Dictionary = rules.age_thresholds_for_species(0, 5) # Human at PL 5
	assert_eq.call(h_pl5.adolescent, 17, "Human PL 5 adolescent threshold = 17")
	assert_eq.call(h_pl5.young_adult, 25, "Human PL 5 young adult threshold = 25")
	assert_eq.call(h_pl5.mature, 40, "Human PL 5 mature threshold = 40")
	assert_eq.call(h_pl5.middle_aged, 62, "Human PL 5 middle-aged threshold = 62")
	assert_eq.call(h_pl5.old, 85, "Human PL 5 old threshold = 85")
	assert_eq.call(h_pl5.ancient_die, "+2d12", "Human PL 5 ancient die = +2d12")

	var f_pl6: Dictionary = rules.age_thresholds_for_species(1, 6) # Fraal at PL 6
	assert_eq.call(f_pl6.adolescent, 27, "Fraal PL 6 adolescent threshold = 27")
	assert_eq.call(f_pl6.young_adult, 85, "Fraal PL 6 young adult threshold = 85")
	assert_eq.call(f_pl6.mature, 136, "Fraal PL 6 mature threshold = 136")
	assert_eq.call(f_pl6.middle_aged, 205, "Fraal PL 6 middle-aged threshold = 205")
	assert_eq.call(f_pl6.old, 287, "Fraal PL 6 old threshold = 287")
	assert_eq.call(f_pl6.ancient_die, "+3d20", "Fraal PL 6 ancient die = +3d20")

	assert_eq.call(rules.age_category_for_years(0, 16, 5), "adolescent", "Human age 16 at PL 5 is Adolescent")
	assert_eq.call(rules.age_category_for_years(0, 24, 5), "young_adult", "Human age 24 at PL 5 is Young Adult")
	assert_eq.call(rules.age_category_for_years(0, 35, 5), "mature", "Human age 35 at PL 5 is Mature")
	assert_eq.call(rules.age_category_for_years(0, 50, 5), "middle_aged", "Human age 50 at PL 5 is Middle-Aged")
	assert_eq.call(rules.age_category_for_years(0, 70, 5), "old", "Human age 70 at PL 5 is Old")
	assert_eq.call(rules.age_category_for_years(0, 90, 5), "ancient", "Human age 90 at PL 5 is Ancient")

	# --- 14. Section 2 Table G2, G3 & Table P30 ---
	print("Testing Table G2, G3 and Table P30...")
	var cs_rolls: Dictionary = rules.roll_random_abilities_by_profession(0) # Combat Spec
	assert_eq.call(cs_rolls.STR, "10+d4", "Combat Spec STR roll 10+d4")
	assert_eq.call(cs_rolls.DEX, "8+d4", "Combat Spec DEX roll 8+d4")

	var fraal_rolls: Dictionary = rules.roll_random_abilities_by_species(1) # Fraal
	assert_eq.call(fraal_rolls.INT, "11+d4", "Fraal INT roll 11+d4")
	assert_eq.call(fraal_rolls.WIL, "8+d8", "Fraal WIL roll 8+d8")

	assert_eq.call(rules.starting_funds_dice(0), "5d6", "Combat Spec starting funds = 5d6")
	assert_eq.call(rules.starting_funds_dice(1), "5d12", "Diplomat starting funds = 5d12")
	assert_eq.call(rules.starting_funds_dice(4), "5d8", "Free Agent starting funds = 5d8")
	assert_eq.call(rules.starting_funds_dice(5), "5d8", "Tech Op starting funds = 5d8")
	assert_eq.call(rules.starting_funds_dice(6), "5d4", "Mindwalker starting funds = 5d4")

	# --- 15. Section 1 & 2 Validation Rules ---
	print("Testing Species & Profession Validation...")
	# Non-human with mutations should trigger human-only mutation validation
	var alien_mutant: Dictionary = rules.default_character()
	alien_mutant["species_id"] = 1 # Fraal
	alien_mutant["mutations"] = {"advantages": ["improved_con"]}
	rules.ensure_character_shape(alien_mutant)
	var alien_val_msgs: Array = rules.validate(alien_mutant)
	var found_mut_msg := false
	for m in alien_val_msgs:
		if m.contains("Mutations are only available to human heroes"):
			found_mut_msg = true
	assert_true.call(found_mut_msg, "Non-human mutant triggers human-only validation warning")

	# Fraal Psionic Talent (non-Mindwalker) with non-telepathy specialty
	var fraal_talent: Dictionary = rules.default_character()
	fraal_talent["species_id"] = 1 # Fraal
	fraal_talent["profession_id"] = 0 # Combat Spec (not Mindwalker)
	rules.ensure_character_shape(fraal_talent)
	# Select Telekinesis broad (902) and specialty Electrokinetics (90201)
	fraal_talent["selected_skills"] = {
		902: 1,
		90201: 1,
	}
	var fraal_val_msgs: Array = rules.validate(fraal_talent)
	var found_fraal_msg := false
	for m in fraal_val_msgs:
		if m.contains("Fraal Psionic Talents"):
			found_fraal_msg = true
	assert_true.call(found_fraal_msg, "Fraal non-Mindwalker talent with non-telepathy specialty triggers validation warning")

	# --- 16. Ability Feat Checks vs Untrained Scores ---
	print("Testing Ability Feat Checks vs Untrained Scores...")
	var feat_hero: Dictionary = rules.default_character()
	feat_hero["species_id"] = 1 # Fraal (INT limits 9-15)
	feat_hero["abilities"]["STR"] = 11
	feat_hero["abilities"]["INT"] = 15
	rules.ensure_character_shape(feat_hero)

	# Feat Check Scores
	var str_feat: Dictionary = rules.feat_check_score(feat_hero, "STR")
	assert_eq.call(str_feat.target_score, 11, "STR 11 feat target score is 11")
	assert_eq.call(str_feat.ordinary, 11, "STR 11 feat ordinary is 11")
	assert_eq.call(str_feat.good, 5, "STR 11 feat good is 5")
	assert_eq.call(str_feat.amazing, 2, "STR 11 feat amazing is 2")
	assert_eq.call(str_feat.marginal, 12, "STR 11 feat marginal is 12")
	assert_eq.call(str_feat.base_die, "+d4", "Feat base situation die is +d4")

	var int_feat: Dictionary = rules.feat_check_score(feat_hero, "INT")
	assert_eq.call(int_feat.target_score, 15, "INT 15 feat target score is 15")
	assert_eq.call(int_feat.ordinary, 15, "INT 15 feat ordinary is 15")
	assert_eq.call(int_feat.good, 7, "INT 15 feat good is 7")
	assert_eq.call(int_feat.amazing, 3, "INT 15 feat amazing is 3")

	# Untrained Ability Scores (floor(Stat / 2))
	assert_eq.call(rules.untrained_ability_score(feat_hero, "STR"), 5, "STR 11 untrained score is 5")
	assert_eq.call(rules.untrained_ability_score(feat_hero, "INT"), 7, "INT 15 untrained score is 7")

	# Feat Check Resolution
	var feat_res: Dictionary = rules.resolve_feat_check(feat_hero, "STR", 5, 0) # Control 5 + Sit 0 = 5 <= 5 (Good)
	assert_eq.call(feat_res.degree, "Good", "5 + 0 = 5 vs 11 is Good")

	# --- 17. Active vs Passive Ability Architecture ---
	print("Testing Active vs Passive Ability Architecture...")
	# Passive Resistance: STR, DEX, INT, WIL
	assert_true.call(rules.is_passive_resistance_ability("STR"), "STR is passive resistance ability")
	assert_true.call(rules.is_passive_resistance_ability("DEX"), "DEX is passive resistance ability")
	assert_true.call(rules.is_passive_resistance_ability("INT"), "INT is passive resistance ability")
	assert_true.call(rules.is_passive_resistance_ability("WIL"), "WIL is passive resistance ability")
	assert_eq.call(rules.is_passive_resistance_ability("CON"), false, "CON is NOT passive resistance ability")
	assert_eq.call(rules.is_passive_resistance_ability("PER"), false, "PER is NOT passive resistance ability")

	# Passive RM for CON is 0 (CON has no RM). STR and PER evaluate Table P2.
	var hero_passive: Dictionary = rules.default_character()
	hero_passive["abilities"]["STR"] = 14 # RM +2
	hero_passive["abilities"]["CON"] = 14 # Passive RM = 0
	hero_passive["abilities"]["PER"] = 14 # RM +2 (Active social)
	rules.ensure_character_shape(hero_passive)
	assert_eq.call(rules.character_resistance_modifier(hero_passive, "STR"), 2, "STR 14 passive RM is +2")
	assert_eq.call(rules.character_resistance_modifier(hero_passive, "CON"), 0, "CON 14 RM is 0 (no RM)")
	assert_eq.call(rules.character_resistance_modifier(hero_passive, "PER"), 2, "PER 14 RM is +2")

	# --- 18. Raw Strength Feats & Breaking Objects (Table G21) ---
	print("Testing Raw Strength Feats & Breaking Objects...")
	# Lifting ladder (GMG p. 70 / PHB p. 63-64) is separate from Table P12
	# encumbrance: Marginal 5x, Slight 10x, Moderate 15x, Extreme 20x.
	var str12_lifts: Dictionary = rules.lifting_capacity(12)
	assert_eq.call(str12_lifts.automatic_carry_kg, 24.0, "STR 12 normal carried load = 24kg (2x, Table P12)")
	assert_eq.call(str12_lifts.marginal_feat_kg, 60.0, "STR 12 marginal feat = 60kg (5x)")
	assert_eq.call(str12_lifts.slight_feat_kg, 120.0, "STR 12 slight feat = 120kg (10x)")
	assert_eq.call(str12_lifts.moderate_feat_kg, 180.0, "STR 12 moderate feat = 180kg (15x)")
	assert_eq.call(str12_lifts.extreme_feat_kg, 240.0, "STR 12 extreme feat = 240kg (20x)")
	assert_eq.call(str12_lifts.max_lift_kg, 240.0, "STR 12 max lift = 240kg (20x)")

	# Each tier's situation die: Marginal +d4, Slight +d6, Moderate +d8, Extreme +d12.
	var lift_tiers: Array = str12_lifts.tiers
	assert_eq.call(lift_tiers.size(), 4, "Lifting ladder has four feat tiers")
	assert_eq.call(lift_tiers[0].situation_die, "+d4", "Marginal lift die = +d4 (+0 steps)")
	assert_eq.call(lift_tiers[1].situation_die, "+d6", "Slight lift die = +d6 (+1 step)")
	assert_eq.call(lift_tiers[2].situation_die, "+d8", "Moderate lift die = +d8 (+2 steps)")
	assert_eq.call(lift_tiers[3].situation_die, "+d12", "Extreme lift die = +d12 (+3 steps)")
	assert_eq.call(lift_tiers[0].clean_and_jerk_die, "+d8", "Clean-and-jerk adds +2 steps to a Marginal lift")

	# Tier selection by mass.
	assert_eq.call(String(rules.lifting_tier_for_mass(12, 55.0).get("id", "")), "marginal", "55kg at STR 12 is a Marginal feat")
	assert_eq.call(String(rules.lifting_tier_for_mass(12, 115.0).get("id", "")), "slight", "115kg at STR 12 is a Slight feat")
	assert_eq.call(String(rules.lifting_tier_for_mass(12, 175.0).get("id", "")), "moderate", "175kg at STR 12 is a Moderate feat")
	assert_eq.call(String(rules.lifting_tier_for_mass(12, 235.0).get("id", "")), "extreme", "235kg at STR 12 is an Extreme feat")
	assert_true.call(rules.lifting_tier_for_mass(12, 900.0).is_empty(), "Above STR x 20 kg no ordinary tier applies")

	# Breaking Objects Table G21
	var brk_ord: Dictionary = rules.breaking_object_feat(12, "ordinary")
	assert_eq.call(brk_ord.step, 1, "Ordinary breaking object step = 1 (+d4)")
	assert_eq.call(brk_ord.situation_die, "+d4", "Ordinary breaking object die = +d4")

	var brk_good: Dictionary = rules.breaking_object_feat(12, "good")
	assert_eq.call(brk_good.step, 2, "Good breaking object step = 2 (+d6)")
	assert_eq.call(brk_good.situation_die, "+d6", "Good breaking object die = +d6")

	var brk_amaz: Dictionary = rules.breaking_object_feat(12, "amazing")
	assert_eq.call(brk_amaz.step, 4, "Amazing breaking object step = 4 (+d12)")
	assert_eq.call(brk_amaz.situation_die, "+d12", "Amazing breaking object die = +d12")

	# --- 19. Heightened Ability Perk & Cascading Advancement ---
	print("Testing Heightened Ability Perk & Cascading Advancement...")
	var perk_char: Dictionary = rules.default_character()
	perk_char["species_id"] = 0 # Human (limits 4-14)
	perk_char["abilities"]["STR"] = 12
	perk_char["selected_perks"] = {"heightened_ability": 10}
	perk_char["heightened_ability_stat"] = "STR"
	rules.ensure_character_shape(perk_char)
	var eff_perk: Dictionary = rules.effective_abilities(perk_char)
	assert_eq.call(eff_perk.STR, 13, "STR 12 + Heightened Ability = 13")

	# Clamped to species max
	var perk_max_char: Dictionary = rules.default_character()
	perk_max_char["species_id"] = 0
	perk_max_char["abilities"]["STR"] = 14
	perk_max_char["selected_perks"] = {"heightened_ability": 10}
	perk_max_char["heightened_ability_stat"] = "STR"
	rules.ensure_character_shape(perk_max_char)
	assert_eq.call(rules.effective_abilities(perk_max_char).STR, 14, "Heightened Ability clamped to species max 14")

	# --- 20. Optional Rules 2A, 2B, and 2C Exhaustive Tests ---
	print("Testing Optional Rules 2A, 2B, and 2C...")
	# Optional Rule 2A: 30 + 3*INT (+5 for Human)
	var expected_2a := {
		4: [42, 47],
		6: [48, 53],
		8: [54, 59],
		10: [60, 65],
		12: [66, 71],
		14: [72, 77],
		16: [78, 83],
	}
	for stat_int in expected_2a.keys():
		assert_eq.call(30 + (3 * stat_int), expected_2a[stat_int][0], "Rule 2A Alien Formula INT %d = %d" % [stat_int, expected_2a[stat_int][0]])
		assert_eq.call(35 + (3 * stat_int), expected_2a[stat_int][1], "Rule 2A Human Formula INT %d = %d" % [stat_int, expected_2a[stat_int][1]])

	# Test on actual character documents within species limits
	for stat_int in [4, 6, 8, 10, 12]:
		var weren_2a: Dictionary = rules.default_character()
		weren_2a["species_id"] = 5 # Weren (Alien, limits 4-13)
		weren_2a["abilities"]["INT"] = stat_int
		weren_2a["optional_rules"] = {"2a": true}
		rules.ensure_character_shape(weren_2a)
		assert_eq.call(rules.starting_skill_budget(weren_2a), expected_2a[stat_int][0], "Rule 2A Weren INT %d SP = %d" % [stat_int, expected_2a[stat_int][0]])

	for stat_int in [4, 6, 8, 10, 12, 14]:
		var human_2a: Dictionary = rules.default_character()
		human_2a["species_id"] = 0 # Human (limits 4-14)
		human_2a["abilities"]["INT"] = stat_int
		human_2a["optional_rules"] = {"2a": true}
		rules.ensure_character_shape(human_2a)
		assert_eq.call(rules.starting_skill_budget(human_2a), expected_2a[stat_int][1], "Rule 2A Human INT %d SP = %d" % [stat_int, expected_2a[stat_int][1]])

	# Optional Rule 2B: 6 + INT RM (+1 for Human)
	var expected_2b := {
		4: [4, 5],
		6: [5, 6],
		8: [6, 7],
		10: [6, 7],
		12: [7, 8],
		14: [8, 9],
		16: [9, 10],
	}
	for stat_int in expected_2b.keys():
		var int_rm := rules.resistance_modifier(stat_int)
		assert_eq.call(6 + int_rm, expected_2b[stat_int][0], "Rule 2B Alien Formula INT %d = %d" % [stat_int, expected_2b[stat_int][0]])
		assert_eq.call(6 + int_rm + 1, expected_2b[stat_int][1], "Rule 2B Human Formula INT %d = %d" % [stat_int, expected_2b[stat_int][1]])

	for stat_int in [4, 6, 8, 10, 12]:
		var weren_2b: Dictionary = rules.default_character()
		weren_2b["species_id"] = 5 # Weren (Alien)
		weren_2b["abilities"]["INT"] = stat_int
		weren_2b["optional_rules"] = {"2b": true}
		rules.ensure_character_shape(weren_2b)
		assert_eq.call(rules.additional_broad_skill_limit(weren_2b), expected_2b[stat_int][0], "Rule 2B Weren INT %d Broad Limit = %d" % [stat_int, expected_2b[stat_int][0]])

	for stat_int in [4, 6, 8, 10, 12, 14]:
		var human_2b: Dictionary = rules.default_character()
		human_2b["species_id"] = 0 # Human
		human_2b["abilities"]["INT"] = stat_int
		human_2b["optional_rules"] = {"2b": true}
		rules.ensure_character_shape(human_2b)
		assert_eq.call(rules.additional_broad_skill_limit(human_2b), expected_2b[stat_int][1], "Rule 2B Human INT %d Broad Limit = %d" % [stat_int, expected_2b[stat_int][1]])

	# Rule 2B reads the raw Table P2 modifier for the INT score. Broad skill
	# capacity is innate mental processing, so situational resistance bonuses --
	# here the Free Agent's +1 RM pick -- must not widen the cap.
	var fa_2b: Dictionary = rules.default_character()
	fa_2b["species_id"] = 0 # Human
	fa_2b["profession_id"] = 4 # Free Agent
	fa_2b["abilities"]["INT"] = 10
	fa_2b["optional_rules"] = {"2b": true}
	rules.ensure_character_shape(fa_2b)
	var fa_cap_before := rules.additional_broad_skill_limit(fa_2b)
	assert_eq.call(fa_cap_before, 7, "Rule 2B Free Agent INT 10 human cap = 7")
	fa_2b["free_agent_rm_bonus"] = "INT"
	assert_eq.call(rules.character_resistance_modifier(fa_2b, "INT"), 1, "Free Agent RM pick does raise the defensive INT RM")
	assert_eq.call(rules.additional_broad_skill_limit(fa_2b), fa_cap_before, "Rule 2B cap ignores the Free Agent RM pick")

	# Optional Rule 2C: Flat Specialty Advancement Cost
	var skill_base3 := rules.get_skill_by_id(12) # Blade (Specialty, base 3, Combat Spec)
	var skill_base5 := rules.get_skill_by_id(89) # Surgery (Specialty, base 5, Tech Op)

	var char_core: Dictionary = rules.default_character() # Core rules (2c disabled)
	char_core["profession_id"] = 4 # Free Agent (no discount on either Blade or Surgery)
	char_core["achievement_level"] = 5 # Allows rank 5

	var char_2c: Dictionary = rules.default_character()
	char_2c["profession_id"] = 4 # Free Agent
	char_2c["achievement_level"] = 5 # Allows rank 5
	char_2c["optional_rules"] = {"2c": true}

	# Test each rank individually
	assert_eq.call(rules.skill_purchase_cost(char_core, skill_base3, 1), 3, "Core base 3 rank 1 = 3")
	assert_eq.call(rules.skill_purchase_cost(char_core, skill_base3, 2), 4, "Core base 3 rank 2 = 4")
	assert_eq.call(rules.skill_purchase_cost(char_core, skill_base3, 3), 5, "Core base 3 rank 3 = 5")
	assert_eq.call(rules.skill_purchase_cost(char_core, skill_base3, 4), 6, "Core base 3 rank 4 = 6")
	assert_eq.call(rules.skill_purchase_cost(char_core, skill_base3, 5), 7, "Core base 3 rank 5 = 7")

	assert_eq.call(rules.skill_purchase_cost(char_2c, skill_base3, 1), 3, "Rule 2C base 3 rank 1 = 3")
	assert_eq.call(rules.skill_purchase_cost(char_2c, skill_base3, 2), 3, "Rule 2C base 3 rank 2 = 3")
	assert_eq.call(rules.skill_purchase_cost(char_2c, skill_base3, 3), 3, "Rule 2C base 3 rank 3 = 3")
	assert_eq.call(rules.skill_purchase_cost(char_2c, skill_base3, 4), 3, "Rule 2C base 3 rank 4 = 3")
	assert_eq.call(rules.skill_purchase_cost(char_2c, skill_base3, 5), 3, "Rule 2C base 3 rank 5 = 3")

	# Test total cumulative cost to Rank 5
	char_core["selected_skills"] = {12: 5, 89: 5}
	char_2c["selected_skills"] = {12: 5, 89: 5}
	assert_eq.call(rules.skill_rank_total_cost(char_core, skill_base3), 25, "Core base 3 cumulative 1-5 total = 25 SP")
	assert_eq.call(rules.skill_rank_total_cost(char_core, skill_base5), 35, "Core base 5 cumulative 1-5 total = 35 SP")
	assert_eq.call(rules.skill_rank_total_cost(char_2c, skill_base3), 15, "Rule 2C base 3 cumulative 1-5 total = 15 SP")
	assert_eq.call(rules.skill_rank_total_cost(char_2c, skill_base5), 25, "Rule 2C base 5 cumulative 1-5 total = 25 SP")

	# --- 21. Optional Rule: Psionic Talents ---
	print("Testing Optional Rule: Psionic Talents...")
	var psi_broad := {"id": 901, "broad_id": 901, "type": "broad", "base_price": 6, "professions": "M", "source": "psionics"}
	var psi_spec := {"id": 90101, "broad_id": 901, "type": "specialty", "base_price": 3, "professions": "M", "source": "psionics"}

	var mw_hero: Dictionary = rules.default_character()
	mw_hero["profession_id"] = 6 # Mindwalker
	mw_hero["abilities"]["WIL"] = 12
	rules.ensure_character_shape(mw_hero)
	assert_eq.call(rules.skill_cost(mw_hero, psi_broad), 5, "Mindwalker broad psionic cost = 6 - 1 = 5 SP")
	assert_eq.call(rules.skill_cost(mw_hero, psi_spec), 2, "Mindwalker specialty psionic cost = 3 - 1 = 2 SP")
	assert_eq.call(rules.psionic_energy_points(mw_hero), 12, "Mindwalker psionic energy pool = WIL (12)")

	# Non-Mindwalker Talent (Combat Spec)
	var talent_hero: Dictionary = rules.default_character()
	talent_hero["profession_id"] = 0 # Combat Spec
	talent_hero["abilities"]["WIL"] = 11
	talent_hero["optional_rules"] = {"psionic_talents": true}
	rules.ensure_character_shape(talent_hero)
	assert_eq.call(rules.skill_cost(talent_hero, psi_broad), 7, "Talent broad psionic cost = 6 + 1 = 7 SP (+1 surcharge)")
	assert_eq.call(rules.skill_cost(talent_hero, psi_spec), 4, "Talent specialty psionic cost = 3 + 1 = 4 SP (+1 surcharge)")

	# Enabling the optional rule only makes psionic skills purchasable. The pool
	# arrives with the first psionic skill actually bought (PHB Ch. 14).
	assert_eq.call(rules.psionic_energy_points(talent_hero), 0, "Talent with the rule on but no psionic skill has no pool")
	assert_true.call(not rules.is_psionic_character(talent_hero), "Talent without a psionic skill is not psionic")
	rules.set_skill_rank(talent_hero, 901, 1) # buy Telepathy
	assert_true.call(rules.is_psionic_character(talent_hero), "Buying a psionic broad skill makes the talent psionic")
	assert_eq.call(rules.psionic_energy_points(talent_hero), 6, "Talent psionic energy pool = ceil(11 * 0.5) = 6")

	# Every fraal starts with Telepathy free (Table P4), so every fraal has a pool.
	var fraal_pool_hero: Dictionary = rules.default_character()
	fraal_pool_hero["species_id"] = 1 # Fraal
	fraal_pool_hero["profession_id"] = 0 # Combat Spec, not a Mindwalker
	fraal_pool_hero["abilities"]["WIL"] = 12
	rules.ensure_character_shape(fraal_pool_hero)
	assert_eq.call(rules.free_species_skill_rank(fraal_pool_hero, 901), 1, "Fraal receive Telepathy (skill 901) free")
	assert_eq.call(rules.psionic_energy_points(fraal_pool_hero), 12, "Fraal talent pool = full WIL (12), not half")
	fraal_pool_hero["sold_species_skills"] = [901]
	assert_eq.call(rules.psionic_energy_points(fraal_pool_hero), 0, "A fraal who sold Telepathy off has no pool")

	# Non-Mindwalker without psionic_talents rule enabled triggers validation warning
	var illegal_talent: Dictionary = rules.default_character()
	illegal_talent["profession_id"] = 0 # Combat Spec
	illegal_talent["species_id"] = 0 # Human
	illegal_talent["selected_skills"] = {901: 1} # Has psionic skill
	rules.ensure_character_shape(illegal_talent)
	var val_psi: Array = rules.validate(illegal_talent)
	var found_psi_warn := false
	for m in val_psi:
		if m.contains("Psionic skills are only available to Mindwalkers"):
			found_psi_warn = true
	assert_true.call(found_psi_warn, "Non-Mindwalker with psionics without psionic_talents triggers validation warning")

	# --- 22. Optional Rule: Dazed & Firepower Scaling ---
	print("Testing Dazed Rule & Firepower Scaling...")
	var dazed_char: Dictionary = rules.default_character()
	dazed_char["abilities"]["CON"] = 10 # Stun 10, Wound 10
	rules.ensure_character_shape(dazed_char)
	dazed_char["damage"] = {"stun": 6, "wound": 0, "mortal": 0, "fatigue": 0} # Stun > 50% (6/10)
	assert_eq.call(rules.dazed_penalty(dazed_char), 0, "Without dazed rule, >50% stun penalty is 0")
	dazed_char["optional_rules"] = {"dazed": true}
	assert_eq.call(rules.dazed_penalty(dazed_char), 1, "With dazed rule, >50% stun penalty is +1 step")
	dazed_char["damage"]["wound"] = 6 # Both Stun and Wound > 50%
	assert_eq.call(rules.dazed_penalty(dazed_char), 2, "With dazed rule, both >50% stun & wound penalty is +2 steps")
	dazed_char["damage"]["mortal"] = 1 # Core mortal adds +1
	assert_eq.call(rules.dazed_penalty(dazed_char), 3, "Dazed (+2) + Mortal (+1) = +3 steps penalty")

	# Firepower Degradation (GMG Chapter 3)
	assert_eq.call(rules.degrade_damage_grade("mortal", "O", "O"), "mortal", "O vs O -> no degradation")
	assert_eq.call(rules.degrade_damage_grade("mortal", "O", "G"), "wound", "O vs G -> Mortal degrades to Wound (1 step)")
	assert_eq.call(rules.degrade_damage_grade("wound", "O", "G"), "stun", "O vs G -> Wound degrades to Stun (1 step)")
	assert_eq.call(rules.degrade_damage_grade("stun", "O", "G"), "none", "O vs G -> Stun degrades to None (1 step)")
	assert_eq.call(rules.degrade_damage_grade("mortal", "O", "A"), "stun", "O vs A -> Mortal degrades to Stun (2 steps)")
	assert_eq.call(rules.degrade_damage_grade("wound", "O", "A"), "none", "O vs A -> Wound degrades to None (2 steps)")
	assert_eq.call(rules.degrade_damage_grade("mortal", "A", "G"), "mortal", "A vs G -> higher firepower, no degradation")

	# The toggle has to actually gate it: degradation only applies when the
	# Firepower Scaling optional rule is on and both grades are supplied.
	var fp_char: Dictionary = rules.default_character()
	fp_char["abilities"]["CON"] = 12
	rules.ensure_character_shape(fp_char)
	assert_eq.call(rules.character_degraded_damage_grade(fp_char, "mortal", "O", "A"), "mortal", "Firepower rule off -> no degradation")
	rules.set_optional_rule(fp_char, "firepower_scaling", true)
	assert_eq.call(rules.character_degraded_damage_grade(fp_char, "mortal", "O", "A"), "stun", "Firepower rule on -> Mortal vs Amazing degrades to Stun")
	assert_eq.call(rules.character_degraded_damage_grade(fp_char, "mortal", "", ""), "mortal", "Unspecified grades -> no degradation")

	# A negated hit marks no boxes at all.
	var negated: Dictionary = rules.apply_damage(fp_char, 10, "wound", 0, "O", "A")
	assert_true.call(bool(negated.negated), "Ordinary weapon vs Amazing toughness negates wound damage")
	assert_eq.call(negated.primary_damage, 0, "Negated hit inflicts no primary damage")
	assert_eq.call(rules._as_int(fp_char["damage"]["wound"]), 0, "Negated hit marks no wound boxes")

	# Secondary damage derives from what got through armor, not the raw roll
	# (PHB p. 52): 8 wound less 6 absorbed is 2 through, so 1 secondary stun.
	var armored: Dictionary = rules.default_character()
	armored["abilities"]["CON"] = 12
	rules.ensure_character_shape(armored)
	var soaked: Dictionary = rules.apply_damage(armored, 8, "wound", 6)
	assert_eq.call(soaked.primary_damage, 2, "8 wound less 6 armor leaves 2 primary")
	assert_eq.call(soaked.secondary_stun, 1, "Secondary stun derives from post-armor damage (2 -> 1), not the raw 8")

	# --- 23. Method III Random Ability Allocation Pool ---
	print("Testing Method III Die Allocation Pool...")
	var test_rng := RandomNumberGenerator.new()
	test_rng.seed = 12345
	var dice_pool: Array = rules.roll_method_3_dice(test_rng)
	assert_eq.call(dice_pool.size(), 7, "Method III rolls exactly 7 dice")
	for d in dice_pool:
		assert_true.call(d >= 1 and d <= 6, "Each Method III die is between 1 and 6")

	# --- 24. Table P28 Achievement Points & Leveling Economy ---
	print("Testing Table P28 AP & Leveling Economy...")
	var ap_char: Dictionary = rules.default_character()
	rules.ensure_character_shape(ap_char)

	# Level 1 (0 AP) -> 0 AP used, 0 AP available, 6 AP needed for Level 2
	rules.achievements.set_achievement_points(ap_char, 0)
	var ap_sum_1 := rules.summary(ap_char)
	assert_eq.call(ap_sum_1["achievement_level"], 1, "0 AP is Level 1")
	assert_eq.call(ap_sum_1["achievements.achievement_points_used"], 0, "Level 1 used AP is 0")
	assert_eq.call(ap_sum_1["achievements.achievement_points_available"], 0, "Level 1 available AP is 0")
	assert_eq.call(ap_sum_1["achievements.achievement_points_to_next_level"], 6, "Level 1 needs 6 AP for Level 2")

	# Level 2 (6 AP) -> 6 AP used, 0 AP available, 7 AP needed for Level 3 (at 13 AP)
	rules.achievements.set_achievement_points(ap_char, 6)
	var ap_sum_2 := rules.summary(ap_char)
	assert_eq.call(ap_sum_2["achievement_level"], 2, "6 AP is Level 2")
	assert_eq.call(ap_sum_2["achievements.achievement_points_used"], 6, "Level 2 used AP is 6")
	assert_eq.call(ap_sum_2["achievements.achievement_points_available"], 0, "Level 2 available AP is 0")
	assert_eq.call(ap_sum_2["achievements.achievement_points_to_next_level"], 7, "Level 2 needs 7 AP for Level 3 (at 13)")

	# Level 2 with Rollover (10 AP) -> 6 AP used, 4 AP available progress, 3 AP needed for Level 3
	rules.achievements.set_achievement_points(ap_char, 10)
	var ap_sum_3 := rules.summary(ap_char)
	assert_eq.call(ap_sum_3["achievement_level"], 2, "10 AP is Level 2")
	assert_eq.call(ap_sum_3["achievements.achievement_points_used"], 6, "10 AP uses 6 AP for Level 2")
	assert_eq.call(ap_sum_3["achievements.achievement_points_available"], 4, "10 AP has 4 AP available progress")
	assert_eq.call(ap_sum_3["achievements.achievement_points_to_next_level"], 3, "10 AP needs 3 AP for Level 3 (at 13)")

	# --- 25. Strength (STR) Skills & Rank Benefits ---
	print("Testing STR Skills, Specialties & Rank Benefits...")
	# 1. Catalog Costs and Trained-Only Verification
	var armor_op := rules.get_skill_by_id(0)
	var combat_armor := rules.get_skill_by_id(1)
	var powered_armor := rules.get_skill_by_id(2)
	var athletics := rules.get_skill_by_id(3)
	var climb := rules.get_skill_by_id(4)
	var jump := rules.get_skill_by_id(5)
	var throw_skill := rules.get_skill_by_id(6)
	var heavy_wpn := rules.get_skill_by_id(8)
	var direct_fire := rules.get_skill_by_id(9)
	var indirect_fire := rules.get_skill_by_id(10)
	var melee_wpn := rules.get_skill_by_id(11)
	var blade := rules.get_skill_by_id(12)
	var bludgeon := rules.get_skill_by_id(13)
	var powered_wpn := rules.get_skill_by_id(14)
	var unarmed := rules.get_skill_by_id(15)
	var brawl := rules.get_skill_by_id(16)
	var pma := rules.get_skill_by_id(17)

	# Verify Base Prices & Trained-Only
	assert_eq.call(armor_op["base_price"], 7, "Armor Operation base price is 7 SP")
	assert_eq.call(combat_armor["base_price"], 3, "Combat armor base price is 3 SP")
	assert_eq.call(powered_armor["base_price"], 4, "Powered armor base price is 4 SP")
	assert_true.call(not bool(powered_armor["untrained"]), "Powered armor is Trained Only (untrained = false)")

	assert_eq.call(athletics["base_price"], 3, "Athletics base price is 3 SP")
	assert_eq.call(climb["base_price"], 2, "Climb base price is 2 SP")
	assert_eq.call(jump["base_price"], 1, "Jump base price is 1 SP")
	assert_eq.call(throw_skill["base_price"], 2, "Throw base price is 2 SP")

	assert_eq.call(heavy_wpn["base_price"], 6, "Heavy Weapons base price is 6 SP")
	assert_eq.call(direct_fire["base_price"], 4, "Direct Fire base price is 4 SP")
	assert_eq.call(indirect_fire["base_price"], 4, "Indirect Fire base price is 4 SP")

	assert_eq.call(melee_wpn["base_price"], 6, "Melee Weapons base price is 6 SP")
	assert_eq.call(blade["base_price"], 3, "Blade base price is 3 SP")
	assert_eq.call(bludgeon["base_price"], 3, "Bludgeon base price is 3 SP")
	assert_eq.call(powered_wpn["base_price"], 4, "Powered weapon base price is 4 SP")

	assert_eq.call(unarmed["base_price"], 5, "Unarmed Attack base price is 5 SP")
	assert_eq.call(brawl["base_price"], 3, "Brawl base price is 3 SP")
	assert_eq.call(pma["base_price"], 5, "Power Martial Arts base price is 5 SP")
	assert_true.call(not bool(pma["untrained"]), "Power Martial Arts is Trained Only (untrained = false)")

	# 2. Profession Discounts (Combat Spec gets discounts on STR combat skills, Free Agent on PMA)
	var cs_hero: Dictionary = rules.default_character()
	cs_hero["profession_id"] = 0 # Combat Spec
	rules.ensure_character_shape(cs_hero)
	assert_eq.call(rules.skill_cost(cs_hero, armor_op), 6, "Combat Spec buys Armor Operation for 6 SP (-1)")
	assert_eq.call(rules.skill_cost(cs_hero, heavy_wpn), 5, "Combat Spec buys Heavy Weapons for 5 SP (-1)")
	assert_eq.call(rules.skill_cost(cs_hero, melee_wpn), 5, "Combat Spec buys Melee Weapons for 5 SP (-1)")
	assert_eq.call(rules.skill_cost(cs_hero, unarmed), 4, "Combat Spec buys Unarmed Attack for 4 SP (-1)")
	assert_eq.call(rules.skill_cost(cs_hero, pma), 4, "Combat Spec buys Power Martial Arts for 4 SP (-1)")

	var fa_hero: Dictionary = rules.default_character()
	fa_hero["profession_id"] = 4 # Free Agent
	rules.ensure_character_shape(fa_hero)
	assert_eq.call(rules.skill_cost(fa_hero, pma), 4, "Free Agent buys Power Martial Arts for 4 SP (-1)")

	# 3. Armor Operation Penalty Reduction
	var armor_hero: Dictionary = rules.default_character()
	rules.achievements.set_achievement_points(armor_hero, 100) # Level 10 allows up to Rank 12
	rules.ensure_character_shape(armor_hero)
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 0, "No armor skills -> 0 reduction")
	rules.set_skill_rank(armor_hero, 0, 1) # Broad skill
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 1, "Broad Armor Operation -> 1 step reduction")
	rules.set_skill_rank(armor_hero, 1, 1) # Specialty Rank 1
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 2, "Combat Armor Rank 1 -> 2 steps reduction")
	rules.set_skill_rank(armor_hero, 1, 4) # Specialty Rank 4
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 3, "Combat Armor Rank 4 -> 3 steps reduction")
	rules.set_skill_rank(armor_hero, 1, 7) # Specialty Rank 7
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 4, "Combat Armor Rank 7 -> 4 steps reduction")
	rules.set_skill_rank(armor_hero, 1, 10) # Specialty Rank 10
	assert_eq.call(rules.equipment.armor_operation_penalty_reduction(armor_hero, 1), 5, "Combat Armor Rank 10 -> 5 steps reduction")

	# Shaking Off Stuns (1 pt per 2 ranks, max 6 pts)
	assert_eq.call(rules.equipment.armor_stun_damage_reduction(armor_hero, 1), 5, "Rank 10 Combat Armor gives 5 pts stun damage reduction")
	rules.set_skill_rank(armor_hero, 1, 12)
	assert_eq.call(rules.equipment.armor_stun_damage_reduction(armor_hero, 1), 6, "Rank 12 Combat Armor gives 6 pts stun damage reduction (cap)")

	# 4. Unarmed Attack vs Power Martial Arts Damage
	var pma_hero: Dictionary = rules.default_character()
	rules.achievements.set_achievement_points(pma_hero, 100) # Level 10 allows up to Rank 12
	pma_hero["abilities"]["STR"] = 12 # +1 STR damage bonus
	rules.ensure_character_shape(pma_hero)

	# Untrained base damage: d4s/d4+1s/d4+2s + STR(+1) -> d4+1s/d4+2s/d4+3s
	var attacks := rules.equipment.attack_forms_for_character(pma_hero)
	assert_eq.call(attacks[0]["damage"], "d4+1s/d4+2s/d4+3s", "Untrained unarmed damage includes STR bonus")

	# Power Martial Arts Rank 1: d6s/d6+2s/d4w + STR(+1) -> d6+1s/d6+3s/d4+1w
	rules.set_skill_rank(pma_hero, 15, 1)
	rules.set_skill_rank(pma_hero, 17, 1)
	var pma_attacks := rules.equipment.attack_forms_for_character(pma_hero)
	assert_eq.call(pma_attacks[0]["name"], "Power Martial Arts", "Attack form reflects Power Martial Arts")
	assert_eq.call(pma_attacks[0]["damage"], "d6+1s/d6+3s/d4+1w", "PMA rank 1 damage formula with STR bonus")

	# Power Martial Arts Rank 7: d6+2s/d4w/d4+2w + STR(+1) -> d6+3s/d4+1w/d4+3w
	rules.set_skill_rank(pma_hero, 17, 7)
	var pma_attacks_7 := rules.equipment.attack_forms_for_character(pma_hero)
	assert_eq.call(pma_attacks_7[0]["damage"], "d6+3s/d4+1w/d4+3w", "PMA rank 7 upgraded damage formula")

	# Power Martial Arts has no printed rank 12 damage increase -- rank 12 grants a
	# third +1 step to the STR Resistance Modifier instead (asserted below), so the
	# rank 7 damage line still stands at rank 12.
	rules.set_skill_rank(pma_hero, 17, 12)
	var pma_attacks_12 := rules.equipment.attack_forms_for_character(pma_hero)
	assert_eq.call(pma_attacks_12[0]["damage"], "d6+3s/d4+1w/d4+3w", "PMA rank 12 keeps the rank 7 damage line")

	# 5. STR Resistance Modifier bonuses from Melee / PMA Ranks
	rules.set_skill_rank(pma_hero, 17, 0)
	var rm_base := rules.character_resistance_modifier(pma_hero, "STR")
	rules.set_skill_rank(pma_hero, 17, 4)
	assert_eq.call(rules.character_resistance_modifier(pma_hero, "STR"), rm_base + 1, "PMA rank 4 grants +1 to STR Resistance Modifier")
	rules.set_skill_rank(pma_hero, 17, 8)
	assert_eq.call(rules.character_resistance_modifier(pma_hero, "STR"), rm_base + 2, "PMA rank 8 grants +2 to STR Resistance Modifier")
	rules.set_skill_rank(pma_hero, 17, 12)
	assert_eq.call(rules.character_resistance_modifier(pma_hero, "STR"), rm_base + 3, "PMA rank 12 grants +3 to STR Resistance Modifier")

	# --- 25b. Trained-only skills and untrained scores (PHB p. 63, Table P19) ---
	print("Testing Trained-Only Skills & Untrained Scores...")
	var untrained_hero: Dictionary = rules.default_character()
	untrained_hero["species_id"] = 0
	untrained_hero["abilities"]["STR"] = 12
	rules.ensure_character_shape(untrained_hero)

	var pma_skill: Dictionary = rules.get_skill_by_id(17) # Power Martial Arts, trained only
	var pma_unheld: Dictionary = rules.skill_score(untrained_hero, pma_skill)
	assert_true.call(not bool(pma_unheld.usable), "Power Martial Arts at rank 0 is not usable")
	assert_true.call(bool(pma_unheld.trained_only), "Power Martial Arts is flagged trained-only")
	assert_eq.call(pma_unheld.ordinary, 0, "An unusable trained-only skill reports no score")

	var powered_armor_skill: Dictionary = rules.get_skill_by_id(2) # Powered armor, trained only
	assert_true.call(not bool(rules.skill_score(untrained_hero, powered_armor_skill).usable), "Powered armor at rank 0 is not usable")

	# A skill that may be tried untrained falls back to floor(ability / 2), not
	# the full ability score.
	var brawl_skill: Dictionary = rules.get_skill_by_id(16) # Brawl, untrained allowed
	var brawl_unheld: Dictionary = rules.skill_score(untrained_hero, brawl_skill)
	assert_true.call(bool(brawl_unheld.usable), "Brawl may be attempted untrained")
	assert_eq.call(brawl_unheld.ordinary, 6, "Untrained Brawl uses floor(STR 12 / 2) = 6, not 12")

	# Once bought it uses the full ability score plus rank.
	rules.set_skill_rank(untrained_hero, 15, 1) # Unarmed Attack broad
	rules.set_skill_rank(untrained_hero, 16, 2) # Brawl rank 2
	var brawl_held: Dictionary = rules.skill_score(untrained_hero, brawl_skill)
	assert_true.call(bool(brawl_held.usable), "A purchased skill is usable")
	assert_eq.call(brawl_held.ordinary, 14, "Brawl rank 2 at STR 12 scores 14")

	# --- 25c. Armor Operation untrained restrictions (PHB p. 64) ---
	print("Testing Armor Operation Untrained Restrictions...")
	var unarmored: Dictionary = rules.default_character()
	rules.ensure_character_shape(unarmored)
	assert_true.call(not bool(rules.movement(unarmored).armor_restricted), "No armor means no movement restriction")
	assert_true.call(bool(rules.movement(unarmored).can_jump), "An unarmored hero can jump")

	# --- 26. Cybertech Tolerance Capacity (PHB Chapter 15) ---
	print("Testing Cybertech Tolerance Capacity...")
	var cyber_hero: Dictionary = rules.default_character()
	cyber_hero["species_id"] = 0 # Human
	cyber_hero["abilities"]["CON"] = 10
	rules.ensure_character_shape(cyber_hero)
	rules.cybertech.set_cybertech_enabled(cyber_hero, true)
	assert_eq.call(rules.cybertech.cyber_tolerance_total(cyber_hero), 10, "Human cyber tolerance = CON")

	var mech_hero: Dictionary = rules.default_character()
	mech_hero["species_id"] = 2 # Mechalus
	mech_hero["abilities"]["CON"] = 10
	rules.ensure_character_shape(mech_hero)
	assert_eq.call(rules.cybertech.cyber_tolerance_total(mech_hero), 14, "Mechalus cyber tolerance = CON + 4")

	# The three threshold bands always account for the whole pool.
	for con_score in [4, 7, 10, 13, 16]:
		var band_hero: Dictionary = rules.default_character()
		band_hero["species_id"] = 0
		band_hero["abilities"]["CON"] = con_score
		rules.ensure_character_shape(band_hero)
		var bands: Dictionary = rules.cybertech.cyber_tolerance_breakdown(band_hero)
		assert_eq.call(
			rules._as_int(bands.left) + rules._as_int(bands.center) + rules._as_int(bands.right),
			rules._as_int(bands.total),
			"Cyber tolerance bands sum to the total at CON %d" % con_score
		)

	# Installing past the limit is refused rather than silently allowed.
	var over_hero: Dictionary = rules.default_character()
	over_hero["species_id"] = 0
	over_hero["abilities"]["CON"] = 4
	rules.ensure_character_shape(over_hero)
	rules.cybertech.set_cybertech_enabled(over_hero, true)
	var refused := 0
	for catalog_item in rules.cybertech_catalog:
		var install_result: Dictionary = rules.cybertech.install_cybertech(over_hero, String(catalog_item.get("id", "")), "ordinary")
		if not bool(install_result.get("ok", false)):
			refused += 1
	assert_true.call(refused > 0, "Cybertech installs are refused once tolerance runs out")
	assert_true.call(rules.cybertech.cyber_tolerance_used(over_hero) <= 4, "Installed cybertech never exceeds CON 4 tolerance")
	assert_true.call(rules.cybertech.cyber_tolerance_remaining(over_hero) >= 0, "Cyber tolerance remaining never goes negative")

	# A hero can still end up over capacity without the installer's help -- CON can
	# drop after the fact. validate() has to catch that.
	var shrunk: Dictionary = rules.default_character()
	shrunk["species_id"] = 0
	shrunk["abilities"]["CON"] = 14
	rules.ensure_character_shape(shrunk)
	rules.cybertech.set_cybertech_enabled(shrunk, true)
	for catalog_item in rules.cybertech_catalog:
		rules.cybertech.install_cybertech(shrunk, String(catalog_item.get("id", "")), "ordinary")
	var filled_used := rules.cybertech.cyber_tolerance_used(shrunk)
	assert_true.call(filled_used > 4, "CON 14 hero installs more than a CON 4 hero could hold")
	assert_true.call(rules.validate(shrunk).filter(func(m): return String(m).contains("cyber tolerance")).is_empty(), "A within-capacity hero raises no cyber tolerance message")

	shrunk["abilities"]["CON"] = 4
	var cyber_messages: Array = rules.validate(shrunk).filter(func(m): return String(m).contains("cyber tolerance"))
	assert_true.call(not cyber_messages.is_empty(), "validate() reports cybertech over capacity after a CON drop")

	# --- 26. Dexterity (DEX) Skills, Specialties & Mechanics ---
	print("Testing DEX Skills, Specialties & Mechanics...")
	# 1. Catalog Costs, Affinities, and Trained-Only Verification
	var acrobatics := rules.get_skill_by_id(18)
	var daredevil := rules.get_skill_by_id(19)
	var dma := rules.get_skill_by_id(20)
	var dodge := rules.get_skill_by_id(21)
	var fall := rules.get_skill_by_id(22)
	var flight := rules.get_skill_by_id(23)
	var zero_g := rules.get_skill_by_id(24)
	var manipulation := rules.get_skill_by_id(26)
	var lockpick := rules.get_skill_by_id(27)
	var pickpocket := rules.get_skill_by_id(28)
	var prestidigitation := rules.get_skill_by_id(29)
	var mrw := rules.get_skill_by_id(30)
	var pistol := rules.get_skill_by_id(31)
	var rifle := rules.get_skill_by_id(32)
	var smg := rules.get_skill_by_id(33)
	var prw := rules.get_skill_by_id(34)
	var bow := rules.get_skill_by_id(35)
	var crossbow := rules.get_skill_by_id(36)
	var flintlock := rules.get_skill_by_id(37)
	var sling := rules.get_skill_by_id(38)
	var stealth := rules.get_skill_by_id(39)
	var hide := rules.get_skill_by_id(40)
	var shadow := rules.get_skill_by_id(41)
	var sneak := rules.get_skill_by_id(42)
	var veh_op := rules.get_skill_by_id(43)
	var air_veh := rules.get_skill_by_id(44)
	var land_veh := rules.get_skill_by_id(45)
	var space_veh := rules.get_skill_by_id(46)
	var water_veh := rules.get_skill_by_id(47)

	# Verify Base Costs
	assert_eq.call(acrobatics["base_price"], 7, "Acrobatics base price is 7 SP")
	assert_eq.call(daredevil["base_price"], 4, "Daredevil base price is 4 SP")
	assert_eq.call(dma["base_price"], 5, "Defensive Martial Arts base price is 5 SP")
	assert_eq.call(dodge["base_price"], 4, "Dodge base price is 4 SP")
	assert_eq.call(fall["base_price"], 3, "Fall base price is 3 SP")
	assert_eq.call(flight["base_price"], 2, "Flight base price is 2 SP")
	assert_eq.call(zero_g["base_price"], 2, "Zero-G Training base price is 2 SP")

	assert_eq.call(manipulation["base_price"], 6, "Manipulation base price is 6 SP")
	assert_eq.call(lockpick["base_price"], 4, "Lockpick base price is 4 SP")
	assert_eq.call(pickpocket["base_price"], 4, "Pickpocket base price is 4 SP")
	assert_eq.call(prestidigitation["base_price"], 3, "Prestidigitation base price is 3 SP")

	assert_eq.call(mrw["base_price"], 6, "Modern Ranged Weapons base price is 6 SP")
	assert_eq.call(pistol["base_price"], 4, "Pistol base price is 4 SP")
	assert_eq.call(rifle["base_price"], 4, "Rifle base price is 4 SP")
	assert_eq.call(smg["base_price"], 4, "SMG base price is 4 SP")

	assert_eq.call(prw["base_price"], 7, "Primitive Ranged Weapons base price is 7 SP")
	assert_eq.call(bow["base_price"], 4, "Bow base price is 4 SP")
	assert_eq.call(crossbow["base_price"], 3, "Crossbow base price is 3 SP")
	assert_eq.call(flintlock["base_price"], 3, "Flintlock base price is 3 SP")
	assert_eq.call(sling["base_price"], 4, "Sling base price is 4 SP")

	assert_eq.call(stealth["base_price"], 7, "Stealth base price is 7 SP")
	assert_eq.call(hide["base_price"], 4, "Hide base price is 4 SP")
	assert_eq.call(shadow["base_price"], 4, "Shadow base price is 4 SP")
	assert_eq.call(sneak["base_price"], 5, "Sneak base price is 5 SP")

	assert_eq.call(veh_op["base_price"], 3, "Vehicle Operation base price is 3 SP")
	assert_eq.call(air_veh["base_price"], 5, "Air Vehicle base price is 5 SP")
	assert_eq.call(land_veh["base_price"], 3, "Land Vehicle base price is 3 SP")
	assert_eq.call(space_veh["base_price"], 5, "Space Vehicle base price is 5 SP")
	assert_eq.call(water_veh["base_price"], 3, "Water Vehicle base price is 3 SP")

	# Verify Trained-Only Demarcations
	assert_true.call(not bool(dma["untrained"]), "Defensive Martial Arts is Trained Only")
	assert_true.call(not bool(flight["untrained"]), "Flight is Trained Only")
	assert_true.call(not bool(zero_g["untrained"]), "Zero-G Training is Trained Only")
	assert_true.call(not bool(air_veh["untrained"]), "Air Vehicle is Trained Only")
	assert_true.call(not bool(space_veh["untrained"]), "Space Vehicle is Trained Only")

	# 2. Profession Discounts
	var dex_fa: Dictionary = rules.default_character()
	dex_fa["profession_id"] = 4 # Free Agent
	rules.ensure_character_shape(dex_fa)
	assert_eq.call(rules.skill_cost(dex_fa, acrobatics), 6, "Free Agent buys Acrobatics for 6 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, dma), 4, "Free Agent buys Defensive Martial Arts for 4 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, dodge), 3, "Free Agent buys Dodge for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, fall), 2, "Free Agent buys Fall for 2 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, lockpick), 3, "Free Agent buys Lockpick for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, pickpocket), 3, "Free Agent buys Pickpocket for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, stealth), 6, "Free Agent buys Stealth for 6 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, hide), 3, "Free Agent buys Hide for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, shadow), 3, "Free Agent buys Shadow for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_fa, sneak), 4, "Free Agent buys Sneak for 4 SP (-1)")

	var dex_cs: Dictionary = rules.default_character()
	dex_cs["profession_id"] = 0 # Combat Spec
	rules.ensure_character_shape(dex_cs)
	assert_eq.call(rules.skill_cost(dex_cs, dma), 4, "Combat Spec buys Defensive Martial Arts for 4 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, dodge), 3, "Combat Spec buys Dodge for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, zero_g), 1, "Combat Spec buys Zero-G Training for 1 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, mrw), 5, "Combat Spec buys Modern Ranged Weapons for 5 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, pistol), 3, "Combat Spec buys Pistol for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, rifle), 3, "Combat Spec buys Rifle for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, smg), 3, "Combat Spec buys SMG for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, prw), 6, "Combat Spec buys Primitive Ranged Weapons for 6 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, bow), 3, "Combat Spec buys Bow for 3 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, crossbow), 2, "Combat Spec buys Crossbow for 2 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, flintlock), 2, "Combat Spec buys Flintlock for 2 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_cs, sling), 3, "Combat Spec buys Sling for 3 SP (-1)")

	var dex_dip: Dictionary = rules.default_character()
	dex_dip["profession_id"] = 2 # Diplomat
	rules.ensure_character_shape(dex_dip)
	assert_eq.call(rules.skill_cost(dex_dip, prestidigitation), 2, "Diplomat buys Prestidigitation for 2 SP (-1)")

	var dex_to: Dictionary = rules.default_character()
	dex_to["profession_id"] = 5 # Tech Op
	rules.ensure_character_shape(dex_to)
	assert_eq.call(rules.skill_cost(dex_to, zero_g), 1, "Tech Op buys Zero-G Training for 1 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_to, air_veh), 4, "Tech Op buys Air Vehicle for 4 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_to, land_veh), 2, "Tech Op buys Land Vehicle for 2 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_to, space_veh), 4, "Tech Op buys Space Vehicle for 4 SP (-1)")
	assert_eq.call(rules.skill_cost(dex_to, water_veh), 2, "Tech Op buys Water Vehicle for 2 SP (-1)")

	# 3. Species Free DEX Skills (Table P4)
	var sesh_hero: Dictionary = rules.default_character()
	sesh_hero["species_id"] = 3 # Sesheyan
	rules.ensure_character_shape(sesh_hero)
	assert_true.call(rules.is_free_species_skill(sesh_hero, 18), "Sesheyan receives Acrobatics (18) for free")

	var tsa_hero: Dictionary = rules.default_character()
	tsa_hero["species_id"] = 4 # T'sa
	rules.ensure_character_shape(tsa_hero)
	assert_true.call(rules.is_free_species_skill(tsa_hero, 26), "T'sa receives Manipulation (26) for free")

	var human_veh: Dictionary = rules.default_character()
	human_veh["species_id"] = 0 # Human
	rules.ensure_character_shape(human_veh)
	assert_true.call(rules.is_free_species_skill(human_veh, 43), "Human receives Vehicle Operation (43) for free")

	# 4. Defensive Martial Arts and Dodge RM Rank Benefits
	var rank_hero: Dictionary = rules.default_character()
	rules.achievements.set_achievement_points(rank_hero, 100) # Level 10 allows up to Rank 12
	rank_hero["abilities"]["STR"] = 10
	rank_hero["abilities"]["DEX"] = 10
	rules.ensure_character_shape(rank_hero)

	# Defensive Martial Arts -> STR RM
	var str_rm_base := rules.character_resistance_modifier(rank_hero, "STR")
	rules.set_skill_rank(rank_hero, 20, 4)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "STR"), str_rm_base + 1, "DMA rank 4 grants +1 to close-combat STR RM")
	rules.set_skill_rank(rank_hero, 20, 8)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "STR"), str_rm_base + 2, "DMA rank 8 grants +2 to close-combat STR RM")
	rules.set_skill_rank(rank_hero, 20, 12)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "STR"), str_rm_base + 3, "DMA rank 12 grants +3 to close-combat STR RM")
	rules.set_skill_rank(rank_hero, 20, 0)

	# Dodge -> DEX RM
	var dex_rm_base := rules.character_resistance_modifier(rank_hero, "DEX")
	rules.set_skill_rank(rank_hero, 21, 4)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "DEX"), dex_rm_base + 1, "Dodge rank 4 grants +1 to ranged DEX RM")
	rules.set_skill_rank(rank_hero, 21, 8)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "DEX"), dex_rm_base + 2, "Dodge rank 8 grants +2 to ranged DEX RM")
	rules.set_skill_rank(rank_hero, 21, 12)
	assert_eq.call(rules.character_resistance_modifier(rank_hero, "DEX"), dex_rm_base + 3, "Dodge rank 12 grants +3 to ranged DEX RM")

	finish()
