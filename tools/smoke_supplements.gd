extends "res://tools/test_harness.gd"
##
## Supplement books, and why they are not settings.
##
## A setting is one-of and says what world the hero is in. A supplement is a book
## the table owns, any number of them, in any setting. They were originally the
## same field, which made Dataware unreachable -- nothing can select "Dataware" as
## its setting, so its twenty robot perks had never been visible to anybody.
##
## The failure mode is silent in both directions: a supplement that is wrongly on
## offers content the table does not own, and one that is wrongly off removes
## content a hero already has. The second is the dangerous one, because Beyond
## Science carries nineteen of the app's twenty-one FX schools.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")

var _rules: AlternityRules


func _init() -> void:
	begin("supplements")

	_rules = RulesScript.new()
	_rules.load_core_data()

	_test_defaults()
	_test_older_saves_keep_their_content()
	_test_beyond_science_owns_the_fx_catalog()
	_test_dataware_is_reachable_at_all()
	_test_independent_of_setting()

	finish()


func _character() -> Dictionary:
	var doc := Doc.new(_rules)
	return doc.raw()


## Beyond Science on, Dataware off, and each for its own reason.
func _test_defaults() -> void:
	var hero := _character()

	check_true(
		_rules.supplement_enabled(hero, "beyond_science"),
		"Beyond Science is on by default -- its FX catalog has always been offered"
	)
	check_false(
		_rules.supplement_enabled(hero, "dataware"),
		"Dataware is off by default -- none of its content has ever been visible"
	)
	check_false(
		_rules.supplement_enabled(hero, "a_book_nobody_wrote"),
		"an unknown supplement is off rather than on"
	)

	# Every declared supplement has to be written onto the character, or the
	# screen that toggles them would show a state the file does not hold.
	var stored: Dictionary = hero.get("supplements", {})
	for supplement in AlternityRules.SUPPLEMENTS:
		check_true(
			stored.has(String(supplement.get("id", ""))),
			"%s is recorded on a new character" % String(supplement.get("id", ""))
		)


## The migration case, and the one that would have hurt.
##
## Every saved character predates this field. Reading that silence as "off" would
## take nineteen FX schools away from every existing hero the first time they were
## loaded, and nothing would have errored.
func _test_older_saves_keep_their_content() -> void:
	var legacy := {"hero_name": "Saved Before Supplements", "setting": "Core"}
	_rules.ensure_character_shape(legacy)

	check_true(
		_rules.supplement_enabled(legacy, "beyond_science"),
		"a character saved before the field existed still has Beyond Science"
	)
	check_false(
		_rules.supplement_enabled(legacy, "dataware"),
		"and still does not have Dataware"
	)

	# An explicit false is an answer, not an absence, and must survive the shape pass.
	var refused := {"hero_name": "No Magic Here", "supplements": {"beyond_science": false}}
	_rules.ensure_character_shape(refused)
	check_false(
		_rules.supplement_enabled(refused, "beyond_science"),
		"a supplement deliberately turned off is not turned back on by ensure_character_shape"
	)


## Turning the book off takes the schools with it, which is the whole point.
func _test_beyond_science_owns_the_fx_catalog() -> void:
	var hero := _character()

	var with_book: Array = _rules.fx.get_broad_skills_for_character(hero)
	check_true(with_book.size() > 15, "Beyond Science supplies most of the FX catalog (%d schools)" % with_book.size())

	_rules.set_supplement(hero, "beyond_science", false)
	var without_book: Array = _rules.fx.get_broad_skills_for_character(hero)
	check_true(
		without_book.size() < with_book.size(),
		"turning Beyond Science off removes its schools (%d left of %d)" % [without_book.size(), with_book.size()]
	)

	# Specialties go with their school rather than lingering as orphans.
	var orphaned := 0
	for broad in _rules.fx.get_broad_skills():
		if String(broad.get("supplement", "")) != "beyond_science":
			continue
		orphaned += _rules.fx.get_specialty_skills_for_broad_and_character(String(broad.get("name", "")), hero).size()
	check_eq(orphaned, 0, "no Beyond Science spell survives its school being put away")

	_rules.set_supplement(hero, "beyond_science", true)
	check_eq(
		_rules.fx.get_broad_skills_for_character(hero).size(), with_book.size(),
		"putting the book back restores exactly what it took"
	)


## The bug this concept exists to fix: content nobody could ever see.
func _test_dataware_is_reachable_at_all() -> void:
	var hero := _character()

	var dataware_entries: Array = []
	for entry in _rules.perks_by_id.values() + _rules.flaws_by_id.values():
		if String(entry.get("supplement", "")) == "dataware":
			dataware_entries.append(entry)
	check_true(dataware_entries.size() > 0, "the robot perks and flaws ship (%d of them)" % dataware_entries.size())

	for entry in dataware_entries:
		if not check_false(_rules.is_entry_available(hero, entry), "%s is hidden without the book" % String(entry.get("id", ""))):
			break

	_rules.set_supplement(hero, "dataware", true)
	for entry in dataware_entries:
		if not check_true(_rules.is_entry_available(hero, entry), "%s appears once the book is on the table" % String(entry.get("id", ""))):
			break


## The two gates are independent, and an entry may carry either or neither.
func _test_independent_of_setting() -> void:
	var core := _character()
	var dark := _character()
	dark["setting"] = "Dark*Matter"

	# A supplement entry does not care which setting is being played.
	var robot := {"id": "r", "supplement": "dataware"}
	_rules.set_supplement(core, "dataware", true)
	_rules.set_supplement(dark, "dataware", true)
	check_true(_rules.is_entry_available(core, robot), "a Dataware perk works in Core")
	check_true(_rules.is_entry_available(dark, robot), "and in Dark*Matter")

	# A setting entry does not care which books are out. Incantation is
	# Dark*Matter's own school and carries no supplement tag, so it must survive
	# Beyond Science being put away.
	var incantation := _rules.fx.get_broad_skill("Incantation")
	check_true(not incantation.is_empty(), "the Incantation school ships")
	check_eq(String(incantation.get("supplement", "")), "", "Dark*Matter's own school belongs to no supplement")

	_rules.set_supplement(dark, "beyond_science", false)
	check_true(
		_rules.is_entry_available(dark, incantation),
		"Dark*Matter keeps its own FX with Beyond Science off"
	)
	check_false(
		_rules.is_entry_available(core, incantation),
		"and Core still does not get it with Beyond Science on"
	)
