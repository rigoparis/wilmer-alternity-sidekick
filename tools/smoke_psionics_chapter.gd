extends "res://tools/test_harness.gd"
##
## The Psionics chapter, pinned to the manual.
##
## Psionics is the first chapter whose supplied breakdown conflicted with the
## catalog on almost every name, ability and price -- and with an answer the
## manual had already given (broad disciplines cost 5-6 SP, Telekinesis is the
## broad with Psychokinetics beneath it). This suite therefore pins only what
## two independent sources agree on:
##
##   * values the manual has already confirmed outright, and
##   * rules stated verbatim in the discipline prose the app already carries,
##     e.g. "The following psionic broad skill AND ITS SPECIALTY SKILLS are
##     connected to a character's Constitution score", and "With just the broad
##     skill, a character can attempt to use any of the related specialty
##     skills except those that can't be used untrained."
##
## Per-specialty prices are deliberately NOT pinned here. They are the open
## question; pinning the catalog's own numbers would only prove that the
## catalog equals itself.
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
	_test_energy_pool()
	_test_pool_needs_training()
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

	# A Diplomat carrying Mindwalker as a secondary profession draws full WIL.
	var diplomat: Dictionary = _character(SPECIES_HUMAN, PROFESSION_DIPLOMAT_MINDWALKER, 11)
	check_eq(
		_rules.psionic_energy_points(diplomat), _will_of(diplomat),
		"a Diplomat (Mindwalker) draws full WIL, not half"
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
