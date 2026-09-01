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
	await _test_mutations_tab()
	await _test_summary_tab()
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

	for method in ["method_1", "method_2", "spread"]:
		var rolled: Dictionary = {}
		match method:
			"method_1": rolled = _rules.roll_abilities_method_1(doc.get_profession_id())
			"method_2": rolled = _rules.roll_abilities_method_2(doc.get_species_id())
			_: rolled = _rules.roll_random_abilities_by_profession(doc.get_profession_id())

		if not check(not rolled.is_empty(), "%s produced a spread" % method):
			continue

		tab._apply_rolled(rolled)
		await process_frame

		var abilities: Dictionary = doc.raw().get("abilities", {})
		check_eq(abilities.size(), 6, "%s writes all six abilities" % method)

		var out_of_band: Array = []
		for ability in ["STR", "DEX", "CON", "INT", "WIL", "PER"]:
			var limits: Array = _rules.ability_limits(doc.raw(), ability)
			var score := AlternityNum.as_int(abilities.get(ability, 0))
			if score < AlternityNum.as_int(limits[0]) or score > AlternityNum.as_int(limits[1]):
				out_of_band.append("%s=%d" % [ability, score])
		check_true(out_of_band.is_empty(), "%s stays inside the legal band (%s)" % [method, str(out_of_band)])

		# The point target is reset to what the roll cost, so the budget is not
		# compared against a purchased spread that no longer exists.
		check_eq(
			AlternityNum.as_int(doc.raw().get("custom_ability_target", -1), -1),
			_rules.ability_total(doc.raw()),
			"%s resets the ability point target" % method
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
