class_name PhysicalDiceSource
extends RandomSource
##
## Dice results read off a tray where the dice actually tumbled.
##
## The other half of RandomSource, and the one AGENTS.md calls authoritative. The
## faces are read from where the dice settle; nothing here decides an outcome
## first and plays an animation over it. `seed_used` stays -1 because a physical
## roll is not reproducible from a seed and must never be presented as though it
## were.
##
## roll() is a coroutine -- it awaits the dice stopping. RandomSource documents
## that callers should `await` the return value, and awaiting a non-coroutine is
## a no-op in GDScript, so the same call site serves this and RngSource.
##
## An action check throws two dice at once: the control d20 and whatever the step
## total came to. That is one throw at a real table, not two, which is what
## roll_group() exists for -- the dice collide with each other on the way down,
## and those collisions are part of what decides the result.
##

var _tray: DiceTray


func _init(tray: DiceTray) -> void:
	_tray = tray


## One notation term. See RandomSource.
func roll(term: Dictionary, label: String = "") -> RollResult:
	var results: Array = await roll_group([term], label)
	return results[0] if not results.is_empty() else _empty_result(term, label)


## Several terms in a single throw, resolved together.
##
## Returns one RollResult per term, in the order given. All of them share the
## throw's reroll count, because a cocked die voided the whole throw and not just
## its own die.
func roll_group(terms: Array, label: String = "") -> Array:
	var results: Array = []
	if _tray == null:
		for term in terms:
			results.append(_empty_result(term, label))
		return results

	# One entry per physical die. A term of "2d20" puts two d20s on the tray.
	var sides_list: Array = []
	var spans: Array = []
	for term in terms:
		var count: int = AlternityNum.as_int(term.get("count", 0))
		var sides: int = AlternityNum.as_int(term.get("sides", 0))
		var start: int = sides_list.size()
		# "+d0" is real notation meaning no die is thrown, and a shape this build
		# cannot make is treated the same way -- the term still resolves, it just
		# contributes only its modifier.
		if sides > 0 and DieShape.is_supported(sides):
			for _i in count:
				sides_list.append(sides)
		spans.append({"start": start, "count": sides_list.size() - start})

	if sides_list.is_empty():
		for term in terms:
			results.append(_empty_result(term, label))
		return results

	if not _tray.throw(sides_list):
		for term in terms:
			results.append(_empty_result(term, label))
		return results

	var outcome: Array = await _tray.settled
	var faces: Array = outcome[0]
	var rerolls: int = AlternityNum.as_int(outcome[1])

	for i in terms.size():
		var term: Dictionary = terms[i]
		var span: Dictionary = spans[i]
		var result := _empty_result(term, label)
		result.rerolls = rerolls

		var mine: Array[int] = []
		for j in range(AlternityNum.as_int(span["start"]), AlternityNum.as_int(span["start"]) + AlternityNum.as_int(span["count"])):
			if j < faces.size():
				mine.append(AlternityNum.as_int(faces[j].get("number", 1), 1))
		result.dice = mine
		result.recompute_total()
		results.append(result)

	return results


func _empty_result(term: Dictionary, label: String) -> RollResult:
	var result := RollResult.new()
	result.notation = DiceNotation.format(term)
	result.modifier = AlternityNum.as_int(term.get("modifier", 0))
	result.sign = AlternityNum.as_int(term.get("sign", 1), 1)
	result.damage_type = String(term.get("damage_type", ""))
	result.source = RollResult.SOURCE_PHYSICAL
	# Not reproducible, and saying so is the point. A seed recorded here would
	# invite someone to try replaying a roll that was decided by collisions.
	result.seed_used = -1
	result.timestamp = int(Time.get_unix_time_from_system())
	result.label = label
	result.dice = [] as Array[int]
	result.recompute_total()
	return result
