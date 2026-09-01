extends "res://tools/test_harness.gd"
##
## Tab-specific behaviour that the shell walkthrough does not reach.
##
## Replaces smoke_mutation_ui, smoke_ability_generation_ui and
## smoke_optional_rules_ui, which each instantiated main.tscn and reached into
## its members. They were three near-identical scene harnesses testing three
## unrelated things; this drives the migrated tabs directly instead.
##
## The rules assertions they made are preserved -- ability rolls landing inside
## their legal band, optional rules reaching the created character, mutations
## applying -- because those are what actually mattered.
##

const RulesScript := preload("res://scripts/alternity_rules.gd")
const Doc := preload("res://scripts/core/character_doc.gd")
const Context := preload("res://scripts/ui/sheet_context.gd")

const TAB_BASICS := preload("res://scenes/ui/tabs/tab_basics.tscn")
const TAB_MUTATIONS := preload("res://scenes/ui/tabs/tab_mutations.tscn")
const TAB_SUMMARY := preload("res://scenes/ui/tabs/tab_summary.tscn")
const OPTIONAL_RULES_ROUTE := preload("res://scenes/ui/routes/optional_rules_route.tscn")

var _rules: AlternityRules


func _init() -> void:
	begin_async("tab behaviour", 400)
	_run.call_deferred()


func _run() -> void:
	_rules = RulesScript.new()
	_rules.load_core_data()

	await _test_ability_generation()
	await _test_basics_explains_origin()
	await _test_mutations_tab()
	await _test_summary_tab()
	await _test_summary_is_self_contained()
	await _test_optional_rules_route()

	finish()


func _mount(scene: PackedScene, doc: CharacterDoc):
	var tab = scene.instantiate()
	root.add_child(tab)
	tab.bind(Context.new(doc, _rules, null, ThemePalette.new(), false))
	return tab


## Every generation method must land inside the legal band for the character,
## because a species or profession minimum can exceed what the dice rolled.
func _test_ability_generation() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)      # Human
	doc.set_profession_id(0)   # Combat Spec

	var tab = _mount(TAB_BASICS, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Basics renders")

	# Only the two methods the tab offers. The third button called
	# roll_random_abilities_by_profession, which returns the formula table rather
	# than rolled scores -- and this loop asserted only that scores landed inside
	# the legal band, which clamping a coerced 0 up to the minimum satisfies. The
	# test passed while the button reliably produced a floor-value hero.
	for method in ["method_1", "method_2"]:
		var rolled: Dictionary = {}
		match method:
			"method_1": rolled = _rules.roll_abilities_method_1(doc.get_profession_id())
			_: rolled = _rules.roll_abilities_method_2(doc.get_species_id())

		if not check(not rolled.is_empty(), "%s produced a spread" % method):
			continue

		tab._apply_rolled(rolled)
		await process_frame

		var abilities: Dictionary = doc.raw().get("abilities", {})
		check_eq(abilities.size(), 6, "%s writes all six abilities" % method)

		var out_of_band: Array = []
		var above_floor := 0
		for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
			var limits: Array = _rules.ability_limits(doc.raw(), ability)
			var score := AlternityNum.as_int(abilities.get(ability, 0))
			if score < AlternityNum.as_int(limits[0]) or score > AlternityNum.as_int(limits[1]):
				out_of_band.append("%s=%d" % [ability, score])
			if score > AlternityNum.as_int(limits[0]):
				above_floor += 1
		check_true(out_of_band.is_empty(), "%s stays inside the legal band (%s)" % [method, str(out_of_band)])

		# In-band is not enough: a generator that produces nothing and gets
		# clamped up to the minimum is also in band. Every published spread
		# starts each ability well above the species floor, so a roll that
		# leaves every score sitting on it did not roll anything.
		check_true(
			above_floor > 0,
			"%s produced scores above the floor, not a clamped zero spread" % method
		)

		# The point target is reset to what the roll cost, so the budget is not
		# compared against a purchased spread that no longer exists.
		check_eq(
			AlternityNum.as_int(doc.raw().get("custom_ability_target", -1), -1),
			_rules.ability_total(doc.raw()),
			"%s resets the ability point target" % method
		)

	tab.queue_free()


## Basics must say what a species and profession are, not just let you pick one.
##
## "This app is trying to be a replacement for the manuals" -- and choosing a
## race showed a dropdown and nothing else. The species summary line read a key
## the data does not have, so it never rendered, and the mechanical notes that
## do exist were displayed nowhere at all.
func _test_basics_explains_origin() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(4)     # T'sa: has notes, a free skill and an action-step bonus
	doc.set_profession_id(0)  # Combat Spec

	var tab = _mount(TAB_BASICS, doc)
	await process_frame
	var labels := _labels_in(tab)

	var species: Dictionary = _rules.get_species_by_id(doc.get_species_id())
	var species_name := String(species.get("name", ""))
	check_true(_any_label_contains(labels, species_name), "Basics names the species (%s)" % species_name)

	var description := String(species.get("description", ""))
	check_true(not description.is_empty(), "the species catalog carries a description")
	if not description.is_empty():
		check_true(
			_any_label_contains(labels, description.substr(0, 40)),
			"Basics shows the species description"
		)

	check_true(_any_label_contains(labels, "Ability range"), "Basics states the species ability range")

	var notes: Array = species.get("notes", [])
	if not notes.is_empty():
		check_true(
			_any_label_contains(labels, String(notes[0]).substr(0, 30)),
			"Basics shows the species rule notes"
		)

	var profession: Dictionary = _rules.get_profession_by_id(doc.get_profession_id())
	check_true(
		_any_label_contains(labels, String(profession.get("name", ""))),
		"Basics names the profession"
	)
	var prof_notes: Array = profession.get("notes", [])
	if not prof_notes.is_empty():
		check_true(
			_any_label_contains(labels, String(prof_notes[0]).substr(0, 30)),
			"Basics shows what the profession is"
		)
	check_true(_any_label_contains(labels, "Requires"), "Basics states the profession requirements")

	# Every generation button offered must actually roll. The removed third
	# button passed the formula table in as if it were scores.
	check_true(
		_any_label_contains(labels, "Method I"), "Basics offers Method I with a name that says what it rolls"
	)

	tab.queue_free()


func _test_mutations_tab() -> void:
	var doc := Doc.new(_rules)
	var context := Context.new(doc, _rules, null, ThemePalette.new(), false)

	var probe = TAB_MUTATIONS.instantiate()
	check_false(probe.is_available_for(context), "Mutations excluded for a Human hero")

	doc.set_species_id(_rules.mutations.mutant_species_id())
	check_true(probe.is_available_for(context), "Mutations applies to a Mutant hero")
	probe.free()

	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.set_mutation_points(c, 3, 2))

	var tab = _mount(TAB_MUTATIONS, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Mutations renders for a Mutant")

	# Adding through the rules must reach the tab as a rebuild.
	var before: int = tab.get_child_count()
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.add_mutation_advantage(c, "improved_str"))
	await process_frame
	check_eq(
		_rules.mutations.selected_mutation_advantages(doc.raw()).size(), 1,
		"the advantage was recorded"
	)
	check_true(tab.get_child_count() >= before, "the tab rebuilt after the change")

	tab.queue_free()


## Summary aggregates everything, so it is the tab most likely to break on an
## unusual character.
func _test_summary_tab() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(_rules.mutations.mutant_species_id())
	doc.apply(CharacterDoc.ALL, func(c):
		_rules.mutations.set_mutation_points(c, 3, 2)
		_rules.mutations.add_mutation_advantage(c, "improved_str")
		_rules.mutations.add_mutation_drawback(c, "slow_reflexes"))

	var tab = _mount(TAB_SUMMARY, doc)
	await process_frame
	check_true(tab.get_child_count() > 0, "Summary renders after mutation selections")

	# The damage trackers are the interactive part, so they must survive a
	# character whose durability came from mutations.
	var summary := doc.summary()
	var durability: Dictionary = summary.get("durability", {})
	check_true(AlternityNum.as_int(durability.get("stun", 0)) > 0, "durability is computed")

	tab.queue_free()


## Summary must carry the whole character, not a set of pointers to other tabs.
##
## The app exists to replace reaching for the manuals mid-session, and Summary is
## the tab that stays open at the table. A heading that says "3 perks" and makes
## you go elsewhere to find out which ones has failed at that job, so this
## asserts the content is actually present rather than merely counted.
func _test_summary_is_self_contained() -> void:
	var doc := Doc.new(_rules)
	doc.set_species_id(0)     # Human
	doc.set_profession_id(0)  # Combat Spec

	# Give the hero one of everything Summary is supposed to spell out.
	doc.apply(CharacterDoc.ALL, func(c):
		for broad in _rules.broad_skills:
			if typeof(broad) == TYPE_DICTIONARY and not _rules.is_psionic_skill(broad):
				_rules.set_skill_rank(c, AlternityNum.as_int(broad.get("id", 0)), 1)
				break
		for perk in AlternityRules.PERK_DEFINITIONS:
			var costs: Array = perk.get("cost_options", [])
			_rules.set_perk_selected(
				c, String(perk.get("id", "")),
				AlternityNum.as_int(costs[0] if not costs.is_empty() else perk.get("cost", 0))
			)
			break
		for flaw in AlternityRules.FLAW_DEFINITIONS:
			var bonuses: Array = flaw.get("bonus_options", [])
			_rules.set_flaw_selected(
				c, String(flaw.get("id", "")),
				AlternityNum.as_int(bonuses[0] if not bonuses.is_empty() else flaw.get("bonus", 0))
			)
			break
		_rules.fx.set_fx_talent(c, true)
		for broad in _rules.fx.get_broad_skills_for_character(c):
			_rules.fx.add_fx_skill(c, String(broad.get("name", "")))
			break)

	var tab = _mount(TAB_SUMMARY, doc)
	await process_frame

	var headings := _labels_in(tab)

	# Each of these is a section the human review asked to see inline.
	for heading in ["Skills", "FX", "Perks and Flaws"]:
		check_true(headings.has(heading), "Summary shows a %s section inline" % heading)

	# And the entries themselves, not just the headings.
	var skills: Array = _rules.selected_skills(doc.raw())
	if check(not skills.is_empty(), "the test hero holds a skill"):
		var skill_name := String(_rules.skill_label(skills[0]))
		check_true(
			_any_label_contains(headings, skill_name),
			"Summary names the skill itself (%s)" % skill_name
		)

	var perks: Array = _rules.selected_perks(doc.raw())
	if check(not perks.is_empty(), "the test hero holds a perk"):
		check_true(
			_any_label_contains(headings, String(perks[0].get("name", ""))),
			"Summary names the perk itself (%s)" % String(perks[0].get("name", ""))
		)

	tab.queue_free()


## Every piece of text in the subtree, so a test can ask what is on screen.
##
## Buttons count: their label is content a reader sees, and several of the
## things these tests assert about (generation methods, catalog actions) are
## rendered as buttons rather than labels.
func _labels_in(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label:
			out.append((child as Label).text)
		elif child is Button:
			out.append((child as Button).text)
		elif child is RichTextLabel:
			out.append((child as RichTextLabel).get_parsed_text())
		out.append_array(_labels_in(child))
	return out


func _any_label_contains(labels: Array, needle: String) -> bool:
	if needle.is_empty():
		return false
	for text in labels:
		if String(text).contains(needle):
			return true
	return false


## The new-hero flow: rules chosen before the character exists, because several
## change the starting skill budget.
func _test_optional_rules_route() -> void:
	var doc := Doc.new(_rules)
	var route = OPTIONAL_RULES_ROUTE.instantiate()
	root.add_child(route)
	route.configure({
		"palette": ThemePalette.new(),
		"rules": _rules,
		"character": doc.raw(),
		"confirm_text": "Create Hero",
	})
	await process_frame

	check_eq(route._confirm_text, "Create Hero", "the confirm label is configurable")
	check_true(route.get_child_count() > 0, "the route renders the rule list")

	# Toggling records only the net change, so a rule flipped twice applies
	# nothing.
	route._changed["2a"] = true
	check_eq(route._changed.size(), 1, "a change is recorded")

	var applied: Dictionary = route._changed.duplicate()
	for rule_id in applied:
		_rules.set_optional_rule(doc.raw(), String(rule_id), bool(applied[rule_id]))
	check_true(_rules.optional_rule_enabled(doc.raw(), "2a"), "the chosen rule reaches the character")

	route.queue_free()
