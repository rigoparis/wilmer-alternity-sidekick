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
