class_name AlternityRulesFx
extends RefCounted

var _parent_ref: WeakRef

func _init(p_parent: RefCounted) -> void:
	_parent_ref = weakref(p_parent)

func _get_parent():
	return _parent_ref.get_ref()

func _normalize_fx(character: Dictionary) -> void:
	if not character.has("fx"):
		character["fx"] = {}
	var fx_data: Dictionary = character.get("fx", {})
	if not fx_data.has("is_fx_talent"):
		fx_data["is_fx_talent"] = false
	if not fx_data.has("energy_pool"):
		fx_data["energy_pool"] = 0
	if not fx_data.has("selected_skills"):
		fx_data["selected_skills"] = {}
	if not fx_data.has("permanent_skills"):
		fx_data["permanent_skills"] = {}
	character["fx"] = fx_data

func is_fx_talent(character: Dictionary) -> bool:
	return bool(character.get("fx", {}).get("is_fx_talent", false))

func set_fx_talent(character: Dictionary, enabled: bool) -> void:
	_normalize_fx(character)
	character["fx"]["is_fx_talent"] = enabled

func energy_pool(character: Dictionary) -> int:
	return AlternityNum.as_int(character.get("fx", {}).get("energy_pool", 0))

func set_energy_pool(character: Dictionary, amount: int) -> void:
	_normalize_fx(character)
	character["fx"]["energy_pool"] = max(0, amount)

func get_broad_skills() -> Array:
	return _get_parent().fx_broad_skills

func get_specialty_skills_for_broad(broad_name: String) -> Array:
	return _get_parent().fx_specialty_skills_by_broad.get(broad_name, [])

func get_broad_skill(skill_name: String) -> Dictionary:
	return _get_parent().fx_broad_skills_by_name.get(skill_name, {})

func get_specialty_skill(skill_name: String) -> Dictionary:
	return _get_parent().fx_specialty_skills_by_name.get(skill_name, {})

func fx_skill_rank(character: Dictionary, skill_name: String) -> int:
	var selected: Dictionary = character.get("fx", {}).get("selected_skills", {})
	return AlternityNum.as_int(selected.get(skill_name, 0))

func is_fx_skill_selected(character: Dictionary, skill_name: String) -> bool:
	return fx_skill_rank(character, skill_name) > 0

func can_fx_skill_be_permanent(skill_name: String) -> bool:
	var specialty = get_specialty_skill(skill_name)
	return specialty.has("permanent_cost")

func is_fx_skill_permanent(character: Dictionary, skill_name: String) -> bool:
	return bool(character.get("fx", {}).get("permanent_skills", {}).get(skill_name, false))

func set_fx_skill_permanent(character: Dictionary, skill_name: String, is_permanent: bool) -> void:
	_normalize_fx(character)
	if is_permanent:
		character["fx"]["permanent_skills"][skill_name] = true
	else:
		character["fx"]["permanent_skills"].erase(skill_name)

func permanent_fx_energy_drain(character: Dictionary) -> int:
	var total_drain := 0
	var perms: Dictionary = character.get("fx", {}).get("permanent_skills", {})
	for skill_name in perms.keys():
		if perms[skill_name] and is_fx_skill_selected(character, skill_name):
			var specialty = get_specialty_skill(skill_name)
			total_drain += AlternityNum.as_int(specialty.get("permanent_cost", 0))
	return total_drain

func permanent_fx_stat_bonus(character: Dictionary, ability: String) -> int:
	var map := {
		"STR": "Super Strength",
		"DEX": "Super Dexterity",
		"CON": "Super Constitution",
		"INT": "Super Intelligence",
		"WIL": "Super Will",
		"PER": "Super Personality"
	}
	var skill_name = map.get(ability.to_upper(), "")
	if skill_name.is_empty():
		return 0
	
	if not is_fx_skill_permanent(character, skill_name):
		return 0
	
	var rank = fx_skill_rank(character, skill_name)
	if rank <= 0:
		return 0
	
	var bonus = 1
	if rank >= 4:
		bonus += 1
	if rank >= 8:
		bonus += 1
	if rank >= 12:
		bonus += 1
		
	return bonus

func permanent_fx_effects_summary(character: Dictionary) -> Array:
	var effects := []
	var perms: Dictionary = character.get("fx", {}).get("permanent_skills", {})
	for skill_name in perms.keys():
		if perms[skill_name] and is_fx_skill_selected(character, skill_name):
			var specialty = get_specialty_skill(skill_name)
			if not specialty.is_empty():
				var desc = String(specialty.get("description", ""))
				effects.append({
					"name": skill_name,
					"description": desc
				})
	return effects

func add_fx_skill(character: Dictionary, skill_name: String) -> void:
	_normalize_fx(character)
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		character["fx"]["selected_skills"][skill_name] = 1
		return
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var current = fx_skill_rank(character, skill_name)
		character["fx"]["selected_skills"][skill_name] = current + 1

func remove_fx_skill(character: Dictionary, skill_name: String) -> void:
	_normalize_fx(character)
	var selected: Dictionary = character["fx"]["selected_skills"]
	if not selected.has(skill_name):
		return
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		selected.erase(skill_name)
		character["fx"].get("permanent_skills", {}).erase(skill_name)
		return
	var current = fx_skill_rank(character, skill_name)
	if current <= 1:
		selected.erase(skill_name)
		character["fx"].get("permanent_skills", {}).erase(skill_name)
	else:
		selected[skill_name] = current - 1
		
func selected_fx_skills(character: Dictionary) -> Array:
	var result := []
	var selected: Dictionary = character.get("fx", {}).get("selected_skills", {})
	for skill_name in selected.keys():
		var broad = get_broad_skill(skill_name)
		if not broad.is_empty():
			var entry = broad.duplicate(true)
			entry["rank"] = 1
			entry["type"] = "broad"
			result.append(entry)
		else:
			var specialty = get_specialty_skill(skill_name)
			if not specialty.is_empty():
				var entry = specialty.duplicate(true)
				entry["rank"] = AlternityNum.as_int(selected.get(skill_name, 0))
				entry["type"] = "specialty"
				result.append(entry)
	
	result.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	return result

func fx_skill_cost(character: Dictionary, skill_name: String) -> int:
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return AlternityNum.as_int(broad.get("cost", 0))
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var rank = fx_skill_rank(character, skill_name)
		return fx_skill_cost_for_rank(character, skill_name, rank + 1)
	return 0

func fx_skill_cost_for_rank(character: Dictionary, skill_name: String, rank: int) -> int:
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return AlternityNum.as_int(broad.get("cost", 0)) if rank == 1 else 0
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var base_cost = AlternityNum.as_int(specialty.get("cost", 0))
		var primary_group = String(character.get("fx", {}).get("primary_broad_group", ""))
		var skill_broad = String(specialty.get("broad_skill", ""))
		if not primary_group.is_empty() and skill_broad != primary_group:
			base_cost *= 2
		if rank <= 1 or _get_parent().optional_rule_enabled(character, "2c"):
			return base_cost
		return base_cost + (rank - 1)
	return 0

func fx_skill_total_cost(character: Dictionary, skill_name: String) -> int:
	var rank = fx_skill_rank(character, skill_name)
	if rank <= 0:
		return 0
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return AlternityNum.as_int(broad.get("cost", 0))
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var total := 0
		for r in range(1, rank + 1):
			total += fx_skill_cost_for_rank(character, skill_name, r)
		return total
	return 0

func fx_skill_purchase_points_used(character: Dictionary) -> int:
	var total := 0
	var selected: Dictionary = character.get("fx", {}).get("selected_skills", {})
	for skill_name in selected.keys():
		total += fx_skill_total_cost(character, skill_name)
	return total

func _extract_ranks_from_text(text: String) -> Array:
	var ranks := []
	var text_lower := text.to_lower()
	var start_pos := 0
	while true:
		var pos = text_lower.find("rank", start_pos)
		if pos == -1:
			break
		
		var search_start = pos + 4
		if text_lower.substr(search_start, 1) == "s":
			search_start += 1
			
		var words = text_lower.substr(search_start, 100).split(" ", false)
		for word in words:
			var digit_str = ""
			for char in word:
				if char in "0123456789":
					digit_str += char
			if not digit_str.is_empty():
				ranks.append(digit_str.to_int())
				break
			var has_letters = false
			for char in word:
				if char in "abcdefghijklmnopqrstuvwxyz":
					has_letters = true
					break
			if has_letters and not (word in ["and", "or", ",", ".", "&", "to"]):
				break
				
		start_pos = pos + 4
	
	if ranks.is_empty():
		ranks.append(99)
	return ranks

func clean_ocr(txt: String) -> String:
	txt = txt.replace("This'skill c\u00e9m't be used untrained.", "This skill cannot be used untrained.")
	txt = txt.replace("This skill c\u00e9m't be used untrained.", "This skill cannot be used untrained.")
	txt = txt.replace("This skill can't be used untrained.", "This skill cannot be used untrained.")
	while txt.contains("  "):
		txt = txt.replace("  ", " ")
	return txt.strip_edges()

func _save_parsed_skill(skill_name: String, desc_lines: Array, meta_str: String, benefits: Dictionary) -> void:
	if skill_name.is_empty():
		return
	var desc_str = clean_ocr(" ".join(desc_lines))
	if _get_parent().fx_broad_skills_by_name.has(skill_name):
		var broad = _get_parent().fx_broad_skills_by_name[skill_name]
		broad["description"] = desc_str
		broad["meta"] = meta_str
		broad["rank_benefits"] = benefits.duplicate()
	elif _get_parent().fx_specialty_skills_by_name.has(skill_name):
		var spec = _get_parent().fx_specialty_skills_by_name[skill_name]
		spec["description"] = desc_str
		spec["meta"] = meta_str
		spec["rank_benefits"] = benefits.duplicate()

func parse_descriptions(path := "res://manuals/alternity_beyond_science_fx_catalog.txt") -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Unable to open FX manual for parsing: %s" % path)
		return
	
	var text := file.get_as_text()
	var lines := text.split("\n")
	
	var skill_names_lower := {}
	for key in get_broad_skills():
		var n = String(key.get("name", ""))
		skill_names_lower[n.to_lower()] = n
	for key in _get_parent().fx_specialty_skills_by_name.keys():
		skill_names_lower[key.to_lower()] = key

	var current_skill := ""
	var current_desc := []
	var current_benefits := {}
	var current_meta := ""
	
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty():
			i += 1
			continue
			
		var line_lower := line.to_lower()
		if skill_names_lower.has(line_lower):
			_save_parsed_skill(current_skill, current_desc, current_meta, current_benefits)
			current_skill = skill_names_lower[line_lower]
			current_desc = []
			current_benefits = {}
			current_meta = ""
			
			var j := i + 1
			var meta_lines := []
			while j < lines.size() and j < i + 6:
				var next_line := lines[j].strip_edges()
				if skill_names_lower.has(next_line.to_lower()) or next_line.begins_with("==="):
					break
				if "spell" in next_line.to_lower() or "miracle" in next_line.to_lower() or "power" in next_line.to_lower() or "energy" in next_line.to_lower():
					meta_lines.append(next_line)
				j += 1
			current_meta = clean_ocr(" ".join(meta_lines))
			i = j - 1
		elif not current_skill.is_empty():
			if line.begins_with("@") or line.begins_with("\u00ae") or line.begins_with("\u00a9"):
				var benefit_text := line
				var j := i + 1
				while j < lines.size():
					var next_line := lines[j].strip_edges()
					if next_line.is_empty():
						j += 1
						continue
					if next_line.begins_with("@") or next_line.begins_with("\u00ae") or skill_names_lower.has(next_line.to_lower()) or next_line.begins_with("==="):
						break
					benefit_text += " " + next_line
					j += 1
				benefit_text = clean_ocr(benefit_text)
				
				var parsed_ranks = _extract_ranks_from_text(benefit_text)
				for r in parsed_ranks:
					current_benefits[str(r)] = benefit_text
				i = j - 1
			elif not line.begins_with("[Printed page"):
				current_desc.append(line)
		i += 1
		
	_save_parsed_skill(current_skill, current_desc, current_meta, current_benefits)

func fx_skill_score(character: Dictionary, skill_name: String) -> Dictionary:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var specialty = get_specialty_skill(skill_name)
	var ability = "WIL"
	if not specialty.is_empty():
		ability = String(specialty.get("ability", "WIL"))
	else:
		var broad = get_broad_skill(skill_name)
		if not broad.is_empty():
			ability = String(broad.get("ability", "WIL"))
			
	var ability_score = 10
	if ability.contains("/"):
		var parts = ability.split("/")
		var max_val = 0
		for part in parts:
			var val = AlternityNum.as_int(abilities.get(part.strip_edges(), 10))
			if val > max_val:
				max_val = val
		ability_score = max_val
	else:
		ability_score = AlternityNum.as_int(abilities.get(ability, 10))
	var rank = fx_skill_rank(character, skill_name)
	var base = ability_score + rank
	var ordinary = base
	var good = int(floor(ordinary / 2.0))
	var amazing = int(floor(good / 2.0))
	
	var is_broad := not get_broad_skill(skill_name).is_empty()
	if is_broad and rank > 0:
		base = int(floor(ability_score / 2.0))
		ordinary = base
		good = int(floor(ordinary / 2.0))
		amazing = int(floor(good / 2.0))
	var step := 1 if is_broad else 0
	step += _get_parent().dazed_penalty(character)

	return {
		"marginal": ordinary + 1,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"base": base,
		"step": step,
		"die": _get_parent().action_step_die(step)
	}
