class_name AlternityRules
extends "res://scripts/alternity_rules_constants.gd"

# Sub-modules
var mutations = preload('res://scripts/alternity_rules_mutations.gd').new(self)
var cybertech = preload('res://scripts/alternity_rules_cybertech.gd').new(self)
var equipment = preload('res://scripts/alternity_rules_equipment.gd').new(self)
var achievements = preload('res://scripts/alternity_rules_achievements.gd').new(self)
var fx = preload('res://scripts/alternity_rules_fx.gd').new(self)

# Delegation wrappers removed. Sub-modules are exposed directly.


var _cached_summary: Dictionary = {}
var _last_character_hash: int = 0

func clear_cache() -> void:
	_cached_summary.clear()
	_last_character_hash = 0

var data: Dictionary = {}
var species: Array = []
var species_by_id: Dictionary = {}
var professions_by_id: Dictionary = {}
var perks_by_id: Dictionary = {}
var flaws_by_id: Dictionary = {}
var skills: Array = []
var equipment_sources: Array = []
var equipment_catalog: Array = []
var equipment_by_id: Dictionary = {}
var achievement_profiles: Array = []
var achievement_sources: Array = []
var achievement_rules: Array = []
var achievement_catalog: Array = []
var achievements_by_id: Dictionary = {}
var mutation_rules: Array = []
var mutation_origins: Array = []
var mutation_origins_by_id: Dictionary = {}
var mutation_uniqueness_by_id: Dictionary = {}
var mutation_advantages: Array = []
var mutation_drawbacks: Array = []
var mutation_advantages_by_id: Dictionary = {}
var mutation_drawbacks_by_id: Dictionary = {}
var cybertech_catalog: Array = []
var cybertech_catalog_by_id: Dictionary = {}
var skills_by_id: Dictionary = {}
var broad_skills: Array = []
var specialty_skills_by_broad_id: Dictionary = {}
var fx_broad_skills: Array = []
var fx_broad_skills_by_name: Dictionary = {}
var fx_specialty_skills_by_broad: Dictionary = {}
var fx_specialty_skills_by_name: Dictionary = {}


func load_core_data(path := "res://data/rules/alternity_core.json") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity rule data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity rule data is not valid JSON: %s" % path)
		return

	data = parsed
	species = data.get("species", [])
	skills = data.get("skills", [])
	_index_constants()
	_load_psionics_catalog()
	_index_skills()
	_load_equipment_catalog()
	_load_achievement_catalog()
	_load_mutation_catalog()
	_load_cybertech_catalog()
	_load_fx_catalog()


func _index_constants() -> void:
	species_by_id.clear()
	for item in species:
		var item_id := _as_int(item.get("id", -1))
		if item_id != -1:
			species_by_id[item_id] = item

	professions_by_id.clear()
	for item in PROFESSION_DEFINITIONS:
		var item_id := _as_int(item.get("id", -1))
		if item_id != -1:
			professions_by_id[item_id] = item

	perks_by_id.clear()
	for item in PERK_DEFINITIONS:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			perks_by_id[item_id] = item

	flaws_by_id.clear()
	for item in FLAW_DEFINITIONS:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			flaws_by_id[item_id] = item


func _load_equipment_catalog(path := "res://data/rules/equipment_core.json") -> void:
	equipment_sources.clear()
	equipment_catalog.clear()
	equipment_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity equipment data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity equipment data is not valid JSON: %s" % path)
		return

	equipment_sources = parsed.get("sources", [])
	equipment_catalog = parsed.get("items", [])
	_index_equipment()


func _load_achievement_catalog(path := "res://data/rules/achievements_core.json") -> void:
	achievement_profiles.clear()
	achievement_sources.clear()
	achievement_rules.clear()
	achievement_catalog.clear()
	achievements_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity achievement data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity achievement data is not valid JSON: %s" % path)
		return

	achievement_profiles = parsed.get("profiles", [])
	achievement_sources = parsed.get("sources", [])
	achievement_rules = parsed.get("rules", [])
	achievement_catalog = parsed.get("items", [])
	_index_achievements()


func _load_mutation_catalog(path := "res://data/rules/mutations_core.json") -> void:
	mutation_rules.clear()
	mutation_origins.clear()
	mutation_origins_by_id.clear()
	mutation_uniqueness_by_id.clear()
	mutation_advantages.clear()
	mutation_drawbacks.clear()
	mutation_advantages_by_id.clear()
	mutation_drawbacks_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity mutation data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity mutation data is not valid JSON: %s" % path)
		return

	mutation_rules = parsed.get("rules", [])
	mutation_origins = parsed.get("origins", [])
	for item_value in mutation_origins:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_origins_by_id[item_id] = item

			var uniqueness_dict: Dictionary = {}
			for uniqueness_value in item.get("uniqueness", []):
				if typeof(uniqueness_value) != TYPE_DICTIONARY:
					continue
				var uniqueness: Dictionary = uniqueness_value
				var uniqueness_id := String(uniqueness.get("id", ""))
				if not uniqueness_id.is_empty():
					uniqueness_dict[uniqueness_id] = uniqueness
			mutation_uniqueness_by_id[item_id] = uniqueness_dict

	mutation_advantages = parsed.get("advantages", [])
	mutation_drawbacks = parsed.get("drawbacks", [])
	for item_value in mutation_advantages:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_advantages_by_id[item_id] = item
	for item_value in mutation_drawbacks:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			mutation_drawbacks_by_id[item_id] = item


func _load_cybertech_catalog(path := "res://data/rules/cybertech_core.json") -> void:
	cybertech_catalog.clear()
	cybertech_catalog_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity cybertech data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Alternity cybertech data is not a valid JSON array: %s" % path)
		return

	cybertech_catalog = parsed
	for item_value in cybertech_catalog:
		if typeof(item_value) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_value
		var item_id := String(item.get("id", ""))
		if not item_id.is_empty():
			cybertech_catalog_by_id[item_id] = item


func _load_fx_catalog(path := "res://data/rules/fx_core.json") -> void:
	fx_broad_skills.clear()
	fx_broad_skills_by_name.clear()
	fx_specialty_skills_by_broad.clear()
	fx_specialty_skills_by_name.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity fx data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity fx data is not valid JSON: %s" % path)
		return

	var broad_dict = parsed.get("broad_skills", {})
	for key in broad_dict.keys():
		var broad = broad_dict[key]
		fx_broad_skills.append(broad)
		fx_broad_skills_by_name[String(broad.get("name", ""))] = broad
		fx_specialty_skills_by_broad[String(broad.get("name", ""))] = []
		
	var spec_dict = parsed.get("specialty_skills", {})
	for key in spec_dict.keys():
		var spec = spec_dict[key]
		fx_specialty_skills_by_name[String(spec.get("name", ""))] = spec
		var broad_name = String(spec.get("broad_skill", ""))
		if fx_specialty_skills_by_broad.has(broad_name):
			fx_specialty_skills_by_broad[broad_name].append(spec)



func _load_psionics_catalog(path := "res://data/rules/psionics_core.json") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to load Alternity psionics data: %s" % path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Alternity psionics data is not valid JSON: %s" % path)
		return

	var psionics_skills: Array = parsed.get("skills", [])
	skills.append_array(psionics_skills)


func default_character() -> Dictionary:
	return {
		"hero_name": "New Hero",
		"player_name": "",
		"career": "",
		"notes": "",
		"setting": data.get("setting", "Core"),
		"achievement_level": 1,
		"achievement_points": 0,
		"achievement_points_available": 0,
		"achievement_points_spent_other": 0,
		"species_id": 0,
		"profession_id": 0,
		"age_category": "young_adult",
		"abilities": {
			"STR": 10,
			"DEX": 10,
			"CON": 10,
			"INT": 10,
			"WIL": 10,
			"PER": 10,
		},
		"sold_species_skills": [],
		"selected_skills": {},
		"selected_perks": {},
		"selected_flaws": {},
		"selected_achievements": [],
		"mutations": {
			"generation_mode": "random",
			"origin": "engineered",
			"uniqueness": "engineered_community",
			"advantage_points": 0,
			"drawback_points": 0,
			"advantage_distribution": {},
			"drawback_distribution": {},
			"advantages": [],
			"drawbacks": [],
		},
		"optional_rules": {
			"2a": false,
			"2b": false,
			"2c": false,
		},
		"damage": {
			"stun": 0,
			"wound": 0,
			"mortal": 0,
			"fatigue": 0,
		},
		"last_resorts_used": 0,
		"equipment": {
			"carried": [],
			"custom_items": [],
		},
	}


func ensure_character_shape(character: Dictionary) -> Dictionary:
	if not character.has("abilities") or typeof(character["abilities"]) != TYPE_DICTIONARY:
		character["abilities"] = {}
	for ability in ABILITIES:
		if not character["abilities"].has(ability):
			character["abilities"][ability] = 10

	if not character.has("age_category") or String(character["age_category"]).strip_edges().is_empty():
		character["age_category"] = "young_adult"

	# Normalize achievement points and level first: skill rank clamping below
	# depends on the achievement level being up to date.
	character["achievement_points"] = max(0, _as_int(character.get("achievement_points", 0)))
	character["achievement_level"] = achievements.achievement_level_for_points(_as_int(character.get("achievement_points", 0)))
	character["achievement_points_spent_other"] = max(0, _as_int(character.get("achievement_points_spent_other", 0)))

	# Migrate saves written with the old dotted character keys.
	if character.has("achievements.selected_achievements"):
		if not character.has("selected_achievements") and typeof(character["achievements.selected_achievements"]) == TYPE_ARRAY:
			character["selected_achievements"] = character["achievements.selected_achievements"]
		character.erase("achievements.selected_achievements")
	character.erase("achievements.achievement_points_available")

	if not character.has("selected_skills") or typeof(character["selected_skills"]) != TYPE_DICTIONARY:
		character["selected_skills"] = {}
	else:
		_normalize_selected_skills(character)
	if not character.has("sold_species_skills") or typeof(character["sold_species_skills"]) != TYPE_ARRAY:
		character["sold_species_skills"] = []
	else:
		var norm_sold := []
		for s_id in character["sold_species_skills"]:
			norm_sold.append(_as_int(s_id))
		character["sold_species_skills"] = norm_sold
	if not character.has("selected_perks") or typeof(character["selected_perks"]) != TYPE_DICTIONARY:
		character["selected_perks"] = {}
	else:
		_normalize_selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost_options")
	if not character.has("selected_flaws") or typeof(character["selected_flaws"]) != TYPE_DICTIONARY:
		character["selected_flaws"] = {}
	else:
		_normalize_selected_character_options(character, "selected_flaws", FLAW_DEFINITIONS, "bonus_options")
	if not character.has("selected_achievements") or typeof(character["selected_achievements"]) != TYPE_ARRAY:
		character["selected_achievements"] = []
	else:
		achievements._normalize_selected_achievements(character)
	if not character.has("mutations") or typeof(character["mutations"]) != TYPE_DICTIONARY:
		character["mutations"] = {}
	mutations._normalize_mutations(character)
	if not character.has("cybertech") or typeof(character["cybertech"]) != TYPE_DICTIONARY:
		character["cybertech"] = {}
	cybertech._normalize_cybertech(character)
	if not character.has("fx") or typeof(character["fx"]) != TYPE_DICTIONARY:
		character["fx"] = {}
	fx._normalize_fx(character)
	if not character.has("optional_rules") or typeof(character["optional_rules"]) != TYPE_DICTIONARY:
		character["optional_rules"] = {}
	for rule in OPTIONAL_RULES:
		var rule_id := String(rule.get("id", ""))
		if not character["optional_rules"].has(rule_id):
			character["optional_rules"][rule_id] = false
	if not character.has("species_id"):
		character["species_id"] = 0
	if not character.has("profession_id"):
		character["profession_id"] = 0
	if not character.has("notes"):
		character["notes"] = ""
	character["notes"] = String(character.get("notes", ""))
	character["achievement_points_available"] = achievements.achievement_points_available(character)
	if not character.has("damage") or typeof(character["damage"]) != TYPE_DICTIONARY:
		character["damage"] = {}
	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		if not character["damage"].has(damage_type):
			character["damage"][damage_type] = 0
	if not character.has("last_resorts_used"):
		character["last_resorts_used"] = 0
	if not character.has("last_resorts_rebought"):
		character["last_resorts_rebought"] = 0
	if not character.has("equipment") or typeof(character["equipment"]) != TYPE_DICTIONARY:
		character["equipment"] = {}
	equipment._normalize_equipment(character)
	clamp_trackers(character)
	return character



func get_species_by_id(species_id: int) -> Dictionary:
	if species_by_id.has(species_id):
		return species_by_id[species_id]
	return species[0] if not species.is_empty() else {}


func get_profession_by_id(profession_id: int) -> Dictionary:
	if professions_by_id.has(profession_id):
		return professions_by_id[profession_id]
	return PROFESSION_DEFINITIONS[0] if not PROFESSION_DEFINITIONS.is_empty() else {}


func get_skill_by_id(skill_id: int) -> Dictionary:
	return skills_by_id.get(skill_id, {})


func get_equipment_item_by_id(item_id: String) -> Dictionary:
	return equipment_by_id.get(item_id, {})


func get_achievement_by_id(achievement_id: String) -> Dictionary:
	return achievements_by_id.get(achievement_id, {})


func get_mutation_advantage_by_id(mutation_id: String) -> Dictionary:
	return mutation_advantages_by_id.get(mutation_id, {})


func get_mutation_drawback_by_id(drawback_id: String) -> Dictionary:
	return mutation_drawbacks_by_id.get(drawback_id, {})



func skill_name_for_id(skill_id: int) -> String:
	var skill := get_skill_by_id(skill_id)
	if not skill.is_empty():
		return skill_label(skill)
	return String(MISSING_SKILL_LABELS.get(skill_id, ""))


func get_perk_by_id(perk_id: String) -> Dictionary:
	return perks_by_id.get(perk_id, {})


func get_flaw_by_id(flaw_id: String) -> Dictionary:
	return flaws_by_id.get(flaw_id, {})


func get_free_skill_ids(character: Dictionary) -> Array:
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var result := []
	for skill_id in current_species.get("free_skill_ids", []):
		result.append(_as_int(skill_id))
	return result


func get_free_specialty_skill_ids(character: Dictionary) -> Array:
	var species_id := _as_int(character.get("species_id", 0))
	var result := []
	for skill_id in SPECIES_FREE_SPECIALTY_IDS.get(species_id, []):
		result.append(_as_int(skill_id))
	return result


func free_species_skill_rank(character: Dictionary, skill_id: int) -> int:
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return 0
	if character.get("sold_species_skills", []).has(skill_id):
		return 0
	if skill.get("type", "") == "broad" and get_free_skill_ids(character).has(skill_id):
		return 1
	if skill.get("type", "") == "specialty" and get_free_specialty_skill_ids(character).has(skill_id):
		return 1
	return 0


func is_normally_free_species_skill(character: Dictionary, skill_id: int) -> bool:
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return false
	if skill.get("type", "") == "broad" and get_free_skill_ids(character).has(skill_id):
		return true
	if skill.get("type", "") == "specialty" and get_free_specialty_skill_ids(character).has(skill_id):
		return true
	return false


func species_rule_notes(character: Dictionary) -> Array:
	return _species_notes_for_character(character, SPECIES_RULE_NOTES)


func species_roll_notes_for_character(character: Dictionary) -> Array:
	return _species_notes_for_character(character, SPECIES_ROLL_NOTES)


func optional_rule_enabled(character: Dictionary, rule_id: String) -> bool:
	var optional_rules: Dictionary = character.get("optional_rules", {})
	return bool(optional_rules.get(rule_id, false))


func set_optional_rule(character: Dictionary, rule_id: String, enabled: bool) -> void:
	var optional_rules: Dictionary = character.get("optional_rules", {})
	optional_rules[rule_id] = enabled
	character["optional_rules"] = optional_rules


func base_abilities(character: Dictionary) -> Dictionary:
	return character.get("abilities", {})


func age_category(character: Dictionary) -> String:
	var cat := String(character.get("age_category", "young_adult")).strip_edges().to_lower()
	return cat if AGE_MODIFIERS.has(cat) else "young_adult"


func age_modifier(character: Dictionary, ability: String) -> int:
	var cat := age_category(character)
	var mods: Dictionary = AGE_MODIFIERS.get(cat, {})
	return _as_int(mods.get(ability, 0))


func age_adjusted_abilities(character: Dictionary) -> Dictionary:
	var result := {}
	var abilities: Dictionary = character.get("abilities", {})
	var cat := age_category(character)
	var mods: Dictionary = AGE_MODIFIERS.get(cat, {})
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var limits_dict: Dictionary = current_species.get("ability_limits", {})
	for ability in ABILITIES:
		var score := _as_int(abilities.get(ability, 10))
		var age_mod := _as_int(mods.get(ability, 0))
		var spec_lim: Array = limits_dict.get(ability, [4, 14])
		# Age modifiers cannot raise or lower scores outside species minimums and maximums.
		result[ability] = clampi(score + age_mod, _as_int(spec_lim[0]), _as_int(spec_lim[1]))
	return result


func achievement_adjusted_abilities(character: Dictionary) -> Dictionary:
	var result := age_adjusted_abilities(character)
	for entry in achievements.selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "ability":
			continue
		var ability := String(effect.get("ability", ""))
		if not ABILITIES.has(ability):
			continue
		var limits := ability_limits(character, ability)
		result[ability] = clampi(_as_int(result.get(ability, 10)) + _as_int(effect.get("amount", 1)), _as_int(limits[0]), _as_int(limits[1]))
	return result


func effective_abilities(character: Dictionary) -> Dictionary:
	var result := achievement_adjusted_abilities(character)
	for ability in ABILITIES:
		result[ability] = max(1, _as_int(result.get(ability, 10)) + mutations.mutation_ability_bonus(character, ability) + cybertech.cybertech_stat_bonus(character, ability) + fx.permanent_fx_stat_bonus(character, ability))
	return result


func achievement_ability_bonus(character: Dictionary, ability: String) -> int:
	return _as_int(effective_abilities(character).get(ability, 10)) - _as_int(character.get("abilities", {}).get(ability, 10))


func ability_total(character: Dictionary) -> int:
	var total := 0
	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		total += _as_int(abilities.get(ability, 0))
	return total


func ability_point_total(character: Dictionary = {}) -> int:
	if not character.is_empty() and character.has("custom_ability_target"):
		return _as_int(character["custom_ability_target"])
	return _as_int(data.get("ability_point_total", 60))


func profession_ability_minimums(character: Dictionary) -> Dictionary:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var minimums: Dictionary = profession.get("ability_minimums", {})
	return minimums


func profession_ability_minimum(character: Dictionary, ability: String) -> int:
	return _as_int(profession_ability_minimums(character).get(ability, 0))


func ability_limits(character: Dictionary, ability: String) -> Array:
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var limits: Dictionary = current_species.get("ability_limits", {})
	var species_limits: Array = limits.get(ability, [4, 14])
	var minimum: int = max(_as_int(species_limits[0]), profession_ability_minimum(character, ability))
	var maximum: int = _as_int(species_limits[1])
	return [minimum, maximum]


func effective_ability_limits(character: Dictionary, ability: String) -> Array:
	var limits := ability_limits(character, ability)
	var bonus := mutations.mutation_ability_bonus(character, ability)
	var maximum: int = _as_int(limits[1]) + maxi(0, bonus)
	if bonus < 0:
		maximum += bonus
	return [_as_int(limits[0]), maximum]


func clamp_abilities_to_species(character: Dictionary) -> void:
	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		var limits := ability_limits(character, ability)
		abilities[ability] = clampi(_as_int(abilities.get(ability, 10)), _as_int(limits[0]), _as_int(limits[1]))
	character["abilities"] = abilities


func untrained_score(score: int) -> int:
	return int(floor(score / 2.0))


# Table P2: Resistance Modifiers. Source: Player's Handbook p. 32.
func resistance_modifier(score: int) -> int:
	if score <= 4:
		return -2
	if score <= 6:
		return -1
	if score <= 10:
		return 0
	if score <= 12:
		return 1
	if score <= 14:
		return 2
	if score <= 16:
		return 3
	if score <= 18:
		return 4
	return 5


func character_resistance_modifier(character: Dictionary, ability: String) -> int:
	var score = 10
	var abilities := effective_abilities(character)
	if abilities.has(ability):
		score = _as_int(abilities[ability])
	var rm = resistance_modifier(score)

	# Free Agent RM Bonus (+1 to one modifier chosen by the player)
	if _as_int(character.get("profession_id", 0)) == 4: # Free Agent primary
		if String(character.get("free_agent_rm_bonus", "")) == ability:
			rm += 1

	# Perk Adjustments
	if ability == "STR" and is_perk_selected(character, "tough_as_nails"):
		rm += 1
	elif ability == "DEX" and is_perk_selected(character, "reflexes"):
		rm += 1
	elif ability == "WIL" and is_perk_selected(character, "willpower"):
		rm += 1

	# Flaw Adjustments
	if ability == "WIL" and is_flaw_selected(character, "spineless"):
		var val = _as_int(character.get("selected_flaws", {}).get("spineless", 0))
		rm -= int(val / 2.0)

	# Skill Rank Benefits
	var skill_bonus := 0
	if ability == "STR":
		var max_melee_bonus := 0
		for skill_id in [12, 13, 14, 17]: # Blade, Bludgeon, Powered weapon, Power Martial Arts
			var r := skill_rank(character, skill_id)
			var b := 0
			if r >= 12:
				b = 3
			elif r >= 8:
				b = 2
			elif r >= 4:
				b = 1
			if b > max_melee_bonus:
				max_melee_bonus = b
		skill_bonus += max_melee_bonus
	elif ability == "DEX":
		var r := skill_rank(character, 21) # Dodge
		if r >= 12:
			skill_bonus += 3
		elif r >= 8:
			skill_bonus += 2
		elif r >= 4:
			skill_bonus += 1
	elif ability == "INT":
		var r := skill_rank(character, 71) # Deduction
		if r >= 12:
			skill_bonus += 3
		elif r >= 8:
			skill_bonus += 2
		elif r >= 4:
			skill_bonus += 1
	elif ability == "WIL":
		var r := skill_rank(character, 135) # Resolve
		if r >= 12:
			skill_bonus += 3
		elif r >= 8:
			skill_bonus += 2
		elif r >= 4:
			skill_bonus += 1

	rm += skill_bonus

	# Table P12 Encumbrance: +1/+2/+3 step penalty to STR and DEX checks/resistance
	if ability == "STR" or ability == "DEX":
		var enc := encumbrance(character)
		rm -= _as_int(enc.get("penalty", 0))

	return rm


func action_check(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var base := int(floor((_as_int(abilities.get("DEX", 10)) + _as_int(abilities.get("INT", 10))) / 2.0))
	var ordinary := base + _as_int(profession.get("action_bonus", 0)) + achievements.achievement_effect_total(character, "action_check_score")
	var good := int(floor(ordinary / 2.0))
	var amazing := int(floor(ordinary / 4.0))
	var action_step := _as_int(current_species.get("action_step", 0)) + achievements.achievement_effect_total(character, "action_check_step") + mutations.mutation_action_check_step(character) + cybertech.cybertech_action_check_step(character)
	var penalty := dazed_penalty(character)
	return {
		"marginal": ordinary + 1,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"die": action_step_die(action_step + penalty),
		"actions": actions_per_round(character),
	}

func dazed_penalty(character: Dictionary) -> int:
	var penalty := 0
	if optional_rule_enabled(character, "dazed"):
		var dmg: Dictionary = character.get("damage", {})
		var max_durability := durability(character)
		if _as_int(dmg.get("stun", 0)) > int(floor(_as_int(max_durability.get("stun", 0)) / 2.0)):
			penalty += 1
		if _as_int(dmg.get("wound", 0)) > int(floor(_as_int(max_durability.get("wound", 0)) / 2.0)):
			penalty += 1
		penalty += _as_int(dmg.get("mortal", 0))
		penalty += _as_int(dmg.get("fatigue", 0))
	return penalty


func durability(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var constitution := _as_int(abilities.get("CON", 10))
	var multiplier := _as_float(current_species.get("durability_multiplier", 1.0))
	var durability_base := int(floor(constitution * multiplier))
	return {
		"stun": durability_base + achievements.achievement_durability_bonus(character, "stun") + mutations.mutation_durability_bonus(character, "stun") + cybertech.cybertech_durability_bonus(character, "stun"),
		"wound": durability_base + achievements.achievement_durability_bonus(character, "wound") + mutations.mutation_durability_bonus(character, "wound") + cybertech.cybertech_durability_bonus(character, "wound"),
		"mortal": int(ceil(durability_base / 2.0)) + achievements.achievement_durability_bonus(character, "mortal") + mutations.mutation_durability_bonus(character, "mortal") + cybertech.cybertech_durability_bonus(character, "mortal"),
		"fatigue": int(ceil(durability_base / 2.0)) + achievements.achievement_durability_bonus(character, "fatigue") + mutations.mutation_durability_bonus(character, "fatigue") + cybertech.cybertech_durability_bonus(character, "fatigue"),
	}


## Table P12: Encumbrance. Source: Player's Handbook p. 34.
func encumbrance(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var str_score := _as_int(abilities.get("STR", 10))
	var eq_summary: Dictionary = equipment.equipment_summary(character)
	var mass := _as_float(eq_summary.get("total_mass", 0.0))
	var light_limit := float(str_score * 2)
	var heavy_limit := float(str_score * 4)
	var severe_limit := float(str_score * 5)
	var extreme_limit := float(str_score * 6)

	var tier_name := "Normal"
	var movement_mult := 1.0
	var penalty := 0

	if mass <= light_limit:
		tier_name = "Normal"
		movement_mult = 1.0
		penalty = 0
	elif mass <= heavy_limit:
		tier_name = "Heavy"
		movement_mult = 0.75
		penalty = 1
	elif mass <= severe_limit:
		tier_name = "Severe"
		movement_mult = 0.50
		penalty = 2
	elif mass <= extreme_limit:
		tier_name = "Extreme"
		movement_mult = 0.25
		penalty = 3
	else:
		tier_name = "Immobile"
		movement_mult = 0.0
		penalty = 3

	return {
		"mass": mass,
		"tier": tier_name,
		"movement_multiplier": movement_mult,
		"penalty": penalty,
		"light_limit": light_limit,
		"heavy_limit": heavy_limit,
		"severe_limit": severe_limit,
		"extreme_limit": extreme_limit,
	}


## Table P8: Combat Movement Rates (Meters per Phase). Source: Player's Handbook p. 33.
func movement(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var movement_total := _as_int(abilities.get("STR", 10)) + _as_int(abilities.get("DEX", 10))
	var table_key := clampi(movement_total, 6, 32)
	if table_key % 2 != 0:
		table_key -= 1
	var rates: Dictionary = MOVEMENT_RATES_TABLE.get(table_key, {"sprint": 12, "run": 8, "walk": 2, "easy_swim": 1, "swim": 2, "glide": 12, "fly": 24})
	var sprint := _as_int(rates.get("sprint", 12))
	var run := _as_int(rates.get("run", 8))
	var walk := _as_int(rates.get("walk", 2))
	var easy_swim := _as_int(rates.get("easy_swim", 1))
	var swim := _as_int(rates.get("swim", 2))
	var can_glide := bool(current_species.get("can_glide", false)) or bool(mutations.mutation_movement_modes(character).get("glide", false))
	var can_fly := bool(current_species.get("can_fly", false)) or bool(mutations.mutation_movement_modes(character).get("fly", false))

	var enc := encumbrance(character)
	var mult: float = _as_float(enc.get("movement_multiplier", 1.0), 1.0)

	return {
		"total": movement_total,
		"sprint": int(floor(sprint * mult)),
		"run": int(floor(run * mult)),
		"walk": int(floor(walk * mult)),
		"easy_swim": int(floor(easy_swim * mult)),
		"swim": int(floor(swim * mult)),
		"glide": str(int(floor(sprint * mult))) if can_glide else "-",
		"fly": str(int(floor(sprint * 2 * mult))) if can_fly else "-",
		"effects": MOVEMENT_EFFECTS,
		"encumbrance": enc,
	}


## Table P7: Actions Per Round. Source: Player's Handbook p. 33.
func actions_per_round(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	var total := _as_int(abilities.get("CON", 10)) + _as_int(abilities.get("WIL", 10))
	var bonus := achievements.achievement_effect_total(character, "extra_action")
	var base := 1
	if total <= 15:
		base = 1
	elif total <= 23:
		base = 2
	elif total <= 31:
		base = 3
	else:
		base = 4
	return min(4, base + bonus)


func is_psionic_character(character: Dictionary) -> bool:
	if _as_int(character.get("species_id", 0)) == 1: # Fraal
		return true
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	return String(profession.get("code", "")) == "M" or String(profession.get("secondary_code", "")) == "M"


func psionic_energy_points(character: Dictionary) -> int:
	if not is_psionic_character(character):
		return 0
	var will := _as_int(effective_abilities(character).get("WIL", 10))
	var is_fraal := _as_int(character.get("species_id", 0)) == 1
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var is_primary_mindwalker := String(profession.get("code", "")) == "M"
	# Fraal Mindwalkers use WIL x 1.5. Fraal talents, Mindwalkers, and Diplomats
	# with Mindwalker as secondary profession use full WIL instead of one-half
	# WIL. Source: Player's Handbook p. 22 and Chapter 14.
	if is_fraal and is_primary_mindwalker:
		return int(will * 1.5)
	return will


func last_resorts(character: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var personality := _as_int(abilities.get("PER", 10))
	var base := _last_resort_base(personality)
	var bonus := _as_int(profession.get("last_resort_bonus", 0))
	var max_points := _as_int(base.get("max", 0)) + bonus
	var used := clampi(_as_int(character.get("last_resorts_used", 0)), 0, max_points)
	character["last_resorts_used"] = used
	return {
		"personality": personality,
		"base_max": _as_int(base.get("max", 0)),
		"profession_bonus": bonus,
		"max": max_points,
		"used": used,
		"available": max_points - used,
		"cost": _as_int(base.get("cost", 0)),
	}


func set_damage_used(character: Dictionary, damage_type: String, used: int) -> void:
	var damage: Dictionary = character.get("damage", {})
	var durability_scores := durability(character)
	damage[damage_type] = clampi(used, 0, _as_int(durability_scores.get(damage_type, 0)))
	character["damage"] = damage


func set_last_resorts_used(character: Dictionary, used: int) -> void:
	var current := last_resorts(character)
	character["last_resorts_used"] = clampi(used, 0, _as_int(current.get("max", 0)))


func clamp_trackers(character: Dictionary) -> void:
	var damage: Dictionary = character.get("damage", {})
	var durability_scores := durability(character)
	for damage_type in ["stun", "wound", "mortal", "fatigue"]:
		damage[damage_type] = clampi(_as_int(damage.get(damage_type, 0)), 0, _as_int(durability_scores.get(damage_type, 0)))
	character["damage"] = damage
	set_last_resorts_used(character, _as_int(character.get("last_resorts_used", 0)))


## Table P5: Starting Skill Point Budget. Source: Player's Handbook p. 34.
func starting_skill_budget(character: Dictionary) -> int:
	var abilities := effective_abilities(character)
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var is_human := String(current_species.get("name", "")) == "Human"
	var human_bonus := 5 if is_human else 0
	var flaw_bonus := flaw_skill_points_bonus(character)

	# Sold species broad skills bonus (+3 SP per sold skill)
	var sold_bonus := 0
	var sold_list: Array = character.get("sold_species_skills", [])
	for skill_id in get_free_skill_ids(character):
		if sold_list.has(skill_id):
			sold_bonus += 3

	var int_score := _as_int(abilities.get("INT", 10))
	var base := 0
	if optional_rule_enabled(character, "2a"):
		base = 30 + (3 * int_score) + human_bonus + flaw_bonus
	else:
		# Table P5: Aliens = (INT * 5) - 5, Humans = (INT * 5)
		base = (int_score * 5) - 5 + human_bonus + flaw_bonus
	return base + sold_bonus


func skill_budget(character: Dictionary) -> int:
	var total_ap := _as_int(character.get("achievement_points", 0))
	var ap_for_sp := achievements.achievement_points_for_current_level(total_ap)
	return starting_skill_budget(character) + ap_for_sp + achievements.achievement_skill_bonus(character)


## Table P5: Broad Skills Cap. Source: Player's Handbook p. 34.
func max_broad_skills(character: Dictionary) -> int:
	return racial_broad_skills_count(character) + additional_broad_skill_limit(character)


func racial_broad_skills_count(character: Dictionary) -> int:
	var count := 0
	for skill_id in get_free_skill_ids(character):
		if not skill_name_for_id(skill_id).is_empty():
			count += 1
	return count


## Table P5: Additional Broad Skills Allowance (excluding racial). Source: Player's Handbook p. 34.
func additional_broad_skill_limit(character: Dictionary) -> int:
	if optional_rule_enabled(character, "2b"):
		var intelligence_rm := character_resistance_modifier(character, "INT")
		return max(0, 6 + intelligence_rm)
	var abilities := effective_abilities(character)
	var int_score := _as_int(abilities.get("INT", 10))
	var current_species := get_species_by_id(_as_int(character.get("species_id", 0)))
	var is_human := String(current_species.get("name", "")) == "Human"
	var human_bonus := 1 if is_human else 0
	return int(floor(int_score / 2.0)) + human_bonus


func profession_codes(character: Dictionary) -> Array:
	var profession := get_profession_by_id(_as_int(character.get("profession_id", 0)))
	var codes := []
	var code := String(profession.get("code", ""))
	var secondary_code := String(profession.get("secondary_code", ""))
	if not code.is_empty():
		codes.append(code)
	if not secondary_code.is_empty():
		codes.append(secondary_code)
	return codes


func skill_cost(character: Dictionary, skill: Dictionary) -> int:
	if skill.get("type", "") == "broad" and is_free_species_skill(character, _as_int(skill.get("id", -1))):
		return 0

	var cost := _as_int(skill.get("base_price", 0))
	var skill_professions := String(skill.get("professions", ""))
	for code in profession_codes(character):
		if skill_professions.contains(String(code)):
			cost -= 1
			break
	return max(1, cost)


func skill_purchase_cost(character: Dictionary, skill: Dictionary, next_rank: int = 1) -> int:
	var free_rank := free_species_skill_rank(character, _as_int(skill.get("id", -1)))
	if next_rank <= free_rank:
		return 0
	if skill.get("type", "") == "broad":
		return skill_cost(character, skill) if next_rank <= 1 else 0

	var base_cost := skill_cost(character, skill)
	if next_rank <= 1 or optional_rule_enabled(character, "2c"):
		return base_cost
	return base_cost + max(0, next_rank - 1)


func skill_rank_total_cost(character: Dictionary, skill: Dictionary) -> int:
	var skill_id := _as_int(skill.get("id", -1))
	var rank := skill_rank(character, skill_id)
	if rank <= 0:
		return 0
	var free_rank := free_species_skill_rank(character, skill_id)
	if rank <= free_rank:
		return 0
	if skill.get("type", "") == "broad":
		return skill_cost(character, skill)

	var total := 0
	for next_rank in range(free_rank + 1, rank + 1):
		total += skill_purchase_cost(character, skill, next_rank)
	return total


## Specialty skill ranks are capped at Rank 3 at creation (Level 1), and Level + 2 in play (capped at 12).
## Source: Player's Handbook p. 34.
func max_skill_rank_for_character(character: Dictionary) -> int:
	if character.is_empty():
		return MAX_SPECIALTY_RANK
	var level := _as_int(character.get("achievement_level", 1))
	return clampi(level + 2, 1, MAX_SPECIALTY_RANK)



func next_skill_rank_cost(character: Dictionary, skill: Dictionary) -> int:
	var skill_id := _as_int(skill.get("id", -1))
	var rank := skill_rank(character, skill_id)
	if skill.get("type", "") == "broad":
		return skill_purchase_cost(character, skill, 1) if rank <= 0 else 0
	if rank >= max_skill_rank_for_character(character):
		return 0
	return skill_purchase_cost(character, skill, rank + 1)


func is_free_species_skill(character: Dictionary, skill_id: int) -> bool:
	return free_species_skill_rank(character, skill_id) > 0


func skill_rank(character: Dictionary, skill_id: int) -> int:
	var free_rank := free_species_skill_rank(character, skill_id)

	var selected: Dictionary = character.get("selected_skills", {})
	if not selected.has(str(skill_id)):
		return free_rank

	var skill := get_skill_by_id(skill_id)
	var rank := _selected_skill_entry_rank(selected.get(str(skill_id)))
	if skill.get("type", "") == "broad":
		return 1 if rank > 0 or free_rank > 0 else 0
	return max(free_rank, clampi(rank, 0, max_skill_rank_for_character(character)))


func is_skill_selected(character: Dictionary, skill_id: int) -> bool:
	return skill_rank(character, skill_id) > 0


func set_skill_selected(character: Dictionary, skill_id: int, selected: bool) -> void:
	set_skill_rank(character, skill_id, 1 if selected else 0)


func set_skill_rank(character: Dictionary, skill_id: int, rank: int) -> void:
	var selected_skills: Dictionary = character.get("selected_skills", {})
	var skill := get_skill_by_id(skill_id)
	if skill.is_empty():
		return
	var free_rank := free_species_skill_rank(character, skill_id)
	if skill.get("type", "") == "broad" and free_rank > 0:
		return

	if rank > free_rank:
		selected_skills[str(skill_id)] = 1 if skill.get("type", "") == "broad" else clampi(rank, 1, max_skill_rank_for_character(character))
		if skill.get("type", "") == "specialty":
			var broad_id := _as_int(skill.get("broad_id", -1))
			if is_normally_free_species_skill(character, broad_id):
				var sold_list: Array = character.get("sold_species_skills", [])
				if sold_list.has(broad_id):
					sold_list.erase(broad_id)
					character["sold_species_skills"] = sold_list
			elif not is_free_species_skill(character, broad_id):
				selected_skills[str(broad_id)] = 1
	else:
		selected_skills.erase(str(skill_id))
		if skill.get("type", "") == "broad":
			for specialty in specialty_skills_by_broad_id.get(skill_id, []):
				selected_skills.erase(str(_as_int(specialty.get("id", -1))))
	character["selected_skills"] = selected_skills


func change_skill_rank(character: Dictionary, skill_id: int, delta: int) -> void:
	set_skill_rank(character, skill_id, skill_rank(character, skill_id) + delta)


func set_perk_selected(character: Dictionary, perk_id: String, cost: int) -> void:
	_set_character_option_selected(character, "selected_perks", PERK_DEFINITIONS, "cost_options", perk_id, cost)


func set_flaw_selected(character: Dictionary, flaw_id: String, bonus: int) -> void:
	_set_character_option_selected(character, "selected_flaws", FLAW_DEFINITIONS, "bonus_options", flaw_id, bonus)



func is_flaw_selected(character: Dictionary, flaw_id: String) -> bool:
	var selected: Dictionary = character.get("selected_flaws", {})
	return selected.has(flaw_id)


func is_perk_selected(character: Dictionary, perk_id: String) -> bool:
	var selected: Dictionary = character.get("selected_perks", {})
	return selected.has(perk_id) or achievements.is_perk_granted_by_achievement(character, perk_id)


func perk_cost_selected(character: Dictionary, perk_id: String) -> int:
	var selected: Dictionary = character.get("selected_perks", {})
	return _as_int(selected.get(perk_id, 0))


func flaw_bonus_selected(character: Dictionary, flaw_id: String) -> int:
	var selected: Dictionary = character.get("selected_flaws", {})
	return _as_int(selected.get(flaw_id, 0))


func selected_perks(character: Dictionary) -> Array:
	var rows := _selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost")
	for granted in achievements.achievement_granted_perks(character):
		var granted_id := String(granted.get("id", ""))
		var already_listed := false
		for row in rows:
			if String(row.get("id", "")) == granted_id:
				already_listed = true
		if not already_listed:
			rows.append(granted)
	return rows


func selected_flaws(character: Dictionary) -> Array:
	return _selected_character_options(character, "selected_flaws", FLAW_DEFINITIONS, "bonus")


func perk_points_used(character: Dictionary) -> int:
	var total := 0
	for perk in _selected_character_options(character, "selected_perks", PERK_DEFINITIONS, "cost"):
		if not perk.get("gm_given", false):
			total += _as_int(perk.get("cost", 0))
	return total


func flaw_skill_points_bonus(character: Dictionary) -> int:
	var total := 0
	for flaw in selected_flaws(character):
		if not flaw.get("gm_given", false):
			total += _as_int(flaw.get("bonus", 0))
	return total


func selected_perk_count(character: Dictionary) -> int:
	return selected_perks(character).size()


func selected_flaw_count(character: Dictionary) -> int:
	return selected_flaws(character).size()


func non_gm_perk_count(character: Dictionary) -> int:
	var count := 0
	for perk in selected_perks(character):
		if not perk.get("granted_by_achievement", false) and not perk.get("gm_given", false):
			count += 1
	return count


func non_gm_flaw_count(character: Dictionary) -> int:
	var count := 0
	for flaw in selected_flaws(character):
		if not flaw.get("gm_given", false):
			count += 1
	return count


func set_perk_gm_given(character: Dictionary, perk_id: String, gm_given: bool) -> void:
	_set_character_option_gm_given(character, "selected_perks", perk_id, gm_given)


func set_flaw_gm_given(character: Dictionary, flaw_id: String, gm_given: bool) -> void:
	_set_character_option_gm_given(character, "selected_flaws", flaw_id, gm_given)


func _set_character_option_gm_given(character: Dictionary, selected_key: String, option_id: String, gm_given: bool) -> void:
	var selected: Dictionary = character.get(selected_key, {})
	if not selected.has(option_id):
		return
	var raw_val = selected[option_id]
	var value := _selected_character_option_entry_value(raw_val)
	if gm_given:
		selected[option_id] = {
			"value": value,
			"gm_given": true
		}
	else:
		selected[option_id] = value
	character[selected_key] = selected


func skill_purchase_points_used(character: Dictionary) -> int:
	var selected: Dictionary = character.get("selected_skills", {})
	var used := 0
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.is_empty():
			continue
		used += skill_rank_total_cost(character, skill)
	return used


func skill_points_used(character: Dictionary) -> int:
	var lr_rebought := _as_int(character.get("last_resorts_rebought", 0))
	var lr_cost := _as_int(last_resorts(character).get("cost", 0))
	var lr_spent := lr_rebought * lr_cost
	return skill_purchase_points_used(character) + perk_points_used(character) + achievements.achievement_points_spent(character) + cybertech.cybertech_skill_points_used(character) + fx.fx_skill_purchase_points_used(character) + lr_spent


func broad_skills_used(character: Dictionary) -> int:
	var used_ids := {}
	for skill_id in get_free_skill_ids(character):
		if not skill_name_for_id(skill_id).is_empty():
			used_ids[_as_int(skill_id)] = true

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.get("type", "") == "broad":
			used_ids[_as_int(skill.get("id", -1))] = true
	return used_ids.size()


func additional_broad_skills_used(character: Dictionary) -> int:
	var used_ids := {}
	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		if skill.get("type", "") == "broad" and not is_free_species_skill(character, _as_int(skill.get("id", -1))):
			used_ids[_as_int(skill.get("id", -1))] = true
	return used_ids.size()


func selected_skill_ids(character: Dictionary) -> Array:
	var ids := []
	var sold: Array = character.get("sold_species_skills", [])
	for skill_id in get_free_skill_ids(character):
		if not sold.has(skill_id) or skill_rank(character, skill_id) > 0:
			if not ids.has(skill_id):
				ids.append(skill_id)
	for skill_id in get_free_specialty_skill_ids(character):
		if not ids.has(skill_id):
			ids.append(skill_id)

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var id := _as_int(key)
		if not ids.has(id):
			if skill_rank(character, id) > 0:
				ids.append(id)

	ids.sort()
	return ids


func selected_skills(character: Dictionary) -> Array:
	var rows := []
	for skill_id in selected_skill_ids(character):
		var skill := get_skill_by_id(skill_id)
		if skill.is_empty():
			continue
		var row := skill.duplicate(true)
		row["rank"] = skill_rank(character, skill_id)
		row["cost"] = skill_rank_total_cost(character, skill)
		row["next_cost"] = next_skill_rank_cost(character, skill)
		row["free"] = is_free_species_skill(character, skill_id)
		row["free_rank"] = free_species_skill_rank(character, skill_id)
		row["score"] = skill_score(character, skill)
		rows.append(row)
	return rows


func skill_score(character: Dictionary, skill: Dictionary) -> Dictionary:
	var abilities := effective_abilities(character)
	var skill_id := _as_int(skill.get("id", -1))
	var ability := String(skill.get("stat", "STR"))
	var rank_bonus := 0 if skill.get("type", "") == "broad" else skill_rank(character, skill_id)
	var ordinary := _as_int(abilities.get(ability, 10)) + rank_bonus
	var good := int(floor(ordinary / 2.0))
	var step := 1 if skill.get("type", "") == "broad" else 0
	step += _species_skill_step_bonus(character, skill_id)
	step += mutations.mutation_skill_step_bonus(character, skill_id)
	step += dazed_penalty(character)
	
	# Table P12 Encumbrance: +1/+2/+3 step penalty to STR and DEX checks
	if ability == "STR" or ability == "DEX":
		var enc := encumbrance(character)
		step += _as_int(enc.get("penalty", 0))

	# Mindwalker profession bonus (-1 step to focused broad skill and its specialties)
	if _as_int(character.get("profession_id", 0)) == 6:
		var broad_id := skill_id if skill.get("type", "") == "broad" else _as_int(skill.get("broad_id", -1))
		if _as_int(character.get("mindwalker_psionic_focus", -1)) == broad_id:
			step -= 1
			
	# Combat Spec profession bonus (-1 step to chosen combat specialty skill)
	if _as_int(character.get("profession_id", 0)) == 0: # Combat Spec primary
		if skill.get("type", "") == "specialty" and _as_int(character.get("combat_spec_bonus_specialty", -1)) == skill_id:
			step -= 1
			
	return {
		"ordinary": ordinary,
		"good": good,
		"amazing": int(floor(ordinary / 4.0)),
		"die": action_step_die(step),
	}



func _species_skill_step_bonus(character: Dictionary, skill_id: int) -> int:
	var species_id := _as_int(character.get("species_id", 0))
	if species_id == 2 and (skill_id == 62 or skill_id == 70):
		return -1
	if species_id == 4 and skill_id == 116:
		return -1
	return 0


func validate(character: Dictionary) -> Array:
	var messages := []

	_validate_abilities(character, messages)
	_validate_skills(character, messages)
	_validate_perks_and_flaws(character, messages)
	_validate_achievements(character, messages)
	_validate_mutations(character, messages)

	return messages


func _validate_abilities(character: Dictionary, messages: Array) -> void:
	var total := ability_total(character)
	var target := ability_point_total(character)
	if total != target:
		messages.append("Ability total must be %d; current total is %d." % [target, total])

	var abilities: Dictionary = character.get("abilities", {})
	for ability in ABILITIES:
		var limits := ability_limits(character, ability)
		var score := _as_int(abilities.get(ability, 0))
		if score < _as_int(limits[0]) or score > _as_int(limits[1]):
			messages.append("%s must be between %d and %d for this species and profession. Source: Player's Handbook Tables P1 and P3." % [ability, _as_int(limits[0]), _as_int(limits[1])])
		var achievement_adjusted_score := _as_int(achievement_adjusted_abilities(character).get(ability, score))
		if achievement_adjusted_score > _as_int(limits[1]):
			messages.append("%s achievement increases exceed the species maximum of %d." % [ability, _as_int(limits[1])])


func _validate_skills(character: Dictionary, messages: Array) -> void:
	var remaining := skill_budget(character) - skill_points_used(character)
	if remaining < 0:
		messages.append("Skill points are overspent by %d." % abs(remaining))

	if optional_rule_enabled(character, "2b"):
		var additional_broad_remaining := additional_broad_skill_limit(character) - additional_broad_skills_used(character)
		if additional_broad_remaining < 0:
			messages.append("Additional broad skills exceed Optional Rule 2B by %d." % abs(additional_broad_remaining))
	else:
		var broad_remaining := max_broad_skills(character) - broad_skills_used(character)
		if broad_remaining < 0:
			messages.append("Broad skills exceed the allowed maximum by %d." % abs(broad_remaining))

	var selected: Dictionary = character.get("selected_skills", {})
	for key in selected.keys():
		var skill := get_skill_by_id(_as_int(key))
		var rank := skill_rank(character, _as_int(key))
		var max_rank := max_skill_rank_for_character(character)
		if skill.get("type", "") == "specialty" and rank > max_rank:
			messages.append("%s cannot exceed rank %d." % [skill_label(skill), max_rank])
		if skill.get("type", "") != "specialty":
			continue
		var broad_id := _as_int(skill.get("broad_id", -1))
		if not is_skill_selected(character, broad_id):
			var broad_skill := get_skill_by_id(broad_id)
			messages.append("%s requires the %s broad skill." % [skill.get("name", "Specialty"), broad_skill.get("name", "parent")])


func _validate_perks_and_flaws(character: Dictionary, messages: Array) -> void:
	var perks_limit_count := non_gm_perk_count(character)
	if perks_limit_count > 3:
		messages.append("A starting hero can have no more than three standard perks (excluding GM-given). Current: %d. Source: Player's Handbook p. 103." % perks_limit_count)

	var flaws_limit_count := non_gm_flaw_count(character)
	if flaws_limit_count > 3:
		messages.append("A starting hero can have no more than three standard flaws (excluding GM-given). Current: %d. Source: Player's Handbook p. 107." % flaws_limit_count)


func _validate_achievements(character: Dictionary, messages: Array) -> void:
	for entry in achievements.selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var min_level := _as_int(achievements.achievement_cost_entry(achievement, character).get("min_level", 99))
		var bought_level := _as_int(entry.get("level", 1))
		if bought_level < min_level:
			messages.append("%s requires hero level %d for the current profession." % [String(entry.get("name", achievement.get("name", "Achievement"))), min_level])
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "remove_flaw" and String(entry.get("target_id", "")).is_empty():
			messages.append("Remove Flaw requires a selected flaw target.")


func _validate_mutations(character: Dictionary, messages: Array) -> void:
	if mutations.mutations_enabled(character):
		var advantages := mutations.selected_mutation_advantages(character)
		var drawbacks := mutations.selected_mutation_drawbacks(character)
		if advantages.is_empty():
			messages.append("A mutant hero must have at least one advantageous mutation. Source: Player's Handbook p. 214.")
		if drawbacks.is_empty():
			messages.append("A mutant hero must have at least one mutation drawback. Source: Player's Handbook p. 214.")
		if mutations.mutation_advantage_points_remaining(character) < 0:
			messages.append("Advantageous mutation points are overspent by %d." % abs(mutations.mutation_advantage_points_remaining(character)))
		if mutations.mutation_drawback_points_remaining(character) < 0:
			messages.append("Mutation drawback points are overspent by %d." % abs(mutations.mutation_drawback_points_remaining(character)))
		for tier in ["Ordinary", "Good", "Amazing"]:
			var cap := mutations._mutation_advantage_tier_cap(tier)
			var count := mutations._mutation_tier_count(advantages, tier)
			var allowed_count := _as_int(mutations.mutation_distribution(character, "advantage").get(tier, 0))
			if count > allowed_count:
				messages.append("Advantageous mutations exceed the selected point distribution for %s by %d." % [tier, count - allowed_count])
			if cap > 0 and count > cap:
				messages.append("A mutant can have no more than %d %s advantageous mutation%s. Source: Player's Handbook p. 216." % [cap, tier, "" if cap == 1 else "s"])
		for tier in ["Slight", "Moderate", "Extreme"]:
			var count := mutations._mutation_tier_count(drawbacks, tier)
			var allowed_count := _as_int(mutations.mutation_distribution(character, "drawback").get(tier, 0))
			if count > allowed_count:
				messages.append("Mutation drawbacks exceed the selected point distribution for %s by %d." % [tier, count - allowed_count])


func summary(character: Dictionary) -> Dictionary:
	ensure_character_shape(character)
	var current_hash := character.hash()
	if current_hash == _last_character_hash and not _cached_summary.is_empty():
		return _cached_summary

	var used_points := skill_points_used(character)
	var broad_used := broad_skills_used(character)
	var additional_broad_used := additional_broad_skills_used(character)
	var additional_broad_max := additional_broad_skill_limit(character)
	var achievement_points := _as_int(character.get("achievement_points", 0))
	var achievement_used := achievements.achievement_points_used(character)
	var achievement_available := achievements.achievement_points_available(character)
	var perk_points := perk_points_used(character)
	var flaw_bonus := flaw_skill_points_bonus(character)
	var skill_purchase_points := skill_purchase_points_used(character)
	var achievement_spending := achievements.achievement_points_spent(character)
	var sold_list: Array = character.get("sold_species_skills", [])
	var sold_broads_count := 0
	for skill_id in get_free_skill_ids(character):
		if sold_list.has(skill_id):
			sold_broads_count += 1

	character["achievement_points_available"] = achievement_available
	_cached_summary = {
		"achievement_level": achievements.achievement_level_for_points(achievement_points),
		"achievement_points": achievement_points,
		"achievement_points_for_sp": achievements.achievement_points_for_current_level(achievement_points),
		"achievements.achievement_points_used": achievement_used,
		"achievements.achievement_points_available": achievement_available,
		"achievements.achievement_next_level_points": achievements.achievement_next_level_points(achievement_points),
		"achievements.achievement_skill_bonus": achievements.achievement_skill_bonus(character),
		"starting_skill_budget": starting_skill_budget(character),
		"sold_broads_count": sold_broads_count,
		"ability_total": ability_total(character),
		"ability_target": ability_point_total(character),
		"effective_abilities": effective_abilities(character),
		"skill_budget": skill_budget(character),
		"skill_points_used": used_points,
		"skill_purchase_points_used": skill_purchase_points,
		"skill_points_remaining": skill_budget(character) - used_points,
		"achievement_benefit_points_used": achievement_spending,
		"achievements.selected_achievements": achievements.selected_achievements(character),
		"perk_points_used": perk_points,
		"perk_count": selected_perk_count(character),
		"flaw_skill_points_bonus": flaw_bonus,
		"flaw_count": selected_flaw_count(character),
		"broad_skills_used": broad_used,
		"max_broad_skills": max_broad_skills(character),
		"broad_skills_remaining": max_broad_skills(character) - broad_used,
		"racial_broad_skills": racial_broad_skills_count(character),
		"additional_broad_skills_used": additional_broad_used,
		"additional_broad_skill_limit": additional_broad_max,
		"additional_broad_skills_remaining": additional_broad_max - additional_broad_used,
		"action_check": action_check(character),
		"durability": durability(character),
		"movement": movement(character),
		"encumbrance": encumbrance(character),
		"age_category": age_category(character),
		"last_resorts": last_resorts(character),
		"equipment": equipment.equipment_summary(character),
		"mutations": mutations.mutation_summary(character),
		"cybertech": cybertech.cybertech_summary(character),
		"permanent_fx_effects": fx.permanent_fx_effects_summary(character),
		"validations": validate(character),
	}
	_last_character_hash = current_hash
	return _cached_summary


## Evaluate a dice check against a target score.
## Core formula: Roll 1d20 (Control Die) +/- Situation Die <= Target Score.
## Degrees of Success: Critical Failure (natural 20), Failure (> target),
## Marginal (= target + 1), Ordinary (<= target), Good (<= target / 2),
## Amazing (<= target / 4), Auto Success (natural 1 unless situation die >= +d20).
func resolve_check(control_die: int, situation_roll: int, target_score: int, situation_die_str: String = "", allow_marginal: bool = true) -> Dictionary:
	var total := control_die + situation_roll
	var is_crit_fail := control_die == 20
	var is_auto_success := false
	if control_die == 1:
		var parsed := DiceNotation.parse(situation_die_str)
		var sides := _as_int(parsed.get("sides", 0))
		var sign := _as_int(parsed.get("sign", 1), 1)
		# Automatic Success unless situation die is +d20 or higher (step >= 5)
		if not (sign > 0 and sides >= 20):
			is_auto_success = true

	var degree := ""
	if is_crit_fail:
		degree = "Critical Failure"
	elif is_auto_success and total > target_score:
		degree = "Ordinary" # Auto success ensures at least Ordinary
	elif total <= int(floor(target_score / 4.0)):
		degree = "Amazing"
	elif total <= int(floor(target_score / 2.0)):
		degree = "Good"
	elif total <= target_score:
		degree = "Ordinary"
	elif allow_marginal and total == target_score + 1:
		degree = "Marginal"
	else:
		degree = "Failure"

	return {
		"control_die": control_die,
		"situation_roll": situation_roll,
		"total": total,
		"target_score": target_score,
		"degree": degree,
		"is_success": degree in ["Ordinary", "Good", "Amazing", "Marginal"],
		"is_critical_failure": is_crit_fail,
		"is_auto_success": is_auto_success,
	}


## Applies damage according to Alternity damage propagation & degradation rules.
## Damage types: "stun", "wound", "mortal", "fatigue".
## Armor absorbs primary damage only; armor never absorbs secondary damage.
## Secondary Stun from Wound: floor(attack_damage / 2).
## Secondary Damage from Mortal: floor(attack_damage / 2) Wound and floor(attack_damage / 2) Stun.
## Heavy Stun overflow: 2 excess stun -> 1 wound.
## Heavy Wound overflow: 2 excess wound -> 1 mortal.
func apply_damage(character: Dictionary, attack_damage: int, damage_type: String, armor_absorption: int = 0) -> Dictionary:
	var primary_dmg: int = max(0, attack_damage - armor_absorption)
	var secondary_stun := 0
	var secondary_wound := 0

	if damage_type == "wound":
		secondary_stun = int(floor(attack_damage / 2.0))
	elif damage_type == "mortal":
		secondary_wound = int(floor(attack_damage / 2.0))
		secondary_stun = int(floor(attack_damage / 2.0))

	var dur := durability(character)
	var damage: Dictionary = character.get("damage", {}).duplicate()
	var current_stun := _as_int(damage.get("stun", 0))
	var current_wound := _as_int(damage.get("wound", 0))
	var current_mortal := _as_int(damage.get("mortal", 0))
	var current_fatigue := _as_int(damage.get("fatigue", 0))

	var max_stun := _as_int(dur.get("stun", 0))
	var max_wound := _as_int(dur.get("wound", 0))
	var max_mortal := _as_int(dur.get("mortal", 0))
	var max_fatigue := _as_int(dur.get("fatigue", 0))

	# 1. Apply primary damage
	if damage_type == "stun":
		current_stun += primary_dmg
	elif damage_type == "wound":
		current_wound += primary_dmg
	elif damage_type == "mortal":
		current_mortal += primary_dmg
	elif damage_type == "fatigue":
		current_fatigue = min(max_fatigue, current_fatigue + primary_dmg)

	# 2. Apply secondary damage
	current_stun += secondary_stun
	current_wound += secondary_wound

	# 3. Handle Heavy Stun overflow (2 stun -> 1 wound)
	if current_stun > max_stun:
		var overflow_stun := current_stun - max_stun
		current_stun = max_stun
		current_wound += int(floor(overflow_stun / 2.0))

	# 4. Handle Heavy Wound overflow (2 wound -> 1 mortal)
	if current_wound > max_wound:
		var overflow_wound := current_wound - max_wound
		current_wound = max_wound
		current_mortal += int(floor(overflow_wound / 2.0))

	current_mortal = min(max_mortal, current_mortal)

	damage["stun"] = current_stun
	damage["wound"] = current_wound
	damage["mortal"] = current_mortal
	damage["fatigue"] = current_fatigue
	character["damage"] = damage

	return {
		"primary_damage": primary_dmg,
		"secondary_stun": secondary_stun,
		"secondary_wound": secondary_wound,
		"damage": damage,
	}


func skill_detail(skill: Dictionary, character: Dictionary = {}) -> Dictionary:

	var skill_id := _as_int(skill.get("id", -1))
	var broad := get_skill_by_id(_as_int(skill.get("broad_id", skill_id)))
	var type_label := "Broad skill" if skill.get("type", "") == "broad" else "Specialty skill"
	var ability := String(skill.get("stat", "STR"))
	var current_rank := skill_rank(character, skill_id) if not character.is_empty() else 0
	var summary_text := _skill_summary(skill)
	var roll_notes := _skill_roll_notes(skill)
	var complex_note := String(COMPLEX_SKILL_NOTES.get(skill_id, ""))
	var rank_benefits: Dictionary = RANK_BENEFIT_NOTES.get(skill_id, {})

	return {
		"id": skill_id,
		"name": skill_label(skill),
		"type_label": type_label,
		"ability": ability,
		"ability_name": ABILITY_NAMES.get(ability, ability),
		"broad_name": String(broad.get("name", "")),
		"rank": current_rank,
		"max_rank": max_skill_rank_for_character(character) if skill.get("type", "") == "specialty" else 1,
		"base_price": _as_int(skill.get("base_price", 0)),
		"rank_one_cost": skill_cost(character, skill) if not character.is_empty() else _as_int(skill.get("base_price", 0)),
		"next_cost": next_skill_rank_cost(character, skill) if not character.is_empty() else _as_int(skill.get("base_price", 0)),
		"profession_codes": String(skill.get("professions", "")),
		"untrained": bool(skill.get("untrained", true)),
		"multi": bool(skill.get("multi", false)),
		"custom_name": bool(skill.get("custom_name", false)),
		"summary": summary_text,
		"roll_notes": roll_notes,
		"complex_check": complex_note,
		"rank_benefits": rank_benefits,
		"sources": _skill_sources(skill),
	}


func _skill_sources(skill: Dictionary) -> Array:
	var skill_id := _as_int(skill.get("id", -1))
	var broad_id := _as_int(skill.get("broad_id", skill_id))
	var sources := []
	if SKILL_SOURCE_REFERENCES.has(skill_id):
		sources.append_array(SKILL_SOURCE_REFERENCES[skill_id])
	elif SKILL_SOURCE_REFERENCES.has(broad_id):
		sources.append_array(SKILL_SOURCE_REFERENCES[broad_id])
	else:
		if skill.get("source", "") == "psionics":
			sources.append("Player's Handbook Chapter 14: Psionics.")
		elif skill.get("source", "") == "mutations":
			sources.append("Player's Handbook Chapter 13: Mutants.")
		else:
			sources.append("Player's Handbook Chapter 4.")
	return _unique_strings(sources)


func skill_roll_notes_for_character(character: Dictionary) -> Array:
	var notes := []
	var selected := selected_skills(character)

	if not selected.is_empty():
		notes.append("Broad skills roll the ability score with a +d4 base situation die; specialty skills roll ability + rank with +d0. %s" % CORE_SKILL_ROLL_SOURCE)
		notes.append("A trained broad skill can be used for related specialties at the broad skill score unless the specialty is prohibited from untrained use. %s" % CORE_SKILL_ROLL_SOURCE)

	for note in species_roll_notes_for_character(character):
		notes.append(String(note))
	for note in mutations.mutation_roll_notes_for_character(character):
		notes.append(String(note))
	if selected.is_empty():
		return _unique_strings(notes)

	for skill in selected:
		var skill_id := _as_int(skill.get("id", -1))
		var complex_note := String(COMPLEX_SKILL_NOTES.get(skill_id, ""))
		if not complex_note.is_empty():
			notes.append("%s: %s %s %s %s" % [
				skill_label(skill),
				complex_note,
				COMPLEX_CHECK_RULES["successes"],
				COMPLEX_CHECK_RULES["failures"],
				COMPLEX_CHECK_SOURCE,
			])

		for note in _skill_summary_roll_notes(skill):
			notes.append("%s: %s" % [skill_label(skill), note])

	return _unique_strings(notes)


func skill_rank_benefit_groups(character: Dictionary) -> Array:
	var groups := []
	for skill in selected_skills(character):
		var skill_id := _as_int(skill.get("id", -1))
		var benefits: Dictionary = RANK_BENEFIT_NOTES.get(skill_id, {})
		if benefits.is_empty():
			continue

		var rank := _as_int(skill.get("rank", skill_rank(character, skill_id)))
		var entries := []
		var thresholds := benefits.keys()
		thresholds.sort()
		for threshold in thresholds:
			var required_rank := _as_int(threshold)
			if rank >= required_rank:
				entries.append({
					"rank": required_rank,
					"text": String(benefits[threshold]),
				})
		if not entries.is_empty():
			groups.append({
				"skill": skill_label(skill),
				"entries": entries,
			})
			
	# FX skills rank benefits
	if fx.is_fx_talent(character):
		for s in fx.selected_fx_skills(character):
			if s.get("type", "") == "specialty":
				var s_name = String(s.get("name", ""))
				var rank = fx.fx_skill_rank(character, s_name)
				var benefits: Dictionary = s.get("rank_benefits", {})
				if benefits.is_empty():
					continue
					
				var entries := []
				var thresholds := benefits.keys()
				thresholds.sort_custom(func(a, b): return int(a) < int(b))
				for threshold in thresholds:
					var required_rank := int(threshold)
					if rank >= required_rank:
						entries.append({
							"rank": required_rank,
							"text": String(benefits[threshold]),
						})
				if not entries.is_empty():
					groups.append({
						"skill": s_name,
						"entries": entries,
					})
	return groups


func action_step_die(step: int) -> String:
	var step_dice := {
		-5: "-d20",
		-4: "-d12",
		-3: "-d8",
		-2: "-d6",
		-1: "-d4",
		0: "+d0",
		1: "+d4",
		2: "+d6",
		3: "+d8",
		4: "+d12",
		5: "+d20",
		6: "+2d20",
		7: "+3d20",
	}
	if step < -5:
		return "-d20" # Cap at -5
	if step > 7:
		return "+%dd20" % (step - 4) # Pattern continues: +8 is +4d20 etc.
	return step_dice.get(step, "+d0")


func skill_label(skill: Dictionary) -> String:
	if skill.get("type", "") == "broad":
		return String(skill.get("name", ""))
	var broad := get_skill_by_id(_as_int(skill.get("broad_id", -1)))
	if broad.is_empty():
		return String(skill.get("name", ""))
	return "%s - %s" % [broad.get("name", ""), skill.get("name", "")]


func _index_skills() -> void:
	skills_by_id.clear()
	broad_skills.clear()
	specialty_skills_by_broad_id.clear()

	for skill in skills:
		var id := _as_int(skill.get("id", -1))
		skills_by_id[id] = skill
		if skill.get("type", "") == "broad":
			broad_skills.append(skill)
		else:
			var broad_id := _as_int(skill.get("broad_id", -1))
			if not specialty_skills_by_broad_id.has(broad_id):
				specialty_skills_by_broad_id[broad_id] = []
			specialty_skills_by_broad_id[broad_id].append(skill)

	broad_skills.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	for broad_id in specialty_skills_by_broad_id.keys():
		specialty_skills_by_broad_id[broad_id].sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))


func _index_equipment() -> void:
	equipment_by_id.clear()
	for item in equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.is_empty():
			continue
		equipment_by_id[item_id] = item


func _index_achievements() -> void:
	achievements_by_id.clear()
	for item in achievement_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.is_empty():
			continue
		achievements_by_id[item_id] = item




func _normalize_selected_skills(character: Dictionary) -> void:
	var selected: Dictionary = character.get("selected_skills", {})
	var normalized := {}
	for key in selected.keys():
		var skill_id := _as_int(key, -1)
		var skill := get_skill_by_id(skill_id)
		if skill.is_empty():
			continue

		var rank := _selected_skill_entry_rank(selected[key])
		if rank <= 0:
			continue
		normalized[str(skill_id)] = 1 if skill.get("type", "") == "broad" else clampi(rank, 1, max_skill_rank_for_character(character))
	character["selected_skills"] = normalized


func _normalize_selected_character_options(character: Dictionary, selected_key: String, definitions: Array, value_options_key: String) -> void:
	var selected: Dictionary = character.get(selected_key, {})
	var normalized := {}
	for key in selected.keys():
		var option_id := String(key)
		var definition := _get_character_option_by_id(definitions, option_id)
		if definition.is_empty():
			continue

		var raw_val = selected[key]
		var value := _selected_character_option_entry_value(raw_val)
		if not _character_option_value_allowed(definition, value_options_key, value):
			continue
		if typeof(raw_val) == TYPE_DICTIONARY:
			var entry: Dictionary = raw_val
			var norm_entry := {}
			norm_entry["value"] = value
			if entry.get("gm_given", false):
				norm_entry["gm_given"] = true
			normalized[option_id] = norm_entry
		else:
			normalized[option_id] = value
	character[selected_key] = normalized


func _get_character_option_by_id(definitions: Array, option_id: String) -> Dictionary:
	# Keep O(1) optimization if definitions happens to match the core constants
	if is_same(definitions, PERK_DEFINITIONS):
		return get_perk_by_id(option_id)
	elif is_same(definitions, FLAW_DEFINITIONS):
		return get_flaw_by_id(option_id)

	for item in definitions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = item
		if String(definition.get("id", "")) == option_id:
			return definition
	return {}


func _set_character_option_selected(character: Dictionary, selected_key: String, definitions: Array, value_options_key: String, option_id: String, value: int) -> void:
	var selected: Dictionary = character.get(selected_key, {})
	var definition := _get_character_option_by_id(definitions, option_id)
	if definition.is_empty() or value <= 0 or not _character_option_value_allowed(definition, value_options_key, value):
		selected.erase(option_id)
	else:
		var existing = selected.get(option_id)
		if typeof(existing) == TYPE_DICTIONARY:
			var new_entry = existing.duplicate()
			new_entry["value"] = value
			selected[option_id] = new_entry
		else:
			selected[option_id] = value
	character[selected_key] = selected


func _selected_character_options(character: Dictionary, selected_key: String, definitions: Array, value_key: String) -> Array:
	var selected: Dictionary = character.get(selected_key, {})
	var rows := []
	for item in definitions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var definition: Dictionary = item
		var option_id := String(definition.get("id", ""))
		if not selected.has(option_id):
			continue

		var row := definition.duplicate(true)
		var raw_val = selected.get(option_id)
		row[value_key] = _selected_character_option_entry_value(raw_val)
		if typeof(raw_val) == TYPE_DICTIONARY:
			row["gm_given"] = bool(raw_val.get("gm_given", false))
		else:
			row["gm_given"] = false
		rows.append(row)
	return rows


func _character_option_value_allowed(definition: Dictionary, value_options_key: String, value: int) -> bool:
	for option_value in definition.get(value_options_key, []):
		if _as_int(option_value) == value:
			return true
	return false


func _selected_character_option_entry_value(value) -> int:
	if typeof(value) == TYPE_DICTIONARY:
		var entry: Dictionary = value
		return _as_int(entry.get("value", entry.get("cost", entry.get("bonus", 0))))
	return _as_int(value, 0)


func _selected_skill_entry_rank(value) -> int:
	match typeof(value):
		TYPE_DICTIONARY:
			return _as_int(value.get("rank", value.get("level", 0)))
		TYPE_BOOL:
			return 1 if value else 0
	return _as_int(value, 0)


func _skill_summary(skill: Dictionary) -> String:
	var skill_id := _as_int(skill.get("id", -1))
	if SPECIALTY_SUMMARIES.has(skill_id):
		return String(SPECIALTY_SUMMARIES[skill_id])
	if skill.get("type", "") == "broad":
		return String(BROAD_SKILL_SUMMARIES.get(skill_id, "Use this broad skill for its related specialty skills."))

	var broad := get_skill_by_id(_as_int(skill.get("broad_id", -1)))
	var name := String(skill.get("name", "specialty"))
	if bool(skill.get("custom_name", false)) or name.contains("specific"):
		return "Choose a specific field when buying this specialty. It uses the %s broad skill and advances as a separate specialty." % broad.get("name", "parent")
	return "Specialized use of %s focused on %s." % [broad.get("name", "the parent broad skill"), name]


func _skill_roll_notes(skill: Dictionary) -> Array:
	var notes := []
	if skill.get("type", "") == "broad":
		notes.append("Score is the linked ability score. Base situation die is +d4.")
	else:
		notes.append("Score is linked ability + current specialty rank. Base situation die is +d0.")

	if not bool(skill.get("untrained", true)):
		notes.append("This skill is prohibited from untrained use; the broad skill alone is not enough.")
	elif skill.get("type", "") == "specialty":
		notes.append("If only the parent broad skill is trained, this specialty can be attempted at the broad skill score with +d4.")

	if bool(skill.get("multi", false)) or bool(skill.get("custom_name", false)):
		notes.append("This can be bought for multiple separate specialties or named fields.")

	for note in _skill_summary_roll_notes(skill):
		notes.append(note)

	return notes


const SKILL_SUMMARY_ROLL_NOTES := {
		0: ["Armor can impose action check and Dexterity resistance penalties; Armor Operation can reduce those penalties."],
		1: ["Combat armor ranks reduce armor penalties for standard combat armor."],
		2: ["Powered armor ranks reduce armor penalties for powered armor."],
		4: ["Combat climbing distance depends on success; long climbs can use complex checks."],
		5: ["Jump distance is based on the success level; critical failures can cause a hard fall."],
		11: ["Melee parries compare the defender's result to the attacker's result."],
		15: ["Overpowering is an unarmed attack used to grab and restrain; multiple attackers can assist."],
		20: ["Blocks compare the defender's Defensive Martial Arts result to the attacker's result."],
		21: ["Dodge adjusts the relevant resistance modifier based on success and costs an action unless a rank benefit changes that."],
		22: ["Fall checks reduce impact damage from falling."],
		24: ["Zero-g conditions penalize many physical actions unless the hero has enough training."],
		28: ["Higher ranks make it harder for a target to notice the attempt."],
		39: ["Stealth usually opposes Awareness or Investigate, depending on whether the observer is actively searching."],
		40: ["Hide is checked again when the situation changes, such as movement, light, or noise."],
		41: ["Shadow is usually opposed by the target's Awareness-intuition."],
		42: ["Sneak is used to move quietly while avoiding observation."],
		52: ["Fatigue and worsening mortal damage can call for Stamina-endurance checks."],
		54: ["Resist Pain can keep a hero acting under injury or pain."],
		61: ["Computer tasks often become complex checks when security, time, or quality matters."],
		85: ["Serious medical care often uses complex checks and can be affected by equipment and conditions."],
		114: ["Technical tasks can vary from one quick juryrig check to long complex checks."],
		125: ["Awareness is a common defensive skill for surprise, hidden details, and being followed."],
		130: ["Investigate often opposes concealment and can become complex when evidence is extensive."],
		142: ["Culture skills can set or change social reactions across cultures."],
		146: ["Deception is often resisted by a target's judgment or resistance modifiers."],
		155: ["Interaction skills often change attitudes, extract information, or impose social pressure."],
		162: ["Leadership affects other characters; exact benefits depend on the scene and GM judgment."],
		900: ["Allows attempting related specialty skills (except untrained-only ones) at broad score with +1 energy point cost and +d4 situation die."],
		90001: ["Generates biokinetic melee weapon (requires Melee Attack-bludgeon to wield). Initial check determines damage type: Ordinary=stun, Good=wound, Amazing=mortal. Wielder STR bonus modifies damage (d4/d4+2/d6+2)."],
		90002: ["Simulates environmental protection: Ordinary=vacuum mask, Good=jumpsuit, Amazing=soft e-suit. Maintenance costs 1 energy point per hour. Can slow bodily functions to fake death."],
		90003: ["Heals wound damage (Ordinary=1, Good=2, Amazing=3 points) or disease (reduces severity by 1/2/3 grades). Max once per hour. Rank 6 allows healing mortal damage (results change to Ordinary=2 wounds, Good=3 wounds or 1 mortal, Amazing=4 wounds or 2 mortals)."],
		90004: ["Squeeze, stretch, or disguise. Take 1 round (4 phases) to morph. Lasts 1/2/3 rounds (Ordinary/Good/Amazing); extendable at 1 point/round. Morphed elongated fingers can grant a -1 step bonus to Manipulation-pickpocket checks."],
		90005: ["Offset fatigue/stun damage. Restores 1 stun per point, 1 fatigue per 2 points. Ordinary/Good/Amazing success grants 2/4/6 rejuvenation points. Max once per hour."],
		90006: ["Lay hands to absorb patient's wounds or disease. Critical Failure: hero takes 1 wound. Success absorbs 1/2/3 wounds or 1 mortal. Reduces disease by 1/2/all grades (transfers disease to hero)."],
		901: ["Allows sending or reading thoughts. Untrained-only specialty skills cannot be attempted with broad skill alone."],
		90101: ["Send/receive thoughts. Ordinary=simple concepts, Good=moderate discussion (notes back and forth), Amazing=detailed discussion. Targets apply Will resistance; unwilling target can expel user via Will or Resolve check with a +1/+2/+3 penalty."],
		90102: ["Link mind to operate computers/cybernetics within 6 meters (+1 penalty if >2m, +2 if >4m). Normal defenses apply as check penalties."],
		90103: ["Fool target's sight/sound. Range 5m/rank. Maintains at +1 penalty to other actions. Target's Awareness-intuition check has +1/+2/+3 penalty. Additional targets add a cumulative +1 penalty."],
		90104: ["Pure mental energy blast at another mind up to 40 meters. Penetrates armor. Damage depends on success and rank (Rank < 5: d4+1s/d4+2s/d6+2s, Rank 5-8: d4+2s/d6+2s/d8+2s, Rank >= 9: 2d4+2s/2d6+2s/2d8+2s)."],
		90105: ["Defense against contact, empathy, illusion, mind reading, mind blast, suggest, and tire. Imposes +1/+2/+3 penalty to attacker. Collapses after failing to stop a power or after d4+4 hours."],
		90106: ["Mesmerize target to plant suggestion lasting 1/2/3 hours. GM sets situation modifier based on extremity (+3 or worse penalty for opposed to nature, -1/-2 bonus for inclined acts). Target gets Will check after suggest wears off to realize they were suggested, with reverse modifier."],
		90107: ["Inflicts 1/2/3 fatigue points on target within 30 meters."],
		902: ["Allows manipulating physical environment. Untrained-only specialty skills cannot be attempted with broad skill alone."],
		90201: ["Direct electrical shock up to 16 meters. Building charge takes a check; discharging in same/next round takes another check. Prevent other psionics while charged. Damage depends on check and rank (Rank < 5: d4+2s/d6+2s/d4w, Rank 5-8: d6+2s/d4w/d4+2w, Rank >= 9: d4+2w/d6+2w/d8+2w)."],
		90202: ["Defensive barrier: Ordinary=HI +1/LI +2, Good=HI +2/LI +3, Amazing=HI +3/LI +4. Action checks while maintaining the shield receive a +1 penalty."],
		90203: ["Fly/hover. Ascend/descend speed: Ordinary=2m, Good=4m, Amazing=6m. Speed doubled in light gravity, halved in heavy. Mid-air collapse causes impact damage. Active actions while levitating receive a +1 penalty."],
		90204: ["Illuminate object for 2 rounds. Daylight radius: Ordinary=2m, Good=4m, Amazing=6m."],
		90205: ["Move objects using mind. Lift weight is Will x 10 kg, push is Will x 20 kg. Lift/push speed: Ordinary=1/2m, Good=2/4m, Amazing=3/6m (doubled in light gravity, halved in heavy). Dropped objects suffer impact damage."],
		90206: ["Ignite target up to 30 meters. Targets air for flash fire storm (grenade-like 6m area fire, damage reduced by 2/3/4 points at 2/4/6 meters). Targets object/character for intense burn (may continue burning). Damage depends on check and rank (Rank < 5: d4+2w/d6+2w/d8+2w, Rank 5-8: d6+2w/d8+2w/d4m, Rank >= 9: d8+2w/d4m/d4+2m)."],
		903: ["Experience environment beyond normal senses. Untrained-only specialty skills cannot be attempted with broad skill alone."],
		90301: ["Bonus to action checks: Ordinary -1, Good -2, Amazing -3 steps/points."],
		90302: ["Hear sounds at projected location for 1/2/3 rounds. Distance and familiarity modifiers apply."],
		90303: ["See around projected location for 1/2/3 rounds. Double vision if eyes are open. Distance and familiarity modifiers apply."],
		90304: ["Read surface emotions in visual contact. Identifies emotional state and provides a step bonus of -1/-2/-3 to subsequent encounter skills."],
		90305: ["Read surface thoughts in visual contact. Cannot be extended. Ordinary=random thoughts (names/identity) for 1 phase, Good=reasons/location for 2 phases, Amazing=complete surface thoughts and key facts for 3 phases."],
		90306: ["Instinctive navigation, replacing Navigation skill by spending energy. Rank 1 chooses one Navigation specialty; rank 5 chooses a second; rank 9 makes the last specialty available."],
		90307: ["Sense mood or see events in an area up to (rank) hours/days into past. Ordinary=general emotions, Good=brief flashes, Amazing=experience brief encounter."],
		90308: ["Receive unconscious future impressions up to (rank) hours/days. Ordinary=vague images, Good=brief flashes, Amazing=experience brief encounter. Forcing a flash doubles cost, applies a +3 penalty, and blocks use for 2d6 days."],
		90309: ["Touch object to read OWNER'S psychic impressions. Ordinary=simple emotions, Good=simple images, Amazing=experience ownership/use encounter."],
		90310: ["Detect psionic use within 20 meters. Persists for 1 minute (extendable at 1 point/minute). Ordinary=tells who, Good=identifies broad skill, Amazing=identifies exact specialty skill."]
}


func _skill_summary_roll_notes(skill: Dictionary) -> Array:
	var skill_id := _as_int(skill.get("id", -1))
	var sourced_notes := []
	var source_text := _source_text_for_skill(skill)
	for note in SKILL_SUMMARY_ROLL_NOTES.get(skill_id, []):
		var text := String(note)
		if text.contains("Source:"):
			sourced_notes.append(text)
		else:
			sourced_notes.append("%s Source: %s" % [text, source_text])
	return sourced_notes


func _source_text_for_skill(skill: Dictionary) -> String:
	var sources := []
	for source in _skill_sources(skill):
		var clean_source := String(source).strip_edges()
		if clean_source.ends_with("."):
			clean_source = clean_source.left(clean_source.length() - 1)
		sources.append(clean_source)
	return "; ".join(sources)


func _species_notes_for_character(character: Dictionary, note_map: Dictionary) -> Array:
	var species_id := _as_int(character.get("species_id", 0))
	var notes := []
	for note in note_map.get(species_id, []):
		notes.append(String(note))
	return _unique_strings(notes)


func _unique_strings(values: Array) -> Array:
	var seen := {}
	var result := []
	for value in values:
		var text := String(value)
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result


## Table P6: Last Resort Points & Recovery Cost. Source: Player's Handbook p. 33.
func _last_resort_base(personality: int) -> Dictionary:
	if personality <= 7:
		return {"max": 0, "cost": 0}
	if personality <= 10:
		return {"max": 1, "cost": 3}
	if personality <= 12:
		return {"max": 2, "cost": 2}
	if personality <= 14:
		return {"max": 3, "cost": 1}
	return {"max": 4, "cost": 1}



## Deprecated forwarders. The implementations moved to AlternityNum (see
## scripts/core/num.gd) because they are pure and were being reached from the
## sub-modules through a weakref dereference. These remain so the existing call
## sites keep working; new code should call AlternityNum.as_int / as_float.
func _as_int(value: Variant, default_value: int = 0) -> int:
	return AlternityNum.as_int(value, default_value)


func _as_float(value, default_value := 0.0) -> float:
	return AlternityNum.as_float(value, default_value)


func psionic_armor_rows(character: Dictionary) -> Array:
	var rows := []
	if is_skill_selected(character, 90202): # Kinetic Shield
		var item := {
			"id": "psionic_90202",
			"kind": "armor",
			"name": "Kinetic Shield",
			"source": "Psionics",
			"source_code": "psionics",
			"reference": "Player's Handbook Chapter 14: Psionics.",
			"category": "Psionic Power",
			"class": "Energy Shield",
			"availability": "-",
			"mass": 0,
			"cost": 0,
			"combat": {
				"role": "armor",
				"action_penalty": 1,
				"toughness": "O",
				"li": "+2",
				"hi": "+1",
				"en": "",
			},
		}
		rows.append({
			"line_id": "psionic_90202",
			"item_id": "psionic_90202",
			"quantity": 1,
			"equipped": true,
			"slot": "Psionic",
			"item": item,
		})
	return rows