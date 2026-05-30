extends RefCounted

var _parent_ref: WeakRef

func _init(parent) -> void:
	_parent_ref = weakref(parent)

func _get_parent():
	return _parent_ref.get_ref()

func get_mutation_advantage_by_id(mutation_id: String) -> Dictionary:
	return _get_parent().mutation_advantages_by_id.get(mutation_id, {})


func get_mutation_drawback_by_id(drawback_id: String) -> Dictionary:
	return _get_parent().mutation_drawbacks_by_id.get(drawback_id, {})


func mutant_species_id() -> int:
	for item in _get_parent().species:
		if String(item.get("name", "")) == "Mutant":
			return _get_parent()._as_int(item.get("id", -1))
	return 6


func mutations_enabled(character: Dictionary) -> bool:
	return _get_parent()._as_int(character.get("species_id", -1)) == mutant_species_id()


func mutation_origin_options() -> Array:
	return _get_parent().mutation_origins


func mutation_uniqueness_options(origin_id: String) -> Array:
	var origin := get_mutation_origin_by_id(origin_id)
	if origin.is_empty():
		return []
	var rows: Array = origin.get("uniqueness", [])
	return rows


func get_mutation_origin_by_id(origin_id: String) -> Dictionary:
	return _get_parent().mutation_origins_by_id.get(origin_id, {})


func get_mutation_uniqueness_by_id(origin_id: String, uniqueness_id: String) -> Dictionary:
	var origin_uniqueness: Dictionary = _get_parent().mutation_uniqueness_by_id.get(origin_id, {})
	return origin_uniqueness.get(uniqueness_id, {})


func set_mutation_generation_mode(character: Dictionary, mode: String) -> void:
	var mutations := _mutation_data(character)
	mutations["generation_mode"] = "player" if mode == "player" else "random"
	character["mutations"] = mutations


func set_mutation_origin(character: Dictionary, origin_id: String) -> void:
	var mutations := _mutation_data(character)
	var origin := get_mutation_origin_by_id(origin_id)
	if origin.is_empty():
		return
	mutations["origin"] = origin_id
	if get_mutation_uniqueness_by_id(origin_id, String(mutations.get("uniqueness", ""))).is_empty():
		var uniqueness_rows: Array = origin.get("uniqueness", [])
		if not uniqueness_rows.is_empty() and typeof(uniqueness_rows[0]) == TYPE_DICTIONARY:
			mutations["uniqueness"] = String(uniqueness_rows[0].get("id", ""))
	character["mutations"] = mutations


func set_mutation_uniqueness(character: Dictionary, uniqueness_id: String) -> void:
	var mutations := _mutation_data(character)
	var origin_id := String(mutations.get("origin", "engineered"))
	if get_mutation_uniqueness_by_id(origin_id, uniqueness_id).is_empty():
		return
	mutations["uniqueness"] = uniqueness_id
	character["mutations"] = mutations


func set_mutation_points(character: Dictionary, advantage_points: int, drawback_points: int) -> void:
	var mutations := _mutation_data(character)
	mutations["advantage_points"] = max(0, advantage_points)
	mutations["drawback_points"] = max(0, drawback_points)
	character["mutations"] = mutations
	_ensure_mutation_distributions(character)


func set_mutation_point_total(character: Dictionary, kind: String, points: int) -> void:
	var mutations := _mutation_data(character)
	if kind == "drawback":
		mutations["drawback_points"] = max(0, points)
	else:
		mutations["advantage_points"] = max(0, points)
	character["mutations"] = mutations
	_ensure_mutation_distribution(character, kind)


func roll_mutation_origin(character: Dictionary) -> Dictionary:
	var origin_roll := randi_range(1, 8)
	var origin_id := "engineered" if origin_roll <= 5 else "natural"
	var uniqueness_roll := randi_range(1, 8)
	var uniqueness_id := ""
	if origin_id == "engineered":
		uniqueness_id = "engineered_community" if uniqueness_roll <= 5 else "engineered_unique"
	else:
		uniqueness_id = "natural_community" if uniqueness_roll <= 3 else "natural_unique"

	var mutations := _mutation_data(character)
	mutations["origin"] = origin_id
	mutations["uniqueness"] = uniqueness_id
	character["mutations"] = mutations
	return {
		"origin_roll": origin_roll,
		"uniqueness_roll": uniqueness_roll,
		"origin": get_mutation_origin_by_id(origin_id),
		"uniqueness": get_mutation_uniqueness_by_id(origin_id, uniqueness_id),
	}


func roll_mutation_origin_and_points(character: Dictionary) -> Dictionary:
	var origin_result := roll_mutation_origin(character)
	var points_result := roll_mutation_points(character)
	origin_result["points"] = points_result
	return origin_result


func roll_mutation_points(character: Dictionary) -> Dictionary:
	var mutations := _mutation_data(character)
	var uniqueness := get_mutation_uniqueness_by_id(String(mutations.get("origin", "engineered")), String(mutations.get("uniqueness", "engineered_community")))
	if uniqueness.is_empty():
		return {}
	var advantage_points := _roll_mutation_formula(String(uniqueness.get("advantage_points", "0")))
	var drawback_points := _roll_mutation_formula(String(uniqueness.get("drawback_points", "0")))
	mutations["advantage_points"] = advantage_points
	mutations["drawback_points"] = drawback_points
	character["mutations"] = mutations
	_ensure_mutation_distributions(character)
	return {
		"advantage_points": advantage_points,
		"drawback_points": drawback_points,
		"uniqueness": uniqueness,
	}


func roll_mutation_point_total(character: Dictionary, kind: String) -> int:
	var mutations := _mutation_data(character)
	var uniqueness := get_mutation_uniqueness_by_id(String(mutations.get("origin", "engineered")), String(mutations.get("uniqueness", "engineered_community")))
	if uniqueness.is_empty():
		return 0
	var formula_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var points := _roll_mutation_formula(String(uniqueness.get(formula_key, "0")))
	set_mutation_point_total(character, kind, points)
	return points


func mutation_distribution_options(kind: String, points: int) -> Array:
	var safe_points: int = max(0, points)
	if kind == "drawback":
		return _mutation_drawback_distribution_options(safe_points)
	return _mutation_advantage_distribution_options(safe_points)


func mutation_distribution(character: Dictionary, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	_ensure_mutation_distribution(character, kind)
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	var value = mutations.get(distribution_key, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func set_mutation_distribution(character: Dictionary, kind: String, distribution_id: String) -> void:
	var mutations := _mutation_data(character)
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	var options := mutation_distribution_options(kind, _get_parent()._as_int(mutations.get(points_key, 0)))
	for option_value in options:
		if typeof(option_value) != TYPE_DICTIONARY:
			continue
		var option: Dictionary = option_value
		if String(option.get("id", "")) == distribution_id:
			mutations[distribution_key] = option.get("counts", {}).duplicate(true)
			character["mutations"] = mutations
			return


func roll_mutation_distribution(character: Dictionary, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var options := mutation_distribution_options(kind, _get_parent()._as_int(mutations.get(points_key, 0)))
	if options.is_empty():
		return {}
	var option: Dictionary = options[randi_range(0, options.size() - 1)]
	set_mutation_distribution(character, kind, String(option.get("id", "")))
	return option


func mutation_distribution_id(character: Dictionary, kind: String) -> String:
	var distribution := mutation_distribution(character, kind)
	var order: Array = _get_parent().MUTATION_DRAWBACK_TIERS if kind == "drawback" else _get_parent().MUTATION_ADVANTAGE_TIERS
	return _mutation_distribution_id(distribution, order)


func mutation_distribution_label(character: Dictionary, kind: String) -> String:
	var distribution := mutation_distribution(character, kind)
	var order: Array = _get_parent().MUTATION_DRAWBACK_LABEL_ORDER if kind == "drawback" else _get_parent().MUTATION_ADVANTAGE_LABEL_ORDER
	return _mutation_distribution_label(distribution, order)


func selected_mutation_advantages(character: Dictionary) -> Array:
	var rows := []
	var mutations := _mutation_data(character)
	for mutation_id_value in mutations.get("advantages", []):
		var mutation_id := String(mutation_id_value)
		var mutation := get_mutation_advantage_by_id(mutation_id)
		if mutation.is_empty():
			continue
		rows.append(mutation.duplicate(true))
	return rows


func selected_mutation_drawbacks(character: Dictionary) -> Array:
	var rows := []
	var mutations := _mutation_data(character)
	for drawback_id_value in mutations.get("drawbacks", []):
		var drawback_id := String(drawback_id_value)
		var drawback := get_mutation_drawback_by_id(drawback_id)
		if drawback.is_empty():
			continue
		rows.append(drawback.duplicate(true))
	return rows


func mutation_advantage_points_used(character: Dictionary) -> int:
	var total := 0
	for mutation in selected_mutation_advantages(character):
		total += _get_parent()._as_int(mutation.get("points", 0))
	return total


func mutation_drawback_points_used(character: Dictionary) -> int:
	var total := 0
	for drawback in selected_mutation_drawbacks(character):
		total += _get_parent()._as_int(drawback.get("points", 0))
	return total


func mutation_advantage_points_remaining(character: Dictionary) -> int:
	var mutations := _mutation_data(character)
	return _get_parent()._as_int(mutations.get("advantage_points", 0)) - mutation_advantage_points_used(character)


func mutation_drawback_points_remaining(character: Dictionary) -> int:
	var mutations := _mutation_data(character)
	return _get_parent()._as_int(mutations.get("drawback_points", 0)) - mutation_drawback_points_used(character)


func can_add_mutation_advantage(character: Dictionary, mutation: Dictionary) -> Dictionary:
	if not mutations_enabled(character):
		return {"allowed": false, "reason": "Only Mutant heroes use mutation rules."}
	var mutation_id := String(mutation.get("id", ""))
	if mutation_id.is_empty() or get_mutation_advantage_by_id(mutation_id).is_empty():
		return {"allowed": false, "reason": "Unknown mutation."}
	if _mutation_selected(character, "advantages", mutation_id):
		return {"allowed": false, "reason": "Already selected."}
	var remaining := mutation_advantage_points_remaining(character)
	var points: int = _get_parent()._as_int(mutation.get("points", 0))
	if remaining < points:
		return {"allowed": false, "reason": "Requires %d available advantageous mutation points." % points}
	var tier := String(mutation.get("tier", "Ordinary"))
	var distribution := mutation_distribution(character, "advantage")
	var allowed_count: int = _get_parent()._as_int(distribution.get(tier, 0))
	if allowed_count <= 0:
		return {"allowed": false, "reason": "The point distribution has no %s mutation slot." % tier}
	if _mutation_tier_count(selected_mutation_advantages(character), tier) >= allowed_count:
		return {"allowed": false, "reason": "The selected point distribution has no remaining %s mutation slot." % tier}
	var cap := _mutation_advantage_tier_cap(tier)
	if cap > 0 and _mutation_tier_count(selected_mutation_advantages(character), tier) >= cap:
		return {"allowed": false, "reason": "A mutant can have no more than %d %s advantageous mutation%s." % [cap, tier, "" if cap == 1 else "s"]}
	return {"allowed": true, "reason": ""}


func can_add_mutation_drawback(character: Dictionary, drawback: Dictionary) -> Dictionary:
	if not mutations_enabled(character):
		return {"allowed": false, "reason": "Only Mutant heroes use mutation rules."}
	var drawback_id := String(drawback.get("id", ""))
	if drawback_id.is_empty() or get_mutation_drawback_by_id(drawback_id).is_empty():
		return {"allowed": false, "reason": "Unknown drawback."}
	if _mutation_selected(character, "drawbacks", drawback_id):
		return {"allowed": false, "reason": "Already selected."}
	var remaining := mutation_drawback_points_remaining(character)
	var points: int = _get_parent()._as_int(drawback.get("points", 0))
	if remaining < points:
		return {"allowed": false, "reason": "Requires %d available drawback mutation points." % points}
	var tier := String(drawback.get("tier", "Slight"))
	var distribution := mutation_distribution(character, "drawback")
	var allowed_count: int = _get_parent()._as_int(distribution.get(tier, 0))
	if allowed_count <= 0:
		return {"allowed": false, "reason": "The point distribution has no %s drawback slot." % tier}
	if _mutation_tier_count(selected_mutation_drawbacks(character), tier) >= allowed_count:
		return {"allowed": false, "reason": "The selected point distribution has no remaining %s drawback slot." % tier}
	return {"allowed": true, "reason": ""}


func add_mutation_advantage(character: Dictionary, mutation_id: String) -> Dictionary:
	var mutation := get_mutation_advantage_by_id(mutation_id)
	var check := can_add_mutation_advantage(character, mutation)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}
	var mutations := _mutation_data(character)
	var selected: Array = mutations.get("advantages", [])
	selected.append(mutation_id)
	mutations["advantages"] = selected
	character["mutations"] = mutations
	_get_parent().clamp_trackers(character)
	return {"ok": true}


func add_mutation_drawback(character: Dictionary, drawback_id: String) -> Dictionary:
	var drawback := get_mutation_drawback_by_id(drawback_id)
	var check := can_add_mutation_drawback(character, drawback)
	if not bool(check.get("allowed", false)):
		return {"ok": false, "reason": String(check.get("reason", ""))}
	var mutations := _mutation_data(character)
	var selected: Array = mutations.get("drawbacks", [])
	selected.append(drawback_id)
	mutations["drawbacks"] = selected
	character["mutations"] = mutations
	_get_parent().clamp_trackers(character)
	return {"ok": true}


func remove_mutation_advantage(character: Dictionary, mutation_id: String) -> void:
	_remove_mutation_selection(character, "advantages", mutation_id)
	_get_parent().clamp_trackers(character)


func remove_mutation_drawback(character: Dictionary, drawback_id: String) -> void:
	_remove_mutation_selection(character, "drawbacks", drawback_id)
	_get_parent().clamp_trackers(character)


func roll_mutations_for_distribution(character: Dictionary, kind: String) -> Dictionary:
	if kind == "drawback":
		return _roll_mutation_selection(character, "drawbacks", _get_parent().mutation_drawbacks, "drawback")
	return _roll_mutation_selection(character, "advantages", _get_parent().mutation_advantages, "advantage")


func mutation_summary(character: Dictionary) -> Dictionary:
	var mutations := _mutation_data(character)
	var origin_id := String(mutations.get("origin", "engineered"))
	var uniqueness_id := String(mutations.get("uniqueness", "engineered_community"))
	return {
		"enabled": mutations_enabled(character),
		"rules": _get_parent().mutation_rules,
		"generation_mode": String(mutations.get("generation_mode", "random")),
		"origin": get_mutation_origin_by_id(origin_id),
		"uniqueness": get_mutation_uniqueness_by_id(origin_id, uniqueness_id),
		"advantage_points": _get_parent()._as_int(mutations.get("advantage_points", 0)),
		"drawback_points": _get_parent()._as_int(mutations.get("drawback_points", 0)),
		"advantage_points_used": mutation_advantage_points_used(character),
		"drawback_points_used": mutation_drawback_points_used(character),
		"advantage_points_remaining": mutation_advantage_points_remaining(character),
		"drawback_points_remaining": mutation_drawback_points_remaining(character),
		"advantage_distribution": mutation_distribution(character, "advantage"),
		"drawback_distribution": mutation_distribution(character, "drawback"),
		"advantage_distribution_label": mutation_distribution_label(character, "advantage"),
		"drawback_distribution_label": mutation_distribution_label(character, "drawback"),
		"advantages": selected_mutation_advantages(character),
		"drawbacks": selected_mutation_drawbacks(character),
	}


func mutation_ability_bonus(character: Dictionary, ability: String) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "ability"):
			if String(effect.get("ability", "")) == ability:
				total += _get_parent()._as_int(effect.get("amount", 0))
	return total


func mutation_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "durability"):
			if String(effect.get("track", "")) == track:
				total += _get_parent()._as_int(effect.get("amount", 0))
	return total


func mutation_action_check_step(character: Dictionary) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "action_check_step"):
			total += _get_parent()._as_int(effect.get("amount", 0))
	return total


func mutation_skill_step_bonus(character: Dictionary, skill_id: int) -> int:
	var total := 0
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "skill_step"):
			var skill_ids: Array = effect.get("skill_ids", [])
			for effect_skill_id in skill_ids:
				if _get_parent()._as_int(effect_skill_id) == skill_id:
					total += _get_parent()._as_int(effect.get("step", 0))
	return total


func mutation_movement_modes(character: Dictionary) -> Dictionary:
	var result := {}
	for mutation in _selected_mutation_effect_sources(character):
		for effect in _mutation_effects(mutation, "movement"):
			var modes: Array = effect.get("modes", [])
			for mode in modes:
				result[String(mode)] = true
			if bool(effect.get("glide", false)):
				result["glide"] = true
			if bool(effect.get("fly", false)):
				result["fly"] = true
	return result


func mutation_roll_notes_for_character(character: Dictionary) -> Array:
	var notes := []
	if not mutations_enabled(character):
		return notes
	for mutation in _selected_mutation_effect_sources(character):
		_append_mutation_notes(mutation, "roll_note", notes)
		_append_mutation_notes(mutation, "damage_note", notes)
	return _get_parent()._unique_strings(notes)


func _append_mutation_notes(mutation: Dictionary, effect_type: String, notes: Array) -> void:
	for effect in _mutation_effects(mutation, effect_type):
		var text := String(effect.get("text", "")).strip_edges()
		if not text.is_empty():
			notes.append("%s: %s Source: %s" % [
				String(mutation.get("name", "Mutation")),
				text,
				String(mutation.get("reference", "")),
			])


func mutation_armor_rows(character: Dictionary) -> Array:
	var rows := []
	if not mutations_enabled(character):
		return rows
	for mutation in selected_mutation_advantages(character):
		for effect in _mutation_effects(mutation, "armor"):
			var item := {
				"id": "mutation_%s" % String(mutation.get("id", "")),
				"kind": "armor",
				"name": String(mutation.get("name", "Mutation Armor")),
				"source": "Mutation",
				"source_code": "mutation",
				"reference": String(mutation.get("reference", "")),
				"category": "Mutation",
				"class": "Natural Armor",
				"availability": "-",
				"mass": 0,
				"cost": 0,
				"combat": {
					"role": "armor",
					"action_penalty": _get_parent()._as_int(effect.get("ap", 0)),
					"toughness": String(effect.get("toughness", "O")),
					"li": String(effect.get("li", "")),
					"hi": String(effect.get("hi", "")),
					"en": String(effect.get("en", "")),
				},
			}
			rows.append({
				"line_id": "mutation_%s" % String(mutation.get("id", "")),
				"item_id": String(item.get("id", "")),
				"quantity": 1,
				"equipped": true,
				"slot": "Mutation",
				"notes": String(mutation.get("summary", "")),
				"item": item,
				"total_mass": 0,
				"total_cost": 0,
			})
	return rows


func mutation_attack_forms(character: Dictionary) -> Array:
	var forms := []
	if not mutations_enabled(character):
		return forms
	for mutation in selected_mutation_advantages(character):
		for effect in _mutation_effects(mutation, "attack"):
			var skill_id: int = _get_parent()._as_int(effect.get("skill_id", 16))
			var score: Dictionary = _get_parent().equipment._combat_skill_score(character, skill_id)
			score["step"] = _get_parent()._as_int(score.get("step", 0)) + _get_parent()._as_int(effect.get("step", 0))
			var damage := String(effect.get("damage", ""))
			if bool(effect.get("strength_bonus", false)):
				var abilities: Dictionary = _get_parent().effective_abilities(character)
				damage = _get_parent().equipment._damage_with_bonus(damage, _get_parent().equipment.strength_damage_bonus(_get_parent()._as_int(abilities.get("STR", 10))))
			var form := {
				"name": String(effect.get("name", mutation.get("name", "Mutation Attack"))),
				"score": _get_parent().equipment._score_text(score),
				"base_die": _get_parent().action_step_die(_get_parent()._as_int(score.get("step", 0))),
				"type": String(effect.get("damage_type", "")),
				"range": String(effect.get("range", "Personal")),
				"damage": damage,
				"hide": String(effect.get("hide", "-")),
				"clip_size": String(effect.get("clip_size", "-")),
				"mass": "",
				"mutation": String(mutation.get("name", "")),
				"note": String(effect.get("note", "")),
			}
			forms.append(form)
	return forms


func _normalize_mutations(character: Dictionary) -> void:
	var mutation_value = character.get("mutations", {})
	var mutations: Dictionary = mutation_value if typeof(mutation_value) == TYPE_DICTIONARY else {}
	var origin_id := String(mutations.get("origin", "engineered"))
	if get_mutation_origin_by_id(origin_id).is_empty():
		origin_id = "engineered"
	var uniqueness_id := String(mutations.get("uniqueness", ""))
	if get_mutation_uniqueness_by_id(origin_id, uniqueness_id).is_empty():
		var uniqueness_rows := mutation_uniqueness_options(origin_id)
		if not uniqueness_rows.is_empty() and typeof(uniqueness_rows[0]) == TYPE_DICTIONARY:
			var first_uniqueness: Dictionary = uniqueness_rows[0]
			uniqueness_id = String(first_uniqueness.get("id", "engineered_community"))
		else:
			uniqueness_id = "engineered_community"

	character["mutations"] = {
		"generation_mode": "player" if String(mutations.get("generation_mode", "random")) == "player" else "random",
		"origin": origin_id,
		"uniqueness": uniqueness_id,
		"advantage_points": max(0, _get_parent()._as_int(mutations.get("advantage_points", 0))),
		"drawback_points": max(0, _get_parent()._as_int(mutations.get("drawback_points", 0))),
		"advantage_distribution": _normalized_mutation_distribution(mutations.get("advantage_distribution", {}), "advantage", max(0, _get_parent()._as_int(mutations.get("advantage_points", 0)))),
		"drawback_distribution": _normalized_mutation_distribution(mutations.get("drawback_distribution", {}), "drawback", max(0, _get_parent()._as_int(mutations.get("drawback_points", 0)))),
		"advantages": _normalized_mutation_id_list(mutations.get("advantages", []), _get_parent().mutation_advantages_by_id),
		"drawbacks": _normalized_mutation_id_list(mutations.get("drawbacks", []), _get_parent().mutation_drawbacks_by_id),
	}
	_ensure_mutation_distributions(character)


func _mutation_data(character: Dictionary) -> Dictionary:
	if not character.has("mutations") or typeof(character.get("mutations")) != TYPE_DICTIONARY:
		character["mutations"] = {}
	_normalize_mutations(character)
	return character.get("mutations", {})


func _normalized_mutation_id_list(value, catalog: Dictionary) -> Array:
	var raw: Array = value if typeof(value) == TYPE_ARRAY else []
	var result := []
	var seen := {}
	for entry_value in raw:
		var mutation_id := ""
		if typeof(entry_value) == TYPE_DICTIONARY:
			mutation_id = String(entry_value.get("id", entry_value.get("mutation_id", "")))
		else:
			mutation_id = String(entry_value)
		if mutation_id.is_empty() or seen.has(mutation_id) or not catalog.has(mutation_id):
			continue
		seen[mutation_id] = true
		result.append(mutation_id)
	return result


func _normalized_mutation_distribution(value, kind: String, points: int) -> Dictionary:
	var order: Array = _get_parent().MUTATION_DRAWBACK_TIERS if kind == "drawback" else _get_parent().MUTATION_ADVANTAGE_TIERS
	var raw: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	var result := {}
	for tier in order:
		result[tier] = max(0, _get_parent()._as_int(raw.get(tier, 0)))
	var options := mutation_distribution_options(kind, points)
	var id := _mutation_distribution_id(result, order)
	for option_value in options:
		if typeof(option_value) == TYPE_DICTIONARY and String(option_value.get("id", "")) == id:
			return result
	if options.is_empty():
		return _empty_mutation_distribution(order)
	var first: Dictionary = options[0]
	return first.get("counts", {}).duplicate(true)


func _ensure_mutation_distributions(character: Dictionary) -> void:
	_ensure_mutation_distribution(character, "advantage")
	_ensure_mutation_distribution(character, "drawback")


func _ensure_mutation_distribution(character: Dictionary, kind: String) -> void:
	var mutations: Dictionary = character.get("mutations", {})
	var points_key := "drawback_points" if kind == "drawback" else "advantage_points"
	var distribution_key := "drawback_distribution" if kind == "drawback" else "advantage_distribution"
	mutations[distribution_key] = _normalized_mutation_distribution(mutations.get(distribution_key, {}), kind, _get_parent()._as_int(mutations.get(points_key, 0)))
	character["mutations"] = mutations


func _mutation_advantage_distribution_options(points: int) -> Array:
	var rows := []
	for amazing in range(mini(1, int(floor(points / 4.0))), -1, -1):
		for good in range(mini(2, int(floor((points - (4 * amazing)) / 2.0))), -1, -1):
			var ordinary: int = points - (4 * amazing) - (2 * good)
			if ordinary <= 3:
				var counts := {
					"Ordinary": ordinary,
					"Good": good,
					"Amazing": amazing,
				}
				rows.append(_mutation_distribution_option(counts, _get_parent().MUTATION_ADVANTAGE_TIERS, _get_parent().MUTATION_ADVANTAGE_LABEL_ORDER))
	return rows


func _mutation_drawback_distribution_options(points: int) -> Array:
	var rows := []
	for moderate in range(mini(8, int(floor(points / 2.0))), -1, -1):
		for extreme in range(mini(8, int(floor((points - (2 * moderate)) / 4.0))), -1, -1):
			var slight: int = points - (2 * moderate) - (4 * extreme)
			if slight <= 8:
				var counts := {
					"Slight": slight,
					"Moderate": moderate,
					"Extreme": extreme,
				}
				rows.append(_mutation_distribution_option(counts, _get_parent().MUTATION_DRAWBACK_TIERS, _get_parent().MUTATION_DRAWBACK_LABEL_ORDER))
	return rows


func _mutation_distribution_option(counts: Dictionary, id_order: Array, label_order: Array) -> Dictionary:
	return {
		"id": _mutation_distribution_id(counts, id_order),
		"label": _mutation_distribution_label(counts, label_order),
		"counts": counts.duplicate(true),
	}


func _mutation_distribution_id(counts: Dictionary, order: Array) -> String:
	var parts := []
	for tier_value in order:
		var tier := String(tier_value)
		parts.append("%s:%d" % [tier, _get_parent()._as_int(counts.get(tier, 0))])
	return "|".join(parts)


func _mutation_distribution_label(counts: Dictionary, order: Array) -> String:
	var parts := []
	for tier_value in order:
		var tier := String(tier_value)
		var count: int = _get_parent()._as_int(counts.get(tier, 0))
		if count <= 0:
			continue
		parts.append("%d %s" % [count, tier])
	return "None" if parts.is_empty() else " + ".join(parts)


func _empty_mutation_distribution(order: Array) -> Dictionary:
	var result := {}
	for tier in order:
		result[String(tier)] = 0
	return result


func _mutation_selected(character: Dictionary, selected_key: String, mutation_id: String) -> bool:
	var mutations := _mutation_data(character)
	for selected_id in mutations.get(selected_key, []):
		if String(selected_id) == mutation_id:
			return true
	return false


func _remove_mutation_selection(character: Dictionary, selected_key: String, mutation_id: String) -> void:
	var mutations := _mutation_data(character)
	var next := []
	for selected_id in mutations.get(selected_key, []):
		if String(selected_id) == mutation_id:
			continue
		next.append(String(selected_id))
	mutations[selected_key] = next
	character["mutations"] = mutations


func _mutation_advantage_tier_cap(tier: String) -> int:
	match tier:
		"Ordinary":
			return 3
		"Good":
			return 2
		"Amazing":
			return 1
	return 0


func _mutation_tier_count(rows: Array, tier: String) -> int:
	var count := 0
	for row_value in rows:
		if typeof(row_value) == TYPE_DICTIONARY and String(row_value.get("tier", "")) == tier:
			count += 1
	return count


func _roll_mutation_selection(character: Dictionary, selected_key: String, catalog: Array, kind: String) -> Dictionary:
	var mutations := _mutation_data(character)
	mutations[selected_key] = []
	character["mutations"] = mutations

	var distribution := mutation_distribution(character, kind)
	var order: Array = _get_parent().MUTATION_DRAWBACK_TIERS if kind == "drawback" else _get_parent().MUTATION_ADVANTAGE_TIERS
	var selected := []
	var failed := []
	for tier_value in order:
		var tier := String(tier_value)
		var needed: int = _get_parent()._as_int(distribution.get(tier, 0))
		for _index in range(needed):
			var mutation := _random_mutation_from_tier(catalog, tier, selected)
			if mutation.is_empty():
				failed.append(tier)
				continue
			var mutation_id := String(mutation.get("id", ""))
			var result := add_mutation_drawback(character, mutation_id) if kind == "drawback" else add_mutation_advantage(character, mutation_id)
			if bool(result.get("ok", false)):
				selected.append(mutation_id)
			else:
				failed.append("%s: %s" % [tier, String(result.get("reason", ""))])
	return {
		"selected": selected,
		"failed": failed,
	}


func _random_mutation_from_tier(catalog: Array, tier: String, excluded: Array) -> Dictionary:
	var candidates := []
	for mutation_value in catalog:
		if typeof(mutation_value) != TYPE_DICTIONARY:
			continue
		var mutation: Dictionary = mutation_value
		var mutation_id := String(mutation.get("id", ""))
		if String(mutation.get("tier", "")) == tier and not excluded.has(mutation_id):
			candidates.append(mutation)
	if candidates.is_empty():
		return {}
	return candidates[randi_range(0, candidates.size() - 1)]


func _selected_mutation_effect_sources(character: Dictionary) -> Array:
	var rows := []
	if not mutations_enabled(character):
		return rows
	for mutation in selected_mutation_advantages(character):
		rows.append(mutation)
	for drawback in selected_mutation_drawbacks(character):
		rows.append(drawback)
	return rows


func _mutation_effects(mutation: Dictionary, effect_type: String) -> Array:
	var result := []
	var effects: Array = mutation.get("effects", [])
	for effect_value in effects:
		if typeof(effect_value) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_value
		if String(effect.get("type", "")) == effect_type:
			result.append(effect)
	return result


func _roll_mutation_formula(formula: String) -> int:
	var clean := formula.strip_edges().to_lower()
	if clean.is_empty():
		return 0
	var sign_index := clean.find("+")
	var sign := 1
	if sign_index < 0:
		sign_index = clean.find("-")
		sign = -1
	if clean.begins_with("d"):
		var die_length := sign_index - 1 if sign_index > 0 else clean.length() - 1
		var die_text := clean.substr(1, die_length)
		var die_size: int = max(1, _get_parent()._as_int(die_text, 1))
		var modifier := 0
		if sign_index > 0:
			modifier = sign * _get_parent()._as_int(clean.substr(sign_index + 1), 0)
		return max(0, randi_range(1, die_size) + modifier)
	return max(0, _get_parent()._as_int(clean, 0))
