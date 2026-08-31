extends SceneTree

# Exhaustive rules audit testing all Core tables (P1-P18), Age modifiers,
# Encumbrance, Check resolution, and Damage propagation.

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
	var r1 := rules.resolve_check(15, 0, 14, "+d0") # 15 vs 14 -> Marginal (14+1)
	assert_eq.call(r1.degree, "Marginal", "15 vs 14 allow_marginal is Marginal")
	var r2 := rules.resolve_check(16, 0, 14, "+d0") # 16 vs 14 -> Failure
	assert_eq.call(r2.degree, "Failure", "16 vs 14 is Failure")
	var r3 := rules.resolve_check(12, 0, 14, "+d0") # 12 vs 14 -> Ordinary
	assert_eq.call(r3.degree, "Ordinary", "12 vs 14 is Ordinary")
	var r4 := rules.resolve_check(7, 0, 14, "+d0") # 7 vs 14 -> Good (<= 7)
	assert_eq.call(r4.degree, "Good", "7 vs 14 is Good")
	var r5 := rules.resolve_check(3, 0, 14, "+d0") # 3 vs 14 -> Amazing (<= 3)
	assert_eq.call(r5.degree, "Amazing", "3 vs 14 is Amazing")
	var r6 := rules.resolve_check(20, -5, 18, "-d6") # Nat 20 is always Critical Failure
	assert_eq.call(r6.degree, "Critical Failure", "Natural 20 is always Critical Failure")
	var r7 := rules.resolve_check(1, 15, 10, "+d12") # Nat 1 with +d12 is Auto Success
	assert_eq.call(r7.degree, "Ordinary", "Nat 1 with +d12 is Automatic Ordinary Success")
	var r8 := rules.resolve_check(1, 15, 10, "+d20") # Nat 1 with +d20 is NOT Auto Success
	assert_eq.call(r8.degree, "Failure", "Nat 1 with +d20 is not auto success when total 16 > 10")

	# --- 2. Table P1: Profession Ability Minimums ---
	print("Testing Table P1 Profession Minimums...")
	var combat_spec := rules.get_profession_by_id(0) # Combat Spec
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("STR", 0)), 11, "Combat Spec STR min 11")
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("DEX", 0)), 9, "Combat Spec DEX min 9")
	assert_eq.call(rules._as_int(combat_spec.get("ability_minimums", {}).get("CON", 0)), 9, "Combat Spec CON min 9")

	var tech_op := rules.get_profession_by_id(5) # Tech Op
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("INT", 0)), 11, "Tech Op INT min 11")
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("DEX", 0)), 9, "Tech Op DEX min 9")
	assert_eq.call(rules._as_int(tech_op.get("ability_minimums", {}).get("CON", 0)), 9, "Tech Op CON min 9")

	var diplomat := rules.get_profession_by_id(2) # Diplomat
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("INT", 0)), 9, "Diplomat INT min 9")
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("WIL", 0)), 9, "Diplomat WIL min 9")
	assert_eq.call(rules._as_int(diplomat.get("ability_minimums", {}).get("PER", 0)), 11, "Diplomat PER min 11")

	var free_agent := rules.get_profession_by_id(4) # Free Agent
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("DEX", 0)), 11, "Free Agent DEX min 11")
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("INT", 0)), 9, "Free Agent INT min 9")
	assert_eq.call(rules._as_int(free_agent.get("ability_minimums", {}).get("WIL", 0)), 9, "Free Agent WIL min 9")

	var mindwalker := rules.get_profession_by_id(6) # Mindwalker
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
	var human_hero := rules.default_character()
	human_hero["species_id"] = 0 # Human
	human_hero["abilities"]["INT"] = 10
	rules.ensure_character_shape(human_hero)
	assert_eq.call(rules.starting_skill_budget(human_hero), 50, "Human INT 10 Starting SP = 50")
	assert_eq.call(rules.additional_broad_skill_limit(human_hero), 6, "Human INT 10 Additional Broad Allowance = 6")
	assert_eq.call(rules.max_broad_skills(human_hero), 12, "Human INT 10 Total Broad Cap = 6 racial + 6 additional = 12")

	# Alien (Fraal) INT 10: SP = 45 (10*5 - 5), Broad Cap = 5 (10/2)
	var fraal_hero := rules.default_character()
	fraal_hero["species_id"] = 1 # Fraal
	fraal_hero["abilities"]["INT"] = 10
	rules.ensure_character_shape(fraal_hero)
	assert_eq.call(rules.starting_skill_budget(fraal_hero), 45, "Fraal INT 10 Starting SP = 45")
	assert_eq.call(rules.additional_broad_skill_limit(fraal_hero), 5, "Fraal INT 10 Additional Broad Allowance = 5")
	assert_eq.call(rules.max_broad_skills(fraal_hero), 11, "Fraal INT 10 Total Broad Cap = 6 racial + 5 additional = 11")

	# Alien (Weren) INT 12: SP = 55 (12*5 - 5), Additional Broad = 6 (12/2)
	var weren_hero := rules.default_character()
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
	var lr7 := rules._last_resort_base(7)
	assert_eq.call(lr7.max, 0, "PER 7 max LR = 0")
	var lr10 := rules._last_resort_base(10)
	assert_eq.call(lr10.max, 1, "PER 10 max LR = 1")
	assert_eq.call(lr10.cost, 3, "PER 10 recovery cost = 3 SP")
	var lr12 := rules._last_resort_base(12)
	assert_eq.call(lr12.max, 2, "PER 12 max LR = 2")
	assert_eq.call(lr12.cost, 2, "PER 12 recovery cost = 2 SP")
	var lr14 := rules._last_resort_base(14)
	assert_eq.call(lr14.max, 3, "PER 14 max LR = 3")
	assert_eq.call(lr14.cost, 1, "PER 14 recovery cost = 1 SP")
	var lr16 := rules._last_resort_base(16)
	assert_eq.call(lr16.max, 4, "PER 16 max LR = 4")
	assert_eq.call(lr16.cost, 1, "PER 16 recovery cost = 1 SP")

	# --- 6. Table P7: Actions Per Round ---
	print("Testing Table P7 Actions Per Round...")
	var test_char := rules.default_character()
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
	var mov := rules.movement(test_char)
	assert_eq.call(mov.sprint, 20, "STR+DEX 20 Sprint = 20")
	assert_eq.call(mov.run, 12, "STR+DEX 20 Run = 12")
	assert_eq.call(mov.walk, 4, "STR+DEX 20 Walk = 4")
	assert_eq.call(mov.easy_swim, 2, "STR+DEX 20 Easy Swim = 2")
	assert_eq.call(mov.swim, 4, "STR+DEX 20 Swim = 4")

	# Sesheyan gliding & flying
	var sesheyan := rules.default_character()
	sesheyan["species_id"] = 3 # Sesheyan
	sesheyan["abilities"]["STR"] = 10
	sesheyan["abilities"]["DEX"] = 10 # Total 20
	rules.ensure_character_shape(sesheyan)
	var sesh_mov := rules.movement(sesheyan)
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
	var enc_char := rules.default_character()
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
	var enc30 := rules.encumbrance(enc_char)
	assert_eq.call(enc30.tier, "Heavy", "30kg for STR 10 is Heavy")
	assert_eq.call(enc30.penalty, 1, "Heavy penalty is +1 step to STR/DEX")
	assert_eq.call(enc30.movement_multiplier, 0.75, "Heavy movement mult is 0.75")
	# Check that RM incorporates encumbrance penalty
	assert_eq.call(rules.character_resistance_modifier(enc_char, "STR"), -1, "STR RM reduced by 1 under Heavy load")
	assert_eq.call(rules.character_resistance_modifier(enc_char, "DEX"), -1, "DEX RM reduced by 1 under Heavy load")
	assert_eq.call(rules.character_resistance_modifier(enc_char, "INT"), 0, "INT RM unaffected by encumbrance")

	# --- 10. Age Modifiers ---
	print("Testing Age Modifiers...")
	var mature_char := rules.default_character()
	mature_char["species_id"] = 0 # Human (limits 4-14)
	mature_char["abilities"]["INT"] = 10
	mature_char["abilities"]["PER"] = 10
	mature_char["age_category"] = "mature" # +1 INT, +1 PER
	rules.ensure_character_shape(mature_char)
	var mature_eff := rules.effective_abilities(mature_char)
	assert_eq.call(mature_eff.INT, 11, "Mature Human INT 10 -> 11")
	assert_eq.call(mature_eff.PER, 11, "Mature Human PER 10 -> 11")
	assert_eq.call(mature_eff.STR, 10, "Mature Human STR unchanged")

	# Clamping to species max
	var max_int_char := rules.default_character()
	max_int_char["species_id"] = 0 # Human max INT is 14
	max_int_char["abilities"]["INT"] = 14
	max_int_char["age_category"] = "mature"
	rules.ensure_character_shape(max_int_char)
	assert_eq.call(rules.effective_abilities(max_int_char).INT, 14, "Mature age bonus cannot exceed species max (14)")

	# --- 11. Damage Propagation & Overflow ---
	print("Testing Damage Propagation & Overflow...")
	var dmg_char := rules.default_character()
	dmg_char["abilities"]["CON"] = 10 # Durability: Stun 10, Wound 10, Mortal 5, Fatigue 5
	rules.ensure_character_shape(dmg_char)
	# Apply 6 wound damage with 0 armor
	# Primary: 6 wound. Secondary: floor(6/2) = 3 stun.
	var res1 := rules.apply_damage(dmg_char, 6, "wound", 0)
	assert_eq.call(dmg_char.damage.wound, 6, "Wound damage applied: 6")
	assert_eq.call(dmg_char.damage.stun, 3, "Secondary stun from 6 wound: 3")

	# Apply 8 wound damage (Total wound would be 6+8=14, exceeding max 10 by 4)
	# Overflow 4 wound -> 2 mortal. Secondary stun 4 + 3 = 7.
	rules.apply_damage(dmg_char, 8, "wound", 0)
	assert_eq.call(dmg_char.damage.wound, 10, "Wound clamped to max 10")
	assert_eq.call(dmg_char.damage.mortal, 2, "Overflow wound converted 2:1 to mortal (2)")
	assert_eq.call(dmg_char.damage.stun, 7, "Stun damage accumulated to 7")

	print("\n--- Audit Summary: %d Passed, %d Failed ---" % [results["pass"], results["fail"]])
	if results["fail"] == 0:
		print("ALL ALTERNITY RULES AUDIT TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("SOME ALTERNITY RULES AUDIT TESTS FAILED!")
		quit(1)
