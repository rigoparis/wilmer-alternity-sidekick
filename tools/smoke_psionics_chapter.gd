extends "res://tools/test_harness.gd"
##
## The Psionics chapter, pinned to the manual.
##
## The first breakdown supplied for this chapter conflicted with the catalog on
## almost every name, ability and price, and with an answer the manual had
## already given; it turned out to be another game's psionics. A second one
## agrees with the catalog throughout. Both are treated the same way: pin what
## two sources that could not have copied each other agree on.
##
## Those sources are:
##
##   * values the manual confirmed outright before being shown the catalog,
##   * rules stated verbatim in the discipline prose the app already carries,
##     e.g. "The following psionic broad skill AND ITS SPECIALTY SKILLS are
##     connected to a character's Constitution score", and "With just the broad
##     skill, a character can attempt to use any of the related specialty
##     skills except those that can't be used untrained", and
##   * each individual power's own description, which states its training
##     requirement in its own words.
##
## Since then the manuals themselves have been read, page by page, out of
## manuals/. Anything citing a page number below was taken off that page rather
## than from any breakdown -- and where the two disagreed, the page won.
##
## The per-power energy column both breakdowns supplied turned out not to exist:
## the cost is flat (Player's Handbook p. 228).
##

const RulesScript := preload("res://scripts/alternity_rules.gd")

## The four disciplines. Ability per the discipline prose; price band confirmed.
## id -> [name, governing ability, min SP, max SP]
const DISCIPLINES := {
	900: ["Biokinesis", "CON", 5, 6],
	901: ["Telepathy", "PER", 5, 6],
	902: ["Telekinesis", "WIL", 5, 6],
	903: ["Extrasensory Perception (ESP)", "INT", 5, 6],
}

const SPECIES_HUMAN := 0
const SPECIES_FRAAL := 1
const PROFESSION_COMBAT_SPEC := 0
const PROFESSION_MINDWALKER := 6
const PROFESSION_DIPLOMAT_MINDWALKER := 7

const SKILL_ESP := 903
const SKILL_TELEPATHY := 901
const SKILL_CLAIRAUDIENCE := 90302   # untrained use allowed
const SKILL_NAVCOGNITION := 90306    # cannot be used untrained
const SKILL_KINETIC_SHIELD := 90202

const CREATION_RANK_CAP := 3
const CAMPAIGN_RANK_CAP := 12

var _rules


func _init() -> void:
	begin("psionics chapter")
	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_disciplines()
	_test_specialties_follow_their_discipline()
	_test_specialty_prices_and_training()
	_test_training_flags_match_their_own_prose()
	_test_dark_matter_specialties()
	_test_spineless()
	_test_fraal_will_ceiling()
	_test_energy_pool()
	_test_pool_needs_training()
	_test_energy_recovery_table()
	_test_activation_costs_are_flat()
	_test_critical_failure_and_full_rest()
	_test_talent_limits()
	_test_dark_matter_talent_limits()
	_test_dark_matter_untrained_specialty_restriction()
	_test_psionic_rank_benefits()
	_test_psionic_energy_bought()
	_test_spending_and_resting()
	_test_fx_pool_shares_the_rest_rule()
	_test_skill_pricing()
	_test_broad_skill_allotment()
	_test_discipline_gate()
	_test_broad_covers_its_specialties()
	_test_roll_shape()
	_test_rank_caps()
	_test_perks()
	_test_fraal()
	_test_mindwalker_focus()
	_test_kinetic_shield()
	_test_psionics_are_resisted_by_will()

	finish()


func _skill(skill_id: int) -> Dictionary:
	return _rules.get_skill_by_id(skill_id)


func _named(skill_name: String) -> Dictionary:
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and String(skill.get("name", "")) == skill_name:
			return skill
	return {}


func _psionic_skills() -> Array:
	var out := []
	for skill in _rules.skills:
		if typeof(skill) == TYPE_DICTIONARY and _rules.is_psionic_skill(skill):
			out.append(skill)
	return out


func _character(species_id: int, profession_id: int, will := 10) -> Dictionary:
	var character: Dictionary = _rules.default_character()
	character["species_id"] = species_id
	character["profession_id"] = profession_id
	character["abilities"]["WIL"] = will
	_rules.ensure_character_shape(character)
	return character


## Four disciplines, no more and no fewer, each trained-only and Mindwalker-coded.
func _test_disciplines() -> void:
	var broads := []
	for skill in _psionic_skills():
		if String(skill.get("type", "")) == "broad":
			broads.append(AlternityNum.as_int(skill.get("id", -1)))
	broads.sort()
	check_eq(broads, DISCIPLINES.keys(), "the catalog holds exactly the four psionic disciplines")

	for skill_id in DISCIPLINES:
		var expected: Array = DISCIPLINES[skill_id]
		var skill: Dictionary = _skill(AlternityNum.as_int(skill_id))
		if not check(not skill.is_empty(), "discipline %d is in the catalog" % skill_id):
			continue
		check_eq(String(skill.get("name", "")), String(expected[0]), "%d is %s" % [skill_id, expected[0]])
		check_eq(
			String(skill.get("stat", "")), String(expected[1]),
			"%s is governed by %s" % [expected[0], expected[1]]
		)
		var price := AlternityNum.as_int(skill.get("base_price", -1))
		check_true(
			price >= AlternityNum.as_int(expected[2]) and price <= AlternityNum.as_int(expected[3]),
			"%s costs %d-%d SP (catalog says %d)" % [expected[0], expected[2], expected[3], price]
		)
		check_false(
			bool(skill.get("untrained", true)),
			"%s cannot be used untrained" % expected[0]
		)
		check_true(
			String(skill.get("professions", "")).contains("M"),
			"%s is a Mindwalker skill" % expected[0]
		)


## "The following psionic broad skill and its specialty skills are connected to
## a character's <ability> score." Every specialty answers to its discipline.
func _test_specialties_follow_their_discipline() -> void:
	for skill in _psionic_skills():
		if String(skill.get("type", "")) != "specialty":
			continue
		var name := String(skill.get("name", ""))
		var broad_id := AlternityNum.as_int(skill.get("broad_id", -1))
		if not check(DISCIPLINES.has(broad_id), "%s sits under a psionic discipline" % name):
			continue
		var expected: Array = DISCIPLINES[broad_id]
		check_eq(
			String(skill.get("stat", "")), String(expected[1]),
			"%s is governed by %s, like the rest of %s" % [name, expected[1], expected[0]]
		)
		check_true(
			String(skill.get("professions", "")).contains("M"),
			"%s is a Mindwalker skill" % name
		)


## Price and training for all 29 core powers, read off Table P52.
##
## These were left unpinned at first because the breakdown then available
## disagreed with the catalog on nearly every one, and pinned only cautiously
## after a second breakdown agreed -- which was weak evidence, since that
## breakdown was answering a question that had quoted the catalog's own list.
##
## Table P52 on p. 229 settles it. Every price below and every training flag is
## that table's, and all 33 rows matched the catalog exactly. The table groups
## the disciplines by governing ability, which independently confirms Biokinesis
## as Constitution, ESP as Intelligence, Telekinesis as Will and Telepathy as
## Personality. Its note reads: "Skills printed in blue can't be used
## untrained."
##
## Source: Player's Handbook p. 229; Table P52.
##
## name -> [skill points, untrained use allowed]
const SPECIALTY_PRICES := {
	# Biokinesis
	"Bioweapon": [3, true],
	"Control Metabolism": [2, true],
	"Heal": [4, false],
	"Morph": [4, false],
	"Rejuvenate": [3, true],
	"Transfer Damage": [2, true],
	# Extrasensory Perception
	"Battle Mind": [4, false],
	"Clairaudience": [2, true],
	"Clairvoyance": [2, true],
	"Empathy": [1, true],
	"Mind Reading": [3, true],
	"Navcognition": [3, false],
	"Postcognition": [3, true],
	"Precognition": [4, true],
	"Psychometry": [3, true],
	"Sensitivity": [2, true],
	# Telekinesis
	"Electrokinetics": [3, false],
	"Kinetic Shield": [2, false],
	"Levitation": [2, true],
	"Photokinetics": [1, true],
	"Psychokinetics": [3, true],
	"Pyrokinetics": [4, false],
	# Telepathy
	"Contact": [3, true],
	"Datalink": [4, false],
	"Illusion": [3, true],
	"Mind Blast": [4, false],
	"Mind Shield": [2, true],
	"Suggest": [3, true],
	"Tire": [3, true],
}

## The Dark*Matter additions, which a Core campaign never sees.
## name -> [id, discipline, skill points, untrained use allowed]
const DARK_MATTER_SPECIALTIES := {
	"Psycholocation": [90311, 903, 2, true],
	"Obscure": [90108, 901, 3, true],
	"Possess": [90109, 901, 4, false],
}


func _test_specialty_prices_and_training() -> void:
	for skill_name in SPECIALTY_PRICES:
		var expected: Array = SPECIALTY_PRICES[skill_name]
		var skill: Dictionary = _named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[0]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[0])]
		)
		check_eq(
			bool(skill.get("untrained", false)), bool(expected[1]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[1]) else "prohibited"]
		)

	# And nothing outside that list, bar the Dark*Matter three.
	for skill in _psionic_skills():
		if String(skill.get("type", "")) != "specialty":
			continue
		var name := String(skill.get("name", ""))
		check_true(
			SPECIALTY_PRICES.has(name) or DARK_MATTER_SPECIALTIES.has(name),
			"%s is a power the manual describes" % name
		)


## The training column, checked against each skill's own manual text.
##
## This is the check that owes the breakdown nothing: every power that cannot be
## used untrained says so inside its own description, and every power that can
## says nothing of the kind. If the two ever disagree, one of them was edited
## without the other.
func _test_training_flags_match_their_own_prose() -> void:
	var checked := 0
	for skill in _psionic_skills():
		if String(skill.get("type", "")) != "specialty":
			continue
		var skill_id := AlternityNum.as_int(skill.get("id", -1))
		if not AlternityRules.SPECIALTY_SUMMARIES.has(skill_id):
			continue
		var prose := String(AlternityRules.SPECIALTY_SUMMARIES[skill_id])
		var prose_says_trained_only: bool = prose.contains("can't be used untrained")
		var flag_says_trained_only: bool = not bool(skill.get("untrained", false))
		check_eq(
			flag_says_trained_only, prose_says_trained_only,
			"%s: the training flag and its own description agree" % skill.get("name", "?")
		)
		checked += 1
	check_true(checked >= 29, "every described power was checked against its own text")


## Dark*Matter adds three powers. They exist, they sit under the right
## discipline, and a Core campaign is never offered them.
func _test_dark_matter_specialties() -> void:
	for skill_name in DARK_MATTER_SPECIALTIES:
		var expected: Array = DARK_MATTER_SPECIALTIES[skill_name]
		var skill: Dictionary = _named(String(skill_name))
		if not check(not skill.is_empty(), "%s is in the catalog" % skill_name):
			continue
		check_eq(
			AlternityNum.as_int(skill.get("id", -1)),
			AlternityNum.as_int(expected[0]), "%s has its own id" % skill_name
		)
		check_eq(
			AlternityNum.as_int(skill.get("broad_id", -1)),
			AlternityNum.as_int(expected[1]), "%s sits under its discipline" % skill_name
		)
		check_eq(
			AlternityNum.as_int(skill.get("base_price", -1)),
			AlternityNum.as_int(expected[2]),
			"%s costs %d SP" % [skill_name, AlternityNum.as_int(expected[2])]
		)
		check_eq(
			bool(skill.get("untrained", false)), bool(expected[3]),
			"%s untrained use is %s" % [skill_name, "allowed" if bool(expected[3]) else "prohibited"]
		)
		check_eq(
			String(skill.get("setting", "")), "Dark*Matter",
			"%s belongs to Dark*Matter" % skill_name
		)
		check_true(
			_rules.skill_detail(skill).get("description", "") != ""
				or _rules.skill_detail(skill).get("summary", "") != "",
			"%s has reference text" % skill_name
		)

		var core: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
		core["setting"] = "Core"
		check_false(
			_rules.is_entry_available(core, skill),
			"a Core campaign is not offered %s" % skill_name
		)
		var dark: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
		dark["setting"] = "Dark*Matter"
		check_true(
			_rules.is_entry_available(dark, skill),
			"a Dark*Matter campaign is offered %s" % skill_name
		)


## The flaw that runs the other way from the Willpower perk.
func _test_spineless() -> void:
	var flaw := {}
	for candidate in AlternityRules.FLAW_DEFINITIONS:
		if String(candidate.get("id", "")) == "spineless":
			flaw = candidate
			break
	if not check(not flaw.is_empty(), "the Spineless flaw exists"):
		return
	check_eq(String(flaw.get("ability", "")), "WIL", "Spineless is a Will flaw")
	check_eq(flaw.get("bonus_options", []), [2, 4, 6], "it is worth 2, 4 or 6 skill points")

	var steps := {2: 1, 4: 2, 6: 3}
	for bonus in steps:
		var plain: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
		var weak: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
		weak["selected_flaws"] = {"spineless": bonus}
		check_eq(
			_rules.character_resistance_modifier(weak, "WIL"),
			_rules.character_resistance_modifier(plain, "WIL") - AlternityNum.as_int(steps[bonus]),
			"a %d point Spineless costs %d step(s) of Will resistance"
				% [AlternityNum.as_int(bonus), AlternityNum.as_int(steps[bonus])]
		)


## Fraal Will reaches 16, higher than any other species, which is what makes
## their pools so large.
func _test_fraal_will_ceiling() -> void:
	var fraal := {}
	for species in _rules.species:
		if typeof(species) == TYPE_DICTIONARY and String(species.get("name", "")) == "Fraal":
			fraal = species
			break
	if not check(not fraal.is_empty(), "Fraal are in the catalog"):
		return
	var limits: Array = fraal.get("ability_limits", {}).get("WIL", [])
	if not check(limits.size() >= 2, "Fraal have a Will range"):
		return
	check_eq(AlternityNum.as_int(limits[1]), 16, "Fraal Will tops out at 16")

	var psion: Dictionary = _character(SPECIES_FRAAL, PROFESSION_MINDWALKER, 16)
	check_eq(
		_rules.psionic_energy_points(psion), 24,
		"so a Fraal Mindwalker can carry a pool of 24"
	)


## Mindwalker WIL x 1; Fraal Mindwalker WIL x 1.5; talent ceil(WIL x 0.5);
## Fraal talent full WIL.
func _will_of(character: Dictionary) -> int:
	return AlternityNum.as_int(_rules.effective_abilities(character).get("WIL", 0))


func _test_energy_pool() -> void:
	# Species ranges and profession minimums move a requested score, so each row
	# is measured against the Will the hero actually ends up with.
	for requested in [8, 10, 11, 12, 15]:
		var mindwalker: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, requested)
		var mw_will := _will_of(mindwalker)
		check_eq(
			_rules.psionic_energy_points(mindwalker), mw_will,
			"a Mindwalker with WIL %d has a pool of %d" % [mw_will, mw_will]
		)

		var fraal_mindwalker: Dictionary = _character(SPECIES_FRAAL, PROFESSION_MINDWALKER, requested)
		var fmw_will := _will_of(fraal_mindwalker)
		check_eq(
			_rules.psionic_energy_points(fraal_mindwalker), int(fmw_will * 1.5),
			"a Fraal Mindwalker with WIL %d has a pool of %d" % [fmw_will, int(fmw_will * 1.5)]
		)

		var fraal_talent: Dictionary = _character(SPECIES_FRAAL, PROFESSION_COMBAT_SPEC, requested)
		var ft_will := _will_of(fraal_talent)
		check_eq(
			_rules.psionic_energy_points(fraal_talent), ft_will,
			"a Fraal talent with WIL %d has a pool of %d, not half" % [ft_will, ft_will]
		)

		var talent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, requested)
		talent["optional_rules"] = {"psionic_talents": true}
		_rules.force_skill_rank(talent, SKILL_ESP, 1)
		var t_will := _will_of(talent)
		check_eq(
			_rules.psionic_energy_points(talent), int(ceil(t_will * 0.5)),
			"a talent with WIL %d has a pool of %d" % [t_will, int(ceil(t_will * 0.5))]
		)

	# A Diplomat carrying Mindwalker as a secondary profession draws half.
	#
	# "A Diplomat with the Mindwalker secondary profession has psionic energy
	# points equal to one-half his Will score." (Player's Handbook p. 228.) This
	# suite originally asserted the opposite, following a breakdown rather than
	# the page.
	var diplomat: Dictionary = _character(SPECIES_HUMAN, PROFESSION_DIPLOMAT_MINDWALKER, 11)
	check_eq(
		_rules.psionic_energy_points(diplomat), int(ceil(_will_of(diplomat) * 0.5)),
		"a Diplomat (Mindwalker) draws half of Will"
	)

	# Unless they are fraal. "A fraal who is a talent, or one who is a Diplomat
	# with Mindwalker as his secondary profession, has psionic energy points
	# equal to his Will score (instead of one-half Will for other such
	# characters)." (Player's Handbook p. 22.)
	var fraal_diplomat: Dictionary = _character(SPECIES_FRAAL, PROFESSION_DIPLOMAT_MINDWALKER, 12)
	check_eq(
		_rules.psionic_energy_points(fraal_diplomat), _will_of(fraal_diplomat),
		"a fraal Diplomat (Mindwalker) draws all of it"
	)


## The pool unlocks with the first psionic broad skill. A hero who has bought
## none has none.
func _test_pool_needs_training() -> void:
	var untrained: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	check_false(_rules.is_psionic_character(untrained), "an untrained hero is not psionic")
	check_eq(_rules.psionic_energy_points(untrained), 0, "an untrained hero has no energy pool")

	untrained["optional_rules"] = {"psionic_talents": true}
	check_eq(
		_rules.psionic_energy_points(untrained), 0,
		"permitting the Psionic Talents rule does not by itself grant a pool"
	)

	_rules.force_skill_rank(untrained, SKILL_ESP, 1)
	check_true(_rules.is_psionic_character(untrained), "buying a discipline makes a hero psionic")
	var opened_will := _will_of(untrained)
	check_eq(
		_rules.psionic_energy_points(untrained), int(ceil(opened_will * 0.5)),
		"and opens a pool of ceil(WIL %d x 0.5)" % opened_will
	)


## One full uninterrupted hour of rest, settled on a Resolve -- mental resolve
## check: Ordinary 1 point, Good 2, Amazing 3. Anything short of Ordinary gives
## nothing back.
func _test_energy_recovery_table() -> void:
	var table := {
		"failure": 0,
		"marginal": 0,
		"ordinary": 1,
		"good": 2,
		"amazing": 3,
	}
	for result in table:
		check_eq(
			_rules.energy_recovered_for_result(String(result)),
			AlternityNum.as_int(table[result]),
			"an %s rest recovers %d point(s)" % [result, AlternityNum.as_int(table[result])]
		)
	check_eq(
		_rules.energy_recovered_for_result("Amazing"), 3,
		"the degree is read whatever its casing"
	)
	check_eq(
		_rules.energy_recovered_for_result("nonsense"), 0,
		"an unrecognised result recovers nothing"
	)
	check_eq(
		AlternityRules.ENERGY_RECOVERY_SKILL_ID, 135,
		"rest is settled on Resolve -- mental resolve"
	)


## "Action / Energy Lost: Critical Failure result 3; Broad skill, success or
## failure 2; Specialty skill, success or failure 1."
## (Player's Handbook p. 228.)
##
## Flat, for every power in every discipline. Both supplied breakdowns invented
## a per-power column instead -- Heal 2, Morph 2, Postcognition 2 and so on --
## and neither matched the page.
func _test_activation_costs_are_flat() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 14)
	_rules.force_skill_rank(psion, SKILL_ESP, 1)

	var broad: Dictionary = _rules.psionic_activation_cost(psion, _skill(SKILL_ESP))
	check_eq(AlternityNum.as_int(broad.get("points", -1)), 2, "a discipline check costs 2 points")
	check_eq(
		AlternityNum.as_int(broad.get("critical_failure", -1)), 3,
		"and a Critical Failure costs 3"
	)

	# Leaning on the discipline for a specialty is a broad skill check, so it
	# costs the broad skill's 2.
	var carried: Dictionary = _rules.psionic_activation_cost(psion, _skill(SKILL_CLAIRAUDIENCE))
	check_eq(
		AlternityNum.as_int(carried.get("points", -1)), 2,
		"reaching a power through the discipline costs the discipline's 2"
	)
	check_true(bool(carried.get("through_broad", false)), "and is flagged as such")

	# A rank of your own drops it to 1, whatever the power is.
	for skill_id in [90302, 90303, 90305, 90307, 90308, 90309]:
		_rules.force_skill_rank(psion, skill_id, 1)
		var own: Dictionary = _rules.psionic_activation_cost(psion, _skill(skill_id))
		check_eq(
			AlternityNum.as_int(own.get("points", -1)), 1,
			"%s costs 1 point with a rank of its own" % _skill(skill_id).get("name", "?")
		)

	# Sensitivity names its own price and overrides the flat rate.
	# "Activating the skill requires the hero to use 2 psionic energy points."
	# (Player's Handbook p. 233.)
	_rules.force_skill_rank(psion, 90310, 1)
	check_eq(
		AlternityNum.as_int(_rules.psionic_activation_cost(psion, _skill(90310)).get("points", -1)), 2,
		"Sensitivity costs 2 to activate even with a rank of its own"
	)

	# A hero must hold what the action costs.
	_rules.set_psionic_energy_used(psion, _rules.psionic_energy_points(psion) - 1)
	check_false(
		bool(_rules.psionic_activation_cost(psion, _skill(SKILL_ESP)).get("affordable", true)),
		"one point left cannot pay for a discipline check"
	)
	check_true(
		bool(_rules.psionic_activation_cost(psion, _skill(90302)).get("affordable", false)),
		"but can pay for a specialty"
	)


## A Critical Failure on the hourly check costs a point instead of returning
## one, and a hero with none to lose takes fatigue. Eight unbroken hours refill
## the pool with no check at all. Source: Player's Handbook p. 228.
func _test_critical_failure_and_full_rest() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	var size: int = _rules.psionic_energy_points(psion)
	_rules.spend_psionic_energy(psion, 4)

	check_eq(
		_rules.rest_psionic_energy(psion, "critical failure"), -1,
		"a Critical Failure costs a point rather than returning one"
	)
	check_eq(
		AlternityNum.as_int(_rules.psionic_energy(psion).get("used", -1)), 5,
		"which deepens the spend"
	)

	# Emptied out, there is nothing left to lose, so it lands as fatigue.
	_rules.spend_psionic_energy(psion, size)
	var before := AlternityNum.as_int(psion.get("damage", {}).get("fatigue", 0))
	check_eq(
		_rules.rest_psionic_energy(psion, "critical failure"), 0,
		"an empty pool loses no points"
	)
	check_eq(
		AlternityNum.as_int(psion.get("damage", {}).get("fatigue", 0)), before + 1,
		"and takes a point of fatigue instead"
	)

	check_eq(
		_rules.full_rest_psionic_energy(psion), size,
		"eight hours give back everything that was spent"
	)
	check_eq(
		AlternityNum.as_int(_rules.psionic_energy(psion).get("available", -1)), size,
		"leaving a full pool"
	)


## "A talent is entitled to purchase one psionic broad skill... as many as two
## psionic specialty skills... One of those specialty skills can be improved to
## as high as rank 6, while the other one can be raised to rank 3."
## (Player's Handbook p. 228.)
func _test_talent_limits() -> void:
	var talent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	talent["optional_rules"] = {"psionic_talents": true}
	_rules.force_skill_rank(talent, SKILL_ESP, 1)
	check_false(_complains(talent, "only 1 psionic broad"), "one discipline is allowed")

	_rules.force_skill_rank(talent, 902, 1)   # Telekinesis as well
	check_true(_complains(talent, "only 1 psionic broad"), "a second discipline is not")

	var counted: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	counted["optional_rules"] = {"psionic_talents": true}
	_rules.force_skill_rank(counted, SKILL_ESP, 1)
	_rules.force_skill_rank(counted, 90302, 1)
	_rules.force_skill_rank(counted, 90303, 1)
	check_false(_complains(counted, "at most 2 psionic specialty"), "two powers are allowed")
	_rules.force_skill_rank(counted, 90305, 1)
	check_true(_complains(counted, "at most 2 psionic specialty"), "a third is not")

	# One power to rank 6, the other to rank 3.
	var ranked: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	ranked["optional_rules"] = {"psionic_talents": true}
	ranked["achievement_level"] = 10
	_rules.force_skill_rank(ranked, SKILL_ESP, 1)
	_rules.force_skill_rank(ranked, 90302, 6)
	_rules.force_skill_rank(ranked, 90303, 3)
	check_false(_complains(ranked, "raise one specialty to rank 6"), "6 and 3 is legal")

	_rules.force_skill_rank(ranked, 90303, 4)
	check_true(_complains(ranked, "raise one specialty to rank 6"), "6 and 4 is not")

	_rules.force_skill_rank(ranked, 90303, 3)
	_rules.force_skill_rank(ranked, 90302, 7)
	check_true(_complains(ranked, "raise one specialty to rank 6"), "and neither is 7 and 3")

	# A Mindwalker is held to none of it.
	var mindwalker: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	mindwalker["achievement_level"] = 10
	for broad_id in [900, 901, 902, 903]:
		_rules.force_skill_rank(mindwalker, broad_id, 1)
	for skill_id in [90302, 90303, 90305, 90307]:
		_rules.force_skill_rank(mindwalker, skill_id, 8)
	check_false(
		_complains(mindwalker, "psionic broad") or _complains(mindwalker, "psionic specialty"),
		"a Mindwalker may hold every discipline and raise every power"
	)


## Dark*Matter Mindwalking: talents may raise 1 specialty to rank 12 and 1 to rank 6.
## With Superior Talent perk:
## - 4 SP: up to 2 broads with up to 2 specialties each; 1 specialty to rank 12, others to rank 6.
## - 6 SP: up to 1 broad with up to 4 specialties; 1 specialty to rank 12, others to rank 6.
## Source: Dark Matter Campaign Setting p. 60, 71.
func _test_dark_matter_talent_limits() -> void:
	var dm_talent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	dm_talent["setting"] = "Dark*Matter"
	dm_talent["achievement_level"] = 10
	_rules.force_skill_rank(dm_talent, SKILL_ESP, 1)
	_rules.force_skill_rank(dm_talent, 90302, 12)
	_rules.force_skill_rank(dm_talent, 90303, 6)
	check_false(_complains(dm_talent, "rank"), "Dark*Matter talent allows rank 12 and rank 6")

	_rules.force_skill_rank(dm_talent, 90303, 7)
	check_true(_complains(dm_talent, "rank 12 and other specialties to rank 6"), "rank 12 and 7 is not allowed for standard DM talent")

	# Superior Talent (4 SP): 2 broads, max 2 specialties each
	var sup4: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	sup4["setting"] = "Dark*Matter"
	sup4["achievement_level"] = 10
	sup4["selected_perks"] = {"superior_talent": 4}
	_rules.force_skill_rank(sup4, SKILL_ESP, 1)
	_rules.force_skill_rank(sup4, 901, 1)
	_rules.force_skill_rank(sup4, 90302, 12)
	_rules.force_skill_rank(sup4, 90303, 6)
	_rules.force_skill_rank(sup4, 90101, 6)
	_rules.force_skill_rank(sup4, 90103, 6)
	check_false(_complains(sup4, "broad") or _complains(sup4, "specialty"), "Superior Talent 4 SP allows 2 broads and 4 specialties total")

	# Adding a 3rd specialty to ESP exceeds 2 per broad
	_rules.force_skill_rank(sup4, 90305, 1)
	check_true(_complains(sup4, "at most 2 specialty skills per broad skill"), "Superior Talent 4 SP rejects >2 specialties in one broad")

	# Superior Talent (6 SP): 1 broad, up to 4 specialties
	var sup6: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	sup6["setting"] = "Dark*Matter"
	sup6["achievement_level"] = 10
	sup6["selected_perks"] = {"superior_talent": 6}
	_rules.force_skill_rank(sup6, SKILL_ESP, 1)
	_rules.force_skill_rank(sup6, 90302, 12)
	_rules.force_skill_rank(sup6, 90303, 6)
	_rules.force_skill_rank(sup6, 90305, 6)
	_rules.force_skill_rank(sup6, 90307, 6)
	check_false(_complains(sup6, "broad") or _complains(sup6, "specialty"), "Superior Talent 6 SP allows 1 broad and 4 specialties")


## "For the purposes of a DARK*MATTER campaign, however, no psionic specialty skill
## may be used untrained by human talents." (Dark Matter Table D5 p. 71.)
func _test_dark_matter_untrained_specialty_restriction() -> void:
	var dm_talent: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	dm_talent["setting"] = "Dark*Matter"
	_rules.force_skill_rank(dm_talent, SKILL_ESP, 1)

	var score: Dictionary = _rules.skill_score(dm_talent, _skill(SKILL_CLAIRAUDIENCE))
	check_false(bool(score.get("usable", false)), "untrained psionic specialty is unusable for human talent in Dark*Matter")
	check_true(String(score.get("reason", "")).contains("Dark*Matter"), "reason cites Dark*Matter restriction")


## Psionic rank benefits are defined in RANK_BENEFIT_NOTES.
func _test_psionic_rank_benefits() -> void:
	var expected_benefit_skills := [
		90003, # Heal (Rank 6 mortal)
		90004, # Morph (Forms at 1, 3, 5, 7, 10, 12)
		90104, # Mind Blast (Damage at 5, 9)
		90106, # Suggest (Programmed suggestion at 6)
		90108, # Obscure (Duration at 4, Amnesia at 8)
		90109, # Possess (Mastery at 4/8/12, Duration at 6/9)
		90201, # Electrokinetics (Short circuit at 4, Damage at 5/9, Override at 8, Jamming at 12)
		90206, # Pyrokinetics (Damage at 5, 9)
		90306, # Navcognition (Specialties at 1, 5, 9)
		90311, # Psycholocation (Radius at 6, 9, 12)
	]
	for skill_id in expected_benefit_skills:
		var detail: Dictionary = _rules.skill_detail(_skill(skill_id))
		var benefits: Dictionary = detail.get("rank_benefits", {})
		check_true(not benefits.is_empty(), "%s has rank benefits defined" % _skill(skill_id).get("name", "?"))


## Psionic energy pool can be enlarged via psionic_energy_bought.
func _test_psionic_energy_bought() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	var base_pts: int = _rules.psionic_energy_points(psion)
	psion["psionic_energy_bought"] = 3
	check_eq(
		_rules.psionic_energy_points(psion), base_pts + 3,
		"psionic_energy_bought increases psionic_energy_points"
	)
	var energy: Dictionary = _rules.psionic_energy(psion)
	check_eq(
		AlternityNum.as_int(energy.get("max", 0)), base_pts + 3,
		"psionic_energy max reflects bought points"
	)


func _complains(character: Dictionary, fragment: String) -> bool:
	for message in _rules.validate(character):
		if String(message).contains(fragment):
			return true
	return false


## The pool is spent from and rested back, and never leaves its own range.
func _test_spending_and_resting() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	var size: int = _rules.psionic_energy_points(psion)

	var pool: Dictionary = _rules.psionic_energy(psion)
	check_eq(AlternityNum.as_int(pool.get("max", -1)), size, "the pool starts at its full size")
	check_eq(AlternityNum.as_int(pool.get("used", -1)), 0, "with nothing spent")
	check_eq(AlternityNum.as_int(pool.get("available", -1)), size, "and all of it available")

	check_eq(_rules.spend_psionic_energy(psion, 3), 3, "spending 3 points takes 3")
	pool = _rules.psionic_energy(psion)
	check_eq(AlternityNum.as_int(pool.get("used", -1)), 3, "3 are marked spent")
	check_eq(AlternityNum.as_int(pool.get("available", -1)), size - 3, "and the rest remain")

	# A power cannot be paid for with points the hero does not have.
	check_eq(
		_rules.spend_psionic_energy(psion, size), size - 3,
		"a pool that cannot cover the cost gives only what it has"
	)
	check_eq(
		AlternityNum.as_int(_rules.psionic_energy(psion).get("available", -1)), 0,
		"leaving it empty, never negative"
	)
	check_eq(_rules.spend_psionic_energy(psion, 1), 0, "an empty pool pays nothing")

	check_eq(_rules.rest_psionic_energy(psion, "good"), 2, "a Good hour gives 2 back")
	check_eq(_rules.rest_psionic_energy(psion, "amazing"), 3, "an Amazing hour gives 3")
	check_eq(_rules.rest_psionic_energy(psion, "failure"), 0, "a failed hour gives none")
	check_eq(
		AlternityNum.as_int(_rules.psionic_energy(psion).get("used", -1)), size - 5,
		"and the spend falls by exactly what was recovered"
	)

	# Resting past full puts back only what was actually spent.
	for _i in 40:
		_rules.rest_psionic_energy(psion, "amazing")
	var rested: Dictionary = _rules.psionic_energy(psion)
	check_eq(AlternityNum.as_int(rested.get("used", -1)), 0, "rest stops at a full pool")
	check_eq(AlternityNum.as_int(rested.get("available", -1)), size, "with everything back")

	# A pool that shrinks -- a lost point of Will, a sold discipline -- drags the
	# spend down with it rather than leaving a hero owing more than they hold.
	_rules.spend_psionic_energy(psion, size)
	psion["abilities"]["WIL"] = 8
	_rules.ensure_character_shape(psion)
	_rules.clamp_trackers(psion)
	var shrunk: Dictionary = _rules.psionic_energy(psion)
	check_eq(
		AlternityNum.as_int(shrunk.get("used", -1)),
		AlternityNum.as_int(shrunk.get("max", -1)),
		"a shrinking pool clamps the spend to its new size"
	)
	check_true(
		AlternityNum.as_int(shrunk.get("available", -1)) >= 0,
		"and never reports a negative remainder"
	)


## FX pools rest on the same table, and a permanently active power holds its
## cost against the pool the whole time it runs.
func _test_fx_pool_shares_the_rest_rule() -> void:
	var mage: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	_rules.fx.set_fx_talent(mage, true)
	_rules.fx.set_energy_pool(mage, 10)

	var pool: Dictionary = _rules.fx.fx_energy(mage)
	check_eq(AlternityNum.as_int(pool.get("max", -1)), 10, "the FX pool is its stated size")
	check_eq(AlternityNum.as_int(pool.get("available", -1)), 10, "and starts wholly available")

	check_eq(_rules.fx.spend_energy(mage, 4), 4, "spending 4 takes 4")
	check_eq(
		AlternityNum.as_int(_rules.fx.fx_energy(mage).get("available", -1)), 6,
		"leaving 6"
	)
	check_eq(_rules.fx.rest_energy(mage, "ordinary"), 1, "an Ordinary hour gives 1 back")
	check_eq(_rules.fx.rest_energy(mage, "amazing"), 3, "an Amazing hour gives 3")
	check_eq(
		AlternityNum.as_int(_rules.fx.fx_energy(mage).get("used", -1)), 0,
		"which clears the spend"
	)

	# A permanent power is not spendable capacity.
	var made_permanent := false
	for broad in _rules.fx.get_broad_skills_for_character(mage):
		var broad_name := String(broad.get("name", ""))
		_rules.fx.add_fx_skill(mage, broad_name)
		for power in _rules.fx.get_specialty_skills_for_broad_and_character(broad_name, mage):
			var power_name := String(power.get("name", ""))
			if not _rules.fx.can_fx_skill_be_permanent(power_name):
				continue
			_rules.fx.add_fx_skill(mage, power_name)
			_rules.fx.set_fx_skill_permanent(mage, power_name, true)
			made_permanent = true
			break
		if made_permanent:
			break

	if check(made_permanent, "a permanently active power could be set up"):
		var held: Dictionary = _rules.fx.fx_energy(mage)
		var reserved := AlternityNum.as_int(held.get("reserved", 0))
		check_true(reserved > 0, "the permanent power holds points against the pool")
		check_eq(
			AlternityNum.as_int(held.get("spendable", -1)),
			AlternityNum.as_int(held.get("max", 0)) - reserved,
			"which come off the top before anything is spent"
		)
		check_eq(
			_rules.fx.spend_energy(mage, 99),
			AlternityNum.as_int(held.get("spendable", 0)),
			"so only the unreserved remainder can be spent"
		)


## Mindwalkers pay 1 SP less; everyone else pays 1 SP more.
func _test_skill_pricing() -> void:
	for skill_id in DISCIPLINES:
		var skill: Dictionary = _skill(AlternityNum.as_int(skill_id))
		var listed := AlternityNum.as_int(skill.get("base_price", 0))
		var name := String(skill.get("name", ""))

		check_eq(
			_rules.skill_cost(_character(SPECIES_HUMAN, PROFESSION_MINDWALKER), skill),
			maxi(1, listed - 1),
			"a Mindwalker buys %s for 1 SP under list" % name
		)
		check_eq(
			_rules.skill_cost(_character(SPECIES_HUMAN, PROFESSION_DIPLOMAT_MINDWALKER), skill),
			maxi(1, listed - 1),
			"a Diplomat (Mindwalker) buys %s for 1 SP under list" % name
		)
		check_eq(
			_rules.skill_cost(_character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC), skill),
			listed + 1,
			"a talent buys %s for 1 SP over list" % name
		)

	# The same surcharge applies to specialties, not just disciplines.
	var clairaudience: Dictionary = _skill(SKILL_CLAIRAUDIENCE)
	var spec_listed := AlternityNum.as_int(clairaudience.get("base_price", 0))
	check_eq(
		_rules.skill_cost(_character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC), clairaudience),
		spec_listed + 1,
		"a talent pays the surcharge on specialties too"
	)


## Disciplines are broad skills and spend a broad skill slot from Table P5.
func _test_broad_skill_allotment() -> void:
	var hero: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	var before: int = _rules.broad_skills_used(hero)
	_rules.force_skill_rank(hero, SKILL_ESP, 1)
	check_eq(
		_rules.broad_skills_used(hero), before + 1,
		"buying a discipline spends a broad skill slot"
	)
	var additional_before: int = _rules.additional_broad_skills_used(hero)
	_rules.force_skill_rank(hero, 902, 1)   # Telekinesis
	check_eq(
		_rules.additional_broad_skills_used(hero), additional_before + 1,
		"a second discipline spends another"
	)


## Psionics is closed. No discipline, no powers -- not even the ones whose
## untrained column reads yes, which means "reachable with the discipline
## alone", not "reachable by anyone".
func _test_discipline_gate() -> void:
	var stranger: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	stranger["abilities"]["INT"] = 12
	stranger["abilities"]["CON"] = 12
	stranger["abilities"]["PER"] = 12
	_rules.ensure_character_shape(stranger)

	var leaked := 0
	for skill in _psionic_skills():
		var score: Dictionary = _rules.skill_score(stranger, skill)
		if bool(score.get("usable", false)):
			leaked += 1
			check(false, "%s is out of reach without its discipline" % skill.get("name", "?"))
	check_eq(leaked, 0, "no psionic power is rollable by an untrained hero")

	# And the refusal names the discipline that would open it.
	var reason := String(_rules.skill_score(stranger, _skill(SKILL_CLAIRAUDIENCE)).get("reason", ""))
	check_true(
		reason.contains("Extrasensory Perception"),
		"the refusal names the discipline to buy"
	)


## "With just the broad skill, a character can attempt to use any of the related
## specialty skills except those that can't be used untrained."
func _test_broad_covers_its_specialties() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	psion["abilities"]["INT"] = 12
	_rules.ensure_character_shape(psion)
	_rules.force_skill_rank(psion, SKILL_ESP, 1)

	var clairaudience: Dictionary = _rules.skill_score(psion, _skill(SKILL_CLAIRAUDIENCE))
	check_true(bool(clairaudience.get("usable", false)), "the discipline reaches Clairaudience")
	check_eq(
		AlternityNum.as_int(clairaudience.get("ordinary", 0)), 12,
		"and rolls it at the discipline's own score, not half of it"
	)
	check_eq(String(clairaudience.get("die", "")), "+d4", "with the discipline's +d4 die")
	check_true(bool(clairaudience.get("via_broad", false)), "flagged as rolled through the discipline")

	var navcognition: Dictionary = _rules.skill_score(psion, _skill(SKILL_NAVCOGNITION))
	check_false(
		bool(navcognition.get("usable", false)),
		"but Navcognition, barred from untrained use, stays barred"
	)

	# Buying the specialty outright beats leaning on the discipline.
	_rules.force_skill_rank(psion, SKILL_CLAIRAUDIENCE, 1)
	var trained: Dictionary = _rules.skill_score(psion, _skill(SKILL_CLAIRAUDIENCE))
	check_eq(AlternityNum.as_int(trained.get("ordinary", 0)), 13, "rank 1 Clairaudience scores 13")
	check_eq(String(trained.get("die", "")), "+d0", "and drops to the specialty's +d0 die")
	check_false(bool(trained.get("via_broad", false)), "no longer rolled through the discipline")

	# The same rule outside psionics: a broad skill covers its own specialties.
	var scholar: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 10)
	scholar["abilities"]["INT"] = 12
	_rules.ensure_character_shape(scholar)
	var chemistry: Dictionary = _named("Chemistry")
	if check(not chemistry.is_empty(), "Chemistry is in the catalog"):
		var without: Dictionary = _rules.skill_score(scholar, chemistry)
		check_eq(
			AlternityNum.as_int(without.get("ordinary", 0)), 6,
			"without Physical Science, Chemistry is an untrained check at half INT"
		)
		_rules.force_skill_rank(scholar, AlternityNum.as_int(chemistry.get("broad_id", -1)), 1)
		var with_broad: Dictionary = _rules.skill_score(scholar, chemistry)
		check_eq(
			AlternityNum.as_int(with_broad.get("ordinary", 0)), 12,
			"holding Physical Science raises Chemistry to the broad skill score"
		)
		check_eq(String(with_broad.get("die", "")), "+d4", "at the broad skill's +d4 die")


## Disciplines roll the ability with +d4; specialties roll ability + rank at +d0.
func _test_roll_shape() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 13)
	psion["abilities"]["CON"] = 11
	_rules.ensure_character_shape(psion)
	_rules.force_skill_rank(psion, 900, 1)   # Biokinesis

	var broad: Dictionary = _rules.skill_score(psion, _skill(900))
	check_eq(AlternityNum.as_int(broad.get("ordinary", 0)), 11, "Biokinesis scores CON 11")
	check_eq(String(broad.get("die", "")), "+d4", "a discipline rolls +d4")
	check_eq(AlternityNum.as_int(broad.get("good", 0)), 5, "Good is half of Ordinary")
	check_eq(AlternityNum.as_int(broad.get("amazing", 0)), 2, "Amazing is a quarter of Ordinary")

	_rules.force_skill_rank(psion, 90002, 2)   # Control Metabolism
	var specialty: Dictionary = _rules.skill_score(psion, _skill(90002))
	check_eq(AlternityNum.as_int(specialty.get("ordinary", 0)), 13, "rank 2 scores CON 11 + 2")
	check_eq(String(specialty.get("die", "")), "+d0", "a specialty rolls +d0")


## Rank 3 at creation; rank 12 across a campaign.
func _test_rank_caps() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	check_eq(
		_rules.max_skill_rank_for_character(psion), CREATION_RANK_CAP,
		"a psionic specialty stops at rank 3 during creation"
	)
	psion["achievement_level"] = 4
	check_eq(
		_rules.max_skill_rank_for_character(psion), CAMPAIGN_RANK_CAP,
		"and at rank 12 thereafter"
	)


func _test_perks() -> void:
	var expected := {
		"psionic_awareness": ["Psionic Awareness", "INT", 3],
		"willpower": ["Willpower", "WIL", 4],
	}
	for perk_id in expected:
		var wanted: Array = expected[perk_id]
		var perk := {}
		for candidate in AlternityRules.PERK_DEFINITIONS:
			if String(candidate.get("id", "")) == String(perk_id):
				perk = candidate
				break
		if not check(not perk.is_empty(), "the %s perk exists" % wanted[0]):
			continue
		check_eq(String(perk.get("name", "")), String(wanted[0]), "%s is named" % wanted[0])
		check_eq(
			String(perk.get("ability", "")), String(wanted[1]),
			"%s is a %s perk" % [wanted[0], wanted[1]]
		)
		check_eq(
			perk.get("cost_options", []), [AlternityNum.as_int(wanted[2])],
			"%s costs %d SP" % [wanted[0], AlternityNum.as_int(wanted[2])]
		)

	# Willpower's whole effect is the resistance step it buys.
	var plain: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	var stoic: Dictionary = _character(SPECIES_HUMAN, PROFESSION_COMBAT_SPEC, 12)
	stoic["selected_perks"] = {"willpower": 4}
	# A resistance modifier is the penalty an attacker eats, so improving it
	# means one step more, not one step less.
	check_eq(
		_rules.character_resistance_modifier(stoic, "WIL"),
		_rules.character_resistance_modifier(plain, "WIL") + 1,
		"the Willpower perk improves the Will resistance modifier by a step"
	)


## Fraal carry Telepathy from birth, so their pool is open before they spend a
## point -- and a Fraal who is not a Mindwalker stays inside that discipline.
func _test_fraal() -> void:
	var fraal: Dictionary = _character(SPECIES_FRAAL, PROFESSION_COMBAT_SPEC, 10)
	check_true(
		_rules.get_free_skill_ids(fraal).has(SKILL_TELEPATHY),
		"Telepathy is a free Fraal species skill"
	)
	check_true(_rules.is_psionic_character(fraal), "so a Fraal is psionic without spending a point")
	check_eq(
		_rules.psionic_energy_points(fraal), _will_of(fraal),
		"with a pool of full WIL"
	)

	# Telepathy's own specialties are fine.
	_rules.force_skill_rank(fraal, 90101, 1)   # Contact
	var complained := false
	for message in _rules.validate(fraal):
		if String(message).contains("Telepathy discipline"):
			complained = true
	check_false(complained, "a Fraal talent may take Telepathy specialties")

	# Another discipline's specialties are not.
	_rules.force_skill_rank(fraal, SKILL_ESP, 1)
	_rules.force_skill_rank(fraal, SKILL_CLAIRAUDIENCE, 1)
	complained = false
	for message in _rules.validate(fraal):
		if String(message).contains("Telepathy discipline"):
			complained = true
	check_true(complained, "a Fraal talent is held to the Telepathy discipline")


## A Mindwalker names one discipline and rolls it, and everything under it, one
## step better.
func _test_mindwalker_focus() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	psion["abilities"]["INT"] = 12
	_rules.ensure_character_shape(psion)
	_rules.force_skill_rank(psion, SKILL_ESP, 1)
	_rules.force_skill_rank(psion, SKILL_CLAIRAUDIENCE, 1)

	check_eq(
		String(_rules.skill_score(psion, _skill(SKILL_ESP)).get("die", "")), "+d4",
		"an unfocused discipline rolls +d4"
	)
	check_eq(
		String(_rules.skill_score(psion, _skill(SKILL_CLAIRAUDIENCE)).get("die", "")), "+d0",
		"an unfocused specialty rolls +d0"
	)

	psion["mindwalker_psionic_focus"] = SKILL_ESP
	check_eq(
		String(_rules.skill_score(psion, _skill(SKILL_ESP)).get("die", "")), "+d0",
		"the focused discipline improves a step, to +d0"
	)
	check_eq(
		String(_rules.skill_score(psion, _skill(SKILL_CLAIRAUDIENCE)).get("die", "")), "-d4",
		"and its specialties improve with it, to -d4"
	)


## Table P10 lists "Psionic Skills" as one row against Will. Every discipline,
## every power, the same resistance -- not Will for mental powers and Dexterity
## for pyrokinetics, which is what both supplied breakdowns claimed.
## Source: Player's Handbook p. 51; Table P10.
func _test_psionics_are_resisted_by_will() -> void:
	var checked := 0
	for skill in _psionic_skills():
		check_eq(
			_rules.resisted_by(skill), ["WIL"],
			"%s is resisted with Will" % skill.get("name", "?")
		)
		checked += 1
	check_true(checked >= 33, "every psionic skill was checked")

	var note: String = _rules.resisted_by_note(_skill(SKILL_CLAIRAUDIENCE))
	check_true(note.contains("Will"), "and the reference text says so")


## Kinetic Shield is worn armour once the specialty is held, and not before.
func _test_kinetic_shield() -> void:
	var psion: Dictionary = _character(SPECIES_HUMAN, PROFESSION_MINDWALKER, 12)
	_rules.force_skill_rank(psion, 902, 1)   # Telekinesis
	check_eq(
		_rules.psionic_armor_rows(psion).size(), 0,
		"the discipline alone puts no shield on the sheet"
	)

	_rules.force_skill_rank(psion, SKILL_KINETIC_SHIELD, 1)
	var rows: Array = _rules.psionic_armor_rows(psion)
	if not check_eq(rows.size(), 1, "holding Kinetic Shield adds one armour row"):
		return
	var item: Dictionary = rows[0].get("item", {})
	check_eq(String(item.get("name", "")), "Kinetic Shield", "the row is the shield")
	var combat: Dictionary = item.get("combat", {})
	check_eq(String(combat.get("li", "")), "+2", "it stops 2 points of low impact")
	check_eq(String(combat.get("hi", "")), "+1", "and 1 point of high impact")
	check_eq(String(combat.get("toughness", "")), "O", "at Ordinary toughness")
