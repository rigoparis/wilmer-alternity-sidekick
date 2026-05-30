extends RefCounted

var _parent_ref: WeakRef

func _init(parent) -> void:
	_parent_ref = weakref(parent)

func _get_parent():
	return _parent_ref.get_ref()

func achievement_points_for_level(level: int) -> int:
	var safe_level: int = max(1, level)
	return int(((safe_level * safe_level) + (9 * safe_level) - 10) / 2.0)


func achievement_level_for_points(points: int) -> int:
	var safe_points: int = max(0, points)
	var level := 1
	while safe_points >= achievement_points_for_level(level + 1):
		level += 1
	return level


func achievement_next_level_points(points: int) -> int:
	return achievement_points_for_level(achievement_level_for_points(points) + 1)


func set_achievement_points(character: Dictionary, points: int) -> void:
	character["achievement_points"] = max(0, points)
	character["achievement_level"] = achievement_level_for_points(_get_parent()._as_int(character["achievement_points"]))
	character["achievement_points_available"] = achievement_points_available(character)


func achievement_points_used(character: Dictionary) -> int:
	var skill_points_from_achievements: int = max(0, _get_parent().skill_points_used(character) - _get_parent().starting_skill_budget(character) - achievement_skill_bonus(character))
	var other_spending: int = max(0, _get_parent()._as_int(character.get("achievement_points_spent_other", 0)))
	return skill_points_from_achievements + other_spending


func achievement_points_available(character: Dictionary) -> int:
	return _get_parent()._as_int(character.get("achievement_points", 0)) - achievement_points_used(character)


func achievement_skill_bonus(character: Dictionary) -> int:
	var profession: Dictionary = _get_parent().get_profession_by_id(_get_parent()._as_int(character.get("profession_id", 0)))
	if String(profession.get("name", "")) != "Tech Op":
		return 0

	var bonus := 0
	var current_level := achievement_level_for_points(_get_parent()._as_int(character.get("achievement_points", 0)))
	for level in range(2, current_level + 1):
		if level <= 5:
			bonus += 1
		elif level <= 10:
			bonus += 2
		elif level <= 15:
			bonus += 3
		elif level <= 20:
			bonus += 4
		else:
			bonus += 5
	return bonus



func achievement_profile_key(character: Dictionary) -> String:
	var profession: Dictionary = _get_parent().get_profession_by_id(_get_parent()._as_int(character.get("profession_id", 0)))
	var profession_name := String(profession.get("name", ""))
	if profession_name.begins_with("Diplomat"):
		return "diplomat"
	if profession_name == "Combat Spec":
		return "combat_spec"
	if profession_name == "Free Agent":
		return "free_agent"
	if profession_name == "Tech Op":
		return "tech_op"
	if profession_name == "Mindwalker":
		return "mindwalker"
	return "combat_spec"


func achievement_profile_index(character: Dictionary) -> int:
	var key := achievement_profile_key(character)
	for index in range(_get_parent().achievement_profiles.size()):
		if String(_get_parent().achievement_profiles[index]) == key:
			return index
	return 0


func achievement_cost_entry(achievement: Dictionary, character: Dictionary) -> Dictionary:
	var costs: Array = achievement.get("costs", [])
	var index := achievement_profile_index(character)
	if index < 0 or index >= costs.size():
		return {"cost": 0, "min_level": 99}
	var row = costs[index]
	if typeof(row) != TYPE_ARRAY or row.size() < 2:
		return {"cost": 0, "min_level": 99}
	var cost: int = _get_parent()._as_int(row[0])
	var min_level: int = _get_parent()._as_int(row[1])
	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw":
		cost = 0
	return {
		"cost": cost,
		"min_level": min_level,
	}


func achievement_purchase_cost(character: Dictionary, achievement: Dictionary, target_value := 0) -> int:
	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw":
		return max(0, _get_parent()._as_int(target_value)) * max(1, _get_parent()._as_int(effect.get("cost_multiplier", 2)))
	return _get_parent()._as_int(achievement_cost_entry(achievement, character).get("cost", 0))



func selected_achievements(character: Dictionary) -> Array:
	var rows := []
	var selected: Array = character.get("selected_achievements", [])
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var achievement_id := String(entry.get("achievement_id", ""))
		var achievement: Dictionary = _get_parent().get_achievement_by_id(achievement_id)
		if achievement.is_empty():
			continue
		var row := entry.duplicate(true)
		row["achievement"] = achievement
		row["cost"] = _get_parent()._as_int(row.get("cost", achievement_purchase_cost(character, achievement, row.get("target_value", 0))))
		row["name"] = achievement_display_name(achievement, row)
		row["summary"] = achievement_effect_summary(achievement, row)
		rows.append(row)
	return rows


func achievement_purchase_count(character: Dictionary, achievement_id: String) -> int:
	var count := 0
	for entry in selected_achievements(character):
		if String(entry.get("achievement_id", "")) == achievement_id:
			count += 1
	return count


func achievement_effect_total(character: Dictionary, effect_type: String) -> int:
	var total := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == effect_type:
			total += _get_parent()._as_int(effect.get("amount", 1))
	return total


func achievement_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "durability" and String(effect.get("track", "")) == track:
			total += _get_parent()._as_int(effect.get("amount", 1))
	return total


func achievement_points_spent(character: Dictionary) -> int:
	var total := 0
	for entry in selected_achievements(character):
		total += _get_parent()._as_int(entry.get("cost", 0))
	return total


func achievement_granted_perk_ids(character: Dictionary) -> Array:
	var ids := []
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "new_perk":
			continue
		var perk_id := String(effect.get("perk_id", ""))
		if not perk_id.is_empty() and not ids.has(perk_id):
			ids.append(perk_id)
	return ids


func is_perk_granted_by_achievement(character: Dictionary, perk_id: String) -> bool:
	return achievement_granted_perk_ids(character).has(perk_id)


func achievement_granted_perks(character: Dictionary) -> Array:
	var rows := []
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "new_perk":
			continue
		var perk: Dictionary = _get_parent().get_perk_by_id(String(effect.get("perk_id", "")))
		if perk.is_empty():
			continue
		var row: Dictionary = perk.duplicate(true)
		row["cost"] = 0
		row["granted_by_achievement"] = true
		row["achievement_name"] = String(achievement.get("name", "Achievement"))
		row["perk_value"] = _get_parent()._as_int(effect.get("perk_value", 0))
		rows.append(row)
	return rows


func can_purchase_achievement(character: Dictionary, achievement: Dictionary, target_id := "", target_value := 0) -> Dictionary:
	var achievement_id := String(achievement.get("id", ""))
	var cost_info := achievement_cost_entry(achievement, character)
	var min_level: int = _get_parent()._as_int(cost_info.get("min_level", 99))
	var current_level := achievement_level_for_points(_get_parent()._as_int(character.get("achievement_points", 0)))
	if current_level < min_level:
		return {"allowed": false, "reason": "Requires hero level %d." % min_level}

	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	var max_purchases: int = _get_parent()._as_int(achievement.get("max", 1))
	if effect_type == "monetary":
		var eligible_levels: Array = effect.get("levels", [])
		var eligible_count := 0
		for level_value in eligible_levels:
			if current_level >= _get_parent()._as_int(level_value):
				eligible_count += 1
		max_purchases = eligible_count
	if effect_type != "remove_flaw" and max_purchases >= 0 and achievement_purchase_count(character, achievement_id) >= max_purchases:
		return {"allowed": false, "reason": "Maximum purchases reached."}

	if effect_type == "ability":
		var ability := String(effect.get("ability", ""))
		var tier: int = _get_parent()._as_int(effect.get("tier", 1))
		if tier > 1 and achievement_ability_purchase_count(character, ability) < tier - 1:
			return {"allowed": false, "reason": "%s Increase %d requires the previous increase first." % [ability, tier]}
		var abilities: Dictionary = _get_parent().achievement_adjusted_abilities(character)
		var limits: Array = _get_parent().ability_limits(character, ability)
		if _get_parent()._as_int(abilities.get(ability, 10)) >= _get_parent()._as_int(limits[1]):
			return {"allowed": false, "reason": "%s is already at the _get_parent().species maximum." % ability}
	if effect_type == "extra_action" and _get_parent().actions_per_round(character) >= 4:
		return {"allowed": false, "reason": "Actions per round are already at the maximum of 4."}
	if effect_type == "new_perk":
		var perk_id := String(effect.get("perk_id", ""))
		if _get_parent().is_perk_selected(character, perk_id):
			return {"allowed": false, "reason": "That perk is already selected."}
		if _get_parent().selected_perk_count(character) >= 3:
			return {"allowed": false, "reason": "The hero already has three perks."}
	if effect_type == "remove_flaw":
		if String(target_id).is_empty():
			return {"allowed": false, "reason": "Choose a flaw to remove."}
		if not _get_parent().is_flaw_selected(character, String(target_id)):
			return {"allowed": false, "reason": "That flaw is not currently selected."}
		for entry in selected_achievements(character):
			var prior_achievement: Dictionary = entry.get("achievement", {})
			var prior_effect: Dictionary = prior_achievement.get("effect", {})
			if String(prior_effect.get("type", "")) == "remove_flaw" and String(entry.get("target_id", "")) == String(target_id):
				return {"allowed": false, "reason": "That flaw has already been removed."}

	var cost := achievement_purchase_cost(character, achievement, target_value)
	var available_points: int = _get_parent().skill_budget(character) - _get_parent().skill_points_used(character)
	if effect_type == "remove_flaw":
		available_points -= max(0, _get_parent()._as_int(target_value))
	if available_points < cost:
		return {"allowed": false, "reason": "Requires %d available skill points." % cost}
	return {"allowed": true, "reason": "", "cost": cost, "min_level": min_level}


func achievement_ability_purchase_count(character: Dictionary, ability: String) -> int:
	var count := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "ability" and String(effect.get("ability", "")) == ability:
			count += 1
	return count


func add_achievement_purchase(character: Dictionary, achievement_id: String, target_id := "", target_value := 0, notes := "") -> Dictionary:
	var achievement: Dictionary = _get_parent().get_achievement_by_id(achievement_id)
	if achievement.is_empty():
		return {"ok": false, "reason": "Unknown achievement."}
	var cost := achievement_purchase_cost(character, achievement, target_value)
	var check := can_purchase_achievement(character, achievement, target_id, target_value)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}

	var selected: Array = character.get("selected_achievements", [])
	var line_id := _next_achievement_line_id_from_list(selected)
	var entry := {
		"line_id": line_id,
		"achievement_id": achievement_id,
		"cost": cost,
		"level": achievement_level_for_points(_get_parent()._as_int(character.get("achievement_points", 0))),
		"target_id": String(target_id),
		"target_value": _get_parent()._as_int(target_value),
		"notes": String(notes),
	}
	selected.append(entry)
	character["selected_achievements"] = selected

	var effect: Dictionary = achievement.get("effect", {})
	if String(effect.get("type", "")) == "remove_flaw" and not String(target_id).is_empty():
		var flaws: Dictionary = character.get("selected_flaws", {})
		flaws.erase(String(target_id))
		character["selected_flaws"] = flaws
	_get_parent().clamp_trackers(character)
	return {"ok": true, "line_id": line_id}


func remove_achievement_purchase(character: Dictionary, line_id: String) -> void:
	var selected: Array = character.get("selected_achievements", [])
	var next := []
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("line_id", "")) != line_id:
			next.append(entry)
			continue

		var achievement: Dictionary = _get_parent().get_achievement_by_id(String(entry.get("achievement_id", "")))
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) != "remove_flaw":
			continue

		var target_id := String(entry.get("target_id", ""))
		var target_value: int = _get_parent()._as_int(entry.get("target_value", 0))
		if target_id.is_empty() or target_value <= 0:
			continue

		var flaws: Dictionary = character.get("selected_flaws", {})
		flaws[target_id] = target_value
		character["selected_flaws"] = flaws

	character["selected_achievements"] = next
	_get_parent().clamp_trackers(character)


func achievement_display_name(achievement: Dictionary, entry: Dictionary = {}) -> String:
	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if effect_type == "remove_flaw":
		var flaw: Dictionary = _get_parent().get_flaw_by_id(String(entry.get("target_id", "")))
		if not flaw.is_empty():
			return "Remove Flaw: %s" % String(flaw.get("name", "Flaw"))
	if effect_type == "contact" and not String(entry.get("notes", "")).strip_edges().is_empty():
		return "%s: %s" % [String(achievement.get("name", "")), String(entry.get("notes", "")).strip_edges()]
	return String(achievement.get("name", "Achievement"))


func achievement_effect_summary(achievement: Dictionary, entry: Dictionary = {}) -> String:
	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	if effect_type == "new_perk":
		var perk: Dictionary = _get_parent().get_perk_by_id(String(effect.get("perk_id", "")))
		if not perk.is_empty():
			return "Grants %s as a %d-point perk without charging the normal perk cost." % [
				String(perk.get("name", "Perk")),
				_get_parent()._as_int(effect.get("perk_value", 0)),
			]
	if effect_type == "remove_flaw":
		var flaw: Dictionary = _get_parent().get_flaw_by_id(String(entry.get("target_id", "")))
		if not flaw.is_empty():
			return "Removes %s and its +%d skill point flaw bonus." % [
				String(flaw.get("name", "Flaw")),
				_get_parent()._as_int(entry.get("target_value", 0)),
			]
	if effect_type == "contact":
		return "Adds one campaign contact. Contacts provide information, resources, or expert help when the GM agrees."
	return String(achievement.get("summary", ""))



func _normalize_selected_achievements(character: Dictionary) -> void:
	var selected_value = character.get("selected_achievements", [])
	var selected: Array = selected_value if typeof(selected_value) == TYPE_ARRAY else []
	var normalized := []
	for entry_value in selected:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		var achievement_id := String(entry.get("achievement_id", ""))
		var achievement: Dictionary = _get_parent().get_achievement_by_id(achievement_id)
		if achievement.is_empty():
			continue
		normalized.append({
			"line_id": String(entry.get("line_id", _next_achievement_line_id_from_list(normalized))),
			"achievement_id": achievement_id,
			"cost": max(0, _get_parent()._as_int(entry.get("cost", achievement_purchase_cost(character, achievement, entry.get("target_value", 0))))),
			"level": max(1, _get_parent()._as_int(entry.get("level", achievement_level_for_points(_get_parent()._as_int(character.get("achievement_points", 0)))))),
			"target_id": String(entry.get("target_id", "")),
			"target_value": max(0, _get_parent()._as_int(entry.get("target_value", 0))),
			"notes": String(entry.get("notes", "")),
		})
	character["selected_achievements"] = normalized

func _next_achievement_line_id_from_list(selected: Array) -> String:
	var max_id := 0
	for item in selected:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var line_id := String(item.get("line_id", ""))
		if line_id.begins_with("ach_"):
			max_id = maxi(max_id, _get_parent()._as_int(line_id.substr(4), 0))
	return "ach_%04d" % (max_id + 1)
