extends RefCounted

var _parent_ref: WeakRef

func _init(parent) -> void:
	_parent_ref = weakref(parent)

func _get_parent():
	return _parent_ref.get_ref()

func get_character_equipment_item(character: Dictionary, item_id: String) -> Dictionary:
	var catalog_item: Dictionary = _get_parent().get_equipment_item_by_id(item_id)
	if not catalog_item.is_empty():
		return catalog_item
	var equipment: Dictionary = character.get("equipment", {})
	if not equipment.has("_custom_items_by_id"):
		# Cache custom items as a dictionary by ID to achieve O(1) lookups
		# instead of repeatedly doing linear scans of the custom_items array.
		var cache := {}
		for item in equipment.get("custom_items", []):
			if typeof(item) == TYPE_DICTIONARY:
				cache[String(item.get("id", ""))] = item
		equipment["_custom_items_by_id"] = cache
	return equipment.get("_custom_items_by_id", {}).get(item_id, {})


func equipment_source_options() -> Array:
	var result := []
	var seen := {}
	for source in _get_parent().equipment_sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var source_id := String(source.get("id", source.get("name", ""))).to_lower()
		if source_id.is_empty() or seen.has(source_id):
			continue
		seen[source_id] = true
		result.append({
			"id": source_id,
			"name": String(source.get("name", source_id.capitalize())),
			"reference": String(source.get("reference", "")),
		})
	return result


func equipment_category_options() -> Array:
	return _equipment_string_options("category")


func equipment_class_options(category := "") -> Array:
	var options := []
	var seen := {}
	var category_filter := String(category)
	for item in _get_parent().equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if not category_filter.is_empty() and String(item.get("category", "")) != category_filter:
			continue
		var value := String(item.get("class", ""))
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		options.append(value)
	options.sort()
	return options


func filtered_equipment(filters: Dictionary) -> Array:
	var search := String(filters.get("search", "")).strip_edges().to_lower()
	var pl_min: int = _get_parent()._as_int(filters.get("pl_min", 0))
	var pl_max: int = _get_parent()._as_int(filters.get("pl_max", 8))
	if pl_min > pl_max:
		var swap: int = pl_min
		pl_min = pl_max
		pl_max = swap
	var category := String(filters.get("category", ""))
	var class_filter := String(filters.get("class", ""))
	var kind := String(filters.get("kind", ""))
	var source_filter: Dictionary = filters.get("sources", {})
	var use_source_filter := not source_filter.is_empty()
	var result: Array = []

	for item in _get_parent().equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_pl: int = _get_parent()._as_int(item.get("pl", 0))
		if item_pl < pl_min or item_pl > pl_max:
			continue
		var source_id := String(item.get("source_code", item.get("source", ""))).to_lower()
		if use_source_filter and not bool(source_filter.get(source_id, false)):
			continue
		if not kind.is_empty() and String(item.get("kind", "")) != kind:
			continue
		if not category.is_empty() and String(item.get("category", "")) != category:
			continue
		if not class_filter.is_empty() and String(item.get("class", "")) != class_filter:
			continue
		if not search.is_empty() and not _equipment_matches_search(item, search):
			continue
		result.append(item)
	return result


func add_equipment_to_character(character: Dictionary, item_id: String, quantity := 1) -> String:
	_normalize_equipment(character)
	if get_character_equipment_item(character, item_id).is_empty():
		return ""
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	var line_id := _next_equipment_line_id(character)
	carried.append({
		"line_id": line_id,
		"item_id": item_id,
		"quantity": max(1, quantity),
		"equipped": false,
		"slot": "",
		"notes": "",
	})
	equipment["carried"] = carried
	character["equipment"] = equipment
	return line_id


func add_custom_equipment_to_character(character: Dictionary, item: Dictionary, quantity := 1) -> String:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var custom_items: Array = equipment.get("custom_items", [])
	var custom_item := _normalize_equipment_item(item.duplicate(true), _next_custom_equipment_id(character))
	custom_items.append(custom_item)
	equipment["custom_items"] = custom_items
	equipment.erase("_custom_items_by_id")
	character["equipment"] = equipment
	return add_equipment_to_character(character, String(custom_item.get("id", "")), quantity)


func update_carried_equipment(character: Dictionary, line_id: String, quantity: int, equipped: bool, slot: String, notes: String) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	for index in range(carried.size()):
		if typeof(carried[index]) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = carried[index]
		if String(row.get("line_id", "")) != line_id:
			continue
		row["quantity"] = max(1, quantity)
		row["equipped"] = equipped
		row["slot"] = slot
		row["notes"] = notes
		carried[index] = row
		break
	equipment["carried"] = carried
	character["equipment"] = equipment


func update_custom_equipment_item(character: Dictionary, item_id: String, item: Dictionary) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var custom_items: Array = equipment.get("custom_items", [])
	for index in range(custom_items.size()):
		if typeof(custom_items[index]) != TYPE_DICTIONARY:
			continue
		var current: Dictionary = custom_items[index]
		if String(current.get("id", "")) != item_id:
			continue
		var normalized := _normalize_equipment_item(item.duplicate(true), item_id)
		normalized["id"] = item_id
		custom_items[index] = normalized
		break
	equipment["custom_items"] = custom_items
	equipment.erase("_custom_items_by_id")
	character["equipment"] = equipment


func remove_carried_equipment(character: Dictionary, line_id: String) -> void:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var carried: Array = equipment.get("carried", [])
	var next_carried := []
	var removed_item_id := ""
	for row in carried:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if String(row.get("line_id", "")) == line_id:
			removed_item_id = String(row.get("item_id", ""))
			continue
		next_carried.append(row)
	equipment["carried"] = next_carried
	character["equipment"] = equipment
	_remove_unused_custom_equipment(character, removed_item_id)


func carried_equipment(character: Dictionary) -> Array:
	_normalize_equipment(character)
	var equipment: Dictionary = character.get("equipment", {})
	var rows: Array = []
	for row in equipment.get("carried", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = get_character_equipment_item(character, String(row.get("item_id", "")))
		if item.is_empty():
			continue
		var quantity: int = max(1, _get_parent()._as_int(row.get("quantity", 1)))
		var result: Dictionary = row.duplicate(true)
		result["item"] = item
		result["quantity"] = quantity
		result["total_mass"] = _get_parent()._as_float(item.get("mass", 0.0)) * float(quantity)
		result["total_cost"] = _get_parent()._as_int(item.get("cost", 0)) * quantity
		rows.append(result)
	return rows


func equipment_summary(character: Dictionary) -> Dictionary:
	var rows := carried_equipment(character)
	var total_mass := 0.0
	var total_cost := 0
	var combat_weapons := []
	var combat_armor := []
	var equipped_weapons := []
	var equipped_armor := []
	for row in rows:
		total_mass += _get_parent()._as_float(row.get("total_mass", 0.0))
		total_cost += _get_parent()._as_int(row.get("total_cost", 0))
		var item: Dictionary = row.get("item", {})
		if equipment_has_combat_role(item, "weapon"):
			combat_weapons.append(row)
			if bool(row.get("equipped", false)):
				equipped_weapons.append(row)
		if equipment_has_combat_role(item, "armor"):
			combat_armor.append(row)
			if bool(row.get("equipped", false)):
				equipped_armor.append(row)
	for mutation_armor in _get_parent().mutations.mutation_armor_rows(character):
		combat_armor.append(mutation_armor)
		equipped_armor.append(mutation_armor)
	for psionic_armor in _get_parent().psionic_armor_rows(character):
		combat_armor.append(psionic_armor)
		equipped_armor.append(psionic_armor)
	return {
		"carried_count": rows.size(),
		"total_mass": total_mass,
		"total_cost": total_cost,
		"combat_weapons": combat_weapons,
		"combat_armor": combat_armor,
		"equipped_weapons": equipped_weapons,
		"equipped_armor": equipped_armor,
		"attack_forms": attack_forms_for_character(character),
	}


func attack_forms_for_character(character: Dictionary) -> Array:
	var forms := [_unarmed_attack_form(character)]
	for row in carried_equipment(character):
		var item: Dictionary = row.get("item", {})
		if not equipment_has_combat_role(item, "weapon"):
			continue
		var form := _weapon_attack_form(character, item)
		form["quantity"] = _get_parent()._as_int(row.get("quantity", 1))
		form["equipped"] = bool(row.get("equipped", false))
		form["slot"] = String(row.get("slot", ""))
		forms.append(form)
	for form in _get_parent().mutations.mutation_attack_forms(character):
		forms.append(form)
	for form in psionic_attack_forms(character):
		forms.append(form)
	return forms

func psionic_attack_forms(character: Dictionary) -> Array:
	var forms := []
	if _get_parent().is_skill_selected(character, 90001): # Bioweapon
		var score := _combat_skill_score(character, 90001)
		var abilities: Dictionary = _get_parent().effective_abilities(character)
		var strength_bonus := strength_damage_bonus(_get_parent()._as_int(abilities.get("STR", 10)))
		forms.append({
			"name": "Bioweapon",
			"score": _score_text(score),
			"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
			"type": "LI/O",
			"range": "Personal",
			"damage": _damage_with_bonus("d4s/d4+2w/d6+2m", strength_bonus), # Ordinary: stun, Good: wound, Amazing: mortal
			"hide": "-",
			"clip_size": "-",
			"mass": "",
		})
	if _get_parent().is_skill_selected(character, 90104): # Mind Blast
		var score := _combat_skill_score(character, 90104)
		var rank: int = _get_parent().skill_rank(character, 90104)
		var dmg := "d4+1s/d4+2s/d6+2s"
		if rank >= 9:
			dmg = "2d4+2s/2d6+2s/2d8+2s"
		elif rank >= 5:
			dmg = "d4+2s/d6+2s/d8+2s"
		forms.append({
			"name": "Mind Blast",
			"score": _score_text(score),
			"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
			"type": "En/O",
			"range": "10/20/40",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "",
		})
	if _get_parent().is_skill_selected(character, 90201): # Electrokinetics
		var score := _combat_skill_score(character, 90201)
		var rank: int = _get_parent().skill_rank(character, 90201)
		var dmg := "d4+2s/d6+2s/d4w"
		if rank >= 9:
			dmg = "d4+2w/d6+2w/d8+2w"
		elif rank >= 5:
			dmg = "d6+2s/d4w/d4+2w"
		forms.append({
			"name": "Electrokinetics",
			"score": _score_text(score),
			"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
			"type": "En/O",
			"range": "4/8/16",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "",
		})
	if _get_parent().is_skill_selected(character, 90206): # Pyrokinetics
		var score := _combat_skill_score(character, 90206)
		var rank: int = _get_parent().skill_rank(character, 90206)
		var dmg := "d4+2w/d6+2w/d8+2w"
		if rank >= 9:
			dmg = "d8+2w/d4m/d4+2m"
		elif rank >= 5:
			dmg = "d6+2w/d8+2w/d4m"
		forms.append({
			"name": "Pyrokinetics",
			"score": _score_text(score),
			"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
			"type": "En/O",
			"range": "10/20/30",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "",
		})
	if _get_parent().is_skill_selected(character, 90107): # Tire
		var score := _combat_skill_score(character, 90107)
		forms.append({
			"name": "Tire",
			"score": _score_text(score),
			"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
			"type": "-",
			"range": "10/20/30",
			"damage": "1f/2f/3f",
			"hide": "-",
			"clip_size": "-",
			"mass": "",
		})
	return forms



func equipment_has_combat_role(item: Dictionary, role: String) -> bool:
	var normalized_role := role.to_lower()
	if String(item.get("kind", "")).to_lower() == normalized_role:
		return true
	if String(item.get("combat_role", "")).to_lower() == normalized_role:
		return true
	var combat = item.get("combat", null)
	if typeof(combat) == TYPE_DICTIONARY and String(combat.get("role", "")).to_lower() == normalized_role:
		return true
	var roles = item.get("combat_roles", [])
	if typeof(roles) != TYPE_ARRAY:
		return false
	for entry in roles:
		if String(entry).to_lower() == normalized_role:
			return true
	return false


func _unarmed_attack_form(character: Dictionary) -> Dictionary:
	var score := _combat_skill_score(character, 15)
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var strength_bonus := strength_damage_bonus(_get_parent()._as_int(abilities.get("STR", 10)))
	return {
		"name": "Unarmed",
		"score": _score_text(score),
		"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 1))),
		"type": "LI/O",
		"range": "Personal",
		"damage": _damage_with_bonus("d4s/d4+1s/d4+2s", strength_bonus),
		"hide": "3",
		"clip_size": "-",
		"mass": "",
	}


func _weapon_attack_form(character: Dictionary, item: Dictionary) -> Dictionary:
	var combat_value = item.get("combat", {})
	var combat: Dictionary = combat_value if typeof(combat_value) == TYPE_DICTIONARY else {}
	var score := _combat_skill_score(character, _get_parent()._as_int(combat.get("skill_id", -1)))
	var accuracy: int = _get_parent()._as_int(combat.get("accuracy", 0))
	score["step"] = _get_parent()._as_int(score.get("step", 1)) + accuracy
	var damage := String(combat.get("damage", ""))
	if bool(combat.get("strength_based", false)):
		var abilities: Dictionary = _get_parent().effective_abilities(character)
		damage = _damage_with_bonus(damage, strength_damage_bonus(_get_parent()._as_int(abilities.get("STR", 10))))
	return {
		"name": String(item.get("name", "Weapon")),
		"score": _score_text(score),
		"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 0))),
		"type": String(combat.get("damage_type", combat.get("type", ""))),
		"range": String(combat.get("range", "")),
		"damage": damage,
		"hide": _dash_for_empty_or_hidden(combat.get("hide", "")),
		"clip_size": _dash_for_empty_or_zero(combat.get("clip_size", "")),
		"mass": _format_rules_number(_get_parent()._as_float(item.get("mass", 0.0))),
	}


func _combat_skill_score(character: Dictionary, skill_id: int) -> Dictionary:
	var skill: Dictionary = _get_parent().get_skill_by_id(skill_id)
	if skill.is_empty():
		return _untrained_combat_score(character, "STR", 1)

	var use_skill: Dictionary = skill
	var rank: int = _get_parent().skill_rank(character, skill_id)
	if rank <= 0:
		var broad_id: int = _get_parent()._as_int(skill.get("broad_id", skill_id))
		var broad: Dictionary = _get_parent().get_skill_by_id(broad_id)
		if String(skill.get("type", "")) == "specialty" and not broad.is_empty() and _get_parent().skill_rank(character, broad_id) > 0 and bool(skill.get("untrained", true)):
			use_skill = broad
		else:
			return _untrained_combat_score(character, String(skill.get("stat", "STR")), 1)

	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var selected_skill_id: int = _get_parent()._as_int(use_skill.get("id", skill_id))
	var rank_bonus: int = 0 if String(use_skill.get("type", "")) == "broad" else _get_parent().skill_rank(character, selected_skill_id)
	var ordinary: int = _get_parent()._as_int(abilities.get(String(use_skill.get("stat", "STR")), 10)) + rank_bonus
	var step := 1 if String(use_skill.get("type", "")) == "broad" else 0
	step += _get_parent()._species_skill_step_bonus(character, selected_skill_id)
	step += _get_parent().mutations.mutation_skill_step_bonus(character, selected_skill_id)
	
	# Mindwalker profession bonus (-1 step to focused broad skill and its specialties)
	if _get_parent()._as_int(character.get("profession_id", 0)) == 6:
		var broad_id: int = selected_skill_id if String(use_skill.get("type", "")) == "broad" else _get_parent()._as_int(use_skill.get("broad_id", -1))
		if _get_parent()._as_int(character.get("mindwalker_psionic_focus", -1)) == broad_id:
			step -= 1
			
	return _combat_score_from_ordinary(ordinary, step)


func _untrained_combat_score(character: Dictionary, ability: String, step: int) -> Dictionary:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	return _combat_score_from_ordinary(_get_parent().untrained_score(_get_parent()._as_int(abilities.get(ability, 10))), step)


func _combat_score_from_ordinary(ordinary: int, step: int) -> Dictionary:
	var good := int(floor(ordinary / 2.0))
	return {
		"ordinary": ordinary,
		"good": good,
		"amazing": int(floor(good / 2.0)),
		"step": step,
	}


func _score_text(score: Dictionary) -> String:
	return "%d/%d/%d" % [
		_get_parent()._as_int(score.get("ordinary", 0)),
		_get_parent()._as_int(score.get("good", 0)),
		_get_parent()._as_int(score.get("amazing", 0)),
	]


func strength_damage_bonus(score: int) -> int:
	if score <= 4:
		return -2
	if score <= 8:
		return -1
	if score <= 12:
		return 0
	if score <= 16:
		return 1
	return 2


func _damage_with_bonus(damage: String, bonus: int) -> String:
	if bonus == 0 or damage.strip_edges().is_empty():
		return damage
	var adjusted := []
	for segment in damage.split("/"):
		adjusted.append(_damage_segment_with_bonus(String(segment).strip_edges(), bonus))
	return "/".join(adjusted)


func _damage_segment_with_bonus(segment: String, bonus: int) -> String:
	if segment.length() < 2:
		return segment
	var suffix := segment.right(1)
	if not ["s", "w", "m"].has(suffix):
		return segment
	var core := segment.left(segment.length() - 1)
	var die_index := core.find("d")
	if die_index < 0:
		return segment
	var modifier_index := -1
	for index in range(die_index + 1, core.length()):
		var character := core.substr(index, 1)
		if character == "+" or character == "-":
			modifier_index = index
	var base := core
	var current_modifier := 0
	if modifier_index >= 0:
		base = core.left(modifier_index)
		current_modifier = _get_parent()._as_int(core.substr(modifier_index), 0)
	var next_modifier := current_modifier + bonus
	if next_modifier == 0:
		return "%s%s" % [base, suffix]
	var sign := "+" if next_modifier > 0 else ""
	return "%s%s%d%s" % [base, sign, next_modifier, suffix]


func _dash_for_empty_or_zero(value) -> String:
	if typeof(value) == TYPE_STRING:
		var text := String(value).strip_edges()
		if text.is_empty() or text == "0":
			return "-"
		if not text.is_valid_int() and not text.is_valid_float():
			return text
	if _get_parent()._as_int(value, 0) <= 0:
		return "-"
	return str(_get_parent()._as_int(value, 0))


func _dash_for_empty_or_hidden(value) -> String:
	if _get_parent()._as_int(value, -1000) <= -1000:
		return "-"
	return str(_get_parent()._as_int(value, 0))


func _format_rules_number(value: float) -> String:
	if is_equal_approx(value, float(int(value))):
		return str(int(value))
	return "%.2f" % value



func _normalize_equipment(character: Dictionary) -> void:
	var equipment: Dictionary = character.get("equipment", {})
	if not equipment.has("custom_items"):
		equipment["custom_items"] = []
	if not equipment.has("carried"):
		equipment["carried"] = []

	var custom_items := []
	for custom_item in equipment.get("custom_items", []):
		if typeof(custom_item) != TYPE_DICTIONARY:
			continue
		var normalized := _normalize_equipment_item(custom_item.duplicate(true), _next_custom_equipment_id_from_list(custom_items))
		custom_items.append(normalized)
	equipment["custom_items"] = custom_items
	equipment.erase("_custom_items_by_id")

	var carried := []
	for carried_item in equipment.get("carried", []):
		if typeof(carried_item) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = carried_item
		var item_id := String(row.get("item_id", ""))
		if item_id.is_empty():
			continue
		var normalized_row := {
			"line_id": String(row.get("line_id", _next_equipment_line_id_from_list(carried))),
			"item_id": item_id,
			"quantity": max(1, _get_parent()._as_int(row.get("quantity", 1))),
			"equipped": bool(row.get("equipped", false)),
			"slot": String(row.get("slot", "")),
			"notes": String(row.get("notes", "")),
		}
		carried.append(normalized_row)
	equipment["carried"] = carried
	character["equipment"] = equipment


func _normalize_equipment_item(item: Dictionary, fallback_id: String) -> Dictionary:
	var combat = item.get("combat", null)
	if typeof(combat) != TYPE_DICTIONARY:
		combat = null
	var normalized := {
		"id": String(item.get("id", fallback_id)),
		"kind": String(item.get("kind", "equipment")),
		"name": String(item.get("name", "Custom Item")),
		"source": String(item.get("source", "Custom")),
		"source_code": String(item.get("source_code", "custom")),
		"reference": String(item.get("reference", "Character custom equipment.")),
		"page": String(item.get("page", "")),
		"table": String(item.get("table", "")),
		"pl": clampi(_get_parent()._as_int(item.get("pl", 0)), 0, 9),
		"category": String(item.get("category", "Custom")),
		"class": String(item.get("class", "Custom")),
		"availability": String(item.get("availability", "Com")),
		"mass": max(0.0, _get_parent()._as_float(item.get("mass", 0.0))),
		"cost": max(0, _get_parent()._as_int(item.get("cost", 0))),
		"combat": combat,
	}
	return normalized


func _equipment_string_options(key: String) -> Array:
	var options := []
	var seen := {}
	for item in _get_parent().equipment_catalog:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var value := String(item.get(key, ""))
		if value.is_empty() or seen.has(value):
			continue
		seen[value] = true
		options.append(value)
	options.sort()
	return options


func _equipment_matches_search(item: Dictionary, search: String) -> bool:
	var haystack := "%s %s %s %s %s" % [
		String(item.get("name", "")),
		String(item.get("category", "")),
		String(item.get("class", "")),
		String(item.get("source", "")),
		String(item.get("availability", "")),
	]
	return haystack.to_lower().contains(search)


func _next_equipment_line_id(character: Dictionary) -> String:
	var equipment: Dictionary = character.get("equipment", {})
	return _next_equipment_line_id_from_list(equipment.get("carried", []))


func _next_equipment_line_id_from_list(carried: Array) -> String:
	var max_id := 0
	for row in carried:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var line_id := String(row.get("line_id", ""))
		if line_id.begins_with("line_"):
			max_id = maxi(max_id, _get_parent()._as_int(line_id.substr(5), 0))
	return "line_%04d" % (max_id + 1)


func _next_custom_equipment_id(character: Dictionary) -> String:
	var equipment: Dictionary = character.get("equipment", {})
	return _next_custom_equipment_id_from_list(equipment.get("custom_items", []))


func _next_custom_equipment_id_from_list(custom_items: Array) -> String:
	var max_id := 0
	for item in custom_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := String(item.get("id", ""))
		if item_id.begins_with("custom_"):
			max_id = maxi(max_id, _get_parent()._as_int(item_id.substr(7), 0))
	return "custom_%04d" % (max_id + 1)



func _remove_unused_custom_equipment(character: Dictionary, item_id: String) -> void:
	if item_id.is_empty() or not item_id.begins_with("custom_"):
		return
	var equipment: Dictionary = character.get("equipment", {})
	for row in equipment.get("carried", []):
		if typeof(row) == TYPE_DICTIONARY and String(row.get("item_id", "")) == item_id:
			return
	var custom_items := []
	for item in equipment.get("custom_items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if String(item.get("id", "")) == item_id:
			continue
		custom_items.append(item)
	equipment["custom_items"] = custom_items
	equipment.erase("_custom_items_by_id")
	character["equipment"] = equipment