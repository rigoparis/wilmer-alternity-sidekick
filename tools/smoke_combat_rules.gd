extends "res://tools/test_harness.gd"
##
## Defence, weapon failures, death, recovery and blasts.
##
## The rules a fight needs once the dice have stopped. Several of these decide
## whether a character lives, so the cases that matter most are the boundaries:
## the last mortal box, a parry that exactly matches the attack, a dodge that
## went wrong, and the outer edge of a blast.
##
## Sourced through a reading assistant rather than verified page by page, so
## each group notes what it is asserting and why -- a later reader should be able
## to tell which claims to re-check first.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

var _rules
var _combat


func _init() -> void:
	begin("combat rules")

	_rules = RulesScript.new()
	_rules.load_core_data()
	_combat = _rules.combat

	_test_armor_layers()
	_test_toughness()
	_test_resistance()
	_test_awareness()
	_test_dodge()
	_test_parry()
	_test_weapon_failures()
	_test_death_and_dying()
	_test_condition()
	_test_end_of_scene()
	_test_recovery()
	_test_last_resort()
	_test_blasts()

	finish()


func _hero(con: int = 10, dex: int = 10, str_score: int = 10) -> Dictionary:
	var character := {}
	_rules.ensure_character_shape(character)
	character["abilities"]["CON"] = con
	character["abilities"]["DEX"] = dex
	character["abilities"]["STR"] = str_score
	return character


# --- Armor -----------------------------------------------------------------

## Layers do not add up: roll them all, keep the best.
##
## The rule that makes wearing three kinds of armor pointless as protection --
## and still costly, because the penalties do stack.
func _test_armor_layers() -> void:
	check_eq(_combat.best_absorption([2, 5, 3]), 5, "the best layer is the one that counts")
	check_eq(_combat.best_absorption([5]), 5, "one layer is its own best")
	check_eq(_combat.best_absorption([]), 0, "no armor absorbs nothing")
	# A d4-2 that rolled a 1 absorbs nothing rather than adding damage.
	check_eq(_combat.best_absorption([-1, -3]), 0, "a negative roll absorbs nothing")
	check_eq(_combat.best_absorption([-1, 2]), 2, "and does not drag a good layer down")

	# A T'sa has a natural hide, which is a layer like any other -- it is not
	# worn, and it still competes for "best" alongside anything that is.
	var tsa := _hero(10)
	for candidate in _rules.species:
		if String(candidate.get("name", "")) == "T'sa":
			tsa["species_id"] = AlternityNum.as_int(candidate.get("id", 0))
	var hide: Array = _combat.armor_layers(tsa, "li")
	check_true(hide.size() > 0, "a T'sa's natural hide is an armor layer")
	if hide.size() > 0:
		check_false(String(hide[0]["notation"]).is_empty(), "with dice to roll")

	# The attack decides which rating answers it, not the armor.
	var bare := _hero(10)
	for impact in ["li", "hi", "en"]:
		var layers: Array = _combat.armor_layers(bare, impact)
		check_true(typeof(layers) == TYPE_ARRAY, "an unarmored hero has a layer list for %s" % impact)
	check_eq(_combat.armor_layers(bare, "plasma").size(), 0, "an unknown impact type matches no rating")
	check_eq(_combat.armor_layers(bare, "").size(), 0, "and neither does none at all")
	check_eq(_combat.armor_layers(bare, "hi").size(), 0, "and a hero in a shirt has nothing to roll")

	# Worn armor, which is where most absorption comes from and which writes its
	# ratings in a different place from a natural hide.
	var suited := _hero(10)
	var line: String = _rules.equipment.add_equipment_to_character(suited, "armor_core_002")
	check_false(line.is_empty(), "battle armor is in the catalogue")
	var carried_only: Array = _combat.armor_layers(suited, "hi")
	check_eq(carried_only.size(), 0, "armor in a backpack absorbs nothing")

	_rules.equipment.update_carried_equipment(suited, line, 1, true, "Body", "")
	var worn: Array = _combat.armor_layers(suited, "hi")
	check_eq(worn.size(), 1, "wearing it makes it a layer")
	if worn.size() > 0:
		check_eq(String(worn[0]["notation"]), "d6+1", "with the rating the attack asked for")
		check_eq(String(worn[0]["name"]), "Attack armor", "and the name of what stopped it")
	var energy: Array = _combat.armor_layers(suited, "en")
	check_eq(String(energy[0]["notation"]) if energy.size() > 0 else "", "d6-1", "a different attack reads a different rating")


## What a weapon is compared against, which is a property of what they wear.
func _test_toughness() -> void:
	check_eq(_combat.toughness_of(_hero(10)), "O", "an unarmored person is Ordinary toughness")

	var suited := _hero(10)
	var line: String = _rules.equipment.add_equipment_to_character(suited, "armor_core_001")
	_rules.equipment.update_carried_equipment(suited, line, 1, true, "Body", "")
	check_eq(_combat.toughness_of(suited), "G", "powered attack armor is Good toughness")

	# Which is the whole point of it: an Ordinary weapon can no longer wound.
	check_eq(
		_rules.degrade_damage_grade("wound", "O", _combat.toughness_of(suited)), "stun",
		"so an Ordinary weapon only stuns them"
	)
	check_eq(
		_rules.degrade_damage_grade("wound", "G", _combat.toughness_of(suited)), "wound",
		"and a Good one wounds as normal"
	)

	# The best layer answers, the same way the best absorption does.
	var layered := _hero(10)
	var soft: String = _rules.equipment.add_equipment_to_character(layered, "armor_core_002")
	var hard: String = _rules.equipment.add_equipment_to_character(layered, "armor_core_001")
	_rules.equipment.update_carried_equipment(layered, soft, 1, true, "Body", "")
	_rules.equipment.update_carried_equipment(layered, hard, 1, true, "Over", "")
	check_eq(_combat.toughness_of(layered), "G", "the best toughness worn is the one that answers")


# --- Defence ---------------------------------------------------------------

## The target's own body, as a step on the attacker's roll.
func _test_resistance() -> void:
	var nimble := _hero(10, 14, 8)

	var ranged: int = _combat.resistance_step(nimble, false)
	var melee: int = _combat.resistance_step(nimble, true)
	check_eq(
		ranged, _rules.character_resistance_modifier(nimble, "DEX"),
		"a ranged attack is resisted by Dexterity"
	)
	check_eq(
		melee, _rules.character_resistance_modifier(nimble, "STR"),
		"and a melee attack by Strength"
	)
	check_true(ranged > melee, "so a nimble, weak target is harder to shoot than to hit")

	# The part that makes surprise and a rear attack worth so much more than
	# their step bonuses suggest: a target who cannot react is not resisting.
	check_eq(_combat.resistance_step(nimble, false, false), 0, "an unaware target resists nothing")
	check_eq(_combat.resistance_step(nimble, true, false), 0, "with a club either")
	check_false(_combat.can_defend(false), "and cannot dodge or parry")
	check_true(_combat.can_defend(true), "while an aware one can")


## Awareness is three situations that look alike and are not.
func _test_awareness() -> void:
	var target := _hero(10, 14, 8)
	var resisting: int = _rules.character_resistance_modifier(target, "DEX")

	var normal: Dictionary = _combat.target_defence(target, false)
	check_eq(AlternityNum.as_int(normal["resistance_step"]), resisting, "a ready target resists")
	check_true(bool(normal["can_dodge"]), "and can dodge")
	check_true(bool(normal["can_parry"]), "and parry")

	# Never saw it coming: nothing at all.
	var ambushed: Dictionary = _combat.target_defence(target, false, false)
	check_eq(AlternityNum.as_int(ambushed["resistance_step"]), 0, "an unseen attacker is unresisted")
	check_false(bool(ambushed["can_dodge"]), "and cannot be dodged")
	check_false(bool(ambushed["can_parry"]), "or parried")

	# From behind is not the same thing. They know there is a fight; they just
	# cannot turn to meet this one.
	var behind: Dictionary = _combat.target_defence(target, false, true, true)
	check_eq(
		AlternityNum.as_int(behind["resistance_step"]), resisting,
		"a rear attack is still resisted -- being attacked from behind is not being unaware"
	)
	check_false(bool(behind["can_dodge"]), "but cannot be dodged")
	check_false(bool(behind["can_parry"]), "or parried")

	# Pinned is the one restraint that takes everything away.
	var pinned: Dictionary = _combat.target_defence(target, true, true, false, true)
	check_eq(AlternityNum.as_int(pinned["resistance_step"]), 0, "a pinned target resists nothing")
	check_false(bool(pinned["can_dodge"]), "and cannot dodge")
	check_true(String(pinned["reason"]).to_lower().contains("pinned"), "and the reason says why")

	# Every state that is not one of those leaves the target defending normally.
	check_true(
		bool(_combat.target_defence(target, true)["can_parry"]),
		"prone and held are miserable, not helpless -- they are simply not modelled here"
	)


## A dodge amplifies the dodger's own resistance; it is not an opposed check.
func _test_dodge() -> void:
	check_eq(_combat.dodge_step("amazing"), 3, "an Amazing dodge is +3 against the attacker")
	check_eq(_combat.dodge_step("good"), 2, "a Good dodge is +2")
	check_eq(_combat.dodge_step("ordinary"), 1, "an Ordinary dodge is +1")
	check_eq(_combat.dodge_step("marginal"), 0, "a marginal dodge is worth nothing")
	check_eq(_combat.dodge_step("failure"), 0, "and a failed one is worth nothing")

	# The risk that makes spending the action a decision rather than a habit.
	check_eq(_combat.dodge_step("critical failure"), -2, "a fumbled dodge helps the attacker")
	check_true(_combat.dodge_step("critical failure") < 0, "which is a bonus to them, not a penalty")

	# And it costs more than the action: everything afterwards is worse.
	check_eq(_combat.DODGE_LATER_PENALTY, 1, "a dodge puts +1 step on the rest of the round")

	# Two things in one phase costs accuracy, not a second action -- which is how
	# a character with one action per round does two things at all.
	check_eq(AlternityNum.as_int(_combat.TWO_ACTIONS_STEPS["primary"]), 2, "the first of two costs +2 steps")
	check_eq(AlternityNum.as_int(_combat.TWO_ACTIONS_STEPS["secondary"]), 4, "and the second +4")


## A parry is an opposed comparison of degrees, and blocks completely or not at
## all.
func _test_parry() -> void:
	check_true(_combat.parry_blocks("ordinary", "ordinary"), "an equal parry blocks")
	check_true(_combat.parry_blocks("good", "amazing"), "a better parry blocks")
	check_true(_combat.parry_blocks("ordinary", "amazing"), "and a far better one certainly does")
	check_false(_combat.parry_blocks("amazing", "good"), "a worse parry does not")
	check_false(_combat.parry_blocks("amazing", "ordinary"), "however hard it tried")

	# A parry that missed blocks nothing, however badly the attack was rolled --
	# comparing tiers alone would have a failed parry "beat" a marginal hit.
	check_false(_combat.parry_blocks("marginal", "failure"), "a failed parry blocks nothing")
	check_false(_combat.parry_blocks("marginal", "marginal"), "and neither does a marginal one")
	check_false(_combat.parry_blocks("ordinary", "nonsense"), "an unknown degree blocks nothing")


# --- Critical failures -----------------------------------------------------

func _test_weapon_failures() -> void:
	# Firearms read one column of Table G8 and melee weapons the other.
	check_eq(String(_combat.weapon_failure(1, true)["result"]), "breakage", "a 1 breaks a firearm")
	check_eq(String(_combat.weapon_failure(3, true)["result"]), "dropped", "a 3 drops it")
	check_eq(String(_combat.weapon_failure(6, true)["result"]), "jammed", "a 6 jams it")
	check_eq(String(_combat.weapon_failure(8, true)["result"]), "out_of_ammo", "an 8 empties it")

	# A sword cannot jam or run out of ammunition.
	for roll in range(1, 9):
		var melee_result := String(_combat.weapon_failure(roll, false)["result"])
		check_true(
			melee_result in ["breakage", "dropped"],
			"a melee weapon on a %d only breaks or drops -- got %s" % [roll, melee_result]
		)
	check_eq(String(_combat.weapon_failure(1, false)["result"]), "breakage", "a 1 breaks a melee weapon")
	check_eq(String(_combat.weapon_failure(8, false)["result"]), "dropped", "an 8 drops it")

	# Every result explains itself, because a GM reading "jammed" needs to know
	# what clearing it costs.
	for roll in range(1, 9):
		check_false(
			String(_combat.weapon_failure(roll, true)["detail"]).is_empty(),
			"a firearm failure on %d says what happens next" % roll
		)

	# A roll off the end of the table is clamped rather than falling through to
	# an empty result.
	check_eq(String(_combat.weapon_failure(0, true)["result"]), "breakage", "a roll below the table clamps")
	check_eq(String(_combat.weapon_failure(99, true)["result"]), "out_of_ammo", "and above it")


# --- Death -----------------------------------------------------------------

## The last mortal box is the end. There is no dying state past it.
func _test_death_and_dying() -> void:
	var hero := _hero(12)
	var mortal_max := AlternityNum.as_int(_rules.durability(hero).get("mortal", 0))
	check_true(mortal_max > 0, "the hero has a mortal track")

	check_false(_combat.is_dead(hero), "an unhurt hero is not dead")
	check_false(_combat.is_dying(hero), "nor dying")

	hero["damage"]["mortal"] = 1
	check_true(_combat.is_dying(hero), "one point of mortal damage is dying")
	check_false(_combat.is_dead(hero), "but not dead")

	hero["damage"]["mortal"] = mortal_max - 1
	check_true(_combat.is_dying(hero), "with one box left, still dying")
	check_false(_combat.is_dead(hero), "and still alive")

	hero["damage"]["mortal"] = mortal_max
	check_true(_combat.is_dead(hero), "the last box is death")
	# Dead is not a worse kind of dying -- nothing is going to stabilise them.
	check_false(_combat.is_dying(hero), "and death is not a dying state")

	# Stun filling is unconsciousness, not death.
	var stunned := _hero(12)
	stunned["damage"]["stun"] = AlternityNum.as_int(_rules.durability(stunned).get("stun", 0))
	check_true(_combat.is_knocked_out(stunned), "a full stun track is unconsciousness")
	check_false(_combat.is_dead(stunned), "which is not death")


func _test_condition() -> void:
	var hero := _hero(12)
	check_eq(_combat.condition_of(hero), "Unhurt", "an unhurt hero reads as unhurt")

	hero["damage"]["mortal"] = 1
	check_eq(_combat.condition_of(hero), "Dying", "mortal damage reads as dying")

	# The worse states win: a dying character who is also unconscious is
	# described by the thing a GM needs to act on.
	var down := _hero(12)
	down["damage"]["stun"] = AlternityNum.as_int(_rules.durability(down).get("stun", 0))
	check_eq(_combat.condition_of(down), "Unconscious", "a full stun track reads as unconscious")

	var gone := _hero(12)
	gone["damage"]["mortal"] = AlternityNum.as_int(_rules.durability(gone).get("mortal", 0))
	check_eq(_combat.condition_of(gone), "Dead", "and death outranks everything")

	# Fatigue is a step penalty, so it shows even with no wound on the sheet.
	var tired := _hero(12)
	tired["damage"]["fatigue"] = 2
	check_true(_combat.condition_of(tired).begins_with("Hurt"), "accumulated penalties read as hurt")
	check_true(_combat.condition_of(tired).contains("2"), "and say how many steps")


# --- Recovery --------------------------------------------------------------

## The cadences are wildly different, and a campaign running for months needs
## them right or a hero either never recovers or never suffers.
## Stun comes back all at once when the shooting stops, and takes the
## unconsciousness with it.
func _test_end_of_scene() -> void:
	var hero := _hero(12)
	var stun_max := AlternityNum.as_int(_rules.durability(hero).get("stun", 0))

	check_eq(_combat.end_scene(hero), 0, "an unhurt hero has nothing to clear")

	hero["damage"]["stun"] = stun_max
	check_true(_combat.is_knocked_out(hero), "a full stun track is unconsciousness")
	check_eq(_combat.end_scene(hero), stun_max, "the scene ending clears all of it")
	check_eq(AlternityNum.as_int(hero["damage"]["stun"]), 0, "leaving the track empty")
	check_false(_combat.is_knocked_out(hero), "so they are awake again")

	# Only stun. A scene ending does not mend a wound.
	var wounded := _hero(12)
	wounded["damage"]["stun"] = 3
	wounded["damage"]["wound"] = 4
	wounded["damage"]["mortal"] = 1
	_combat.end_scene(wounded)
	check_eq(AlternityNum.as_int(wounded["damage"]["wound"]), 4, "wounds are untouched by the scene ending")
	check_eq(AlternityNum.as_int(wounded["damage"]["mortal"]), 1, "and so is mortal damage")
	check_true(_combat.is_dying(wounded), "a dying hero is still dying when the shooting stops")

	# How long being knocked out lasts, which nothing shortens.
	check_eq(_combat.KNOCKOUT_ROUNDS, 2, "a knockout lasts this round and the next")


func _test_recovery() -> void:
	check_eq(String(_combat.RECOVERY["stun"]["cadence"]), "scene", "stun is gone by the end of the scene")
	check_eq(String(_combat.RECOVERY["fatigue"]["cadence"]), "hour", "fatigue comes back hourly")
	check_eq(String(_combat.RECOVERY["wound"]["cadence"]), "week", "wounds take weeks")
	check_eq(String(_combat.RECOVERY["mortal"]["cadence"]), "never", "mortal damage never comes back on its own")

	check_true(_combat.recovers_naturally("wound"), "wounds heal with rest")
	check_false(_combat.recovers_naturally("mortal"), "mortal damage does not")

	# Wounds and fatigue are not on the same scale, and a marginal success is
	# worth something for one and nothing for the other.
	check_eq(_combat.recovery_amount("wound", "marginal"), 1, "a marginal week still mends a wound")
	check_eq(_combat.recovery_amount("wound", "ordinary"), 2, "an ordinary one mends two")
	check_eq(_combat.recovery_amount("wound", "amazing"), 4, "and an amazing one four")
	check_eq(_combat.recovery_amount("fatigue", "marginal"), 0, "a marginal hour shakes off no fatigue")
	check_eq(_combat.recovery_amount("fatigue", "ordinary"), 1, "an ordinary one shakes off a point")
	check_eq(_combat.recovery_amount("fatigue", "amazing"), 3, "and an amazing one three")

	check_eq(_combat.recovery_amount("mortal", "amazing"), 0, "no check heals mortal damage")
	check_eq(_combat.recovery_amount("stun", "amazing"), 0, "and stun does not need one")
	check_eq(_combat.recovery_amount("nonsense", "good"), 0, "an unknown track recovers nothing")


# --- Last resort points ----------------------------------------------------

func _test_last_resort() -> void:
	check_eq(_combat.last_resort_shift("failure"), "marginal", "a point lifts a failure one grade")
	check_eq(_combat.last_resort_shift("ordinary"), "good", "and an ordinary success to good")
	check_eq(_combat.last_resort_shift("good"), "amazing", "and a good one to amazing")
	check_eq(_combat.last_resort_shift("amazing"), "amazing", "amazing is the ceiling")

	# A critical failure is stubborn: one point only reaches an ordinary failure.
	# It takes two, which only some professions can spend at once, to buy back a
	# success.
	check_eq(_combat.last_resort_shift("critical failure"), "failure", "one point makes a fumble an ordinary failure")
	check_eq(
		_combat.last_resort_shift("critical failure", 2), "marginal",
		"two points get further, which is the Free Agent's trick"
	)

	check_eq(_combat.last_resort_shift("ordinary", 0), "ordinary", "spending nothing changes nothing")

	# A defender can spend one to blunt an incoming hit before damage is rolled.
	check_eq(_combat.last_resort_blunt("amazing"), "good", "a point turns an Amazing hit into a Good one")
	check_eq(_combat.last_resort_blunt("ordinary"), "marginal", "and an ordinary hit into a marginal one")
	check_eq(_combat.last_resort_blunt("failure"), "failure", "a miss cannot be blunted further")


# --- Explosions ------------------------------------------------------------

func _test_blasts() -> void:
	# A fragmentation grenade: Amazing within 2m, Good to 4m, Ordinary to 10m.
	check_eq(_combat.blast_zone(1.0, 2.0, 4.0, 10.0), "amazing", "at the centre of the blast")
	check_eq(_combat.blast_zone(2.0, 2.0, 4.0, 10.0), "amazing", "the boundary is inclusive")
	check_eq(_combat.blast_zone(3.0, 2.0, 4.0, 10.0), "good", "in the middle band")
	check_eq(_combat.blast_zone(9.0, 2.0, 4.0, 10.0), "ordinary", "in the outer band")
	check_eq(_combat.blast_zone(11.0, 2.0, 4.0, 10.0), "", "and outside it, nothing at all")

	# Hitting the deck drops the blast one grade, so somebody on the edge who
	# throws themselves flat takes nothing.
	check_eq(_combat.blast_after_dodge("amazing", true), "good", "diving turns Amazing into Good")
	check_eq(_combat.blast_after_dodge("good", true), "ordinary", "and Good into Ordinary")
	check_eq(_combat.blast_after_dodge("ordinary", true), "", "and Ordinary into nothing")
	check_eq(_combat.blast_after_dodge("amazing", false), "amazing", "standing still changes nothing")
	check_eq(_combat.blast_after_dodge("", true), "", "and diving out of no blast is still no blast")
