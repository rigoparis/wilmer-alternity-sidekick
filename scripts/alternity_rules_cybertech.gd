class_name AlternityRulesCybertech
extends RefCounted

var _parent_ref: WeakRef

func _init(p_parent: RefCounted) -> void:
	_parent_ref = weakref(p_parent)

func _get_parent():
	return _parent_ref.get_ref()

func get_cybertech_item_by_id(item_id: String) -> Dictionary:
	return _get_parent().cybertech_catalog_by_id.get(item_id, {})

func cybertech_enabled(character: Dictionary) -> bool:
	return bool(character.get("cybertech", {}).get("enabled", false))

func set_cybertech_enabled(character: Dictionary, enabled: bool) -> void:
	var cybertech_data := _cybertech_data(character)
	cybertech_data["enabled"] = enabled
	character["cybertech"] = cybertech_data

func is_cybertech_skill_purchased(character: Dictionary) -> bool:
	return bool(character.get("cybertech", {}).get("skill_purchased", false))

func set_cybertech_skill_purchased(character: Dictionary, purchased: bool) -> void:
	var cybertech_data := _cybertech_data(character)
	cybertech_data["skill_purchased"] = purchased
	character["cybertech"] = cybertech_data

func cyber_tolerance_total(character: Dictionary) -> int:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var con: int = AlternityNum.as_int(abilities.get("CON", 10))
	var species_id: int = AlternityNum.as_int(character.get("species_id", -1))
	# Mechalus species_id is typically 5 (assuming based on Alternity lore, but we'll check name)
	var is_mechalus = false
	for item in _get_parent().species:
		if String(item.get("name", "")) == "Mechalus" and AlternityNum.as_int(item.get("id", -1)) == species_id:
			is_mechalus = true
			break
	if is_mechalus:
		return con + 4
	return con

func cyber_tolerance_breakdown(character: Dictionary) -> Dictionary:
	var total := cyber_tolerance_total(character)
	var left := int(ceil(total / 2.0))
	var center := int(ceil((total - left) / 2.0))
	var right := int(ceil(float(total - left) / 2.0 / 2.0))
	# Fallback to avoid rounding issues if the sum isn't exactly total
	if left + center + right != total:
		right = total - left - center
	var used := 0
	for item in installed_cybertech(character):
		var size = AlternityNum.as_int(item.get("item", {}).get("size", item.get("item", {}).get("size_%s" % String(item.get("quality", "ordinary")), 0)))
		used += size

	return {
		"total": total,
		"left": left,
		"center": center,
		"right": right,
		"used": used
	}

func cykosis_total(character: Dictionary) -> int:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var will: int = AlternityNum.as_int(abilities.get("WIL", 10))
	return int(ceil(will / 2.0))

func cykosis_used(character: Dictionary) -> int:
	return AlternityNum.as_int(character.get("cybertech", {}).get("cykosis", 0))

func set_cykosis_used(character: Dictionary, used: int) -> void:
	var cybertech_data := _cybertech_data(character)
	cybertech_data["cykosis"] = clampi(used, 0, cykosis_total(character))
	character["cybertech"] = cybertech_data

func installed_cybertech(character: Dictionary) -> Array:
	var rows := []
	var cybertech_data := _cybertech_data(character)
	for install_data in cybertech_data.get("installed", []):
		if typeof(install_data) != TYPE_DICTIONARY:
			continue
		var item_id := String(install_data.get("item_id", ""))
		var item := get_cybertech_item_by_id(item_id)
		if item.is_empty():
			continue
		var row: Dictionary = install_data.duplicate(true)
		row["item"] = item
		rows.append(row)
	return rows

func install_cybertech(character: Dictionary, item_id: String, quality: String) -> Dictionary:
	var item := get_cybertech_item_by_id(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Unknown cybertech item."}
	var cybertech_data := _cybertech_data(character)
	var installed: Array = cybertech_data.get("installed", [])

	# Check if already installed
	for row in installed:
		if String(row.get("item_id", "")) == item_id:
			return {"ok": false, "reason": "Already installed."}
	installed.append({"item_id": item_id, "quality": quality})
	cybertech_data["installed"] = installed
	character["cybertech"] = cybertech_data

	# Auto-purchase skill if required and not purchased
	if bool(item.get("requires_skill_points", false)) and not is_cybertech_skill_purchased(character):
		set_cybertech_skill_purchased(character, true)

	return {"ok": true}

func remove_cybertech(character: Dictionary, item_id: String) -> void:
	var cybertech_data := _cybertech_data(character)
	var next := []
	for row in cybertech_data.get("installed", []):
		if String(row.get("item_id", "")) == item_id:
			continue
		next.append(row)
	cybertech_data["installed"] = next
	character["cybertech"] = cybertech_data

func cybertech_skill_points_used(character: Dictionary) -> int:
	if is_cybertech_skill_purchased(character):
		return 10
	return 0

func cybertech_stat_bonus(character: Dictionary, stat: String) -> int:
	var total := 0
	if not cybertech_enabled(character):
		return total
	for row in installed_cybertech(character):
		var item = row.get("item", {})
		var quality = String(row.get("quality", "ordinary"))
		var effects = item.get("effects", {})
		if effects.has("stat_bonus") and effects["stat_bonus"].has(stat):
			total += AlternityNum.as_int(effects["stat_bonus"][stat].get(quality, 0))
	return total

func cybertech_durability_bonus(character: Dictionary, track: String) -> int:
	var total := 0
	if not cybertech_enabled(character):
		return total
	for row in installed_cybertech(character):
		var item = row.get("item", {})
		var quality = String(row.get("quality", "ordinary"))
		var effects = item.get("effects", {})
		if effects.has("durability"):
			total += AlternityNum.as_int(effects["durability"].get(quality, {}).get(track, 0))
	return total

func cybertech_action_check_step(character: Dictionary) -> int:
	var total := 0
	if not cybertech_enabled(character):
		return total
	for row in installed_cybertech(character):
		var item = row.get("item", {})
		var quality = String(row.get("quality", "ordinary"))
		var effects = item.get("effects", {})
		if effects.has("action_step"):
			total += AlternityNum.as_int(effects["action_step"].get(quality, 0))
	return total

func cybertech_armor_rows(character: Dictionary) -> Array:
	var rows := []
	if not cybertech_enabled(character):
		return rows
	for row in installed_cybertech(character):
		var item = row.get("item", {})
		var quality = String(row.get("quality", "ordinary"))
		var effects = item.get("effects", {})
		if bool(effects.get("armor", false)):
			var li = "d4"
			var hi = "d4"
			var en = "d4-1"
			if quality == "good":
				li = "d6"
				hi = "d4+1"
				en = "d4+1"
			elif quality == "amazing":
				li = "d8+1"
				hi = "d6+1"
				en = "d6+1"
			var armor_item := {
				"id": "cybertech_%s" % String(item.get("id", "")),
				"kind": "armor",
				"name": String(item.get("name", "Cybertech Armor")),
				"source": "Cybertech",
				"source_code": "cybertech",
				"category": "Cybertech",
				"class": "Cybernetic Armor",
				"mass": 0,
				"cost": 0,
				"combat": {
					"role": "armor",
					"action_penalty": 0,
					"toughness": "O",
					"li": li,
					"hi": hi,
					"en": en,
				},
			}
			rows.append({
				"line_id": "cybertech_%s" % String(item.get("id", "")),
				"item_id": String(armor_item.get("id", "")),
				"quantity": 1,
				"equipped": true,
				"slot": "Cybertech",
				"notes": "Quality: %s" % quality.capitalize(),
				"item": armor_item,
				"total_mass": 0,
				"total_cost": 0,
			})
	return rows

func cybertech_attack_forms(character: Dictionary) -> Array:
	var forms := []
	if not cybertech_enabled(character):
		return forms
	for row in installed_cybertech(character):
		var item = row.get("item", {})
		var quality = String(row.get("quality", "ordinary"))
		var effects = item.get("effects", {})
		var combat = effects.get("combat", {})
		if not combat.is_empty():
			var skill_id: int = AlternityNum.as_int(combat.get("skill_id", 15))
			var score: Dictionary = _get_parent().equipment._combat_skill_score(character, skill_id)
			var damage := "d4w/d4+1w/d4+2w" # Default Ordinary BattleKlaw
			if String(item.get("id", "")) == "battleklaw":
				if quality == "good":
					damage = "d4+2w/d6+2w/d4m"
				elif quality == "amazing":
					damage = "d6+2w/d4m/d4+2m"
			var form := {
				"name": String(item.get("name", "Cybertech Attack")),
				"score": _get_parent().equipment._score_text(score),
				"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
				"type": String(combat.get("type", "")),
				"range": String(combat.get("range", "Personal")),
				"damage": damage,
				"hide": String(combat.get("hide", "-")),
				"clip_size": String(combat.get("clip_size", "-")),
				"mass": "",
				"note": "Quality: %s" % quality.capitalize(),
			}
			forms.append(form)
	return forms

func cybertech_summary(character: Dictionary) -> Dictionary:
	return {
		"enabled": cybertech_enabled(character),
		"skill_purchased": is_cybertech_skill_purchased(character),
		"tolerance": cyber_tolerance_breakdown(character),
		"cykosis": cykosis_used(character),
		"cykosis_total": cykosis_total(character),
		"installed": installed_cybertech(character),
	}

func _normalize_cybertech(character: Dictionary) -> void:
	var value = character.get("cybertech", {})
	var cybertech_data: Dictionary = value if typeof(value) == TYPE_DICTIONARY else {}
	character["cybertech"] = {
		"enabled": bool(cybertech_data.get("enabled", false)),
		"skill_purchased": bool(cybertech_data.get("skill_purchased", false)),
		"cykosis": AlternityNum.as_int(cybertech_data.get("cykosis", 0)),
		"installed": cybertech_data.get("installed", []) if typeof(cybertech_data.get("installed")) == TYPE_ARRAY else []
	}

func _cybertech_data(character: Dictionary) -> Dictionary:
	if not character.has("cybertech") or typeof(character.get("cybertech")) != TYPE_DICTIONARY:
		character["cybertech"] = {}
	_normalize_cybertech(character)
	return character.get("cybertech", {})
