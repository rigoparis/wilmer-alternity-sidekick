extends SceneTree

# Exhaustive rules audit testing all Core tables (P1-P30, G1-G21), Species & Profession mechanics,
# Ability feats, Passive/Active architecture, Encumbrance, Check resolution, and Damage propagation.

func _init() -> void:
	print("--- Running Alternity Rules Engine Audit ---")
	var rules := AlternityRules.new()
	rules.load_core_data()
	var results := {"pass": 0, "fail": 0}

	var assert_eq = func(actual, expected, msg: String):
		if actual == expected:
			results["pass"] += 1
		else:
			results["fail"] += 1
			printerr("FAIL: %s | Expected: %s, Got: %s" % [msg, str(expected), str(actual)])

	var assert_true = func(cond: bool, msg: String):
		if cond:
			results["pass"] += 1
		else:
			results["fail"] += 1
			printerr("FAIL: %s | Condition was false" % msg)

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
	var str12_lifts: Dictionary = rules.lifting_capacity(12)
	assert_eq.call(str12_lifts.automatic_lift_kg, 24.0, "STR 12 automatic lift = 24kg (2x)")
	assert_eq.call(str12_lifts.marginal_feat_kg, 36.0, "STR 12 marginal feat = 36kg (3x)")
	assert_eq.call(str12_lifts.slight_feat_kg, 60.0, "STR 12 slight feat = 60kg (5x)")
	assert_eq.call(str12_lifts.max_lift_kg, 72.0, "STR 12 max lift = 72kg (6x)")

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

	print("\n--- Audit Summary: %d Passed, %d Failed ---" % [results["pass"], results["fail"]])
	if results["fail"] == 0:
		print("ALL ALTERNITY RULES AUDIT TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("SOME ALTERNITY RULES AUDIT TESTS FAILED!")
		quit(1)
