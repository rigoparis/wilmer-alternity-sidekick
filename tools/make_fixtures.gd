extends "res://tools/test_harness.gd"
##
## Regenerates the synthetic character fixtures in tests/fixtures/characters/.
##
##     godot --headless --path . -s tools/make_fixtures.gd
##
## Run this only when you intend to change what the fixtures cover. Because the
## golden summaries in tests/golden/ are keyed to these files, regenerating them
## means recapturing the goldens too -- see tools/capture_golden.gd.
##
## Everything here is deterministic: catalog ids are read from the loaded data
## and sorted, never rolled. The mutation "roll_*" paths are deliberately
## avoided because they use the unseeded global RNG.
##
## The real_*.json fixtures alongside these are actual saved characters and are
## not generated -- do not overwrite them.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const OUT_DIR := "res://tests/fixtures/characters"

var _rules


func _init() -> void:
	begin("fixture generation")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_write("synthetic_default", _make_default())
	_write("synthetic_combat_spec_loaded", _make_combat_spec())
	_write("synthetic_mutant", _make_mutant())
	_write("synthetic_fraal_mindwalker", _make_mindwalker())
	_write("synthetic_cybertech", _make_cybertech())
	_write("synthetic_fx_talent", _make_fx())
	_write("synthetic_optional_rules", _make_optional_rules())

	finish()


func _base(hero: String, species_id: int, profession_id: int) -> Dictionary:
	var c: Dictionary = _rules.default_character()
	_rules.ensure_character_shape(c)
	c["hero_name"] = hero
	c["player_name"] = "Fixture"
	c["species_id"] = species_id
	c["profession_id"] = profession_id
	return c


func _sorted_ids(by_id: Dictionary) -> Array:
	var keys: Array = by_id.keys()
	keys.sort()
	return keys


func _make_default() -> Dictionary:
	return _base("Default Hero", 0, 0)


func _make_combat_spec() -> Dictionary:
	var c := _base("Loaded Combat Spec", 0, 0)
	c["career"] = "Marine"
	c["abilities"] = {"STR": 12, "DEX": 11, "CON": 11, "INT": 9, "WIL": 10, "PER": 8}

	# Broad skill then its specialty, so rank prerequisites hold.
	_rules.set_skill_rank(c, 30, 1)
	_rules.set_skill_rank(c, 31, 3)
	_rules.set_skill_rank(c, 0, 1)
	_rules.set_skill_rank(c, 1, 2)
	c["combat_spec_bonus_specialty"] = 31

	var perk_ids := _sorted_ids(_rules.perks_by_id)
	var perk: Dictionary = _rules.perks_by_id[perk_ids[0]]
	_rules.set_perk_selected(c, String(perk_ids[0]), _rules._as_int(perk.get("cost_options", [1])[0]))

	var flaw_ids := _sorted_ids(_rules.flaws_by_id)
	var flaw: Dictionary = _rules.flaws_by_id[flaw_ids[0]]
	_rules.set_flaw_selected(c, String(flaw_ids[0]), _rules._as_int(flaw.get("bonus_options", [1])[0]))

	# One armour and one weapon, so equipment_summary has both to aggregate.
	_rules.equipment.add_equipment_to_character(c, "armor_core_001", 1)
	for item in _rules.equipment_catalog:
		if _rules.equipment.equipment_has_combat_role(item, "weapon"):
			_rules.equipment.add_equipment_to_character(c, String(item.get("id", "")), 1)
			break

	_rules.achievements.set_achievement_points(c, 30)
	_rules.achievements.add_achievement_purchase(c, "action_check_increase")
	return c


func _make_mutant() -> Dictionary:
	var c := _base("Mutant Bruiser", _rules.mutations.mutant_species_id(), 0)
	c["abilities"] = {"STR": 11, "DEX": 9, "CON": 12, "INT": 9, "WIL": 10, "PER": 8}
	_rules.mutations.set_mutation_points(c, 4, 2)
	_rules.mutations.set_mutation_distribution(c, "advantage", "Ordinary:2|Good:1|Amazing:0")
	_rules.mutations.set_mutation_distribution(c, "drawback", "Slight:0|Moderate:1|Extreme:0")
	_rules.mutations.add_mutation_advantage(c, "improved_str")
	_rules.mutations.add_mutation_advantage(c, "dermal_reinforcement")
	_rules.mutations.add_mutation_advantage(c, "natural_attack")
	_rules.mutations.add_mutation_drawback(c, "slow_reflexes")
	return c


func _make_mindwalker() -> Dictionary:
	var c := _base("Fraal Mindwalker", 1, 6)
	c["abilities"] = {"STR": 8, "DEX": 10, "CON": 9, "INT": 12, "WIL": 13, "PER": 11}
	_rules.set_skill_rank(c, 900, 2)   # Biokinesis broad
	c["mindwalker_psionic_focus"] = 900
	return c


func _make_cybertech() -> Dictionary:
	var c := _base("Wired Tech Op", 0, 5)
	c["abilities"] = {"STR": 9, "DEX": 10, "CON": 10, "INT": 12, "WIL": 10, "PER": 9}
	_rules.cybertech.set_cybertech_enabled(c, true)
	_rules.cybertech.set_cybertech_skill_purchased(c, true)
	var ids := _sorted_ids(_rules.cybertech_catalog_by_id)
	_rules.cybertech.install_cybertech(c, String(ids[0]), "ordinary")
	_rules.cybertech.install_cybertech(c, String(ids[2]), "good")
	_rules.cybertech.set_cykosis_used(c, 1)
	return c


func _make_fx() -> Dictionary:
	var c := _base("Shaman", 0, 0)
	c["abilities"] = {"STR": 9, "DEX": 9, "CON": 10, "INT": 12, "WIL": 12, "PER": 10}
	_rules.fx.set_fx_talent(c, true)
	_rules.fx.set_energy_pool(c, 12)
	var broads: Array = _rules.fx.get_broad_skills()
	if not broads.is_empty():
		var broad_name := String(broads[0].get("name", ""))
		c["fx"]["primary_broad_group"] = broad_name
		_rules.fx.add_fx_skill(c, broad_name)
		for specialty in _rules.fx.get_specialty_skills_for_broad(broad_name):
			_rules.fx.add_fx_skill(c, String(specialty.get("name", "")))
			break
	return c


func _make_optional_rules() -> Dictionary:
	# All optional rules on at once: these branch skill budgets and ability
	# limits, so the golden catches a regression in any of them.
	var c := _base("Optional Rules Hero", 0, 5)
	for rule in _rules.OPTIONAL_RULES:
		_rules.set_optional_rule(c, String(rule.get("id", "")), true)
	c["abilities"] = {"STR": 10, "DEX": 10, "CON": 10, "INT": 12, "WIL": 10, "PER": 10}
	_rules.set_skill_rank(c, 30, 1)
	return c


func _write(name: String, character: Dictionary) -> void:
	# Strip the transient memo the equipment module writes onto the character.
	if character.has("equipment") and typeof(character["equipment"]) == TYPE_DICTIONARY:
		character["equipment"].erase("_custom_items_by_id")

	var path := "%s/%s.json" % [OUT_DIR, name]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not check(file != null, "can write %s" % path):
		return
	file.store_string(JSON.stringify(character, "\t", true) + "\n")
	file.close()
	print("  wrote %s (%d keys)" % [name, character.size()])
