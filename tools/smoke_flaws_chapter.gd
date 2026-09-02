extends "res://tools/test_harness.gd"

##
## Automated smoke test suite for the complete Flaws Chapter.
## Audits all 20 Core Flaws (PHB Ch 7 / GMG Ch 5), Dark Matter Flaws, FX Flaws,
## and Robot Flaws against rulebooks, verifying bonus SP, ability associations,
## action check modifiers, resistance modifiers, starting funds, roll notes,
## and setting catalog filtering.
##

const AlternityRules = preload("res://scripts/alternity_rules.gd")
const AlternityRulesConstants = preload("res://scripts/alternity_rules_constants.gd")
const AlternityNum = preload("res://scripts/core/num.gd")


func _init() -> void:
	begin("flaws chapter audit")
	var rules := AlternityRules.new()
	rules.load_core_data()

	print("--- 1. Testing Core Flaws Definitions and Costs (Table P27) ---")
	var core_flaw_ids := [
		"alien_artifact_flaw", "bad_luck", "clueless", "clumsy", "code_of_honor",
		"delicate", "dirt_poor", "forgetful", "fragile", "infamy",
		"oblivious", "obsessed", "old_injury", "phobia", "poor_looks",
		"powerful_enemy", "primitive", "slow", "spineless", "temper"
	]
	check_eq(rules.flaws_by_id.size() >= 20, true, "at least 20 flaws registered in rules engine")

	for flaw_id in core_flaw_ids:
		var flaw: Dictionary = rules.get_flaw_by_id(flaw_id)
		check_eq(flaw.is_empty(), false, "core flaw '%s' exists" % flaw_id)
		check_eq(String(flaw.get("setting", "")), "", "core flaw '%s' has no setting requirement" % flaw_id)

	# Verify specific Core Flaw costs and abilities (Table P27)
	check_eq(rules.get_flaw_by_id("clumsy").get("bonus_options"), [5], "clumsy is strictly +5 SP (DEX), per Table P27 p. 107")
	check_eq(rules.get_flaw_by_id("clumsy").get("ability"), "DEX", "clumsy is DEX ability")
	check_eq(rules.get_flaw_by_id("bad_luck").get("bonus_options"), [6], "bad luck is +6 SP (WIL)")
	check_eq(rules.get_flaw_by_id("bad_luck").get("ability"), "WIL", "bad luck is WIL ability")
	check_eq(rules.get_flaw_by_id("slow").get("bonus_options"), [6], "slow is +6 SP (DEX)")
	check_eq(rules.get_flaw_by_id("slow").get("ability"), "DEX", "slow is DEX ability")
	check_eq(rules.get_flaw_by_id("dirt_poor").get("bonus_options"), [5], "dirt poor is +5 SP (PER)")
	check_eq(rules.get_flaw_by_id("forgetful").get("bonus_options"), [5], "forgetful is +5 SP (INT)")
	check_eq(rules.get_flaw_by_id("fragile").get("bonus_options"), [3], "fragile is +3 SP (CON)")
	check_eq(rules.get_flaw_by_id("delicate").get("bonus_options"), [3], "delicate is +3 SP (STR)")
	check_eq(rules.get_flaw_by_id("poor_looks").get("bonus_options"), [3], "poor looks is +3 SP (PER)")
	check_eq(rules.get_flaw_by_id("code_of_honor").get("bonus_options"), [3], "code of honor is +3 SP (WIL)")
	check_eq(rules.get_flaw_by_id("alien_artifact_flaw").get("bonus_options"), [5], "alien artifact flaw is +5 SP (Special)")
	check_eq(rules.get_flaw_by_id("oblivious").get("bonus_options"), [4], "oblivious is +4 SP (WIL)")

	# Graded Core Flaws (2/4/6 ladder)
	var graded_core := ["clueless", "infamy", "obsessed", "old_injury", "phobia", "powerful_enemy", "primitive", "spineless", "temper"]
	for gid in graded_core:
		check_eq(rules.get_flaw_by_id(gid).get("bonus_options"), [2, 4, 6], "%s follows 2/4/6 SP ladder" % gid)

	print("--- 2. Testing Dark Matter Flaws (Table D3) ---")
	var dm_flaw_ids := [
		"abductee", "criminal_record", "dilettante", "divided_loyalty",
		"illiterate", "implants", "possessed", "rampant_paranoia",
		"rebellious", "wild_talent"
	]
	for fid in dm_flaw_ids:
		var flaw: Dictionary = rules.get_flaw_by_id(fid)
		check_eq(flaw.is_empty(), false, "dark matter flaw '%s' exists" % fid)
		check_eq(flaw.get("setting"), "Dark Matter", "flaw '%s' requires Dark Matter setting" % fid)

	check_eq(rules.get_flaw_by_id("abductee").get("bonus_options"), [4], "abductee is +4 SP (CON)")
	check_eq(rules.get_flaw_by_id("criminal_record").get("bonus_options"), [4], "criminal record is +4 SP (PER)")
	check_eq(rules.get_flaw_by_id("dilettante").get("bonus_options"), [5], "dilettante is +5 SP (WIL)")
	check_eq(rules.get_flaw_by_id("divided_loyalty").get("bonus_options"), [4], "divided loyalty is +4 SP (PER)")
	check_eq(rules.get_flaw_by_id("illiterate").get("bonus_options"), [5], "illiterate is +5 SP (INT)")
	check_eq(rules.get_flaw_by_id("implants").get("bonus_options"), [2], "implants is +2 SP (CON)")
	check_eq(rules.get_flaw_by_id("possessed").get("bonus_options"), [4, 8], "possessed is +4/8 SP (WIL)")
	check_eq(rules.get_flaw_by_id("rampant_paranoia").get("bonus_options"), [2], "rampant paranoia is +2 SP (PER)")
	check_eq(rules.get_flaw_by_id("rebellious").get("bonus_options"), [2], "rebellious is +2 SP (PER)")
	check_eq(rules.get_flaw_by_id("wild_talent").get("bonus_options"), [6], "wild talent is +6 SP (WIL)")

	print("--- 3. Testing Beyond Science FX Flaws (Table F2) ---")
	var fx_flaw_ids := [
		"fixed_fx_recovery", "inhibited_fx_recovery", "fx_require_recharging",
		"fx_susceptibility", "slow_fx_energy_recovery"
	]
	for fid in fx_flaw_ids:
		var flaw: Dictionary = rules.get_flaw_by_id(fid)
		check_eq(flaw.is_empty(), false, "FX flaw '%s' exists" % fid)
		check_eq(flaw.get("setting"), "Beyond Science", "flaw '%s' requires Beyond Science setting" % fid)

	check_eq(rules.get_flaw_by_id("fixed_fx_recovery").get("bonus_options"), [3], "fixed fx recovery is +3 SP")
	check_eq(rules.get_flaw_by_id("inhibited_fx_recovery").get("bonus_options"), [1, 3, 5], "inhibited fx recovery is +1/3/5 SP")
	check_eq(rules.get_flaw_by_id("fx_require_recharging").get("bonus_options"), [5], "fx require recharging is +5 SP")
	check_eq(rules.get_flaw_by_id("fx_susceptibility").get("bonus_options"), [3, 6, 9], "fx susceptibility is +3/6/9 SP")
	check_eq(rules.get_flaw_by_id("slow_fx_energy_recovery").get("bonus_options"), [5], "slow fx energy recovery is +5 SP")

	print("--- 4. Testing Dataware Robot Flaws (Table D22) ---")
	var robot_flaw_ids := [
		"asimov_circuits", "command_circuitry", "doublespeak", "honesty",
		"incomplete_coding", "inferior_tech", "memory_lapse", "overheat",
		"secret_orders", "short_circuit", "unarmored"
	]
	for fid in robot_flaw_ids:
		var flaw: Dictionary = rules.get_flaw_by_id(fid)
		check_eq(flaw.is_empty(), false, "robot flaw '%s' exists" % fid)
		check_eq(flaw.get("setting"), "Dataware", "flaw '%s' requires Dataware setting" % fid)

	check_eq(rules.get_flaw_by_id("asimov_circuits").get("bonus_options"), [3], "asimov circuits is +3 SP")
	check_eq(rules.get_flaw_by_id("command_circuitry").get("bonus_options"), [4], "command circuitry is +4 SP")
	check_eq(rules.get_flaw_by_id("doublespeak").get("bonus_options"), [2], "doublespeak is +2 SP")
	check_eq(rules.get_flaw_by_id("honesty").get("bonus_options"), [2], "honesty is +2 SP")
	check_eq(rules.get_flaw_by_id("incomplete_coding").get("bonus_options"), [2, 4], "incomplete coding is +2/4 SP")
	check_eq(rules.get_flaw_by_id("inferior_tech").get("bonus_options"), [4], "inferior tech is +4 SP")
	check_eq(rules.get_flaw_by_id("memory_lapse").get("bonus_options"), [5], "memory lapse is +5 SP")
	check_eq(rules.get_flaw_by_id("overheat").get("bonus_options"), [6], "overheat is +6 SP")
	check_eq(rules.get_flaw_by_id("secret_orders").get("bonus_options"), [3], "secret orders is +3 SP")
	check_eq(rules.get_flaw_by_id("short_circuit").get("bonus_options"), [4], "short circuit is +4 SP")
	check_eq(rules.get_flaw_by_id("unarmored").get("bonus_options"), [2], "unarmored is +2 SP")

	print("--- 5. Testing Setting Gating and is_entry_available ---")
	var core_char := {"setting": "Core"}
	var dm_char := {"setting": "Dark Matter"}
	var dw_char := {"setting": "Dataware"}

	check_eq(rules.is_entry_available(core_char, rules.get_flaw_by_id("bad_luck")), true, "Core character can select Bad Luck")
	check_eq(rules.is_entry_available(core_char, rules.get_flaw_by_id("abductee")), false, "Core character CANNOT select Dark Matter Abductee")
	check_eq(rules.is_entry_available(core_char, rules.get_flaw_by_id("asimov_circuits")), false, "Core character CANNOT select Robot Asimov Circuits")

	check_eq(rules.is_entry_available(dm_char, rules.get_flaw_by_id("bad_luck")), true, "Dark Matter character can select Bad Luck")
	check_eq(rules.is_entry_available(dm_char, rules.get_flaw_by_id("abductee")), true, "Dark Matter character can select Abductee")

	check_eq(rules.is_entry_available(dw_char, rules.get_flaw_by_id("asimov_circuits")), true, "Dataware character can select Asimov Circuits")

	print("--- 6. Testing Flaw Mechanical Effects and Calculations ---")
	var hero := {
		"profession_id": 0, # Combat Spec (base starting funds: 5d6)
		"species_id": 0,    # Human
		"abilities": {"STR": 12, "DEX": 12, "CON": 11, "INT": 12, "WIL": 12, "PER": 10},
		"selected_flaws": {},
		"selected_perks": {},
	}

	# Starting funds calculation (Table P30 p. 132)
	check_eq(rules.starting_funds_dice(hero), "5d6", "Normal Combat Spec starting funds are 5d6")

	# Dirt Poor flaw -> 1 die (1d6)
	rules.set_flaw_selected(hero, "dirt_poor", 5)
	check_eq(rules.starting_funds_dice(hero), "1d6", "Dirt Poor Combat Spec gets only 1d6 starting funds")
	check_eq(rules.flaw_skill_points_bonus(hero), 5, "Dirt Poor gives 5 SP bonus")

	# Filthy Rich perk -> double funds (10d6)
	hero["selected_flaws"].erase("dirt_poor")
	rules.set_perk_selected(hero, "filthy_rich", 6)
	check_eq(rules.starting_funds_dice(hero), "10d6", "Filthy Rich Combat Spec gets 10d6 starting funds")
	hero["selected_perks"].erase("filthy_rich")

	# Action Check modifier for Slow flaw (PHB p. 110)
	var normal_ac := rules.action_check(hero)
	check_eq(normal_ac.get("die"), "+d0", "Normal human action check die is +d0")

	rules.set_flaw_selected(hero, "slow", 6)
	var slow_ac := rules.action_check(hero)
	check_eq(slow_ac.get("die"), "+d4", "Slow flaw adds +1 step penalty to Action Check die (+d4)")
	check_eq(rules.flaw_skill_points_bonus(hero), 6, "Slow gives 6 SP bonus")

	# Will Resistance Modifier reduction for Spineless flaw (PHB p. 110, Table P2)
	# WIL 12 base RM is +1
	check_eq(rules.character_resistance_modifier(hero, "WIL"), 1, "Base WIL 12 RM is +1")

	rules.set_flaw_selected(hero, "spineless", 2)
	check_eq(rules.character_resistance_modifier(hero, "WIL"), 0, "Spineless (Minor 2 SP) reduces Will RM by 1 step (0)")

	rules.set_flaw_selected(hero, "spineless", 4)
	check_eq(rules.character_resistance_modifier(hero, "WIL"), -1, "Spineless (Moderate 4 SP) reduces Will RM by 2 steps (-1)")

	rules.set_flaw_selected(hero, "spineless", 6)
	check_eq(rules.character_resistance_modifier(hero, "WIL"), -2, "Spineless (Severe 6 SP) reduces Will RM by 3 steps (-2)")

	print("--- 7. Testing Flaw Roll Notes ---")
	var notes_hero := {
		"selected_flaws": {
			"bad_luck": 6,
			"clumsy": 5,
			"delicate": 3,
		}
	}
	var roll_notes := rules.flaw_roll_notes_for_character(notes_hero)
	check_eq(roll_notes.size(), 3, "generates 3 roll notes for 3 flaws")
	check_eq(roll_notes[0].contains("Bad Luck: A Critical Failure occurs whenever the control die shows 19 or 20"), true, "Bad Luck note is accurate")
	check_eq(roll_notes[1].contains("Clumsy: Suffers a +1 step penalty to all Dexterity-based skill checks"), true, "Clumsy note is accurate")
	check_eq(roll_notes[2].contains("Delicate: Successful Unarmed Attack checks inflict 1 stun"), true, "Delicate note is accurate")

	print("--- 8. Testing Flaw Constraints and Validations ---")
	var val_hero := {
		"selected_flaws": {
			"bad_luck": 6,
			"clumsy": 5,
			"delicate": 3,
			"forgetful": 5, # 4th standard flaw -> exceeds limit of 3
		}
	}
	var msgs: Array = rules.validate(val_hero)
	var found_flaw_limit := false
	for m in msgs:
		if m.contains("no more than three standard flaws"):
			found_flaw_limit = true
			break
	check_eq(found_flaw_limit, true, "character validation catches >3 standard flaws limit")

	finish()
