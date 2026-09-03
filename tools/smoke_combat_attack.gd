extends "res://tools/test_harness.gd"
##
## An attack, from the GM declaring it to the target's sheet.
##
## The division of labour is the point, and it is what the assertions are really
## about: the GM decides whether it hit and for how much, and the target's own
## device decides what that cost. Neither can do the other's half, and the test
## resolves an attack the long way -- armor layers, apply_damage, knockout check
## -- to prove the pieces fit.
##

const Attack := preload("res://scripts/core/session/combat_attack.gd")
const RulesScript := preload("res://scripts/alternity_rules.gd")

var _rules
var _combat


func _init() -> void:
	begin("combat attack")

	_rules = RulesScript.new()
	_rules.load_core_data()
	_combat = _rules.combat

	_test_weapon_classification()
	_test_damage_entries()
	_test_declaring()
	_test_round_trip()
	_test_resolving_against_a_sheet()
	_test_describing()

	finish()


func _hero(con: int = 12) -> Dictionary:
	var character := {}
	_rules.ensure_character_shape(character)
	character["abilities"]["CON"] = con
	return character


# --- What kind of weapon is it ---------------------------------------------

## The skill used to fire a weapon is its classification for the range table.
func _test_weapon_classification() -> void:
	check_eq(_combat.weapon_range_class(31), "pistol", "the Pistol skill fires a pistol")
	check_eq(_combat.weapon_range_class(32), "rifle", "the Rifle skill fires a rifle")
	check_eq(_combat.weapon_range_class(33), "smg", "the SMG skill fires an SMG")
	check_eq(_combat.weapon_range_class(34), "primitive", "Primitive Ranged Weapons is primitive")
	check_eq(_combat.weapon_range_class(8), "heavy_direct", "Heavy Weapons is a heavy weapon")

	# Melee and unarmed have no range band at all, which is a caller's cue to use
	# the melee modifier table instead of asking for one.
	check_eq(_combat.weapon_range_class(11), "", "Melee Weapons has no range class")
	check_eq(_combat.weapon_range_class(15), "", "nor does Unarmed Attack")
	check_false(_combat.is_ranged_weapon(11), "so a sword is not a ranged weapon")
	check_true(_combat.is_ranged_weapon(32), "and a rifle is")

	# The classification has to reach the right row of the range table.
	check_eq(
		_rules.range_step_for(_combat.weapon_range_class(31), "long"), 3,
		"a pistol at long range is +3"
	)
	check_eq(
		_rules.range_step_for(_combat.weapon_range_class(32), "long"), 1,
		"and a rifle at the same band is +1"
	)


# --- The damage triple -----------------------------------------------------

## The degree picks which entry to roll; it is not one roll scaled afterwards.
func _test_damage_entries() -> void:
	var entries: Dictionary = _combat.damage_entries("d4+1w/d4+2w/d4m")
	check_eq(String(entries["ordinary"]), "d4+1w", "an ordinary hit rolls the first entry")
	check_eq(String(entries["good"]), "d4+2w", "a good hit the second")
	check_eq(String(entries["amazing"]), "d4m", "and an amazing hit the third")

	check_eq(_combat.damage_entry_for("d4+1w/d4+2w/d4m", "good"), "d4+2w", "picking by degree")
	check_eq(_combat.damage_entry_for("d4+1w/d4+2w/d4m", "amazing"), "d4m", "and again")
	check_eq(
		_combat.damage_entry_for("d4+1w/d4+2w/d4m", "failure"), "d4+1w",
		"an unknown degree falls back rather than returning nothing"
	)

	# A weapon written with fewer entries repeats its last, so there is always
	# something to roll.
	var sparse: Dictionary = _combat.damage_entries("d6s")
	check_eq(String(sparse["amazing"]), "d6s", "a single entry covers every degree")
	check_eq(_combat.damage_entries("").get("ordinary", "x"), "", "and nothing yields nothing")

	# The track is the suffix.
	check_eq(_combat.damage_track_of("d4+2w"), "w", "a w suffix is wound damage")
	check_eq(_combat.damage_track_of("d6m"), "m", "an m suffix is mortal")
	check_eq(_combat.damage_track_of("d4s"), "s", "an s suffix is stun")
	check_eq(_combat.damage_track_of("d4+1"), "s", "and no suffix is stun -- an unarmed hit does not kill")


# --- Declaring --------------------------------------------------------------

func _test_declaring() -> void:
	var attack := Attack.declare("player-1", "A thug", "Charge pistol", "Good", 7, "w", "hi", "O")
	check_eq(attack.target_player_id, "player-1", "it names the seat it lands on")
	check_eq(attack.attacker_name, "A thug", "and who swung")
	check_true(attack.hits(), "a Good hit lands")
	check_false(attack.is_amazing(), "but is not Amazing")
	check_eq(attack.track_name(), "wound", "and marks the wound track")
	check_false(attack.is_resolved(), "and nothing has been applied yet")

	check_true(Attack.declare("p", "x", "y", "Amazing", 1, "m", "en", "A").is_amazing(), "an Amazing hit says so")

	# A miss still travels: the target should be told they were shot at, and the
	# log should say so. It simply has nothing to apply.
	var missed := Attack.declare("player-1", "A thug", "Charge pistol", "Failure", 0, "w", "hi", "O")
	check_false(missed.hits(), "a failure does not land")
	check_false(Attack.declare("p", "x", "y", "Critical Failure", 0, "w", "hi", "O").hits(), "nor a fumble")
	check_false(Attack.declare("p", "x", "y", "Marginal", 3, "w", "hi", "O").hits(), "nor a marginal result")

	# The awareness flags travel with the attack because only the GM knows them.
	attack.sees_attacker = false
	check_false(attack.sees_attacker, "whether they saw it coming is carried on the attack")


func _test_round_trip() -> void:
	var attack := Attack.declare("player-9", "A thug", "Charge pistol", "Good", 7, "w", "hi", "G")
	attack.is_melee = false
	attack.from_rear = true
	attack.resolve({"primary_damage": 5, "absorbed": 2, "knocked_out": false})

	var restored := Attack.from_dict(JSON.parse_string(JSON.stringify(attack.to_dict())))
	check_eq(restored.attack_id, attack.attack_id, "the id survives")
	check_eq(restored.target_player_id, "player-9", "the target survives")
	check_eq(restored.degree, "Good", "the degree survives")
	check_eq(restored.damage, 7, "the damage survives")
	check_eq(restored.damage_type, "w", "the track survives")
	check_eq(restored.impact_type, "hi", "the impact type survives, which picks the armor")
	check_eq(restored.firepower, "G", "and the firepower grade, which decides degradation")
	check_true(restored.from_rear, "the awareness flags survive")
	check_true(restored.is_resolved(), "and so does the fact it was resolved")
	check_eq(AlternityNum.as_int(restored.result.get("primary_damage", 0)), 5, "with what got through")

	var empty := Attack.from_dict({})
	check_false(empty.attack_id.is_empty(), "a malformed attack still has an id")
	check_false(empty.hits(), "and has not hit anything")
	var junk := Attack.from_dict({"result": "not a dictionary", "damage": "seven"})
	check_eq(junk.result.size(), 0, "a malformed result is ignored")
	check_eq(junk.damage, 0, "and malformed damage is nothing")


# --- The target's half ------------------------------------------------------

## Resolving an attack the long way, as the player's device does it.
##
## Armor layers, then the damage pipeline, then the knockout check. The point is
## that each piece is the engine's own and nothing here re-implements a rule.
func _test_resolving_against_a_sheet() -> void:
	var hero := _hero(12)
	var attack := Attack.declare("player-1", "A thug", "Charge pistol", "Good", 6, "w", "hi", "O")

	# The armor the attack has to get through, chosen by its impact type.
	var layers: Array = _combat.armor_layers(hero, attack.impact_type)
	check_true(typeof(layers) == TYPE_ARRAY, "the target works out its own armor layers")
	# An unarmored hero soaks nothing, and that is a number rather than an error.
	var soaked: int = _combat.best_absorption([])
	check_eq(soaked, 0, "with nothing to soak it")

	var before := AlternityNum.as_int(hero["damage"].get("wound", 0))
	var outcome: Dictionary = _rules.apply_damage(
		hero, attack.damage, attack.track_name(), soaked, attack.firepower, "O"
	)
	check_eq(String(outcome.get("damage_type", "")), "wound", "an Ordinary weapon against Ordinary toughness is undegraded")
	check_eq(AlternityNum.as_int(outcome.get("primary_damage", 0)), 6, "and all six points get through")
	check_eq(
		AlternityNum.as_int(hero["damage"]["wound"]), before + 6,
		"landing on the target's own sheet"
	)
	# Secondary damage is derived from what got through, not from the raw roll.
	check_eq(AlternityNum.as_int(outcome.get("secondary_stun", 0)), 3, "with secondary stun from the wound")

	# A Good hit forces no endurance check; an Amazing one does.
	check_false(
		bool(_rules.amazing_damage_knockout(hero, attack.degree).get("required", false)),
		"a Good hit forces no knockout check"
	)
	check_true(
		bool(_rules.amazing_damage_knockout(hero, "amazing").get("required", false)),
		"an Amazing one does"
	)

	attack.resolve({
		"primary_damage": AlternityNum.as_int(outcome.get("primary_damage", 0)),
		"absorbed": soaked,
		"negated": bool(outcome.get("negated", false)),
		"knocked_out": _combat.is_knocked_out(hero),
		"condition": _combat.condition_of(hero),
	})
	check_true(attack.is_resolved(), "and the attack comes back resolved")
	check_eq(String(attack.result.get("condition", "")), _combat.condition_of(hero), "saying how they are now")

	# A weapon too weak for its target is stopped entirely, and the target still
	# reports back -- silence would leave the GM waiting.
	var armored := _hero(12)
	var weak := Attack.declare("player-1", "A thug", "Club", "Ordinary", 4, "s", "li", "O")
	var stopped: Dictionary = _rules.apply_damage(armored, weak.damage, weak.track_name(), 0, "O", "A")
	check_true(bool(stopped.get("negated", false)), "an Ordinary weapon against Amazing toughness is negated")
	check_eq(AlternityNum.as_int(armored["damage"].get("stun", 0)), 0, "and marks nothing")


func _test_describing() -> void:
	var missed := Attack.declare("p", "A thug", "Charge pistol", "Failure", 0, "w", "hi", "O")
	check_true(missed.describe().contains("missed"), "a miss reads as a miss")

	var hit := Attack.declare("p", "A thug", "Charge pistol", "Good", 7, "w", "hi", "O")
	check_true(hit.describe().contains("A thug"), "a hit names the attacker")
	check_true(hit.describe().contains("Charge pistol"), "and the weapon")
	check_true(hit.describe().contains("wound"), "and the track")

	hit.resolve({"primary_damage": 5, "absorbed": 2, "knocked_out": false})
	check_true(hit.describe().contains("soaked 2"), "once resolved it says what the armor stopped")
	check_true(hit.describe().contains("5 got through"), "and what got through")

	var dropped := Attack.declare("p", "A thug", "Rifle", "Amazing", 12, "m", "hi", "G")
	dropped.resolve({"primary_damage": 12, "absorbed": 0, "knocked_out": true})
	check_true(dropped.describe().contains("went down"), "and says when somebody went down")

	var stopped := Attack.declare("p", "A thug", "Club", "Ordinary", 4, "s", "li", "O")
	stopped.resolve({"primary_damage": 0, "absorbed": 0, "negated": true})
	check_true(stopped.describe().contains("stopped entirely"), "a negated hit says so plainly")
