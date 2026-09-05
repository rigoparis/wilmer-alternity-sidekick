class_name AlternityRulesAchievements
extends RefCounted

var _parent_ref: WeakRef

func _init(p_parent: RefCounted) -> void:
	_parent_ref = weakref(p_parent)

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


func achievement_points_for_current_level(points: int) -> int:
	return achievement_points_for_level(achievement_level_for_points(points))


func set_achievement_points(character: Dictionary, points: int) -> void:
	var previous_level := AlternityNum.as_int(character.get("achievement_level", 1), 1)
	character["achievement_points"] = max(0, points)
	character["achievement_level"] = achievement_level_for_points(AlternityNum.as_int(character["achievement_points"]))
	character["achievement_points_available"] = achievement_points_available(character)
	# Gaining a level starts a fresh one-rank allowance for every specialty.
	if AlternityNum.as_int(character["achievement_level"], 1) > previous_level:
		_get_parent().snapshot_skill_ranks(character)


func achievement_points_used(character: Dictionary) -> int:
	var total_ap := AlternityNum.as_int(character.get("achievement_points", 0))
	return achievement_points_for_current_level(total_ap)


func achievement_points_available(character: Dictionary) -> int:
	var total_ap := AlternityNum.as_int(character.get("achievement_points", 0))
	return max(0, total_ap - achievement_points_used(character))


func achievement_points_to_next_level(character: Dictionary) -> int:
	var total_ap := AlternityNum.as_int(character.get("achievement_points", 0))
	return max(0, achievement_next_level_points(total_ap) - total_ap)


func achievement_skill_bonus(character: Dictionary) -> int:
	var profession: Dictionary = _get_parent().get_profession_by_id(AlternityNum.as_int(character.get("profession_id", 0)))
	if String(profession.get("name", "")) != "Tech Op":
		return 0

	var bonus := 0
	var current_level := achievement_level_for_points(AlternityNum.as_int(character.get("achievement_points", 0)))
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
	var profession: Dictionary = _get_parent().get_profession_by_id(AlternityNum.as_int(character.get("profession_id", 0)))
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
	var cost: int = AlternityNum.as_int(row[0])
	var min_level: int = AlternityNum.as_int(row[1])
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
		return max(0, AlternityNum.as_int(target_value)) * max(1, AlternityNum.as_int(effect.get("cost_multiplier", 2)))
	return AlternityNum.as_int(achievement_cost_entry(achievement, character).get("cost", 0))



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
		row["cost"] = AlternityNum.as_int(row.get("cost", achievement_purchase_cost(character, achievement, row.get("target_value", 0))))
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
			total += AlternityNum.as_int(effect.get("amount", 1))
	return total


func achievement_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	for entry in selected_achievements(character):
		var achievement: Dictionary = entry.get("achievement", {})
		var effect: Dictionary = achievement.get("effect", {})
		if String(effect.get("type", "")) == "durability" and String(effect.get("track", "")) == track:
			total += AlternityNum.as_int(effect.get("amount", 1))
	return total


func achievement_points_spent(character: Dictionary) -> int:
	var total := 0
	for entry in selected_achievements(character):
		total += AlternityNum.as_int(entry.get("cost", 0))
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
		# Whether it was bought or handed over decides if it counts against the
		# three-perk career limit, so the award flag travels with the perk.
		row["gm_given"] = bool(entry.get("gm_given", false))
		row["achievement_name"] = String(achievement.get("name", "Achievement"))
		row["perk_value"] = AlternityNum.as_int(effect.get("perk_value", 0))
		rows.append(row)
	return rows


## What one extra point of FX energy pool costs in achievement points.
##
## Unlike every other benefit this is bought with achievement points rather than
## skill points, so buying one costs progress toward the next level. Alternity
## has no parallel "spendable AP" pool: the points come straight off the hero's
## unbanked track. Source: Beyond Science ch. 1 p. 8.
func fx_energy_pool_ap_cost(character: Dictionary) -> int:
	# Dark*Matter prices its own, and cheaper than the scale it belongs to: the
	# setting is a realistic campaign, which the generic rules would charge 15.
	if _get_parent().is_dark_matter(character):
		return AlternityRules.DARK_MATTER_FX_POOL_AP_COST
	var scale: Dictionary = _get_parent().fx_campaign_scale_entry(character)
	return AlternityNum.as_int(scale.get("ap_per_point", 10), 10)


## How many pool increases this hero has bought.
func fx_energy_pool_purchases(character: Dictionary) -> int:
	return achievement_purchase_count(character, "fx_energy_pool_increase")


## The pool may never be enlarged past twice its starting value, so the number
## of increases can never exceed the base the hero began with.
func fx_energy_pool_increase_limit(character: Dictionary) -> int:
	return max(0, _get_parent().fx.energy_pool(character))


## Whether the hero may take this benefit, and why not when they may not.
##
## `gm_given` is the Gamemaster awarding a benefit narratively rather than the
## player buying one in downtime. The Gamemaster Guide lets the GM hand out a
## perk, remove a flaw or grant a windfall as a story reward, so such an award
## skips both the skill-point cost and the achievement-level prerequisite --
## Table P29 prices purchases, not gifts.
##
## What it does not skip are the hard ceilings: a species ability maximum and
## the four-actions-per-round limit are physiology, not economics, and still
## apply however the benefit arrived.
func can_purchase_achievement(
	character: Dictionary,
	achievement: Dictionary,
	target_id := "",
	target_value := 0,
	gm_given := false
) -> Dictionary:
	var achievement_id := String(achievement.get("id", ""))
	var cost_info := achievement_cost_entry(achievement, character)
	var min_level: int = AlternityNum.as_int(cost_info.get("min_level", 99))
	var current_level := achievement_level_for_points(AlternityNum.as_int(character.get("achievement_points", 0)))
	if not gm_given and current_level < min_level:
		return {"allowed": false, "reason": "Requires hero level %d." % min_level}

	var effect: Dictionary = achievement.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	var max_purchases: int = AlternityNum.as_int(achievement.get("max", 1))
	if effect_type == "monetary":
		var eligible_levels: Array = effect.get("levels", [])
		var eligible_count := 0
		for level_value in eligible_levels:
			if current_level >= AlternityNum.as_int(level_value):
				eligible_count += 1
		# The printed list stops at 24th and, unlike the achievement track,
		# carries no "etc." -- so eight is the maximum by the text. The pattern
		# underneath is simply every third level, which an epic campaign can
		# keep going with the optional rule.
		if _get_parent().optional_rule_enabled(character, "monetary_awards_uncapped"):
			eligible_count = int(current_level / 3.0)
		max_purchases = eligible_count
	if effect_type != "remove_flaw" and max_purchases >= 0 and achievement_purchase_count(character, achievement_id) >= max_purchases:
		return {"allowed": false, "reason": "Maximum purchases reached."}

	if effect_type == "ability":
		var ability := String(effect.get("ability", ""))
		var tier: int = AlternityNum.as_int(effect.get("tier", 1))
		if tier > 1 and achievement_ability_purchase_count(character, ability) < tier - 1:
			return {"allowed": false, "reason": "%s Increase %d requires the previous increase first." % [ability, tier]}
		var abilities: Dictionary = _get_parent().achievement_adjusted_abilities(character)
		var limits: Array = _get_parent().ability_limits(character, ability)
		if AlternityNum.as_int(abilities.get(ability, 10)) >= AlternityNum.as_int(limits[1]):
			return {"allowed": false, "reason": "%s is already at the species maximum." % ability}
	if effect_type == "extra_action" and _get_parent().actions_per_round(character) >= 4:
		return {"allowed": false, "reason": "Actions per round are already at the maximum of 4."}
	if effect_type == "fx_energy_pool":
		if not _get_parent().fx.is_fx_talent(character):
			return {"allowed": false, "reason": "This hero does not use FX."}
		var base_pool: int = fx_energy_pool_increase_limit(character)
		if base_pool <= 0:
			return {"allowed": false, "reason": "Set a starting FX energy pool first."}
		if fx_energy_pool_purchases(character) >= base_pool:
			return {"allowed": false, "reason": "The pool is already twice its starting value."}
		# Paid in achievement points off the unbanked track, not in skill
		# points, so it is checked here and skips the skill-point test below.
		var ap_cost := 0 if gm_given else fx_energy_pool_ap_cost(character)
		var ap_available := achievement_points_available(character)
		if not gm_given and ap_available < ap_cost:
			return {
				"allowed": false,
				"reason": "Requires %d achievement points; %d banked toward the next level." % [
					ap_cost, ap_available,
				],
			}
		return {"allowed": true, "reason": "", "cost": 0, "ap_cost": ap_cost, "min_level": min_level}
	if effect_type == "new_perk":
		var perk_id := String(effect.get("perk_id", ""))
		if _get_parent().is_perk_selected(character, perk_id):
			return {"allowed": false, "reason": "That perk is already selected."}
		# The three-perk career limit counts perks the player bought. A perk the
		# Gamemaster hands over is a story reward and does not spend that budget.
		if not gm_given and _get_parent().non_gm_perk_count(character) >= 3:
			return {"allowed": false, "reason": "The hero already has three standard perks."}
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

	var cost := 0 if gm_given else achievement_purchase_cost(character, achievement, target_value)
	if not gm_given:
		var available_points: int = _get_parent().skill_budget(character) - _get_parent().skill_points_used(character)
		if effect_type == "remove_flaw":
			available_points -= max(0, AlternityNum.as_int(target_value))
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


func add_achievement_purchase(
	character: Dictionary,
	achievement_id: String,
	target_id := "",
	target_value := 0,
	notes := "",
	gm_given := false
) -> Dictionary:
	var achievement: Dictionary = _get_parent().get_achievement_by_id(achievement_id)
	if achievement.is_empty():
		return {"ok": false, "reason": "Unknown achievement."}
	var cost := 0 if gm_given else achievement_purchase_cost(character, achievement, target_value)
	var check := can_purchase_achievement(character, achievement, target_id, target_value, gm_given)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}

	var selected: Array = character.get("selected_achievements", [])
	var line_id := _next_achievement_line_id_from_list(selected)
	# An AP-priced benefit records what it cost in achievement points and zero
	# skill points, so achievement_points_spent -- which feeds skill_points_used
	# -- never counts it against the skill budget.
	var effect_for_cost: Dictionary = achievement.get("effect", {})
	var ap_cost := 0
	if not gm_given and String(effect_for_cost.get("type", "")) == "fx_energy_pool":
		ap_cost = AlternityNum.as_int(check.get("ap_cost", fx_energy_pool_ap_cost(character)))
		cost = 0
		character["achievement_points"] = max(
			0, AlternityNum.as_int(character.get("achievement_points", 0)) - ap_cost
		)

	var entry := {
		"line_id": line_id,
		"achievement_id": achievement_id,
		"cost": cost,
		"ap_cost": ap_cost,
		"level": achievement_level_for_points(AlternityNum.as_int(character.get("achievement_points", 0))),
		"target_id": String(target_id),
		"target_value": AlternityNum.as_int(target_value),
		"notes": String(notes),
		"gm_given": gm_given,
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

		# Giving up an AP-priced benefit puts the points back on the track.
		var refund: int = AlternityNum.as_int(entry.get("ap_cost", 0))
		if refund > 0:
			character["achievement_points"] = AlternityNum.as_int(
				character.get("achievement_points", 0)
			) + refund

		if String(effect.get("type", "")) != "remove_flaw":
			continue

		var target_id := String(entry.get("target_id", ""))
		var target_value: int = AlternityNum.as_int(entry.get("target_value", 0))
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
				AlternityNum.as_int(effect.get("perk_value", 0)),
			]
	if effect_type == "remove_flaw":
		var flaw: Dictionary = _get_parent().get_flaw_by_id(String(entry.get("target_id", "")))
		if not flaw.is_empty():
			return "Removes %s and its +%d skill point flaw bonus." % [
				String(flaw.get("name", "Flaw")),
				AlternityNum.as_int(entry.get("target_value", 0)),
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
			"cost": max(0, AlternityNum.as_int(entry.get("cost", achievement_purchase_cost(character, achievement, entry.get("target_value", 0))))),
			"level": max(1, AlternityNum.as_int(entry.get("level", achievement_level_for_points(AlternityNum.as_int(character.get("achievement_points", 0)))))),
			"target_id": String(entry.get("target_id", "")),
			"target_value": max(0, AlternityNum.as_int(entry.get("target_value", 0))),
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
			max_id = maxi(max_id, AlternityNum.as_int(line_id.substr(4), 0))
	return "ach_%04d" % (max_id + 1)
