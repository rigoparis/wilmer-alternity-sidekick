extends "res://tools/test_harness.gd"

const RulesScript := preload("res://scripts/alternity_rules.gd")

func _init() -> void:
	begin("mutations_audit")

	var rules = RulesScript.new()
	rules.load_core_data()

	# 1. Catalog integrity
	check_eq(rules.mutation_advantages.size(), 60, "exactly 60 mutation advantages in catalog")
	check_eq(rules.mutation_drawbacks.size(), 24, "exactly 24 mutation drawbacks in catalog")

	var ord_count := 0
	var good_count := 0
	var amz_count := 0
	for adv_val in rules.mutation_advantages:
		var adv: Dictionary = adv_val
		match String(adv.get("tier", "")):
			"Ordinary": ord_count += 1
			"Good": good_count += 1
			"Amazing": amz_count += 1
		check_true(AlternityNum.as_int(adv.get("table_roll", 0)) >= 1 and AlternityNum.as_int(adv.get("table_roll", 0)) <= 20, "advantage table_roll between 1 and 20")

	check_eq(ord_count, 20, "20 Ordinary advantages in Table P49")
	check_eq(good_count, 20, "20 Good advantages in Table P49")
	check_eq(amz_count, 20, "20 Amazing advantages in Table P49")

	var sli_count := 0
	var mod_count := 0
	var ext_count := 0
	for draw_val in rules.mutation_drawbacks:
		var draw: Dictionary = draw_val
		match String(draw.get("tier", "")):
			"Slight": sli_count += 1
			"Moderate": mod_count += 1
			"Extreme": ext_count += 1
		check_true(AlternityNum.as_int(draw.get("table_roll", 0)) >= 1 and AlternityNum.as_int(draw.get("table_roll", 0)) <= 8, "drawback table_roll between 1 and 8")

	check_eq(sli_count, 8, "8 Slight drawbacks in Table P50")
	check_eq(mod_count, 8, "8 Moderate drawbacks in Table P50")
	check_eq(ext_count, 8, "8 Extreme drawbacks in Table P50")

	# 2. Table P51 Related Abilities mapping
	check_eq(rules.mutations.mutation_related_ability_table_p51("STR"), "INT", "Table P51: STR -> INT")
	check_eq(rules.mutations.mutation_related_ability_table_p51("DEX"), "STR", "Table P51: DEX -> STR")
	check_eq(rules.mutations.mutation_related_ability_table_p51("CON"), "DEX", "Table P51: CON -> DEX")
	check_eq(rules.mutations.mutation_related_ability_table_p51("INT"), "PER", "Table P51: INT -> PER")
	check_eq(rules.mutations.mutation_related_ability_table_p51("WIL"), "CON", "Table P51: WIL -> CON")
	check_eq(rules.mutations.mutation_related_ability_table_p51("PER"), "WIL", "Table P51: PER -> WIL")

	# 3. Mutant species rules
	var char: Dictionary = rules.default_character()
	rules.ensure_character_shape(char)
	char["species_id"] = rules.mutations.mutant_species_id()
	check_true(rules.mutations.mutations_enabled(char), "mutations enabled for Mutant species")

	# 4. Point combination tables (1-7 points)
	var adv_1: Array = rules.mutations.mutation_distribution_options("advantage", 1)
	check_eq(adv_1.size(), 1, "1 adv pt has 1 option")
	var adv_1_first: Dictionary = adv_1[0]
	check_eq(String(adv_1_first.get("label", "")), "1 Ordinary", "1 pt = 1 Ordinary")

	var adv_2: Array = rules.mutations.mutation_distribution_options("advantage", 2)
	check_eq(adv_2.size(), 2, "2 adv pts have 2 options (1 Good, 2 Ordinary)")

	var adv_3: Array = rules.mutations.mutation_distribution_options("advantage", 3)
	check_eq(adv_3.size(), 2, "3 adv pts have 2 options (1 Good + 1 Ordinary, 3 Ordinary)")

	var adv_4: Array = rules.mutations.mutation_distribution_options("advantage", 4)
	check_eq(adv_4.size(), 3, "4 adv pts have 3 options (1 Amazing, 1 Good + 2 Ordinary, 2 Good)")

	var adv_7: Array = rules.mutations.mutation_distribution_options("advantage", 7)
	check_eq(adv_7.size(), 3, "7 adv pts have 3 options per Table P49 combinations")

	# Drawbacks match combination table (max 3 Slight, max 2 Moderate, max 1 Extreme)
	var draw_4: Array = rules.mutations.mutation_distribution_options("drawback", 4)
	check_eq(draw_4.size(), 3, "4 draw pts have 3 options (1 Extreme, 1 Moderate + 2 Slight, 2 Moderate)")

	var draw_7: Array = rules.mutations.mutation_distribution_options("drawback", 7)
	check_eq(draw_7.size(), 3, "7 draw pts have 3 options (1 Extreme + 1 Moderate + 1 Slight, 1 Extreme + 3 Slight, 2 Moderate + 3 Slight)")

	# 5. Tier caps enforcement
	rules.mutations.set_mutation_points(char, 7, 7)
	rules.mutations.set_mutation_distribution(char, "advantage", "Ordinary:1|Good:1|Amazing:1")
	rules.mutations.set_mutation_distribution(char, "drawback", "Slight:1|Moderate:1|Extreme:1")

	# Add 1 Amazing
	var res: Dictionary = rules.mutations.add_mutation_advantage(char, "hyper_str")
	check_true(bool(res.get("ok", false)), "Hyper STR (Amazing) added")

	# Try adding second Amazing (should fail)
	var res2: Dictionary = rules.mutations.add_mutation_advantage(char, "flight")
	check_false(bool(res2.get("ok", false)), "Second Amazing mutation rejected by tier cap")

	# Add 1 Extreme drawback: try Wild Mutation before compatible advantage
	var wild_res: Dictionary = rules.mutations.add_mutation_drawback(char, "wild_mutation")
	check_false(bool(wild_res.get("ok", false)), "Wild Mutation rejected when no compatible advantage is selected")

	# Add Good advantage compatible with Wild Mutation
	var res_acid: Dictionary = rules.mutations.add_mutation_advantage(char, "acid_touch")
	check_true(bool(res_acid.get("ok", false)), "Acid Touch added")

	# Now Wild Mutation should succeed
	wild_res = rules.mutations.add_mutation_drawback(char, "wild_mutation")
	check_true(bool(wild_res.get("ok", false)), "Wild Mutation accepted when compatible advantage (Acid Touch) is present")

	# Try adding second Extreme drawback (should fail)
	var res_deadly: Dictionary = rules.mutations.add_mutation_drawback(char, "deadly_immunity")
	check_false(bool(res_deadly.get("ok", false)), "Second Extreme drawback rejected by tier cap")

	# 6. Dark Matter setting restrictions (Dark Matter Campaign Setting p. 74)
	var dm_char: Dictionary = rules.default_character()
	rules.ensure_character_shape(dm_char)
	dm_char["species_id"] = rules.mutations.mutant_species_id()
	dm_char["setting"] = "Dark*Matter"
	rules.mutations.set_mutation_points(dm_char, 4, 4)

	# In Dark Matter, 4 points should only offer Ordinary/Good combinations (NO Amazing)
	var dm_adv_options: Array = rules.mutations.mutation_distribution_options("advantage", 4, dm_char)
	check_eq(dm_adv_options.size(), 2, "Dark Matter 4 adv points only allows 2 options (no Amazing)")
	for opt_val in dm_adv_options:
		var opt: Dictionary = opt_val
		var counts: Dictionary = opt.get("counts", {})
		check_eq(AlternityNum.as_int(counts.get("Amazing", 0)), 0, "Dark Matter advantage distribution has 0 Amazing")

	# In Dark Matter, 4 drawback points should only offer Slight/Moderate (NO Extreme)
	var dm_draw_options: Array = rules.mutations.mutation_distribution_options("drawback", 4, dm_char)
	check_eq(dm_draw_options.size(), 2, "Dark Matter 4 draw points only allows 2 options (no Extreme)")
	for opt_val in dm_draw_options:
		var opt: Dictionary = opt_val
		var counts: Dictionary = opt.get("counts", {})
		check_eq(AlternityNum.as_int(counts.get("Extreme", 0)), 0, "Dark Matter drawback distribution has 0 Extreme")

	# Dark Matter validation rejects Amazing / Extreme directly
	rules.mutations.set_mutation_distribution(dm_char, "advantage", "Ordinary:2|Good:1|Amazing:0")
	rules.mutations.set_mutation_distribution(dm_char, "drawback", "Slight:2|Moderate:1|Extreme:0")

	var dm_amz_check: Dictionary = rules.mutations.can_add_mutation_advantage(dm_char, rules.mutations.get_mutation_advantage_by_id("hyper_str"))
	check_false(bool(dm_amz_check.get("allowed", false)), "Dark Matter can_add_mutation_advantage rejects Amazing")
	check_true(String(dm_amz_check.get("reason", "")).contains("Dark*Matter"), "Reason cites Dark*Matter prohibition")

	var dm_ext_check: Dictionary = rules.mutations.can_add_mutation_drawback(dm_char, rules.mutations.get_mutation_drawback_by_id("deadly_immunity"))
	check_false(bool(dm_ext_check.get("allowed", false)), "Dark Matter can_add_mutation_drawback rejects Extreme")
	check_true(String(dm_ext_check.get("reason", "")).contains("Dark*Matter"), "Reason cites Dark*Matter prohibition")

	# 7. Untrained Mutation Check
	var unt_check: Dictionary = rules.mutations.untrained_mutation_check(char, "CON")
	check_eq(unt_check.get("situation_die", ""), "+d4", "Untrained mutation check situation die is +d4")
	check_true(int(unt_check.get("score", 0)) > 0, "Untrained score is computed from 1/2 CON")

	finish()
