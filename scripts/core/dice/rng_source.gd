class_name RngSource
extends RandomSource
##
## Dice results from a seeded RandomNumberGenerator.
##
## Used wherever there is no physics tray: the rules engine rolling on mutation
## tables, and every headless test. Seeding is what makes those tests able to
## assert exact outcomes.
##
## The project previously used the global randi_range() with no randomize()
## anywhere, from five call sites in alternity_rules_mutations.gd. That is
## unseeded and unownable -- nothing could reproduce a generated mutant, and
## nothing could test one.
##

var _rng := RandomNumberGenerator.new()


## seed_value < 0 randomizes, which is what normal play wants. Any other value
## makes the sequence reproducible, which is what tests want.
func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


## The seed in use, recorded on every result so a roll can be reproduced.
func get_seed() -> int:
	return _rng.seed


func roll(term: Dictionary, label: String = "") -> RollResult:
	var result := RollResult.new()
	result.notation = DiceNotation.format(term)
	result.modifier = AlternityNum.as_int(term.get("modifier", 0))
	result.sign = AlternityNum.as_int(term.get("sign", 1), 1)
	result.damage_type = String(term.get("damage_type", ""))
	result.source = RollResult.SOURCE_RNG
	result.seed_used = int(_rng.seed)
	result.timestamp = int(Time.get_unix_time_from_system())
	result.label = label

	var count: int = AlternityNum.as_int(term.get("count", 0))
	var sides: int = AlternityNum.as_int(term.get("sides", 0))

	# "+d0" is real notation meaning no die is rolled -- guard before calling
	# randi_range(1, 0), which would be an invalid range.
	var faces: Array[int] = []
	if sides > 0:
		for _i in count:
			faces.append(_rng.randi_range(1, sides))
	result.dice = faces

	result.recompute_total()
	return result
