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
	if not fx_data.has("energy_used"):
		fx_data["energy_used"] = 0
	if not fx_data.has("selected_skills"):
		fx_data["selected_skills"] = {}
	if not fx_data.has("permanent_skills"):
		fx_data["permanent_skills"] = {}
	character["fx"] = fx_data

func is_fx_active(character: Dictionary) -> bool:
	if _get_parent().is_adept_profession(character):
		return true
	var fx_data: Dictionary = character.get("fx", {})
	if bool(fx_data.get("enabled", false)):
		return true
	if bool(fx_data.get("is_fx_talent", false)):
		return true
	if not fx_data.get("selected_skills", {}).is_empty():
		return true
	return false


func is_fx_talent(character: Dictionary) -> bool:
	if not is_fx_active(character):
		return false
	if _get_parent().is_adept_profession(character):
		return false
	if _get_parent().is_dark_matter(character):
		return true
	var p_type := String(character.get("fx", {}).get("practitioner_type", ""))
	if not p_type.is_empty():
		return p_type == "talent"
	return bool(character.get("fx", {}).get("is_fx_talent", false))


func is_fx_adept(character: Dictionary) -> bool:
	if not is_fx_active(character):
		return false
	if _get_parent().is_adept_profession(character):
		return true
	if _get_parent().is_dark_matter(character):
		return false
	# Compatibility for characters saved before Adept became a profession in
	# the app. New characters select an Adept profession instead.
	return String(character.get("fx", {}).get("practitioner_type", "")) == "adept"


func set_fx_talent(character: Dictionary, enabled: bool) -> void:
	_normalize_fx(character)
	character["fx"]["enabled"] = enabled
	character["fx"]["is_fx_talent"] = enabled
	if enabled:
		character["fx"]["practitioner_type"] = "talent"


func set_practitioner_type(character: Dictionary, p_type: String) -> void:
	_normalize_fx(character)
	character["fx"]["practitioner_type"] = p_type
	character["fx"]["is_fx_talent"] = (p_type == "talent")

## The pool the hero started with, before anything they have bought.
##
## Flat in Dark*Matter, and not the player's to set: "Each FX talent starts with
## an FX energy pool of 5 points" (Part 2: Arcana p. 75). Elsewhere it is a number
## the player records, because the generic rules tie it to campaign scale -- 5
## realistic, 10 heroic, 15 superheroic. Dark*Matter is a realistic campaign and
## reprints the 5 as its own rule, so a hero who happened to have recorded 10
## would otherwise be playing a heroic game inside a modern one.
##
## The ceiling falls out of this rather than being stated twice: the pool may
## never pass twice its starting value, and twice five is the ten the setting
## names.
func energy_pool(character: Dictionary) -> int:
	if _get_parent().is_dark_matter(character):
		if _get_parent().is_primary_adept_profession(character):
			return 10
		return AlternityRules.DARK_MATTER_FX_STARTING_POOL
	var recorded := AlternityNum.as_int(character.get("fx", {}).get("energy_pool", 0))
	if recorded > 0 or not is_fx_active(character):
		return recorded

	# Beyond Science p. 4 sets the full pool by campaign scale. Page 6 gives
	# Talents half that amount (rounded up), while a primary Adept receives the
	# full pool. The default heroic campaign therefore starts at 10 / 5.
	var full_pool := 10
	match _get_parent().fx_campaign_scale(character):
		"realistic": full_pool = 5
		"superheroic": full_pool = 15
		_: full_pool = 10
	var is_legacy_primary_adept: bool = is_fx_adept(character) and not _get_parent().is_adept_profession(character)
	return full_pool if _get_parent().is_primary_adept_profession(character) or is_legacy_primary_adept else int(ceil(full_pool / 2.0))

func set_energy_pool(character: Dictionary, amount: int) -> void:
	_normalize_fx(character)
	character["fx"]["energy_pool"] = max(0, amount)


## Points added to the pool by achievement benefits.
##
## Kept apart from the recorded pool rather than folded into it, so the starting
## value stays visible -- Beyond Science caps the pool at twice that starting
## value, which cannot be checked once the two are added together.
func energy_pool_bonus(character: Dictionary) -> int:
	return _get_parent().achievements.fx_energy_pool_purchases(character)


## The hero's whole pool: what they recorded plus what they have bought.
func total_energy_pool(character: Dictionary) -> int:
	return energy_pool(character) + energy_pool_bonus(character)

func get_broad_skills() -> Array:
	return _get_parent().fx_broad_skills

func get_broad_skills_for_character(character: Dictionary) -> Array:
	var result: Array = []
	for broad in get_broad_skills():
		if _get_parent().is_entry_available(character, broad):
			result.append(broad)
	return result

func get_specialty_skills_for_broad(broad_name: String) -> Array:
	return _get_parent().fx_specialty_skills_by_broad.get(broad_name, [])

func get_specialty_skills_for_broad_and_character(broad_name: String, character: Dictionary) -> Array:
	var result: Array = []
	for spec in get_specialty_skills_for_broad(broad_name):
		if _get_parent().is_entry_available(character, spec):
			result.append(spec)
	return result

func get_broad_skill(skill_name: String) -> Dictionary:
	var map: Dictionary = _get_parent().fx_broad_skills_by_name
	if map.has(skill_name):
		return map[skill_name]
	return map.get(skill_name.to_lower(), {})

func get_specialty_skill(skill_name: String) -> Dictionary:
	var map: Dictionary = _get_parent().fx_specialty_skills_by_name
	if map.has(skill_name):
		return map[skill_name]
	return map.get(skill_name.to_lower(), {})

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

## The live FX pool. A permanently active power holds its cost against the pool
## for as long as it runs, so those come off the top before anything is spent.
## Source: Beyond Science: A Guide to FX p. 5.
func fx_energy(character: Dictionary) -> Dictionary:
	var total := total_energy_pool(character)
	var reserved: int = mini(permanent_fx_energy_drain(character), total)
	var spendable := total - reserved
	var used := clampi(energy_used(character), 0, spendable)
	_normalize_fx(character)
	character["fx"]["energy_used"] = used
	return {
		"max": total,
		"reserved": reserved,
		"spendable": spendable,
		"used": used,
		"available": spendable - used,
	}


func energy_used(character: Dictionary) -> int:
	return AlternityNum.as_int(character.get("fx", {}).get("energy_used", 0))


func set_energy_used(character: Dictionary, used: int) -> void:
	_normalize_fx(character)
	var total := total_energy_pool(character)
	var spendable: int = total - mini(permanent_fx_energy_drain(character), total)
	character["fx"]["energy_used"] = clampi(used, 0, maxi(0, spendable))


func spend_energy(character: Dictionary, points: int) -> int:
	if points <= 0:
		return 0
	var pool := fx_energy(character)
	var spent: int = mini(points, AlternityNum.as_int(pool.get("available", 0)))
	set_energy_used(character, AlternityNum.as_int(pool.get("used", 0)) + spent)
	return spent


func restore_energy(character: Dictionary, points: int) -> int:
	if points <= 0:
		return 0
	var pool := fx_energy(character)
	var restored: int = mini(points, AlternityNum.as_int(pool.get("used", 0)))
	set_energy_used(character, AlternityNum.as_int(pool.get("used", 0)) - restored)
	return restored


## An hour of rest, settled the same way a psionic one is.
## Source: Beyond Science: A Guide to FX p. 5.
func rest_energy(character: Dictionary, result: String) -> int:
	return restore_energy(character, _get_parent().energy_recovered_for_result(result))


## Eight unbroken hours without using FX refill the pool outright, no check.
## Source: Beyond Science: A Guide to FX p. 5.
func full_rest_energy(character: Dictionary) -> int:
	var restored := energy_used(character)
	set_energy_used(character, 0)
	return restored


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

func max_rank_for_fx_skill(character: Dictionary, skill_name: String) -> int:
	if character.is_empty():
		return AlternityRules.CREATION_SPECIALTY_RANK
	var broad := get_broad_skill(skill_name)
	if not broad.is_empty():
		return 1
	var specialty := get_specialty_skill(skill_name)
	if specialty.is_empty():
		return 0

	var general_cap: int = _get_parent().max_skill_rank_for_character(character)

	if is_fx_adept(character):
		if (
			_get_parent().is_dark_matter(character)
			and not _get_parent().optional_rule_enabled(character, "dm_adept_unrestricted_ranks")
		):
			var primary_group := primary_broad_group(character)
			var skill_broad := String(specialty.get("broad_skill", ""))
			var setting_cap := (
				AlternityRules.DARK_MATTER_FX_TALENT_TOP_RANK
				if not primary_group.is_empty() and skill_broad == primary_group
				else AlternityRules.DARK_MATTER_FX_TALENT_OTHER_RANK
			)
			return mini(general_cap, setting_cap)
		return general_cap

	if is_fx_talent(character):
		var is_dm: bool = _get_parent().is_dark_matter(character)
		var max_top_slots: int = 1 if is_dm else 2
		var top_cap := 6
		var second_cap := 3

		var other_above_second := 0
		var selected: Dictionary = character.get("fx", {}).get("selected_skills", {})
		for o_name in selected.keys():
			var o_key := String(o_name)
			if o_key == skill_name:
				continue
			var o_spec := get_specialty_skill(o_key)
			if o_spec.is_empty():
				continue
			if fx_skill_rank(character, o_key) > second_cap:
				other_above_second += 1

		var talent_cap := second_cap if other_above_second >= max_top_slots else top_cap
		return mini(general_cap, talent_cap)

	return general_cap

func add_fx_skill(character: Dictionary, skill_name: String) -> void:
	_normalize_fx(character)
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		character["fx"]["selected_skills"][skill_name] = 1
		return
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var parent_broad := String(specialty.get("broad_skill", ""))
		if not parent_broad.is_empty() and not is_fx_skill_selected(character, parent_broad):
			character["fx"]["selected_skills"][parent_broad] = 1
		var current = fx_skill_rank(character, skill_name)
		var max_rank = max_rank_for_fx_skill(character, skill_name)
		character["fx"]["selected_skills"][skill_name] = mini(
			current + 1, max_rank
		)

func remove_fx_skill(character: Dictionary, skill_name: String) -> void:
	_normalize_fx(character)
	var selected: Dictionary = character["fx"]["selected_skills"]
	if not selected.has(skill_name):
		return
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		selected.erase(skill_name)
		character["fx"].get("permanent_skills", {}).erase(skill_name)
		for spec in get_specialty_skills_for_broad(skill_name):
			var spec_name := String(spec.get("name", ""))
			selected.erase(spec_name)
			character["fx"].get("permanent_skills", {}).erase(spec_name)
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

## The school this hero's FX is centred on, if they still have it.
##
## Adepts receive their profession discount only inside the primary school.
## Talents still name a primary tradition, but Beyond Science p. 3 says they pay
## full list price for all FX broad and specialty skills; it does not double the
## price of skills outside that tradition.
##
## A primary school the hero does not have is treated as unset, so an Adept never
## receives a discount from stale imported data.
func primary_broad_group(character: Dictionary) -> String:
	var stored := String(character.get("fx", {}).get("primary_broad_group", "")).strip_edges()
	if stored.is_empty():
		return ""
	return stored if is_fx_skill_selected(character, stored) else ""


## Name the hero's primary school. Fixed once set.
##
## Beyond Science requires every FX user to designate one school when they first
## take FX abilities, and it defines their tradition rather than being a
## purchase they can re-optimise. Reassigning it would let a player move the
## doubled cost onto whichever school they had spent least in.
##
## The one reassignment allowed is away from a school the hero does not have,
## which is stale data rather than a choice -- a real saved character carried
## exactly that and was being charged double for powers in schools they owned.
func set_primary_broad_group(character: Dictionary, broad_name: String) -> void:
	_normalize_fx(character)
	if not primary_broad_group(character).is_empty():
		return
	character["fx"]["primary_broad_group"] = broad_name


## Whether the hero still needs to name a primary school.
##
## True once they hold an FX broad skill and have not designated one. Their
## powers are priced at list until they do, which is cheaper than the rules
## allow, so it is worth saying rather than leaving quietly favourable.
func needs_primary_broad_group(character: Dictionary) -> bool:
	if not is_fx_adept(character):
		return false
	if not primary_broad_group(character).is_empty():
		return false
	for broad in get_broad_skills_for_character(character):
		if is_fx_skill_selected(character, String(broad.get("name", ""))):
			return true
	return false


func next_fx_skill_rank_cost(character: Dictionary, skill_name: String) -> int:
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return fx_skill_cost_for_rank(character, skill_name, 1) if not is_fx_skill_selected(character, skill_name) else 0
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var rank = fx_skill_rank(character, skill_name)
		if rank >= max_rank_for_fx_skill(character, skill_name):
			return 0
		return fx_skill_cost_for_rank(character, skill_name, rank + 1)
	return 0


func fx_skill_cost(character: Dictionary, skill_name: String) -> int:
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		# Through cost_for_rank rather than off the catalog, so a school is priced
		# in one place and a talent's surcharge cannot be skipped by asking a
		# different question about the same skill.
		return fx_skill_cost_for_rank(character, skill_name, 1)
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var rank = fx_skill_rank(character, skill_name)
		return fx_skill_cost_for_rank(character, skill_name, rank + 1)
	return 0

## What Dark*Matter adds above the listed price for every FX practitioner.
##
## "FX Talents must pay 1 point more than the listed cost for all FX broad and
## specialty skills." It is the same shape as the psionic talent surcharge and
## for the same reason. A GM-imported Adept still pays it; the Adept's chosen
## school discount is applied separately and offsets the surcharge there.
##
## Zero outside Dark*Matter, where an Adept buys at list.
func _talent_surcharge(character: Dictionary) -> int:
	if not _get_parent().is_dark_matter(character):
		return 0
	return AlternityRules.DARK_MATTER_TALENT_SURCHARGE


## What the book on the table prices this at.
##
## A setting may reprint a school at its own price rather than adopt the one it
## inherited: Beyond Science prices Hermeticism at 9 (p. 14, Table F3) and
## Dark*Matter reprints it at 10 (Part 2: Arcana p. 74, Table D6). Both are
## correct in their own book, so the entry carries both and the campaign decides
## -- rather than one of them being quietly wrong for half the tables using it.
func _listed_cost(character: Dictionary, entry: Dictionary) -> int:
	var overrides = entry.get("cost_by_setting")
	if typeof(overrides) == TYPE_DICTIONARY:
		for setting_name in overrides:
			if _get_parent().is_setting_available(character, String(setting_name)):
				return AlternityNum.as_int(overrides[setting_name])
	return AlternityNum.as_int(entry.get("cost", 0))


func fx_skill_cost_for_rank(character: Dictionary, skill_name: String, rank: int) -> int:
	var entry: Dictionary = get_broad_skill(skill_name)
	var entry_broad := skill_name
	var is_broad := not entry.is_empty()
	if not is_broad:
		entry = get_specialty_skill(skill_name)
		if entry.is_empty():
			return 0
		entry_broad = String(entry.get("broad_skill", ""))

	if is_broad and rank != 1:
		return 0

	var base_cost := _listed_cost(character, entry)
	var primary_group := primary_broad_group(character)
	if is_fx_adept(character) and not primary_group.is_empty() and entry_broad == primary_group:
		base_cost -= 1
	base_cost += _talent_surcharge(character)
	base_cost = maxi(1, base_cost)

	if is_broad or rank <= 1 or _get_parent().optional_rule_enabled(character, "2c"):
		return base_cost
	return base_cost + (rank - 1)

func fx_skill_total_cost(character: Dictionary, skill_name: String) -> int:
	var rank = fx_skill_rank(character, skill_name)
	if rank <= 0:
		return 0
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return fx_skill_cost_for_rank(character, skill_name, 1)
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
			for ch in word:
				if ch in "0123456789":
					digit_str += ch
			if not digit_str.is_empty():
				ranks.append(digit_str.to_int())
				break
			var has_letters = false
			for ch in word:
				if ch in "abcdefghijklmnopqrstuvwxyz":
					has_letters = true
					break
			if has_letters and not (word in ["and", "or", ",", ".", "&", "to"]):
				break
				
		start_pos = pos + 4
	
	if ranks.is_empty():
		ranks.append(99)
	return ranks


## What an FX power actually rolls, and whether it may be attempted at all.
##
## Three rules from the same paragraph, none of which were computed:
##
##   * No FX broad skill can ever be used untrained. An unheld school scored
##     the caster's full ability, so a hero with no magic at all rolled
##     Illusion better than one who had paid for it.
##   * Holding a broad skill is not untrained use. The halving was attached to
##     the wrong branch, so buying a school HALVED its score -- INT 12 went
##     from 12 to 6 the moment it was paid for.
##   * A spell, miracle or power is reachable only through its own school,
##     faith or category, exactly as a psionic power is reachable only through
##     its discipline.
##
## Source: Beyond Science: A Guide to FX p. 5.
func fx_skill_score(character: Dictionary, skill_name: String) -> Dictionary:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var specialty := get_specialty_skill(skill_name)
	var broad := get_broad_skill(skill_name)
	var is_broad := not broad.is_empty()
	var entry: Dictionary = broad if is_broad else specialty

	var ability := String(entry.get("ability", "WIL"))
	var ability_score := 10
	if ability.contains("/"):
		# Several broads answer to more than one ability; the caster uses whichever
		# of them serves them best.
		var best := 0
		for part in ability.split("/"):
			var value := AlternityNum.as_int(abilities.get(part.strip_edges(), 10))
			if value > best:
				best = value
		ability_score = best
	else:
		ability_score = AlternityNum.as_int(abilities.get(ability, 10))

	var rank := fx_skill_rank(character, skill_name)
	var parent_name := "" if is_broad else String(specialty.get("broad_skill", ""))
	var parent_held: bool = (not is_broad) and is_fx_skill_selected(character, parent_name)

	if entry.is_empty():
		return _fx_unusable("This FX skill is not in the catalog.")

	if is_broad and rank <= 0:
		return _fx_unusable(
			"%s cannot be used untrained. No FX broad skill can be, so the school, faith or category has to be bought before anything under it can be attempted. Source: Beyond Science: A Guide to FX p. 5."
			% skill_name
		)

	if not is_broad and not parent_held:
		return _fx_unusable(
			"%s needs the %s broad skill. FX powers are reachable only through the school, faith or category they belong to. Source: Beyond Science: A Guide to FX p. 5."
			% [skill_name, parent_name]
		)

	# A held specialty rolls its own rank at +d0. Without a rank the parent broad
	# carries it, at the broad score and the broad's +d4 -- but only where the
	# entry permits untrained use, which is most Faith miracles and almost no
	# Arcane spell or Super Power.
	var via_broad := false
	if not is_broad and rank <= 0:
		if not bool(specialty.get("untrained", false)):
			return _fx_unusable(
				"%s cannot be used untrained; the %s broad skill alone is not enough. Source: Beyond Science: A Guide to FX p. 5."
				% [skill_name, parent_name]
			)
		via_broad = true
		if _get_parent().is_dark_matter(character):
			# Dark Matter Part 2: Arcana p. 75: untrained FX skill checks are made
			# using a feat check using the ability score associated with the specialty skill used.
			var spec_ability := String(specialty.get("ability", "WIL"))
			ability_score = AlternityNum.as_int(abilities.get(spec_ability, 10))
		else:
			ability_score = _broad_ability_score(character, parent_name)

	var rank_bonus := 0 if (is_broad or via_broad) else rank
	var ordinary := ability_score + rank_bonus
	var good := int(floor(ordinary / 2.0))
	var amazing := int(floor(good / 2.0))
	var step := 1 if (is_broad or via_broad) else 0
	var dazed: int = _get_parent().dazed_penalty(character)
	step += dazed

	# Build a step_breakdown the same way skill_score() does, so the dice
	# tray and the GM step-setting modal can display it.
	var step_breakdown: Array = []
	if is_broad:
		step_breakdown.append({"source": "Broad FX Skill", "step": 1, "detail": "Broad FX skills suffer a +1 step penalty (+d4). Source: Beyond Science p. 5."})
	elif via_broad:
		step_breakdown.append({"source": "Covered by Broad Skill", "step": 1, "detail": "Untrained power covered by the broad skill (+1 step penalty). Source: Beyond Science p. 5."})
	if dazed != 0:
		step_breakdown.append({"source": "Damage / Dazed Condition", "step": dazed, "detail": "Penalty from marked Mortal/Fatigue damage or Dazed state."})

	# Medical Science - Medical Knowledge synergy for Animate Dead
	if skill_name.to_lower() == "animate dead":
		var med_rank: int = _get_parent().skill_rank(character, 87)
		var med_bonus := 0
		if med_rank >= 12:
			med_bonus = -4
		elif med_rank >= 8:
			med_bonus = -3
		elif med_rank >= 5:
			med_bonus = -2
		elif med_rank >= 2:
			med_bonus = -1
		if med_bonus != 0:
			step += med_bonus
			step_breakdown.append({
				"source": "Medical Science - Medical Knowledge",
				"step": med_bonus,
				"detail": "Synergy bonus from Medical Knowledge rank %d (%d step bonus). Source: Beyond Science p. 32." % [med_rank, med_bonus]
			})

	# For non-permanent specialty powers, check whether the hero has enough FX
	# energy to activate them. Flag the score unusable rather than silently
	# letting a player roll a power they physically cannot fire.
	if not is_broad:
		var is_perm: bool = is_fx_skill_permanent(character, skill_name)
		if not is_perm:
			var act: Dictionary = fx_activation_cost(character, skill_name)
			var cost: int = AlternityNum.as_int(act.get("total", 1))
			var pool: Dictionary = fx_energy(character)
			var available: int = AlternityNum.as_int(pool.get("available", 0))
			if available < cost:
				var parent_broad := String(specialty.get("broad_skill", ""))
				var has_necromancy: bool = is_fx_skill_selected(character, "Necromancy") or parent_broad.to_lower() == "necromancy"
				if has_necromancy:
					var needed_fx := cost - available
					var needed_fatigue := needed_fx * 2
					var dur: Dictionary = _get_parent().durability(character)
					var max_fatigue: int = AlternityNum.as_int(dur.get("fatigue", 0))
					var dmg: Dictionary = character.get("damage", {})
					var cur_fatigue: int = AlternityNum.as_int(dmg.get("fatigue", 0))
					if cur_fatigue + needed_fatigue <= max_fatigue:
						step_breakdown.append({
							"source": "Life Force Substitution",
							"step": 0,
							"detail": "FX energy insufficient; substituting %d fatigue points (%d available FX + %d fatigue). Source: Beyond Science p. 31." % [needed_fatigue, available, needed_fatigue]
						})
					else:
						return _fx_unusable(
							"%s requires %d FX energy point%s (or %d fatigue points via Life Force Substitution), but hero has only %d FX and %d remaining fatigue capacity. Rest to recover. Source: Beyond Science p. 31."
							% [skill_name, cost, "s" if cost != 1 else "", needed_fatigue, available, max_fatigue - cur_fatigue]
						)
				else:
					return _fx_unusable(
						"%s requires %d FX energy point%s to activate, but only %d %s available. Rest to recover FX energy. Source: Beyond Science: A Guide to FX p. 5."
						% [skill_name, cost, "s" if cost != 1 else "", available, "are" if available != 1 else "is"]
					)

	return {
		"marginal": ordinary + 1,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"base": ability_score,
		"step": step,
		"step_breakdown": step_breakdown,
		"usable": true,
		"via_broad": via_broad,
		"die": _get_parent().action_step_die(step)
	}


func _fx_unusable(reason: String) -> Dictionary:
	return {
		"marginal": 0,
		"ordinary": 0,
		"good": 0,
		"amazing": 0,
		"base": 0,
		"step": 0,
		"usable": false,
		"via_broad": false,
		"reason": reason,
		"die": "+d0",
	}


## Checks whether a character can use Life Force Substitution (2 Fatigue per 1 missing FX).
## Only available to practitioners of Necromancy.
## Source: Beyond Science: A Guide to FX p. 31.
func can_substitute_life_force(character: Dictionary, cost: int) -> Dictionary:
	var has_necromancy: bool = is_fx_skill_selected(character, "Necromancy")
	if not has_necromancy:
		return {"allowed": false, "reason": "Character does not possess the Necromancy broad skill."}
	var pool: Dictionary = fx_energy(character)
	var available: int = AlternityNum.as_int(pool.get("available", 0))
	if available >= cost:
		return {"allowed": false, "reason": "Hero has sufficient FX energy pool (%d available, %d needed)." % [available, cost]}
	var missing: int = cost - available
	var fatigue_needed: int = missing * 2
	var dur: Dictionary = _get_parent().durability(character)
	var max_fatigue: int = AlternityNum.as_int(dur.get("fatigue", 0))
	var dmg: Dictionary = character.get("damage", {})
	var cur_fatigue: int = AlternityNum.as_int(dmg.get("fatigue", 0))
	var remaining_fatigue: int = maxi(0, max_fatigue - cur_fatigue)
	if cur_fatigue + fatigue_needed > max_fatigue:
		return {
			"allowed": false,
			"missing_fx": missing,
			"fatigue_needed": fatigue_needed,
			"remaining_fatigue": remaining_fatigue,
			"reason": "Insufficient fatigue capacity (%d needed, only %d remaining before KO)." % [fatigue_needed, remaining_fatigue],
		}
	return {
		"allowed": true,
		"missing_fx": missing,
		"fatigue_needed": fatigue_needed,
		"remaining_fatigue": remaining_fatigue,
	}


## The score a broad skill itself rolls, used when it carries one of its own
## specialties.
func _broad_ability_score(character: Dictionary, broad_name: String) -> int:
	var broad := get_broad_skill(broad_name)
	if broad.is_empty():
		return 0
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	var ability := String(broad.get("ability", "WIL"))
	if not ability.contains("/"):
		return AlternityNum.as_int(abilities.get(ability, 10))
	var best := 0
	for part in ability.split("/"):
		var value := AlternityNum.as_int(abilities.get(part.strip_edges(), 10))
		if value > best:
			best = value
	return best


## What one activation costs, and why.
##
## Every entry states its cost; leaning on the broad skill instead of a rank of
## your own adds a point.
## Source: Beyond Science: A Guide to FX p. 5.
func fx_activation_cost(character: Dictionary, skill_name: String) -> Dictionary:
	var specialty := get_specialty_skill(skill_name)
	if specialty.is_empty():
		return {"points": 0, "untrained_surcharge": 0, "total": 0}
	var base := AlternityNum.as_int(specialty.get("fx_cost", 1), 1)
	var maximum := AlternityNum.as_int(specialty.get("fx_cost_max", base), base)
	var surcharge := 1 if fx_skill_rank(character, skill_name) <= 0 else 0
	return {
		"points": base,
		"points_max": maxi(base, maximum),
		"untrained_surcharge": surcharge,
		"total": base + surcharge,
	}


## Calculates temporary durability boxes granted by Fortitude.
## Ordinary: +2 stun, +1 wound, +0 mortal, +0 fatigue
## Good: +3 stun, +2 wound, +1 mortal, +0 fatigue
## Amazing: +4 stun, +3 wound, +2 mortal, +2 fatigue
## Rank 4: +1 to each category; Rank 8: +2; Rank 12: +3.
## Source: Beyond Science: A Guide to FX p. 32.
func fortitude_boxes(character: Dictionary, degree: String, rank_override: int = -1) -> Dictionary:
	var rank: int = rank_override if rank_override >= 0 else fx_skill_rank(character, "Fortitude")
	var rank_bonus := 0
	if rank >= 12:
		rank_bonus = 3
	elif rank >= 8:
		rank_bonus = 2
	elif rank >= 4:
		rank_bonus = 1

	var d := degree.to_lower()
	var s := 0
	var w := 0
	var m := 0
	var f := 0

	if d == "ordinary":
		s = 2
		w = 1
		m = 0
		f = 0
	elif d == "good":
		s = 3
		w = 2
		m = 1
		f = 0
	elif d == "amazing":
		s = 4
		w = 3
		m = 2
		f = 2
	else:
		return {"stun": 0, "wound": 0, "mortal": 0, "fatigue": 0, "total": 0, "degree": degree, "rank": rank, "rank_bonus": rank_bonus}

	s += rank_bonus
	w += rank_bonus
	m += rank_bonus
	f += rank_bonus
	return {
		"stun": s,
		"wound": w,
		"mortal": m,
		"fatigue": f,
		"total": s + w + m + f,
		"degree": degree.capitalize(),
		"rank": rank,
		"rank_bonus": rank_bonus,
	}


## Apply Fortitude temporary durability boxes to a character.
## Sets character["temporary_durability"] with the remaining and max boxes.
func apply_fortitude(target_character: Dictionary, degree: String, rank: int = 0) -> Dictionary:
	var boxes := fortitude_boxes(target_character, degree, rank)
	if AlternityNum.as_int(boxes.get("total", 0)) <= 0:
		return {}
	var s: int = AlternityNum.as_int(boxes.get("stun", 0))
	var w: int = AlternityNum.as_int(boxes.get("wound", 0))
	var m: int = AlternityNum.as_int(boxes.get("mortal", 0))
	var f: int = AlternityNum.as_int(boxes.get("fatigue", 0))
	var temp_dur := {
		"source": "Fortitude",
		"degree": degree.capitalize(),
		"rank": rank,
		"stun": 0,
		"wound": 0,
		"mortal": 0,
		"fatigue": 0,
		"max_stun": s,
		"max_wound": w,
		"max_mortal": m,
		"max_fatigue": f,
	}
	target_character["temporary_durability"] = temp_dur
	return temp_dur


## Clear any temporary durability boxes (e.g. at end of scene or when dismissed).
func clear_temporary_durability(character: Dictionary) -> void:
	character.erase("temporary_durability")


## Control limit for Animate Dead: CON score.
## Source: Beyond Science: A Guide to FX p. 32.
func zombie_control_limit(character: Dictionary) -> int:
	var abilities: Dictionary = _get_parent().effective_abilities(character)
	return AlternityNum.as_int(abilities.get("CON", 10))


## Durability bonus for zombies created by Animate Dead:
## Rank 6: +1 to all durability tracks (+1 stun, +1 wound, +1 mortal).
## Rank 12: +2 to all durability tracks (+2 stun, +2 wound, +2 mortal).
## Source: Beyond Science: A Guide to FX p. 32.
func zombie_durability_bonus(character: Dictionary) -> int:
	var rank := fx_skill_rank(character, "Animate dead")
	if rank >= 12:
		return 2
	elif rank >= 6:
		return 1
	return 0


## Attack forms granted by FX powers (e.g. Energy Drain, Zombie Servant minion, etc.)
func fx_attack_forms(character: Dictionary) -> Array:
	var forms: Array = []
	if is_fx_skill_selected(character, "Energy drain"):
		var score := fx_skill_score(character, "Energy drain")
		var rank := fx_skill_rank(character, "Energy drain")
		var dmg := "d4+1s/d6+2s/d4+1w"
		if rank >= 9:
			dmg = "d8+2s/d12+3s/d4+3f"
		elif rank >= 5:
			dmg = "d6+2s/d8+3s/d4+2f"
		forms.append({
			"name": "Energy Drain",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": "Touch",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
		})
	if is_fx_skill_selected(character, "Animate dead"):
		var limit := zombie_control_limit(character)
		var dur_bonus := zombie_durability_bonus(character)
		forms.append({
			"name": "Zombie Servant (Minion)",
			"score": "Max Control: %d" % limit,
			"base_die": "+d0",
			"type": "LI/O",
			"range": "Melee",
			"damage": "d4+1w/d4+2w/d4+3w",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Zombie minion slam/bite. Durability bonus: +%d to all tracks." % dur_bonus,
		})
	if is_fx_skill_selected(character, "Mummy's curse"):
		var score := fx_skill_score(character, "Mummy's curse")
		forms.append({
			"name": "Mummy's Curse",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "Sp/O",
			"range": "10m",
			"damage": "Affliction (-2/-4/-6 stat penalty)",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
		})
	if is_fx_skill_selected(character, "Steal the soul"):
		var score := fx_skill_score(character, "Steal the soul")
		forms.append({
			"name": "Steal the Soul",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "Sp/O",
			"range": "Touch",
			"damage": "Soul extraction / Coma",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
		})
	if is_fx_skill_selected(character, "Hellfire"):
		var score := fx_skill_score(character, "Hellfire")
		var rank := fx_skill_rank(character, "Hellfire")
		var dmg := "d4w/d4+1w/d4+2w"
		if rank >= 12:
			dmg = "d6+1w/d6+1w/d6+2w"
		elif rank >= 8:
			dmg = "d6w/d6+1w/d6+2w"
		elif rank >= 4:
			dmg = "d4+1w/d4+1w/d4+2w"
		forms.append({
			"name": "Hellfire",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": "30m",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Extradimensional hellfire; bypasses physical armor.",
		})
	if is_fx_skill_selected(character, "Command"):
		var score := fx_skill_score(character, "Command")
		forms.append({
			"name": "Command (Extradimensional)",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "Sp/O",
			"range": "10m",
			"damage": "Mental Domination / Subjugation",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Commands extraplanar entity; target resists with Willpower.",
		})
	if is_fx_skill_selected(character, "Stigmata"):
		var score := fx_skill_score(character, "Stigmata")
		var rank := fx_skill_rank(character, "Stigmata")
		var dmg := "d4+1s/d6+1s/d4w"
		if rank >= 12:
			dmg = "d8+2s/d12+2s/d4+4w"
		elif rank >= 8:
			dmg = "d6+2s/2d4+2s/2d4w"
		elif rank >= 4:
			dmg = "d4+2s/d6+2s/d4+1w"
		forms.append({
			"name": "Stigmata",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "LI/O",
			"range": "Touch / 10m",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Causes spontaneous bleeding from flesh; bypasses physical armor.",
		})
	if is_fx_skill_selected(character, "Runs cold"):
		var score := fx_skill_score(character, "Runs cold")
		forms.append({
			"name": "Runs Cold",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "Sp/O",
			"range": "Touch",
			"damage": "Debuff (-1 phase / +1 step penalty)",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Chills target blood; slows reactions and imposes action penalties.",
		})
	if is_fx_skill_selected(character, "Fiery bolt"):
		var score := fx_skill_score(character, "Fiery bolt")
		var rank := fx_skill_rank(character, "Fiery bolt")
		var bonus := 0
		if rank >= 8:
			bonus = 2
		elif rank >= 4:
			bonus = 1
		forms.append({
			"name": "Fiery Bolt",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": "20m/40m/60m",
			"damage": "d4+%dw/d6+%dw/d4+%dm" % [1 + bonus, 1 + bonus, 2 + bonus],
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Searing bolt of flame projected from hands.",
		})
	if is_fx_skill_selected(character, "Flame gauntlet"):
		var score := fx_skill_score(character, "Flame gauntlet")
		var rank := fx_skill_rank(character, "Flame gauntlet")
		var bonus := 0
		if rank >= 12:
			bonus = 3
		elif rank >= 8:
			bonus = 2
		elif rank >= 4:
			bonus = 1
		forms.append({
			"name": "Flame Gauntlet",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": "Melee Touch",
			"damage": "d4+%dw/d6+%dw/d4+%dm" % [2 + bonus, 2 + bonus, 2 + bonus],
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Fists sheathed in supernatural fire; adds to melee touch strikes.",
		})
	if is_fx_skill_selected(character, "Immolation"):
		var score := fx_skill_score(character, "Immolation")
		var rank := fx_skill_rank(character, "Immolation")
		var dmg := "d4s/d4+1s/d4+2s per round"
		if rank >= 12:
			dmg = "d6+3s per round"
		elif rank >= 8:
			dmg = "d4+3s per round"
		elif rank >= 4:
			dmg = "d4+1s/d4+2s/d4+4s per round"
		forms.append({
			"name": "Immolation",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": "20m",
			"damage": dmg,
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Target spontaneously catches fire; continuous damage over time.",
		})
	if is_fx_skill_selected(character, "Incendiary seal"):
		var score := fx_skill_score(character, "Incendiary seal")
		var rank := fx_skill_rank(character, "Incendiary seal")
		var range_str := "Touch"
		if rank >= 12:
			range_str = "30m proximity"
		elif rank >= 8:
			range_str = "20m proximity"
		elif rank >= 4:
			range_str = "10m proximity"
		forms.append({
			"name": "Incendiary Seal",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": range_str,
			"damage": "d4+1w/d6+1w/d4m",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Trap rune inscribed on surface; detonates when crossed.",
		})
	if is_fx_skill_selected(character, "Storm of flames"):
		var score := fx_skill_score(character, "Storm of flames")
		var rank := fx_skill_rank(character, "Storm of flames")
		var range_str := "30m"
		if rank >= 12:
			range_str = "250m"
		elif rank >= 4:
			range_str = "60m"
		var vol_str := "10m radius" if rank < 8 else "10m x 10m volume"
		forms.append({
			"name": "Storm of Flames",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "En/O",
			"range": range_str,
			"damage": "d6w/d8w/d6m (%s)" % vol_str,
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Cataclysmic tempest of fire sweeping through the designated area.",
		})
	if is_fx_skill_selected(character, "Super Strength"):
		var score := fx_skill_score(character, "Super Strength")
		var rank := fx_skill_rank(character, "Super Strength")
		var mult := 2
		if rank >= 12:
			mult = 5
		elif rank >= 8:
			mult = 4
		elif rank >= 4:
			mult = 3
		forms.append({
			"name": "Super Strength Melee",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"type": "LI/O",
			"range": "Melee",
			"damage": "d4+2w/d4+4w/d4+2m (LI/O)",
			"hide": "-",
			"clip_size": "-",
			"mass": "-",
			"detail": "Superhuman physical strikes; lift capacity multiplied by %dx." % mult,
		})
	return forms


## Defense and support forms granted by FX powers (e.g. Fortitude Vitality Shield, Haunt, Knit Wounds)
func fx_defense_forms(character: Dictionary) -> Array:
	var forms: Array = []
	if is_fx_skill_selected(character, "Fortitude"):
		var score := fx_skill_score(character, "Fortitude")
		var rank := fx_skill_rank(character, "Fortitude")
		var rank_bonus := 0
		if rank >= 12:
			rank_bonus = 3
		elif rank >= 8:
			rank_bonus = 2
		elif rank >= 4:
			rank_bonus = 1
		forms.append({
			"name": "Fortitude",
			"skill_name": "Fortitude",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Vitality Shield",
			"range": "Touch (Self or Ally)",
			"duration": "1 scene",
			"benefit": "Temporary durability boxes: Ord %ds/%dw, Good %ds/%dw/%dm, Amazing %ds/%dw/%dm/%df." % [
				2 + rank_bonus, 1 + rank_bonus,
				3 + rank_bonus, 2 + rank_bonus, 1 + rank_bonus,
				4 + rank_bonus, 3 + rank_bonus, 2 + rank_bonus, 2 + rank_bonus
			],
			"can_activate": true,
		})
	if is_fx_skill_selected(character, "Haunt"):
		var score := fx_skill_score(character, "Haunt")
		forms.append({
			"name": "Haunt",
			"skill_name": "Haunt",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Supernatural Ward / Distraction",
			"range": "5m radius",
			"duration": "1 scene",
			"benefit": "Opponents suffer +1/+2/+3 step penalty within 5m/10m/20m radius.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Knit wounds"):
		var score := fx_skill_score(character, "Knit wounds")
		var rank := fx_skill_rank(character, "Knit wounds")
		var heal_desc := "Heals wound damage: Ord 2w, Good 3w, Amazing 4w."
		if rank >= 6:
			heal_desc = "Heals mortal/wound damage: Ord 2w, Good 3w or 1m, Amazing 4w or 2m."
		forms.append({
			"name": "Knit Wounds",
			"skill_name": "Knit wounds",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Necromantic Healing",
			"range": "Touch",
			"duration": "Instantaneous",
			"benefit": heal_desc,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Black warding"):
		var score := fx_skill_score(character, "Black warding")
		var rank := fx_skill_rank(character, "Black warding")
		var bonus := 2
		if rank >= 12:
			bonus = 5
		elif rank >= 8:
			bonus = 4
		elif rank >= 4:
			bonus = 3
		forms.append({
			"name": "Black Warding",
			"skill_name": "Black warding",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Protective Ward",
			"range": "Self",
			"duration": "1 scene",
			"benefit": "+%d resistance modifier against all incoming attacks (melee, ranged, psionic, FX)." % bonus,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Binding"):
		var score := fx_skill_score(character, "Binding")
		var rank := fx_skill_rank(character, "Binding")
		var dur_bonus := 0
		if rank >= 12:
			dur_bonus = 3
		elif rank >= 8:
			dur_bonus = 2
		elif rank >= 4:
			dur_bonus = 1
		forms.append({
			"name": "Binding",
			"skill_name": "Binding",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Planar Entanglement",
			"range": "Touch / Magic Circle",
			"duration": "%d round%s + scene" % [1 + dur_bonus, "s" if dur_bonus > 0 else ""],
			"benefit": "Restrains and incapacitates extraplanar entities; binding durability bonus +%d." % dur_bonus,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Rend the weave"):
		var score := fx_skill_score(character, "Rend the weave")
		forms.append({
			"name": "Rend the Weave",
			"skill_name": "Rend the weave",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Supernatural Dispel",
			"range": "10m",
			"duration": "Instantaneous",
			"benefit": "Dispels active FX spells and miracles with caster rank contest.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Reciprocity"):
		var score := fx_skill_score(character, "Reciprocity")
		var rank := fx_skill_rank(character, "Reciprocity")
		var rds := 2
		if rank >= 9:
			rds = 16
		elif rank >= 6:
			rds = 8
		elif rank >= 3:
			rds = 4
		forms.append({
			"name": "Reciprocity",
			"skill_name": "Reciprocity",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Retaliatory Feedback",
			"range": "Self",
			"duration": "%d rounds" % rds,
			"benefit": "Mirrors all damage taken back to the attacker, completely bypassing target armor.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Lifeblood"):
		var score := fx_skill_score(character, "Lifeblood")
		var rank := fx_skill_rank(character, "Lifeblood")
		var heal_str := "Heals wound damage: Ord 2w, Good 3w, Amazing 4w."
		if rank >= 6:
			heal_str = "Heals mortal/wound damage: Ord 2w, Good 3w or 1m, Amazing 4w or 2m."
		forms.append({
			"name": "Lifeblood",
			"skill_name": "Lifeblood",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Hemomantic Healing",
			"range": "Touch",
			"duration": "Instantaneous",
			"benefit": heal_str,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Daedalus improved"):
		var score := fx_skill_score(character, "Daedalus improved")
		var rank := fx_skill_rank(character, "Daedalus improved")
		var mult := 1
		if rank >= 12:
			mult = 4
		elif rank >= 8:
			mult = 3
		elif rank >= 4:
			mult = 2
		forms.append({
			"name": "Daedalus Improved",
			"skill_name": "Daedalus improved",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Hermetic Flight",
			"range": "Self",
			"duration": "1 scene",
			"benefit": "Grants flight speed: Ord %dm, Good %dm, Amazing %dm per phase." % [10 * mult, 20 * mult, 30 * mult],
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Ligature"):
		var score := fx_skill_score(character, "Ligature")
		var rank := fx_skill_rank(character, "Ligature")
		var bonus := 0
		if rank >= 12:
			bonus = 3
		elif rank >= 8:
			bonus = 2
		elif rank >= 4:
			bonus = 1
		forms.append({
			"name": "Ligature",
			"skill_name": "Ligature",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Restraining Threads",
			"range": "10m",
			"duration": "%d round%s" % [1 + bonus, "s" if bonus > 0 else ""],
			"benefit": "Binds target limbs with invisible fibers; durability bonus +%d." % bonus,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Sleep of Morpheus"):
		var score := fx_skill_score(character, "Sleep of Morpheus")
		forms.append({
			"name": "Sleep of Morpheus",
			"skill_name": "Sleep of Morpheus",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Alchemical Slumber",
			"range": "10m",
			"duration": "Ord 1d4 hrs, Good 1d6 hrs, Amazing 24 hrs",
			"benefit": "Target falls into deep enchanted slumber; resists with Willpower.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Shapechanging"):
		var score := fx_skill_score(character, "Shapechanging")
		forms.append({
			"name": "Shapechanging",
			"skill_name": "Shapechanging",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Beast Form",
			"range": "Self",
			"duration": "1 scene",
			"benefit": "Transforms into animal form, gaining natural attacks, enhanced senses, and bonus durability.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Cloak of the phoenix"):
		var score := fx_skill_score(character, "Cloak of the phoenix")
		var rank := fx_skill_rank(character, "Cloak of the phoenix")
		var armor_str := "d4 (LI/HI/En)"
		if rank >= 12:
			armor_str = "d6+1 (LI/HI), d6+2 (En)"
		elif rank >= 4:
			armor_str = "d4+1 (LI/HI), d4+2 (En)"
		var retal_str := "d4 (En/O)" if rank < 8 else "d6 (En/O)"
		forms.append({
			"name": "Cloak of the Phoenix",
			"skill_name": "Cloak of the phoenix",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Flame Armor",
			"range": "Self",
			"duration": "1 scene",
			"benefit": "Absorbs damage (%s) and retaliates with %s fire damage to melee attackers." % [armor_str, retal_str],
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Fire wall"):
		var score := fx_skill_score(character, "Fire wall")
		var rank := fx_skill_rank(character, "Fire wall")
		var bonus_sqm := 0
		if rank >= 12:
			bonus_sqm = 30
		elif rank >= 8:
			bonus_sqm = 20
		elif rank >= 4:
			bonus_sqm = 10
		forms.append({
			"name": "Fire Wall",
			"skill_name": "Fire wall",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Area Denial / Barrier",
			"range": "30m",
			"duration": "1 scene",
			"benefit": "Impassable wall of fire (%d sq meters); inflicts d6+2w fire damage to any entering." % [10 + bonus_sqm],
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Aura"):
		var score := fx_skill_score(character, "Aura")
		var rank := fx_skill_rank(character, "Aura")
		var dmg_str := ""
		if rank >= 12:
			dmg_str = " (inflicts d14w on infernal touch)"
		elif rank >= 8:
			dmg_str = " (inflicts d8w on infernal touch)"
		elif rank >= 4:
			dmg_str = " (inflicts d4w on infernal touch)"
		forms.append({
			"name": "Aura",
			"skill_name": "Aura",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Divine Aura",
			"range": "Self",
			"duration": "1 scene",
			"benefit": "+2 resistance modifier against all attacks; shifts onlooker attitudes toward Fanatic%s." % dmg_str,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Blessing"):
		var score := fx_skill_score(character, "Blessing")
		var rank := fx_skill_rank(character, "Blessing")
		var bonus_step := 1 if rank < 4 else 2
		var range_str := "10m radius"
		if rank >= 12:
			range_str = "Line of sight"
		elif rank >= 8:
			range_str = "100m radius"
		forms.append({
			"name": "Blessing",
			"skill_name": "Blessing",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Divine Favor",
			"range": range_str,
			"duration": "1 scene",
			"benefit": "Allies gain -%d step bonus to all checks and +%d resistance modifier." % [bonus_step, bonus_step],
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Cure"):
		var score := fx_skill_score(character, "Cure")
		var rank := fx_skill_rank(character, "Cure")
		var cure_str := "Neutralizes poisons, toxins, and restores health."
		if rank >= 6:
			cure_str = "Neutralizes poisons, toxins, diseases, and supernatural afflictions."
		forms.append({
			"name": "Cure",
			"skill_name": "Cure",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Miraculous Restoration",
			"range": "Touch",
			"duration": "Instantaneous",
			"benefit": cure_str,
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Demon ward"):
		var score := fx_skill_score(character, "Demon ward")
		var rank := fx_skill_rank(character, "Demon ward")
		var rad := 5
		if rank >= 12:
			rad = 30
		elif rank >= 8:
			rad = 20
		elif rank >= 4:
			rad = 10
		forms.append({
			"name": "Demon Ward",
			"skill_name": "Demon ward",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Sanctuary Barrier",
			"range": "%dm radius" % rad,
			"duration": "1 scene",
			"benefit": "Prevents demons, undead, and infernal creatures from crossing the perimeter.",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Body Armor"):
		var score := fx_skill_score(character, "Body Armor")
		forms.append({
			"name": "Body Armor",
			"skill_name": "Body Armor",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Dermal Density",
			"range": "Self (Permanent)",
			"duration": "Permanent",
			"benefit": "Passive dermal armor absorption without bulk penalties (absorption dice scale with rank).",
			"can_activate": false,
		})
	if is_fx_skill_selected(character, "Life Support"):
		var score := fx_skill_score(character, "Life Support")
		var rank := fx_skill_rank(character, "Life Support")
		var dur_str := "24 hours"
		if rank >= 12:
			dur_str = "27 days"
		elif rank >= 8:
			dur_str = "9 days"
		elif rank >= 4:
			dur_str = "72 hours (3 days)"
		forms.append({
			"name": "Life Support",
			"skill_name": "Life Support",
			"score": "%d / %d / %d" % [score.get("ordinary", 0), score.get("good", 0), score.get("amazing", 0)],
			"base_die": _get_parent().action_step_die(AlternityNum.as_int(score.get("step", 0))),
			"kind": "Environmental Immunity",
			"range": "Self",
			"duration": dur_str,
			"benefit": "Complete immunity to vacuum, extreme pressure, toxic environments, radiation, and drowning.",
			"can_activate": false,
		})
	return forms
