extends "res://tools/test_harness.gd"
##
## What Dark*Matter forbids that the core rules allow.
##
## Dark*Matter is contemporary Earth, so it takes things away rather than adding
## them: no alien species, no Mindwalker career, no Adept profession. Everything
## it changes is reached through a perk instead, which is why every psionic and
## every spellcaster in the setting is a talent and lives under the talent caps.
##
## Half of this suite is about Core. Every rule below is gated on the setting, and
## a gate that leaks is invisible -- a Core hero would simply start failing
## validation for a book their table does not own. So each restriction is checked
## twice: that it fires in Dark*Matter, and that it stays silent outside it.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")

const SPECIES_HUMAN := 0
const SPECIES_WEREN := 5
const PROFESSION_COMBAT_SPEC := 0
const PROFESSION_MINDWALKER := 6

var _rules: AlternityRules


func _init() -> void:
	begin("dark matter")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_the_setting_is_recognised()
	_test_humans_only()
	_test_no_mindwalker_career()
	_test_psionics_come_through_a_perk()
	_test_fx_comes_through_a_perk()
	_test_fx_talent_rank_caps()
	_test_talent_surcharges()
	_test_the_new_skills()
	_test_alien_heroes()
	_test_enochian()
	_test_setting_repriced_schools()
	_test_lore_is_a_free_agent_skill()
	_test_fx_energy_pool()
	_test_psionic_energy_purchases()
	_test_alien_technology()
	_test_the_two_pools_are_separate()
	_test_species_creation_budgets()
	_test_dark_matter_mutant_restrictions()
	_test_incantation_sasquatch_gating()
	_test_dark_matter_untrained_fx_feat_check()
	_test_social_science_and_setting_skills()
	_test_career_packages()
	_test_requisition_subsystem()
	_test_investigate_modifiers()
	_test_contacts_allegiances()
	_test_core_is_untouched()

	finish()


func _hero(setting: String, species_id: int = SPECIES_HUMAN, profession_id: int = PROFESSION_COMBAT_SPEC) -> Dictionary:
	var c: Dictionary = _rules.default_character()
	_rules.ensure_character_shape(c)
	c["setting"] = setting
	c["species_id"] = species_id
	c["profession_id"] = profession_id
	return c


## Whether any validation message mentions this phrase.
func _complains_about(character: Dictionary, phrase: String) -> bool:
	for message in _rules.validate(character):
		if String(message).to_lower().contains(phrase.to_lower()):
			return true
	return false


func _test_the_setting_is_recognised() -> void:
	check_true(_rules.is_dark_matter(_hero("Dark*Matter")), "Dark*Matter is recognised")
	# Saved files carry both spellings, and a strict check would silently apply
	# the core rules to half the campaign.
	check_true(_rules.is_dark_matter(_hero("Dark Matter")), "so is the space-spelled form")
	check_false(_rules.is_dark_matter(_hero("Core")), "Core is not")
	check_false(_rules.is_dark_matter(_hero("Star*Drive")), "neither is Star*Drive")


## Human by default, non-human at the Gamemaster's option -- and not a ban.
##
## The books do not forbid a non-human hero; they assume one is not there and
## hand the decision to the table (p. 51, and Chapter 10 p. 257). So this is a
## note the GM can switch off, not a rule the sheet enforces, and the difference
## matters: an error would have made a legal character look illegal.
func _test_humans_only() -> void:
	var phrase := "belongs to the far-future setting"

	check_false(
		_complains_about(_hero("Dark*Matter", SPECIES_HUMAN), phrase),
		"a Human is at home in Dark*Matter"
	)
	check_true(
		_complains_about(_hero("Dark*Matter", SPECIES_WEREN), phrase),
		"a Weren is questioned"
	)
	check_true(
		_complains_about(_hero("Dark*Matter", 1), phrase),
		"and so is a Fraal, whatever the core rules allow them"
	)

	# The Gamemaster's option, which is what makes it a note rather than a ban.
	var allowed := _hero("Dark*Matter", SPECIES_WEREN)
	_rules.set_optional_rule(allowed, "dm_alien_heroes", true)
	check_false(
		_complains_about(allowed, phrase),
		"and the note goes away once the GM allows alien heroes"
	)

	# Human is unremarkable either way; turning the rule on must not start
	# saying something about a hero it has nothing to say about.
	var human := _hero("Dark*Matter", SPECIES_HUMAN)
	_rules.set_optional_rule(human, "dm_alien_heroes", true)
	check_false(_complains_about(human, phrase), "a Human is still unremarkable with it on")


## "Humans cannot select the dedicated Mindwalker career."
func _test_no_mindwalker_career() -> void:
	check_true(
		_complains_about(_hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_MINDWALKER), "no Mindwalker career"),
		"the Mindwalker career is refused in Dark*Matter"
	)
	check_false(
		_complains_about(_hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC), "no Mindwalker career"),
		"and any other career is fine"
	)


## "They must purchase the Psionic Awareness perk to become a Psionic Talent."
func _test_psionics_come_through_a_perk() -> void:
	var psionic_skill_id := _first_psionic_broad_id()
	if not check(psionic_skill_id >= 0, "a psionic broad skill ships"):
		return

	var without := _hero("Dark*Matter")
	_rules.force_skill_rank(without, psionic_skill_id, 1)
	check_true(
		_complains_about(without, "require the Psionic Awareness perk"),
		"psionic skills without the perk are refused in Dark*Matter"
	)

	var with_perk := _hero("Dark*Matter")
	_rules.force_skill_rank(with_perk, psionic_skill_id, 1)
	_rules.set_perk_selected(with_perk, "psionic_awareness", 3)
	check_false(
		_complains_about(with_perk, "require the Psionic Awareness perk"),
		"and allowed with it"
	)

	# The perk is the Dark*Matter door, not a replacement for the core one: a Core
	# hero still reaches psionics by career, species or the optional rule, and must
	# not start being told to buy a perk.
	var core := _hero("Core")
	_rules.force_skill_rank(core, psionic_skill_id, 1)
	check_false(
		_complains_about(core, "require the Psionic Awareness perk"),
		"a Core hero is never asked for the Dark*Matter perk"
	)


## "Human spellcasters must buy the Faith or Arcane Magic perks to act as FX Talents."
func _test_fx_comes_through_a_perk() -> void:
	var school := _first_fx_broad_name()
	if not check(school != "", "an FX school ships"):
		return

	var without := _hero("Dark*Matter")
	_rules.fx.add_fx_skill(without, school)
	check_true(
		_complains_about(without, "Faith or Arcane Magic perk"),
		"FX without a gateway perk is refused in Dark*Matter"
	)

	for perk_id in AlternityRules.DARK_MATTER_FX_PERKS:
		var allowed := _hero("Dark*Matter")
		_rules.fx.add_fx_skill(allowed, school)
		_rules.set_perk_selected(allowed, String(perk_id), 5)
		check_false(
			_complains_about(allowed, "Faith or Arcane Magic perk"),
			"the %s perk opens FX in Dark*Matter" % String(perk_id)
		)

	# Arcane Magic is Dark*Matter's own perk and must not leak into Core.
	var arcane := _rules.get_perk_by_id("arcane_magic")
	check_true(not arcane.is_empty(), "the Arcane Magic perk ships")
	check_false(_rules.is_entry_available(_hero("Core"), arcane), "and is hidden in Core")
	check_true(_rules.is_entry_available(_hero("Dark*Matter"), arcane), "and offered in Dark*Matter")


## "Ranks are strictly capped at rank 6 in one specialty skill and rank 3 in all others."
func _test_fx_talent_rank_caps() -> void:
	var school := _first_fx_broad_name()
	var specialties: Array = _rules.fx.get_specialty_skills_for_broad(school)
	if not check(specialties.size() >= 2, "the school has at least two spells to compare"):
		return

	var first := String(specialties[0].get("name", ""))
	var second := String(specialties[1].get("name", ""))

	# One above the line is the allowance, so it must not complain.
	var legal := _dm_caster(school)
	_set_fx_rank(legal, first, AlternityRules.DARK_MATTER_FX_TALENT_TOP_RANK)
	_set_fx_rank(legal, second, AlternityRules.DARK_MATTER_FX_TALENT_OTHER_RANK)
	check_false(_complains_about(legal, "may raise one specialty above"), "one specialty may go to rank 6")
	check_false(_complains_about(legal, "may not exceed rank"), "and rank 6 is not itself over the cap")

	# Two above the line is one too many, and the rule is about the set rather
	# than either skill on its own -- both of these are individually legal.
	var greedy := _dm_caster(school)
	_set_fx_rank(greedy, first, AlternityRules.DARK_MATTER_FX_TALENT_TOP_RANK)
	_set_fx_rank(greedy, second, AlternityRules.DARK_MATTER_FX_TALENT_OTHER_RANK + 1)
	check_true(_complains_about(greedy, "may raise one specialty above"), "a second specialty above rank 3 is refused")

	# Nothing may pass rank 6 at all.
	var overreaching := _dm_caster(school)
	_set_fx_rank(overreaching, first, AlternityRules.DARK_MATTER_FX_TALENT_TOP_RANK + 1)
	check_true(_complains_about(overreaching, "may not exceed rank"), "rank 7 is refused outright")

	# The same spread in Core is a matter for the Beyond Science rules, not these.
	var core := _hero("Core")
	_rules.fx.set_fx_talent(core, true)
	_rules.fx.add_fx_skill(core, school)
	_set_fx_rank(core, first, AlternityRules.DARK_MATTER_FX_TALENT_TOP_RANK)
	_set_fx_rank(core, second, AlternityRules.DARK_MATTER_FX_TALENT_OTHER_RANK + 1)
	check_false(_complains_about(core, "Dark*Matter FX talent"), "Core casters are not held to the Dark*Matter caps")


## "FX Talents must pay 1 point more than the listed cost", and the same for psionics.
##
## The psionic surcharge was already in place for every non-Mindwalker, which in
## Dark*Matter is everybody, so that half only needs confirming. The FX half is
## new and must not reach Core, where an Adept still buys at list.
func _test_talent_surcharges() -> void:
	var school := _first_fx_broad_name()
	var listed := AlternityNum.as_int(_rules.fx.get_broad_skill(school).get("cost", 0))
	if not check(listed > 0, "the school has a listed cost"):
		return

	var core := _hero("Core")
	check_eq(_rules.fx.fx_skill_cost(core, school), listed, "a Core caster pays the listed price for a school")

	var dark := _dm_caster(school)
	check_eq(
		_rules.fx.fx_skill_cost(dark, school), listed + AlternityRules.DARK_MATTER_TALENT_SURCHARGE,
		"a Dark*Matter talent pays one point more"
	)

	var specialties: Array = _rules.fx.get_specialty_skills_for_broad(school)
	if specialties.is_empty():
		return
	var spell := String(specialties[0].get("name", ""))
	var spell_listed := AlternityNum.as_int(specialties[0].get("cost", 0))
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(core, spell, 1), spell_listed,
		"and a Core caster pays list for a spell"
	)
	check_eq(
		_rules.fx.fx_skill_cost_for_rank(dark, spell, 1),
		spell_listed + AlternityRules.DARK_MATTER_TALENT_SURCHARGE,
		"where the talent pays one more for the same spell"
	)

	# Psionics: the surcharge predates this work and applies to any non-Mindwalker,
	# so in Dark*Matter -- which has no Mindwalkers at all -- it always applies.
	var psionic_id := _first_psionic_broad_id()
	var psionic_skill := _rules.get_skill_by_id(psionic_id)
	var mindwalker := _hero("Core", SPECIES_HUMAN, PROFESSION_MINDWALKER)
	check_true(
		_rules.skill_cost(_hero("Dark*Matter"), psionic_skill) > _rules.skill_cost(mindwalker, psionic_skill),
		"a Dark*Matter talent pays more for a psionic skill than a Mindwalker does"
	)


## The skills Dark*Matter brings, and where they must not turn up.
##
## Two of them hang under broads every campaign already has -- Cryptography under
## Investigate, Forgery under Creativity -- which is the case a gate on the broad
## alone would miss entirely.
func _test_the_new_skills() -> void:
	var core := _hero("Core")
	var dark := _hero("Dark*Matter")

	var expected := {
		"Lore": "broad",
		"Conspiracy Theories": "specialty",
		"Fringe Science": "specialty",
		"Occult Lore": "specialty",
		"Psychic Lore": "specialty",
		"UFO Lore": "specialty",
		"Cryptography": "specialty",
		"Research": "specialty",
		"Forgery": "specialty",
		"Linguistics": "specialty",
		"Xenoengineering": "specialty",
	}
	for name in expected:
		var skill := _skill_named(String(name))
		if not check(not skill.is_empty(), "%s ships" % name):
			continue
		check_eq(String(skill.get("type", "")), String(expected[name]), "%s is a %s" % [name, expected[name]])
		check_false(_rules.is_entry_available(core, skill), "%s is hidden in Core" % name)
		check_true(_rules.is_entry_available(dark, skill), "%s is offered in Dark*Matter" % name)

	# The costs the setting lists, so a hero is not quietly charged the wrong price.
	check_eq(AlternityNum.as_int(_skill_named("Lore").get("base_price", 0)), 6, "Lore costs 6")
	check_eq(AlternityNum.as_int(_skill_named("Cryptography").get("base_price", 0)), 4, "Cryptography costs 4")
	check_eq(AlternityNum.as_int(_skill_named("Research").get("base_price", 0)), 3, "Research costs 3")
	check_eq(AlternityNum.as_int(_skill_named("Xenoengineering").get("base_price", 0)), 5, "Xenoengineering costs 5")

	# Four of them cannot be attempted by somebody who has never learned them.
	for name in ["Cryptography", "Forgery", "Linguistics", "Xenoengineering"]:
		check_false(bool(_skill_named(String(name)).get("untrained", true)), "%s cannot be used untrained" % name)

	# The specialties that hang under an ungated broad, which is the leak worth
	# naming: Investigate and Creativity are in every campaign.
	check_eq(AlternityNum.as_int(_skill_named("Cryptography").get("broad_id", -1)), 130, "Cryptography sits under Investigate")
	check_eq(AlternityNum.as_int(_skill_named("Forgery").get("broad_id", -1)), 128, "Forgery sits under Creativity")
	check_true(
		_rules.is_entry_available(core, _rules.get_skill_by_id(130)),
		"and Investigate itself is still a Core skill, so the broad cannot be what hides them"
	)


func _skill_named(name: String) -> Dictionary:
	for skill in _rules.skills:
		if String(skill.get("name", "")) == name:
			return skill
	return {}


## The five species Chapter 10 offers, and the two gates in front of them.
##
## "At the Gamemaster's option, other species -- including Greys, kinori,
## mothmen, sandmen, or sasquatch -- may be available to play as heroes."
## (Dark Matter Campaign Setting Chapter 10 p. 257.) So they need the setting and
## the Alien Heroes rule both, and a Core campaign must never see them.
const DM_SPECIES := ["Grey", "Kinori", "Mothman", "Sandman", "Sasquatch"]


func _test_alien_heroes() -> void:
	for name in DM_SPECIES:
		check_true(not _species_named(String(name)).is_empty(), "%s ships" % name)

	# Core: not offered, whatever the optional rule says, because the rule is
	# about Dark*Matter's own species and Core has never heard of them.
	var core := _hero("Core")
	_rules.set_optional_rule(core, "dm_alien_heroes", true)
	for name in DM_SPECIES:
		check_false(_offers_species(core, String(name)), "%s stays out of Core" % name)

	# Dark*Matter without the rule: still not offered.
	var closed := _hero("Dark*Matter")
	for name in DM_SPECIES:
		check_false(_offers_species(closed, String(name)), "%s waits on the GM in Dark*Matter" % name)
	check_true(_offers_species(closed, "Human"), "and Human is offered regardless")

	# Dark*Matter with the rule: all five.
	var open_table := _hero("Dark*Matter")
	_rules.set_optional_rule(open_table, "dm_alien_heroes", true)
	for name in DM_SPECIES:
		check_true(_offers_species(open_table, String(name)), "%s is offered once the GM allows it" % name)

	# A hero already built as one keeps it even if the rule is switched back off.
	# A picker that drops the saved answer writes back index 0 on the next save,
	# so the hero silently becomes a Human.
	var built := _hero("Dark*Matter", AlternityNum.as_int(_species_named("Sasquatch").get("id", -1)))
	check_true(_offers_species(built, "Sasquatch"), "a hero already built as one keeps their species")

	# The numbers that make them different from each other.
	check_eq(_limits("Sandman", "WIL"), [2, 12], "a sandman may have a Will of 2, lower than any other species")
	check_eq(_limits("Sasquatch", "STR"), [9, 16], "a sasquatch is never weak")
	check_eq(_limits("Grey", "CON"), [4, 10], "a Grey is never robust")
	check_eq(_limits("Mothman", "WIL"), [9, 15], "a mothman is never weak-willed")
	check_eq(_limits("Kinori", "DEX"), [9, 14], "a kinori is never clumsy")

	check_eq(float(_species_named("Sasquatch").get("durability_multiplier", 1.0)), 1.5, "a sasquatch is tougher than its CON")
	check_true(bool(_species_named("Mothman").get("can_fly", false)), "a mothman flies")
	for name in ["Grey", "Kinori", "Sandman", "Sasquatch"]:
		check_false(bool(_species_named(String(name)).get("can_fly", false)), "%s does not fly" % name)

	# None of the five gets the human creation bonus.
	for name in DM_SPECIES:
		var sp := _species_named(String(name))
		check_eq(AlternityNum.as_int(sp.get("skill_points", -1)), 0, "%s gets no bonus skill points" % name)
		check_eq(AlternityNum.as_int(sp.get("broad_skills", -1)), 0, "%s gets no bonus broad skill" % name)

	# Greys are psionic on the Fraal pattern: a talent draws full Will where a
	# human talent draws half, and a Mindwalker draws Will and a half.
	var grey := _species_named("Grey")
	check_true(bool(grey.get("psionic", false)), "a Grey is inherently psionic")
	# Compared as numbers: JSON hands these back as floats, so has(901) misses.
	var grey_free: Array = []
	for value in grey.get("free_skill_ids", []):
		grey_free.append(AlternityNum.as_int(value))
	check_true(grey_free.has(901), "and begins with Telepathy")

	var grey_talent := _hero("Dark*Matter", AlternityNum.as_int(grey.get("id", -1)))
	grey_talent["abilities"]["WIL"] = 12
	var human_talent := _hero("Dark*Matter", SPECIES_HUMAN)
	human_talent["abilities"]["WIL"] = 12
	_rules.set_perk_selected(human_talent, "psionic_awareness", 3)
	check_eq(_rules.psionic_energy_points(grey_talent), 12, "a Grey talent draws their full Will")
	check_eq(_rules.psionic_energy_points(human_talent), 6, "where a human talent draws half")


## Enochian, the one arcane school cast entirely on Will.
func _test_enochian() -> void:
	var school := _rules.fx.get_broad_skill("Enochian")
	if not check(not school.is_empty(), "the Enochian school ships"):
		return
	check_eq(String(school.get("ability", "")), "WIL/WIL", "Enochian is cast on Will alone")
	check_eq(AlternityNum.as_int(school.get("cost", 0)), 9, "and costs 9")
	check_eq(String(school.get("category", "")), "Arcane Magic", "and is arcane, not a faith")

	check_false(_rules.is_entry_available(_hero("Core"), school), "it is hidden in Core")
	check_true(_rules.is_entry_available(_hero("Dark*Matter"), school), "and offered in Dark*Matter")

	var spells: Array = _rules.fx.get_specialty_skills_for_broad("Enochian")
	check_eq(spells.size(), 7, "the school has seven spells")
	var by_name: Dictionary = {}
	for spell in spells:
		by_name[String(spell.get("name", ""))] = spell
		check_eq(String(spell.get("ability", "")), "WIL", "%s is cast on Will" % spell.get("name", "?"))

	check_eq(AlternityNum.as_int(by_name.get("Lumen", {}).get("cost", 0)), 2, "Lumen costs 2")
	check_eq(AlternityNum.as_int(by_name.get("White salamander", {}).get("cost", 0)), 4, "White salamander costs 4")
	check_eq(AlternityNum.as_int(by_name.get("White salamander", {}).get("fx_cost", 0)), 2, "and burns 2 FX energy where the rest burn 1")
	check_eq(AlternityNum.as_int(by_name.get("Halo", {}).get("fx_cost", 0)), 1, "Halo burns 1")

	# Six of the seven cannot be attempted by somebody who never learned them.
	var untrained_count := 0
	for spell in spells:
		if bool(spell.get("untrained", false)):
			untrained_count += 1
	check_eq(untrained_count, 1, "only White salamander may be cast untrained")


func _species_named(name: String) -> Dictionary:
	for entry in _rules.species:
		if String(entry.get("name", "")) == name:
			return entry
	return {}


func _offers_species(character: Dictionary, name: String) -> bool:
	for entry in _rules.available_species(character):
		if String(entry.get("name", "")) == name:
			return true
	return false


func _limits(species_name: String, ability: String) -> Array:
	var raw: Array = _species_named(species_name).get("ability_limits", {}).get(ability, [])
	var out: Array = []
	for value in raw:
		out.append(AlternityNum.as_int(value))
	return out


## A school a setting reprints at its own price.
##
## Beyond Science prices Hermeticism at 9 (p. 14, Table F3); Dark*Matter reprints
## it at 10 (Part 2: Arcana p. 74, Table D6). Neither number is wrong, so the
## campaign has to decide -- and the surcharge stacks on top of whichever it is.
func _test_setting_repriced_schools() -> void:
	var core := _hero("Core")
	check_eq(_rules.fx.fx_skill_cost(core, "Hermeticism"), 9, "Beyond Science prices Hermeticism at 9")

	var dark := _dm_caster("Hermeticism")
	check_eq(
		_rules.fx.fx_skill_cost(dark, "Hermeticism"),
		10 + AlternityRules.DARK_MATTER_TALENT_SURCHARGE,
		"Dark*Matter reprints it at 10, and the talent still pays their point on top"
	)

	# A school with no reprint is unaffected in either direction.
	check_eq(
		_rules.fx.fx_skill_cost(core, "Diabolism"),
		AlternityNum.as_int(_rules.fx.get_broad_skill("Diabolism").get("cost", 0)),
		"a school nobody reprinted keeps its listed price in Core"
	)


## Lore is a Free Agent skill, and the discount that goes with that.
##
## "Lore (WIL-based, Cost 6, Pr. F)". The profession code was missing when the
## skill was added, so a Free Agent -- the profession the setting built it for --
## was being charged list price for their own skill, and nothing said so.
func _test_lore_is_a_free_agent_skill() -> void:
	var lore := _skill_named("Lore")
	check_eq(String(lore.get("professions", "")), "F", "Lore is a Free Agent skill")

	const PROFESSION_FREE_AGENT := 4
	var free_agent := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_FREE_AGENT)
	var combat_spec := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC)
	check_eq(_rules.skill_cost(free_agent, lore), 5, "a Free Agent pays 5 for it")
	check_eq(_rules.skill_cost(combat_spec, lore), 6, "and anybody else pays the listed 6")


## "Each FX talent starts with an FX energy pool of 5 points."
##
## Flat, and not the player's to set. The ceiling of 10 is not a second rule --
## the pool may never pass twice its starting value, and twice five is ten.
func _test_fx_energy_pool() -> void:
	var dark := _dm_caster(_first_fx_broad_name())
	# Recorded as something else entirely: the setting still says five.
	_rules.fx.set_energy_pool(dark, 15)
	check_eq(
		_rules.fx.energy_pool(dark), AlternityRules.DARK_MATTER_FX_STARTING_POOL,
		"a Dark*Matter hero starts with 5 whatever the file says"
	)
	check_eq(
		_rules.achievements.fx_energy_pool_increase_limit(dark), 5,
		"and may buy five more, for the ten the setting names"
	)
	# Recorded as a realistic campaign, which is what Dark*Matter is -- and what
	# the generic rules charge 15 a point for. The setting's own price of 10 has
	# to win over that, so the scale is set explicitly here: left at the default
	# heroic, which is also 10, this check would pass with the override deleted.
	_rules.set_fx_campaign_scale(dark, "realistic")
	check_eq(
		_rules.achievements.fx_energy_pool_ap_cost(dark), AlternityRules.DARK_MATTER_FX_POOL_AP_COST,
		"at the setting's 10 achievement points each, not the 15 its scale would charge"
	)

	# Core keeps the recorded pool and the price its campaign scale sets. A
	# realistic Core campaign pays 15 for the same point Dark*Matter sells for 10.
	var core := _hero("Core")
	_rules.fx.set_fx_talent(core, true)
	_rules.fx.set_energy_pool(core, 15)
	check_eq(_rules.fx.energy_pool(core), 15, "a Core hero keeps the pool they recorded")
	_rules.set_fx_campaign_scale(core, "realistic")
	check_eq(_rules.achievements.fx_energy_pool_ap_cost(core), 15, "and a realistic Core campaign pays 15 a point")


## Psionic energy bought with achievement points: from 6th level, three in a life.
func _test_psionic_energy_purchases() -> void:
	var phrase_level := "may not be bought before"
	var phrase_cap := "at most 3 psionic energy points"

	var novice := _hero("Dark*Matter")
	_rules.set_perk_selected(novice, "psionic_awareness", 3)
	check_false(_complains_about(novice, phrase_level), "a hero who has bought none is not questioned")

	novice["psionic_energy_bought"] = 1
	check_true(_complains_about(novice, phrase_level), "buying one at 1st level is refused")

	# Enough achievement points to reach 6th level.
	var veteran := _hero("Dark*Matter")
	_rules.set_perk_selected(veteran, "psionic_awareness", 3)
	veteran["achievement_points"] = _points_for_level(AlternityRules.DARK_MATTER_PEP_PURCHASE_MIN_LEVEL)
	veteran["psionic_energy_bought"] = 3
	check_false(_complains_about(veteran, phrase_level), "at 6th level it is allowed")
	check_false(_complains_about(veteran, phrase_cap), "and three is the allowance, not one over it")

	veteran["psionic_energy_bought"] = 4
	check_true(_complains_about(veteran, phrase_cap), "a fourth is refused")

	# The pool actually grows by what was bought, which is the point of buying it.
	veteran["psionic_energy_bought"] = 3
	veteran["abilities"]["WIL"] = 12
	check_eq(_rules.psionic_energy_points(veteran), 6 + 3, "and the pool is half Will plus what was bought")


func _points_for_level(level: int) -> int:
	for points in range(0, 4000):
		if _rules.achievements.achievement_level_for_points(points) >= level:
			return points
	return 0


## Alien technology is charged for twice: once to work on it, once to use it.
##
## Building or repairing it is Technical Science and always +3 steps, plus a step
## per Progress Level the item stands above the hero. Using it is its own penalty,
## which Xenoengineering reduces rather than removes.
## Source: Dark Matter Campaign Setting Part 1: Player Rules p. 55.
func _test_alien_technology() -> void:
	var dark := _hero("Dark*Matter")
	# Technical Science-invention, -juryrig and -repair: the three the rule names.
	for skill_id in [115, 116, 117]:
		var detail: Dictionary = _rules.skill_detail(_rules.get_skill_by_id(skill_id), dark)
		var found := false
		for note in detail.get("roll_notes", []):
			if String(note).contains("Alien technology") and String(note).contains("+3 steps"):
				found = true
		check_true(found, "%s carries the alien tech penalty" % _rules.skill_name_for_id(skill_id))

	var xeno: Dictionary = _rules.skill_detail(_skill_named("Xenoengineering"), dark)
	var reduces := false
	for note in xeno.get("roll_notes", []):
		if String(note).contains("1, 2 or 3 steps"):
			reduces = true
	check_true(reduces, "Xenoengineering says by how much a success cuts the penalty")


## FX energy and psionic energy are separate pools and stay that way.
##
## A Dark*Matter hero can hold both -- an arcanist who also took Psionic
## Awareness -- and neither pool pays for the other, nor does spending one
## interfere with the other recovering. They are separate fields for that reason,
## and a single "energy" field would have quietly merged them.
## Source: Beyond Science: A Guide to FX pp. 11-12.
func _test_the_two_pools_are_separate() -> void:
	var both := _dm_caster(_first_fx_broad_name())
	_rules.set_perk_selected(both, "psionic_awareness", 3)
	both["abilities"]["WIL"] = 12

	var fx_before: Dictionary = _rules.fx.fx_energy(both)
	var psi_before: Dictionary = _rules.psionic_energy(both)
	check_true(AlternityNum.as_int(fx_before.get("max", 0)) > 0, "the hero has an FX pool")
	check_true(AlternityNum.as_int(psi_before.get("max", 0)) > 0, "and a psionic pool")

	# Spend FX; the psionic pool must not move.
	both["fx"]["energy_used"] = 3
	check_eq(
		AlternityNum.as_int(_rules.psionic_energy(both).get("available", 0)),
		AlternityNum.as_int(psi_before.get("available", 0)),
		"spending FX energy leaves the psionic pool alone"
	)

	# And the other way.
	both["psionic_energy_used"] = 2
	check_eq(
		AlternityNum.as_int(_rules.fx.fx_energy(both).get("available", 0)),
		AlternityNum.as_int(fx_before.get("available", 0)) - 3,
		"and spending psionic energy leaves the FX pool where the FX spend left it"
	)


## What each species brings to creation, and what it does not.
##
## Humans get 5 skill points and a broad skill of their own choosing; that is the
## whole of their species benefit, and it is why they get one. Nobody else gets
## either -- an alien hero is limited to the fixed free skills their species is
## born with.
## Source: Player's Handbook pp. 33-34; Dark Matter Campaign Setting Chapter 10.
func _test_species_creation_budgets() -> void:
	for entry in _rules.species:
		var name := String(entry.get("name", ""))
		var points := AlternityNum.as_int(entry.get("skill_points", 0))
		var broads := AlternityNum.as_int(entry.get("broad_skills", 0))
		if name == "Human":
			check_eq(points, 5, "a Human brings 5 extra skill points")
			check_eq(broads, 1, "and one broad skill of their choosing")
		else:
			check_eq(points, 0, "%s brings no extra skill points" % name)
			check_eq(broads, 0, "and no broad skill of their choosing" % [])
		# Every species begins with a fixed handful, chosen for them.
		check_true(
			(entry.get("free_skill_ids", []) as Array).size() >= 6,
			"%s begins with its own free skills" % name
		)


## The gate, checked from the other side.
##
## An ordinary Core hero must produce none of this setting's messages. If any of
## them leaks, a table that has never opened the book starts being told their
## character is illegal.
func _test_core_is_untouched() -> void:
	for setting in ["Core", "Star*Drive"]:
		var hero := _hero(setting, SPECIES_WEREN, PROFESSION_MINDWALKER)
		for phrase in [
			"belongs to the far-future setting",
			"no Mindwalker career",
			"require the Psionic Awareness perk",
			"Faith or Arcane Magic perk",
			"Dark*Matter FX talent",
		]:
			check_false(
				_complains_about(hero, phrase),
				"%s hears nothing about '%s'" % [setting, phrase]
			)


func _dm_caster(school: String) -> Dictionary:
	var c := _hero("Dark*Matter")
	_rules.set_perk_selected(c, "arcane_magic", 5)
	_rules.fx.set_fx_talent(c, true)
	_rules.fx.add_fx_skill(c, school)
	return c


func _set_fx_rank(character: Dictionary, skill_name: String, rank: int) -> void:
	character["fx"]["selected_skills"][skill_name] = rank


func _first_psionic_broad_id() -> int:
	for skill in _rules.skills:
		if _rules.is_psionic_skill(skill) and String(skill.get("type", "")) == "broad":
			return AlternityNum.as_int(skill.get("id", -1), -1)
	return -1


func _first_fx_broad_name() -> String:
	for broad in _rules.fx.get_broad_skills():
		var name := String(broad.get("name", ""))
		# A school with no setting of its own, so the test is about the talent
		# rules rather than about which book the school came from.
		if String(broad.get("setting", "")).is_empty() and not name.is_empty():
			return name
	return ""


## Mutants in Dark*Matter: no Amazing advantages or Extreme drawbacks (p. 73).
func _test_dark_matter_mutant_restrictions() -> void:
	var dm_mutant := _hero("Dark*Matter", 6)
	var core_mutant := _hero("Core", 6)

	var amazing_mut := {"id": "test_amazing", "tier": "Amazing", "type": "advantage"}
	var good_mut := {"id": "test_good", "tier": "Good", "type": "advantage"}
	var extreme_drawback := {"id": "test_extreme", "tier": "Extreme", "type": "drawback"}
	var ordinary_drawback := {"id": "test_ord", "tier": "Ordinary", "type": "drawback"}

	check_false(_rules.is_entry_available(dm_mutant, amazing_mut), "Amazing advantage is not available in Dark*Matter")
	check_true(_rules.is_entry_available(core_mutant, amazing_mut), "Amazing advantage is available in Core")
	check_true(_rules.is_entry_available(dm_mutant, good_mut), "Good advantage is available in Dark*Matter")

	check_false(_rules.is_entry_available(dm_mutant, extreme_drawback), "Extreme drawback is not available in Dark*Matter")
	check_true(_rules.is_entry_available(core_mutant, extreme_drawback), "Extreme drawback is available in Core")
	check_true(_rules.is_entry_available(dm_mutant, ordinary_drawback), "Ordinary drawback is available in Dark*Matter")

	# Validation complaint if Dark*Matter mutant holds Amazing advantage or Extreme drawback
	var invalid_dm := _hero("Dark*Matter", 6)
	for m in _rules.mutation_advantages:
		if String(m.get("tier", "")) == "Amazing":
			invalid_dm["mutations"]["advantages"].append(String(m.get("id", "")))
			break
	check_true(
		_complains_about(invalid_dm, "restricted to Ordinary and Good"),
		"Dark*Matter mutant with Amazing advantage fails validation"
	)
	var core_with_amazing := _hero("Core", 6)
	core_with_amazing["mutations"]["advantages"] = invalid_dm["mutations"]["advantages"].duplicate()
	check_false(
		_complains_about(core_with_amazing, "restricted to Ordinary and Good"),
		"Core mutant with Amazing advantage is permitted"
	)


## Incantation Faith FX: Sasquatch only (Dark Matter p. 226).
func _test_incantation_sasquatch_gating() -> void:
	var sasquatch := _hero("Dark*Matter", 11)
	var human := _hero("Dark*Matter", SPECIES_HUMAN)
	var grey := _hero("Dark*Matter", AlternityNum.as_int(_species_named("Grey").get("id", -1)))

	var incantation := _rules.fx.get_broad_skill("Incantation")
	check_true(not incantation.is_empty(), "Incantation exists")
	check_true(_rules.is_entry_available(sasquatch, incantation), "Incantation is available to Sasquatch")
	check_false(_rules.is_entry_available(human, incantation), "Incantation is not available to Human")
	check_false(_rules.is_entry_available(grey, incantation), "Incantation is not available to Grey")

	var miracles: Array = _rules.fx.get_specialty_skills_for_broad("Incantation")
	check_eq(miracles.size(), 4, "Incantation has 4 miracles")
	for m in miracles:
		check_true(_rules.is_entry_available(sasquatch, m), "%s available to Sasquatch" % m.get("name", ""))
		check_false(_rules.is_entry_available(human, m), "%s hidden from Human" % m.get("name", ""))

	# Validation complains if non-Sasquatch holds Incantation
	var illegal_human := _hero("Dark*Matter", SPECIES_HUMAN)
	_rules.fx.add_fx_skill(illegal_human, "Incantation")
	check_true(
		_complains_about(illegal_human, "Only Sasquatch"),
		"Human holding Incantation fails validation"
	)


## Untrained FX in Dark*Matter rolls as feat check using specialty ability (Dark Matter p. 75).
func _test_dark_matter_untrained_fx_feat_check() -> void:
	var caster := _dm_caster("Enochian")
	caster["abilities"]["WIL"] = 14
	# White salamander is untrained: true under Enochian (WIL)
	var ws_score: Dictionary = _rules.fx.fx_skill_score(caster, "White salamander")
	check_true(bool(ws_score.get("usable", false)), "White salamander is usable untrained")
	check_true(bool(ws_score.get("via_broad", false)), "rolled via broad")
	check_eq(AlternityNum.as_int(ws_score.get("ordinary", 0)), 14, "ordinary target is full Will score 14")
	check_eq(AlternityNum.as_int(ws_score.get("step", 0)), 1, "base feat check die is +d4 (step 1)")

	# Lumen is untrained: false, so cannot be used untrained
	var lumen_score: Dictionary = _rules.fx.fx_skill_score(caster, "Lumen")
	check_false(bool(lumen_score.get("usable", true)), "Lumen cannot be used untrained")


## Setting skills: Social Science, Anthropology, History, Linguistics, Net Savvy, Journalism, Photography.
func _test_social_science_and_setting_skills() -> void:
	var core := _hero("Core")
	var dm := _hero("Dark*Matter")

	var ss := _skill_named("Social Science")
	check_true(not ss.is_empty(), "Social Science ships")
	check_eq(String(ss.get("stat", "")), "INT", "Social Science is INT-based")
	check_eq(AlternityNum.as_int(ss.get("base_price", 0)), 6, "Social Science costs 6")
	check_eq(String(ss.get("professions", "")), "DT", "Social Science is Diplomat/Tech Op")
	check_false(_rules.is_entry_available(core, ss), "Social Science is hidden in Core")
	check_true(_rules.is_entry_available(dm, ss), "Social Science is available in Dark*Matter")

	var anthro := _skill_named("Anthropology")
	check_true(not anthro.is_empty(), "Anthropology ships")
	check_eq(AlternityNum.as_int(anthro.get("broad_id", -1)), 176, "Anthropology sits under Social Science")
	check_eq(AlternityNum.as_int(anthro.get("base_price", 0)), 3, "Anthropology costs 3")
	check_false(_rules.is_entry_available(core, anthro), "Anthropology is hidden in Core")
	check_true(_rules.is_entry_available(dm, anthro), "Anthropology is available in Dark*Matter")

	var hist := _skill_named("History")
	check_true(not hist.is_empty(), "History ships")
	check_eq(AlternityNum.as_int(hist.get("broad_id", -1)), 176, "History sits under Social Science")
	check_eq(AlternityNum.as_int(hist.get("base_price", 0)), 3, "History costs 3")
	check_false(_rules.is_entry_available(core, hist), "History is hidden in Core")
	check_true(_rules.is_entry_available(dm, hist), "History is available in Dark*Matter")

	var ling := _skill_named("Linguistics")
	check_true(not ling.is_empty(), "Linguistics ships")
	check_eq(AlternityNum.as_int(ling.get("broad_id", -1)), 176, "Linguistics sits under Social Science")
	check_false(bool(ling.get("untrained", true)), "Linguistics cannot be used untrained")
	check_false(_rules.is_entry_available(core, ling), "Linguistics is hidden in Core")
	check_true(_rules.is_entry_available(dm, ling), "Linguistics is available in Dark*Matter")

	var net_savvy := _skill_named("Net Savvy")
	check_true(not net_savvy.is_empty(), "Net Savvy ships")
	check_eq(AlternityNum.as_int(net_savvy.get("broad_id", -1)), 137, "Net Savvy sits under Street Smart")
	check_eq(AlternityNum.as_int(net_savvy.get("base_price", 0)), 3, "Net Savvy costs 3")
	check_eq(String(net_savvy.get("professions", "")), "FT", "Net Savvy is Free Agent/Tech Op")
	check_false(_rules.is_entry_available(core, net_savvy), "Net Savvy is hidden in Core")
	check_true(_rules.is_entry_available(dm, net_savvy), "Net Savvy is available in Dark*Matter")

	var journ := _skill_named("Journalism")
	check_true(not journ.is_empty(), "Journalism ships")
	check_eq(AlternityNum.as_int(journ.get("broad_id", -1)), 128, "Journalism sits under Creativity")
	check_eq(AlternityNum.as_int(journ.get("base_price", 0)), 1, "Journalism costs 1")
	check_false(_rules.is_entry_available(core, journ), "Journalism is hidden in Core")
	check_true(_rules.is_entry_available(dm, journ), "Journalism is available in Dark*Matter")

	var photo := _skill_named("Photography")
	check_true(not photo.is_empty(), "Photography ships")
	check_eq(AlternityNum.as_int(photo.get("broad_id", -1)), 128, "Photography sits under Creativity")
	check_eq(AlternityNum.as_int(photo.get("base_price", 0)), 1, "Photography costs 1")
	check_false(_rules.is_entry_available(core, photo), "Photography is hidden in Core")
	check_true(_rules.is_entry_available(dm, photo), "Photography is available in Dark*Matter")

	# Profession discounts
	const PROFESSION_DIPLOMAT := 1
	var dip := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_DIPLOMAT)
	check_eq(_rules.skill_cost(dip, ss), 5, "a Diplomat pays 5 for Social Science")
	check_eq(_rules.skill_cost(dip, anthro), 2, "a Diplomat pays 2 for Anthropology")


## Career packages catalog, dynamic cost calculations, and application.
func _test_career_packages() -> void:
	var dm := _hero("Dark*Matter")
	var core := _hero("Core")

	var dm_pkgs := _rules.available_career_packages(dm)
	var core_pkgs := _rules.available_career_packages(core)
	check_true(dm_pkgs.size() >= 6, "Dark*Matter has access to career packages")
	check_true(core_pkgs.size() >= 1, "Core has access to core career packages")

	# Verify canonical cost calculation
	var mercenary := _rules.get_career_package_by_id("mercenary")
	check_true(not mercenary.is_empty(), "Mercenary package ships")
	var merc_hero := _hero("Core", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC)
	check_eq(_rules.career_package_cost(merc_hero, mercenary), 25, "Mercenary costs 25 SP")

	var sof := _rules.get_career_package_by_id("soldier_of_fortune")
	check_true(not sof.is_empty(), "Soldier of Fortune package ships")
	var sof_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC)
	check_eq(_rules.career_package_cost(sof_hero, sof), 32, "Soldier of Fortune costs 32 SP")

	var sec := _rules.get_career_package_by_id("corporate_security_specialist")
	check_true(not sec.is_empty(), "Corporate Security Specialist package ships")
	var sec_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC)
	check_eq(_rules.career_package_cost(sec_hero, sec), 30, "Corporate Security Specialist costs 30 SP")

	var forensics := _rules.get_career_package_by_id("forensics_expert")
	check_true(not forensics.is_empty(), "Forensics Expert package ships")
	const PROFESSION_TECH_OP := 2
	var fore_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_TECH_OP)
	check_eq(_rules.career_package_cost(fore_hero, forensics), 42, "Forensics Expert costs 42 SP")

	var xeno := _rules.get_career_package_by_id("xenoengineer")
	check_true(not xeno.is_empty(), "Xenoengineer package ships")
	var xeno_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_TECH_OP)
	check_eq(_rules.career_package_cost(xeno_hero, xeno), 45, "Xenoengineer costs 45 SP")

	var gadget := _rules.get_career_package_by_id("gadgeteer")
	check_true(not gadget.is_empty(), "Gadgeteer package ships")
	var gad_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_TECH_OP)
	check_eq(_rules.career_package_cost(gad_hero, gadget), 36, "Gadgeteer costs 36 SP")

	var occ := _rules.get_career_package_by_id("occultist")
	check_true(not occ.is_empty(), "Occultist package ships")
	const PROFESSION_DIPLOMAT := 1
	var occ_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_DIPLOMAT)
	check_eq(_rules.career_package_cost(occ_hero, occ, 0), 38, "Occultist (Alchemist) costs 38 SP")

	# Test apply_career_package
	var applied_hero := _hero("Dark*Matter", SPECIES_HUMAN, PROFESSION_COMBAT_SPEC)
	var res := _rules.apply_career_package(applied_hero, "soldier_of_fortune")
	check_true(bool(res.get("ok", false)), "apply_career_package succeeds")
	check_eq(String(applied_hero.get("career", "")), "Soldier of Fortune", "career name is set")
	var pistol := _rules.get_skill_by_name("Pistol")
	var mrw := _rules.get_skill_by_name("Modern Ranged Weapons")
	check_true(_rules.skill_rank(applied_hero, AlternityNum.as_int(pistol.get("id"))) >= 1, "Pistol rank is at least 1")
	check_true(_rules.skill_rank(applied_hero, AlternityNum.as_int(mrw.get("id"))) >= 1, "Modern Ranged Weapons broad is held")


## Requisition Subsystem (Arms & Equipment Guide p. 5).
func _test_requisition_subsystem() -> void:
	# Step modifier tests
	check_eq(_rules.requisition_step_modifier({"availability": "Common"}), 0, "Common availability +0")
	check_eq(_rules.requisition_step_modifier({"availability": "Controlled"}), 1, "Controlled availability +1")
	check_eq(_rules.requisition_step_modifier({"availability": "Military"}), 2, "Military availability +2")
	check_eq(_rules.requisition_step_modifier({"availability": "Restricted"}), 3, "Restricted availability +3")

	check_eq(_rules.requisition_step_modifier({"urgency": "standard"}), 0, "standard urgency +0")
	check_eq(_rules.requisition_step_modifier({"urgency": "short_notice"}), 1, "short notice +1")
	check_eq(_rules.requisition_step_modifier({"urgency": "emergency"}), 2, "emergency +2")
	check_eq(_rules.requisition_step_modifier({"urgency": "advance"}), -1, "advance -1")

	check_eq(_rules.requisition_step_modifier({"necessity": "useful"}), 0, "useful +0")
	check_eq(_rules.requisition_step_modifier({"necessity": "essential"}), -2, "essential -2")
	check_eq(_rules.requisition_step_modifier({"necessity": "luxury"}), 2, "luxury +2")

	var combo := _rules.requisition_step_modifier({
		"availability": "Military", # +2
		"urgency": "short_notice",  # +1
		"necessity": "essential"    # -2
	})
	check_eq(combo, 1, "Combined options sum correctly: 2 + 1 - 2 = 1")

	# Check score calculation
	var hero := _hero("Dark*Matter")
	hero["abilities"]["WIL"] = 14
	var score_info := _rules.requisition_check_score(hero, {"availability": "Common"})
	check_eq(AlternityNum.as_int(score_info.get("ordinary", 0)), 14, "untrained fallback uses WIL feat score 14")
	check_eq(AlternityNum.as_int(score_info.get("step", 0)), 1, "base feat check step is 1 (+d4)")

	# Resolution
	var outcome := _rules.resolve_requisition_check(hero, 5, 2, {"availability": "Common"})
	check_true(outcome.has("degree"), "returns degree")
	check_true(outcome.has("outcome_description"), "returns outcome description")


## Investigate Modifiers (Player's Handbook p. 93).
func _test_investigate_modifiers() -> void:
	# Freshness
	check_eq(_rules.investigate_step_modifier({"freshness": "fresh"}), -1, "fresh -1")
	check_eq(_rules.investigate_step_modifier({"freshness": "recent"}), 0, "recent freshness +0")
	check_eq(_rules.investigate_step_modifier({"freshness": "days_old"}), 2, "days old +2")
	check_eq(_rules.investigate_step_modifier({"freshness": "old"}), 4, "old +4")

	# Site condition
	check_eq(_rules.investigate_step_modifier({"site": "undisturbed"}), 0, "undisturbed site +0")
	check_eq(_rules.investigate_step_modifier({"site": "disturbed"}), 2, "disturbed site +2")

	# Clue size
	check_eq(_rules.investigate_step_modifier({"clue": "obvious"}), -2, "obvious clue -2")
	check_eq(_rules.investigate_step_modifier({"clue": "standard"}), 0, "standard clue +0")
	check_eq(_rules.investigate_step_modifier({"clue": "small"}), 2, "small clue +2")
	check_eq(_rules.investigate_step_modifier({"clue": "concealed"}), 4, "concealed clue +4")

	# Cumulative across groups
	var cumulative := _rules.investigate_step_modifier({
		"freshness": "days_old", # +2
		"clue": "small",         # +2
		"site": "disturbed",     # +2
	})
	check_eq(cumulative, 6, "groups are cumulative: 2 + 2 + 2 = 6")

	# Related skill reductions
	check_eq(_rules.investigate_step_modifier({}, 1), -1, "rank 1-4 gives -1 step")
	check_eq(_rules.investigate_step_modifier({}, 4), -1, "rank 4 gives -1 step")
	check_eq(_rules.investigate_step_modifier({}, 5), -2, "rank 5-8 gives -2 steps")
	check_eq(_rules.investigate_step_modifier({}, 8), -2, "rank 8 gives -2 steps")
	check_eq(_rules.investigate_step_modifier({}, 9), -3, "rank 9-12 gives -3 steps")
	check_eq(_rules.investigate_step_modifier({}, 12), -3, "rank 12 gives -3 steps")


## Contacts and Allegiances (Table D8, Dark Matter p. 245).
func _test_contacts_allegiances() -> void:
	check_eq(_rules.contact_step_modifier({"favor": "area_of_expertise"}), -1, "area of expertise -1")
	check_eq(_rules.contact_step_modifier({"favor": "close_ally"}), -1, "close ally -1")
	check_eq(_rules.contact_step_modifier({"favor": "casual"}), 0, "casual favor +0")
	check_eq(_rules.contact_step_modifier({"favor": "high_risk"}), 2, "high risk favor +2")
	check_eq(_rules.contact_step_modifier({"favor": "extreme_danger"}), 4, "extreme danger favor +4")
	check_eq(_rules.contact_step_modifier({"abused_penalty": 2}), 2, "abused contact adds +2 steps")

	var check_res := _rules.resolve_contact_check(6, 1, 12, {"favor": "casual"})
	check_true(check_res.has("degree"), "returns degree")
	check_true(check_res.has("outcome_description"), "returns outcome description")
