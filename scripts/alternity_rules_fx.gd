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

func is_fx_talent(character: Dictionary) -> bool:
	return bool(character.get("fx", {}).get("is_fx_talent", false))

func set_fx_talent(character: Dictionary, enabled: bool) -> void:
	_normalize_fx(character)
	character["fx"]["is_fx_talent"] = enabled

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
		return AlternityRules.DARK_MATTER_FX_STARTING_POOL
	return AlternityNum.as_int(character.get("fx", {}).get("energy_pool", 0))

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

func add_fx_skill(character: Dictionary, skill_name: String) -> void:
	_normalize_fx(character)
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		character["fx"]["selected_skills"][skill_name] = 1
		return
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var current = fx_skill_rank(character, skill_name)
		# A specialty stops at rank 12 like every other specialty in the game.
		# Nothing capped this, so repeated buys walked straight past it.
		character["fx"]["selected_skills"][skill_name] = mini(
			current + 1, AlternityRules.MAX_SPECIALTY_RANK
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
## Powers outside the primary school cost double, so a stale value here silently
## doubles the price of everything. A real saved character had this set to
## Alienism while owning Brick, Druidism and Taoism -- so every power in a school
## they did own was charged at twice its price, and nothing in the app could set
## or clear the field to fix it.
##
## A primary school the hero does not have is treated as unset: the surcharge is
## defined relative to a school you actually practise.
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
	if not is_fx_talent(character):
		return false
	if not primary_broad_group(character).is_empty():
		return false
	for broad in get_broad_skills_for_character(character):
		if is_fx_skill_selected(character, String(broad.get("name", ""))):
			return true
	return false


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

## What a Dark*Matter FX talent pays above the listed price.
##
## "FX Talents must pay 1 point more than the listed cost for all FX broad and
## specialty skills." It is the same shape as the psionic talent surcharge and
## for the same reason: in Dark*Matter nobody has the profession that would make
## them a full practitioner, so everybody is a talent and everybody pays it.
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
	var surcharge := _talent_surcharge(character)
	var broad = get_broad_skill(skill_name)
	if not broad.is_empty():
		return _listed_cost(character, broad) + surcharge if rank == 1 else 0
	var specialty = get_specialty_skill(skill_name)
	if not specialty.is_empty():
		var base_cost = _listed_cost(character, specialty) + surcharge
		var primary_group := primary_broad_group(character)
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
	step += _get_parent().dazed_penalty(character)

	return {
		"marginal": ordinary + 1,
		"ordinary": ordinary,
		"good": good,
		"amazing": amazing,
		"base": ability_score,
		"step": step,
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
